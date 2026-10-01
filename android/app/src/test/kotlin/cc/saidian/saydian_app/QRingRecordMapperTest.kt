package cc.saidian.saydian_app

import com.oudmon.ble.base.bean.SleepDisplay
import com.oudmon.ble.base.communication.entity.BleStepDetails
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class QRingRecordMapperTest {
    @Test
    fun `seconds and milliseconds from SDK normalize to milliseconds`() {
        val fallback = 1_700_000_000_000L
        assertEquals(1_700_000_000_000L, QRingRecordMapper.sdkTimestamp(1_700_000_000L, fallback))
        assertEquals(1_700_000_000_123L, QRingRecordMapper.sdkTimestamp(1_700_000_000_123L, fallback))
        assertEquals(fallback, QRingRecordMapper.sdkTimestamp(0, fallback))
    }

    @Test
    fun `supported sports round trip and unknown modes fail closed`() {
        val modes = listOf(
            "running",
            "indoor_running",
            "walking",
            "cycling",
            "indoor_cycling",
            "basketball",
            "football",
            "badminton",
            "swimming",
            "jump_rope",
            "yoga",
            "hiking",
            "mountaineering",
        )

        modes.forEach { mode ->
            val type = QRingRecordMapper.sportType(mode)
            assertTrue("missing QRing sport type for $mode", type != null)
            assertEquals(mode, QRingRecordMapper.sportMode(type!!))
        }
        assertEquals(null, QRingRecordMapper.sportType("unknown"))
        assertEquals(null, QRingRecordMapper.sportMode(9_999))
    }

    @Test
    fun `native records use qring scoped device identity without double prefix`() {
        val values = linkedMapOf<String, Any>("value" to 72)
        val first = QRingRecordMapper.healthRecord(
            "AA:BB:CC:DD:EE:FF",
            "Q_HR01",
            "1.0.0",
            "heart_rate",
            1_700_000_000_000L,
            values,
            "bpm",
            "watch_history",
            "device_reported",
        )
        val second = QRingRecordMapper.healthRecord(
            "qring:AA:BB:CC:DD:EE:FF",
            "Q_HR01",
            "1.0.0",
            "heart_rate",
            1_700_000_000_000L,
            values,
            "bpm",
            "watch_history",
            "device_reported",
        )

        assertEquals("qring:AA:BB:CC:DD:EE:FF", first["deviceId"])
        assertEquals(first["deviceId"], second["deviceId"])
        assertEquals("qring", first["sourceVendor"])
        assertEquals("ring", first["sourceDeviceCategory"])
    }

    @Test
    fun `step detail uses fifteen minute slots and separates old record identity`() {
        val item = BleStepDetails().apply {
            timeIndex = 4
            walkSteps = 12
        }
        val record = QRingRecordMapper.stepRecords("ring", "R22", "1", 0, listOf(item)).single()
        val start = QRingRecordMapper.dayStart(0)
        assertEquals(Instant.ofEpochMilli(start + 60 * 60_000L).toString(), record["measuredAt"])
        val legacy = QRingRecordMapper.healthRecord(
            "ring", "R22", "1", "steps", start + 2 * 60 * 60_000L,
            linkedMapOf<String, Any>("value" to 12), "步", "watch_history", "device_reported",
        )
        assertNotEquals(legacy["id"], record["id"])
        assertEquals(2, record["rawVersion"])
    }

    @Test
    fun `sleep seconds become hours and corrected sync keeps old row separate`() {
        val sleep = SleepDisplay().apply {
            totalSleepDuration = 23_700
            deepSleepDuration = 7_200
            shallowSleepDuration = 12_600
            rapidDuration = 3_900
            awakeDuration = 600
        }
        val record = QRingRecordMapper.sleepRecords("ring", "R22", "1", 0, sleep).single()
        @Suppress("UNCHECKED_CAST")
        val values = record["values"] as Map<String, Number>
        assertEquals(23_700 / 3600.0, values["value"]!!.toDouble(), 0.001)
        assertEquals(2.0, values["deepHours"]!!.toDouble(), 0.001)
        assertEquals(3.5, values["lightHours"]!!.toDouble(), 0.001)
        assertEquals(3_900 / 3600.0, values["remHours"]!!.toDouble(), 0.001)
        assertEquals(10.0, values["awakeMinutes"]!!.toDouble(), 0.001)
        val legacy = QRingRecordMapper.healthRecord(
            "ring", "R22", "1", "sleep", QRingRecordMapper.dayStart(0) + 12 * 60 * 60_000L,
            linkedMapOf<String, Any>(
                "value" to 23_700 / 60.0,
                "deepHours" to 7_200 / 60.0,
                "lightHours" to 12_600 / 60.0,
                "remHours" to 3_900 / 60.0,
                "awakeMinutes" to 600,
                "score" to sleep.sleepScore,
            ), "h", "watch_history", "device_reported",
        )
        assertNotEquals(legacy["id"], record["id"])
    }

    @Test
    fun `current SDK stage codes retain night and nap intervals excluding awake`() {
        assertEquals("deep", QRingRecordMapper.sleepStage(1))
        assertEquals("light", QRingRecordMapper.sleepStage(2))
        assertEquals("awake", QRingRecordMapper.sleepStage(3))
        assertEquals("rem", QRingRecordMapper.sleepStage(4))
        assertEquals("unknown", QRingRecordMapper.sleepStage(5))
        val start = 1_700_000_000L
        val sleep = SleepDisplay().apply {
            list = listOf(
                SleepDisplay.SleepDataBean(start, start + 3600, 1),
                SleepDisplay.SleepDataBean(start + 3600, start + 4200, 3),
                SleepDisplay.SleepDataBean(start + 4200, start + 6000, 2),
            )
            napList = listOf(SleepDisplay.SleepDataBean(start + 36_000, start + 36_900, 4))
            totalSleepDuration = 6000
            awakeDuration = 600
        }
        val record = QRingRecordMapper.sleepRecords("ring", "R21", "1", 0, sleep).single()
        @Suppress("UNCHECKED_CAST")
        val values = record["values"] as Map<String, Number>
        assertEquals(6300 / 3600.0, values["value"]!!.toDouble(), 0.001)
        assertEquals(10.0, values["awakeMinutes"]!!.toDouble(), 0.001)
        @Suppress("UNCHECKED_CAST")
        val timeline = record["sleepTimeline"] as Map<String, Any>
        @Suppress("UNCHECKED_CAST")
        val sessions = timeline["sessions"] as List<Map<String, Any>>
        assertEquals(listOf("night", "nap"), sessions.map { it["kind"] })
        assertTrue(QRingRecordMapper.sleepTimelineIsComplete(timeline))
        assertTrue(QRingRecordMapper.sleepTimelineHasData(timeline))
    }

    @Test
    fun `partial overlapping stages preserve valid edges and invalid cross-session data fails`() {
        val start = 1_700_000_000L
        val sleep = SleepDisplay().apply {
            list = listOf(
                SleepDisplay.SleepDataBean(start, start + 3600, 1),
                SleepDisplay.SleepDataBean(start + 1800, start + 5400, 2),
            )
        }
        val record = QRingRecordMapper.sleepRecords("ring", "R21", "1", 0, sleep).single()
        @Suppress("UNCHECKED_CAST")
        val values = record["values"] as Map<String, Number>
        assertEquals(0.5, values["deepHours"]!!.toDouble(), 0.001)
        assertEquals(0.5, values["lightHours"]!!.toDouble(), 0.001)
        assertEquals(1.0, values["value"]!!.toDouble(), 0.001)
        sleep.napList = listOf(SleepDisplay.SleepDataBean(start + 600, start + 900, 4))
        assertTrue(!QRingRecordMapper.sleepTimelineIsComplete(QRingRecordMapper.sleepTimeline("ring", 0, sleep)))
        assertTrue(QRingRecordMapper.sleepRecords("ring", "R21", "1", 0, sleep).isEmpty())
        val empty = QRingRecordMapper.sleepTimeline("ring", 0, SleepDisplay())
        assertTrue(QRingRecordMapper.sleepTimelineIsComplete(empty))
        assertTrue(!QRingRecordMapper.sleepTimelineHasData(empty))
        val absentDay = QRingRecordMapper.sleepTimelineForSuccessfulRead(
            "ring", QRingRecordMapper.sleepRequestDay(0), null,
        )
        assertTrue(QRingRecordMapper.sleepTimelineIsComplete(absentDay))
        assertTrue(!QRingRecordMapper.sleepTimelineHasData(absentDay))
        assertTrue(!QRingRecordMapper.sleepTimelineIsComplete(
            QRingRecordMapper.sleepTimeline("ring", 0, null),
        ))
        assertTrue(QRingRecordMapper.sleepRecords("ring", "R21", "1", 0, SleepDisplay()).isEmpty())
    }

    @Test
    fun `sleep callback preserves request day and timezone after midnight`() {
        val requested = QRingRecordMapper.sleepRequestDay(
            LocalDate.of(2023, 11, 14), ZoneId.of("Asia/Shanghai"),
        )
        val laterPhoneDay = QRingRecordMapper.sleepRequestDay(
            LocalDate.of(2023, 11, 15), ZoneId.of("America/New_York"),
        )
        assertNotEquals(requested.sdkDate, laterPhoneDay.sdkDate)
        assertNotEquals(requested.timezone, laterPhoneDay.timezone)
        val sleep = SleepDisplay().apply {
            deepSleepDuration = 3600
            awakeDuration = 600
            totalSleepDuration = 4200
        }
        val timeline = QRingRecordMapper.sleepTimeline("ring", requested, sleep)
        assertEquals("2023-11-14", timeline["sdkDate"])
        assertEquals("+08:00", timeline["timezone"])
        val record = QRingRecordMapper.sleepRecords("ring", "R21", "1", requested, sleep).single()
        assertEquals("+08:00", record["timezone"])
        assertEquals(
            Instant.ofEpochMilli(requested.dayStart + 12 * 60 * 60_000L).toString(),
            record["measuredAt"],
        )
        @Suppress("UNCHECKED_CAST")
        assertEquals("2023-11-14", (record["sleepTimeline"] as Map<String, Any>)["sdkDate"])
    }

    @Test
    fun `invalid SDK raw summary rejects day before Flutter batch parsing`() {
        val corrupt: List<(SleepDisplay) -> Unit> = listOf(
            { it.totalSleepDuration = -1 },
            { it.totalSleepDuration = 86401 },
            { it.deepSleepDuration = -1 },
            { it.deepSleepDuration = 86401 },
            { it.shallowSleepDuration = -1 },
            { it.shallowSleepDuration = 86401 },
            { it.awakeDuration = -1 },
            { it.awakeDuration = 86401 },
            { it.rapidDuration = -1 },
            { it.rapidDuration = 86401 },
            { it.napDuration = -1 },
            { it.napDuration = 86401 },
            { it.deepSleepDuration = 50000; it.shallowSleepDuration = 50000 },
        )
        val start = 1_700_000_000L
        for (change in corrupt) {
            val sleep = SleepDisplay().apply {
                list = listOf(SleepDisplay.SleepDataBean(start, start + 3600, 1))
                deepSleepDuration = 3600
                totalSleepDuration = 3600
            }
            change(sleep)
            val timeline = QRingRecordMapper.sleepTimeline("ring", 0, sleep)
            assertTrue(!QRingRecordMapper.sleepTimelineIsComplete(timeline))
            assertTrue(QRingRecordMapper.sleepRecords("ring", "R21", "1", 0, sleep).isEmpty())
        }
    }
}
