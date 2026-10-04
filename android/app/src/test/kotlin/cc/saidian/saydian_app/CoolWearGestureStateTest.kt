package cc.saidian.saydian_app

import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_GESTURE_CONFIG
import org.junit.Assert.*
import org.junit.Test

class CoolWearGestureStateTest {
    @Test fun `six modes agree with shipped SDK constants`() {
        assertEquals(listOf(0, 1, 2, 3, 4, 5), listOf(
            K6_DATA_TYPE_GESTURE_CONFIG.GESTURE_CTRL_TYPE_NONE,
            K6_DATA_TYPE_GESTURE_CONFIG.GESTURE_CTRL_TYPE_TIKTOK,
            K6_DATA_TYPE_GESTURE_CONFIG.GESTURE_CTRL_TYPE_MUSIC,
            K6_DATA_TYPE_GESTURE_CONFIG.GESTURE_CTRL_TYPE_READER,
            K6_DATA_TYPE_GESTURE_CONFIG.GESTURE_CTRL_TYPE_PHOTO,
            K6_DATA_TYPE_GESTURE_CONFIG.GESTURE_CTRL_TYPE_TELEPHONE,
        ))
    }

    @Test fun `capability requires handshake and actual device flag`() {
        assertTrue(CoolWearGestureState.supported(true, true, true))
        assertFalse(CoolWearGestureState.supported(false, true, true))
        assertFalse(CoolWearGestureState.supported(true, false, true))
        assertFalse(CoolWearGestureState.supported(true, true, false))
    }

    @Test fun `invalid types and out of range modes cannot be sent`() {
        listOf(null, -1, 6, Long.MAX_VALUE, 4.0, true, "4").forEach {
            assertNull(CoolWearGestureState.validMode(it))
            assertFalse(CoolWearGestureState().begin(it, 100))
        }
        assertEquals(4, CoolWearGestureState.validMode(4L))
    }

    @Test fun `write stays unknown until matching reply`() {
        (0..5).forEach { mode ->
            val state = CoolWearGestureState()
            assertTrue(state.begin(mode, 100))
            assertNull(state.confirmedMode())
            assertFalse(state.confirm((mode + 1) % 6, state.generation(), 101))
            assertTrue(state.pending())
            assertTrue(state.confirm(mode, state.generation(), 102))
            assertEquals(mode, state.confirmedMode())
            assertFalse(state.pending())
            assertFalse(state.confirm(mode, state.generation(), 103))
        }
    }

    @Test fun `duplicates and concurrent writes cannot replace a pending request`() {
        val state = CoolWearGestureState()
        assertTrue(state.begin(1, 100))
        assertFalse(state.begin(2, 101))
        assertFalse(state.begin(1, 102))
        assertTrue(state.confirm(1, state.generation(), 103))
        assertTrue(state.begin(2, 104))
        assertNull(state.confirmedMode())
        assertFalse(state.confirm(1, state.generation(), 105))
    }

    @Test fun `deadline and late reply never produce success or enable retry`() {
        val state = CoolWearGestureState()
        assertTrue(state.begin(4, 100))
        assertFalse(state.confirm(4, state.generation(), 100 + CoolWearGestureState.TIMEOUT_MS))
        state.fail()
        assertNull(state.confirmedMode())
        assertTrue(state.requiresReconnect())
        assertFalse(state.confirm(4, state.generation(), 8200))
        assertFalse(state.begin(4, 8300))
        state.reset()
        assertTrue(state.begin(4, 8400))
    }

    @Test fun `reconnection discards old confirmed state and queued callback generation`() {
        val state = CoolWearGestureState()
        val previous = state.generation()
        assertTrue(state.begin(3, 100))
        assertTrue(state.confirm(3, previous, 101))
        state.reset()
        assertNull(state.confirmedMode())
        assertTrue(state.begin(3, 102))
        assertFalse(state.confirm(3, previous, 103))
        assertTrue(state.confirm(3, state.generation(), 104))
    }

    @Test fun `disconnect cancels a pending operation without changing next ring mode`() {
        val state = CoolWearGestureState()
        assertTrue(state.begin(5, 100))
        state.reset()
        assertFalse(state.pending())
        assertNull(state.confirmedMode())
        assertFalse(state.confirm(5, state.generation(), 101))
    }
}
