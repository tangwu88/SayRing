package cc.saidian.saydian_app;

import java.util.Map;
import java.util.HashMap;

/** 运行桥接真实清理方法。SDK 双缓存行为另由原 AAR 字节码门禁验证。 */
public final class CoolWearRecoveryTargetHarness {
    private static final String TAG = "host-test";
    private final BluetoothHelper helper = new BluetoothHelper();
    // PRODUCTION_ADAPTER
    private final Main main = new Main();
    private Runnable connectDeadline;
    private MethodChannel.Result pendingConnect;
    private boolean linkConnected, deviceInfoReceived, recoveringConnection;
    private Object functionControl;
    private String activeMeasurement, connectedId = "old-target", connectedName, connectedVendorId;
    private long measurementGeneration, measurementStartedAt;
    private boolean resultEmitted;
    private final String businessBinding = "owner-target", systemBond = "system-bond";
    private final int healthRecords = 134;
    private int disconnectedEvents;
    private int cancelledClears;
    private void finishHistoryClear(boolean acknowledged, String code) {
        assert !acknowledged : "connection failure must not confirm a clear";
        assert "CONNECT_CANCELLED".equals(code);
        cancelledClears++;
    }
    private void emit(String type, Map<String, Object> data) {
        assert "disconnected".equals(type);
        assert !recoveryTarget.isActive() : "controller notified while SDK recovery still owns transport";
        assert BleFactory.getInstance().proxy.stored.isEmpty();
        assert helper.disconnects == 1;
        assert "authorized-target".equals(data.get("deviceId"));
        disconnectedEvents++;
    }
    private void cancelHealthPulse(boolean ignored) { }
    private void cancelSdkRecoveryLease() { }
    private void resetGesture(String code, String message) { }
    private void hrvDiagnostic(String event, String reason) { }
    static final class Main { void removeCallbacks(Runnable task) { } }
    static final class Log { static void w(String tag, String message) { } }
    static final class MethodChannel {
        interface Result { void error(String code, String message, Object details); }
    }
    static final class ConnectUtil {
        String address = "old-target";
        String getBlueAddress() { return address; }
    }
    static final class CEBluetoothProxyBase {
        String stored = "old-target";
        boolean refuseWrite;
        final ConnectUtil connect = new ConnectUtil();
        String getBlueAddress() { return stored; }
        ConnectUtil getConnectUtil() { return connect; }
        void setBlueAddress(String target) {
            if (refuseWrite) return;
            connect.address = target;
            stored = target;
        }
    }
    static final class BleFactory {
        static BleFactory instance = new BleFactory();
        final CEBluetoothProxyBase proxy = new CEBluetoothProxyBase();
        static BleFactory getInstance() { return instance; }
        CEBluetoothProxyBase getK6Proxy() { return proxy; }
    }
    static final class BluetoothHelper {
        int disconnects;
        void disConnect() {
            disconnects++;
            BleFactory.getInstance().proxy.connect.address = "";
        }
    }
    // PRODUCTION_METHODS
    private static CoolWearRecoveryTargetHarness fresh() {
        BleFactory.instance = new BleFactory();
        return new CoolWearRecoveryTargetHarness();
    }
    public static void main(String[] args) {
        CoolWearRecoveryTargetHarness lost = fresh();
        lost.recoveryTarget.activate("authorized-target", lost.recoverySdk);
        long retired = lost.recoveryTarget.generation();
        lost.releaseLostConnection("authorized-target");
        assert lost.disconnectedEvents == 1 && !lost.recoveringConnection;
        assert !lost.recoveryTarget.acceptCallback(retired, true, lost.recoverySdk);
        assert lost.helper.disconnects == 1 : "retired callback must not stop a future controller attempt";
        lost.recoveryTarget.activate("authorized-target", lost.recoverySdk);
        assert !lost.recoveryTarget.acceptCallback(retired, false, lost.recoverySdk);
        assert lost.recoveryTarget.acceptCallback(lost.recoveryTarget.generation(), true, lost.recoverySdk);
        assert lost.helper.disconnects == 1 && lost.recoveryTarget.isActive();
        assert lost.businessBinding.equals("owner-target") && lost.systemBond.equals("system-bond");
        assert lost.healthRecords == 134;
        CoolWearRecoveryTargetHarness bridge = fresh();
        bridge.recoveryTarget.activate("authorized-target", bridge.recoverySdk);
        final CoolWearRecoveryTargetHarness first = bridge;
        bridge.pendingConnect = (code, message, details) -> {
            assert first.cancelledClears == 1 : "pending clear must terminate before connection result";
            assert !first.recoveryTarget.isActive() : "result returned before revoking target";
            assert BleFactory.getInstance().proxy.stored.isEmpty() : "result returned before cache cleanup";
        };
        bridge.failConnect("CONNECT_CANCELLED", "cancelled");
        assert bridge.measurementGeneration == 1 && bridge.activeMeasurement == null;
        assert bridge.cancelledClears == 1;
        assert BleFactory.getInstance().proxy.stored.isEmpty() : "old target would be restored by vendor timer";
        assert bridge.helper.disconnects == 1;
        assert bridge.connectedId == null;
        assert bridge.businessBinding.equals("owner-target") && bridge.systemBond.equals("system-bond");
        assert bridge.healthRecords == 134;

        bridge = fresh();
        bridge.recoveryTarget.initializeIdle(bridge.recoverySdk);
        assert BleFactory.getInstance().proxy.stored.isEmpty();
        assert bridge.helper.disconnects == 0 : "idle query must not stop a new scan";
        BleFactory.getInstance().proxy.stored = "late-old-target";
        BleFactory.getInstance().proxy.connect.address = "late-old-target";
        assert !bridge.recoveryTarget.acceptCallback(bridge.recoveryTarget.generation(), true, bridge.recoverySdk);
        assert BleFactory.getInstance().proxy.stored.isEmpty();
        assert bridge.helper.disconnects == 1;

        bridge = fresh();
        bridge.recoveryTarget.activate("authorized-target", bridge.recoverySdk);
        BleFactory.getInstance().proxy.refuseWrite = true;
        bridge.failConnect("CONNECT_CANCELLED", "cancelled");
        assert !bridge.recoveryTarget.isActive();
        assert bridge.helper.disconnects == 1 : "cache failure must not skip ordinary disconnect";
        assert !BleFactory.getInstance().proxy.stored.isEmpty() : "fixture must preserve cleanup-failure evidence";
    }
}
