import java.util.*;

public class CoolWearSystemTargetTest {
    static class BluetoothProfile { static final int GATT = 7; }
    static class BluetoothDevice {
        static final int BOND_BONDED = 12;
        final String id, name;
        boolean bonded;
        BluetoothDevice(String id, String name) { this.id = id; this.name = name; }
        String getAddress() { return id; }
        String getName() { return name; }
        int getBondState() { return bonded ? BOND_BONDED : 10; }
    }
    static class Adapter {
        Set<BluetoothDevice> bonds = new HashSet<>();
        Set<BluetoothDevice> getBondedDevices() { return bonds; }
    }
    static class BluetoothManager {
        Adapter adapter = new Adapter();
        List<BluetoothDevice> gatt = new ArrayList<>();
        List<BluetoothDevice> getConnectedDevices(int profile) {
            check(profile == BluetoothProfile.GATT); return gatt;
        }
        Adapter getAdapter() { return adapter; }
    }
    static class Context { static final String BLUETOOTH_SERVICE = "bluetooth"; }
    static class Activity {
        final BluetoothManager manager = new BluetoothManager();
        Object getSystemService(String key) { return manager; }
    }
    private final Activity activity = new Activity();
    private final Map<String, Map<String, Object>> scanned = new HashMap<>();
    static String supportedModel(String name) { return "R7 Ultra".equals(name) ? name : null; }

    // PRODUCTION_METHODS

    static void check(boolean condition) { if (!condition) throw new AssertionError(); }
    public static void main(String[] ignored) {
        CoolWearSystemTargetTest t = new CoolWearSystemTargetTest();
        BluetoothManager os = t.activity.manager;
        String wire = "aa:bb:cc:dd:ee:ff", mac = wire.toUpperCase(Locale.ROOT);
        BluetoothDevice target = new BluetoothDevice(mac, "R7 Ultra");
        BluetoothDevice other = new BluetoothDevice("11:22:33:44:55:66", "R7 Ultra");
        os.gatt.add(other);
        os.gatt.add(new BluetoothDevice(mac, "R21"));
        check(t.findExactSystemTarget(wire, true) == null);
        os.gatt.add(target);
        check(t.findExactSystemTarget("malformed", true) == null);
        check(t.findExactSystemTarget(wire, false) == null);
        Map<String,Object> verified = t.findExactSystemTarget(wire, true);
        check(verified.get("id").equals(wire) && verified.get("hardwareAddress").equals(mac));
        check(!Boolean.TRUE.equals(verified.get("bonded")));
        verified.put("ownedSystemTarget", true);
        t.scanned.put(wire, verified);
        check(t.currentConnectCandidate(wire) != null);
        os.gatt.clear();
        check(t.currentConnectCandidate(wire) == null);
        os.adapter.bonds.add(target);
        check(t.findExactSystemTarget(wire, true) == null);
        target.bonded = true;
        check(Boolean.TRUE.equals(t.findExactSystemTarget(wire, false).get("bonded")));
        Map<String,Object> advertised = new HashMap<>();
        t.scanned.put("fresh", advertised);
        check(t.currentConnectCandidate("fresh") == advertised);
    }
}
