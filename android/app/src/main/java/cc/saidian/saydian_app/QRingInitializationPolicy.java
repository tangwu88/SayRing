package cc.saidian.saydian_app;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.Map;

/** QRing's reset has no response parser. Verified setup is not a reset ACK. */
final class QRingInitializationPolicy {
    static final int SETUP_VERIFIED_NO_ACK = 13; // requested | settings verified | NO_ACK

    private QRingInitializationPolicy() { }

    static boolean complete(int phase, long notBefore) {
        return phase == 0 || phase == 7
                || (phase == SETUP_VERIFIED_NO_ACK && notBefore > 0 && notBefore < Long.MAX_VALUE);
    }

    static boolean canInitialize(int phase, boolean resetConnection) {
        return !resetConnection && (phase == 1 || phase == 3);
    }

    static int completedPhase(int phase) {
        if (phase != 1 && phase != 3)
            throw new IllegalArgumentException("Unrecognized QRing initialization phase");
        return phase == 3 ? 7 : SETUP_VERIFIED_NO_ACK;
    }

    static int eligibleDays(long notBefore, long now, ZoneId zone, int requested) {
        if (notBefore == 0) return requested;
        long days = ChronoUnit.DAYS.between(Instant.ofEpochMilli(notBefore).atZone(zone).toLocalDate(),
                Instant.ofEpochMilli(now).atZone(zone).toLocalDate()) + 1;
        return (int) Math.max(1, Math.min(requested, days));
    }

    static boolean healthRecordAllowed(Map<String, Object> record, long notBefore) {
        if (notBefore == 0) return true;
        if (record == null || notBefore < 0 || notBefore == Long.MAX_VALUE) return false;
        Object timeline = record.get("sleepTimeline");
        if (timeline instanceof Map) return sleepTimelineAllowed((Map<?, ?>) timeline, notBefore);
        return atOrAfter(record.get("measuredAt"), notBefore);
    }

    static boolean sportRecordAllowed(Map<String, Object> record, long notBefore) {
        return notBefore == 0 || (record != null && atOrAfter(record.get("startedAt"), notBefore));
    }

    static boolean sleepTimelineAllowed(Map<?, ?> timeline, long notBefore) {
        if (notBefore == 0) return true;
        if (timeline == null || notBefore < 0 || notBefore == Long.MAX_VALUE) return false;
        if (Boolean.TRUE.equals(timeline.get("invalidSegments"))) return false;
        if (timeline.containsKey("rawSummary")) {
            // A day summary has no per-value timestamps. The confirmation day
            // can mix pre-ownership values even when its retained segments are new.
            try {
                long dayStart = LocalDate.parse((String) timeline.get("sdkDate"))
                        .atStartOfDay(ZoneId.of((String) timeline.get("timezone"))).toInstant().toEpochMilli();
                if (dayStart < notBefore) return false;
            } catch (RuntimeException invalid) { return false; }
        }
        Object sessions = timeline.get("sessions");
        if (!(sessions instanceof Iterable)) return false;
        boolean found = false;
        for (Object session : (Iterable<?>) sessions) {
            if (!(session instanceof Map)) return false;
            Object raw = ((Map<?, ?>) session).get("rawSegments");
            if (raw instanceof Iterable) {
                for (Object item : (Iterable<?>) raw) {
                    if (!(item instanceof Map)) return false;
                    Object start = ((Map<?, ?>) item).get("startSeconds");
                    if (!(start instanceof Number)) return false;
                    double seconds = ((Number) start).doubleValue();
                    if (!Double.isFinite(seconds) || seconds <= 0 || seconds < notBefore / 1000.0) return false;
                }
            }
            Object segments = ((Map<?, ?>) session).get("segments");
            if (!(segments instanceof Iterable)) return false;
            for (Object segment : (Iterable<?>) segments) {
                if (!(segment instanceof Map)
                        || !atOrAfter(((Map<?, ?>) segment).get("startAt"), notBefore)) return false;
                found = true;
            }
        }
        return found; // Never import an old summary under a new read timestamp.
    }

    private static boolean atOrAfter(Object value, long notBefore) {
        if (!(value instanceof String) || notBefore <= 0 || notBefore == Long.MAX_VALUE) return false;
        try { return Instant.parse((String) value).toEpochMilli() >= notBefore; }
        catch (RuntimeException invalid) { return false; }
    }
}
