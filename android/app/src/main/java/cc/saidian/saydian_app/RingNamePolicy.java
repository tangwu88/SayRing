package cc.saidian.saydian_app;

import java.util.Locale;

/** Name routing selects a candidate SDK; capabilities still require its handshake. */
final class RingNamePolicy {
    private RingNamePolicy() { }

    private static String normalize(String name) {
        return name == null ? "" : name.trim().toUpperCase(Locale.ROOT);
    }

    private static boolean hasQRingMarker(String name) {
        return name.contains("R8") || name.contains("R21") || name.contains("R22");
    }

    private static boolean hasLuckRingMarker(String name) {
        return name.contains("R7") || name.contains("K80")
                || name.contains("HR01") || name.contains("HR05");
    }

    static boolean isQRingName(String name) {
        String normalized = normalize(name);
        if (hasLuckRingMarker(normalized)) return false;
        return hasQRingMarker(normalized) || normalized.startsWith("Q_")
                || normalized.startsWith("O_") || normalized.startsWith("R2");
    }

    static String luckRingModel(String name) {
        String normalized = normalize(name);
        if (hasQRingMarker(normalized)) return null;
        if (normalized.contains("HR01")) return "HR01";
        if (normalized.contains("HR05")) return "HR05";
        if (normalized.contains("R7ULTRA")) return "R7Ultra";
        if (normalized.contains("R7")) return "R7";
        if (normalized.contains("K80")) return "K80";
        return null;
    }
}
