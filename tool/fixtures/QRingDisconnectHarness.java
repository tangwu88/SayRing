package cc.saidian.saydian_app;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Synthetic SDK state; production disconnect methods and cancellation gate are unchanged. */
public final class QRingDisconnectHarness {
    static final class SystemClock {
        static long now;
        static long elapsedRealtime() { return now; }
    }
    static final class Log {
        static void i(String tag, String message) { }
        static void w(String tag, String message) { }
    }
    static final class MethodChannel {
        interface Result { void success(Object value); void error(String code, String message, Object details); }
    }
    static final class Reply implements MethodChannel.Result {
        int calls;
        String code;
        public void success(Object value) { calls++; }
        public void error(String value, String message, Object details) { calls++; code = value; }
    }
    static final class Handler {
        final Map<Runnable, Long> tasks = new HashMap<>();
        void removeCallbacks(Runnable task) { tasks.remove(task); }
        void postDelayed(Runnable task, long delay) { tasks.put(task, SystemClock.now + delay); }
        void advance(long millis) {
            SystemClock.now += millis;
            for (Map.Entry<Runnable, Long> entry : new ArrayList<>(tasks.entrySet())) {
                if (entry.getValue() <= SystemClock.now && tasks.remove(entry.getKey()) != null) entry.getKey().run();
            }
        }
    }
    static final class BluetoothDevice {
        final String address;
        BluetoothDevice(String value) { address = value; }
        String getAddress() { return address; }
        String getName() { return "synthetic-ring"; }
    }
    static final class DeviceManager {
        static final DeviceManager instance = new DeviceManager();
        static DeviceManager getInstance() { return instance; }
        void setDeviceAddress(String id) { }
        void setDeviceName(String name) { }
    }
    static final class BleBaseControl {
        static BleBaseControl instance;
        boolean connected = true, connecting, gatt = true;
        static BleBaseControl getInstance() { return instance; }
        boolean ismIsConnected() { return connected; }
        boolean isConnecting() { return connecting; }
        Object getGatt(String id) { return gatt ? this : null; }
    }
    final class Manager {
        boolean bonded = true, deferClosure, denyDisconnect, needConnect = true;
        int queued = 2, active = 1, lateDispatched, disconnects, unbinds;
        void setNeedConnect(boolean value) { needConnect = value; }
        void clearPendingTasks() { queued = 0; }
        void cancelCurrentTask() { active = 0; lateDispatched += queued; }
        void disconnect() {
            disconnects++;
            if (denyDisconnect) throw new SecurityException("synthetic denial");
            BleBaseControl.instance.connected = false;
            // SDK broadcasts disconnect before an in-progress bond settles and the GATT closes.
            onConnectionState(new BluetoothDevice(connectedId), false);
            if (!deferClosure) BleBaseControl.instance.gatt = false;
        }
        void unBindDevice() { unbinds++; bonded = false; disconnect(); }
    }

    static final String TAG = "fixture";
    final Handler main = new Handler();
    final Manager manager = new Manager();
    final List<String> events = new ArrayList<>();
    String connectedId = "synthetic-current", connectedName = "synthetic-ring";
    String recoveryTargetId = connectedId, recoveryContext = "synthetic-owner";
    String firmwareVersion = "old", hardwareVersion = "old", batteryUpdatedAt = "old";
    Integer batteryPercent = 80;
    Boolean charging = false;
    long batteryQueryAt = 4L;
    int connectionGeneration = 7, syncCancellations, cameraResets;
    boolean cancellingConnection, recoveryConnecting = true, handshakeStarted = true;
    Object setTimeFlags = new Object(), supportFlags = new Object();
    Object activeMeasurement = new Object(), activeSportMode = new Object(), activeSportType = new Object();
    MethodChannel.Result pendingConnect, pendingDisconnect;
    Runnable recoveryRetry = () -> {}, connectDeadline = () -> {};
    void resetRemoteCamera() { cameraResets++; }
    void finishCamera(Object value, String code, String message) { }
    void failPendingSync(String code, String message) { syncCancellations++; }
    void startAutomaticRecovery() { throw new AssertionError("Disconnect assertion failed: recovery was disarmed"); }
    void emit(String event, Map<String, Object> value) { events.add(event); }

    // PRODUCTION_METHODS

    static int checks;
    static void check(boolean value) { if (!value) throw new AssertionError("Disconnect assertion failed at " + checks); checks++; }
    static QRingDisconnectHarness fresh() {
        SystemClock.now = 1000L;
        BleBaseControl.instance = new BleBaseControl();
        return new QRingDisconnectHarness();
    }
    public static void main(String[] args) {
        QRingDisconnectHarness b = fresh();
        Reply reply = new Reply(), connect = new Reply();
        b.pendingConnect = connect;
        b.disconnectWithResult(reply);
        check(b.manager.bonded && b.manager.unbinds == 0 && b.manager.disconnects == 1);
        check(!b.manager.needConnect && b.manager.queued == 0 && b.manager.active == 0 && b.manager.lateDispatched == 0);
        check(connect.calls == 1 && "CONNECT_CANCELLED".equals(connect.code));
        check(reply.calls == 1 && reply.code == null && b.pendingDisconnect == null && !b.cancellingConnection);
        check(b.connectedId == null && b.recoveryTargetId == null && b.recoveryContext == null);
        check(b.setTimeFlags == null && b.supportFlags == null && b.batteryPercent == null);
        check(b.syncCancellations == 1 && b.cameraResets == 1 && b.activeMeasurement == null);
        check(!b.isCurrentConnection(7, "synthetic-current"));
        b.main.advance(25_000L);
        check(reply.calls == 1 && connect.calls == 1);

        b = fresh(); reply = new Reply(); b.manager.deferClosure = true;
        b.disconnectWithResult(reply);
        check(reply.calls == 0 && b.cancellingConnection && b.pendingDisconnect == reply);
        check(!b.isCurrentConnection(7, "synthetic-current"));
        check(b.connectedId != null && BleBaseControl.instance.gatt);
        Reply duplicate = new Reply(); b.disconnectWithResult(duplicate);
        check(duplicate.calls == 1 && "RECOVERY_PENDING".equals(duplicate.code) && b.manager.disconnects == 1);
        b.onConnectionState(new BluetoothDevice("synthetic-other"), false);
        check(reply.calls == 0 && b.cancellingConnection);
        b.main.advance(250L);
        check(reply.calls == 0 && b.cancellingConnection);
        BleBaseControl.instance.gatt = false; b.main.advance(250L);
        check(reply.calls == 1 && reply.code == null && !b.cancellingConnection && b.connectedId == null);
        b.main.advance(25_000L); check(reply.calls == 1);

        b = fresh(); reply = new Reply(); b.manager.denyDisconnect = true;
        b.disconnectWithResult(reply);
        check(reply.calls == 0 && b.cancellingConnection && b.manager.bonded);
        b.main.advance(20_000L);
        check(reply.calls == 1 && "RECOVERY_PENDING".equals(reply.code));
        check(b.cancellingConnection && b.connectedId != null);
        BleBaseControl.instance.connected = false; BleBaseControl.instance.gatt = false;
        b.onConnectionState(new BluetoothDevice("synthetic-current"), false);
        check(!b.cancellingConnection && b.connectedId == null && reply.calls == 1);

        b = fresh(); b.connectedId = null; reply = new Reply(); b.disconnectWithResult(reply);
        check(reply.calls == 1 && b.manager.disconnects == 0 && b.manager.bonded);
        b = fresh(); reply = new Reply(); b.onConnectionState(new BluetoothDevice("synthetic-other"), false);
        check(b.connectedId != null && b.connectionGeneration == 7);
        System.out.println("Production Android disconnect assertions: " + checks);
    }
}
