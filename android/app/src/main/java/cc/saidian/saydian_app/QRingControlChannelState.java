package cc.saidian.saydian_app;

/** Photo UI (0x02) and HID settings (0x3b) use different vendor response slots. */
final class QRingControlChannelState {
    enum Channel { PHOTO_UI, HID }
    private int photoBlocked = -1;
    private int hidBlocked = -1;

    boolean blocked(Channel channel, int generation) {
        return generation == (channel == Channel.PHOTO_UI ? photoBlocked : hidBlocked);
    }

    void block(Channel channel, int generation) {
        if (channel == Channel.PHOTO_UI) photoBlocked = generation;
        else hidBlocked = generation;
    }
}
