package cc.saidian.saydian_app

import ce.com.cenewbluesdk.CEBC
import org.junit.Assert.*
import org.junit.Test

class CoolWearProtocolEvidenceTest {
    @Test fun `capability number agrees with actual SDK and only confirmed shape exposes extension bits`() {
        assertEquals(22, CEBC.K6.DATA_TYPE_FUNCTION_CONTROL)
        val bytes = ByteArray(8)
        bytes[3] = 6
        val evidence = CoolWearProtocolEvidence.describe(22, 8, 1, bytes)
        assertTrue(evidence.contains("extendedTouch=true,gestureMusic=true"))
        assertArrayEquals(byteArrayOf(0, 0, 0, 6, 0, 0, 0, 0), bytes)
        bytes[3] = 0
        assertTrue(CoolWearProtocolEvidence.describe(22, 8, 1, bytes)
            .contains("extendedTouch=false,gestureMusic=false"))
    }

    @Test fun `truncated batched absent and mismatched capabilities remain unconfirmed`() {
        for (value in listOf(
            CoolWearProtocolEvidence.describe(22, 8, 1, null),
            CoolWearProtocolEvidence.describe(22, 8, 1, ByteArray(3)),
            CoolWearProtocolEvidence.describe(22, 8, 2, ByteArray(16)),
            CoolWearProtocolEvidence.describe(22, 7, 1, ByteArray(8)),
        )) {
            assertTrue(value.contains("extensions=unconfirmed"))
            assertFalse(value.contains("extendedTouch="))
        }
    }

    @Test fun `HRV envelopes reveal no sample values timestamp or payload bytes`() {
        for (type in listOf(60, 61, 62)) {
            val first = CoolWearProtocolEvidence.describe(type, 16, 1, ByteArray(16) { 7 })
            val other = CoolWearProtocolEvidence.describe(type, 16, 1, ByteArray(16) { 99 })
            assertEquals(first, other)
            assertEquals("protocol envelope; type=$type,bytes=16,itemLength=16,itemCount=1", first)
        }
    }

    @Test fun `unrelated packets cannot enter diagnostics`() {
        for (type in listOf(-1, 0, 5, 6, 8, 40, 42, 44, 45, 47, 63, 255)) {
            assertNull(CoolWearProtocolEvidence.describe(type, 8, 1, ByteArray(8)))
        }
    }
}
