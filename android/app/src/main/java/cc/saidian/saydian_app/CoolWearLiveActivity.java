package cc.saidian.saydian_app;

import java.util.Arrays;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.time.Instant;
import java.time.ZoneId;
import ce.com.cenewbluesdk.entity.k6.K6_Sport;

/** Actual SDK rows from a current connection's CRC-verified activity DATA. */
final class CoolWearLiveActivity {
    static boolean needsRead(long now, long lastPacket) {
        return lastPacket <= 0 || now - lastPacket >= 15_000L;
    }
    static boolean usesExerciseHeart(String model) {
        return "R7Ultra".equals(model) || "R7Pro".equals(model);
    }
    static boolean persistAsHistory(int type, boolean workoutActive) {
        return type == 5 || (type == 4 && !workoutActive);
    }

    static List<K6_Sport> rows(byte[] bytes) {
        List<K6_Sport> values = new ArrayList<>();
        if (bytes == null || bytes.length < 3) return values;
        int count = bytes[2] & 255, size = K6_Sport.getItemSize();
        int remaining = (bytes[0] & 255) | ((bytes[1] & 255) << 8);
        if (count == 0 || remaining < count || remaining > 16384 || bytes.length != 3 + count * size) return values;
        for (int index = 0; index < count; index++)
            values.add(new K6_Sport(Arrays.copyOfRange(bytes, 3 + index * size, 3 + (index + 1) * size)));
        return values;
    }

    static Map<String, Object> accept(byte[] bytes, SportSessionCounters counters, long now) {
        K6_Sport latest = null;
        for (K6_Sport value : rows(bytes)) {
            long time = ((long) value.getStarTime()) * 1000;
            if (time <= 0 || time > now + 60_000 || !Instant.ofEpochMilli(time).atZone(ZoneId.systemDefault()).toLocalDate()
                    .equals(Instant.ofEpochMilli(now).atZone(ZoneId.systemDefault()).toLocalDate())) continue;
            if (latest == null || value.getStarTime() > latest.getStarTime()) latest = value;
        }
        // Type4 is a current-day cumulative snapshot. Its timestamp advances
        // with every read; it is not the start of a new activity bucket.
        long day = Instant.ofEpochMilli(now).atZone(ZoneId.systemDefault()).toLocalDate().toEpochDay();
        return latest == null ? null : counters.accept(day, latest.getWalkSteps(), latest.getDistance());
    }
}
