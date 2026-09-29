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
import java.util.Map;
import java.util.UUID;

final class QRingRecordMapper {
    private QRingRecordMapper() { }

    static long dayStart(int dayIndex) {
        return LocalDate.now().minusDays(Math.max(0, dayIndex))
                .atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli();
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
            long measuredAt = dayStart(dayIndex) + Math.max(0, item.getTimeIndex()) * 30L * 60_000L;
            if (item.getWalkSteps() > 0) {
                addSingle(result, deviceId, model, firmware, "steps", measuredAt,
                        item.getWalkSteps(), "步", "watch_history");
            }
            if (item.getDistance() > 0) {
                addSingle(result, deviceId, model, firmware, "distance", measuredAt,
                        item.getDistance() / 1000.0, "km", "watch_history");
            }
            if (item.getCalorie() > 0) {
                addSingle(result, deviceId, model, firmware, "calories", measuredAt,
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
        List<Map<String, Object>> result = new ArrayList<>();
        if (value == null || value.getTotalSleepDuration() <= 0) return result;
        Map<String, Object> measured = new LinkedHashMap<>();
        measured.put("value", value.getTotalSleepDuration() / 60.0);
        if (value.getDeepSleepDuration() > 0) measured.put("deepHours", value.getDeepSleepDuration() / 60.0);
        if (value.getShallowSleepDuration() > 0) measured.put("lightHours", value.getShallowSleepDuration() / 60.0);
        if (value.getRapidDuration() > 0) measured.put("remHours", value.getRapidDuration() / 60.0);
        if (value.getAwakeDuration() > 0) measured.put("awakeMinutes", value.getAwakeDuration());
        if (value.getWakingCount() > 0) measured.put("wakeCount", value.getWakingCount());
        if (value.getSleepScore() > 0) measured.put("score", value.getSleepScore());
        long measuredAt = sdkTimestamp(value.getWakeTime(), dayStart(dayIndex) + 12L * 60L * 60_000L);
        result.add(healthRecord(deviceId, model, firmware, "sleep", measuredAt,
                measured, "h", "watch_history", "device_reported"));
        return result;
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
