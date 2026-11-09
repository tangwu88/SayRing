package cc.saidian.saydian_app

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.*
import org.junit.Test
import ce.com.cenewbluesdk.entity.k6.K6_Sport
import com.oudmon.ble.base.communication.req.StartHeartRateReq
import com.oudmon.ble.base.communication.rsp.RealTimeHeartRateRsp

class SportSessionCountersTest {
    @Test fun `SDK recovery lease is bounded and duplicate drops cannot extend it`() {
        val lease = CoolWearRecoveryLease()
        assertTrue(lease.begin("AA:BB", 1, 1000))
        assertFalse(lease.begin("aa:bb", 1, 5000))
        assertEquals(11000L, lease.remaining(5000))
        assertEquals(0L, lease.remaining(16000))
        assertFalse(lease.matches("CC:DD", 1))
        assertFalse(lease.matches("AA:BB", 2))
        assertTrue(lease.begin("AA:BB", 2, 17000))
        assertFalse(lease.matches("AA:BB", 1))
        lease.clear()
        assertFalse(lease.matches("AA:BB", 2))
    }
    @Test fun `R7 workout consumes the actual SDK exercise channel without a parallel manual measurement`() {
        assertTrue(CoolWearLiveActivity.usesExerciseHeart("R7Ultra"))
        assertTrue(CoolWearLiveActivity.usesExerciseHeart("R7Pro"))
        assertFalse(CoolWearLiveActivity.usesExerciseHeart("HR05"))
        assertFalse(CoolWearLiveActivity.usesExerciseHeart(null))
        val exercise = ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean.ProcessDATA_TYPE_HEART_EXERCISE(null)
        assertTrue(exercise.isMyStr(ce.com.cenewbluesdk.entity.k6.K6_Action.RCVD.RCVD_SPORT_HEART))
        assertTrue(exercise.isMy(ce.com.cenewbluesdk.CEBC.K6.DATA_TYPE_EXERCISE_HEART))
        assertFalse(exercise.isMy(ce.com.cenewbluesdk.CEBC.K6.DATA_TYPE_REAL_HEART))
    }
    @Test fun `live device pushes suppress redundant reads but silence permits recovery reads`() {
        assertTrue(CoolWearLiveActivity.needsRead(10000, 0))
        assertFalse(CoolWearLiveActivity.needsRead(20000, 19000))
        assertFalse(CoolWearLiveActivity.needsRead(24999, 10000))
        assertTrue(CoolWearLiveActivity.needsRead(25000, 10000))
    }
    @Test fun `late pre-midnight reply cannot be counted as new-day activity`() {
        val state = SportSessionCounters()
        state.acceptReadDay(1, 1, 12000, 6000)
        assertEquals(12L, state.acceptReadDay(1, 1, 12012, 6010)!!["steps"])
        assertNull(state.acceptReadDay(1, 2, 12020, 6020))
        assertEquals(15L, state.acceptReadDay(2, 2, 3, 2)!!["steps"])
    }
    @Test fun `live polling cannot create repeated daily history and true history remains accepted`() {
        assertFalse(CoolWearLiveActivity.persistAsHistory(4, true))
        assertTrue(CoolWearLiveActivity.persistAsHistory(5, true))
        assertTrue(CoolWearLiveActivity.persistAsHistory(4, false))
        assertTrue(CoolWearLiveActivity.persistAsHistory(5, false))
        assertFalse(CoolWearLiveActivity.persistAsHistory(6, false))
    }
    @Test fun `daily counters become session deltas and regressions stay rejected`() {
        val state = SportSessionCounters()
        assertEquals(0L, state.accept(1, 10000, 6000)!!["steps"])
        assertEquals(30L, state.accept(1, 10030, 6025)!!["steps"])
        assertNull(state.accept(1, 9000, 5000))
        assertEquals(40L, state.accept(1, 10040, 6035)!!["steps"])
        assertNull(state.accept(0, 1, 1))
        assertEquals(43L, state.accept(2, 3, 3)!!["steps"])
        assertNull(state.accept(1, 20000, 9000))
        state.rebase()
        assertEquals(43L, state.accept(2, 500, 900)!!["steps"])
        assertEquals(48L, state.accept(2, 505, 905)!!["steps"])
        state.reset()
        assertEquals(0L, state.accept(3, 6000, 9000)!!["steps"])
    }
    private fun frame(at: Long, steps: Int): ByteArray {
        val row = ByteBuffer.allocate(K6_Sport.getItemSize()).order(ByteOrder.LITTLE_ENDIAN)
            .putInt((at / 1000).toInt()).putInt(steps).putInt(steps).array()
        return byteArrayOf(1, 0, 1) + row
    }
    @Test fun `type4 parsing uses actual SDK row size and rejects stale or malformed frames`() {
        val state = SportSessionCounters(); val now = System.currentTimeMillis()
        assertEquals(0L, CoolWearLiveActivity.accept(frame(now, 2000), state, now)!!["steps"])
        assertEquals(12L, CoolWearLiveActivity.accept(frame(now, 2012), state, now)!!["steps"])
        assertNull(CoolWearLiveActivity.accept(frame(now - 86400000, 3000), state, now))
        assertNull(CoolWearLiveActivity.accept(frame(now, 2015).dropLast(1).toByteArray(), state, now))
        assertNull(CoolWearLiveActivity.accept(byteArrayOf(0,0,0), state, now))
    }
    @Test fun `advancing snapshot timestamps never re-add the daily cumulative total`() {
        val state = SportSessionCounters()
        val now = java.time.LocalDate.of(2026, 11, 7).atTime(12, 0)
            .atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
        assertEquals(0L, CoolWearLiveActivity.accept(frame(now, 1214), state, now)!!["steps"])
        assertEquals(8L, CoolWearLiveActivity.accept(frame(now + 10000, 1222), state, now + 10000)!!["steps"])
        assertEquals(8L, CoolWearLiveActivity.accept(frame(now + 20000, 1222), state, now + 20000)!!["steps"])
        assertEquals(25L, CoolWearLiveActivity.accept(frame(now + 30000, 1239), state, now + 30000)!!["steps"])
        assertNull(CoolWearLiveActivity.accept(frame(now + 5000, 1218), state, now + 40000))
        assertEquals(25L, CoolWearLiveActivity.accept(frame(now + 40000, 1239), state, now + 40000)!!["steps"])
    }
    @Test fun `QRing realtime HR uses SDK named start-stop selectors and unsigned samples`() {
        val start = StartHeartRateReq.getRealtimeHeartRate(StartHeartRateReq.ACTION_START).data
        val stop = StartHeartRateReq.getRealtimeHeartRate(StartHeartRateReq.ACTION_STOP).data
        assertEquals(105, start[0].toInt() and 255)
        assertEquals(6, start[1].toInt() and 255)
        assertEquals(1, start[2].toInt() and 255)
        assertEquals(4, stop[2].toInt() and 255)
        val reply = RealTimeHeartRateRsp(); reply.acceptData(byteArrayOf(150.toByte()))
        assertEquals(150, reply.heart and 255)
    }
}
