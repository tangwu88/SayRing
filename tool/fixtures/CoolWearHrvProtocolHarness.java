package cc.saidian.saydian_app;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Runs production bridge methods against protocol-shaped synthetic samples. */
public final class CoolWearHrvProtocolHarness {
    private static final String TAG = "test";
    private String activeMeasurement;
    private boolean resultEmitted;
    private boolean linkConnected = true;
    private final String connectedId = "coolwear:test-only";
    private final String firmwareVersion = "test-only";
    private final Helper helper = new Helper();
    private final Main main = new Main();
    private final List<Map<String, Object>> emitted = new ArrayList<>();
    private final List<Map<String, Object>> collected = new ArrayList<>();
    // These stubs let the same test run against the previous production methods
    // and fail on the wrong result/command, rather than fail compilation.
    private static final long LEGACY_HRV_FALLBACK_MS = 8_000L;
    private Runnable hrvFallback;

    // PRODUCTION_METHODS

    private void collectHealth(List<Map<String, Object>> values) { collected.addAll(values); }
    private void emitMeasurement(String metric, long time, int value, String unit) {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("value", value);
        emitMeasurement(metric, time, values, unit);
    }
    private void emitMeasurement(String metric, long time, Map<String, Object> values, String unit) {
        Map<String, Object> event = new LinkedHashMap<>();
        event.put("metric", metric);
        event.put("unit", unit);
        event.put("values", values);
        event.put("time", time);
        emitted.add(event);
        resultEmitted = true;
    }

    public static void main(String[] args) {
        CoolWearHrvProtocolHarness h = new CoolWearHrvProtocolHarness();
        switch (args[0]) {
            case "legacy-hrv":
                h.activeMeasurement = "hrv";
                h.onStressCompatValues(Arrays.asList(null, new K6_HrvStruct(30)));
                require(h.emitted.isEmpty(), "type 45 was emitted as HRV milliseconds");
                require(h.collected.isEmpty(), "type 45 was collected during HRV");
                require(!h.resultEmitted, "legacy packet prematurely completed HRV");
                break;
            case "hrv-command":
                h.activeMeasurement = "hrv";
                h.setMeasurement("hrv", true);
                h.main.runDelayed();
                require(h.helper.commands.equals(List.of("rri:1")),
                        "HRV startup sent legacy/stress type 45: " + h.helper.commands);
                h.setMeasurement("hrv", false);
                h.main.runDelayed();
                require(h.helper.commands.equals(List.of("rri:1", "rri:0")),
                        "HRV stop touched legacy/stress type 45: " + h.helper.commands);
                break;
            case "rri-fields":
                h.activeMeasurement = "hrv";
                h.onHrvValues(List.of(new k6_RRI_HRV_DATA(0, 0, 0),
                        new k6_RRI_HRV_DATA(1001, 0, 0)));
                require(h.emitted.isEmpty(), "invalid SDNN was accepted");
                h.onHrvValues(List.of(new k6_RRI_HRV_DATA(42, 51, 803)));
                require(h.emitted.size() == 1, "new-protocol HRV was not emitted once");
                Map<String, Object> event = h.emitted.get(0);
                require(event.get("metric").equals("hrv") && event.get("unit").equals("ms"),
                        "new-protocol HRV metric/unit changed");
                require(event.get("values").equals(Map.of("value", 42, "sdnn", 42,
                        "rmssd", 51, "rri", 803)), "new-protocol fields were flattened/mislabeled");
                h.onHrvValues(List.of(new k6_RRI_HRV_DATA(43, 52, 804)));
                require(h.emitted.size() == 1, "HRV completed more than once");
                break;
            case "stress-compat":
                h.activeMeasurement = "stress";
                h.setMeasurement("stress", true);
                h.onStressCompatValues(Arrays.asList(null, new K6_HrvStruct(0),
                        new K6_HrvStruct(101)));
                require(h.emitted.isEmpty(), "stress compatibility accepted an invalid value");
                h.onStressCompatValues(List.of(new K6_HrvStruct(30)));
                require(h.emitted.size() == 1, "stress compatibility did not emit");
                require(h.emitted.get(0).get("metric").equals("stress")
                        && h.emitted.get(0).get("unit").equals("")
                        && h.emitted.get(0).get("values").equals(Map.of("value", 30)),
                        "stress compatibility semantics changed");
                h.setMeasurement("stress", false);
                require(h.helper.commands.equals(List.of("stress:1", "stress:0")),
                        "stress commands changed");
                break;
            case "callback-guards":
                for (String metric : new String[]{null, "heart_rate", "blood_oxygen", "hrv"}) {
                    h.activeMeasurement = metric;
                    h.onStressCompatValues(List.of(new K6_HrvStruct(30)));
                }
                h.activeMeasurement = "stress";
                h.linkConnected = false;
                h.onStressCompatValues(List.of(new K6_HrvStruct(30)));
                h.linkConnected = true;
                h.resultEmitted = true;
                h.onStressCompatValues(List.of(new K6_HrvStruct(30)));
                require(h.emitted.isEmpty() && h.collected.isEmpty(),
                        "legacy callback escaped its active stress session");
                break;
            default: throw new AssertionError("Unknown scenario: " + args[0]);
        }
        System.out.println("CoolWear HRV protocol passed: " + args[0]);
    }

    private static void require(boolean passed, String message) {
        if (!passed) throw new AssertionError("HRV protocol assertion failed: " + message);
    }
    private static final class BuildConfig { static final boolean DEBUG = false; }
    private static final class Log { static void i(String tag, String message) {} }
    private static final class CEBC {
        static final class OPENSTATUS { static final int OPEN = 1; static final int CLOSE = 0; }
    }
    private static final class Main {
        private final List<Runnable> tasks = new ArrayList<>();
        void postDelayed(Runnable task, long delay) { tasks.add(task); }
        void removeCallbacks(Runnable task) { tasks.remove(task); }
        void runDelayed() {
            List<Runnable> pending = new ArrayList<>(tasks);
            tasks.clear();
            pending.forEach(Runnable::run);
        }
    }
    private static final class Helper {
        final List<String> commands = new ArrayList<>();
        Helper getSendBlueData() { return this; }
        void sendHeartRateSwitch(int state) { commands.add("heart:" + state); }
        void sendBloodOxygenDetection(int state) { commands.add("oxygen:" + state); }
        void sendRriHrvCmd(int state) { commands.add("rri:" + state); }
        void sendHRVSwitch(int state) { commands.add("legacy45:" + state); }
        void sendStressSwitch(int state) { commands.add("stress:" + state); }
    }
    private static final class K6_HrvStruct {
        private final int value;
        K6_HrvStruct(int value) { this.value = value; }
        int getHrvNums() { return value; }
        long getTime() { return System.currentTimeMillis(); }
    }
    private static final class k6_RRI_HRV_DATA {
        private final int sdnn, rmssd, rri;
        k6_RRI_HRV_DATA(int sdnn, int rmssd, int rri) {
            this.sdnn = sdnn; this.rmssd = rmssd; this.rri = rri;
        }
        int getSdnn() { return sdnn; }
        int getRmssd() { return rmssd; }
        int getRri() { return rri; }
        long getTime() { return System.currentTimeMillis(); }
    }
    private static final class CoolWearRecordMapper {
        static long currentTimestamp(long time) { return time; }
        static List<Map<String, Object>> hrvRecords(String id, String firmware,
                List<k6_RRI_HRV_DATA> values) { return List.of(); }
    }
}
