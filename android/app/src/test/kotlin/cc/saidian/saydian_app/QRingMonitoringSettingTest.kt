package cc.saidian.saydian_app

import com.oudmon.ble.base.communication.req.PressureSettingReq
import com.oudmon.ble.base.communication.rsp.*
import org.junit.Assert.*
import org.junit.Test

class QRingMonitoringSettingTest {
    private fun rejects(block: () -> Unit) {
        try { block(); fail("Invalid setting was accepted") }
        catch (_: IllegalArgumentException) { }
    }
    private fun oxygen(interval: Int, enabled: Boolean = true): QRingMonitoringSetting {
        val rsp = BloodOxygenSettingRsp()
        rsp.acceptData(byteArrayOf(1, if (enabled) 1 else 0, interval.toByte()))
        return QRingMonitoringSetting.read("bloodOxygen", rsp)!!
    }

    @Test fun `oxygen interval is independent and survives disabling`() {
        val setting = oxygen(30)
        assertEquals(30, setting.intervalMap()["minutes"])
        val encoded = setting.write("bloodOxygen", null, false).data
        assertEquals(listOf(2, 0, 30), encoded.slice(1..3).map { it.toInt() and 255 })
        val changed = setting.write("bloodOxygen", 15, null).data
        assertEquals(listOf(2, 1, 15), changed.slice(1..3).map { it.toInt() and 255 })
    }

    @Test fun `byte intervals are unsigned and missing values do not get fabricated`() {
        assertEquals(200, oxygen(200).minutes)
        assertNull(oxygen(0).intervalMap())
        rejects { oxygen(0).write("bloodOxygen", 10, null) }
        rejects { oxygen(30, false).write("bloodOxygen", 10, null) }
        rejects { oxygen(30).write("bloodOxygen", 256, null) }
    }

    @Test fun `pressure honors firmware minimum and clears SDK interval cache`() {
        val rsp = PressureSettingRsp()
        rsp.acceptData(byteArrayOf(1, 1, 5, 30))
        val setting = QRingMonitoringSetting.read("stress", rsp)!!
        assertEquals(5, setting.intervalMap()["minMinutes"])
        rejects { setting.write("stress", 4, null) }
        val write = setting.write("stress", null, false) as PressureSettingReq
        assertFalse(write.isOpen)
        assertEquals(5, write.minInterval)
        assertEquals(30, write.interval)
        assertFalse(PressureSettingReq.getWriteInstance(true).hasIntervalSettings())
    }

    @Test fun `toggle-only pressure firmware stays toggle-only`() {
        val rsp = PressureSettingRsp()
        rsp.acceptData(byteArrayOf(1, 1))
        val setting = QRingMonitoringSetting.read("stress", rsp)!!
        assertNull(setting.intervalMap())
        assertFalse((setting.write("stress", null, false) as PressureSettingReq).hasIntervalSettings())
        rejects { setting.write("stress", 5, null) }
    }

    @Test fun `temperature uses its own readback and range`() {
        val rsp = BloodSugarLipidsSettingRsp()
        rsp.acceptData(byteArrayOf(3, 1, 1, 20, 5))
        val setting = QRingMonitoringSetting.read("bodyTemperature", rsp)!!
        assertEquals(20, setting.minutes)
        assertEquals(5, setting.minimum)
        rejects { setting.write("bodyTemperature", 2, null) }
        val wrongType = BloodSugarLipidsSettingRsp()
        wrongType.acceptData(byteArrayOf(4, 1, 1, 20, 5))
        assertNull(QRingMonitoringSetting.read("bodyTemperature", wrongType))
    }

    @Test fun `failed response or write ACK cannot be treated as a setting read`() {
        val rsp = BloodOxygenSettingRsp()
        rsp.acceptData(byteArrayOf(2, 1, 30))
        assertNull(QRingMonitoringSetting.read("bloodOxygen", rsp))
        rsp.acceptData(byteArrayOf(1, 1, 30))
        rsp.status = 1
        assertNull(QRingMonitoringSetting.read("bloodOxygen", rsp))
        assertNull(QRingMonitoringSetting.read("hrv", HRVSettingRsp()))
    }

    @Test fun `not-worn SDK callback fails immediately even when generic status is OK`() {
        val rsp = StartHeartRateRsp()
        rsp.errCode = 3
        assertEquals(BaseRspCmd.RESULT_OK, rsp.status)
        assertTrue(QRingBridge.measurementFailed(rsp))
        rsp.errCode = 0
        assertFalse(QRingBridge.measurementFailed(rsp))
        rsp.status = 1
        assertTrue(QRingBridge.measurementFailed(rsp))
        assertTrue(QRingBridge.measurementFailed(null))
    }
}
