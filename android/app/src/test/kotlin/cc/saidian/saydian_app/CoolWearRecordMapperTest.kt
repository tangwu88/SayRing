package cc.saidian.saydian_app

import ce.com.cenewbluesdk.entity.K6_sleepData
import ce.com.cenewbluesdk.entity.k6.K6_MixSportType
import ce.com.cenewbluesdk.entity.k6.K6_Mix_sport_Struct
import ce.com.cenewbluesdk.entity.k6.K6_Sport
import ce.com.cenewbluesdk.entity.k6.k6_RRI_HRV_DATA
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CoolWearRecordMapperTest {
    private val nowSeconds: Int
        get() = (System.currentTimeMillis() / 1_000L).toInt()

    @Test
    fun `activity data maps steps distance and calories without zero fillers`() {
        val sample = K6_Sport().apply {
            starTime = nowSeconds
            walkSteps = 1_234
            distance = 1_500
            calories = 45
        }

        val records = CoolWearRecordMapper.activityRecords("ring", "1.0", listOf(sample))

        assertEquals(listOf("steps", "distance", "calories"), records.map { it["type"] })
        assertEquals(1.5, value(records, "distance"), 0.0001)
    }

    @Test
    fun `sleep data preserves sleep composition and wake count`() {
        val session = K6_sleepData().apply {
            startTime = (nowSeconds - 8 * 3_600).toLong()
            endTime = nowSeconds.toLong()
            sleepTime = 420
            deepTime = 120
            lightTime = 280
            movementTime = 20
            revivetimes = 2
        }
        val container = K6_sleepData().apply { k6SleepData = listOf(session) }

        val record = CoolWearRecordMapper.sleepRecords("ring", "1.0", container).single()
        @Suppress("UNCHECKED_CAST")
        val values = record["values"] as Map<String, Number>

        assertEquals(7.0, values.getValue("value").toDouble(), 0.0001)
        assertEquals(2.0, values.getValue("deepHours").toDouble(), 0.0001)
        assertEquals(2, values.getValue("wakeCount").toInt())
    }

    @Test
    fun `HRV uses device SDNN and retains supporting measurements`() {
        val sample = k6_RRI_HRV_DATA().apply {
            time = nowSeconds
            sdnn = 42
            rmssd = 38
            rri = 760
        }

        val record = CoolWearRecordMapper.hrvRecords("ring", "1.0", listOf(sample)).single()
        @Suppress("UNCHECKED_CAST")
        val values = record["values"] as Map<String, Number>

        assertEquals(42, values.getValue("value").toInt())
        assertEquals(38, values.getValue("rmssd").toInt())
    }

    @Test
    fun `known workout becomes app mode and unknown workout is skipped`() {
        val hiking = K6_Mix_sport_Struct().apply {
            sport_type = K6_MixSportType.MIX_SPORT_ON_FOOT
            startTime = (nowSeconds - 600).toLong() * 1_000L
            endTime = nowSeconds.toLong() * 1_000L
            totalTime = 600
            distance = 1_200
            step = 1_500
        }
        val unknown = K6_Mix_sport_Struct().apply {
            sport_type = 9_999
            startTime = nowSeconds.toLong() * 1_000L
        }

        val records = CoolWearRecordMapper.sportRecords("ring", listOf(hiking, unknown))

        assertEquals(1, records.size)
        assertEquals("hiking", records.single()["mode"])
        assertEquals(1.2, records.single()["distanceKm"] as Double, 0.0001)
    }

    @Test
    fun `impossible future timestamp is rejected`() {
        val twoDaysAhead = System.currentTimeMillis() + 2 * 86_400_000L
        assertEquals(0L, CoolWearRecordMapper.historyTimestamp(twoDaysAhead))
        assertTrue(CoolWearRecordMapper.historyTimestamp(nowSeconds.toLong()) > 0)
    }

    private fun value(records: List<Map<String, Any>>, type: String): Double {
        val record = records.single { it["type"] == type }
        @Suppress("UNCHECKED_CAST")
        return ((record["values"] as Map<String, Number>).getValue("value")).toDouble()
    }
}
