package cc.saidian.saydian_app;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import androidx.core.content.ContextCompat;

import com.oudmon.ble.base.bean.SleepDisplay;
import com.oudmon.ble.base.bluetooth.BleAction;
import com.oudmon.ble.base.bluetooth.BleBaseControl;
import com.oudmon.ble.base.bluetooth.BleOperateManager;
import com.oudmon.ble.base.bluetooth.DeviceManager;
import com.oudmon.ble.base.bluetooth.QCBluetoothCallbackCloneReceiver;
import com.oudmon.ble.base.communication.CommandHandle;
import com.oudmon.ble.base.communication.ICommandResponse;
import com.oudmon.ble.base.communication.LargeDataHandler;
import com.oudmon.ble.base.communication.Constants;
import com.oudmon.ble.base.communication.bigData.BloodOxygenEntity;
import com.oudmon.ble.base.communication.bigData.bean.IntervalTemperatureEntity;
import com.oudmon.ble.base.communication.entity.BleStepDetails;
import com.oudmon.ble.base.communication.req.BloodOxygenSettingReq;
import com.oudmon.ble.base.communication.req.BaseReqCmd;
import com.oudmon.ble.base.communication.req.CameraReq;
import com.oudmon.ble.base.communication.req.DeviceSupportReq;
import com.oudmon.ble.base.communication.req.FindDeviceReq;
import com.oudmon.ble.base.communication.req.RestoreKeyReq;
import com.oudmon.ble.base.communication.req.TargetSettingReq;
import com.oudmon.ble.base.communication.rsp.TargetSettingRsp;
import com.oudmon.ble.base.communication.req.HeartRateSettingReq;
import com.oudmon.ble.base.communication.req.HrvSettingReq;
import com.oudmon.ble.base.communication.req.PhoneSportReq;
import com.oudmon.ble.base.communication.req.PressureSettingReq;
import com.oudmon.ble.base.communication.req.SetTimeReq;
import com.oudmon.ble.base.communication.req.SimpleKeyReq;
import com.oudmon.ble.base.communication.req.SugarLipidsSettingReq;
import com.oudmon.ble.base.communication.req.TimeFormatReq;
import com.oudmon.ble.base.communication.req.TouchControlReq;
import com.oudmon.ble.base.communication.rsp.AppSportRsp;
import com.oudmon.ble.base.communication.rsp.BaseRspCmd;
import com.oudmon.ble.base.communication.rsp.BatteryRsp;
import com.oudmon.ble.base.communication.rsp.BloodOxygenSettingRsp;
import com.oudmon.ble.base.communication.rsp.CameraNotifyRsp;
import com.oudmon.ble.base.communication.rsp.DeviceSupportFunctionRsp;
import com.oudmon.ble.base.communication.rsp.HRVRsp;
import com.oudmon.ble.base.communication.rsp.HRVSettingRsp;
import com.oudmon.ble.base.communication.rsp.HeartRateSettingRsp;
import com.oudmon.ble.base.communication.rsp.PressureRsp;
import com.oudmon.ble.base.communication.rsp.PressureSettingRsp;
import com.oudmon.ble.base.communication.rsp.ReadHeartRateRsp;
import com.oudmon.ble.base.communication.rsp.SetTimeRsp;
import com.oudmon.ble.base.communication.rsp.StartHeartRateRsp;
import com.oudmon.ble.base.communication.rsp.BloodSugarLipidsSettingRsp;
import com.oudmon.ble.base.communication.rsp.TimeFormatRsp;
import com.oudmon.ble.base.communication.rsp.TouchControlResp;
import com.oudmon.ble.base.communication.sport.SportPlusEntity;
import com.oudmon.ble.base.scan.BleScannerHelper;
import com.oudmon.ble.base.scan.ScanRecord;
import com.oudmon.ble.base.scan.ScanWrapperCallback;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Native Android adapter for QRing SDK 1.0.0.76. */
public final class QRingBridge
        implements MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private static final String TAG = "QRingBridge";
    private static final long SCAN_MS = 10_000L;
    private static final long CONNECT_MS = 35_000L;
    private static final long DISCONNECT_MS = 15_000L;
    private static final long SYNC_MS = 165_000L;

    private final Activity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final LinkedHashMap<String, Map<String, Object>> scanned = new LinkedHashMap<>();
    private final LinkedHashMap<String, Map<String, Object>> syncRecords = new LinkedHashMap<>();
    private final QRingHistoryReadState historyReads = new QRingHistoryReadState();
    private EventChannel.EventSink sink;
    private BleOperateManager manager;
    private QCBluetoothCallbackCloneReceiver receiver;
    private boolean receiverRegistered;
    private MethodChannel.Result pendingScan;
    private MethodChannel.Result pendingConnect;
    private MethodChannel.Result pendingSync;
    private Runnable scanDeadline;
    private long scanGeneration;
    private Runnable connectDeadline;
    private Runnable disconnectDeadline;
    private Runnable syncDeadline;
    private String connectedId;
    private String connectedName;
    private String firmwareVersion = "";
    private String hardwareVersion = "";
    private Integer batteryPercent;
    private Boolean charging;
    private SetTimeRsp setTimeFlags;
    private DeviceSupportFunctionRsp supportFlags;
    private Map<String, Object> pendingProfile;
    private String activeMeasurement;
    private int measurementOperation;
    private String activeSportMode;
    private Integer activeSportType;
    private boolean manualResultEmitted;
    private Boolean autoHeart;
    private Boolean autoOxygen;
    private Boolean autoStress;
    private Boolean autoHrv;
    private Boolean autoTemperature;
    private int connectionGeneration;
    private int monitoringPoisonGeneration = -1;
    private String batteryUpdatedAt;
    private long batteryQueryAt;
    private String recoveryTargetId;
    private String recoveryTargetName;
    private String recoveryContext;
    private Integer factoryResetGeneration;
    private Integer factoryInitializingGeneration;
    private Map<String, Object> recoveryProfile;
    private boolean recoveryConnecting;
    private boolean cancellingConnection;
    private boolean handshakeStarted;
    private MethodChannel.Result pendingDisconnect;
    private Runnable recoveryRetry;
    private MethodChannel.Result pendingCamera;
    private int cameraOperation;
    private int cameraPhase;
    private final QRingControlChannelState controlChannels = new QRingControlChannelState();
    private QRingControlChannelState.Channel pendingControlChannel = QRingControlChannelState.Channel.HID;
    private void traceControl(String stage) {
        if (BuildConfig.DEBUG) Log.i("SayRingControl", stage);
    }
    private boolean remoteCameraSupported;
    private boolean remoteCameraActive;
    private int remoteCameraEpoch;
    private Runnable remoteCameraKeepAlive;

    // Photo UI (command 0x02) is separate from persistent HID photo mode 5.
    // Probe both enter and exit ACKs before advertising this device capability.
    private void probeRemoteCamera(Runnable completion) {
        remoteCameraSupported = false;
        final int connection = connectionGeneration;
        final String id = connectedId;
        final int operation = ++cameraOperation;
        final boolean[] done = {false};
        Runnable finish = () -> {
            if (done[0] || operation != cameraOperation || !isCurrentConnection(connection, id)) return;
            done[0] = true;
            cameraOperation++;
            completion.run();
        };
        if (supportFlags == null || (!supportFlags.supportGesture && !supportFlags.supportTouch)) {
            finish.run(); return;
        }
        main.postDelayed(() -> {
            if (!done[0] && operation == cameraOperation) {
                controlChannels.block(QRingControlChannelState.Channel.PHOTO_UI, connection);
                finish.run();
            }
        }, 8_000L);
        CommandHandle.getInstance().executeReqCmd(new CameraReq(CameraReq.ACTION_INTO_CAMARA_UI),
                (ICommandResponse<BaseRspCmd>) response -> main.post(() -> {
                    if (done[0] || operation != cameraOperation || !isCurrentConnection(connection, id)) return;
                    final boolean accepted = response != null && response.getStatus() == BaseRspCmd.RESULT_OK;
                    CommandHandle.getInstance().executeReqCmd(new CameraReq(CameraReq.ACTION_FINISH),
                            (ICommandResponse<BaseRspCmd>) exit -> main.post(() -> {
                                if (done[0] || operation != cameraOperation || !isCurrentConnection(connection, id)) return;
                                remoteCameraSupported = accepted && exit != null && exit.getStatus() == BaseRspCmd.RESULT_OK;
                                finish.run();
                            }));
                }));
    }

    private void resetRemoteCamera() {
        boolean wasActive = remoteCameraActive;
        remoteCameraActive = false;
        remoteCameraEpoch++;
        if (remoteCameraKeepAlive != null) main.removeCallbacks(remoteCameraKeepAlive);
        remoteCameraKeepAlive = null;
        if (manager != null) manager.removeNotifyListener(Constants.CMD_TAKING_PICTURE);
        if (wasActive && connectedId != null) {
            Map<String, Object> event = new HashMap<>();
            event.put("deviceId", connectedId);
            emit("cameraRemoteStopped", event);
        }
    }

    private void stopRemoteCamera(MethodChannel.Result result) {
        resetRemoteCamera();
        final int connection = connectionGeneration;
        final String id = connectedId;
        final long deadline = SystemClock.elapsedRealtime() + 8_000L;
        waitToStopCamera(result, connection, id, deadline);
    }

    private void waitToStopCamera(MethodChannel.Result result, int connection, String id, long deadline) {
        if (!isCurrentConnection(connection, id) || !resolved()) { result.success(null); return; }
        if (pendingCamera != null && SystemClock.elapsedRealtime() < deadline) {
            main.postDelayed(() -> waitToStopCamera(result, connection, id, deadline), 100L); return;
        }
        remoteCameraCommand(CameraReq.ACTION_FINISH, result);
    }

    private void scheduleCameraKeepAlive(int epoch) {
        remoteCameraKeepAlive = () -> {
            if (epoch != remoteCameraEpoch || !remoteCameraActive || !resolved()) return;
            remoteCameraCommand(CameraReq.ACTION_KEEP_SCREEN_ON, new MethodChannel.Result() {
                public void success(Object value) { if (epoch == remoteCameraEpoch) scheduleCameraKeepAlive(epoch); }
                public void error(String code, String message, Object details) { resetRemoteCamera(); }
                public void notImplemented() { resetRemoteCamera(); }
            });
        };
        main.postDelayed(remoteCameraKeepAlive, 10_000L);
    }

    private void remoteCameraCommand(byte action, MethodChannel.Result result) {
        final boolean entering = action == CameraReq.ACTION_INTO_CAMARA_UI;
        if (!entering && action == CameraReq.ACTION_FINISH) resetRemoteCamera();
        if (!resolved() || (entering && !remoteCameraSupported)) {
            if (!entering) { result.success(null); return; }
            result.error("QRING_FEATURE_UNVERIFIED", "此戒指未确认支持相机遥控", null); return;
        }
        if (pendingCamera != null || pendingSync != null || activeMeasurement != null || activeSportType != null) {
            result.error("DEVICE_BUSY", "设备忙，请稍后重试", null); return;
        }
        if (controlChannels.blocked(QRingControlChannelState.Channel.PHOTO_UI, connectionGeneration)) {
            result.error("QRING_CONTROL_UNCONFIRMED", "相机遥控未确认，请重新连接", null); return;
        }
        pendingCamera = result;
        pendingControlChannel = QRingControlChannelState.Channel.PHOTO_UI;
        final int operation = ++cameraOperation;
        final int connection = connectionGeneration;
        final String id = connectedId;
        final int epoch = remoteCameraEpoch;
        main.postDelayed(() -> {
            if (!currentCamera(operation, connection, id)) return;
            controlChannels.block(QRingControlChannelState.Channel.PHOTO_UI, connection);
            resetRemoteCamera();
            finishCamera(null, "QRING_CONTROL_UNCONFIRMED", "相机遥控未确认，请重新连接");
        }, 8_000L);
        CommandHandle.getInstance().executeReqCmd(new CameraReq(action),
                (ICommandResponse<BaseRspCmd>) response -> main.post(() -> {
                    if (!currentCamera(operation, connection, id)) return;
                    if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK) {
                        resetRemoteCamera();
                        finishCamera(null, "QRING_ACTION_FAILED", "相机遥控未开启，请重试"); return;
                    }
                    if (entering && epoch == remoteCameraEpoch) {
                        remoteCameraActive = true;
                        manager.addNotifyListener(Constants.CMD_TAKING_PICTURE,
                                (ICommandResponse<CameraNotifyRsp>) notification -> main.post(() -> {
                            if (!remoteCameraActive || epoch != remoteCameraEpoch || !isCurrentConnection(connection, id)
                                    || notification == null || notification.getStatus() != BaseRspCmd.RESULT_OK) return;
                            if (notification.getAction() == CameraNotifyRsp.ACTION_TAKE_PHOTO) {
                                Map<String, Object> event = new HashMap<>();
                                event.put("deviceId", id);
                                emit("cameraShutter", event);
                            } else if (notification.getAction() == CameraNotifyRsp.ACTION_FINISH) {
                                resetRemoteCamera();
                            }
                        }));
                        scheduleCameraKeepAlive(epoch);
                    }
                    finishCamera(null, null, null);
                }));
    }

    public QRingBridge(Activity activity, BinaryMessenger messenger) {
        this.activity = activity;
        new MethodChannel(messenger, "cc.saidian.ring/qring/commands")
                .setMethodCallHandler(this);
        new EventChannel(messenger, "cc.saidian.ring/qring/events")
                .setStreamHandler(this);
    }

    private void ensureSdk() {
        if (manager != null) return;
        manager = BleOperateManager.getInstance(activity.getApplication());
        manager.init();
        manager.setManualMeasurementDefaultValuesEnabled(false);
        // App-scoped exact bindings, never the SDK's installation-wide target.
        manager.setAutoReconnectEnabled(false);
        receiver = new QCBluetoothCallbackCloneReceiver() {
            @Override public void connectStatue(BluetoothDevice device, boolean connected) {
                main.post(() -> onConnectionState(device, connected));
            }

            @Override public void onServiceDiscovered() {
                main.post(QRingBridge.this::onServiceReady);
            }

            @Override public void onCharacteristicRead(String uuid, byte[] data) {
                main.post(() -> onCharacteristic(uuid, data));
            }
        };
        ContextCompat.registerReceiver(
                activity.getApplicationContext(), receiver, BleAction.getIntentFilter(),
                ContextCompat.RECEIVER_NOT_EXPORTED);
        receiverRegistered = true;
    }

    private boolean hasBlePermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return activity.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)
                            == PackageManager.PERMISSION_GRANTED
                    && activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                            == PackageManager.PERMISSION_GRANTED;
        }
        return activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
    }

    private boolean isBluetoothEnabled() {
        BluetoothManager bluetooth =
                (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        return bluetooth != null && bluetooth.getAdapter() != null
                && bluetooth.getAdapter().isEnabled();
    }

    static boolean isQRingName(String name) {
        return RingNamePolicy.isQRingName(name);
    }

    static String resolveScanName(String cachedName, String advertisedName) {
        if (isQRingName(advertisedName)) return advertisedName.trim();
        if (isQRingName(cachedName)) return cachedName.trim();
        return null;
    }

    static boolean isExactBondedQRing(String requestedId, String bondedId, String name) {
        return requestedId != null && bondedId != null
                && requestedId.equalsIgnoreCase(bondedId) && isQRingName(name);
    }

    static boolean isValidBluetoothAddress(String id) {
        return id != null && id.matches("(?i)(?:[0-9A-F]{2}:){5}[0-9A-F]{2}");
    }

    private void startScan(MethodChannel.Result result) {
        if (!hasBlePermissions()) {
            result.error("BLE_PERMISSION_REQUIRED", "请允许附近设备权限后重试", null);
            return;
        }
        if (!isBluetoothEnabled()) {
            result.error("BLUETOOTH_OFF", "请先开启手机蓝牙", null);
            return;
        }
        finishScan(); // stop/reset the previous OEM scan even after a failure.
        final long generation = ++scanGeneration;
        scanned.clear();
        pendingScan = result;
        BleScannerHelper.getInstance().reSetCallback();
        try { BleScannerHelper.getInstance().scanDevice(activity, null, new ScanWrapperCallback() {
            @Override public void onStart() { }
            @Override public void onStop() { main.post(() -> {
                if (generation == scanGeneration && pendingScan != null) finishScan();
            }); }
            @Override public void onScanFailed(int errorCode) {
                main.post(() -> { if (generation == scanGeneration && pendingScan != null)
                    failScan("QRING_SCAN_FAILED", "蓝牙扫描失败，请稍后重试（" + errorCode + "）"); });
            }
            // onLeScan carries the same advertisement plus RSSI; handle both there.
            @Override public void onParsedData(BluetoothDevice device, ScanRecord record) { }
            @Override public void onBatchScanResults(List<ScanResult> results) {
                if (results == null) return;
                for (ScanResult item : results) {
                    if (item == null) continue;
                    final String name = item.getScanRecord() == null ? null : item.getScanRecord().getDeviceName();
                    main.post(() -> { if (generation == scanGeneration && pendingScan != null)
                        receiveScan(item.getDevice(), item.getRssi(), name); });
                }
            }

            @Override public void onLeScan(BluetoothDevice device, int rssi, byte[] scanRecord) {
                if (device == null) return;
                String name = null;
                if (scanRecord != null) {
                    try {
                        ScanRecord parsed = ScanRecord.parseFromBytes(scanRecord);
                        if (parsed != null) name = parsed.getDeviceName();
                    } catch (RuntimeException ignored) { }
                }
                final String advertisedName = name;
                main.post(() -> { if (generation == scanGeneration && pendingScan != null)
                    receiveScan(device, rssi, advertisedName); });
            }
        }); } catch (RuntimeException error) {
            failScan("QRING_SCAN_FAILED", "蓝牙扫描无法开始，请检查权限与蓝牙后重试");
            return;
        }
        scanDeadline = () -> { if (generation == scanGeneration) finishScan(); };
        main.postDelayed(scanDeadline, SCAN_MS);
    }

    private void receiveScan(BluetoothDevice device, int rssi, String advertisedName) {
        if (pendingScan == null || device == null) return;
        String cachedName;
        try {
            cachedName = device.getName();
        } catch (SecurityException error) {
            if (pendingCamera != null) {
                controlChannels.block(pendingControlChannel, connectionGeneration);
                finishCamera(null, "BLE_PERMISSION_REQUIRED", "蓝牙权限已变化，请重新允许");
                return;
            }
            failScan("BLE_PERMISSION_REQUIRED", "蓝牙权限已变化，请重新允许");
            return;
        }
        String name = resolveScanName(cachedName, advertisedName);
        String id = device.getAddress();
        if (name == null || id == null || id.isEmpty()) return;
        Map<String, Object> value = new HashMap<>();
        value.put("id", id);
        value.put("name", name);
        value.put("model", name);
        value.put("hardwareAddress", id);
        value.put("rssi", rssi);
        boolean fresh = !scanned.containsKey(id);
        scanned.put(id, value);
        if (fresh) emit("scanDevice", value);
    }

    private void lookupBondedDevice(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id");
        if (id == null || id.isEmpty() || !hasBlePermissions()) {
            result.success(null);
            return;
        }
        BluetoothManager bluetooth =
                (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetooth == null || bluetooth.getAdapter() == null) {
            result.success(null);
            return;
        }
        for (BluetoothDevice device : bluetooth.getAdapter().getBondedDevices()) {
            if (!id.equalsIgnoreCase(device.getAddress())) continue;
            String name = device.getName();
            if (!isExactBondedQRing(id, device.getAddress(), name)) break;
            Map<String, Object> value = new HashMap<>();
            value.put("id", id);
            value.put("name", name.trim());
            value.put("model", name.trim());
            value.put("hardwareAddress", id);
            value.put("bonded", true);
            scanned.put(id, value);
            result.success(value);
            return;
        }
        result.success(null);
    }

    private void listBondedDevices(MethodChannel.Result result) {
        if (!hasBlePermissions()) {
            result.error("BLE_PERMISSION_REQUIRED", "请允许附近设备权限后重试", null);
            return;
        }
        if (!isBluetoothEnabled()) {
            result.error("BLUETOOTH_OFF", "请先开启手机蓝牙", null);
            return;
        }
        BluetoothManager bluetooth =
                (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetooth == null || bluetooth.getAdapter() == null) {
            result.success(new ArrayList<>());
            return;
        }
        List<Map<String, Object>> values = new ArrayList<>();
        for (BluetoothDevice device : bluetooth.getAdapter().getBondedDevices()) {
            String id = device.getAddress();
            String name = device.getName();
            if (id == null || id.isEmpty() || !isQRingName(name)) continue;
            Map<String, Object> value = new HashMap<>();
            value.put("id", id);
            value.put("name", name.trim());
            value.put("model", name.trim());
            value.put("hardwareAddress", id);
            value.put("bonded", true);
            scanned.put(id, value);
            values.add(value);
        }
        result.success(values);
    }

    private void prepareRememberedDevice(MethodCall call, MethodChannel.Result result) {
        if (!hasBlePermissions()) {
            result.error("BLE_PERMISSION_REQUIRED", "请允许附近设备权限后重试", null);
            return;
        }
        if (!isBluetoothEnabled()) {
            result.error("BLUETOOTH_OFF", "请先开启手机蓝牙", null);
            return;
        }
        String id = call.argument("id");
        String knownName = call.argument("name");
        if (!isValidBluetoothAddress(id)) {
            result.success(null);
            return;
        }
        String displayName = isQRingName(knownName)
                ? knownName.trim() : "上次连接的 QRing 戒指";
        Map<String, Object> value = new HashMap<>();
        value.put("id", id);
        value.put("name", displayName);
        value.put("model", isQRingName(knownName) ? knownName.trim() : "QRing");
        value.put("hardwareAddress", id);
        value.put("remembered", true);
        scanned.put(id, value);
        result.success(value);
    }

    private boolean remainsBondedQRing(String id, String expectedName) {
        BluetoothManager bluetooth =
                (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetooth == null || bluetooth.getAdapter() == null) return false;
        for (BluetoothDevice device : bluetooth.getAdapter().getBondedDevices()) {
            if (!isExactBondedQRing(id, device.getAddress(), device.getName())) continue;
            return expectedName == null
                    || expectedName.trim().equalsIgnoreCase(device.getName().trim());
        }
        return false;
    }

    private void finishScan() {
        ++scanGeneration; // invalidate posted callbacks before stopping the OEM singleton.
        if (scanDeadline != null) main.removeCallbacks(scanDeadline);
        scanDeadline = null;
        try {
            BleScannerHelper.getInstance().stopScan(activity);
        } catch (RuntimeException ignored) { }
        if (pendingScan == null) return;
        MethodChannel.Result result = pendingScan;
        pendingScan = null;
        result.success(new ArrayList<>(scanned.values()));
    }

    private void failScan(String code, String message) {
        if (pendingScan == null) return;
        MethodChannel.Result result = pendingScan;
        pendingScan = null;
        finishScan();
        result.error(code, message, null);
    }

    @SuppressWarnings("unchecked")
    private void connect(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id");
        Map<String, Object> profile = call.argument("profile");
        Map<String, Object> scannedDevice = scanned.get(id);
        boolean remembered = scannedDevice != null
                && Boolean.TRUE.equals(scannedDevice.get("remembered"));
        if (id == null || scannedDevice == null
                || (!isQRingName(String.valueOf(scannedDevice.get("name")))
                    && !(remembered && isValidBluetoothAddress(id)))) {
            result.error("QRING_DEVICE_UNVERIFIED", "请重新搜索并选择 QRing 戒指", null);
            return;
        }
        if (Boolean.TRUE.equals(scannedDevice.get("bonded"))
                && !remainsBondedQRing(id, String.valueOf(scannedDevice.get("name")))) {
            scanned.remove(id);
            result.error("QRING_BOND_CHANGED", "系统配对信息已变化，请重新选择戒指", null);
            return;
        }
        if (pendingConnect != null || recoveryConnecting || cancellingConnection) {
            result.error("CONNECT_BUSY", "戒指正在连接，请稍候", null);
            return;
        }
        finishScan();
        connectedId = id;
        connectedName = String.valueOf(scannedDevice.get("name"));
        pendingProfile = profile == null ? new HashMap<>() : new HashMap<>(profile);
        setTimeFlags = null;
        supportFlags = null;
        batteryPercent = null;
        charging = null;
        pendingConnect = result;
        connectionGeneration++;
        handshakeStarted = false;
        DeviceManager.getInstance().setDeviceAddress(id);
        DeviceManager.getInstance().setDeviceName(connectedName);
        manager.connectDirectly(id);
        connectDeadline = () -> failConnect(
                "QRING_CONNECT_TIMEOUT", "戒指连接或能力读取超时，请靠近手机后重试");
        main.postDelayed(connectDeadline, CONNECT_MS);
    }

    private void onConnectionState(BluetoothDevice device, boolean connected) {
        if (device != null && (connectedId == null
                || !connectedId.equalsIgnoreCase(device.getAddress()))) return;
        if (connected) {
            if (cancellingConnection || connectedId == null) return;
            if (device != null) {
                connectedId = device.getAddress();
                try {
                    if (device.getName() != null) connectedName = device.getName();
                } catch (SecurityException ignored) { }
                DeviceManager.getInstance().setDeviceAddress(connectedId);
                DeviceManager.getInstance().setDeviceName(connectedName);
            }
            return;
        }
        finishDisconnectedSession();
    }

    private void finishDisconnectedSession() {
        resetRemoteCamera();
        remoteCameraSupported = false;
        finishCamera(null, "QRING_DISCONNECTED", "戒指已断开");
        String retired = connectedId;
        connectionGeneration++;
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        recoveryConnecting = false;
        handshakeStarted = false;
        setTimeFlags = null;
        supportFlags = null;
        activeMeasurement = null;
        activeSportMode = null;
        activeSportType = null;
        failPendingSync("CONNECTION_DROPPED", "戒指连接中断，请靠近手机后重试");
        if (pendingConnect != null) {
            MethodChannel.Result pending = pendingConnect;
            pendingConnect = null;
            pending.error("QRING_DISCONNECTED", "戒指连接中断，请靠近手机后重试", null);
        } else if (retired != null) {
            Map<String, Object> value = new HashMap<>();
            value.put("deviceId", retired);
            emit("disconnected", value);
        }
        connectedId = null;
        if (pendingDisconnect != null) {
            MethodChannel.Result pending = pendingDisconnect;
            pendingDisconnect = null;
            cancellingConnection = false;
            pending.success(null);
        } else if (cancellingConnection) {
            cancellingConnection = false;
        }
        scheduleRecoveryRetry();
    }

    private boolean isCurrentConnection(int generation, String id) {
        return generation == connectionGeneration && !cancellingConnection
                && id != null && id.equalsIgnoreCase(connectedId);
    }

    private void scheduleRecoveryRetry() {
        if (recoveryRetry != null) main.removeCallbacks(recoveryRetry);
        if (recoveryTargetId == null || recoveryContext == null) return;
        recoveryRetry = () -> { recoveryRetry = null; startAutomaticRecovery(); };
        main.postDelayed(recoveryRetry, 5_000L);
    }

    private void startAutomaticRecovery() {
        if (recoveryTargetId == null || recoveryContext == null || resolved()
                || pendingConnect != null || pendingDisconnect != null
                || cancellingConnection || recoveryConnecting
                || !hasBlePermissions() || !isBluetoothEnabled()) return;
        connectedId = recoveryTargetId;
        connectedName = recoveryTargetName;
        pendingProfile = recoveryProfile == null ? new HashMap<>() : new HashMap<>(recoveryProfile);
        setTimeFlags = null;
        supportFlags = null;
        recoveryConnecting = true;
        handshakeStarted = false;
        final int generation = ++connectionGeneration;
        DeviceManager.getInstance().setDeviceAddress(connectedId);
        DeviceManager.getInstance().setDeviceName(connectedName);
        Map<String, Object> value = new HashMap<>();
        value.put("status", "waiting");
        value.put("deviceId", connectedId);
        emit("recoveryState", value);
        manager.connectDirectly(connectedId);
        connectDeadline = () -> {
            if (generation == connectionGeneration) {
                failConnect("QRING_CONNECT_TIMEOUT", "戒指暂时不在附近，靠近后会自动重连");
            }
        };
        main.postDelayed(connectDeadline, CONNECT_MS);
    }

    @SuppressWarnings("unchecked")
    private void configureRecoveryTarget(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id");
        if (id == null || id.isEmpty()) {
            recoveryTargetId = null;
            recoveryContext = null;
            if (recoveryRetry != null) main.removeCallbacks(recoveryRetry);
            recoveryRetry = null;
            if (recoveryConnecting && !resolved()) disconnectWithResult(result);
            else { recoveryConnecting = false; result.success(null); }
            return;
        }
        String name = call.argument("name");
        String context = call.argument("context");
        if (!isValidBluetoothAddress(id) || !isQRingName(name)
                || context == null || context.isEmpty()) {
            result.error("QRING_DEVICE_UNVERIFIED", "保存的戒指信息无效，请重新添加", null); return;
        }
        if (cancellingConnection || (recoveryConnecting && (!id.equalsIgnoreCase(recoveryTargetId)
                || !context.equals(recoveryContext)))) {
            result.error("RECOVERY_PENDING", "请先结束上一台戒指的连接", null); return;
        }
        recoveryTargetId = id;
        recoveryTargetName = name;
        recoveryContext = context;
        Map<String, Object> profile = call.argument("profile");
        recoveryProfile = profile == null ? new HashMap<>() : new HashMap<>(profile);
        int phase = factoryInitialization(id, context);
        if (resolved() && id.equalsIgnoreCase(connectedId) && phase != 0 && (phase & 4) == 0 &&
                !Integer.valueOf(connectionGeneration).equals(factoryResetGeneration)) {
            if (Integer.valueOf(connectionGeneration).equals(factoryInitializingGeneration)) {
                result.error("DEVICE_BUSY", "戒指正在初始化，请稍候", null); return;
            }
            final int generation = connectionGeneration;
            factoryInitializingGeneration = generation;
            pendingProfile = new HashMap<>(recoveryProfile);
            final boolean[] done = {false};
            Runnable finish = () -> {
                if (done[0]) return;
                done[0] = true;
                if (Integer.valueOf(generation).equals(factoryInitializingGeneration)) factoryInitializingGeneration = null;
                if (currentFactoryTarget(generation, id, context)) {
                    emit("capabilitiesUpdated", capabilities()); emitFactoryInitialization();
                }
                result.success(null);
            };
            main.postDelayed(finish, 12_000L);
            writeProfileWithCompletion(finish);
            return;
        }
        startAutomaticRecovery();
        result.success(null);
    }

    private void disconnectWithResult(MethodChannel.Result result) {
        recoveryTargetId = null;
        recoveryContext = null;
        if (recoveryRetry != null) main.removeCallbacks(recoveryRetry);
        recoveryRetry = null;
        if (pendingDisconnect != null || cancellingConnection) {
            result.error("RECOVERY_PENDING", "蓝牙连接正在结束，请稍候", null); return;
        }
        connectionGeneration++;
        recoveryConnecting = false;
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        if (pendingConnect != null) {
            MethodChannel.Result pending = pendingConnect;
            pendingConnect = null;
            pending.error("CONNECT_CANCELLED", "连接已取消", null);
        }
        boolean nativePending = connectedId != null;
        setTimeFlags = null;
        supportFlags = null;
        if (!nativePending) { result.success(null); return; }
        cancellingConnection = true;
        pendingDisconnect = result;
        manager.unBindDevice();
        verifyNativeCancellation(connectionGeneration, connectedId,
                SystemClock.elapsedRealtime() + 20_000L);
        main.postDelayed(() -> {
            if (pendingDisconnect != result) return;
            pendingDisconnect = null;
            result.error("RECOVERY_PENDING", "蓝牙连接尚未结束，请稍后重试", null);
            // The native cancellation barrier remains until its callback.
        }, 20_000L);
    }

    private void onServiceReady() {
        if (connectedId == null || cancellingConnection || handshakeStarted) return;
        handshakeStarted = true;
        final int generation = connectionGeneration;
        final String id = connectedId;
        LargeDataHandler.getInstance().initEnable();
        CommandHandle.getInstance().executeReqCmd(
                new SetTimeReq(1),
                (ICommandResponse<SetTimeRsp>) response -> main.post(() -> {
                    if (!isCurrentConnection(generation, id)) return;
                    if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK) {
                        failConnect("QRING_HANDSHAKE_FAILED", "戒指基础能力读取失败，请重试");
                        return;
                    }
                    setTimeFlags = response;
                    readExtendedCapabilities();
                }));
    }

    private void readExtendedCapabilities() {
        final int generation = connectionGeneration;
        final String id = connectedId;
        CommandHandle.getInstance().executeReqCmd(
                DeviceSupportReq.getReadInstance(),
                (ICommandResponse<DeviceSupportFunctionRsp>) response -> main.post(() -> {
                    if (!isCurrentConnection(generation, id)) return;
                    if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK) {
                        failConnect("QRING_HANDSHAKE_FAILED", "戒指扩展能力读取失败，请重试");
                        return;
                    }
                    supportFlags = response;
                    if (response.supportBlePair) manager.bleCreateBond();
                    writeProfileThenFinish();
                }));
    }

    private int profileInt(String key, int fallback, int minimum, int maximum) {
        Object raw = pendingProfile == null ? null : pendingProfile.get(key);
        int value = raw instanceof Number ? ((Number) raw).intValue() : fallback;
        return Math.max(minimum, Math.min(maximum, value));
    }

    private String factoryInitializationKey(String id, String context) {
        return "factory-init.v1." + context + "." + id.toLowerCase(java.util.Locale.ROOT);
    }

    private int factoryInitialization(String id, String context) {
        if (id == null || context == null || context.isEmpty()) return 0;
        try {
            return activity.getSharedPreferences("say_ring_factory_initialization", Context.MODE_PRIVATE)
                    .getInt(factoryInitializationKey(id, context), 0);
        } catch (ClassCastException error) { return 1; }
    }

    private boolean saveFactoryInitialization(String id, String context, int phase) {
        return activity.getSharedPreferences("say_ring_factory_initialization", Context.MODE_PRIVATE)
                .edit().putInt(factoryInitializationKey(id, context), phase).commit();
    }

    private void updateFactoryInitialization(String id, String context, int flags) {
        int phase = factoryInitialization(id, context);
        if (phase != 0) saveFactoryInitialization(id, context, phase | flags);
    }

    private boolean factoryInitializationPending() {
        int phase = factoryInitialization(connectedId, recoveryContext);
        return phase != 0 && phase != 7;
    }

    private void emitFactoryInitialization() {
        if (!resolved() || factoryInitialization(connectedId, recoveryContext) == 0) return;
        Map<String, Object> value = new HashMap<>();
        value.put("deviceId", connectedId);
        value.put("ownerKey", recoveryContext.substring(recoveryContext.lastIndexOf(':') + 1));
        value.put("status", factoryInitializationPending() ? "pending" : "complete");
        emit("ringInitialization", value);
    }

    private boolean currentFactoryTarget(int generation, String id, String context) {
        return isCurrentConnection(generation, id) && context != null && context.equals(recoveryContext);
    }

    private void initializeFactoryTarget(Runnable completion) {
        final int generation = connectionGeneration;
        final boolean rearming = Integer.valueOf(generation).equals(factoryInitializingGeneration);
        final String id = connectedId, context = recoveryContext;
        int phase = factoryInitialization(id, context);
        if (phase == 0 || (phase & 4) != 0) { completion.run(); return; }
        final int target = profileInt("targetSteps", 8000, 1000, 100000);
        final boolean[] done = {false};
        Runnable finish = () -> { if (!done[0]) { done[0] = true; completion.run(); } };
        java.util.function.BooleanSupplier current = () -> !done[0] &&
                (!rearming || Integer.valueOf(generation).equals(factoryInitializingGeneration)) && currentFactoryTarget(generation, id, context);
        main.postDelayed(() -> { if (current.getAsBoolean()) finish.run(); }, 8_000L);
        CommandHandle.getInstance().executeReqCmd(TargetSettingReq.getReadInstance(),
                (ICommandResponse<TargetSettingRsp>) before -> main.post(() -> {
                    if (!current.getAsBoolean()) return;
                    if (before == null || before.getStatus() != BaseRspCmd.RESULT_OK || before.getAction() != TargetSettingRsp.ACTION_READ) { finish.run(); return; }
                    CommandHandle.getInstance().executeReqCmd(TargetSettingReq.getWriteInstance(target,
                            before.getCalorie(), before.getDistance(), before.getmSport(), before.getmSleep()),
                            (ICommandResponse<TargetSettingRsp>) ack -> main.post(() -> {
                                if (!current.getAsBoolean()) return;
                                if (ack == null || ack.getStatus() != BaseRspCmd.RESULT_OK) { finish.run(); return; }
                                CommandHandle.getInstance().executeReqCmd(TargetSettingReq.getReadInstance(),
                                        (ICommandResponse<TargetSettingRsp>) actual -> main.post(() -> {
                                            if (!current.getAsBoolean()) return;
                                            if (actual != null && actual.getStatus() == BaseRspCmd.RESULT_OK && actual.getAction() == TargetSettingRsp.ACTION_READ &&
                                                    actual.getStep() == target && actual.getCalorie() == before.getCalorie() &&
                                                    actual.getDistance() == before.getDistance() && actual.getmSport() == before.getmSport() &&
                                                    actual.getmSleep() == before.getmSleep()) updateFactoryInitialization(id, context, 4);
                                            finish.run();
                                        }));
                            }));
                }));
    }

    private void resetFirstMemberRing(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id"), owner = call.argument("ownerKey");
        if (!Boolean.TRUE.equals(call.argument("allowFactoryReset")) || !resolved() || id == null ||
                !id.equalsIgnoreCase(connectedId) || owner == null || owner.isEmpty() ||
                recoveryContext == null || !recoveryContext.endsWith(":" + owner)) {
            result.error("FACTORY_RESET_NOT_AUTHORIZED", "首次绑定恢复出厂未获确认，未执行", null); return;
        }
        if (pendingSync != null || activeMeasurement != null || activeSportType != null ||
                Integer.valueOf(connectionGeneration).equals(factoryResetGeneration) ||
                factoryInitialization(id, recoveryContext) != 0) {
            result.error("DEVICE_BUSY", "设备忙或已请求初始化，不会重复重置", null); return;
        }
        final String context = recoveryContext;
        if (!saveFactoryInitialization(id, context, 1)) {
            result.error("INITIALIZATION_STORAGE_FAILED", "初始化记录未能保存，未重置戒指", null); return;
        }
        factoryResetGeneration = connectionGeneration;
        final int generation = connectionGeneration;
        CommandHandle.getInstance().executeReqCmd(new RestoreKeyReq(Constants.CMD_RE_STORE),
                (ICommandResponse<BaseRspCmd>) ack -> main.post(() -> {
                    if (!currentFactoryTarget(generation, id, context)) return;
                    if (ack != null && ack.getStatus() == BaseRspCmd.RESULT_OK) {
                        updateFactoryInitialization(id, context, 2);
                        if (id.equalsIgnoreCase(connectedId) && context.equals(recoveryContext) && resolved()) {
                            emit("capabilitiesUpdated", capabilities()); emitFactoryInitialization();
                        }
                    }
                }));
        result.success("factoryResetRequested");
    }

    private void writeProfileThenFinish() {
        writeProfileWithCompletion(() -> probeRemoteCamera(this::finishHandshake));
    }

    private void writeProfileWithCompletion(Runnable completion) {
        final int generation = connectionGeneration;
        final boolean rearming = Integer.valueOf(generation).equals(factoryInitializingGeneration);
        final String id = connectedId;
        final String context = recoveryContext;
        int sdkGender = profileInt("gender", 1, 1, 2) == 2 ? 1 : 0;
        TimeFormatReq request = TimeFormatReq.getWriteInstance(
                true, 0, sdkGender,
                profileInt("age", 30, 5, 120),
                profileInt("heightCm", 175, 80, 240),
                profileInt("weightKg", 70, 20, 250),
                0, 0, 0);
        CommandHandle.getInstance().executeReqCmd(
                request,
                (ICommandResponse<TimeFormatRsp>) response -> main.post(() -> {
                    if ((rearming && !Integer.valueOf(generation).equals(factoryInitializingGeneration)) ||
                            !isCurrentConnection(generation, id) || !java.util.Objects.equals(context, recoveryContext)) return;
                    if (response != null && response.getStatus() == BaseRspCmd.RESULT_OK)
                        initializeFactoryTarget(completion);
                    else completion.run();
                }));
    }

    private void finishHandshake() {
        if (setTimeFlags == null || supportFlags == null || connectedId == null
                || !isQRingName(connectedName) || cancellingConnection) {
            failConnect("QRING_HANDSHAKE_FAILED", "戒指能力未完整返回，请重试");
            return;
        }
        CommandHandle.getInstance().executeReqCmd(
                new SimpleKeyReq(Constants.CMD_BIND_SUCCESS), null);
        readBattery();
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        Map<String, Object> details = deviceDetails();
        boolean recovered = recoveryConnecting;
        recoveryConnecting = false;
        if (pendingConnect != null) {
            MethodChannel.Result result = pendingConnect;
            pendingConnect = null;
            result.success(null);
        }
        emit("deviceDetails", details);
        emit("capabilitiesUpdated", capabilities());
        if (recovered) emit("reconnected", details);
    }

    private void failConnect(String code, String message) {
        connectionGeneration++;
        recoveryConnecting = false;
        handshakeStarted = false;
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        if (pendingConnect != null) {
            MethodChannel.Result result = pendingConnect;
            pendingConnect = null;
            result.error(code, message, null);
        }
        // A failed handshake may leave a GATT request pending. Do not allow
        // the next target to start until the SDK reports its cancellation.
        cancellingConnection = manager != null && connectedId != null;
        try {
            if (manager != null) manager.disconnect();
        } catch (RuntimeException ignored) { }
        verifyNativeCancellation(connectionGeneration, connectedId,
                SystemClock.elapsedRealtime() + 20_000L);
    }

    private void verifyNativeCancellation(int generation, String retiredId, long deadline) {
        boolean sameTarget = retiredId != null && retiredId.equalsIgnoreCase(connectedId);
        if (!cancellingConnection || generation != connectionGeneration || !sameTarget) return;
        try {
            // The vendor emits disconnect only for a previously published ready
            // session. A failed pre-handshake attempt can close its GATT silently.
            // Confirm actual SDK teardown; elapsed time alone never releases it.
            BleBaseControl control = BleBaseControl.getInstance();
            if (control != null && QRingCancellationGate.canFinish(
                    generation == connectionGeneration, sameTarget, cancellingConnection,
                    control.ismIsConnected(), control.isConnecting(),
                    control.getGatt(retiredId) != null)) {
                Log.i(TAG, "QRing SDK cancellation confirmed");
                finishDisconnectedSession();
                return;
            }
        } catch (RuntimeException ignored) {
            // A failed state read does not prove teardown.
        }
        if (SystemClock.elapsedRealtime() < deadline) {
            main.postDelayed(() -> verifyNativeCancellation(generation, retiredId, deadline), 250L);
        }
    }

    private void onCharacteristic(String uuid, byte[] data) {
        if (uuid == null || data == null || data.length == 0) return;
        String value = new String(data).trim();
        if (Constants.CHAR_FIRMWARE_REVISION.toString().equalsIgnoreCase(uuid)) {
            firmwareVersion = value;
        } else if (Constants.CHAR_HW_REVISION.toString().equalsIgnoreCase(uuid)) {
            hardwareVersion = value;
        }
    }

    private void readBattery() {
        final int generation = connectionGeneration;
        final String deviceId = connectedId;
        if (deviceId == null || remoteCameraActive || pendingCamera != null || pendingSync != null || activeMeasurement != null ||
                android.os.SystemClock.elapsedRealtime() - batteryQueryAt < 8_000L) return;
        batteryQueryAt = android.os.SystemClock.elapsedRealtime();
        CommandHandle.getInstance().executeReqCmd(
                new SimpleKeyReq(Constants.CMD_GET_DEVICE_ELECTRICITY_VALUE),
                (ICommandResponse<BatteryRsp>) response -> main.post(() -> {
                    if (!isCurrentConnection(generation, deviceId)) return;
                    if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK) return;
                    int percent = response.getBatteryValue();
                    if (percent < 0 || percent > 100) return;
                    batteryPercent = percent;
                    charging = response.isCharging();
                    batteryUpdatedAt = Instant.now().toString();
                    emit("deviceDetails", deviceDetails());
                }));
    }

    private Map<String, Object> deviceDetails() {
        Map<String, Object> value = new HashMap<>();
        value.put("id", connectedId == null ? "" : connectedId);
        value.put("name", connectedName == null ? "QRing" : connectedName);
        value.put("model", connectedName == null ? "QRing" : connectedName);
        if (connectedId != null) value.put("hardwareAddress", connectedId);
        if (!firmwareVersion.isEmpty()) value.put("firmwareVersion", firmwareVersion);
        if (!hardwareVersion.isEmpty()) value.put("serialNumber", hardwareVersion);
        if (batteryPercent != null) {
            Map<String, Object> battery = new HashMap<>();
            battery.put("value", batteryPercent);
            battery.put("scale", 100);
            battery.put("isPercent", true);
            battery.put("chargeState", charging == null ? "unknown" : charging ? "charging" : "normal");
            battery.put("updatedAt", batteryUpdatedAt);
            battery.put("chargingUpdatedAt", batteryUpdatedAt);
            value.put("battery", battery);
            value.put("batteryPercent", batteryPercent);
        }
        return value;
    }

    private boolean resolved() {
        return manager != null && manager.isConnected()
                && setTimeFlags != null && supportFlags != null
                && pendingConnect == null && !recoveryConnecting && !cancellingConnection;
    }

    private Map<String, Object> capabilities() {
        Map<String, Object> value = new HashMap<>();
        value.put("resolved", resolved());
        List<String> metrics = new ArrayList<>();
        List<String> manual = new ArrayList<>();
        List<String> features = new ArrayList<>();
        List<String> sports = new ArrayList<>();
        if (!resolved()) {
            value.put("metrics", metrics);
            value.put("manualMetrics", manual);
            value.put("sportModes", sports);
            value.put("features", features);
            return value;
        }
        metrics.add("steps");
        metrics.add("distance");
        metrics.add("calories");
        if (setTimeFlags.supportsSleepHistory()) metrics.add("sleep");
        if (setTimeFlags.supportsHeartRate() || supportFlags.supportHeart
                || supportFlags.supportIntervalHeartRate) {
            metrics.add("heart_rate");
            if (setTimeFlags.mSupportManualHeart || setTimeFlags.mSupportAppMeasure) {
                manual.add("heart_rate");
            }
        }
        if (setTimeFlags.supportsBloodOxygen() || supportFlags.supportIntervalBloodOxygen) {
            metrics.add("blood_oxygen");
            if (setTimeFlags.mSupportManualBloodOxygen || setTimeFlags.mSupportAppMeasure) {
                manual.add("blood_oxygen");
            }
        }
        if (setTimeFlags.supportsBloodPressure()) {
            metrics.add("blood_pressure");
            if (setTimeFlags.mSupportAppMeasure) manual.add("blood_pressure");
        }
        if (setTimeFlags.supportsPressure()) {
            metrics.add("stress");
            manual.add("stress");
        }
        if (setTimeFlags.supportsHrv()) {
            metrics.add("hrv");
            manual.add("hrv");
        }
        if (setTimeFlags.supportsTemperature() || supportFlags.supportIntervalTemperature
                || supportFlags.supportSkinTemperature) {
            metrics.add("body_temperature");
            if (setTimeFlags.mSupportAppMeasure) manual.add("body_temperature");
        }
        if (setTimeFlags.supportsSportRecord()) {
            String[] supported = {"running", "indoor_running", "walking", "cycling",
                    "indoor_cycling", "basketball", "football", "badminton",
                    "swimming", "jump_rope", "yoga", "hiking", "mountaineering"};
            for (String sport : supported) sports.add(sport);
        }
        features.add("find_watch");
        if (remoteCameraSupported) features.add("camera");
        if (supportsGesture()) features.add("gesture_control");
        if (supportFlags.supportIntervalHeartRate || supportFlags.supportIntervalBloodOxygen
                || supportFlags.supportIntervalTemperature || setTimeFlags.supportsPressure()
                || setTimeFlags.supportsHrv()) {
            features.add("health_monitoring");
        }
        value.put("metrics", metrics);
        value.put("manualMetrics", manual);
        value.put("sportModes", sports);
        value.put("features", features);
        value.put("integratedFeatures", features);
        value.put("supportsSportPause", false);
        value.put("supportsBackgroundSync", false);
        value.put("supportsHistorySync", !factoryInitializationPending());
        value.put("supportsWatchFaces", false);
        value.put("supportsOta", false);
        return value;
    }

    private boolean supportsMetric(String metric, boolean manual) {
        Object raw = capabilities().get(manual ? "manualMetrics" : "metrics");
        return raw instanceof List && ((List<?>) raw).contains(metric);
    }

    private void startMeasurement(String metric, MethodChannel.Result result) {
        if (!resolved()) {
            result.error("CAPABILITIES_UNAVAILABLE", "请先读取戒指功能", null);
            return;
        }
        if (!supportsMetric(metric, true)) {
            result.error("QRING_FEATURE_UNVERIFIED", "此项手动测量未获戒指确认", null);
            return;
        }
        if (activeMeasurement != null) {
            result.error("MEASUREMENT_ACTIVE", "已有健康测量正在进行", null);
            return;
        }
        activeMeasurement = metric;
        measurementOperation++;
        manualResultEmitted = false;
        Map<String, Object> progress = new HashMap<>();
        progress.put("metric", metric);
        // This SDK reports results/errors, not a percentage. Use an indeterminate indicator.
        progress.put("progress", 0);
        emit("measurementProgress", progress);
        runMeasurement(metric, false);
        result.success(null);
    }

    static boolean measurementFailed(StartHeartRateRsp response) {
        return response == null || response.getStatus() != BaseRspCmd.RESULT_OK || response.getErrCode() != 0;
    }

    private void runMeasurement(String metric, boolean stop) {
        final int operation = measurementOperation, generation = connectionGeneration;
        final String id = connectedId;
        final String context = recoveryContext;
        ICommandResponse<StartHeartRateRsp> callback = response -> main.post(() -> {
            if (stop || operation != measurementOperation || !isCurrentConnection(generation, id)
                    || !java.util.Objects.equals(context, recoveryContext)
                    || !metric.equals(activeMeasurement)) return;
            // The SDK forwards not-worn/error packets with status == RESULT_OK and a nonzero errCode.
            if (measurementFailed(response)) {
                emitMeasurementError(response == null ? -1 : response.getErrCode());
                return;
            }
            emitManualValue(metric, response);
        });
        switch (metric) {
            case "heart_rate": manager.manualModeHeart(callback, stop); break;
            case "blood_oxygen": manager.manualModeSpO2(callback, stop); break;
            case "blood_pressure": manager.manualModeBP(callback, stop); break;
            case "stress": manager.manualModePressure(callback, stop); break;
            case "hrv": manager.manualModeHrv(callback, stop); break;
            case "body_temperature": manager.manualTemperature(callback, stop); break;
            default: break;
        }
    }

    private void emitManualValue(String metric, StartHeartRateRsp response) {
        if (manualResultEmitted || connectedId == null) return;
        Map<String, Object> values = new LinkedHashMap<>();
        String unit = "";
        switch (metric) {
            case "heart_rate": {
                int amount = response.getHeartRate() > 0 ? response.getHeartRate()
                        : (response.getHeart() > 0 ? response.getHeart() : response.getValue());
                if (amount < 20 || amount > 300) return;
                values.put("value", amount);
                unit = "bpm";
                break;
            }
            case "blood_oxygen": {
                int amount = response.getBloodOxygen();
                if (amount < 50 || amount > 100) return;
                values.put("value", amount);
                unit = "%";
                break;
            }
            case "blood_pressure": {
                int systolic = response.getSbp();
                int diastolic = response.getDbp();
                if (systolic < 50 || systolic > 260 || diastolic < 30 || diastolic > 180) return;
                values.put("systolic", systolic);
                values.put("diastolic", diastolic);
                values.put("value", systolic);
                unit = "mmHg";
                break;
            }
            case "stress": {
                int amount = response.getStress() > 0 ? response.getStress() : response.getValue();
                if (amount < 1 || amount > 100) return;
                values.put("value", amount);
                break;
            }
            case "hrv": {
                int amount = response.getHrv() > 0 ? response.getHrv() : response.getValue();
                if (amount < 1 || amount > 1000) return;
                values.put("value", amount);
                values.put("sdnn", amount);
                unit = "ms";
                break;
            }
            case "body_temperature": {
                double amount = response.getTemperature();
                if (amount > 100) amount /= 100.0;
                if (amount < 20 || amount > 45) return;
                values.put("value", amount);
                values.put("skinTemperature", amount);
                unit = "℃";
                break;
            }
            default: return;
        }
        manualResultEmitted = true;
        Map<String, Object> progress = new HashMap<>();
        progress.put("metric", metric);
        progress.put("progress", 100);
        emit("measurementProgress", progress);
        emit("healthRecord", QRingRecordMapper.manualRecord(
                connectedId, connectedName, firmwareVersion, metric, values, unit));
        runMeasurement(metric, true);
        activeMeasurement = null;
        measurementOperation++;
    }

    private void emitMeasurementError(int errorCode) {
        String metric = activeMeasurement;
        activeMeasurement = null;
        measurementOperation++;
        if (metric != null) runMeasurement(metric, true);
        Map<String, Object> value = new HashMap<>();
        value.put("code", errorCode == 3 ? "MEASUREMENT_NOT_WORN" : "MEASUREMENT_FAILED");
        value.put("message", errorCode == 3
                ? "未检测到正确佩戴，请调整戒指后重试" : "戒指未返回有效测量结果，请保持静止后重试");
        emit("error", value);
    }

    private void stopMeasurement(String metric, MethodChannel.Result result) {
        if (metric != null && metric.equals(activeMeasurement)) runMeasurement(metric, true);
        activeMeasurement = null;
        measurementOperation++;
        manualResultEmitted = false;
        result.success(null);
    }

    private void startHealthSync(MethodChannel.Result result) {
        if (factoryInitializationPending()) { result.error("INITIALIZATION_PENDING", "戒指初始化尚未确认，历史同步已暂停", null); return; }
        if (!resolved()) {
            result.error("NOT_CONNECTED", "请先连接戒指", null);
            return;
        }
        if (pendingSync != null) {
            result.error("SYNC_BUSY", "戒指数据正在同步", null);
            return;
        }
        pendingSync = result;
        syncRecords.clear();
        List<String> metrics = new ArrayList<>();
        metrics.add("steps");
        for (String metric : new String[]{"sleep", "heart_rate", "blood_oxygen", "stress", "hrv", "body_temperature"}) {
            if (supportsMetric(metric, false)) metrics.add(metric);
        }
        historyReads.begin(metrics, 7);
        syncDeadline = () -> {
            if (pendingSync == result) failPendingSync("SYNC_TIMEOUT", "戒指数据同步超时，请重试");
        };
        main.postDelayed(syncDeadline, SYNC_MS);
        syncDay(0, 0);
    }

    private void syncDay(int day, int phase) {
        if (pendingSync == null) return;
        if (day >= 7) {
            completeHealthSync();
            return;
        }
        double progressValue = Math.min(0.98, (day * 7.0 + phase) / 49.0);
        Map<String, Object> progress = new HashMap<>();
        progress.put("deviceId", connectedId);
        progress.put("progress", progressValue);
        emit("syncProgress", progress);
        switch (phase) {
            case 0:
                manager.getStepDetail(day, callback("steps",
                        values -> QRingRecordMapper.stepRecords(
                                connectedId, connectedName, firmwareVersion, day, values),
                        () -> syncDay(day, 1)));
                break;
            case 1:
                if (!supportsMetric("sleep", false)) { syncDay(day, 2); return; }
                final MethodChannel.Result sleepSync = pendingSync;
                final String sleepDeviceId = connectedId;
                final int sleepConnectionGeneration = connectionGeneration;
                final QRingHistoryReadState.Ticket sleepRead = historyReads.open("sleep");
                final QRingRecordMapper.SleepRequestDay sleepRequestDay = QRingRecordMapper.sleepRequestDay(day);
                manager.getSleep(day, new BleOperateManager.HealthDataCallback<SleepDisplay>() {
                    @Override public void onSuccess(SleepDisplay value) {
                        main.post(() -> {
                            if (pendingSync != sleepSync || !isCurrentConnection(sleepConnectionGeneration, sleepDeviceId)) return;
                            Map<String, Object> timeline = QRingRecordMapper.sleepTimelineForSuccessfulRead(
                                    sleepDeviceId, sleepRequestDay, value);
                            boolean complete = QRingRecordMapper.sleepTimelineIsComplete(timeline);
                            if (!historyReads.accept(sleepRead, complete,
                                    complete && QRingRecordMapper.sleepTimelineHasData(timeline))) return;
                            Map<String, Object> status = new HashMap<>();
                            status.put("deviceId", "qring:" + sleepDeviceId);
                            status.put("sdkDate", sleepRequestDay.sdkDate);
                            status.put("status", complete
                                    ? (QRingRecordMapper.sleepTimelineHasData(timeline) ? "complete" : "noData") : "failed");
                            if (complete) {
                                status.put("sleepTimeline", timeline);
                                collect(QRingRecordMapper.sleepRecords(sleepDeviceId, connectedName, firmwareVersion, sleepRequestDay, value));
                            }
                            emit("sleepReadStatus", status);
                            syncDay(day, 2);
                        });
                    }

                    @Override public void onError(int code, String message) {
                        main.post(() -> {
                            if (pendingSync != sleepSync || !isCurrentConnection(sleepConnectionGeneration, sleepDeviceId)) return;
                            if (!historyReads.accept(sleepRead, false, false)) return;
                            Map<String, Object> status = new HashMap<>();
                            status.put("deviceId", "qring:" + sleepDeviceId);
                            status.put("sdkDate", sleepRequestDay.sdkDate);
                            status.put("status", "failed");
                            emit("sleepReadStatus", status);
                            syncDay(day, 2);
                        });
                    }
                });
                break;
            case 2:
                if (!supportsMetric("heart_rate", false)) { syncDay(day, 3); return; }
                manager.getHeartRate(day, callback("heart_rate",
                        value -> QRingRecordMapper.heartRecords(
                                connectedId, connectedName, firmwareVersion, day, value),
                        () -> syncDay(day, 3)));
                break;
            case 3:
                if (!supportsMetric("blood_oxygen", false)) { syncDay(day, 4); return; }
                manager.getBloodOxygen(day, callback("blood_oxygen",
                        value -> QRingRecordMapper.oxygenRecords(
                                connectedId, connectedName, firmwareVersion, day, value),
                        () -> syncDay(day, 4)));
                break;
            case 4:
                if (!supportsMetric("stress", false)) { syncDay(day, 5); return; }
                manager.getPressure(day, callback("stress",
                        value -> QRingRecordMapper.stressRecords(
                                connectedId, connectedName, firmwareVersion, day, value),
                        () -> syncDay(day, 5)));
                break;
            case 5:
                if (!supportsMetric("hrv", false)) { syncDay(day, 6); return; }
                manager.getHrv(day, callback("hrv",
                        value -> QRingRecordMapper.hrvRecords(
                                connectedId, connectedName, firmwareVersion, day, value),
                        () -> syncDay(day, 6)));
                break;
            case 6:
                if (!supportsMetric("body_temperature", false)) { syncDay(day + 1, 0); return; }
                manager.getTemperature(day, callback("body_temperature",
                        value -> QRingRecordMapper.temperatureRecords(
                                connectedId, connectedName, firmwareVersion, day, value),
                        () -> syncDay(day + 1, 0)));
                break;
            default:
                syncDay(day + 1, 0);
        }
    }

    private interface RecordMapper<T> { List<Map<String, Object>> map(T value); }

    private <T> BleOperateManager.HealthDataCallback<T> callback(
            String metric, RecordMapper<T> mapper, Runnable next) {
        final MethodChannel.Result request = pendingSync;
        final int requestConnection = connectionGeneration;
        final String requestDevice = connectedId;
        final QRingHistoryReadState.Ticket ticket = historyReads.open(metric);
        return new BleOperateManager.HealthDataCallback<T>() {
            @Override public void onSuccess(T value) {
                main.post(() -> {
                    if (pendingSync != request || !isCurrentConnection(requestConnection, requestDevice)) return;
                    // Null is not an explicit empty history response.
                    List<Map<String, Object>> records = value == null ? null : mapper.map(value);
                    if (!historyReads.accept(ticket, records != null, records != null && !records.isEmpty())) return;
                    collect(records);
                    next.run();
                });
            }

            @Override public void onError(int code, String message) {
                main.post(() -> {
                    if (pendingSync != request || !isCurrentConnection(requestConnection, requestDevice)) return;
                    if (historyReads.accept(ticket, false, false)) next.run();
                });
            }
        };
    }

    private void collect(List<Map<String, Object>> records) {
        if (records == null) return;
        for (Map<String, Object> record : records) {
            Object id = record.get("id");
            if (id != null) syncRecords.put(String.valueOf(id), record);
        }
    }

    private void completeHealthSync() {
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        syncDeadline = null;
        if (pendingSync == null) return;
        MethodChannel.Result result = pendingSync;
        pendingSync = null;
        Map<String, Object> response = new HashMap<>();
        response.put("records", new ArrayList<>(syncRecords.values()));
        response.put("statuses", historyReads.statuses());
        historyReads.cancel();
        result.success(response);
    }

    private void failPendingSync(String code, String message) {
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        syncDeadline = null;
        if (pendingSync == null) return;
        MethodChannel.Result result = pendingSync;
        pendingSync = null;
        historyReads.cancel();
        result.error(code, message, null);
    }

    private void startSport(String mode, MethodChannel.Result result) {
        if (!resolved() || !((List<?>) capabilities().get("sportModes")).contains(mode)) {
            result.error("QRING_SPORT_UNAVAILABLE", "此运动模式未获戒指确认", null);
            return;
        }
        if (activeMeasurement != null || activeSportType != null) {
            result.error("DEVICE_BUSY", "请先结束当前测量或运动", null);
            return;
        }
        Integer type = QRingRecordMapper.sportType(mode);
        if (type == null) {
            result.error("QRING_SPORT_UNAVAILABLE", "此运动模式暂不支持", null);
            return;
        }
        CommandHandle.getInstance().executeReqCmd(
                PhoneSportReq.getSportStatus((byte) 1, type.byteValue()),
                (ICommandResponse<AppSportRsp>) response -> main.post(() -> {
                    if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK) {
                        result.error("QRING_SPORT_START_FAILED", "戒指未能开始运动", null);
                        return;
                    }
                    activeSportMode = mode;
                    activeSportType = type;
                    Map<String, Object> event = new HashMap<>();
                    event.put("value", "running");
                    event.put("mode", mode);
                    emit("sportState", event);
                    result.success(null);
                }));
    }

    private void stopSport(MethodChannel.Result result) {
        if (activeSportType == null) {
            result.error("QRING_SPORT_UNAVAILABLE", "当前没有正在进行的戒指运动", null);
            return;
        }
        int type = activeSportType;
        String mode = activeSportMode;
        CommandHandle.getInstance().executeReqCmd(
                PhoneSportReq.getSportStatus((byte) 4, (byte) type),
                (ICommandResponse<AppSportRsp>) response -> main.post(() -> {
                    if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK) {
                        result.error("QRING_SPORT_STOP_FAILED", "戒指未能结束运动", null);
                        return;
                    }
                    activeSportMode = null;
                    activeSportType = null;
                    Map<String, Object> event = new HashMap<>();
                    event.put("value", "stopped");
                    event.put("mode", mode == null ? "" : mode);
                    emit("sportState", event);
                    result.success(null);
                }));
    }

    private void readSportRecords(MethodChannel.Result result) {
        if (factoryInitializationPending()) { result.error("INITIALIZATION_PENDING", "戒指初始化尚未确认，历史同步已暂停", null); return; }
        if (!resolved()) {
            result.error("NOT_CONNECTED", "请先连接戒指", null);
            return;
        }
        manager.getSports(0, 7, new BleOperateManager.HealthDataCallback<
                List<BleOperateManager.DayIndexedData<List<SportPlusEntity>>>>() {
            @Override public void onSuccess(
                    List<BleOperateManager.DayIndexedData<List<SportPlusEntity>>> values) {
                main.post(() -> {
                    List<Map<String, Object>> records = new ArrayList<>();
                    if (values != null) {
                        for (BleOperateManager.DayIndexedData<List<SportPlusEntity>> item : values) {
                            if (item != null) records.addAll(QRingRecordMapper.sportRecords(
                                    connectedId, item.getData()));
                        }
                    }
                    result.success(records);
                });
            }

            @Override public void onError(int code, String message) {
                main.post(() -> result.error(
                        "QRING_SPORT_SYNC_FAILED", "戒指运动记录读取失败", null));
            }
        });
    }

    private void readAutoSettings(MethodChannel.Result result) {
        if (!resolved()) {
            result.error("NOT_CONNECTED", "请先连接戒指", null);
            return;
        }
        autoHeart = autoOxygen = autoStress = autoHrv = autoTemperature = null;
        CommandHandle.getInstance().executeReqCmd(
                HeartRateSettingReq.getReadInstance(),
                (ICommandResponse<HeartRateSettingRsp>) heart -> main.post(() -> {
                    autoHeart = heart != null && heart.getStatus() == BaseRspCmd.RESULT_OK
                            ? heart.isEnable() : null;
                    readAutoOxygen(result);
                }));
    }

    private void readAutoOxygen(MethodChannel.Result result) {
        if (!supportsMetric("blood_oxygen", false)) {
            readAutoStress(result);
            return;
        }
        CommandHandle.getInstance().executeReqCmd(
                BloodOxygenSettingReq.getReadInstance(),
                (ICommandResponse<BloodOxygenSettingRsp>) oxygen -> main.post(() -> {
                    autoOxygen = oxygen != null && oxygen.getStatus() == BaseRspCmd.RESULT_OK
                            ? oxygen.isEnable() : null;
                    readAutoStress(result);
                }));
    }

    private void readAutoStress(MethodChannel.Result result) {
        if (!supportsMetric("stress", false)) {
            readAutoHrv(result);
            return;
        }
        CommandHandle.getInstance().executeReqCmd(
                PressureSettingReq.getReadInstance(),
                (ICommandResponse<PressureSettingRsp>) pressure -> main.post(() -> {
                    autoStress = pressure != null && pressure.getStatus() == BaseRspCmd.RESULT_OK
                            ? pressure.isEnable() : null;
                    readAutoHrv(result);
                }));
    }

    private void readAutoHrv(MethodChannel.Result result) {
        if (!supportsMetric("hrv", false)) {
            readAutoTemperature(result);
            return;
        }
        CommandHandle.getInstance().executeReqCmd(
                HrvSettingReq.getReadInstance(),
                (ICommandResponse<HRVSettingRsp>) hrv -> main.post(() -> {
                    autoHrv = hrv != null && hrv.getStatus() == BaseRspCmd.RESULT_OK
                            ? hrv.isEnable() : null;
                    readAutoTemperature(result);
                }));
    }

    private void readAutoTemperature(MethodChannel.Result result) {
        if (!supportsMetric("body_temperature", false)) { result.success(autoSettings()); return; }
        CommandHandle.getInstance().executeReqCmd(SugarLipidsSettingReq.getReadTemperatureInstance(),
                (ICommandResponse<BloodSugarLipidsSettingRsp>) response -> main.post(() -> {
                    QRingMonitoringSetting setting = QRingMonitoringSetting.read("bodyTemperature", response);
                    autoTemperature = setting == null ? null : setting.enabled;
                    result.success(autoSettings());
                }));
    }

    private Map<String, Object> autoSettings() {
        Map<String, Object> value = new HashMap<>();
        if (autoHeart != null) value.put("heartRate", autoHeart);
        if (autoOxygen != null) value.put("bloodOxygen", autoOxygen);
        if (autoStress != null) value.put("stress", autoStress);
        if (autoHrv != null) value.put("hrv", autoHrv);
        if (autoTemperature != null) value.put("bodyTemperature", autoTemperature);
        return value;
    }

    private String monitoringMetric(String type) {
        if (type == null) return "";
        switch (type) {
            case "heartRate": return "heart_rate";
            case "bloodOxygen": return "blood_oxygen";
            case "stress": return "stress";
            case "bodyTemperature": return "body_temperature";
            default: return "";
        }
    }

    private void readMonitoringSetting(String type, java.util.function.Consumer<QRingMonitoringSetting> callback) {
        BaseReqCmd request;
        switch (type) {
            case "heartRate": request = HeartRateSettingReq.getReadInstance(); break;
            case "bloodOxygen": request = BloodOxygenSettingReq.getReadInstance(); break;
            case "stress": request = PressureSettingReq.getReadInstance(); break;
            case "bodyTemperature": request = SugarLipidsSettingReq.getReadTemperatureInstance(); break;
            default: callback.accept(null); return;
        }
        final boolean[] delivered = {false};
        CommandHandle.getInstance().executeReqCmd(request, (ICommandResponse<BaseRspCmd>) response -> main.post(() -> {
            if (delivered[0]) return;
            delivered[0] = true;
            callback.accept(QRingMonitoringSetting.read(type, response));
        }));
    }

    private void readMonitoringIntervals(int index, Map<String, Object> values,
            java.util.function.BooleanSupplier current, MethodChannel.Result result) {
        if (!current.getAsBoolean()) return;
        String[] types = {"heartRate", "bloodOxygen", "stress", "bodyTemperature"};
        if (index == types.length) { result.success(values); return; }
        String type = types[index];
        if (!supportsMetric(monitoringMetric(type), false)) {
            readMonitoringIntervals(index + 1, values, current, result); return;
        }
        readMonitoringSetting(type, setting -> {
            if (!current.getAsBoolean()) return;
            if (setting != null && setting.hasInterval()) values.put(type, setting.intervalMap());
            readMonitoringIntervals(index + 1, values, current, result);
        });
    }

    // Read current constraints, preserve independent intervals on toggle, then verify the write.
    private void monitoringInterval(String type, Integer minutes, Boolean enabled, MethodChannel.Result result) {
        if (!resolved() || (type != null && !supportsMetric(monitoringMetric(type), false))
                || (minutes != null && (minutes < 1 || minutes > 255))) {
            result.error("QRING_FEATURE_UNVERIFIED", "此监测间隔暂不支持", null); return;
        }
        final int generation = connectionGeneration;
        final String id = connectedId;
        final String context = recoveryContext;
        final boolean[] done = {false};
        MethodChannel.Result once = new MethodChannel.Result() {
            public void success(Object value) { if (!done[0]) { done[0] = true; result.success(value); } }
            public void error(String code, String message, Object detail) { if (!done[0]) { done[0] = true; result.error(code, message, detail); } }
            public void notImplemented() { if (!done[0]) { done[0] = true; result.notImplemented(); } }
        };
        java.util.function.BooleanSupplier current = () -> {
            if (done[0]) return false;
            if (isCurrentConnection(generation, id) && java.util.Objects.equals(context, recoveryContext)) return true;
            once.error("QRING_SESSION_CHANGED", "戒指连接已改变，请刷新设置", null);
            return false;
        };
        main.postDelayed(() -> {
            if (done[0]) return;
            if (isCurrentConnection(generation, id)) monitoringPoisonGeneration = generation;
            once.error("QRING_SETTING_TIMEOUT", "监测设置未确认，请重连后刷新", null);
        }, 15000);
        if (type == null) {
            readMonitoringIntervals(0, new HashMap<>(), current, once); return;
        }
        readMonitoringSetting(type, before -> {
            if (!current.getAsBoolean()) return;
            if (before == null) {
                once.error("UNSUPPORTED", "暂未读取到此项监测设置，请刷新后重试", null); return;
            }
            final BaseReqCmd request;
            try { request = before.write(type, minutes, enabled); }
            catch (IllegalArgumentException error) {
                once.error("UNSUPPORTED", "请先开启监测并选择戒指允许的间隔", null); return;
            }
            final boolean[] acknowledged = {false};
            CommandHandle.getInstance().executeReqCmd(request, (ICommandResponse<BaseRspCmd>) response -> main.post(() -> {
                if (!current.getAsBoolean() || acknowledged[0]) return;
                acknowledged[0] = true;
                if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK) {
                    once.error("QRING_SETTING_FAILED", "监测设置未保存，请重试", null); return;
                }
                readMonitoringSetting(type, actual -> {
                    if (!current.getAsBoolean()) return;
                    boolean expectedEnabled = enabled == null ? before.enabled : enabled;
                    int expectedMinutes = minutes == null ? before.minutes : minutes;
                    if (actual == null || actual.enabled != expectedEnabled ||
                            (before.hasInterval() && (!actual.hasInterval() || actual.minutes != expectedMinutes))) {
                        once.error("QRING_SETTING_UNCONFIRMED", "监测设置尚未确认，请刷新后检查", null); return;
                    }
                    once.success(null);
                });
            }));
        });
    }

    private void setAutoSetting(String type, Boolean enabled, MethodChannel.Result result) {
        if (!resolved() || enabled == null) {
            result.error("QRING_FEATURE_UNVERIFIED", "此自动检测项目暂不支持", null);
            return;
        }
        if (!monitoringMetric(type).isEmpty() && supportsMetric(monitoringMetric(type), false)) {
            monitoringInterval(type, null, enabled, result);
        } else if ("hrv".equals(type) && supportsMetric("hrv", false)) {
            CommandHandle.getInstance().executeReqCmd(
                    HrvSettingReq.getWriteInstance(enabled),
                    (ICommandResponse<HRVSettingRsp>) response -> main.post(() -> {
                        if (response != null && response.getStatus() == BaseRspCmd.RESULT_OK) {
                            autoHrv = enabled;
                            result.success(null);
                        } else result.error("QRING_SETTING_FAILED", "自动 HRV 设置失败", null);
                    }));
        } else {
            result.error("QRING_FEATURE_UNVERIFIED", "此自动检测项目未获戒指确认", null);
        }
    }

    private boolean supportsCamera() {
        return resolved() && QRingCameraPolicy.supported(supportFlags.supportGesture,
                supportFlags.supportRingCamera, supportFlags.supportTouch,
                supportFlags.supportRingCameraTouch, supportFlags.supportRt11);
    }

    private void finishCamera(Object value, String code, String message) {
        MethodChannel.Result pending = pendingCamera;
        if (pending == null) return;
        pendingCamera = null;
        cameraOperation++;
        if (code == null) pending.success(value);
        else pending.error(code, message, null);
    }

    private boolean supportsGesture() {
        return resolved() && (supportFlags.supportGesture
                || (supportFlags.supportTouch && !supportFlags.supportRt11));
    }

    private List<Integer> gestureModes(boolean touch) {
        List<Integer> modes = new ArrayList<>();
        modes.add(0);
        boolean[] flags = touch ? new boolean[] {supportFlags.supportRingVideoTouch,
                supportFlags.supportRingMusicTouch, supportFlags.supportRingEbookTouch,
                supportFlags.supportRingCameraTouch, supportFlags.supportRingPhoneCallTouch}
                : new boolean[] {supportFlags.supportRingVideo, supportFlags.supportRingMusic,
                supportFlags.supportRingEbook, supportFlags.supportRingCamera, supportFlags.supportRingPhoneCall};
        for (int index = 0; index < flags.length; index++) if (flags[index]) modes.add(index + 1);
        return modes;
    }

    private void gestureControl(MethodCall call, boolean write, MethodChannel.Result result) {
        traceControl(write ? "gesture_write_start" : "gesture_read_start");
        if (!supportsGesture()) {
            result.error("QRING_FEATURE_UNVERIFIED", "此戒指未确认支持手势控制", null); return;
        }
        boolean touch = !supportFlags.supportGesture;
        traceControl(touch ? "control_touch_channel" : "control_gesture_channel");
        List<Integer> modes = gestureModes(touch);
        Object raw = call.argument("values");
        Object mode = raw instanceof Map ? ((Map<?, ?>) raw).get("mode") : null;
        Object expectedMode = raw instanceof Map ? ((Map<?, ?>) raw).get("expectedMode") : null;
        Object selectedStrength = raw instanceof Map ? ((Map<?, ?>) raw).get("strength") : null;
        boolean stopping = raw instanceof Map && Boolean.TRUE.equals(((Map<?, ?>) raw).get("stopControl"));
        if (write && (!(mode instanceof Integer) || !modes.contains(mode)
                || !QRingGesturePolicy.validExpectedMode((Integer) mode, expectedMode, stopping))) {
            result.error("INVALID_GESTURE_MODE", "请刷新后选择戒指支持的手势模式", null); return;
        }
        if (pendingCamera != null || pendingSync != null || activeMeasurement != null || activeSportType != null) {
            result.error("DEVICE_BUSY", "设备忙，请稍后重试", null); return;
        }
        if (controlChannels.blocked(QRingControlChannelState.Channel.HID, connectionGeneration)) {
            result.error("QRING_CONTROL_RECONNECT", "手势状态未确认，请重新连接", null); return;
        }
        pendingCamera = result;
        pendingControlChannel = QRingControlChannelState.Channel.HID;
        cameraPhase = 0;
        final int operation = ++cameraOperation, connection = connectionGeneration;
        final String id = connectedId;
        final int expected = write ? QRingGesturePolicy.rawMode((Integer) mode) : -1;
        Runnable fail = () -> {
            if (!currentCamera(operation, connection, id)) return;
            controlChannels.block(QRingControlChannelState.Channel.HID, connection);
            finishCamera(null, "QRING_CONTROL_UNCONFIRMED", "手势状态未确认，请重新连接");
        };
        main.postDelayed(fail, 20_000L);
        main.postDelayed(() -> {
            if (!currentCamera(operation, connection, id)) return;
            CommandHandle.getInstance().executeReqCmd(TouchControlReq.getReadInstance(touch),
                    (ICommandResponse<TouchControlResp>) response -> main.post(() -> {
                if (!currentCamera(operation, connection, id) || cameraPhase != 0) return;
                Map<String, Object> snapshot = cameraSnapshot(response, touch);
                if (snapshot == null) { fail.run(); return; }
                if (!write) {
                    finishGestureAfterSettling(operation, connection, id,
                            QRingGesturePolicy.snapshot(snapshot, modes)); return;
                }
                if (!stopping && !snapshot.get("mode").equals(expectedMode)) {
                    finishCamera(null, "QRING_CONTROL_CHANGED", "戒指控制模式已改变，请刷新"); return;
                }
                int strength = QRingGesturePolicy.writeStrength(touch,
                        touch ? 0 : (Integer) snapshot.get("strength"), selectedStrength);
                if (strength < 0) {
                    finishCamera(null, "QRING_STRENGTH_REQUIRED", "请先选择1～10的手势力度"); return;
                }
                if (!touch) snapshot.put("strength", strength);
                cameraPhase = 1;
                int duration = touch ? (Integer) snapshot.get("duration") : 0;
                main.postDelayed(() -> {
                    if (!currentCamera(operation, connection, id) || cameraPhase != 1) return;
                    CommandHandle.getInstance().executeReqCmd(
                            TouchControlReq.getWriteInstance(expected, touch, strength, duration),
                            (ICommandResponse<TouchControlResp>) ack -> main.postDelayed(() -> {
                        if (!currentCamera(operation, connection, id) || cameraPhase != 1) return;
                        if (ack == null || ack.isRead() || ack.getStatus() != BaseRspCmd.RESULT_OK) {
                            fail.run(); return;
                        }
                        cameraPhase = 2;
                        readGestureBack(operation, connection, id, touch, expected, snapshot, 0, fail);
                    }, 400L));
                }, 200L);
            }));
        }, 200L);
    }

    private void finishGestureAfterSettling(int operation, int connection, String id, Object value) {
        main.postDelayed(() -> {
            if (currentCamera(operation, connection, id)) finishCamera(value, null, null);
        }, 200L);
    }

    private void readGestureBack(int operation, int connection, String id, boolean touch,
                                 int expected, Map<String, Object> original, int attempt, Runnable fail) {
        if (!currentCamera(operation, connection, id) || cameraPhase != 2) return;
        CommandHandle.getInstance().executeReqCmd(TouchControlReq.getReadInstance(touch),
                (ICommandResponse<TouchControlResp>) response -> main.post(() -> {
            if (!currentCamera(operation, connection, id) || cameraPhase != 2) return;
            Map<String, Object> actual = cameraSnapshot(response, touch);
            if (actual != null && Integer.valueOf(expected).equals(actual.get("mode"))
                    && (touch ? original.get("duration").equals(actual.get("duration"))
                              : original.get("strength").equals(actual.get("strength")))) {
                finishGestureAfterSettling(operation, connection, id, null); return;
            }
            if (attempt >= 2) { fail.run(); return; }
            main.postDelayed(() -> readGestureBack(operation, connection, id, touch,
                    expected, original, attempt + 1, fail), 400L);
        }));
    }

    private void cameraControl(MethodCall call, boolean write, MethodChannel.Result result) {
        if (!"camera".equals(call.argument("feature")) || !supportsCamera()) {
            result.error("QRING_FEATURE_UNVERIFIED", "此戒指不支持拍照控制", null); return;
        }
        Object raw = call.argument("values");
        Object enabled = raw instanceof Map ? ((Map<?, ?>) raw).get("enabled") : null;
        Object expectedMode = raw instanceof Map ? ((Map<?, ?>) raw).get("expectedMode") : null;
        if (write && (!(enabled instanceof Boolean) || !(expectedMode instanceof Integer)
                || (Integer) expectedMode < 0 || (Integer) expectedMode > 9)) {
            result.error("INVALID_ARGUMENT", "拍照设置无效", null); return;
        }
        if (pendingCamera != null || pendingSync != null || activeMeasurement != null || activeSportType != null) {
            result.error("DEVICE_BUSY", "设备忙，请稍后重试", null); return;
        }
        if (controlChannels.blocked(QRingControlChannelState.Channel.HID, connectionGeneration)) {
            result.error("QRING_CONTROL_RECONNECT", "拍照状态未确认，请重新连接", null); return;
        }
        pendingCamera = result;
        pendingControlChannel = QRingControlChannelState.Channel.HID;
        cameraPhase = 0;
        final int operation = ++cameraOperation;
        final int connection = connectionGeneration;
        final String id = connectedId;
        final boolean touch = !(supportFlags.supportGesture && supportFlags.supportRingCamera);
        final int expected = Boolean.TRUE.equals(enabled) ? QRingCameraPolicy.PHOTO_MODE : 0;
        Runnable fail = () -> {
            if (!currentCamera(operation, connection, id)) return;
            controlChannels.block(QRingControlChannelState.Channel.HID, connection);
            finishCamera(null, "QRING_CONTROL_UNCONFIRMED", "拍照状态未确认，请重新连接");
        };
        main.postDelayed(fail, 25_000L);
        CommandHandle.getInstance().executeReqCmd(TouchControlReq.getReadInstance(touch),
                (ICommandResponse<TouchControlResp>) response -> main.post(() -> {
                    if (!currentCamera(operation, connection, id) || cameraPhase != 0) return;
                    Map<String, Object> snapshot = cameraSnapshot(response, touch);
                    if (snapshot == null) { fail.run(); return; }
                    if (!write) { finishCamera(snapshot, null, null); return; }
                    int mode = (Integer) snapshot.get("mode");
                    if (!Integer.valueOf(mode).equals(expectedMode)) {
                        finishCamera(null, "QRING_CONTROL_CHANGED", "戒指控制模式已改变，请刷新"); return;
                    }
                    if (!Boolean.TRUE.equals(enabled) && mode != QRingCameraPolicy.PHOTO_MODE && mode != 0) {
                        finishCamera(null, "QRING_CONTROL_CHANGED", "戒指控制模式已改变，请刷新"); return;
                    }
                    int strength = touch ? 0 : (Integer) snapshot.get("strength");
                    if (!touch && QRingGesturePolicy.writeStrength(false, strength, null) < 0) {
                        finishCamera(null, "QRING_STRENGTH_REQUIRED", "请先在手势控制中选择力度"); return;
                    }
                    int duration = touch ? (Integer) snapshot.get("duration") : 0;
                    cameraPhase = 1;
                    CommandHandle.getInstance().executeReqCmd(
                            TouchControlReq.getWriteInstance(expected, touch, strength, duration),
                            (ICommandResponse<TouchControlResp>) acknowledgement -> main.post(() -> {
                                if (!currentCamera(operation, connection, id) || cameraPhase != 1) return;
                                if (acknowledgement == null || acknowledgement.isRead()
                                        || acknowledgement.getStatus() != BaseRspCmd.RESULT_OK) {
                                    fail.run(); return;
                                }
                                cameraPhase = 2;
                                CommandHandle.getInstance().executeReqCmd(TouchControlReq.getReadInstance(touch),
                                        (ICommandResponse<TouchControlResp>) readback -> main.post(() -> {
                                            if (!currentCamera(operation, connection, id) || cameraPhase != 2) return;
                                            Map<String, Object> actual = cameraSnapshot(readback, touch);
                                            if (actual == null || !Integer.valueOf(expected).equals(actual.get("mode"))
                                                    || (touch && !snapshot.get("duration").equals(actual.get("duration")))
                                                    || (!touch && !snapshot.get("strength").equals(actual.get("strength")))) {
                                                fail.run(); return;
                                            }
                                            finishCamera(null, null, null);
                                        }));
                            }));
                }));
    }

    private boolean currentCamera(int operation, int connection, String id) {
        return pendingCamera != null && cameraOperation == operation
                && isCurrentConnection(connection, id) && resolved();
    }

    private Map<String, Object> cameraSnapshot(TouchControlResp response, boolean touch) {
        if (response == null) traceControl("control_response_absent");
        else if (response.getStatus() != BaseRspCmd.RESULT_OK) traceControl("control_response_failed");
        else if (!response.isRead()) traceControl("control_response_not_read");
        else if (response.isTouch() != touch) traceControl("control_response_wrong_channel");
        else if (response.getAppType() < 0 || response.getAppType() > 9) traceControl("control_mode_outside_catalogue");
        else if (touch && response.getSleepTime() == 0) traceControl("control_touch_duration_zero");
        else if (touch && (response.getSleepTime() < 1 || response.getSleepTime() > 10)) traceControl("control_touch_duration_invalid");
        else if (!touch && response.getStrength() == 0) traceControl("control_gesture_strength_zero");
        else if (!touch && (response.getStrength() < 1 || response.getStrength() > 10)) traceControl("control_gesture_strength_invalid");
        else traceControl("control_read_valid");
        if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK || !response.isRead()
                || response.isTouch() != touch) return null;
        return QRingCameraPolicy.snapshot(response.getAppType(), response.getStrength(),
                touch, response.getSleepTime());
    }

    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            if ("openBluetoothControlSettings".equals(call.method)) {
                activity.startActivity(new android.content.Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS));
                result.success(null); return;
            }
            if (monitoringPoisonGeneration == connectionGeneration &&
                    ("readAutoMeasureSettings".equals(call.method) || "setAutoMeasureSetting".equals(call.method)
                    || "readAutoMeasureIntervals".equals(call.method) || "setAutoMeasureInterval".equals(call.method))) {
                result.error("QRING_SETTING_UNCONFIRMED", "请重新连接后读取监测设置", null); return;
            }
            boolean stoppingCamera = "triggerDeviceAction".equals(call.method)
                    && "camera".equals(call.argument("feature")) && Boolean.FALSE.equals(call.argument("enabled"));
            if (stoppingCamera) { stopRemoteCamera(result); return; }
            if ((pendingCamera != null || remoteCameraActive) && ("syncHealthData".equals(call.method)
                    || "startMeasurement".equals(call.method) || "startSport".equals(call.method)
                    || "readSportRecords".equals(call.method) || "readAutoMeasureSettings".equals(call.method)
                    || "setAutoMeasureSetting".equals(call.method) || "readAutoMeasureIntervals".equals(call.method) || "setAutoMeasureInterval".equals(call.method) || "triggerDeviceAction".equals(call.method)
                    || "readDeviceFeature".equals(call.method) || "writeDeviceFeature".equals(call.method))) {
                result.error("DEVICE_BUSY", "设备忙，请稍后重试", null); return;
            }
            if ("connect".equals(call.method) || "disconnect".equals(call.method)
                    || "configureRecoveryTarget".equals(call.method)) {
                resetRemoteCamera();
                finishCamera(null, "QRING_DISCONNECTED", "戒指连接已改变");
            }
            if (manager == null && "configureRecoveryTarget".equals(call.method)
                    && call.argument("id") == null) {
                result.success(null); return;
            }
            ensureSdk();
            if ((Integer.valueOf(connectionGeneration).equals(factoryResetGeneration) ||
                    Integer.valueOf(connectionGeneration).equals(factoryInitializingGeneration)) &&
                    !("disconnect".equals(call.method) || "configureRecoveryTarget".equals(call.method) ||
                    "getCapabilities".equals(call.method) || "getDeviceDetails".equals(call.method))) {
                result.error("DEVICE_BUSY", "戒指正在重置，请重新连接后继续", null); return;
            }
            switch (call.method) {
                case "clearRingHistory": resetFirstMemberRing(call, result); break;
                case "scanDevices": startScan(result); break;
                case "lookupBondedDevice": lookupBondedDevice(call, result); break;
                case "listBondedDevices": listBondedDevices(result); break;
                case "prepareRememberedDevice": prepareRememberedDevice(call, result); break;
                case "configureRecoveryTarget": configureRecoveryTarget(call, result); break;
                case "stopScan": finishScan(); result.success(null); break;
                case "connect": connect(call, result); break;
                case "disconnect":
                    disconnectWithResult(result);
                    break;
                case "getDeviceDetails":
                    if (resolved() && !Integer.valueOf(connectionGeneration).equals(factoryInitializingGeneration)) readBattery();
                    result.success(resolved() ? deviceDetails() : null); break;
                case "getCapabilities":
                    emitFactoryInitialization();
                    if (!resolved()) result.error("CAPABILITIES_UNAVAILABLE", "请先连接戒指", null);
                    else result.success(capabilities());
                    break;
                case "readDeviceFeature":
                case "writeDeviceFeature":
                    if ("gesture_control".equals(call.argument("feature")))
                        gestureControl(call, "writeDeviceFeature".equals(call.method), result);
                    else cameraControl(call, "writeDeviceFeature".equals(call.method), result);
                    break;
                case "syncHealthData": startHealthSync(result); break;
                case "startMeasurement": startMeasurement(call.argument("metric"), result); break;
                case "stopMeasurement": stopMeasurement(call.argument("metric"), result); break;
                case "startSport": startSport(call.argument("mode"), result); break;
                case "stopSport": stopSport(result); break;
                case "readSportRecords": readSportRecords(result); break;
                case "readAutoMeasureIntervals": monitoringInterval(null, null, null, result); break;
                case "setAutoMeasureInterval": {
                    Object raw = call.argument("minutes");
                    if (!(raw instanceof Number) || ((Number)raw).doubleValue() != ((Number)raw).intValue()) {
                        result.error("UNSUPPORTED", "无效监测间隔", null); break;
                    }
                    monitoringInterval(call.argument("type"), ((Number)raw).intValue(), null, result); break;
                }
                case "readAutoMeasureSettings": readAutoSettings(result); break;
                case "setAutoMeasureSetting":
                    setAutoSetting(call.argument("type"), call.argument("enabled"), result);
                    break;
                case "pulseHealthReminder": {
                    String expected = call.argument("expectedDeviceId");
                    if (!resolved() || expected == null || connectedId == null || !expected.equalsIgnoreCase(connectedId)
                            || !RingNamePolicy.isVibratingReminderName(connectedName)) {
                        result.error("HAPTIC_UNAVAILABLE", "此戒指暂不支持振动提醒", null); break;
                    }
                    CommandHandle.getInstance().executeReqCmd(new FindDeviceReq(), null);
                    Map<String, Object> value = new HashMap<>();
                    value.put("accepted", true); value.put("acknowledged", false);
                    result.success(value);
                    break;
                }
                case "triggerDeviceAction":
                    if ("camera".equals(call.argument("feature"))) {
                        remoteCameraCommand(Boolean.FALSE.equals(call.argument("enabled"))
                                ? CameraReq.ACTION_FINISH : CameraReq.ACTION_INTO_CAMARA_UI, result);
                    } else if (!resolved() || !"find_watch".equals(call.argument("feature"))) {
                        result.error("QRING_FEATURE_UNVERIFIED", "此戒指功能暂不支持", null);
                    } else {
                        CommandHandle.getInstance().executeReqCmd(new FindDeviceReq(), null);
                        result.success(null);
                    }
                    break;
                default: result.notImplemented();
            }
        } catch (SecurityException error) {
            result.error("BLE_PERMISSION_REQUIRED", "蓝牙权限已变化，请重新允许", null);
        } catch (RuntimeException error) {
            if (pendingCamera != null) {
                controlChannels.block(pendingControlChannel, connectionGeneration);
                finishCamera(null, "QRING_SDK_ERROR", "拍照状态未确认，请重新连接");
                return;
            }
            Log.e(TAG, "Vendor operation failed: " + call.method, error);
            result.error("QRING_SDK_ERROR", "戒指通信失败，请重试", null);
        }
    }

    private void emit(String type, Map<String, Object> payload) {
        main.post(() -> {
            EventChannel.EventSink target = sink;
            if (target == null) return;
            Map<String, Object> event = new HashMap<>();
            event.put("type", type);
            event.put("payload", payload);
            target.success(event);
        });
    }

    @Override public void onListen(Object arguments, EventChannel.EventSink events) {
        sink = events;
    }

    @Override public void onCancel(Object arguments) {
        sink = null;
    }

    public void dispose() {
        resetRemoteCamera();
        finishCamera(null, "BRIDGE_DISPOSED", "戒指通信已关闭");
        recoveryTargetId = null;
        recoveryContext = null;
        connectionGeneration++;
        if (recoveryRetry != null) main.removeCallbacks(recoveryRetry);
        finishScan();
        failPendingSync("BRIDGE_DISPOSED", "戒指通信已关闭");
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        pendingConnect = null;
        if (disconnectDeadline != null) main.removeCallbacks(disconnectDeadline);
        disconnectDeadline = null;
        if (pendingDisconnect != null) {
            pendingDisconnect.error("BRIDGE_DISPOSED", "戒指通信已关闭", null);
            pendingDisconnect = null;
        }
        if (receiverRegistered && receiver != null) {
            try {
                activity.getApplicationContext().unregisterReceiver(receiver);
            } catch (IllegalArgumentException ignored) { }
        }
        receiverRegistered = false;
        receiver = null;
        sink = null;
    }
}
