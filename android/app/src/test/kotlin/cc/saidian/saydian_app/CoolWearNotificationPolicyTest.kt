package cc.saidian.saydian_app

import org.junit.Assert.*
import org.junit.Test

class CoolWearNotificationPolicyTest {
    @Test fun `known vibrating ring requires every real connection proof`() {
        for (model in listOf("R7Pro", "R7Ultra", "HR05")) {
            assertTrue(CoolWearNotificationPolicy.canRelay(model, true, true, true, true))
            for (missing in 0..3) {
                val proof = BooleanArray(4) { it != missing }
                assertFalse(CoolWearNotificationPolicy.canRelay(model, proof[0], proof[1], proof[2], proof[3]))
            }
        }
    }

    @Test fun `other models and the QRing R8 Pro cannot inherit relay`() {
        for (model in listOf(null, "R7", "HR01", "R8Pro", "R8 Pro", "R12", "R21")) {
            assertFalse(CoolWearNotificationPolicy.canRelay(model, true, true, true, true))
        }
    }
}
