package cc.saidian.saydian_app

import org.junit.Assert.*
import org.junit.Test

class RingGestureBondPolicyTest {
    @Test fun `only exact pending target in the same connection may authorize gesture sending`() {
        val target = "AA:BB:CC:DD:EE:01"
        assertTrue(RingGestureBondPolicy.accepts(target, 2, target.lowercase(), 2, true))
        assertFalse(RingGestureBondPolicy.accepts(target, 2, "AA:BB:CC:DD:EE:02", 2, true))
        assertFalse(RingGestureBondPolicy.accepts(target, 2, target, 3, true))
        assertFalse(RingGestureBondPolicy.accepts(target, 2, target, 2, false))
        assertFalse(RingGestureBondPolicy.accepts(null, 2, target, 2, true))
        assertFalse(RingGestureBondPolicy.accepts("", 2, target, 2, true))
        assertFalse(RingGestureBondPolicy.accepts(target, 2, null, 2, true))
    }
}
