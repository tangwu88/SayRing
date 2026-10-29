package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QRingHistoryReadStateTest {
    @Test
    fun `one failed day is not erased by later successful days`() {
        val state = QRingHistoryReadState()
        state.begin(listOf("steps", "sleep"), 7)
        repeat(7) { day ->
            assertTrue(state.accept(state.open("steps"), day != 2, day != 2))
            assertTrue(state.accept(state.open("sleep"), true, false))
        }
        assertEquals(mapOf("steps" to "failed", "sleep" to "no_data"), state.statuses())
    }

    @Test
    fun `complete requires all requested days and distinguishes an explicit empty response`() {
        val state = QRingHistoryReadState()
        state.begin(listOf("steps", "sleep"), 2)
        state.accept(state.open("steps"), true, true)
        state.accept(state.open("sleep"), true, false)
        assertEquals(mapOf("steps" to "failed", "sleep" to "failed"), state.statuses())
        state.accept(state.open("steps"), true, false)
        state.accept(state.open("sleep"), true, false)
        assertEquals(mapOf("steps" to "complete", "sleep" to "no_data"), state.statuses())
    }

    @Test
    fun `duplicate and old callbacks cannot advance a different day or request`() {
        val state = QRingHistoryReadState()
        state.begin(listOf("steps"), 2)
        val first = state.open("steps")
        assertTrue(state.accept(first, true, true))
        val next = state.open("steps")
        assertFalse(state.accept(first, false, false))
        assertTrue(state.accept(next, true, false))
        assertEquals("complete", state.statuses()["steps"])
        state.begin(listOf("steps"), 1)
        val replacement = state.open("steps")
        assertFalse(state.accept(next, true, true))
        assertTrue(state.accept(replacement, true, false))
        assertEquals("no_data", state.statuses()["steps"])
    }

    @Test
    fun `cancelled read cannot claim a response or affect the following request`() {
        val state = QRingHistoryReadState()
        state.begin(listOf("steps"), 1)
        val cancelled = state.open("steps")
        state.cancel()
        assertFalse(state.accept(cancelled, true, true))
        assertEquals("failed", state.statuses()["steps"])
        state.begin(listOf("steps"), 1)
        assertTrue(state.accept(state.open("steps"), true, false))
        assertEquals("no_data", state.statuses()["steps"])
    }
}
