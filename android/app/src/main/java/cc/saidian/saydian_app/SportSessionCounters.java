package cc.saidian.saydian_app;

import java.util.LinkedHashMap;
import java.util.Map;

/** Session deltas of genuine cumulative device counters, never daily totals. */
final class SportSessionCounters {
    private boolean based;
    private long bucket;
    private int lastSteps, lastDistance;
    private long steps, distance;

    void reset() { based = false; steps = distance = 0; }
    void rebase() { based = false; }

    Map<String, Object> acceptReadDay(long requestedDay, long receivedDay, int stepTotal, int distanceTotal) {
        return requestedDay == receivedDay ? accept(requestedDay, stepTotal, distanceTotal) : null;
    }

    Map<String, Object> accept(long key, int stepTotal, int distanceTotal) {
        if (key <= 0 || stepTotal < 0 || distanceTotal < 0) return null;
        if (!based) {
            bucket = key; lastSteps = stepTotal; lastDistance = distanceTotal; based = true;
        } else {
            if (key < bucket || (key == bucket &&
                    (stepTotal < lastSteps || distanceTotal < lastDistance))) return null;
            if (key > bucket) { lastSteps = lastDistance = 0; bucket = key; }
            steps += stepTotal - lastSteps;
            distance += distanceTotal - lastDistance;
            lastSteps = stepTotal; lastDistance = distanceTotal;
        }
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("steps", steps); values.put("distanceMeters", distance);
        return values;
    }
}
