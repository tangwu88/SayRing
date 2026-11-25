package cc.saidian.saydian_app;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Opt-in, one requested read window. Contains counts/enums only, never samples. */
final class CoolWearReadEvidence {
    private final java.util.Set<String> mappingObserved = new java.util.HashSet<>();
    private final Map<String, int[]> rows = new LinkedHashMap<>();
    private static String metric(int type) {
        switch (type) {
            case 5: return "steps"; case 6: return "sleep";
            case 8: return "heart_rate"; case 40: return "blood_oxygen";
            case 42: return "stress"; case 47: return "body_temperature";
            case 61: return "hrv"; default: return null;
        }
    }
    private static int add(int a, int b) { return (int) Math.min(1_000_000L, (long) a + Math.max(0, b)); }
    private int[] row(String metric) { return rows.computeIfAbsent(metric, key -> new int[6]); }
    void requested(int type) { String m = metric(type); if (m != null) { int[] r = row(m); r[0] = add(r[0], 1); } }
    void packet(int type, byte[] payload) {
        String m = metric(type);
        if (m == null || payload == null) return;
        int[] r = row(m); r[1] = add(r[1], 1);
        if (payload.length >= 3) r[2] = add(r[2], payload[2] & 255);
    }
    void mapped(String metric, int decoded, List<Map<String,Object>> records) {
        mappingObserved.add(metric);
        int count = 0;
        for (Map<String,Object> record : records) if (metric.equals(record.get("type"))) count++;
        int[] r = row(metric);
        r[3] = add(r[3], decoded); r[4] = add(r[4], count);
        r[5] = add(r[5], Math.max(0, decoded - count));
    }
    Map<String,Object> snapshot(Map<String,String> statuses, Map<String,Object> clock,
            Boolean heart, Boolean oxygen) {
        List<Map<String,Object>> metrics = new ArrayList<>();
        String[] keys = {"requests", "packets", "wireRows", "decodedRows", "mappedRecords", "filteredRecords"};
        for (Map.Entry<String,int[]> entry : rows.entrySet()) {
            Map<String,Object> item = new LinkedHashMap<>();
            item.put("metric", entry.getKey());
            item.put("mappingObserved", mappingObserved.contains(entry.getKey()));
            item.put("state", statuses.getOrDefault(entry.getKey(), "not_received"));
            for (int i = 0; i < keys.length; i++) item.put(keys[i], entry.getValue()[i]);
            metrics.add(item);
        }
        Map<String,Object> result = new LinkedHashMap<>();
        result.put("metrics", metrics); result.put("clock", clock);
        Map<String,Object> monitoring = new LinkedHashMap<>();
        if (heart != null) monitoring.put("heartRate", heart);
        if (oxygen != null) monitoring.put("bloodOxygen", oxygen);
        if (!monitoring.isEmpty()) result.put("monitoring", monitoring);
        return result;
    }
}
