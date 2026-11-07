package cc.saidian.saydian_app;

/** One bounded SDK recovery owner before the controller may take over. */
final class CoolWearRecoveryLease {
    static final long DURATION_MS = 15_000L;
    private String target;
    private long generation, deadline;

    boolean begin(String id, long owner, long now) {
        if (matches(id, owner)) return false; // Duplicate drops cannot extend it.
        target = id;
        generation = owner;
        deadline = now + DURATION_MS;
        return true;
    }

    boolean matches(String id, long owner) {
        return target != null && id != null && target.equalsIgnoreCase(id)
                && generation == owner;
    }

    long remaining(long now) { return Math.max(0, deadline - now); }
    void clear() { target = null; deadline = 0; }
}
