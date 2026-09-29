package cc.saidian.saydian_app

import com.oudmon.ble.base.bean.SleepDisplay
import com.oudmon.ble.base.communication.entity.BleStepDetails
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

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
}
