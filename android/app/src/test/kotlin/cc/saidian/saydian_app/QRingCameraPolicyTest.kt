package cc.saidian.saydian_app

import org.junit.Assert.*
import org.junit.Test

class QRingCameraPolicyTest {
    @Test fun `photo controls require real gesture or touch support and mapped protocol`() {
        for (mask in 0 until 32) {
            val flag = (0 until 5).map { mask and (1 shl it) != 0 }
            assertEquals((flag[0] && flag[1]) || (flag[2] && flag[3] && !flag[4]),
                QRingCameraPolicy.supported(flag[0], flag[1], flag[2], flag[3], flag[4]))
        }
    }

    @Test fun `mode five only means camera and unrelated parameters are retained`() {
        for (mode in 0..9) {
            val gesture = QRingCameraPolicy.snapshot(mode, 7, false, 0)!!
            assertEquals(mode == 5, gesture["enabled"])
            assertEquals(7, gesture["strength"])
            assertFalse(gesture.containsKey("duration"))
            val touch = QRingCameraPolicy.snapshot(mode, 0, true, 8)!!
            assertEquals(mode == 5, touch["enabled"])
            assertEquals(8, touch["duration"])
            assertFalse(touch.containsKey("strength"))
        }
    }

    @Test fun `malformed fields do not create usable settings`() {
        for (mode in listOf(-1, 10)) assertNull(QRingCameraPolicy.snapshot(mode, 1, false, 0))
        for (strength in listOf(0, 11)) assertNull(QRingCameraPolicy.snapshot(5, strength, false, 0))
        for (duration in listOf(0, 11)) assertNull(QRingCameraPolicy.snapshot(5, 0, true, duration))
    }
}
