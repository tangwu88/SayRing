package cc.saidian.saydian_app;

import java.util.HashMap;
import java.util.Map;

/** QRing ring control protocol, not the unrelated watch camera UI command. */
public final class QRingCameraPolicy {
    public static final int PHOTO_MODE = 5;
    private QRingCameraPolicy() { }

    public static boolean supported(boolean gesture, boolean gesturePhoto,
                                    boolean touch, boolean touchPhoto, boolean rt11) {
        return (gesture && gesturePhoto) || (touch && touchPhoto && !rt11);
    }

    public static Map<String, Object> snapshot(int mode, int strength,
                                              boolean touch, int duration) {
        // Touch responses do not contain strength; do not use a made-up value.
        if (mode < 0 || mode > 9 || (!touch && (strength < 1 || strength > 10))
                || (touch && (duration < 1 || duration > 10))) return null;
        Map<String, Object> value = new HashMap<>();
        value.put("mode", mode);
        value.put("enabled", mode == PHOTO_MODE);
        value.put("touch", touch);
        if (!touch) value.put("strength", strength);
        if (touch) value.put("duration", duration);
        return value;
    }
}
