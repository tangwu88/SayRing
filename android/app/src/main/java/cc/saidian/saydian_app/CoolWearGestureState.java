package cc.saidian.saydian_app;

/** Connection-local confirmation of vendor gesture replies, never an optimistic setting. */
final class CoolWearGestureState {
    static final long TIMEOUT_MS = 8_000L;
    static final long PAIRING_TIMEOUT_MS = 45_000L;
    private volatile long generation;
    private Integer pendingMode;
    private Integer confirmedMode;
    private long deadline;
    private boolean requiresReconnect;
    private boolean awaitingBond;
    private boolean modeAcknowledged;
    private Integer sentMode;
    private boolean repliesTrusted = true;

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
    Integer sentMode() { return sentMode; }

    void reset() {
        generation++;
        pendingMode = null;
        confirmedMode = null;
        requiresReconnect = false;
        awaitingBond = false;
        modeAcknowledged = false;
        sentMode = null;
        repliesTrusted = true;
    }

    boolean begin(Object mode, long now) {
        return begin(mode, now, false);
    }

    boolean begin(Object mode, long now, boolean needsBond) {
        Integer valid = validMode(mode);
        if (valid == null || pending() || requiresReconnect) return false;
        pendingMode = valid;
        confirmedMode = null;
        sentMode = null;
        awaitingBond = valid > 0 && needsBond;
        modeAcknowledged = false;
        deadline = now + (awaitingBond ? PAIRING_TIMEOUT_MS : TIMEOUT_MS);
        return true;
    }

    boolean confirm(int mode, long callbackGeneration, long now) {
        if (!repliesTrusted || callbackGeneration != generation || pendingMode == null ||
                pendingMode != mode || now >= deadline) return false;
        modeAcknowledged = true;
        return completeIfReady();
    }

    boolean bonded(long callbackGeneration, long now) {
        if (callbackGeneration != generation || pendingMode == null || now >= deadline) return false;
        awaitingBond = false;
        return completeIfReady();
    }

    private boolean completeIfReady() {
        if (awaitingBond || !modeAcknowledged) return false;
        confirmedMode = pendingMode;
        sentMode = pendingMode;
        pendingMode = null;
        return true;
    }

    /** SDK send returned, not evidence that the ring applied the setting. */
    void dispatched() {
        if (pendingMode != null) sentMode = pendingMode;
    }

    /** Missing OEM status is unknown, not a transport/pairing failure.
     * After this point unsolicited late statuses cannot confirm any retry in
     * this connection: the OEM protocol has no per-request identifier.
     */
    boolean settleUnconfirmed() {
        if (pendingMode == null || awaitingBond || !pendingMode.equals(sentMode)) return false;
        pendingMode = null;
        confirmedMode = null;
        modeAcknowledged = false;
        repliesTrusted = false;
        return true;
    }

    void fail() {
        pendingMode = null;
        confirmedMode = null;
        awaitingBond = false;
        modeAcknowledged = false;
        sentMode = null;
        // The OEM reply has no request ID. A timed-out reply cannot safely be
        // attributed to a retry in this connection, even for the same mode.
        requiresReconnect = true;
    }
}
