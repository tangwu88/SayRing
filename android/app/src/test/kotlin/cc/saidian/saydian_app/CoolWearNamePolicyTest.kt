package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CoolWearNamePolicyTest {
    @Test
    fun `bond lookup is exact and never routes another family or arbitrary identifier`() {
        val id = "AA:BB:CC:DD:EE:01"
        assertEquals(true, CoolWearRingBridge.isExactBondedTarget(id, id.lowercase(), "SD-RING-R7 Ultra"))
        assertEquals(false, CoolWearRingBridge.isExactBondedTarget(id, "AA:BB:CC:DD:EE:02", "R7 Ultra"))
        assertEquals(false, CoolWearRingBridge.isExactBondedTarget(id, id, "R22_C493"))
        assertEquals(false, CoolWearRingBridge.isExactBondedTarget(id, id, null))
        assertEquals(false, CoolWearRingBridge.isExactBondedTarget("arbitrary", "arbitrary", "R7 Ultra"))
    }
    @Test
    fun `vibrating models preserve explicit routes and reject ambiguous names`() {
        for (name in listOf("R8 pro", "r8PRO", "SD-RING-r8_pro-123", "R8-Pro")) {
            assertEquals(name, "R8Pro", CoolWearRingBridge.supportedModel(name))
            assertEquals(name, false, QRingBridge.isQRingName(name))
        }
        assertEquals("R7Ultra", CoolWearRingBridge.supportedModel("R7 Ultra"))
        assertEquals("R7Pro", CoolWearRingBridge.supportedModel("r7 pro"))
        for (name in listOf("R8Pro-R21", "R8Pro-R8", "R8Protein", "R12-R8Pro", "R7C-R8 Pro")) {
            assertNull(name, CoolWearRingBridge.supportedModel(name))
        }
    }
    @Test
    fun `only confirmed LuckRing family names are accepted`() {
        assertEquals("HR01", CoolWearRingBridge.supportedModel("HR01"))
        assertEquals("HR01", CoolWearRingBridge.supportedModel("hr01-1"))
        assertEquals("HR05", CoolWearRingBridge.supportedModel(" hr05 "))
        assertEquals("R7Ultra", CoolWearRingBridge.supportedModel(" sd-ring-r7ultra "))
        assertEquals("HR05", CoolWearRingBridge.supportedModel("HR050"))
        assertEquals("HR05", CoolWearRingBridge.supportedModel("HR05-unknown"))
        assertEquals("R7Ultra", CoolWearRingBridge.supportedModel("SD-RING-R7ULTRA-UNKNOWN"))
        assertEquals("R7", CoolWearRingBridge.supportedModel("Q_device-r7-123"))
        assertEquals("K80", CoolWearRingBridge.supportedModel("V-device-k80-123"))
        assertEquals("HR01", CoolWearRingBridge.supportedModel("device-hr01-123"))
        assertNull(CoolWearRingBridge.supportedModel("R22_C493"))
        assertNull(CoolWearRingBridge.supportedModel(null))
    }

    @Test
    fun `QRing model markers never enter the LuckRing SDK`() {
        for (name in listOf("R7C", "R7C_HR01", "SD-RING-R7C", "YC-R7C", "R12", "R18", "R20", "R21-K80", "R99", "R8", "device-R21", "YC-R22", "R7-R8", "K80-R21", "HR05-R22")) {
            assertNull(name, CoolWearRingBridge.supportedModel(name))
        }
        assertNull(CoolWearRingBridge.supportedModel("unknown"))
    }
}
