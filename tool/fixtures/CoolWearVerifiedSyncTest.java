package cc.saidian.saydian_app;

import java.util.*;

/** Executes production synchronization methods with an ordered monotonic clock. */
public final class CoolWearVerifiedSyncTest {
    final Map<String, Map<String, Object>> syncedHealthRecords = new LinkedHashMap<>(), syncedSportRecords = new LinkedHashMap<>();
    final Map<String, Map<String, Object>> connectionHealthRecords = new LinkedHashMap<>();
    final Map<String, String> connectionRecordReceipts = new HashMap<>();
    final String receiptNamespace = "synthetic";
    long receiptSequence;
    final Map<Integer, CoolWearHistoryBatch> historyBatches = new LinkedHashMap<>(), connectionHistoryBatches = new LinkedHashMap<>();
    final Set<Integer> requestedHistoryTypes = new HashSet<>();
    MethodChannel.Result pendingHealthSync, pendingSportSync;
    Runnable syncDeadline;
    CoolWearSyncWindow syncWindow, healthProgressWindow;
    final String connectedId = "test-ring", connectedName = "R7 Ultra", TAG = "test";
    boolean linkConnected = true, deviceInfoReceived = true, historyObserverReady = true;
    long historyRequestGeneration;
    K6_DATA_TYPE_FUNCTION_CONTROL functionControl;
    final Main main = new Main();
    final Helper helper = new Helper();
    int progress, passive;
    String supportedModel(String name) { return name; }
    void emit(String type, Map<String, Object> payload) {
        if (type.equals("healthRecord")) passive++;
        if (type.equals("syncRecords")) progress++;
    }
    static final class Log { static void w(String t, String m) {} static void i(String t, String m) {} }
    static final class SystemClock { static long now; static long elapsedRealtime() { return now; } }
    static final class Main {
        record Task(long at, long seq, Runnable action) {}
        long seq;
        final PriorityQueue<Task> tasks = new PriorityQueue<>(Comparator.comparingLong(Task::at).thenComparingLong(Task::seq));
        void removeCallbacks(Runnable t) { tasks.removeIf(x -> x.action == t); }
        void post(Runnable t) { postDelayed(t, 0); }
        void postDelayed(Runnable t, long delay) { tasks.add(new Task(SystemClock.now + delay, ++seq, t)); }
        void advance(long until) {
            while (!tasks.isEmpty() && tasks.peek().at <= until) {
                Task task = tasks.remove(); SystemClock.now = task.at; task.action.run();
            }
            SystemClock.now = until;
        }
    }
    static final class Helper { void setEnableGsDataTrans(boolean enabled) { assert enabled; } }
    static final class CoolWearReadRequests { enum Kind { MIXED_INFO } }
    CEBluetoothProxyBase currentReadProxy() { return BleFactory.instance.proxy; }
    void requestRingInfo(CoolWearReadRequests.Kind kind) {
        assert kind == CoolWearReadRequests.Kind.MIXED_INFO;
        currentReadProxy().sendData(new CEDevData(3,9));
    }
    static final class CEDevData {
        final int cmd, type;
        CEDevData(int cmd, int type) { this.cmd = cmd; this.type = type; }
    }
    static final class CEBluetoothProxyBase {
        final List<Integer> requests = new ArrayList<>();
        String getBlueAddress() { return "test-ring"; }
        void sendData(CEDevData packet) { assert packet.cmd == 3 : "configuration write escaped"; requests.add(packet.type); }
    }
    static final class BleFactory {
        static final BleFactory instance = new BleFactory();
        final CEBluetoothProxyBase proxy = new CEBluetoothProxyBase();
        static BleFactory getInstance() { return instance; }
        CEBluetoothProxyBase getK6Proxy() { return proxy; }
    }
    static final class K6_DATA_TYPE_FUNCTION_CONTROL {
        boolean isHasHR24H() { return true; } boolean isHr_measure_button() { return true; }
        boolean isHasO2() { return true; } boolean isHasHrvSupported() { return true; }
        boolean isHasTemperature() { return true; }
    }
    static final class MethodChannel {
        static final class Result {
            String code; Object detail, value; long at; int calls;
            void error(String c, String m, Object d) { assert calls++ == 0 : "callback twice"; code=c; detail=d; at=SystemClock.now; }
            void success(Object v) { assert calls++ == 0 : "callback twice"; value=v; at=SystemClock.now; }
        }
    }
    // PRODUCTION_METHODS
    static List<Map<String, Object>> record(String id, int value) {
        Map<String,Object> r = new HashMap<>(); r.put("id",id); r.put("values", Map.of("value",value)); return List.of(r);
    }
    static CoolWearVerifiedSyncTest start() {
        SystemClock.now=0; BleFactory.instance.proxy.requests.clear(); return new CoolWearVerifiedSyncTest();
    }
    static byte[] packet(int remaining, int... rows) {
        byte[] result=new byte[3+rows.length]; result[0]=(byte)remaining; result[1]=(byte)(remaining >> 8); result[2]=(byte)rows.length;
        for(int i=0;i<rows.length;i++)result[i+3]=(byte)rows[i]; return result;
    }
    public static void main(String[] args) {
        CoolWearVerifiedSyncTest s=start(); MethodChannel.Result health=new MethodChannel.Result();
        s.startSync(health,false); s.main.advance(1000);
        assert BleFactory.instance.proxy.requests.equals(List.of(9,4,5,6));
        s.main.advance(2000); s.collectHealth(record("steps",30)); s.receiveHistoryBatch(5,packet(1,1));
        s.main.advance(5000); s.collectHealth(record("steps",30)); s.receiveHistoryBatch(5,packet(1,1));
        s.main.advance(12000); s.collectHealth(record("steps",30)); s.receiveHistoryBatch(5,packet(1,1));
        s.main.advance(32000);
        assert health.code==null && ((Map<?,?>)health.value).get("statuses") instanceof Map;
        assert ((Map<?,?>)((Map<?,?>)health.value).get("statuses")).get("sleep").equals("not_received") : "missing range claimed complete";
        assert ((List<?>)((Map<?,?>)health.value).get("records")).size()==1;
        assert s.progress==1 : "duplicates inflated progress";
        s.collectHealth(record("late",31)); assert s.passive==1 : "late history lost";

        s=start(); health=new MethodChannel.Result();
        // A real early callback is cached before Flutter starts its explicit read.
        s.collectHealth(record("early",11)); s.receiveHistoryBatch(5,packet(0,1));
        s.startSync(health,false); s.main.advance(1000);
        CoolWearVerifiedSyncTest active = s;
        // Emulate the SDK listener's final mapping task already queued when
        // the raw terminal packet arrives. Completion must include that row.
        s.main.post(() -> active.collectHealth(record("last-mapped",12)));
        s.receiveHistoryBatch(6,packet(0));
        assert health.calls==0 : "returned before SDK mapping turn drained";
        s.main.advance(1000);
        assert health.code==null && health.calls==1 && health.value instanceof Map : "explicit complete ranges not returned";
        Map<?,?> result=(Map<?,?>)health.value;
        assert ((List<?>)result.get("records")).size()==2 : "early or final mapped callback disappeared";
        assert ((Map<?,?>)result.get("statuses")).get("sleep").equals("no_data");

        s=start(); health=new MethodChannel.Result(); MethodChannel.Result sport=new MethodChannel.Result();
        s.startSync(health,false); s.main.advance(500); s.startSync(sport,true);
        s.collectHealth(record("steps",5)); s.receiveHistoryBatch(5,packet(0,1)); s.receiveHistoryBatch(6,packet(0));
        assert health.calls==0 : "sport range still pending";
        s.collectSport(record("workout",8)); s.receiveHistoryBatch(10,packet(0,1));
        s.main.advance(500);
        assert health.calls==1 && sport.calls==1 && ((List<?>)sport.value).size()==1;

        s=start(); health=new MethodChannel.Result(); s.functionControl=new K6_DATA_TYPE_FUNCTION_CONTROL();
        s.startSync(health,false); s.main.advance(5000);
        for(int type:new int[]{5,6,8,40,42,47}) s.receiveHistoryBatch(type,packet(0));
        assert health.calls==0 : "HRV read was silently skipped";
        s.receiveHistoryBatch(61,packet(0)); s.main.advance(5000);
        assert health.calls==1 && health.code==null;

        s=start(); health=new MethodChannel.Result(); s.startSync(health,false);
        s.failPendingSync("CONNECT_CANCELLED","cancel"); int before=BleFactory.instance.proxy.requests.size();
        s.main.advance(40000); assert BleFactory.instance.proxy.requests.size()==before : "cancelled delayed command escaped";
        assert health.calls==1;
        s=start(); health=new MethodChannel.Result();
        s.collectHealth(record("retained",7)); String first=s.connectionRecordReceipts.get("retained");
        s.collectHealth(record("retained",8)); String second=s.connectionRecordReceipts.get("retained");
        assert !first.equals(second);
        s.acknowledgeHealthRecords(Map.of("retained",first));
        assert s.connectionHealthRecords.containsKey("retained") : "stale receipt removed a newer sample";
        s.acknowledgeHealthRecords(Map.of("retained",second));
        assert s.connectionHealthRecords.isEmpty() && s.connectionRecordReceipts.isEmpty();
        System.out.println("Production history sync state machine PASS");
    }
}
