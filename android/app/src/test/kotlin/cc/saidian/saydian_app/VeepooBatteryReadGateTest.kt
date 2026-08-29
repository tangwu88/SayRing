package cc.saidian.saydian_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VeepooBatteryReadGateTest {
    @Test
    fun `battery snapshot keeps grid semantics and sdk low state`() {
        val grid = VeepooBatterySnapshot.fromSdk(false, percent = 75, level = 3, low = true, chargeState = 0)!!

        assertEquals(3, grid.value)
        assertEquals(4, grid.scale)
        assertNull(grid.percent)
        assertTrue(grid.low)
        assertNull(VeepooBatterySnapshot.fromSdk(false, 0, 5, false, 0))

        val percent = VeepooBatterySnapshot.fromSdk(true, percent = 65, level = 3, low = false, chargeState = 1)!!
        assertEquals(65, percent.percent)
        assertEquals(100, percent.scale)
    }

    @Test
    fun `completed request releases the lock for a retry`() {
        val gate = VeepooBatteryReadGate()
        val first = gate.begin(4, "AA:BB")!!

        assertNull(gate.begin(4, "AA:BB"))
        assertTrue(gate.complete(first, 4, "AA:BB"))
        assertFalse(gate.isInFlight)
        assertNotNull(gate.begin(4, "AA:BB"))
    }

    @Test
    fun `late callback from the previous watch cannot finish the new read`() {
        val gate = VeepooBatteryReadGate()
        val old = gate.begin(4, "AA:BB")!!
        gate.reset()
        val current = gate.begin(5, "CC:DD")!!

        assertFalse(gate.complete(old, 5, "CC:DD"))
        assertTrue(gate.isInFlight)
        assertTrue(gate.complete(current, 5, "CC:DD"))
    }

    @Test
    fun `same callback is discarded after the connection generation changes`() {
        val gate = VeepooBatteryReadGate()
        val request = gate.begin(4, "AA:BB")!!

        assertFalse(gate.complete(request, 5, "CC:DD"))
        assertFalse(gate.isInFlight)
    }

    @Test
    fun `late exclusive operation cannot release a newer transfer`() {
        val gate = VeepooExclusiveOperationGate()
        val old = gate.begin()!!
        gate.reset()
        val current = gate.begin()!!

        assertFalse(gate.complete(old))
        assertTrue(gate.isInFlight)
        assertTrue(gate.complete(current))
        assertFalse(gate.isInFlight)
    }
}
