package cc.saidian.saydian_app;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import ce.com.cenewbluesdk.CEBC;
import ce.com.cenewbluesdk.entity.MyBleDevice;
import ce.com.cenewbluesdk.entity.k6.K6_Action;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_BATTERY_INFO;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_FUNCTION_CONTROL;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_REAL_O2;
import ce.com.cenewbluesdk.entity.k6.K6_DevInfoStruct;
import ce.com.cenewbluesdk.entity.k6.K6_HeartStruct;
import ce.com.cenewbluesdk.proxy.interfaces.K6BleDataResult;
import ce.com.cenewbluesdk.proxy.interfaces.OnScanDevListener;
import ce.com.cenewbluesdk.proxy.sdkhelper.BluetoothHelper;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Fail-closed HR01 adapter. Only real vendor callbacks prove connection and
 * features; multi-packet history is deliberately not acknowledged here.
 */
public final class CoolWearRingBridge
        implements MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private static final String TAG = "CoolWearRing";
    private static final long SCAN_MS = 8_000L;
    private static final long CONNECT_MS = 28_000L;
    private static final long CAPABILITY_MS = 7_000L;

    private final Activity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final LinkedHashMap<String, Map<String, Object>> scanned = new LinkedHashMap<>();
    private BluetoothHelper helper;
    private EventChannel.EventSink sink;
    private MethodChannel.Result pendingScan;
    private MethodChannel.Result pendingConnect;
    private MethodChannel.Result pendingCapabilities;
    private Runnable scanDeadline;
    private Runnable connectDeadline;
    private Runnable capabilityDeadline;
    private String connectedId;
    private String connectedName;
    private String connectedVendorId;
    private String firmwareVersion;
    private String activeMeasurement;
    private boolean linkConnected;
    private boolean deviceInfoReceived;
    private boolean recoveringConnection;
    private boolean resultEmitted;
    private Integer batteryPercent;
    private Boolean charging;
    private K6_DATA_TYPE_FUNCTION_CONTROL functionControl;

    public CoolWearRingBridge(Activity activity, BinaryMessenger messenger) {
        this.activity = activity;
        new MethodChannel(messenger, "cc.saidian.ring/commands").setMethodCallHandler(this);
        new EventChannel(messenger, "cc.saidian.ring/events").setStreamHandler(this);
    }

    private void ensureSdk() {
        if (helper != null) return;
        helper = BluetoothHelper.getInstance();
        helper.init();
        helper.initProxy(activity.getApplicationContext());
        helper.scanningDeviceInit(activity, new OnScanDevListener() {
            @Override public void onFindDev(ScanResult result) { }

            @Override public void onFindDevList(
                    ScanResult result, List<MyBleDevice> devices, MyBleDevice found) {
                main.post(() -> receiveScannedDevices(devices));
            }
        });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_BLUE_CONNECT_STATE_CHANGE,
                (K6BleDataResult<Integer>) status -> {
                    main.post(() -> onConnectionState(status));
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DEVINFO,
                (K6BleDataResult<K6_DevInfoStruct>) info -> {
                    main.post(() -> onDeviceInfo(info));
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_FUNCTION_CONTROL,
                (K6BleDataResult<K6_DATA_TYPE_FUNCTION_CONTROL>) control -> {
                    main.post(() -> onFunctionControl(control));
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_BATTERY,
                (K6BleDataResult<K6_DATA_TYPE_BATTERY_INFO>) battery -> {
                    main.post(() -> onBattery(battery));
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_SPORT_HEART_FOR_SHOW,
                (K6BleDataResult<ArrayList<K6_HeartStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_HeartStruct> snapshot = new ArrayList<>(values);
                        main.post(() -> onHeartValues(snapshot));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_REAL_O2,
                (K6BleDataResult<ArrayList<K6_DATA_TYPE_REAL_O2>>) values -> {
                    if (values != null) {
                        ArrayList<K6_DATA_TYPE_REAL_O2> snapshot = new ArrayList<>(values);
                        main.post(() -> onOxygenValues(snapshot));
                    }
                    return false;
                });
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
        BluetoothManager manager =
                (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        return manager != null && manager.getAdapter() != null && manager.getAdapter().isEnabled();
    }

    private static boolean isHr01(String name) {
        if (name == null) return false;
        String normalized = name.trim().toUpperCase(Locale.ROOT);
        return normalized.equals("HR01") || normalized.startsWith("HR01-");
    }

    private void receiveScannedDevices(List<MyBleDevice> devices) {
        if (pendingScan == null || devices == null) return;
        for (MyBleDevice device : devices) {
            if (device == null || device.getmBluetoothDevice() == null) continue;
            String name = device.getName();
            String id = device.getmBluetoothDevice().getAddress();
            if (!isHr01(name) || id == null || id.isEmpty()) continue;
            Map<String, Object> value = new HashMap<>();
            value.put("id", id);
            value.put("name", name.trim());
            value.put("model", "HR01");
            value.put("rssi", device.getRssi());
            if (device.getmK6ManufacturerInfo() != null) {
                value.put("vendorId", device.getmK6ManufacturerInfo().name);
            }
            boolean fresh = !scanned.containsKey(id);
            scanned.put(id, value);
            if (fresh) emit("scanDevice", value);
        }
    }

    private void finishScan() {
        if (scanDeadline != null) main.removeCallbacks(scanDeadline);
        scanDeadline = null;
        if (helper != null) helper.stopScan();
        MethodChannel.Result result = pendingScan;
        pendingScan = null;
        if (result != null) result.success(new ArrayList<>(scanned.values()));
    }

    private void failConnect(String code, String message) {
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        MethodChannel.Result result = pendingConnect;
        pendingConnect = null;
        if (result != null) result.error(code, message, null);
        linkConnected = false;
        deviceInfoReceived = false;
        functionControl = null;
        activeMeasurement = null;
        recoveringConnection = false;
        connectedId = null;
        connectedName = null;
        connectedVendorId = null;
        if (helper != null) helper.disConnect();
    }

    private void completeConnectIfReady() {
        if (!linkConnected || !deviceInfoReceived || pendingConnect == null) return;
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        MethodChannel.Result result = pendingConnect;
        pendingConnect = null;
        Log.i(TAG, "vendor device-info handshake complete");
        result.success(null);
        emit("deviceDetails", deviceDetails());
    }

    private void onConnectionState(Integer status) {
        if (status == null) return;
        if (status == K6_Action.RCVD.BLUE_CONNECTED) {
            if (connectedId == null) {
                helper.disConnect();
                return;
            }
            linkConnected = true;
            Log.i(TAG, "vendor link connected");
            try {
                // The vendor demo persists all three scan identities after
                // BLUE_CONNECTED. Its transport uses these for follow-up
                // commands and direct reconnects.
                helper.getPersistent().setBlueAddress(connectedId);
                helper.getPersistent().setDevName(connectedName);
                if (connectedVendorId != null && !connectedVendorId.isEmpty()) {
                    helper.getPersistent().setDeviceId(connectedVendorId);
                }
                helper.getSendDataManager().sendAsynInfo();
                helper.getSendDataManager().getDevInfo();
            } catch (RuntimeException error) {
                Log.e(TAG, "vendor handshake rejected: " + error.getClass().getSimpleName());
                failConnect("COOLWEAR_HANDSHAKE_FAILED", "戒指信息读取失败，请重试");
                return;
            }
            completeConnectIfReady();
        } else if (status == K6_Action.RCVD.BLUE_DISCONNECT) {
            String retiredId = connectedId;
            linkConnected = false;
            deviceInfoReceived = false;
            functionControl = null;
            activeMeasurement = null;
            if (pendingConnect != null) {
                failConnect("COOLWEAR_DISCONNECTED", "戒指连接中断，请靠近手机后重试");
            } else if (retiredId != null) {
                recoveringConnection = true;
                Map<String, Object> event = new HashMap<>();
                event.put("deviceId", retiredId);
                emit("disconnected", event);
            }
            Log.i(TAG, "vendor link disconnected");
        }
    }

    private void onDeviceInfo(K6_DevInfoStruct info) {
        if (connectedId == null || info == null) return;
        firmwareVersion = info.getSoftwareVer();
        deviceInfoReceived = true;
        try {
            helper.setEnableGsDataTrans(true);
        } catch (RuntimeException ignored) {
            // Some firmware revisions do not expose this optional channel.
        }
        completeConnectIfReady();
        if (recoveringConnection && pendingConnect == null && linkConnected) {
            recoveringConnection = false;
            Log.i(TAG, "vendor link recovered");
            emit("reconnected", deviceDetails());
        }
        if (pendingConnect == null && linkConnected) emit("deviceDetails", deviceDetails());
    }

    private void onFunctionControl(K6_DATA_TYPE_FUNCTION_CONTROL control) {
        if (connectedId == null || control == null) return;
        functionControl = control;
        Log.i(TAG, "vendor function flags received");
        if (pendingCapabilities != null) {
            if (capabilityDeadline != null) main.removeCallbacks(capabilityDeadline);
            capabilityDeadline = null;
            MethodChannel.Result result = pendingCapabilities;
            pendingCapabilities = null;
            result.success(capabilities());
        }
        if (linkConnected && deviceInfoReceived) emit("capabilitiesUpdated", capabilities());
    }

    private void onBattery(K6_DATA_TYPE_BATTERY_INFO value) {
        if (connectedId == null || value == null) return;
        int percent = value.getBattery();
        if (percent < 0 || percent > 100) return;
        batteryPercent = percent;
        charging = value.isChargerStatus();
        if (linkConnected && deviceInfoReceived) emit("deviceDetails", deviceDetails());
    }

    private Map<String, Object> deviceDetails() {
        Map<String, Object> value = new HashMap<>();
        value.put("id", connectedId);
        value.put("name", connectedName == null ? "HR01" : connectedName);
        value.put("model", "HR01");
        value.put("hardwareAddress", connectedId);
        if (firmwareVersion != null && !firmwareVersion.isEmpty()) {
            value.put("firmwareVersion", firmwareVersion);
        }
        if (batteryPercent != null) {
            Map<String, Object> battery = new HashMap<>();
            battery.put("value", batteryPercent);
            battery.put("scale", 100);
            battery.put("isPercent", true);
            battery.put("chargeState", Boolean.TRUE.equals(charging) ? "charging" : "normal");
            value.put("battery", battery);
            value.put("batteryPercent", batteryPercent);
        }
        return value;
    }

    private Map<String, Object> capabilities() {
        K6_DATA_TYPE_FUNCTION_CONTROL flags = functionControl;
        Map<String, Object> value = new HashMap<>();
        value.put("resolved", flags != null && linkConnected && deviceInfoReceived);
        List<String> metrics = new ArrayList<>();
        List<String> manual = new ArrayList<>();
        if (flags != null) {
            if (flags.isHasHR24H() || flags.isHr_measure_button()) {
                metrics.add("heart_rate");
            }
            if (flags.isHr_measure_button()) manual.add("heart_rate");
            if (flags.isHasO2()) {
                metrics.add("blood_oxygen");
                manual.add("blood_oxygen");
            }
            if (flags.isHasHrvSupported()) metrics.add("hrv");
            if (flags.isHasTemperature()) metrics.add("body_temperature");
            if (flags.isHasBp()) metrics.add("blood_pressure");
            if (flags.isHasEcg()) metrics.add("ecg");
        }
        value.put("metrics", metrics);
        value.put("manualMetrics", manual);
        value.put("sportModes", new ArrayList<String>());
        value.put("features", new ArrayList<String>());
        value.put("supportsSportPause", false);
        value.put("supportsBackgroundSync", false);
        value.put("supportsWatchFaces", false);
        value.put("supportsOta", false);
        return value;
    }

    private static long plausibleTimestamp(long raw) {
        if (raw <= 0) return 0;
        long milliseconds = raw < 100_000_000_000L ? raw * 1_000L : raw;
        return Math.abs(System.currentTimeMillis() - milliseconds)
                <= TimeUnit.MINUTES.toMillis(10) ? milliseconds : 0;
    }

    private void onHeartValues(List<K6_HeartStruct> values) {
        if (!"heart_rate".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        Log.i(TAG, "manual heart callback received; sample count=" + values.size());
        for (K6_HeartStruct value : values) {
            long time = plausibleTimestamp(value.getTime());
            int bpm = value.getHeartNums();
            if (time != 0 && bpm > 0 && bpm <= 250) {
                emitMeasurement("heart_rate", time, bpm, "bpm");
                return;
            }
        }
        Log.i(TAG, "manual heart callback had no current valid sample");
    }

    private void onOxygenValues(List<K6_DATA_TYPE_REAL_O2> values) {
        if (!"blood_oxygen".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        Log.i(TAG, "manual oxygen callback received; sample count=" + values.size());
        for (K6_DATA_TYPE_REAL_O2 value : values) {
            long time = plausibleTimestamp(value.getTime());
            int percent = value.getValue();
            if (time != 0 && percent > 0 && percent <= 100) {
                emitMeasurement("blood_oxygen", time, percent, "%");
                return;
            }
        }
        Log.i(TAG, "manual oxygen callback had no current valid sample");
    }

    private void emitMeasurement(String metric, long time, int amount, String unit) {
        if (connectedId == null || resultEmitted) return;
        resultEmitted = true;
        String recordKey = connectedId + '|' + metric + '|' + time + '|' + amount;
        Map<String, Object> record = new HashMap<>();
        record.put("id", UUID.nameUUIDFromBytes(recordKey.getBytes(StandardCharsets.UTF_8)).toString());
        record.put("type", metric);
        Map<String, Object> values = new HashMap<>();
        values.put("value", amount);
        record.put("values", values);
        record.put("unit", unit);
        record.put("measuredAt", Instant.ofEpochMilli(time).toString());
        record.put("timezone", ZoneId.systemDefault().getRules()
                .getOffset(Instant.ofEpochMilli(time)).toString());
        record.put("deviceId", "coolwear:" + connectedId);
        record.put("firmwareVersion", firmwareVersion == null ? "" : firmwareVersion);
        record.put("quality", "unknown");
        record.put("source", "wearable");
        record.put("origin", "app_measurement");
        record.put("rawVersion", 1);
        record.put("sourceVendor", "coolwear");
        record.put("sourceDeviceCategory", "ring");
        record.put("sourceApp", "say-ring");
        emit("healthRecord", record);
    }

    private void emit(String type, Map<String, Object> payload) {
        main.post(() -> {
            EventChannel.EventSink target = sink;
            if (target != null) {
                Map<String, Object> event = new HashMap<>();
                event.put("type", type);
                event.put("payload", payload);
                target.success(event);
            }
        });
    }

    @Override public void onListen(Object arguments, EventChannel.EventSink events) {
        sink = events;
    }

    @Override public void onCancel(Object arguments) {
        sink = null;
    }

    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            main.post(() -> onMethodCall(call, result));
            return;
        }
        try {
            if (!hasBlePermissions()) {
                result.error("BLE_PERMISSION_REQUIRED", "请允许附近设备权限后重试", null);
                return;
            }
            if (!isBluetoothEnabled()) {
                result.error("BLUETOOTH_DISABLED", "请先开启手机蓝牙", null);
                return;
            }
            ensureSdk();
            switch (call.method) {
                case "scanDevices":
                    if (pendingScan != null) {
                        result.error("SCAN_BUSY", "戒指扫描正在进行", null);
                        return;
                    }
                    scanned.clear();
                    pendingScan = result;
                    helper.startScan();
                    scanDeadline = this::finishScan;
                    main.postDelayed(scanDeadline, SCAN_MS);
                    break;
                case "stopScan":
                    finishScan();
                    result.success(null);
                    break;
                case "connect":
                    String id = call.argument("id");
                    if (id == null || !scanned.containsKey(id) || pendingConnect != null) {
                        result.error("UNKNOWN_SCANNED_DEVICE", "请重新扫描并选择 HR01 戒指", null);
                        return;
                    }
                    finishScan();
                    connectedId = id;
                    connectedName = (String) scanned.get(id).get("name");
                    connectedVendorId = (String) scanned.get(id).get("vendorId");
                    linkConnected = false;
                    deviceInfoReceived = false;
                    firmwareVersion = null;
                    functionControl = null;
                    batteryPercent = null;
                    charging = null;
                    activeMeasurement = null;
                    recoveringConnection = false;
                    pendingConnect = result;
                    helper.connectDev(id, "");
                    connectDeadline = () -> failConnect(
                            "COOLWEAR_HANDSHAKE_TIMEOUT", "戒指未完成设备信息握手，请重试");
                    main.postDelayed(connectDeadline, CONNECT_MS);
                    break;
                case "disconnect":
                    finishScan();
                    if (pendingConnect != null) failConnect("CONNECT_CANCELLED", "连接已取消");
                    else helper.disConnect();
                    connectedId = null;
                    connectedVendorId = null;
                    connectedName = null;
                    linkConnected = false;
                    deviceInfoReceived = false;
                    recoveringConnection = false;
                    functionControl = null;
                    activeMeasurement = null;
                    result.success(null);
                    break;
                case "getDeviceDetails":
                    result.success(linkConnected && deviceInfoReceived ? deviceDetails() : null);
                    break;
                case "getCapabilities":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                    } else if (functionControl != null) {
                        result.success(capabilities());
                    } else if (pendingCapabilities != null) {
                        result.error("CAPABILITIES_BUSY", "正在读取戒指功能", null);
                    } else {
                        pendingCapabilities = result;
                        helper.getSendDataManager().sendAsynInfo();
                        capabilityDeadline = () -> {
                            MethodChannel.Result pending = pendingCapabilities;
                            pendingCapabilities = null;
                            if (pending != null) pending.error(
                                    "CAPABILITIES_UNAVAILABLE", "戒指未返回功能位", null);
                        };
                        main.postDelayed(capabilityDeadline, CAPABILITY_MS);
                    }
                    break;
                case "syncHealthData":
                    result.error("HISTORY_UNVERIFIED", "历史多包完成和确认协议尚未验证，暂不读取", null);
                    break;
                case "startMeasurement":
                    String metric = call.argument("metric");
                    if (!linkConnected || !deviceInfoReceived || functionControl == null) {
                        result.error("CAPABILITIES_UNAVAILABLE", "请先读取戒指功能", null);
                        return;
                    }
                    List<?> manual = (List<?>) capabilities().get("manualMetrics");
                    if (metric == null || !manual.contains(metric)) {
                        result.error("COOLWEAR_FEATURE_UNVERIFIED", "此项手动测量未获戒指确认", null);
                        return;
                    }
                    activeMeasurement = metric;
                    resultEmitted = false;
                    Log.i(TAG, "manual measurement command start: " + metric);
                    setMeasurement(metric, true);
                    result.success(null);
                    break;
                case "stopMeasurement":
                    String stopping = call.argument("metric");
                    Log.i(TAG, "manual measurement command stop: " + stopping);
                    activeMeasurement = null;
                    resultEmitted = false;
                    if (stopping != null) setMeasurement(stopping, false);
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
            }
        } catch (SecurityException error) {
            result.error("BLE_PERMISSION_REQUIRED", "蓝牙权限已变化，请重新允许", null);
        } catch (RuntimeException error) {
            Log.e(TAG, "vendor operation failed: " + call.method);
            result.error("COOLWEAR_SDK_ERROR", "戒指通信失败，请重试", null);
        }
    }

    private void setMeasurement(String metric, boolean enabled) {
        int state = enabled ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE;
        if ("heart_rate".equals(metric)) {
            helper.getSendBlueData().sendHeartRateSwitch(state);
        } else if ("blood_oxygen".equals(metric)) {
            helper.getSendBlueData().sendBloodOxygenDetection(state);
        }
    }

    public void dispose() {
        if (scanDeadline != null) main.removeCallbacks(scanDeadline);
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        if (capabilityDeadline != null) main.removeCallbacks(capabilityDeadline);
        if (helper != null) {
            helper.stopScan();
            helper.disConnect();
        }
        sink = null;
    }
}
