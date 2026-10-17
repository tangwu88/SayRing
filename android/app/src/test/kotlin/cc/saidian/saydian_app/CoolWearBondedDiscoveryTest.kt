package cc.saidian.saydian_app

import org.junit.Assert.*
import org.junit.Test

class CoolWearBondedDiscoveryTest {
    private val address = "AA:BB:CC:DD:EE:FF"

    @Test fun `real bond offers a candidate without inventing capabilities or signal`() {
        val value = CoolWearBondedDiscovery.candidate(address, " HR05 ", true)!!
        assertEquals(address, value["id"])
        assertEquals("HR05", value["name"])
        assertEquals(true, value["bonded"])
        assertFalse(value.containsKey("rssi"))
        assertFalse(value.containsKey("capabilities"))
        assertFalse(value.containsKey("vendorId"))
    }

    @Test fun `name alone and invalid identifiers cannot become candidates`() {
        assertNull(CoolWearBondedDiscovery.candidate(address, "HR05", false))
        for (id in listOf(null, "", "HR05", "AA:BB:CC:DD:EE", "AA:BB:CC:DD:EE:GG")) {
            assertNull(CoolWearBondedDiscovery.candidate(id, "HR05", true))
        }
    }

    @Test fun `QRing and conflicting families do not leak into CoolWear`() {
        for (name in listOf(null, "", "R22_C493", "R21", "R7C", "R12", "Q_Test", "unknown")) {
            assertNull(CoolWearBondedDiscovery.candidate(address, name, true))
        }
    }

    @Test fun `supported bonded families retain the existing routing policy`() {
        for (name in listOf("HR01", "HR05", "K80", "SD-RING-R7 Ultra")) {
            val value = CoolWearBondedDiscovery.candidate(address, name, true)!!
            assertEquals(RingNamePolicy.luckRingModel(name), value["model"])
            assertEquals(name, value["name"])
        }
    }
}
