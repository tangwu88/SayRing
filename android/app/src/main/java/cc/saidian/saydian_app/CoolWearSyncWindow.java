package cc.saidian.saydian_app;

/** Monotonic transport deadline; packets extend the idle window, never success. */
final class CoolWearSyncWindow {
    static final long IDLE_MS = 30_000L;
    static final long MAX_MS = 90_000L;
    private final long started;
    private long lastPacket;

    CoolWearSyncWindow(long now) { started = lastPacket = now; }

    void received(long now) {
        if (remaining(now) > 0) lastPacket = now;
    }

    long remaining(long now) {
        return Math.max(0, Math.min(MAX_MS - (now - started), IDLE_MS - (now - lastPacket)));
    }
}
