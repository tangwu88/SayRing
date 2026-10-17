package cc.saidian.saydian_app;

import java.util.HashMap;
import java.util.Map;

/** Discovery candidates only: an OS bond never substitutes for the SDK handshake. */
final class CoolWearBondedDiscovery {
    static Map<String, Object> candidate(String id, String name, boolean bonded) {
        if (!bonded || id == null || !id.matches("(?i)([0-9a-f]{2}:){5}[0-9a-f]{2}")) {
            return null;
        }
        String model = RingNamePolicy.luckRingModel(name);
        if (model == null) return null;
        Map<String, Object> value = new HashMap<>();
        value.put("id", id);
        value.put("name", name.trim());
        value.put("model", model);
        value.put("hardwareAddress", id);
        value.put("bonded", true);
        // No advertisement was received, so RSSI/manufacturer data stay unknown.
        return value;
    }
}
