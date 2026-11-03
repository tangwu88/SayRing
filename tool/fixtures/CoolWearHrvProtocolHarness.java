package cc.saidian.saydian_app;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Runs production bridge methods against protocol-shaped synthetic samples. */
public final class CoolWearHrvProtocolHarness {
    private static final String TAG = "test";
    private String activeMeasurement;
    private boolean resultEmitted;
    private volatile long measurementGeneration = 1;
    private long measurementStartedAt = System.currentTimeMillis() - 1_000;
    private int hrvLivePackets, hrvHistoryPackets, hrvLegacyPackets, hrvStressPackets;
    private boolean linkConnected = true;
    private final String connectedId = "coolwear:test-only";
    private final String connectedName = "HR05_TEST_ONLY";
    private final String firmwareVersion = "test-only";
    private final Helper helper = new Helper();
    private final Main main = new Main();
    private final List<Map<String, Object>> emitted = new ArrayList<>();
    private final List<Map<String, Object>> collected = new ArrayList<>();
    // These stubs let the same test run against the previous production methods
    // and fail on the wrong result/command, rather than fail compilation.
    private static final long LEGACY_HRV_FALLBACK_MS = 8_000L;
    private Runnable hrvFallback;

    private void live(List<k6_RRI_HRV_DATA> values) {
        onHrvValues(values, true, measurementGeneration);
    }

    // PRODUCTION_METHODS

    private void collectHealth(List<Map<String, Object>> values) { collected.addAll(values); }
    private String supportedModel(String name) { return "HR05"; }
    private void emit(String event, Map<String, Object> record) {
        require("healthRecord".equals(event), "unexpected emitted event");
        emitted.add(record);
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
                h.live(List.of(new k6_RRI_HRV_DATA(0, 0, 0, 3, 80),
                        new k6_RRI_HRV_DATA(1001, 0, 0, 3, 80)));
                require(h.emitted.isEmpty(), "invalid SDNN was accepted");
                h.live(List.of(new k6_RRI_HRV_DATA(42, 51, 803, 3, 80)));
                require(h.emitted.size() == 1, "new-protocol HRV was not emitted once");
                Map<String, Object> event = h.emitted.get(0);
                require(event.get("type").equals("hrv") && event.get("unit").equals("ms"),
                        "new-protocol HRV metric/unit changed");
                require(event.get("values").equals(Map.of("value", 42, "sdnn", 42,
                        "rmssd", 51, "rri", 803, "sdkQuality", 3, "validCount", 80)),
                        "new-protocol fields were flattened/mislabeled");
                h.live(List.of(new k6_RRI_HRV_DATA(43, 52, 804, 2, 70)));
                require(h.emitted.size() == 1, "HRV completed more than once");
                break;
            case "rri-quality":
                h.activeMeasurement = "hrv";
                for (int[] invalid : new int[][]{{-1, 80}, {0, 80}, {4, 80}, {255, 80},
                        {2, -1}, {2, 0}, {2, 1}, {2, 256}}) {
                    h.live(List.of(new k6_RRI_HRV_DATA(42, 51, 803, invalid[0], invalid[1])));
                    require(h.emitted.isEmpty() && !h.resultEmitted,
                            "invalid quality/count prematurely completed HRV: " + Arrays.toString(invalid));
                }
                h.live(List.of(new k6_RRI_HRV_DATA(42, 51, 803, 2, 60)));
                require(h.emitted.size() == 1 && h.resultEmitted, "valid later RRI did not complete HRV");
                break;
            case "rri-quality-boundaries":
                for (int quality : new int[]{1, 2, 3}) {
                    for (int count : new int[]{2, 255}) {
                        for (int sdnn : new int[]{1, 1000}) {
                            CoolWearHrvProtocolHarness sample = new CoolWearHrvProtocolHarness();
                            sample.activeMeasurement = "hrv";
                            sample.live(List.of(new k6_RRI_HRV_DATA(sdnn, 0, 0, quality, count)));
                            require(sample.emitted.size() == 1, "valid RRI boundary rejected");
                            require(sample.emitted.get(0).get("values").equals(Map.of("value", sdnn,
                                    "sdnn", sdnn, "sdkQuality", quality, "validCount", count)),
                                    "actual quality/count were not retained");
                        }
                    }
                }
                break;
            case "command-failure":
                Result start = new Result();
                h.helper.failCommand = true;
                long oldGeneration = h.measurementGeneration;
                h.startMeasurementSession("hrv", start);
                require("MEASUREMENT_START_FAILED".equals(start.error)
                        && h.activeMeasurement == null && h.measurementGeneration > oldGeneration,
                        "failed SDK start left a live session");
                require("hrv".equals(start.details.get("metric"))
                        && h.connectedId.equals(start.details.get("deviceId")), "start failure lost its context");
                h.helper.failCommand = false;
                h.startMeasurementSession("hrv", new Result());
                require("hrv".equals(h.activeMeasurement), "clean subsequent start failed");
                long started = h.measurementGeneration;
                Result otherStop = new Result();
                h.stopMeasurementSession("heart_rate", otherStop);
                require("MEASUREMENT_ACTIVE".equals(otherStop.error)
                        && "hrv".equals(h.activeMeasurement) && h.measurementGeneration == started,
                        "late stop for another metric cancelled the current session");
                Result stop = new Result();
                h.helper.failCommand = true;
                h.stopMeasurementSession("hrv", stop);
                require("MEASUREMENT_STOP_FAILED".equals(stop.error)
                        && h.activeMeasurement == null && h.measurementGeneration > started,
                        "failed SDK stop retained an accepting session");
                h.onHrvValues(List.of(new k6_RRI_HRV_DATA(42, 51, 803, 2, 60)), true, started);
                require(h.emitted.isEmpty(), "late packet survived a failed stop");
                break;
            case "rri-source-session":
                h.activeMeasurement = "hrv";
                k6_RRI_HRV_DATA valid = new k6_RRI_HRV_DATA(42, 51, 803, 2, 60);
                h.onHrvValues(List.of(valid), false, h.measurementGeneration);
                require(h.emitted.isEmpty(), "history 61 completed a manual measurement");
                h.onHrvValues(List.of(valid), true, h.measurementGeneration - 1);
                require(h.emitted.isEmpty(), "retired callback completed a new session");
                h.live(Arrays.asList(null, new k6_RRI_HRV_DATA(42, 51, 803, 2, 60, 0),
                        new k6_RRI_HRV_DATA(42, 51, 803, 2, 60, h.measurementStartedAt - 10_000),
                        new k6_RRI_HRV_DATA(42, 51, 803, 2, 60, System.currentTimeMillis() + 60_000)));
                require(h.emitted.isEmpty(), "missing/old/future sample was relabeled now");
                long cancelled = h.measurementGeneration;
                h.clearMeasurementSession("test_cancel");
                h.activeMeasurement = "hrv";
                h.measurementStartedAt = System.currentTimeMillis();
                h.onHrvValues(List.of(valid), true, cancelled);
                require(h.emitted.isEmpty(), "cancelled callback completed restarted session");
                h.live(List.of(new k6_RRI_HRV_DATA(42, 51, 803, 2, 60)));
                require(h.emitted.size() == 1, "fresh live sample was rejected");
                break;
            case "rri-version":
                h.activeMeasurement = "hrv";
                h.live(List.of(new k6_RRI_HRV_DATA(42, 51, 803, 3, 80)));
                require(h.emitted.size() == 1, "valid RRI did not emit");
                Map<String, Object> actual = h.emitted.get(0);
                require(Integer.valueOf(2).equals(actual.get("rawVersion")),
                        "real HRV emission bypasses version 2 quality validation");
                require(actual.get("origin").equals("app_measurement")
                        && actual.get("sourceVendor").equals("coolwear")
                        && actual.get("sourceModel").equals("HR05")
                        && actual.get("deviceId").equals(h.connectedId), "record provenance changed");
                break;
            case "other-versions":
                for (String metric : new String[]{"heart_rate", "blood_oxygen", "stress", "body_temperature"}) {
                    CoolWearHrvProtocolHarness sample = new CoolWearHrvProtocolHarness();
                    sample.emitMeasurement(metric, System.currentTimeMillis(), 30, "test-only");
                    require(sample.emitted.size() == 1
                            && Integer.valueOf(1).equals(sample.emitted.get(0).get("rawVersion")),
                            "non-HRV measurement version changed: " + metric);
                }
                break;
            case "stress-compat":
                h.activeMeasurement = "stress";
                h.setMeasurement("stress", true);
                h.onStressCompatValues(Arrays.asList(null, new K6_HrvStruct(0),
                        new K6_HrvStruct(101)));
                require(h.emitted.isEmpty(), "stress compatibility accepted an invalid value");
                h.onStressCompatValues(List.of(new K6_HrvStruct(30)));
                require(h.emitted.size() == 1, "stress compatibility did not emit");
                require(h.emitted.get(0).get("type").equals("stress")
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
    private static final class MethodChannel {
        interface Result {
            void error(String code, String message, Object details);
            void success(Object value);
        }
    }
    private static final class Result implements MethodChannel.Result {
        String error;
        Map<?, ?> details = Map.of();
        @Override public void error(String code, String message, Object value) {
            error = code;
            if (value instanceof Map<?, ?>) details = (Map<?, ?>) value;
        }
        @Override public void success(Object value) { }
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
        boolean failCommand;
        final List<String> commands = new ArrayList<>();
        Helper getSendBlueData() { return this; }
        void sendHeartRateSwitch(int state) { commands.add("heart:" + state); }
        void sendBloodOxygenDetection(int state) { commands.add("oxygen:" + state); }
        void sendRriHrvCmd(int state) {
            if (failCommand) throw new IllegalStateException("synthetic SDK failure");
            commands.add("rri:" + state);
        }
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
        private final int sdnn, rmssd, rri, quality, validCount;
        private final long time;
        k6_RRI_HRV_DATA(int sdnn, int rmssd, int rri, int quality, int validCount) {
            this(sdnn, rmssd, rri, quality, validCount, System.currentTimeMillis());
        }
        k6_RRI_HRV_DATA(int sdnn, int rmssd, int rri, int quality, int validCount, long time) {
            this.sdnn = sdnn; this.rmssd = rmssd; this.rri = rri;
            this.quality = quality; this.validCount = validCount; this.time = time;
        }
        int getSdnn() { return sdnn; }
        int getRmssd() { return rmssd; }
        int getRri() { return rri; }
        int getQuality() { return quality; }
        int getValid_count() { return validCount; }
        long getTime() { return time; }
    }
    private static final class CoolWearRecordMapper {
        // PRODUCTION_RECORD_METHOD
        static long currentTimestamp(long time) { return time; }
        static List<Map<String, Object>> hrvRecords(String id, String firmware,
                List<k6_RRI_HRV_DATA> values) { return List.of(); }
    }
}
