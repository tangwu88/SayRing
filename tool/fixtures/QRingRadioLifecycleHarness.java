package cc.saidian.saydian_app;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Synthetic transport only; exercises unchanged production state-transition methods. */
public final class QRingRadioLifecycleHarness {
    static final class BluetoothAdapter {
        static final int ERROR = Integer.MIN_VALUE, STATE_OFF = 10, STATE_ON = 12, STATE_TURNING_OFF = 13;
        static int state = STATE_ON;
        int getState() { return state; }
        boolean isEnabled() { return state == STATE_ON; }
        BluetoothDevice getRemoteDevice(String id) { return new BluetoothDevice(); }
    }
    static final class BluetoothDevice {
        static final int ERROR = Integer.MIN_VALUE, BOND_NONE = 10, BOND_BONDING = 11, BOND_BONDED = 12;
        int getBondState() { return BOND_BONDED; }
    }
    static final class BluetoothManager { BluetoothAdapter getAdapter() { return new BluetoothAdapter(); } }
    static final class Context { static final String BLUETOOTH_SERVICE = "synthetic-service"; }
    static final class Activity { Object getSystemService(String name) { return new BluetoothManager(); } }
    static final class BleBaseControl {
        static final BleBaseControl instance = new BleBaseControl();
        String address = "synthetic-current";
        static BleBaseControl getInstance() { return instance; }
        String getmDeviceAddress() { return address; }
    }
    static final class DeviceManager {
        static final DeviceManager instance = new DeviceManager();
        static DeviceManager getInstance() { return instance; }
        void setDeviceAddress(String id) { BleBaseControl.instance.address = id; }
        void setDeviceName(String name) { }
    }
    static final class Manager {
        boolean connected = true, failDisconnect;
        int disconnects, connects;
        String lastTarget;
        boolean isConnected() { return connected; }
        void disconnect() { disconnects++; connected=false; if(failDisconnect)throw new SecurityException("synthetic denial"); }
        void connectDirectly(String id) { connects++; lastTarget=id; }
    }
    static final class Handler {
        final Set<Runnable> tasks = new HashSet<>();
        void removeCallbacks(Runnable r) { tasks.remove(r); }
        void postDelayed(Runnable r, long delay) { tasks.add(r); }
    }
    static final class MethodChannel {
        interface Result { void success(Object v); void error(String code,String message,Object details); }
    }
    static final class Reply implements MethodChannel.Result {
        int calls; String code;
        public void success(Object v) { calls++; }
        public void error(String code,String message,Object details) { calls++;this.code=code; }
    }
    final Activity activity = new Activity();
    final Handler main = new Handler();
    final Manager manager = new Manager();
    String connectedId="synthetic-current", connectedName="synthetic-ring";
    String recoveryTargetId=connectedId,recoveryTargetName=connectedName,recoveryContext="synthetic-owner";
    String firmwareVersion="old-firmware",hardwareVersion="old-hardware",batteryUpdatedAt="old-time";
    Integer batteryPercent=80; Boolean charging=true; long batteryQueryAt=100;
    Object setTimeFlags=new Object(),supportFlags=new Object(),pendingSync=new Object();
    String activeMeasurement="synthetic-metric",activeSportMode="synthetic-mode";
    Object activeSportType=new Object();
    Map<String,Object> pendingProfile,recoveryProfile;
    MethodChannel.Result pendingConnect,pendingDisconnect;
    Runnable connectDeadline=()->{},recoveryRetry;
    int connectionGeneration=4;
    static final long CONNECT_MS=35000L;
    boolean cancellingConnection,recoveryConnecting,handshakeStarted=true,bluetoothPowerUnavailable,permissions=true;
    final List<String> events=new ArrayList<>();
    int cameraResets,cameraFinishes;
    void resetRemoteCamera() { cameraResets++; }
    void finishCamera(Object value,String code,String message) { cameraFinishes++; }
    void failPendingSync(String code,String message) { pendingSync=null; }
    void failConnect(String code,String message) { throw new AssertionError("unexpected deadline"); }
    boolean hasBlePermissions() { return permissions; }
    boolean hasRetainedReadyGatt(String id) { return false; }
    void onServiceReady() { throw new AssertionError("no retained physical GATT in fixture"); }
    void emit(String event,Map<String,Object> value) {
        String id=(String)value.get("deviceId");
        check("synthetic-current".equals(id));events.add(event+":"+value.get("status"));
    }

    // PRODUCTION_METHODS

    static int checks;
    static void check(boolean value) { checks++;if(!value)throw new AssertionError("Radio lifecycle assertion failed at "+checks); }
    static QRingRadioLifecycleHarness fresh() { BluetoothAdapter.state=BluetoothAdapter.STATE_ON;BleBaseControl.instance.address="synthetic-current";return new QRingRadioLifecycleHarness(); }
    public static void main(String[] args) {
        QRingRadioLifecycleHarness b=fresh();check(b.resolved());
        // OEM reports physical radio loss but suppresses its application disconnect broadcast.
        BluetoothAdapter.state=BluetoothAdapter.STATE_OFF;b.manager.connected=false;
        b.onBluetoothState(BluetoothAdapter.STATE_OFF);
        check(b.connectedId==null && b.setTimeFlags==null && b.supportFlags==null);
        check(!b.resolved() && b.pendingSync==null && b.cameraResets==1 && b.cameraFinishes==1);
        check(b.connectionGeneration==5 && b.recoveryRetry==null && b.manager.disconnects==1);
        check("synthetic-current".equals(b.recoveryTargetId) && "synthetic-owner".equals(b.recoveryContext));
        check(b.events.contains("disconnected:null") && b.events.contains("recoveryState:bluetoothOff"));
        check(b.firmwareVersion.isEmpty() && b.batteryPercent==null);
        int emitted=b.events.size();
        b.onBluetoothState(BluetoothAdapter.STATE_TURNING_OFF);b.onBluetoothState(BluetoothAdapter.STATE_OFF);
        check(b.connectionGeneration==5 && b.manager.disconnects==1 && b.events.size()==emitted);
        b.onBluetoothState(BluetoothAdapter.STATE_ON);check(b.manager.connects==0 && b.bluetoothPowerUnavailable);
        BluetoothAdapter.state=BluetoothAdapter.STATE_ON;b.onBluetoothState(BluetoothAdapter.STATE_ON);
        check(b.manager.connects==1 && "synthetic-current".equals(b.manager.lastTarget));
        check(b.recoveryConnecting && b.connectionGeneration==6 && !b.handshakeStarted && !b.resolved());
        b.onBluetoothState(BluetoothAdapter.STATE_ON);check(b.manager.connects==1);
        // A queued old OFF cannot retire the newly available connection attempt.
        b.onBluetoothState(BluetoothAdapter.STATE_OFF);check(b.connectionGeneration==6 && b.manager.disconnects==1);
        b=fresh();BluetoothAdapter.state=BluetoothAdapter.STATE_OFF;b.onBluetoothState(BluetoothAdapter.STATE_OFF);
        b.recoveryTargetId=null;b.recoveryContext=null;BluetoothAdapter.state=BluetoothAdapter.STATE_ON;b.onBluetoothState(BluetoothAdapter.STATE_ON);check(b.manager.connects==0);
        b=fresh();BluetoothAdapter.state=BluetoothAdapter.STATE_OFF;b.onBluetoothState(BluetoothAdapter.STATE_OFF);
        b.permissions=false;BluetoothAdapter.state=BluetoothAdapter.STATE_ON;b.onBluetoothState(BluetoothAdapter.STATE_ON);check(b.manager.connects==0);
        b=fresh();BluetoothAdapter.state=BluetoothAdapter.STATE_OFF;Reply connect=new Reply();b.pendingConnect=connect;b.onBluetoothState(BluetoothAdapter.STATE_OFF);check(connect.calls==1 && "QRING_DISCONNECTED".equals(connect.code));
        b=fresh();BluetoothAdapter.state=BluetoothAdapter.STATE_OFF;Reply stop=new Reply();b.pendingDisconnect=stop;b.cancellingConnection=true;b.onBluetoothState(BluetoothAdapter.STATE_OFF);check(stop.calls==1 && !b.cancellingConnection);
        b=fresh();BleBaseControl.instance.address="synthetic-other";BluetoothAdapter.state=BluetoothAdapter.STATE_OFF;b.onBluetoothState(BluetoothAdapter.STATE_OFF);check(b.manager.disconnects==0 && b.connectedId==null);
        b=fresh();b.manager.failDisconnect=true;BluetoothAdapter.state=BluetoothAdapter.STATE_OFF;b.onBluetoothState(BluetoothAdapter.STATE_OFF);check(b.connectedId==null && "synthetic-current".equals(b.recoveryTargetId));
        b=fresh();BluetoothAdapter.state=BluetoothAdapter.STATE_OFF;check(!b.resolved());
        System.out.println("Production radio lifecycle assertions: "+checks);
    }
}
