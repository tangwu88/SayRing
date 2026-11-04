package cc.saidian.saydian_app;

import java.util.*;

/** Executes the production callback and deadline methods against a monotonic test clock. */
public final class CoolWearSyncTest {
    final Map<String, Map<String, Object>> syncedHealthRecords = new LinkedHashMap<>(), syncedSportRecords = new LinkedHashMap<>();
    MethodChannel.Result pendingHealthSync, pendingSportSync;
    Runnable syncDeadline;
    CoolWearSyncWindow syncWindow, healthProgressWindow;
    final String connectedId = "test-ring", connectedName = "R7 Ultra";
    final String TAG = "test";
    boolean linkConnected = true, deviceInfoReceived = true;
    final Main main = new Main();
    final Helper helper = new Helper();
    // 本夹具只验收同步时钟；实际 SDK 请求帧由 CoolWearReadRequestsSdkTest 验收。
    static final class CoolWearReadRequests { enum Kind { MIXED_INFO } }
    void requestRingInfo(CoolWearReadRequests.Kind... ignored) { helper.reads++; }
    int progress, passive;
    String supportedModel(String name) { return name; }
    void emit(String type, Map<String, Object> payload) {
        if (type.equals("healthRecord")) passive++;
        if (type.equals("syncRecords")) progress++;
    }
    static final class Log { static void w(String tag, String message) {} }
    static final class SystemClock { static long now; static long elapsedRealtime() { return now; } }
    static final class Main {
        long at; Runnable task;
        void removeCallbacks(Runnable t) { if (task == t) task = null; }
        void postDelayed(Runnable t, long delay) { at = SystemClock.now + delay; task = t; }
        void advance(long until) {
            while (task != null && at <= until) {
                SystemClock.now = at; Runnable next = task; task = null; next.run();
            }
            SystemClock.now = until;
        }
    }
    static final class Helper {
        int reads;
        void setEnableGsDataTrans(boolean ignored) {}
    }
    static final class MethodChannel {
        static final class Result {
            String code; Object detail; long at;
            void error(String c, String m, Object d) {
                if (code != null) throw new AssertionError("callback returned twice");
                code = c; detail = d; at = SystemClock.now;
            }
            boolean partialAt(long when, int count) {
                return "COOLWEAR_SYNC_TIMEOUT".equals(code) && at == when && ((List<?>) detail).size() == count;
            }
        }
    }
    // PRODUCTION_METHODS
    static List<Map<String, Object>> packet(String id, int value) {
        Map<String, Object> row = new HashMap<>();
        if (id != null) row.put("id", id);
        row.put("values", Collections.singletonMap("value", value));
        return Collections.singletonList(row);
    }
    static CoolWearSyncTest start() {
        SystemClock.now = 0;
        return new CoolWearSyncTest();
    }
    public static void main(String[] args) {
        CoolWearSyncTest s = start();
        MethodChannel.Result health = new MethodChannel.Result();
        s.startSync(health, false);
        s.main.advance(2200); s.collectHealth(packet("steps", 30));
        s.main.advance(5000); s.collectHealth(packet("steps", 30));
        s.main.advance(12200); s.collectHealth(packet("steps", 30));
        s.main.advance(31000); s.collectHealth(packet(null, 10));
        s.main.advance(32200);
        assert health.partialAt(32200, 1) : "duplicate extended health wait";
        assert s.progress == 1 : "duplicate/invalid packet reported progress";

        // A real workout can arrive after the health callback, before a sport reader joins.
        s.main.advance(34000); s.collectSport(packet("workout", 12));
        s.main.advance(36500); s.collectHealth(packet("late-steps", 32));
        assert s.passive == 1 : "new late health record was lost";
        MethodChannel.Result sport = new MethodChannel.Result();
        s.startSync(sport, true);
        assert s.helper.reads == 1 : "late sport join started a new stream";
        s.main.advance(40000); s.collectSport(packet("workout", 13));
        s.main.advance(70000);
        assert sport.partialAt(70000, 1) : "late workout discarded or timeout changed";
        assert sport.detail.toString().contains("value=13") : "revised workout discarded";

        // Same identifier, changed values: preserve content and extend from the change.
        s = start(); health = new MethodChannel.Result(); s.startSync(health, false);
        s.main.advance(2100); s.collectHealth(packet("count", 10));
        s.main.advance(12100); s.collectHealth(packet("count", 11));
        s.main.advance(35000); assert health.code == null && s.progress == 2;
        s.main.advance(42100); assert health.partialAt(42100, 1) && health.detail.toString().contains("value=11");

        // A sport consumer or already-buffered sport data keeps the original wire window.
        for (boolean joinFirst : new boolean[] {true, false}) {
            s = start(); health = new MethodChannel.Result(); sport = new MethodChannel.Result();
            s.startSync(health, false);
            if (joinFirst) s.startSync(sport, true);
            else s.collectSport(packet("early-workout", 5));
            s.main.advance(2000); s.collectHealth(packet("same", 1));
            s.main.advance(12000); s.collectHealth(packet("same", 1));
            s.main.advance(34000); assert health.code == null : "sport stream closed early";
            s.collectSport(packet("real-workout", 7));
            if (!joinFirst) s.startSync(sport, true);
            s.main.advance(64000);
            assert health.partialAt(64000, 1) && sport.partialAt(64000, joinFirst ? 1 : 2);
        }

        // Starting another explicit read while the previous transfer is draining must not lose sport data.
        s = start(); health = new MethodChannel.Result(); s.startSync(health, false);
        s.main.advance(1000); s.collectHealth(packet("steps", 1));
        s.main.advance(15000); s.collectHealth(packet("steps", 1));
        s.main.advance(31000); assert health.partialAt(31000, 1);
        s.main.advance(35000); s.collectSport(packet("during-tail", 77));
        MethodChannel.Result next = new MethodChannel.Result(); s.startSync(next, false);
        sport = new MethodChannel.Result(); s.startSync(sport, true);
        s.main.advance(65000); assert sport.partialAt(65000, 1) && next.partialAt(65000, 0);

        // Actual changes keep the transfer alive but cannot defer the 90s hard cap.
        s = start(); health = new MethodChannel.Result(); s.startSync(health, false);
        for (int seconds : new int[] {22, 43, 68, 88}) {
            s.main.advance(seconds * 1000L); s.collectHealth(packet("revised", seconds));
        }
        s.main.advance(90000); assert health.partialAt(90000, 1);

        // An invalid batch alone cannot keep the stream open or publish progress.
        s = start(); health = new MethodChannel.Result(); s.startSync(health, false);
        s.main.advance(25000); s.collectHealth(packet(null, 1)); s.collectSport(packet(null, 8));
        s.main.advance(30000); assert health.partialAt(30000, 0) && s.progress == 0;
    }
}
