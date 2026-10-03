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
import android.util.Log;

import androidx.core.content.ContextCompat;

import com.oudmon.ble.base.bean.SleepDisplay;
import com.oudmon.ble.base.bluetooth.BleAction;
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
import com.oudmon.ble.base.communication.req.DeviceSupportReq;
import com.oudmon.ble.base.communication.req.FindDeviceReq;
import com.oudmon.ble.base.communication.req.HeartRateSettingReq;
import com.oudmon.ble.base.communication.req.HrvSettingReq;
import com.oudmon.ble.base.communication.req.PhoneSportReq;
import com.oudmon.ble.base.communication.req.PressureSettingReq;
import com.oudmon.ble.base.communication.req.SetTimeReq;
import com.oudmon.ble.base.communication.req.SimpleKeyReq;
import com.oudmon.ble.base.communication.req.TimeFormatReq;
import com.oudmon.ble.base.communication.rsp.AppSportRsp;
import com.oudmon.ble.base.communication.rsp.BaseRspCmd;
import com.oudmon.ble.base.communication.rsp.BatteryRsp;
import com.oudmon.ble.base.communication.rsp.BloodOxygenSettingRsp;
import com.oudmon.ble.base.communication.rsp.DeviceSupportFunctionRsp;
import com.oudmon.ble.base.communication.rsp.HRVRsp;
import com.oudmon.ble.base.communication.rsp.HRVSettingRsp;
import com.oudmon.ble.base.communication.rsp.HeartRateSettingRsp;
import com.oudmon.ble.base.communication.rsp.PressureRsp;
import com.oudmon.ble.base.communication.rsp.PressureSettingRsp;
import com.oudmon.ble.base.communication.rsp.ReadHeartRateRsp;
import com.oudmon.ble.base.communication.rsp.SetTimeRsp;
import com.oudmon.ble.base.communication.rsp.StartHeartRateRsp;
import com.oudmon.ble.base.communication.rsp.TimeFormatRsp;
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
    private static final long SYNC_MS = 165_000L;

    private final Activity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final LinkedHashMap<String, Map<String, Object>> scanned = new LinkedHashMap<>();
    private final LinkedHashMap<String, Map<String, Object>> syncRecords = new LinkedHashMap<>();
    private EventChannel.EventSink sink;
    private BleOperateManager manager;
    private QCBluetoothCallbackCloneReceiver receiver;
    private boolean receiverRegistered;
    private MethodChannel.Result pendingScan;
    private MethodChannel.Result pendingConnect;
    private MethodChannel.Result pendingSync;
    private Runnable scanDeadline;
    private Runnable connectDeadline;
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
    private String activeSportMode;
    private Integer activeSportType;
    private boolean manualResultEmitted;
    private Boolean autoHeart;
    private Boolean autoOxygen;
    private Boolean autoStress;
    private Boolean autoHrv;
    private int connectionGeneration;
    private String batteryUpdatedAt;
    private long batteryQueryAt;
    private String recoveryTargetId;
    private String recoveryTargetName;
    private String recoveryContext;
    private Map<String, Object> recoveryProfile;
    private boolean recoveryConnecting;
    private boolean cancellingConnection;
    private boolean handshakeStarted;
    private MethodChannel.Result pendingDisconnect;
    private Runnable recoveryRetry;

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
        if (name == null) return false;
        String normalized = name.trim().toUpperCase(Locale.ROOT);
        return normalized.startsWith("Q_") || normalized.startsWith("O_")
                || normalized.startsWith("R2");
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
        if (pendingScan != null) {
            finishScan();
        }
        scanned.clear();
        pendingScan = result;
        BleScannerHelper.getInstance().reSetCallback();
        BleScannerHelper.getInstance().scanDevice(activity, null, new ScanWrapperCallback() {
            @Override public void onStart() { }
            @Override public void onStop() { main.post(QRingBridge.this::finishScan); }
            @Override public void onScanFailed(int errorCode) {
                main.post(() -> failScan("QRING_SCAN_FAILED", "搜索戒指失败，请重试"));
            }
            // onLeScan carries the same advertisement plus RSSI; handle both there.
            @Override public void onParsedData(BluetoothDevice device, ScanRecord record) { }
            @Override public void onBatchScanResults(List<ScanResult> results) { }

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
                main.post(() -> receiveScan(device, rssi, advertisedName));
            }
        });
        scanDeadline = this::finishScan;
        main.postDelayed(scanDeadline, SCAN_MS);
    }

    private void receiveScan(BluetoothDevice device, int rssi, String advertisedName) {
        String cachedName;
        try {
            cachedName = device.getName();
        } catch (SecurityException error) {
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
        if (scanDeadline != null) main.removeCallbacks(scanDeadline);
        scanDeadline = null;
        if (pendingScan == null) return;
        MethodChannel.Result result = pendingScan;
        pendingScan = null;
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
        manager.disconnect();
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

    private void writeProfileThenFinish() {
        final int generation = connectionGeneration;
        final String id = connectedId;
        int sdkGender = profileInt("gender", 1, 1, 2) == 2 ? 1 : 0;
        TimeFormatReq request = TimeFormatReq.getWriteInstance(
                true, 0, sdkGender,
                profileInt("age", 30, 5, 120),
                profileInt("heightCm", 175, 80, 240),
                profileInt("weightKg", 70, 20, 250),
                0, 0, 0);
        CommandHandle.getInstance().executeReqCmd(
                request,
                (ICommandResponse<TimeFormatRsp>) ignored -> main.post(() -> {
                    if (isCurrentConnection(generation, id)) finishHandshake();
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
        if (deviceId == null || pendingSync != null || activeMeasurement != null ||
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
        manualResultEmitted = false;
        Map<String, Object> progress = new HashMap<>();
        progress.put("metric", metric);
        progress.put("progress", 5);
        emit("measurementProgress", progress);
        runMeasurement(metric, false);
        result.success(null);
    }

    private void runMeasurement(String metric, boolean stop) {
        ICommandResponse<StartHeartRateRsp> callback = response -> main.post(() -> {
            if (stop || response == null || !metric.equals(activeMeasurement)) return;
            if (response.getStatus() != BaseRspCmd.RESULT_OK) {
                emitMeasurementError(response.getErrCode());
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
    }

    private void emitMeasurementError(int errorCode) {
        Map<String, Object> value = new HashMap<>();
        value.put("code", errorCode == 3 ? "MEASUREMENT_NOT_WORN" : "MEASUREMENT_FAILED");
        value.put("message", errorCode == 3
                ? "未检测到正确佩戴，请调整戒指后重试" : "戒指未返回有效测量结果，请保持静止后重试");
        emit("error", value);
        activeMeasurement = null;
    }

    private void stopMeasurement(String metric, MethodChannel.Result result) {
        if (metric != null) runMeasurement(metric, true);
        activeMeasurement = null;
        manualResultEmitted = false;
        result.success(null);
    }

    private void startHealthSync(MethodChannel.Result result) {
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
        syncDeadline = () -> failPendingSync("SYNC_TIMEOUT", "戒指数据同步超时，请重试");
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
                manager.getStepDetail(day, callback(
                        values -> collect(QRingRecordMapper.stepRecords(
                                connectedId, connectedName, firmwareVersion, day, values)),
                        () -> syncDay(day, 1)));
                break;
            case 1:
                if (!supportsMetric("sleep", false)) { syncDay(day, 2); return; }
                final MethodChannel.Result sleepSync = pendingSync;
                final String sleepDeviceId = connectedId;
                final int sleepConnectionGeneration = connectionGeneration;
                final QRingRecordMapper.SleepRequestDay sleepRequestDay = QRingRecordMapper.sleepRequestDay(day);
                manager.getSleep(day, new BleOperateManager.HealthDataCallback<SleepDisplay>() {
                    @Override public void onSuccess(SleepDisplay value) {
                        main.post(() -> {
                            if (pendingSync != sleepSync || !isCurrentConnection(sleepConnectionGeneration, sleepDeviceId)) return;
                            Map<String, Object> timeline = QRingRecordMapper.sleepTimelineForSuccessfulRead(
                                    sleepDeviceId, sleepRequestDay, value);
                            boolean complete = QRingRecordMapper.sleepTimelineIsComplete(timeline);
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
                manager.getHeartRate(day, callback(
                        value -> collect(QRingRecordMapper.heartRecords(
                                connectedId, connectedName, firmwareVersion, day, value)),
                        () -> syncDay(day, 3)));
                break;
            case 3:
                if (!supportsMetric("blood_oxygen", false)) { syncDay(day, 4); return; }
                manager.getBloodOxygen(day, callback(
                        value -> collect(QRingRecordMapper.oxygenRecords(
                                connectedId, connectedName, firmwareVersion, day, value)),
                        () -> syncDay(day, 4)));
                break;
            case 4:
                if (!supportsMetric("stress", false)) { syncDay(day, 5); return; }
                manager.getPressure(day, callback(
                        value -> collect(QRingRecordMapper.stressRecords(
                                connectedId, connectedName, firmwareVersion, day, value)),
                        () -> syncDay(day, 5)));
                break;
            case 5:
                if (!supportsMetric("hrv", false)) { syncDay(day, 6); return; }
                manager.getHrv(day, callback(
                        value -> collect(QRingRecordMapper.hrvRecords(
                                connectedId, connectedName, firmwareVersion, day, value)),
                        () -> syncDay(day, 6)));
                break;
            case 6:
                if (!supportsMetric("body_temperature", false)) { syncDay(day + 1, 0); return; }
                manager.getTemperature(day, callback(
                        value -> collect(QRingRecordMapper.temperatureRecords(
                                connectedId, connectedName, firmwareVersion, day, value)),
                        () -> syncDay(day + 1, 0)));
                break;
            default:
                syncDay(day + 1, 0);
        }
    }

    private interface ValueConsumer<T> { void accept(T value); }

    private <T> BleOperateManager.HealthDataCallback<T> callback(
            ValueConsumer<T> consumer, Runnable next) {
        return new BleOperateManager.HealthDataCallback<T>() {
            @Override public void onSuccess(T value) {
                main.post(() -> {
                    if (pendingSync == null) return;
                    consumer.accept(value);
                    next.run();
                });
            }

            @Override public void onError(int code, String message) {
                main.post(() -> {
                    if (pendingSync != null) next.run();
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
        result.success(new ArrayList<>(syncRecords.values()));
    }

    private void failPendingSync(String code, String message) {
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        syncDeadline = null;
        if (pendingSync == null) return;
        MethodChannel.Result result = pendingSync;
        pendingSync = null;
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
            result.success(autoSettings());
            return;
        }
        CommandHandle.getInstance().executeReqCmd(
                HrvSettingReq.getReadInstance(),
                (ICommandResponse<HRVSettingRsp>) hrv -> main.post(() -> {
                    autoHrv = hrv != null && hrv.getStatus() == BaseRspCmd.RESULT_OK
                            ? hrv.isEnable() : null;
                    result.success(autoSettings());
                }));
    }

    private Map<String, Object> autoSettings() {
        Map<String, Object> value = new HashMap<>();
        if (autoHeart != null) value.put("heartRate", autoHeart);
        if (autoOxygen != null) value.put("bloodOxygen", autoOxygen);
        if (autoStress != null) value.put("stress", autoStress);
        if (autoHrv != null) value.put("hrv", autoHrv);
        return value;
    }

    private void setAutoSetting(String type, Boolean enabled, MethodChannel.Result result) {
        if (!resolved() || enabled == null) {
            result.error("QRING_FEATURE_UNVERIFIED", "此自动检测项目暂不支持", null);
            return;
        }
        if ("heartRate".equals(type) && supportsMetric("heart_rate", false)) {
            CommandHandle.getInstance().executeReqCmd(
                    HeartRateSettingReq.getWriteInstance(enabled, 10, 10, 40, 110),
                    (ICommandResponse<HeartRateSettingRsp>) response -> main.post(() -> {
                        if (response != null && response.getStatus() == BaseRspCmd.RESULT_OK) {
                            autoHeart = enabled;
                            result.success(null);
                        } else result.error("QRING_SETTING_FAILED", "自动心率设置失败", null);
                    }));
        } else if ("bloodOxygen".equals(type) && supportsMetric("blood_oxygen", false)) {
            CommandHandle.getInstance().executeReqCmd(
                    BloodOxygenSettingReq.getWriteInstance(enabled),
                    (ICommandResponse<BloodOxygenSettingRsp>) response -> main.post(() -> {
                        if (response != null && response.getStatus() == BaseRspCmd.RESULT_OK) {
                            autoOxygen = enabled;
                            result.success(null);
                        } else result.error("QRING_SETTING_FAILED", "自动血氧设置失败", null);
                    }));
        } else if ("stress".equals(type) && supportsMetric("stress", false)) {
            CommandHandle.getInstance().executeReqCmd(
                    PressureSettingReq.getWriteInstance(enabled),
                    (ICommandResponse<PressureSettingRsp>) response -> main.post(() -> {
                        if (response != null && response.getStatus() == BaseRspCmd.RESULT_OK) {
                            autoStress = enabled;
                            result.success(null);
                        } else result.error("QRING_SETTING_FAILED", "自动压力设置失败", null);
                    }));
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

    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            if (manager == null && "configureRecoveryTarget".equals(call.method)
                    && call.argument("id") == null) {
                result.success(null); return;
            }
            ensureSdk();
            switch (call.method) {
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
                    if (resolved()) readBattery();
                    result.success(resolved() ? deviceDetails() : null); break;
                case "getCapabilities":
                    if (!resolved()) result.error("CAPABILITIES_UNAVAILABLE", "请先连接戒指", null);
                    else result.success(capabilities());
                    break;
                case "syncHealthData": startHealthSync(result); break;
                case "startMeasurement": startMeasurement(call.argument("metric"), result); break;
                case "stopMeasurement": stopMeasurement(call.argument("metric"), result); break;
                case "startSport": startSport(call.argument("mode"), result); break;
                case "stopSport": stopSport(result); break;
                case "readSportRecords": readSportRecords(result); break;
                case "readAutoMeasureSettings": readAutoSettings(result); break;
                case "setAutoMeasureSetting":
                    setAutoSetting(call.argument("type"), call.argument("enabled"), result);
                    break;
                case "triggerDeviceAction":
                    if (!resolved() || !"find_watch".equals(call.argument("feature"))) {
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
        recoveryTargetId = null;
        recoveryContext = null;
        connectionGeneration++;
        if (recoveryRetry != null) main.removeCallbacks(recoveryRetry);
        finishScan();
        failPendingSync("BRIDGE_DISPOSED", "戒指通信已关闭");
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        pendingConnect = null;
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
