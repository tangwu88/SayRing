package cc.saidian.saydian_app;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Host-only synthetic transitions through the production bridge methods. */
public final class QRingConnectionStateHarness {
    static final class BluetoothDevice {
        static final int BOND_NONE = 10, BOND_BONDING = 11, BOND_BONDED = 12;
    }
    String connectedId = "synthetic-current", connectedName = "synthetic-ring";
    String recoveryTargetId = connectedId, recoveryContext = "synthetic-owner";
    String firmwareVersion = "old-firmware", hardwareVersion = "old-hardware";
    Integer batteryPercent = 80;
    Boolean charging = true;
    String batteryUpdatedAt = "old-time";
    long batteryQueryAt = 100L;
    int connectionGeneration = 4;
    boolean recoveryConnecting = true, cancellingConnection;
    final List<String> events = new ArrayList<>();
    void emit(String type, Map<String, Object> payload) {
        check(type.equals("recoveryState") && connectedId.equals(payload.get("deviceId")));
        events.add((String) payload.get("status"));
    }

    // PRODUCTION_METHODS

    static int checks;
    static void check(boolean value) {
        checks++;
        if (!value) throw new AssertionError("Connection state assertion failed at " + checks);
    }
    public static void main(String[] args) {
        QRingConnectionStateHarness b = new QRingConnectionStateHarness();
        b.onBondState(4, b.connectedId, 11, 10);
        b.onBondState(4, b.connectedId, 12, 11);
        b.onBondState(4, b.connectedId, 10, 11);
        check(b.events.equals(List.of("pairing", "connecting", "pairingFailed")));
        b.events.clear();
        b.onBondState(3, b.connectedId, 11, 10);
        b.onBondState(4, "synthetic-other", 11, 10);
        b.onBondState(4, b.connectedId, 10, 10);
        check(b.events.isEmpty());
        b.cancellingConnection = true;
        b.onBondState(4, b.connectedId, 11, 10);
        b.cancellingConnection = false;
        b.recoveryContext = null;
        b.onBondState(4, b.connectedId, 11, 10);
        b.recoveryContext = "synthetic-owner";
        b.recoveryTargetId = "synthetic-replaced";
        b.onBondState(4, b.connectedId, 11, 10);
        b.recoveryTargetId = b.connectedId;
        b.recoveryConnecting = false;
        b.onBondState(4, b.connectedId, 11, 10);
        check(b.events.isEmpty());
        check(b.deviceDetails().containsKey("firmwareVersion"));
        b.resetDeviceDetails();
        b.connectedId = "synthetic-new";
        Map<String, Object> details = b.deviceDetails();
        check(details.get("id").equals("synthetic-new"));
        check(!details.containsKey("firmwareVersion") && !details.containsKey("serialNumber"));
        check(!details.containsKey("battery") && !details.containsKey("batteryPercent"));
        check(b.batteryQueryAt == 0L && b.batteryUpdatedAt == null && b.charging == null);
        b.firmwareVersion = "new-firmware";
        b.batteryPercent = 40;
        check(b.deviceDetails().get("firmwareVersion").equals("new-firmware"));
        b.resetDeviceDetails();
        check(!b.deviceDetails().containsKey("firmwareVersion"));
        System.out.println("Production Android connection state assertions: " + checks);
    }
}
