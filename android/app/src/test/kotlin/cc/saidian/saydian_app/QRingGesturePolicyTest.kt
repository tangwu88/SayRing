package cc.saidian.saydian_app
import org.junit.Assert.*
import org.junit.Test
class QRingGesturePolicyTest {
    @Test fun `cleanup can close after a lost scene read but cannot enable with that exception`() {
        assertTrue(QRingGesturePolicy.validExpectedMode(0,null,true))
        assertTrue(QRingGesturePolicy.validExpectedMode(0,-1,true))
        for (mode in 1..5) assertFalse(QRingGesturePolicy.validExpectedMode(mode,null,true))
        for (expected in listOf(null,-1,10,true,"2")) assertFalse(QRingGesturePolicy.validExpectedMode(1,expected,false))
        for (expected in 0..9) assertTrue(QRingGesturePolicy.validExpectedMode(1,expected,false))
    }
    @Test fun `sensitivity requires explicit valid selection only when current value is unconfigured`() {
        assertEquals(-1, QRingGesturePolicy.writeStrength(false,0,null))
        for (value in listOf<Any>(0,11,-1,true,"5",5.0)) assertEquals(-1,QRingGesturePolicy.writeStrength(false,0,value))
        for (value in 1..10) {
            assertEquals(value,QRingGesturePolicy.writeStrength(false,value,null))
            assertEquals(value,QRingGesturePolicy.writeStrength(false,0,value))
        }
        assertEquals(0,QRingGesturePolicy.writeStrength(true,0,null))
    }
    @Test fun `UI modes roundtrip through QRing firmware enum`() {
        val expected = listOf(0,2,1,4,5,6)
        for (app in 0..5) {
            val raw = QRingGesturePolicy.rawMode(app)
            assertEquals(expected[app], raw)
            assertEquals(app, QRingGesturePolicy.appMode(raw))
            val snapshot = QRingGesturePolicy.snapshot(QRingCameraPolicy.snapshot(raw,7,false,0),listOf(0,1,4))!!
            assertEquals(app, snapshot["confirmedMode"])
            assertEquals(raw != 0, snapshot["enabled"])
            assertEquals(7, snapshot["strength"])
            assertEquals(listOf(0,1,4), snapshot["availableModes"])
        }
    }
    @Test fun `unknown firmware modes stay distinct and touch duration survives`() {
        for (raw in listOf(3,7,8,9)) {
            val snapshot = QRingGesturePolicy.snapshot(QRingCameraPolicy.snapshot(raw,0,true,8),listOf(0))!!
            assertEquals(-1, snapshot["confirmedMode"])
            assertEquals(raw, snapshot["rawMode"])
            assertEquals(8, snapshot["duration"])
        }
        assertEquals(-1, QRingGesturePolicy.rawMode(6))
        assertEquals(-1, QRingGesturePolicy.rawMode(-1))
        assertNull(QRingGesturePolicy.snapshot(null, listOf(0)))
    }
}
