package cc.saidian.saydian_app;

import android.os.SystemClock;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Extracted production control flow, virtual time, no real Bluetooth/health data. */
public final class CoolWearClockHarness {
    private static CoolWearClockHarness activeBridge;
    private static final String TAG = "test";
    private final CoolWearClockSync clockSync = new CoolWearClockSync();
    private Runnable clockSyncTask;
    private final Handler main = new Handler();
    private final Target recoveryTarget = new Target();
    private boolean linkConnected = true, deviceInfoReceived = true, resultEmitted;
    private long connectionEpoch = 1, measurementGeneration, measurementStartedAt;
    private String connectedId = "target-A", activeMeasurement, activeSportMode, pendingSportStopTarget;
    private Object pendingConnect, pendingClear, pendingHealthSync, pendingSportSync, syncWindow;
    private Object pendingReminders, pendingAutoSettings, pendingGesture, pendingHealthPulse;
    private int hrvLivePackets, hrvHistoryPackets, hrvLegacyPackets, hrvStressPackets;
    private final Gesture gesture = new Gesture();
    private int writes;
    private boolean throwOnWrite;
    private final List<String> order = new ArrayList<>();
    private final Proxy proxy = new Proxy();

    private static final class Target {
        long owner = 1; boolean active = true;
        long generation() { return owner; }
        boolean isActive() { return active; }
    }
    private static final class Gesture { boolean busy; boolean pending() { return busy; } }
    private static final class Handler {
        private final List<Runnable> queue = new ArrayList<>();
        void post(Runnable r) { queue.add(r); }
        void postDelayed(Runnable r, long delay) { queue.add(r); }
        void removeCallbacks(Runnable r) { queue.removeIf(value -> value == r); }
        void turn() { if (!queue.isEmpty()) queue.remove(0).run(); }
    }
    private static final class CEDevData { }
    private static final class K6_CESyncTime { static Object getCurrentTime() { return new Object(); } }
    private static final class CoolWearReadRequests {
        static CEDevData connectionClockUpdate(Object phone, int format, int mdFormat) {
            if (phone == null || format < 0 || format > 1 || mdFormat < 0 || mdFormat > 1)
                throw new AssertionError("unverified format");
            return new CEDevData();
        }
    }
    private static final class Log {
        static void w(String tag, String message) { }
        static void i(String tag, String message) { }
    }
    private static final class MethodChannel {
        static final class Result {
            boolean success;
            void error(String code, String message, Object details) { throw new AssertionError(code); }
            void success(Object value) { success = true; }
        }
    }
    private final class Proxy {
        void sendData(CEDevData value) {
            writes++; order.add("clock");
            if (throwOnWrite) throw new IllegalStateException("ambiguous SDK submission");
        }
    }
    private Proxy currentReadProxy() { return proxy; }
    private void setMeasurement(String metric, boolean enabled) { order.add("manual"); }
    private void hrvDiagnostic(String event, String reason) { }
    private void clearMeasurementSession(String reason) { activeMeasurement = null; }

    // PRODUCTION_METHODS

    private static CoolWearClockHarness fresh() {
        SystemClock.now = 0;
        CoolWearClockHarness h = new CoolWearClockHarness(); activeBridge = h; return h;
    }
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }
    public static void main(String[] args) throws Exception {
        int cases = 0;
        CoolWearClockHarness h = fresh(); h.synchronizeConnectionClock(1, 0); h.main.turn();
        check(h.writes == 1, "idle control"); h.synchronizeConnectionClock(1, 0); h.main.turn();
        check(h.writes == 1, "no duplicate submission"); cases++;
        for (String field : new String[]{"pendingConnect", "pendingClear", "pendingHealthSync",
                "pendingSportSync", "syncWindow", "pendingReminders", "pendingAutoSettings",
                "pendingGesture", "pendingHealthPulse", "activeMeasurement", "activeSportMode",
                "pendingSportStopTarget"}) {
            h = fresh(); java.lang.reflect.Field f = CoolWearClockHarness.class.getDeclaredField(field);
            f.set(h, f.getType() == String.class ? "busy" : new Object());
            h.synchronizeConnectionClock(1, 1); h.main.turn();
            check(h.writes == 0 && h.clockSync.pending() != null, field + " retains real format");
            f.set(h, null); SystemClock.now = 500; h.main.turn();
            check(h.writes == 1 && h.clockSync.pending() == null, field + " drains when idle"); cases++;
        }
        h = fresh(); h.deviceInfoReceived = false; h.synchronizeConnectionClock(0, 1); h.main.turn();
        check(h.writes == 0, "pre-handshake time retained"); h.deviceInfoReceived = true;
        h.main.turn(); check(h.writes == 1, "handshake enables deferred time"); cases++;
        h = fresh(); h.gesture.busy = true; h.synchronizeConnectionClock(0, 0); h.main.turn();
        check(h.writes == 0, "gesture blocks"); h.gesture.busy = false; h.main.turn();
        check(h.writes == 1, "gesture idle resumes"); cases++;
        h = fresh(); h.synchronizeConnectionClock(-1, 0); h.synchronizeConnectionClock(0, 2);
        h.main.turn(); check(h.writes == 0 && h.clockSync.pending() == null, "invalid format never writes"); cases++;
        h = fresh(); h.pendingHealthSync = new Object(); h.synchronizeConnectionClock(1, 0);
        SystemClock.now = CoolWearClockSync.MAX_WAIT_MS - 1; h.synchronizeConnectionClock(1, 0);
        check(h.main.queue.size() == 1, "duplicates do not multiply tasks");
        SystemClock.now++; h.pendingHealthSync = null; h.main.turn();
        check(h.writes == 0 && h.clockSync.pending() == null, "duplicates cannot extend deadline"); cases++;
        for (int stale = 0; stale < 6; stale++) {
            h = fresh(); h.synchronizeConnectionClock(0, 0);
            switch (stale) {
                case 0: h.connectionEpoch++; break;
                case 1: h.recoveryTarget.owner++; break;
                case 2: h.connectedId = "target-B"; break;
                case 3: h.linkConnected = false; break;
                case 4: h.recoveryTarget.active = false; break;
                default: activeBridge = null; break;
            }
            h.main.turn(); check(h.writes == 0 && h.clockSync.pending() == null, "retired context " + stale); cases++;
        }
        h = fresh(); h.synchronizeConnectionClock(0, 0); h.cancelConnectionClock(); h.main.turn();
        check(h.writes == 0 && h.main.queue.isEmpty(), "teardown removes task"); cases++;
        h = fresh(); h.throwOnWrite = true; h.synchronizeConnectionClock(1, 1); h.main.turn();
        h.synchronizeConnectionClock(1, 1); h.main.turn();
        check(h.writes == 1 && h.clockSync.pending() == null, "ambiguous write not replayed"); cases++;
        h.throwOnWrite = false; h.connectionEpoch++; h.synchronizeConnectionClock(0, 0); h.main.turn();
        check(h.writes == 2, "new real connection eligible"); cases++;
        h = fresh(); h.synchronizeConnectionClock(1, 0); MethodChannel.Result result = new MethodChannel.Result();
        h.startMeasurementSession("heart_rate", result); h.main.turn();
        check(result.success && h.order.equals(List.of("clock", "manual")), "clock precedes immediate manual command"); cases++;
        h = fresh(); h.startMeasurementSession("blood_oxygen", new MethodChannel.Result());
        check(h.order.equals(List.of("manual")), "no guessed format on ordinary manual measurement"); cases++;
        System.out.println("Production clock sessions PASS; cases=" + cases);
    }
}
