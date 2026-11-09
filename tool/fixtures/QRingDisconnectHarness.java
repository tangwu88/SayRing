package cc.saidian.saydian_app;

import com.oudmon.ble.base.bluetooth.BleAction;
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
    static final class BluetoothGatt { static final int GATT_SUCCESS = 0; }
    static final class Intent {
        final String action;
        final Map<String, Object> extras = new HashMap<>();
        Intent(String action, String address) { this.action = action; extras.put(BleAction.EXTRA_ADDR, address); }
        String getAction() { return action; }
        String getStringExtra(String key) { return (String) extras.get(key); }
        int getIntExtra(String key, int fallback) { return (Integer) extras.getOrDefault(key, fallback); }
        BluetoothDevice getParcelableExtra(String key) { return (BluetoothDevice) extras.get(key); }
        byte[] getByteArrayExtra(String key) { return (byte[]) extras.get(key); }
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
    void onFactoryResetWrite(Intent intent) { }
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
    int sportLiveStops;
    void stopSportLive(boolean sendStop) { check(!sendStop); sportLiveStops++; }
    void finishCamera(Object value, String code, String message) { }
    void failPendingSync(String code, String message) { syncCancellations++; }
    void startAutomaticRecovery() { throw new AssertionError("Disconnect assertion failed: recovery was disarmed"); }
    void emit(String event, Map<String, Object> value) { events.add(event); }
    int handshakes, reads;
    void onServiceReady() { handshakes++; }
    void onCharacteristic(String uuid, byte[] data) { reads++; }

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
        // The vendor clone receiver forwards BLE_NO_CALLBACK as (null, false)
        // even though its GATT and command-independent features remain live.
        b = fresh(); b.onConnectionState(null, false);
        check("synthetic-current".equals(b.connectedId) && b.connectionGeneration == 7);
        check(b.supportFlags != null && b.cameraResets == 0 && b.syncCancellations == 0);
        b.onSdkBroadcast(new Intent(BleAction.BLE_NO_CALLBACK, null));
        b.onSdkBroadcast(new Intent(BleAction.BLE_GATT_DISCONNECTED, null));
        check(b.connectedId != null && b.events.isEmpty() && b.cameraResets == 0);
        b.onSdkBroadcast(new Intent(BleAction.BLE_SERVICE_DISCOVERED, "synthetic-other"));
        b.onSdkBroadcast(new Intent(BleAction.BLE_SERVICE_DISCOVERED, null));
        check(b.handshakes == 0);
        b.onSdkBroadcast(new Intent(BleAction.BLE_SERVICE_DISCOVERED, "SYNTHETIC-CURRENT"));
        check(b.handshakes == 1);
        Intent read = new Intent(BleAction.BLE_CHARACTERISTIC_READ, "synthetic-other");
        read.extras.put(BleAction.EXTRA_STATUS, 0);
        b.onSdkBroadcast(read);
        read.extras.put(BleAction.EXTRA_ADDR, b.connectedId);
        read.extras.put(BleAction.EXTRA_STATUS, 133);
        b.onSdkBroadcast(read);
        check(b.reads == 0);
        read.extras.put(BleAction.EXTRA_STATUS, 0);
        b.onSdkBroadcast(read);
        check(b.reads == 1);
        Intent disconnected = new Intent(BleAction.BLE_GATT_DISCONNECTED, b.connectedId);
        disconnected.extras.put(BleAction.EXTRA_DEVICE, new BluetoothDevice(b.connectedId));
        b.onSdkBroadcast(disconnected);
        check(b.connectedId == null && b.events.equals(List.of("disconnected")) && b.cameraResets == 1 && b.sportLiveStops == 1);
        System.out.println("Production Android disconnect assertions: " + checks);
    }
}
