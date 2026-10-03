package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CoolWearNamePolicyTest {
    @Test
    fun `legacy HR01 and exact HR05 names remain compatible`() {
        assertEquals("HR01", CoolWearRingBridge.supportedModel("HR01"))
        assertEquals("HR01", CoolWearRingBridge.supportedModel("hr01-1"))
        assertEquals("HR05", CoolWearRingBridge.supportedModel(" hr05 "))
        assertNull(CoolWearRingBridge.supportedModel("HR050"))
        assertNull(CoolWearRingBridge.supportedModel("HR05-unknown"))
        assertNull(CoolWearRingBridge.supportedModel("R22_C493"))
        assertNull(CoolWearRingBridge.supportedModel(null))
    }

    @Test
    fun `confirmed LuckRing models and technical suffixes are accepted`() {
        val names = mapOf(
            "hr01" to "HR01", "hr05" to "HR05", "k80" to "K80",
            "R7" to "R7", "R7y" to "R7Y", " r7Pro " to "R7Pro",
            "HR05_4F5F" to "HR05", "HR05-1" to "HR05",
            "K80_ABCD" to "K80", "R7_1234" to "R7",
            "R7Y_A1B2" to "R7Y", "R7Pro_001122AABBCC" to "R7Pro",
            "R7Pro_00:11:22:AA:BB:CC" to "R7Pro",
        )
        names.forEach { (name, model) ->
            assertEquals(name, model, CoolWearRingBridge.supportedModel(name))
        }
    }

    @Test
    fun `neighboring models and other vendors do not route to CoolWear`() {
        listOf("K800", "K80Pro", "R70", "R7Y2", "R7Pro2", "R7Protein",
            "R7_", "R7_ABCZ", "R7Pro_123456789ABCDE", "R21_4F5F", "Q_R7",
            "YC_R7", "HR050", "HR05-unknown", "Ring", "").forEach {
            assertNull(it, CoolWearRingBridge.supportedModel(it))
        }
    }
}
