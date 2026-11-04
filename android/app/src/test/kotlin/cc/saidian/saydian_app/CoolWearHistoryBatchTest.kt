package cc.saidian.saydian_app

import org.junit.Assert.*
import org.junit.Test

class CoolWearHistoryBatchTest {
    private fun packet(remaining: Int, vararg rows: Int): ByteArray =
        byteArrayOf(remaining.toByte(), (remaining ushr 8).toByte(), rows.size.toByte(), *rows.map { it.toByte() }.toByteArray())

    @Test fun onlyExplicitEmptyPacketProvesNoData() {
        val batch = CoolWearHistoryBatch()
        assertFalse(batch.complete())
        assertEquals("not_received", batch.status())
        batch.accept(packet(0))
        assertTrue(batch.complete())
        assertEquals("no_data", batch.status())
    }
    @Test fun duplicatesAndMissingMiddleNeverComplete() {
        val batch = CoolWearHistoryBatch()
        batch.accept(packet(4, 1, 2))
        batch.accept(packet(4, 1, 2))
        batch.accept(packet(0, 5, 6))
        assertFalse(batch.complete())
        batch.accept(packet(2, 3, 4))
        assertTrue(batch.complete())
        assertEquals("complete", batch.status())
    }
    @Test fun invalidLengthAndConflictingRowsStayIncomplete() {
        for (payload in listOf(byteArrayOf(0), byteArrayOf(0, 0, 1), byteArrayOf(0, 0, 0, 99), byteArrayOf(0, 0, 2, 1, 2, 3))) {
            val batch = CoolWearHistoryBatch()
            batch.accept(payload)
            batch.accept(packet(0))
            assertFalse(batch.complete())
        }
        val changing = CoolWearHistoryBatch()
        changing.accept(packet(0, 1))
        changing.accept(packet(0, 2))
        assertFalse(changing.complete())
    }
    @Test fun emptyQueryResponseIsNotProofAndDoesNotDiscardLaterRealUpload() {
        val batch = CoolWearHistoryBatch()
        batch.accept(byteArrayOf())
        assertFalse(batch.complete())
        batch.accept(packet(0, 1, 2))
        assertTrue(batch.complete())
    }
    @Test fun acknowledgementOrCurrentActivityCannotBeAnEmptyHistory() {
        val batch = CoolWearHistoryBatch()
        batch.accept(byteArrayOf(0))
        assertFalse(batch.complete())
    }
}
