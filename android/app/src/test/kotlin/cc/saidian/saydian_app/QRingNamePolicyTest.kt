package cc.saidian.saydian_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class QRingNamePolicyTest {
    @Test
    fun `user confirmed R2 family and vendor prefixes are accepted`() {
        assertTrue(QRingBridge.isQRingName("Q_Ring"))
        assertTrue(QRingBridge.isQRingName("O_Ring"))
        assertTrue(QRingBridge.isQRingName(" r22_c493 "))
        assertTrue(QRingBridge.isQRingName("R21"))
        assertTrue(QRingBridge.isQRingName(" r210 "))
        assertTrue(QRingBridge.isQRingName("R22_"))
        assertTrue(QRingBridge.isQRingName("R22_C493_extra"))
        assertTrue(QRingBridge.isQRingName("R22_Z493"))
        assertTrue(QRingBridge.isQRingName("R22"))
        assertFalse(QRingBridge.isQRingName("HR01"))
        assertFalse(QRingBridge.isQRingName("HR05"))
        assertTrue(QRingBridge.isQRingName("R1"))
        assertTrue(QRingBridge.isQRingName("R3"))
        assertFalse(QRingBridge.isQRingName(null))
        assertFalse(QRingBridge.isQRingName("Q Ring"))
    }

    @Test
    fun `confirmed QRing markers match inside names and reject LuckRing conflicts`() {
        for (name in listOf("R8 Pro", "r8PRO", "SD-RING-r8_pro-123", "R8-Pro", "R8_Pro", "R8Pro-R21", "R8Pro-R8", "R8", " device-r8-123 ", "YC-R21-123", "V-R22-123", "SD-RING-R7C", "YC-R7C", "R12", "R18", "R20", " r7c ", "R7C_K80", "R2-HR05", "R21-K80", "R22-HR05", "R99", "Ring")) {
            assertTrue(name, QRingBridge.isQRingName(name))
        }
        for (name in listOf("R8 Pro-HR05", "R8Pro-K80", "R8Pro-R7", "Q_R7", "O_K80", "Q_HR01", "R8-R7", "YC-R21-K80", "Q_R22-HR05")) {
            assertFalse(name, QRingBridge.isQRingName(name))
        }
    }

    @Test
    fun `advertisement name finds R21 without a cached Bluetooth device name`() {
        assertEquals("R21", QRingBridge.resolveScanName(null, " R21 "))
        assertEquals("R22_C493", QRingBridge.resolveScanName("HR05", "R22_C493"))
        assertEquals("R21", QRingBridge.resolveScanName("R21", null))
        assertNull(QRingBridge.resolveScanName(null, "HR05"))
        assertNull(QRingBridge.resolveScanName("HR05", null))
    }

    @Test
    fun `bonded fallback requires exact saved address and QRing name`() {
        assertTrue(QRingBridge.isExactBondedQRing("AA:BB", "aa:bb", "R22_C493"))
        assertTrue(QRingBridge.isExactBondedQRing("AA:BB", "aa:bb", "device-r8-123"))
        assertFalse(QRingBridge.isExactBondedQRing("AA:BB", "AA:BB", "R8-R7"))
        assertFalse(QRingBridge.isExactBondedQRing("AA:BB", "AA:CC", "R22_C493"))
        assertFalse(QRingBridge.isExactBondedQRing("AA:BB", "AA:BB", "V Ring"))
        assertFalse(QRingBridge.isExactBondedQRing(null, "AA:BB", "R22_C493"))
    }

    @Test
    fun `remembered recovery accepts only a complete bluetooth address`() {
        assertTrue(QRingBridge.isValidBluetoothAddress("AA:BB:CC:DD:EE:FF"))
        assertTrue(QRingBridge.isValidBluetoothAddress("aa:bb:cc:dd:ee:ff"))
        assertFalse(QRingBridge.isValidBluetoothAddress("AA:BB"))
        assertFalse(QRingBridge.isValidBluetoothAddress("R22_C493"))
        assertFalse(QRingBridge.isValidBluetoothAddress(null))
    }
}
