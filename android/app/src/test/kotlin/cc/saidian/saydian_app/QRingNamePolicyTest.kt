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
        assertFalse(QRingBridge.isQRingName("R1"))
        assertFalse(QRingBridge.isQRingName("R3"))
        assertFalse(QRingBridge.isQRingName(null))
        assertFalse(QRingBridge.isQRingName("Q Ring"))
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
