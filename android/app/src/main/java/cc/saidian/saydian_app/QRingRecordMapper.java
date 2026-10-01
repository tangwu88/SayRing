package cc.saidian.saydian_app;

import com.oudmon.ble.base.bean.SleepDisplay;
import com.oudmon.ble.base.communication.bigData.BloodOxygenEntity;
import com.oudmon.ble.base.communication.bigData.bean.IntervalTemperatureEntity;
import com.oudmon.ble.base.communication.entity.BleStepDetails;
import com.oudmon.ble.base.communication.rsp.HRVRsp;
import com.oudmon.ble.base.communication.rsp.PressureRsp;
import com.oudmon.ble.base.communication.rsp.ReadHeartRateRsp;
import com.oudmon.ble.base.communication.sport.SportPlusEntity;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Comparator;
import java.util.HashSet;
import java.util.Set;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

final class QRingRecordMapper {
    private QRingRecordMapper() { }

    static long dayStart(int dayIndex) {
        return LocalDate.now().minusDays(Math.max(0, dayIndex))
                .atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli();
    }

    static final class SleepRequestDay {
        final long dayStart;
        final String sdkDate;
        final String timezone;

        private SleepRequestDay(long dayStart, String sdkDate, String timezone) {
            this.dayStart = dayStart;
            this.sdkDate = sdkDate;
            this.timezone = timezone;
        }
    }

    static SleepRequestDay sleepRequestDay(int dayIndex) {
        ZoneId zone = ZoneId.systemDefault();
        return sleepRequestDay(LocalDate.now(zone).minusDays(Math.max(0, dayIndex)), zone);
    }

    static SleepRequestDay sleepRequestDay(LocalDate date, ZoneId zone) {
        long start = date.atStartOfDay(zone).toInstant().toEpochMilli();
        int offset = zone.getRules().getOffset(Instant.ofEpochMilli(start)).getTotalSeconds();
        String timezone = String.format(Locale.ROOT, "%s%02d:%02d", offset < 0 ? "-" : "+",
                Math.abs(offset) / 3600, Math.abs(offset) / 60 % 60);
        return new SleepRequestDay(start, date.toString(), timezone);
    }

    static long sdkTimestamp(long raw, long fallback) {
        if (raw <= 0) return fallback;
        if (raw < 10_000_000_000L) return raw * 1000L;
        return raw;
    }

    static List<Map<String, Object>> stepRecords(
            String deviceId, String model, String firmware, int dayIndex,
            List<BleStepDetails> values) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (values == null) return result;
        for (BleStepDetails item : values) {
            if (item == null) continue;
            // The SDK's 0..95 index is a 15-minute slot, not a 30-minute slot.
            int slot = item.getTimeIndex();
            if (slot < 0 || slot > 95) continue;
            long measuredAt = dayStart(dayIndex) + slot * 15L * 60_000L;
            if (item.getWalkSteps() > 0) {
                addStepSlot(result, deviceId, model, firmware, "steps", measuredAt,
                        item.getWalkSteps(), "步", "watch_history");
            }
            if (item.getDistance() > 0) {
                addStepSlot(result, deviceId, model, firmware, "distance", measuredAt,
                        item.getDistance() / 1000.0, "km", "watch_history");
            }
            if (item.getCalorie() > 0) {
                addStepSlot(result, deviceId, model, firmware, "calories", measuredAt,
                        item.getCalorie() / 1000.0, "kcal", "watch_history");
            }
        }
        return result;
    }

    static List<Map<String, Object>> heartRecords(
            String deviceId, String model, String firmware, int dayIndex,
            ReadHeartRateRsp value) {
        long base = value == null ? dayStart(dayIndex)
                : sdkTimestamp(value.getmUtcTime(), dayStart(dayIndex));
        int interval = value == null ? 5 : Math.max(1, value.getInterval());
        return integerSeries(deviceId, model, firmware, "heart_rate", "bpm",
                base, interval, value == null ? null : value.getArray(), 20, 300);
    }

    static List<Map<String, Object>> oxygenRecords(
            String deviceId, String model, String firmware, int dayIndex,
            BloodOxygenEntity value) {
        long base = value == null ? dayStart(dayIndex)
                : sdkTimestamp(value.getUnix_time(), dayStart(dayIndex));
        int interval = value == null ? 5 : Math.max(1, value.getInterval());
        return integerSeries(deviceId, model, firmware, "blood_oxygen", "%",
                base, interval, value == null ? null : value.getArray(), 50, 100);
    }

    static List<Map<String, Object>> hrvRecords(
            String deviceId, String model, String firmware, int dayIndex, HRVRsp value) {
        int interval = value == null ? 5 : Math.max(1, value.getRange());
        long base = dayStart(dayIndex) + (value == null ? 0 : Math.max(0, value.getStartInterval())) * 60_000L;
        return integerSeries(deviceId, model, firmware, "hrv", "ms", base, interval,
                value == null ? null : value.getArray(), 1, 1000);
    }

    static List<Map<String, Object>> stressRecords(
            String deviceId, String model, String firmware, int dayIndex, PressureRsp value) {
        int interval = value == null ? 5 : Math.max(1, value.getRange());
        long base = dayStart(dayIndex) + (value == null ? 0 : Math.max(0, value.getOffset())) * 60_000L;
        return integerSeries(deviceId, model, firmware, "stress", "", base, interval,
                value == null ? null : value.getArray(), 1, 100);
    }

    static List<Map<String, Object>> temperatureRecords(
            String deviceId, String model, String firmware, int dayIndex,
            IntervalTemperatureEntity value) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (value == null || value.getArray() == null) return result;
        long base = dayStart(dayIndex);
        int interval = Math.max(1, value.getInterval());
        for (int index = 0; index < value.getArray().size(); index++) {
            Float amount = value.getArray().get(index);
            if (amount == null || !Float.isFinite(amount) || amount < 20f || amount > 45f) continue;
            addSingle(result, deviceId, model, firmware, "body_temperature",
                    base + index * interval * 60_000L, amount, "℃", "watch_history");
        }
        return result;
    }

    static List<Map<String, Object>> sleepRecords(
            String deviceId, String model, String firmware, int dayIndex, SleepDisplay value) {
        return sleepRecords(deviceId, model, firmware, sleepRequestDay(dayIndex), value);
    }

    static List<Map<String, Object>> sleepRecords(
            String deviceId, String model, String firmware, SleepRequestDay requestDay, SleepDisplay value) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (value == null) return result;
        Map<String, Object> timeline = sleepTimeline(deviceId, requestDay, value);
        if (!sleepTimelineIsComplete(timeline)) return result;
        double[] seconds = new double[5];
        int segmentCount = 0;
        for (Map<String, Object> session : sleepSessions(timeline)) {
            for (Map<String, Object> segment : sleepSegments(session)) {
                String stage = (String) segment.get("stage");
                int type = "deep".equals(stage) ? 1 : "light".equals(stage) ? 2
                        : "awake".equals(stage) ? 3 : "rem".equals(stage) ? 4 : 0;
                long elapsed = Instant.parse((String) segment.get("endAt")).getEpochSecond()
                        - Instant.parse((String) segment.get("startAt")).getEpochSecond();
                if (type > 0) seconds[type] += elapsed;
                segmentCount++;
            }
        }
        if (segmentCount == 0) {
            // The SDK's totalSleepDuration includes awake time in its new
            // protocol. Preserve it in rawSummary and count only actual stages.
            seconds[1] = value.getDeepSleepDuration();
            seconds[2] = value.getShallowSleepDuration();
            seconds[3] = value.getAwakeDuration();
            seconds[4] = value.getRapidDuration();
        }
        double asleep = seconds[1] + seconds[2] + seconds[4];
        if (asleep <= 0 || asleep + seconds[3] > 86400) return result;
        Map<String, Object> measured = new LinkedHashMap<>();
        measured.put("value", asleep / 3600.0);
        measured.put("deepHours", seconds[1] / 3600.0);
        measured.put("lightHours", seconds[2] / 3600.0);
        measured.put("remHours", seconds[4] / 3600.0);
        measured.put("awakeMinutes", seconds[3] / 60.0);
        if (value.getWakingCount() > 0) measured.put("wakeCount", value.getWakingCount());
        if (value.getSleepScore() > 0 && value.getSleepScore() <= 100)
            measured.put("score", value.getSleepScore());
        if (value.getSleepEfficiency() > 0 && value.getSleepEfficiency() <= 100)
            measured.put("efficiency", value.getSleepEfficiency());
        long measuredAt = sdkTimestamp(value.getWakeTime(), requestDay.dayStart + 12L * 60L * 60_000L);
        Map<String, Object> record = healthRecord(deviceId, model, firmware,
                "sleep", measuredAt, measured, "h", "watch_history", "device_reported");
        record.put("rawVersion", 2);
        record.put("timezone", requestDay.timezone);
        record.put("sleepTimeline", timeline);
        result.add(record);
        return result;
    }

    static String sleepStage(int type) {
        switch (type) {
            case 1: return "deep";
            case 2: return "light";
            case 3: return "awake";
            case 4: return "rem";
            default: return "unknown";
        }
    }

    static Map<String, Object> sleepTimeline(String deviceId, int dayIndex, SleepDisplay value) {
        return sleepTimeline(deviceId, sleepRequestDay(dayIndex), value);
    }

    static Map<String, Object> sleepTimelineForSuccessfulRead(
            String deviceId, SleepRequestDay requestDay, SleepDisplay value) {
        // The SDK can complete a requested day with null when it returned no
        // packet for that day. Its onError callback is a separate read failure.
        return sleepTimeline(deviceId, requestDay, value == null ? new SleepDisplay() : value);
    }

    static Map<String, Object> sleepTimeline(String deviceId, SleepRequestDay requestDay, SleepDisplay value) {
        long now = Instant.now().getEpochSecond();
        String scoped = deviceId.startsWith("qring:") ? deviceId : "qring:" + deviceId;
        Map<String, Object> timeline = new LinkedHashMap<>();
        timeline.put("deviceId", scoped);
        timeline.put("sdkDate", requestDay.sdkDate);
        timeline.put("timezone", requestDay.timezone);
        timeline.put("readAt", Instant.ofEpochSecond(now).toString());
        timeline.put("revision", 0);
        List<Map<String, Object>> sessions = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        boolean[] malformed = {value == null};
        if (value != null) {
            addSleepSession(sessions, "night", value.getList(), now, seen, malformed);
            addSleepSession(sessions, "nap", value.getNapList(), now, seen, malformed);
        }
        List<long[]> ranges = new ArrayList<>();
        long coveredSeconds = 0;
        for (Map<String, Object> session : sessions) {
            for (Map<String, Object> segment : sleepSegments(session)) {
                long begin = Instant.parse((String) segment.get("startAt")).getEpochSecond();
                long end = Instant.parse((String) segment.get("endAt")).getEpochSecond();
                ranges.add(new long[] {begin, end});
                coveredSeconds += end - begin;
            }
        }
        ranges.sort(Comparator.comparingLong(range -> range[0]));
        for (int index = 1; index < ranges.size(); index++) {
            if (ranges.get(index)[0] < ranges.get(index - 1)[1]) malformed[0] = true;
        }
        if (coveredSeconds > 86400) malformed[0] = true;
        timeline.put("sessions", sessions);
        Map<String, Object> raw = new LinkedHashMap<>();
        if (value != null) {
            raw.put("totalSeconds", value.getTotalSleepDuration());
            raw.put("deepSeconds", value.getDeepSleepDuration());
            raw.put("lightSeconds", value.getShallowSleepDuration());
            raw.put("awakeSeconds", value.getAwakeDuration());
            raw.put("remSeconds", value.getRapidDuration());
            raw.put("napSeconds", value.getNapDuration());
            raw.put("sleepTimeSeconds", value.getSleepTime());
            raw.put("wakeTimeSeconds", value.getWakeTime());
            if (value.getWakingCount() > 0) raw.put("wakeCount", value.getWakingCount());
            if (value.getTotalSleepDuration() > 0) {
                int score = value.getSleepScore(), efficiency = value.getSleepEfficiency();
                if (score > 0 && score <= 100) raw.put("score", score);
                if (efficiency > 0 && efficiency <= 100) raw.put("efficiency", efficiency);
            }
            long[] durations = {value.getTotalSleepDuration(), value.getDeepSleepDuration(),
                    value.getShallowSleepDuration(), value.getAwakeDuration(),
                    value.getRapidDuration(), value.getNapDuration()};
            for (long duration : durations) {
                if (duration < 0 || duration > 86400) malformed[0] = true;
            }
            long stageSeconds = (long) value.getDeepSleepDuration() + value.getShallowSleepDuration()
                    + value.getAwakeDuration() + value.getRapidDuration();
            if (stageSeconds > 86400) malformed[0] = true;
        }
        timeline.put("rawSummary", raw);
        timeline.put("invalidSegments", malformed[0]);
        return timeline;
    }

    private static void addSleepSession(List<Map<String, Object>> sessions, String kind,
            List<SleepDisplay.SleepDataBean> source, long now, Set<String> seen, boolean[] malformed) {
        if (source == null || source.isEmpty()) return;
        List<Map<String, Object>> raw = new ArrayList<>();
        List<SleepDisplay.SleepDataBean> valid = new ArrayList<>();
        for (SleepDisplay.SleepDataBean item : source) {
            Map<String, Object> original = new LinkedHashMap<>();
            if (item == null) {
                original.put("missing", true);
                malformed[0] = true;
            } else {
                original.put("startSeconds", item.getSleepStart());
                original.put("endSeconds", item.getSleepEnd());
                original.put("type", item.getType());
                long duration = item.getSleepEnd() - item.getSleepStart();
                if (item.getSleepStart() < 946684800L || duration <= 0 || duration > 86400
                        || item.getSleepEnd() > now + 300) {
                    malformed[0] = true;
                } else if (seen.add(item.getSleepStart() + "|" + item.getSleepEnd() + "|" + item.getType())) {
                    valid.add(new SleepDisplay.SleepDataBean(item.getSleepStart(), item.getSleepEnd(), item.getType()));
                }
            }
            raw.add(original);
        }
        Set<Long> boundaries = new HashSet<>();
        for (SleepDisplay.SleepDataBean item : valid) {
            boundaries.add(item.getSleepStart());
            boundaries.add(item.getSleepEnd());
        }
        List<Long> ordered = new ArrayList<>(boundaries);
        ordered.sort(Long::compareTo);
        List<SleepDisplay.SleepDataBean> normalized = new ArrayList<>();
        for (int index = 0; index + 1 < ordered.size(); index++) {
            long begin = ordered.get(index), end = ordered.get(index + 1);
            Set<Integer> types = new HashSet<>();
            for (SleepDisplay.SleepDataBean item : valid) {
                if (item.getSleepStart() <= begin && item.getSleepEnd() >= end) types.add(item.getType());
            }
            if (types.isEmpty()) continue;
            int type = types.size() == 1 ? types.iterator().next() : 0;
            SleepDisplay.SleepDataBean previous = normalized.isEmpty() ? null : normalized.get(normalized.size() - 1);
            if (previous != null && begin == previous.getSleepEnd() && previous.getType() == type) previous.setSleepEnd(end);
            else normalized.add(new SleepDisplay.SleepDataBean(begin, end, type));
        }
        List<Map<String, Object>> segments = new ArrayList<>();
        for (SleepDisplay.SleepDataBean item : normalized) {
            Map<String, Object> segment = new LinkedHashMap<>();
            segment.put("startAt", Instant.ofEpochSecond(item.getSleepStart()).toString());
            segment.put("endAt", Instant.ofEpochSecond(item.getSleepEnd()).toString());
            segment.put("rawStage", item.getType());
            segment.put("stage", sleepStage(item.getType()));
            segments.add(segment);
        }
        Map<String, Object> session = new LinkedHashMap<>();
        session.put("kind", kind);
        session.put("segments", segments);
        session.put("rawSegments", raw);
        sessions.add(session);
    }

    static boolean sleepTimelineIsComplete(Map<String, Object> timeline) {
        return !Boolean.TRUE.equals(timeline.get("invalidSegments"));
    }

    static boolean sleepTimelineHasData(Map<String, Object> timeline) {
        if (!sleepSessions(timeline).isEmpty()) return true;
        Map<?, ?> raw = (Map<?, ?>) timeline.get("rawSummary");
        Object total = raw.get("totalSeconds"), nap = raw.get("napSeconds");
        return total instanceof Number && ((Number) total).doubleValue() > 0
                || nap instanceof Number && ((Number) nap).doubleValue() > 0;
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> sleepSessions(Map<String, Object> timeline) {
        return (List<Map<String, Object>>) timeline.get("sessions");
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> sleepSegments(Map<String, Object> session) {
        return (List<Map<String, Object>>) session.get("segments");
    }

    private static void addStepSlot(
            List<Map<String, Object>> result, String deviceId, String model,
            String firmware, String metric, long measuredAt,
            Number value, String unit, String origin) {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("value", value);
        Map<String, Object> record = healthRecord(deviceId, model, firmware,
                metric, measuredAt, values, unit, origin, "device_reported");
        record.put("rawVersion", 2);
        result.add(record);
    }

    static List<Map<String, Object>> sportRecords(
            String deviceId, List<SportPlusEntity> values) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (values == null) return result;
        for (SportPlusEntity item : values) {
            if (item == null) continue;
            String mode = sportMode(item.mSportType);
            if (mode == null) continue;
            long startedAt = sdkTimestamp(item.mStartTime, 0);
            if (startedAt <= 0) continue;
            Map<String, Object> record = new HashMap<>();
            String key = deviceId + "|sport|" + item.mSportType + '|' + startedAt;
            record.put("id", UUID.nameUUIDFromBytes(key.getBytes(StandardCharsets.UTF_8)).toString());
            record.put("mode", mode);
            record.put("startedAt", Instant.ofEpochMilli(startedAt).toString());
            record.put("durationSeconds", Math.max(0, item.mDuration));
            record.put("distanceMeters", Math.max(0, item.mDistance));
            record.put("calories", Math.max(0f, item.mCalories));
            record.put("steps", Math.max(0, item.steps));
            record.put("heartRate", Math.max(0, item.mRateAvg));
            record.put("minimumHeartRate", Math.max(0, item.mRateMin));
            record.put("maximumHeartRate", Math.max(0, item.mRateMax));
            result.add(record);
        }
        return result;
    }

    static String sportMode(int type) {
        switch (type) {
            case 4: return "walking";
            case 5: return "jump_rope";
            case 6: return "swimming";
            case 7: return "running";
            case 8: return "hiking";
            case 9: return "cycling";
            case 20: return "mountaineering";
            case 21: return "badminton";
            case 22: return "yoga";
            case 24: return "indoor_cycling";
            case 31: return "basketball";
            case 32: return "football";
            case 40: return "indoor_running";
            case 50: return "cycling";
            case 51: return "indoor_cycling";
            case 55:
            case 56: return "swimming";
            case 60: return "hiking";
            default: return null;
        }
    }

    static Integer sportType(String mode) {
        if (mode == null) return null;
        switch (mode) {
            case "walking": return 4;
            case "jump_rope": return 5;
            case "swimming": return 6;
            case "running": return 7;
            case "hiking": return 8;
            case "cycling": return 9;
            case "mountaineering": return 20;
            case "badminton": return 21;
            case "yoga": return 22;
            case "indoor_cycling": return 24;
            case "basketball": return 31;
            case "football": return 32;
            case "indoor_running": return 40;
            default: return null;
        }
    }

    static Map<String, Object> manualRecord(
            String deviceId, String model, String firmware, String metric,
            Map<String, Object> values, String unit) {
        return healthRecord(deviceId, model, firmware, metric,
                System.currentTimeMillis(), values, unit, "app_measurement", "device_reported");
    }

    private static List<Map<String, Object>> integerSeries(
            String deviceId, String model, String firmware, String metric, String unit,
            long base, int intervalMinutes, List<Integer> values, int minimum, int maximum) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (values == null) return result;
        for (int index = 0; index < values.size(); index++) {
            Integer amount = values.get(index);
            if (amount == null || amount < minimum || amount > maximum) continue;
            addSingle(result, deviceId, model, firmware, metric,
                    base + index * Math.max(1, intervalMinutes) * 60_000L,
                    amount, unit, "watch_history");
        }
        return result;
    }

    private static void addSingle(
            List<Map<String, Object>> records, String deviceId, String model,
            String firmware, String metric, long time, Number value, String unit,
            String origin) {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("value", value);
        records.add(healthRecord(deviceId, model, firmware, metric, time,
                values, unit, origin, "device_reported"));
    }

    static Map<String, Object> healthRecord(
            String deviceId, String model, String firmware, String metric, long time,
            Map<String, Object> values, String unit, String origin, String quality) {
        String nativeId = deviceId == null ? "" : deviceId;
        String scopedId = nativeId.startsWith("qring:") ? nativeId : "qring:" + nativeId;
        String key = scopedId + '|' + metric + '|' + time + '|' + values;
        Map<String, Object> record = new HashMap<>();
        record.put("id", UUID.nameUUIDFromBytes(key.getBytes(StandardCharsets.UTF_8)).toString());
        record.put("type", metric);
        record.put("values", values);
        record.put("unit", unit);
        record.put("measuredAt", Instant.ofEpochMilli(time).toString());
        record.put("timezone", ZoneId.systemDefault().getRules()
                .getOffset(Instant.ofEpochMilli(time)).toString());
        record.put("deviceId", scopedId);
        record.put("firmwareVersion", firmware == null ? "" : firmware);
        record.put("quality", quality);
        record.put("source", "wearable");
        record.put("origin", origin);
        record.put("rawVersion", 1);
        record.put("sourceModel", model == null ? "QRing" : model);
        record.put("sourceVendor", "qring");
        record.put("sourceDeviceCategory", "ring");
        record.put("sourceApp", "say-ring");
        return record;
    }
}
