package cc.saidian.saydian_app

import org.junit.Assert.*
import org.junit.Test

class CoolWearSyncWindowTest {
    @Test fun `silent stream times out at original thirty second bound`() {
        val window = CoolWearSyncWindow(100)
        assertEquals(30_000L, window.remaining(100))
        assertEquals(1L, window.remaining(30_099))
        assertEquals(0L, window.remaining(30_100))
    }

    @Test fun `valid packets prevent premature fixed deadline without infinite wait`() {
        val window = CoolWearSyncWindow(0)
        window.received(25_000)
        assertEquals(25_000L, window.remaining(30_000))
        window.received(50_000)
        window.received(75_000)
        assertEquals(15_000L, window.remaining(75_000))
        assertEquals(0L, window.remaining(90_000))
    }

    @Test fun `late packet cannot resurrect expired stream`() {
        val window = CoolWearSyncWindow(0)
        window.received(30_000)
        assertEquals(0L, window.remaining(30_000))
        window.received(40_000)
        assertEquals(0L, window.remaining(40_000))
    }
}
