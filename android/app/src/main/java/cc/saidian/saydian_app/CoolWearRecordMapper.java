package cc.saidian.saydian_app;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import ce.com.cenewbluesdk.entity.K6_sleepData;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_REAL_O2;
import ce.com.cenewbluesdk.entity.k6.K6_HeartStruct;
import ce.com.cenewbluesdk.entity.k6.K6_MixSportType;
import ce.com.cenewbluesdk.entity.k6.K6_Mix_sport_Struct;
import ce.com.cenewbluesdk.entity.k6.K6_Sport;
import ce.com.cenewbluesdk.entity.k6.K6_TempStruct;
import ce.com.cenewbluesdk.entity.k6.k6_RRI_HRV_DATA;

/** Pure mapping and validation for CoolWear values returned by the vendor SDK. */
public final class CoolWearRecordMapper {
    private static final long EARLIEST_SUPPORTED_MS = 1_420_070_400_000L; // 2015-01-01 UTC
    private static final long FUTURE_TOLERANCE_MS = 86_400_000L;

    private CoolWearRecordMapper() { }

    public static long historyTimestamp(long raw) {
        if (raw <= 0) return 0;
        long milliseconds;
        try {
            milliseconds = raw < 100_000_000_000L ? Math.multiplyExact(raw, 1_000L) : raw;
        } catch (ArithmeticException ignored) {
            return 0;
        }
        long now = System.currentTimeMillis();
        return milliseconds >= EARLIEST_SUPPORTED_MS
                        && milliseconds <= now + FUTURE_TOLERANCE_MS
                ? milliseconds
                : 0;
    }

    public static long currentTimestamp(long raw) {
        long milliseconds = historyTimestamp(raw);
        return milliseconds != 0 && Math.abs(System.currentTimeMillis() - milliseconds) <= 600_000L
                ? milliseconds
                : 0;
    }

    public static List<Map<String, Object>> activityRecords(
            String deviceId,
            String firmwareVersion,
            List<K6_Sport> values) {
        List<Map<String, Object>> records = new ArrayList<>();
        if (values == null) return records;
        for (K6_Sport value : values) {
            if (value == null) continue;
            long time = historyTimestamp(value.getStarTime());
            if (time == 0) continue;
            addSingleValue(records, deviceId, firmwareVersion, "steps", time,
                    value.getWalkSteps(), "步");
            if (value.getDistance() > 0) {
                addSingleValue(records, deviceId, firmwareVersion, "distance", time,
                        value.getDistance() / 1_000.0, "km");
            }
            addSingleValue(records, deviceId, firmwareVersion, "calories", time,
                    value.getCalories(), "kcal");
        }
        return records;
    }

    public static List<Map<String, Object>> sleepRecords(
            String deviceId,
            String firmwareVersion,
            K6_sleepData container) {
        if (container == null) return new ArrayList<>();
        List<K6_sleepData> sessions = container.getK6SleepData();
        if (sessions == null || sessions.isEmpty()) sessions = Collections.singletonList(container);
        List<Map<String, Object>> records = new ArrayList<>();
        for (K6_sleepData value : sessions) {
            if (value == null || value.getSleepTime() <= 0) continue;
            long time = historyTimestamp(value.getEndTime());
            if (time == 0) time = historyTimestamp(value.getSleepDay());
            if (time == 0) time = historyTimestamp(value.getStartTime());
            if (time == 0) continue;
            Map<String, Object> measured = new LinkedHashMap<>();
            measured.put("value", value.getSleepTime() / 60.0);
            if (value.getDeepTime() > 0) measured.put("deepHours", value.getDeepTime() / 60.0);
            if (value.getLightTime() > 0) measured.put("lightHours", value.getLightTime() / 60.0);
            if (value.getMovementTime() > 0) {
                measured.put("movementMinutes", value.getMovementTime());
            }
            if (value.getRevivetimes() > 0) measured.put("wakeCount", value.getRevivetimes());
            records.add(healthRecord(deviceId, firmwareVersion, "sleep", time, measured,
                    "h", "watch_history", "device_reported"));
        }
        return records;
    }

    public static List<Map<String, Object>> heartRecords(
            String deviceId,
            String firmwareVersion,
            List<K6_HeartStruct> values) {
        List<Map<String, Object>> records = new ArrayList<>();
        if (values == null) return records;
        for (K6_HeartStruct value : values) {
            if (value == null) continue;
            long time = historyTimestamp(value.getTime());
            int bpm = value.getHeartNums();
            if (time != 0 && bpm >= 20 && bpm <= 300) {
                addSingleValue(records, deviceId, firmwareVersion, "heart_rate", time, bpm, "bpm");
            }
        }
        return records;
    }

    public static List<Map<String, Object>> oxygenRecords(
            String deviceId,
            String firmwareVersion,
            List<K6_DATA_TYPE_REAL_O2> values) {
        List<Map<String, Object>> records = new ArrayList<>();
        if (values == null) return records;
        for (K6_DATA_TYPE_REAL_O2 value : values) {
            if (value == null || value.isEnd()) continue;
            long time = historyTimestamp(value.getTime());
            int percent = value.getValue();
            if (time != 0 && percent >= 2 && percent <= 100) {
                addSingleValue(records, deviceId, firmwareVersion, "blood_oxygen", time,
                        percent, "%");
            }
        }
        return records;
    }

    public static List<Map<String, Object>> hrvRecords(
            String deviceId,
            String firmwareVersion,
            List<k6_RRI_HRV_DATA> values) {
        List<Map<String, Object>> records = new ArrayList<>();
        if (values == null) return records;
        for (k6_RRI_HRV_DATA value : values) {
            if (value == null) continue;
            long time = historyTimestamp(value.getTime());
            int sdnn = value.getSdnn();
            if (time == 0 || sdnn <= 0 || sdnn > 1_000) continue;
            Map<String, Object> measured = new LinkedHashMap<>();
            measured.put("value", sdnn);
            measured.put("sdnn", sdnn);
            if (value.getRmssd() > 0) measured.put("rmssd", value.getRmssd());
            if (value.getRri() > 0) measured.put("rri", value.getRri());
            if (value.getPnn() > 0) measured.put("pnn", value.getPnn());
            if (value.getHr_bpm() > 0) measured.put("heartRate", value.getHr_bpm());
            if (value.getValid_count() > 0) measured.put("validCount", value.getValid_count());
            if (value.getRejected_count() > 0) {
                measured.put("rejectedCount", value.getRejected_count());
            }
            measured.put("sdkQuality", value.getQuality());
            records.add(healthRecord(deviceId, firmwareVersion, "hrv", time, measured,
                    "ms", "watch_history", "device_reported"));
        }
        return records;
    }

    public static List<Map<String, Object>> temperatureRecords(
            String deviceId,
            String firmwareVersion,
            List<K6_TempStruct> values) {
        List<Map<String, Object>> records = new ArrayList<>();
        if (values == null) return records;
        for (K6_TempStruct value : values) {
            if (value == null) continue;
            long time = historyTimestamp(value.getTime());
            float temperature = value.getTempValue();
            if (time != 0 && Float.isFinite(temperature)
                    && temperature >= 20.0f && temperature <= 45.0f) {
                addSingleValue(records, deviceId, firmwareVersion, "body_temperature", time,
                        temperature, "℃");
            }
        }
        return records;
    }

    public static List<Map<String, Object>> sportRecords(
            String deviceId,
            List<K6_Mix_sport_Struct> values) {
        List<Map<String, Object>> records = new ArrayList<>();
        if (values == null) return records;
        for (K6_Mix_sport_Struct value : values) {
            if (value == null) continue;
            String mode = sportMode(value.getSport_type());
            long startedAt = historyTimestamp(value.getStartTime());
            if (mode == null || startedAt == 0) continue;
            int duration = Math.max(0, value.getTotalTime());
            long endedAt = historyTimestamp(value.getEndTime());
            if (duration == 0 && endedAt >= startedAt) {
                duration = (int) Math.min(Integer.MAX_VALUE, (endedAt - startedAt) / 1_000L);
            }
            String key = deviceId + "|sport|" + mode + '|' + startedAt;
            Map<String, Object> record = new HashMap<>();
            record.put("id", "cw-" + UUID.nameUUIDFromBytes(
                    key.getBytes(StandardCharsets.UTF_8)));
            record.put("mode", mode);
            record.put("startedAt", Instant.ofEpochMilli(startedAt).toString());
            record.put("durationSeconds", duration);
            record.put("distanceKm", Math.max(0, value.getDistance()) / 1_000.0);
            record.put("calories", Math.max(0, value.getCalories()));
            record.put("steps", Math.max(0, value.getStep()));
            record.put("heartRate", Math.max(0, value.getAvgHr()));
            record.put("minimumHeartRate", 0);
            record.put("maximumHeartRate", Math.max(0, value.getMaxHr()));
            record.put("routePoints", new ArrayList<>());
            records.add(record);
        }
        return records;
    }

    public static String sportMode(int type) {
        switch (type) {
            case K6_MixSportType.MIX_SPORT_RUNNING_MACHINE:
            case K6_MixSportType.MIX_SPORT_TREADMILLS:
                return "indoor_running";
            case K6_MixSportType.MIX_SPORT_RUN:
            case K6_MixSportType.MIX_SPORT_OUTDOOR_RUNNING:
            case K6_MixSportType.MIX_SPORT_MARATHON:
                return "running";
            case K6_MixSportType.MIX_SPORT_WALK:
            case K6_MixSportType.MIX_SPORT_WALKINGMACHINE:
            case K6_MixSportType.MIX_SPORT_LNDOOR_WALKING:
                return "walking";
            case K6_MixSportType.MIX_SPORT_CYCLING:
            case K6_MixSportType.MIX_SPORT_MOUNTAIN_BIKING:
            case K6_MixSportType.MIX_SPORT_MOUNTAIN_BIKING_1:
                return "cycling";
            case K6_MixSportType.MIX_SPORT_CYCLING_INDOOR:
                return "indoor_cycling";
            case K6_MixSportType.MIX_SPORT_BASKETBALL:
                return "basketball";
            case K6_MixSportType.MIX_SPORT_FOOTBALL:
                return "football";
            case K6_MixSportType.MIX_SPORT_BADMINTON:
                return "badminton";
            case K6_MixSportType.MIX_SPORT_SWIM:
            case K6_MixSportType.MIX_SPORT_OPENWATER:
            case K6_MixSportType.MIX_SPORT_OPEN_SWIM:
                return "swimming";
            case K6_MixSportType.MIX_SPORT_SKIP:
                return "jump_rope";
            case K6_MixSportType.MIX_SPORT_YOGA:
                return "yoga";
            case K6_MixSportType.MIX_SPORT_ON_FOOT:
            case K6_MixSportType.MIX_SPORT_CROSSCOUNTRYRACE:
                return "hiking";
            case K6_MixSportType.MIX_SPORT_CLIMBING:
            case K6_MixSportType.MIX_SPORT_ROCKCLIMBING:
            case K6_MixSportType.MIX_SPORT_CLIMB_STAIRS:
                return "mountaineering";
            default:
                return null;
        }
    }

    public static Integer sportType(String mode) {
        if ("running".equals(mode)) return K6_MixSportType.MIX_SPORT_RUN;
        if ("indoor_running".equals(mode)) return K6_MixSportType.MIX_SPORT_RUNNING_MACHINE;
        if ("walking".equals(mode)) return K6_MixSportType.MIX_SPORT_WALK;
        if ("cycling".equals(mode)) return K6_MixSportType.MIX_SPORT_CYCLING;
        if ("indoor_cycling".equals(mode)) return K6_MixSportType.MIX_SPORT_CYCLING_INDOOR;
        if ("basketball".equals(mode)) return K6_MixSportType.MIX_SPORT_BASKETBALL;
        if ("football".equals(mode)) return K6_MixSportType.MIX_SPORT_FOOTBALL;
        if ("badminton".equals(mode)) return K6_MixSportType.MIX_SPORT_BADMINTON;
        if ("swimming".equals(mode)) return K6_MixSportType.MIX_SPORT_SWIM;
        if ("jump_rope".equals(mode)) return K6_MixSportType.MIX_SPORT_SKIP;
        if ("yoga".equals(mode)) return K6_MixSportType.MIX_SPORT_YOGA;
        if ("hiking".equals(mode)) return K6_MixSportType.MIX_SPORT_ON_FOOT;
        if ("mountaineering".equals(mode)) return K6_MixSportType.MIX_SPORT_CLIMBING;
        return null;
    }

    public static Map<String, Object> healthRecord(
            String deviceId,
            String firmwareVersion,
            String metric,
            long time,
            Map<String, Object> values,
            String unit,
            String origin,
            String quality) {
        String scopedDeviceId = deviceId != null && deviceId.startsWith("coolwear:")
                ? deviceId
                : "coolwear:" + (deviceId == null ? "" : deviceId);
        String key = scopedDeviceId + '|' + metric + '|' + time + '|' + values;
        Map<String, Object> record = new HashMap<>();
        record.put("id", UUID.nameUUIDFromBytes(key.getBytes(StandardCharsets.UTF_8)).toString());
        record.put("type", metric);
        record.put("values", values);
        record.put("unit", unit);
        record.put("measuredAt", Instant.ofEpochMilli(time).toString());
        record.put("timezone", ZoneId.systemDefault().getRules()
                .getOffset(Instant.ofEpochMilli(time)).toString());
        record.put("deviceId", scopedDeviceId);
        record.put("firmwareVersion", firmwareVersion == null ? "" : firmwareVersion);
        record.put("quality", quality);
        record.put("source", "wearable");
        record.put("origin", origin);
        record.put("rawVersion", 1);
        record.put("sourceModel", "HR01");
        record.put("sourceVendor", "coolwear");
        record.put("sourceDeviceCategory", "ring");
        record.put("sourceApp", "say-ring");
        return record;
    }

    private static void addSingleValue(
            List<Map<String, Object>> records,
            String deviceId,
            String firmwareVersion,
            String metric,
            long time,
            Number value,
            String unit) {
        if (value == null || !Double.isFinite(value.doubleValue()) || value.doubleValue() <= 0) return;
        Map<String, Object> measured = new LinkedHashMap<>();
        measured.put("value", value);
        records.add(healthRecord(deviceId, firmwareVersion, metric, time, measured,
                unit, "watch_history", "device_reported"));
    }
}
