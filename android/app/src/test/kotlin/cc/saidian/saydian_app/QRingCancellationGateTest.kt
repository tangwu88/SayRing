package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Test

class QRingCancellationGateTest {
    @Test
    fun `only current exact target with confirmed SDK teardown can release barrier`() {
        // Include stale probes, another target, callback already handled,
        // connecting, connected, and a remaining GATT; none may release it.
        for (bits in 0 until 64) {
            val flags = (0 until 6).map { bits and (1 shl it) != 0 }
            val expected = flags[0] && flags[1] && flags[2] &&
                !flags[3] && !flags[4] && !flags[5]
            assertEquals("state combination $bits", expected,
                QRingCancellationGate.canFinish(
                    flags[0], flags[1], flags[2], flags[3], flags[4], flags[5]))
        }
    }
}
