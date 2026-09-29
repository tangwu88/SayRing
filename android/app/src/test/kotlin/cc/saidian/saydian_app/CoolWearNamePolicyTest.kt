package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CoolWearNamePolicyTest {
    @Test
    fun `only observed HR05 and existing HR01 names are accepted`() {
        assertEquals("HR01", CoolWearRingBridge.supportedModel("HR01"))
        assertEquals("HR01", CoolWearRingBridge.supportedModel("hr01-1"))
        assertEquals("HR05", CoolWearRingBridge.supportedModel(" hr05 "))
        assertNull(CoolWearRingBridge.supportedModel("HR050"))
        assertNull(CoolWearRingBridge.supportedModel("HR05-unknown"))
        assertNull(CoolWearRingBridge.supportedModel("R22_C493"))
        assertNull(CoolWearRingBridge.supportedModel(null))
    }
}
