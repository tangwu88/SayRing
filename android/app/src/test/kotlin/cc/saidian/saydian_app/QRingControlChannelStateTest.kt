package cc.saidian.saydian_app
import org.junit.Assert.*
import org.junit.Test

class QRingControlChannelStateTest {
    @Test fun `HID uncertainty cannot disable acknowledged photo UI protocol`() {
        val state=QRingControlChannelState()
        val hid=QRingControlChannelState.Channel.HID
        val photo=QRingControlChannelState.Channel.PHOTO_UI
        assertFalse(state.blocked(hid,7));assertFalse(state.blocked(photo,7))
        state.block(hid,7)
        assertTrue(state.blocked(hid,7));assertFalse(state.blocked(photo,7))
        // Camera start/stop must not clear the existing HID safety fence.
        assertFalse(state.blocked(photo,7));assertTrue(state.blocked(hid,7))
        state.block(photo,7)
        assertTrue(state.blocked(photo,7));assertTrue(state.blocked(hid,7))
    }
    @Test fun `photo uncertainty stays fenced while independent HID can still read`() {
        val state=QRingControlChannelState()
        state.block(QRingControlChannelState.Channel.PHOTO_UI,3)
        assertFalse(state.blocked(QRingControlChannelState.Channel.HID,3))
        assertTrue(state.blocked(QRingControlChannelState.Channel.PHOTO_UI,3))
        for (channel in QRingControlChannelState.Channel.values()) assertFalse(state.blocked(channel,4))
        assertTrue(state.blocked(QRingControlChannelState.Channel.PHOTO_UI,3))
    }
}
