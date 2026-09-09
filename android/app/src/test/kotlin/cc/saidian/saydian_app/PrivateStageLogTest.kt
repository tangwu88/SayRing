package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class PrivateStageLogTest {
    @Test
    fun healthValuesAndDeviceIdentityNeverReachStageNames() {
        val samples = mapOf(
            "measurement callback metric=hrv value=72 active=hrv" to "measurement_callback",
            "measurement callback high=121 low=81" to "measurement_callback",
            "measurement start device=AA:BB:CC:DD:EE:FF" to "measurement_start",
            "Confirmed disconnect for AA:BB:CC:DD:EE:FF" to "device_disconnect",
            "health sync idle timeout device=private-uuid stage=origin" to "health_sync",
            "Current watch face: /private/path.bin" to "watch_face_operation",
            "AuthKey=secret Token=secret user@example.invalid" to "native_operation",
            "DF 00 81 79 00 21" to "native_operation",
        )
        samples.forEach { (payload, expected) ->
            val stage = PrivateStageNames.fromMessage(payload)
            assertEquals(expected, stage)
            assertFalse(stage.any { it.isDigit() })
            assertFalse(stage.contains(":"))
            assertFalse(stage.contains("@"))
            assertFalse(stage.contains("secret"))
        }
    }
}
