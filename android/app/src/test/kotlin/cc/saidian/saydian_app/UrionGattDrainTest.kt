package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UrionGattDrainTest {
    private class Fixture(
        failDisconnect: Boolean = false,
        failClose: Boolean = false,
    ) {
        val events = mutableListOf<String>()
        val deadlines = mutableListOf<() -> Unit>()
        val drain = UrionGattDrain<Any>(
            disconnect = {
                events.add("disconnect")
                if (failDisconnect) throw IllegalStateException()
            },
            close = {
                events.add("close")
                if (failClose) throw IllegalStateException()
            },
            scheduleTimeout = { timeout ->
                deadlines.add(timeout)
                val cancel: () -> Unit = { events.add("cancel-timeout") }
                cancel
            },
        )
    }

    @Test
    fun `disconnect completes only after the old GATT closes`() {
        val fixture = Fixture()
        val old = Any()
        fixture.drain.retire(old)
        fixture.drain.whenDrained { fixture.events.add("completed:$it") }
        assertEquals(listOf("disconnect"), fixture.events)

        fixture.drain.didDisconnect(old)
        assertEquals(listOf("disconnect", "cancel-timeout", "close", "completed:true"), fixture.events)
    }

    @Test
    fun `timeout closes before the next connection is allowed`() {
        val fixture = Fixture()
        fixture.drain.retire(Any())
        fixture.drain.whenDrained { closed ->
            assertTrue(closed)
            fixture.events.add("connect-next")
        }
        fixture.deadlines.single().invoke()
        assertEquals(listOf("disconnect", "cancel-timeout", "close", "connect-next"), fixture.events)
    }

    @Test
    fun `late duplicate callback cannot close twice or release a newer drain`() {
        val fixture = Fixture()
        val old = Any()
        val next = Any()
        fixture.drain.retire(old)
        fixture.deadlines.single().invoke()
        fixture.drain.retire(next)
        var completed = false
        fixture.drain.whenDrained { completed = it }
        fixture.drain.didDisconnect(old)
        assertFalse(completed)
        assertEquals(1, fixture.events.count { it == "close" })
        fixture.drain.didDisconnect(next)
        assertTrue(completed)
        assertEquals(2, fixture.events.count { it == "close" })
    }

    @Test
    fun `all retired clients must close before concurrent waiters complete`() {
        val fixture = Fixture()
        val first = Any()
        val second = Any()
        fixture.drain.retire(first)
        fixture.drain.retire(first)
        fixture.drain.retire(second)
        var completions = 0
        repeat(2) { fixture.drain.whenDrained { if (it) completions++ } }
        fixture.drain.didDisconnect(first)
        assertEquals(0, completions)
        fixture.drain.didDisconnect(second)
        assertEquals(2, completions)
        assertEquals(2, fixture.events.count { it == "disconnect" })
    }

    @Test
    fun `disconnect failure still closes the client before completion`() {
        val fixture = Fixture(failDisconnect = true)
        fixture.drain.retire(Any())
        fixture.drain.whenDrained { fixture.events.add("completed:$it") }
        assertEquals(listOf("disconnect", "cancel-timeout", "close", "completed:true"), fixture.events)
    }

    @Test
    fun `close failure refuses success and the next connection`() {
        val fixture = Fixture(failClose = true)
        val old = Any()
        fixture.drain.retire(old)
        val results = mutableListOf<Boolean>()
        fixture.drain.whenDrained(results::add)
        fixture.drain.didDisconnect(old)
        fixture.drain.whenDrained(results::add)
        assertEquals(listOf(false, false), results)
    }
}
