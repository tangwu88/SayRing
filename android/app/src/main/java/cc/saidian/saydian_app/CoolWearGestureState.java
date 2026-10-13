package cc.saidian.saydian_app;

/** Connection-local confirmation of vendor gesture replies, never an optimistic setting. */
final class CoolWearGestureState {
    static final long TIMEOUT_MS = 8_000L;
    private volatile long generation;
    private Integer pendingMode;
    private Integer confirmedMode;
    private long deadline;
    private boolean requiresReconnect;

    static boolean supported(boolean connected, boolean infoReady, boolean gestureFlag) {
        return connected && infoReady && gestureFlag;
    }

    static Integer validMode(Object value) {
        if (!(value instanceof Integer || value instanceof Long)) return null;
        long mode = ((Number) value).longValue();
        return mode >= 0 && mode <= 5 ? (int) mode : null;
    }

    long generation() { return generation; }
    boolean pending() { return pendingMode != null; }
    boolean requiresReconnect() { return requiresReconnect; }
    Integer confirmedMode() { return confirmedMode; }

    void reset() {
        generation++;
        pendingMode = null;
        confirmedMode = null;
        requiresReconnect = false;
    }

    boolean begin(Object mode, long now) {
        Integer valid = validMode(mode);
        if (valid == null || pending() || requiresReconnect) return false;
        pendingMode = valid;
        confirmedMode = null;
        deadline = now + TIMEOUT_MS;
        return true;
    }

    boolean confirm(int mode, long callbackGeneration, long now) {
        if (callbackGeneration != generation || pendingMode == null ||
                pendingMode != mode || now >= deadline) return false;
        confirmedMode = mode;
        pendingMode = null;
        return true;
    }

    void fail() {
        pendingMode = null;
        confirmedMode = null;
        // The OEM reply has no request ID. A timed-out reply cannot safely be
        // attributed to a retry in this connection, even for the same mode.
        requiresReconnect = true;
    }
}
