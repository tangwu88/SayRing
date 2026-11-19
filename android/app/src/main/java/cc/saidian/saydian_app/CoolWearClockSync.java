package cc.saidian.saydian_app;

/** One optional clock submission using only this connection's returned format. */
final class CoolWearClockSync {
    static final long MAX_WAIT_MS = 300_000L;

    static final class Request {
        final long epoch, owner, expiresAt;
        final String target;
        final int format, mdFormat;

        Request(long epoch, long owner, String target, int format, int mdFormat, long now) {
            this.epoch = epoch;
            this.owner = owner;
            this.target = target;
            this.format = format;
            this.mdFormat = mdFormat;
            expiresAt = now + MAX_WAIT_MS;
        }

        boolean matches(long epoch, long owner, String target) {
            return this.epoch == epoch && this.owner == owner && this.target.equals(target);
        }
    }

    private Request pending;
    private long attemptedEpoch = -1L;

    Request offer(long epoch, long owner, String target, int format, int mdFormat, long now) {
        if (target == null || target.isEmpty() || attemptedEpoch == epoch
                || (format != 0 && format != 1) || (mdFormat != 0 && mdFormat != 1)) return null;
        // Duplicate packets must not extend the bounded wait or replace the
        // first genuine format while another device operation is in flight.
        if (pending != null && pending.matches(epoch, owner, target)) return pending;
        pending = new Request(epoch, owner, target, format, mdFormat, now);
        return pending;
    }

    Request pending() { return pending; }

    boolean claim(Request request) {
        if (request == null || request != pending) return false;
        pending = null;
        // This means one send attempt, never a device ACK. An exception from a
        // void vendor API is ambiguous and must not replay a physical write.
        attemptedEpoch = request.epoch;
        return true;
    }

    void cancel() { pending = null; }
}
