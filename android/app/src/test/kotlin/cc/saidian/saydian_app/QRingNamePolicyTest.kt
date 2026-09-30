package cc.saidian.saydian_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QRingNamePolicyTest {
    @Test
    fun `only observed QRing model shapes are accepted`() {
        assertTrue(QRingBridge.isQRingName("Q_Ring"))
        assertTrue(QRingBridge.isQRingName("O_Ring"))
        assertTrue(QRingBridge.isQRingName(" r22_c493 "))
        assertFalse(QRingBridge.isQRingName("R22_"))
        assertFalse(QRingBridge.isQRingName("R22_C493_extra"))
        assertFalse(QRingBridge.isQRingName("R22_Z493"))
        assertFalse(QRingBridge.isQRingName("R22"))
        assertFalse(QRingBridge.isQRingName("Q Ring"))
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
