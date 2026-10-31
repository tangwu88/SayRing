package cc.saidian.saydian_app;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** App modes and QRing firmware modes are distinct from LuckRing's protocol. */
public final class QRingGesturePolicy {
    private static final int[] RAW = {0, 2, 1, 4, 5, 6};
    private QRingGesturePolicy() { }
    public static int rawMode(int app) {
        return app >= 0 && app < RAW.length ? RAW[app] : -1;
    }
    public static int appMode(int raw) {
        for (int mode = 0; mode < RAW.length; mode++) if (RAW[mode] == raw) return mode;
        return -1;
    }
    public static int writeStrength(boolean touch, int current, Object selected) {
        if (touch) return 0;
        if (selected != null && !(selected instanceof Integer)) return -1;
        int value = selected == null ? current : (Integer) selected;
        return value >= 1 && value <= 10 ? value : -1;
    }
    public static boolean validExpectedMode(int mode, Object expected, boolean stopping) {
        return stopping ? mode == 0 : expected instanceof Integer && (Integer) expected >= 0 && (Integer) expected <= 9;
    }
    public static Map<String, Object> snapshot(Map<String, Object> raw, List<Integer> modes) {
        if (raw == null) return null;
        Map<String, Object> value = new HashMap<>(raw);
        value.put("rawMode", raw.get("mode"));
        value.put("enabled", !Integer.valueOf(0).equals(raw.get("mode")));
        value.put("confirmedMode", appMode((Integer) raw.get("mode")));
        value.put("availableModes", modes);
        value.put("readbackVerified", true);
        return value;
    }
}
