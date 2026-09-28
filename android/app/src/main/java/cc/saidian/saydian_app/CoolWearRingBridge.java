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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import ce.com.cenewbluesdk.CEBC;
import ce.com.cenewbluesdk.entity.K6_sleepData;
import ce.com.cenewbluesdk.entity.MyBleDevice;
import ce.com.cenewbluesdk.entity.k6.K6_Action;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_BATTERY_INFO;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_FUNCTION_CONTROL;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_HEART_AUTO_SWITCH;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_REAL_O2;
import ce.com.cenewbluesdk.entity.k6.K6_DevInfoStruct;
import ce.com.cenewbluesdk.entity.k6.K6_HeartStruct;
import ce.com.cenewbluesdk.entity.k6.K6_HrvStruct;
import ce.com.cenewbluesdk.entity.k6.K6_Mix_sport_Struct;
import ce.com.cenewbluesdk.entity.k6.K6_SEND_APP_SPORT_STRUCT;
import ce.com.cenewbluesdk.entity.k6.K6_Sport;
import ce.com.cenewbluesdk.entity.k6.K6_StressStruct;
import ce.com.cenewbluesdk.entity.k6.K6_TempStruct;
import ce.com.cenewbluesdk.entity.k6.k6_RRI_HRV_DATA;
import ce.com.cenewbluesdk.proxy.interfaces.K6BleDataResult;
import ce.com.cenewbluesdk.proxy.interfaces.OnScanDevListener;
import ce.com.cenewbluesdk.proxy.sdkhelper.BluetoothHelper;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Fail-closed HR01 adapter. A real device-info callback proves the HR01
 * protocol baseline; function flags still gate optional health features.
 * History completion and live sport state require their vendor callbacks.
 */
public final class CoolWearRingBridge
        implements MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private static final String TAG = "CoolWearRing";
    private static final long SCAN_MS = 8_000L;
    private static final long CONNECT_MS = 28_000L;
    private static final long SYNC_MS = 30_000L;
    private static final long SETTINGS_MS = 5_000L;

    private final Activity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final LinkedHashMap<String, Map<String, Object>> scanned = new LinkedHashMap<>();
    private BluetoothHelper helper;
    private EventChannel.EventSink sink;
    private MethodChannel.Result pendingScan;
    private MethodChannel.Result pendingConnect;
    private MethodChannel.Result pendingHealthSync;
    private MethodChannel.Result pendingSportSync;
    private MethodChannel.Result pendingAutoSettings;
    private Runnable scanDeadline;
    private Runnable connectDeadline;
    private Runnable syncDeadline;
    private Runnable settingsDeadline;
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
    private Boolean autoHeartEnabled;
    private Boolean autoOxygenEnabled;
    private int autoMeasureIntervalMinutes = 5;
    private final LinkedHashMap<String, Map<String, Object>> syncedHealthRecords =
            new LinkedHashMap<>();
    private final LinkedHashMap<String, Map<String, Object>> syncedSportRecords =
            new LinkedHashMap<>();
    private String activeSportMode;
    private Integer activeSportType;

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
                K6_Action.RCVD.RCVD_K6_DATA_TYPE_HEART_AUTO_SWITCH,
                (K6BleDataResult<K6_DATA_TYPE_HEART_AUTO_SWITCH>) settings -> {
                    if (settings != null) main.post(() -> onAutoMeasureSettings(settings));
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_TAKE_PHOTOS,
                (K6BleDataResult<Integer>) state -> {
                    if (state != null && state == CEBC.OPENSTATUS.OPEN) {
                        main.post(() -> emit("cameraShutter", new HashMap<>()));
                    }
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
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DAILY_HEART,
                (K6BleDataResult<ArrayList<K6_HeartStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_HeartStruct> snapshot = new ArrayList<>(values);
                        main.post(() -> collectHealth(CoolWearRecordMapper.heartRecords(
                                connectedId, firmwareVersion, snapshot)));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_REAL_O2_HISTORY,
                (K6BleDataResult<ArrayList<K6_DATA_TYPE_REAL_O2>>) values -> {
                    if (values != null) {
                        ArrayList<K6_DATA_TYPE_REAL_O2> snapshot = new ArrayList<>(values);
                        main.post(() -> collectHealth(CoolWearRecordMapper.oxygenRecords(
                                connectedId, firmwareVersion, snapshot)));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_SPORT_DATA,
                (K6BleDataResult<ArrayList<K6_Sport>>) values -> {
                    if (values != null) {
                        ArrayList<K6_Sport> snapshot = new ArrayList<>(values);
                        main.post(() -> collectHealth(CoolWearRecordMapper.activityRecords(
                                connectedId, firmwareVersion, snapshot)));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_K6_SLEEP_DATA,
                (K6BleDataResult<K6_sleepData>) value -> {
                    if (value != null) {
                        main.post(() -> collectHealth(CoolWearRecordMapper.sleepRecords(
                                connectedId, firmwareVersion, value)));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_RRI_HRV,
                (K6BleDataResult<ArrayList<k6_RRI_HRV_DATA>>) values -> {
                    if (values != null) {
                        ArrayList<k6_RRI_HRV_DATA> snapshot = new ArrayList<>(values);
                        main.post(() -> onHrvValues(snapshot));
                    }
                    return false;
                });
        // Type 45 is named both "real HRV" and "real stress" by different
        // CoolWear firmware/SDK generations. The payload shape is identical,
        // so accept the alternate callback only while a stress session is active.
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_SPORT_HRV_FOR_SHOW,
                (K6BleDataResult<ArrayList<K6_HrvStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_HrvStruct> snapshot = new ArrayList<>(values);
                        main.post(() -> onStressCompatValues(snapshot));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_STRESS_SHOW,
                (K6BleDataResult<ArrayList<K6_StressStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_StressStruct> snapshot = new ArrayList<>(values);
                        main.post(() -> onStressValues(snapshot));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_SPORT_TEMP_FOR_SHOW,
                (K6BleDataResult<ArrayList<K6_TempStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_TempStruct> snapshot = new ArrayList<>(values);
                        main.post(() -> collectHealth(CoolWearRecordMapper.temperatureRecords(
                                connectedId, firmwareVersion, snapshot)));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_MIX_SPORT_DATA,
                (K6BleDataResult<ArrayList<K6_Mix_sport_Struct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_Mix_sport_Struct> snapshot = new ArrayList<>(values);
                        main.post(() -> collectSport(CoolWearRecordMapper.sportRecords(
                                connectedId, snapshot)));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_APP_SPORT,
                (K6BleDataResult<K6_SEND_APP_SPORT_STRUCT>) value -> {
                    if (value != null) main.post(() -> onSportUpdate(value));
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_DEV_SYNC,
                (K6BleDataResult<Object>) ignored -> {
                    main.post(this::completeSync);
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

    private void collectHealth(List<Map<String, Object>> records) {
        if (pendingHealthSync == null || records == null) return;
        for (Map<String, Object> record : records) {
            Object id = record.get("id");
            if (id != null) syncedHealthRecords.put(id.toString(), record);
        }
    }

    private void collectSport(List<Map<String, Object>> records) {
        if (pendingSportSync == null || records == null) return;
        for (Map<String, Object> record : records) {
            Object id = record.get("id");
            if (id != null) syncedSportRecords.put(id.toString(), record);
        }
    }

    private void startSync(MethodChannel.Result result, boolean sportOnly) {
        if (!linkConnected || !deviceInfoReceived) {
            result.error("NOT_CONNECTED", "请先连接戒指", null);
            return;
        }
        if (pendingHealthSync != null || pendingSportSync != null) {
            result.error("SYNC_BUSY", "戒指数据正在同步", null);
            return;
        }
        syncedHealthRecords.clear();
        syncedSportRecords.clear();
        if (sportOnly) pendingSportSync = result;
        else pendingHealthSync = result;
        syncDeadline = () -> failPendingSync(
                "COOLWEAR_SYNC_TIMEOUT", "戒指未返回同步完成状态，请重试");
        main.postDelayed(syncDeadline, SYNC_MS);
        try {
            helper.synDevData();
        } catch (RuntimeException error) {
            failPendingSync("COOLWEAR_SYNC_FAILED", "戒指数据同步启动失败，请重试");
        }
    }

    private void completeSync() {
        if (pendingHealthSync == null && pendingSportSync == null) return;
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        syncDeadline = null;
        MethodChannel.Result healthResult = pendingHealthSync;
        MethodChannel.Result sportResult = pendingSportSync;
        pendingHealthSync = null;
        pendingSportSync = null;
        if (healthResult != null) {
            Log.i(TAG, "vendor history sync complete; health records="
                    + syncedHealthRecords.size());
            healthResult.success(new ArrayList<>(syncedHealthRecords.values()));
        }
        if (sportResult != null) {
            Log.i(TAG, "vendor history sync complete; sport records="
                    + syncedSportRecords.size());
            sportResult.success(new ArrayList<>(syncedSportRecords.values()));
        }
    }

    private void failPendingSync(String code, String message) {
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        syncDeadline = null;
        MethodChannel.Result healthResult = pendingHealthSync;
        MethodChannel.Result sportResult = pendingSportSync;
        pendingHealthSync = null;
        pendingSportSync = null;
        syncedHealthRecords.clear();
        syncedSportRecords.clear();
        if (healthResult != null) healthResult.error(code, message, null);
        if (sportResult != null) sportResult.error(code, message, null);
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
            autoHeartEnabled = null;
            autoOxygenEnabled = null;
            failPendingAutoSettings("CONNECTION_DROPPED", "戒指连接中断，请靠近手机后重试");
            activeMeasurement = null;
            activeSportMode = null;
            activeSportType = null;
            failPendingSync("CONNECTION_DROPPED", "戒指连接中断，请靠近手机后重试");
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
        Log.i(TAG, "vendor function flags received: heart="
                + (control.isHasHR24H() || control.isHr_measure_button())
                + ", oxygen=" + control.isHasO2()
                + ", hrv=" + control.isHasHrvSupported()
                + ", temperature=" + control.isHasTemperature());
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

    private void onAutoMeasureSettings(K6_DATA_TYPE_HEART_AUTO_SWITCH settings) {
        autoHeartEnabled = settings.getAutoHROnoff() == CEBC.OPENSTATUS.OPEN;
        autoOxygenEnabled = settings.getAutoO2noff() == CEBC.OPENSTATUS.OPEN;
        int interval = Byte.toUnsignedInt(settings.getTimeInterval());
        if (interval > 0) autoMeasureIntervalMinutes = interval;
        if (pendingAutoSettings == null) return;
        if (settingsDeadline != null) main.removeCallbacks(settingsDeadline);
        settingsDeadline = null;
        MethodChannel.Result result = pendingAutoSettings;
        pendingAutoSettings = null;
        result.success(autoMeasureSettings());
    }

    private Map<String, Object> autoMeasureSettings() {
        Map<String, Object> value = new HashMap<>();
        if (autoHeartEnabled != null) value.put("heartRate", autoHeartEnabled);
        if (autoOxygenEnabled != null) value.put("bloodOxygen", autoOxygenEnabled);
        return value;
    }

    private void failPendingAutoSettings(String code, String message) {
        if (settingsDeadline != null) main.removeCallbacks(settingsDeadline);
        settingsDeadline = null;
        if (pendingAutoSettings == null) return;
        MethodChannel.Result result = pendingAutoSettings;
        pendingAutoSettings = null;
        result.error(code, message, null);
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
        value.put("resolved", linkConnected && deviceInfoReceived);
        List<String> metrics = new ArrayList<>();
        List<String> manual = new ArrayList<>();
        metrics.add("steps");
        metrics.add("distance");
        metrics.add("calories");
        metrics.add("sleep");
        if (flags != null) {
            if (flags.isHasHR24H() || flags.isHr_measure_button()) {
                metrics.add("heart_rate");
            }
            if (flags.isHr_measure_button()) manual.add("heart_rate");
            if (flags.isHasO2()) {
                metrics.add("blood_oxygen");
                manual.add("blood_oxygen");
            }
            if (flags.isHasHrvSupported()) {
                metrics.add("hrv");
                manual.add("hrv");
                // The vendor SDK exposes pressure as an HRV-derived algorithm
                // and does not publish a separate pressure capability bit.
                metrics.add("stress");
                manual.add("stress");
            }
            if (flags.isHasTemperature()) metrics.add("body_temperature");
        }
        value.put("metrics", metrics);
        value.put("manualMetrics", manual);
        List<String> sportModes = new ArrayList<>();
        sportModes.add("running");
        sportModes.add("indoor_running");
        sportModes.add("walking");
        sportModes.add("cycling");
        sportModes.add("indoor_cycling");
        sportModes.add("basketball");
        sportModes.add("football");
        sportModes.add("badminton");
        sportModes.add("swimming");
        sportModes.add("jump_rope");
        sportModes.add("yoga");
        sportModes.add("hiking");
        sportModes.add("mountaineering");
        value.put("sportModes", sportModes);
        List<String> features = new ArrayList<>();
        features.add("find_watch");
        if (flags != null && flags.isHasGestureSupported()) features.add("camera");
        if (flags != null && (flags.isHasHR24H() || flags.isHasO2())) {
            features.add("health_monitoring");
        }
        value.put("features", features);
        value.put("supportsSportPause", linkConnected && deviceInfoReceived);
        value.put("supportsBackgroundSync", false);
        value.put("supportsWatchFaces", false);
        value.put("supportsOta", false);
        return value;
    }

    private void onHeartValues(List<K6_HeartStruct> values) {
        if (activeSportMode != null && linkConnected) {
            for (K6_HeartStruct value : values) {
                long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
                int bpm = value.getHeartNums();
                if (time != 0 && bpm > 0 && bpm <= 250) {
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("heartRate", bpm);
                    emit("sportData", payload);
                    break;
                }
            }
        }
        if (!"heart_rate".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        Log.i(TAG, "manual heart callback received; sample count=" + values.size());
        for (K6_HeartStruct value : values) {
            long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
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
            long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
            int percent = value.getValue();
            if (time != 0 && percent > 0 && percent <= 100) {
                emitMeasurement("blood_oxygen", time, percent, "%");
                return;
            }
        }
        Log.i(TAG, "manual oxygen callback had no current valid sample");
    }

    private void onHrvValues(List<k6_RRI_HRV_DATA> values) {
        collectHealth(CoolWearRecordMapper.hrvRecords(connectedId, firmwareVersion, values));
        if (!"hrv".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        for (k6_RRI_HRV_DATA value : values) {
            long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
            int sdnn = value.getSdnn();
            if (sdnn <= 0 || sdnn > 1_000) continue;
            if (time == 0) time = System.currentTimeMillis();
            Map<String, Object> measured = new LinkedHashMap<>();
            measured.put("value", sdnn);
            measured.put("sdnn", sdnn);
            if (value.getRmssd() > 0) measured.put("rmssd", value.getRmssd());
            if (value.getRri() > 0) measured.put("rri", value.getRri());
            emitMeasurement("hrv", time, measured, "ms");
            return;
        }
    }

    private void onStressValues(List<K6_StressStruct> values) {
        collectHealth(CoolWearRecordMapper.stressRecords(
                connectedId, firmwareVersion, values));
        if (!"stress".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        Log.i(TAG, "manual stress callback received; source=stress, sample count="
                + values.size());
        for (K6_StressStruct value : values) {
            if (value == null) continue;
            long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
            int stress = value.getStressValue();
            if (stress >= 1 && stress <= 100) {
                if (time == 0) time = System.currentTimeMillis();
                emitMeasurement("stress", time, stress, "");
                return;
            }
        }
        Log.i(TAG, "manual stress callback had no current valid sample; source=stress");
    }

    private void onStressCompatValues(List<K6_HrvStruct> values) {
        if (!"stress".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        Log.i(TAG, "manual stress callback received; source=real_hrv, sample count="
                + values.size());
        for (K6_HrvStruct value : values) {
            if (value == null) continue;
            long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
            int stress = value.getHrvNums();
            if (stress >= 1 && stress <= 100) {
                if (time == 0) time = System.currentTimeMillis();
                emitMeasurement("stress", time, stress, "");
                return;
            }
        }
        Log.i(TAG, "manual stress callback had no current valid sample; source=real_hrv");
    }

    private void emitMeasurement(String metric, long time, int amount, String unit) {
        Map<String, Object> values = new HashMap<>();
        values.put("value", amount);
        emitMeasurement(metric, time, values, unit);
    }

    private void emitMeasurement(
            String metric, long time, Map<String, Object> values, String unit) {
        if (connectedId == null || resultEmitted) return;
        resultEmitted = true;
        Map<String, Object> record = CoolWearRecordMapper.healthRecord(
                connectedId, firmwareVersion, metric, time, values, unit,
                "app_measurement", "device_reported");
        emit("healthRecord", record);
    }

    private void sendSportCommand(
            MethodChannel.Result result, String mode, int status, boolean requiresActive) {
        if (!linkConnected || !deviceInfoReceived) {
            result.error("NOT_CONNECTED", "请先连接戒指", null);
            return;
        }
        Integer type = requiresActive ? activeSportType : CoolWearRecordMapper.sportType(mode);
        if (type == null) {
            result.error("COOLWEAR_SPORT_UNAVAILABLE", "当前没有可控制的戒指运动", null);
            return;
        }
        helper.getSendBlueData().sendAppSport(type, status, 0, 0);
        if (!requiresActive) {
            activeSportType = type;
            activeSportMode = mode;
        }
        if (status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP
                || status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP_FORCE) {
            activeSportType = null;
            activeSportMode = null;
        }
        result.success(null);
    }

    private void onSportUpdate(K6_SEND_APP_SPORT_STRUCT value) {
        int type = value.getType();
        int status = value.getStatus();
        String mode = CoolWearRecordMapper.sportMode(type);
        if (mode == null) mode = activeSportMode;
        Map<String, Object> data = new HashMap<>();
        if (value.getTime() >= 0) data.put("durationSeconds", value.getTime());
        if (value.getDistance() >= 0) data.put("distanceMeters", value.getDistance());
        if (!data.isEmpty()) emit("sportData", data);

        String state;
        if (status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP
                || status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP_FORCE) {
            state = "stopped";
            activeSportType = null;
            activeSportMode = null;
        } else {
            activeSportType = type;
            if (mode != null) activeSportMode = mode;
            state = status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_PAUSE
                    ? "paused" : "running";
        }
        Map<String, Object> event = new HashMap<>();
        event.put("value", state);
        event.put("state", status);
        event.put("sportType", type);
        if (mode != null) event.put("mode", mode);
        emit("sportState", event);
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
                    autoHeartEnabled = null;
                    autoOxygenEnabled = null;
                    autoMeasureIntervalMinutes = 5;
                    batteryPercent = null;
                    charging = null;
                    activeMeasurement = null;
                    activeSportMode = null;
                    activeSportType = null;
                    recoveringConnection = false;
                    pendingConnect = result;
                    helper.connectDev(id, "");
                    connectDeadline = () -> failConnect(
                            "COOLWEAR_HANDSHAKE_TIMEOUT", "戒指未完成设备信息握手，请重试");
                    main.postDelayed(connectDeadline, CONNECT_MS);
                    break;
                case "disconnect":
                    finishScan();
                    failPendingSync("CONNECT_CANCELLED", "连接已断开");
                    failPendingAutoSettings("CONNECT_CANCELLED", "连接已断开");
                    if (pendingConnect != null) failConnect("CONNECT_CANCELLED", "连接已取消");
                    else helper.disConnect();
                    connectedId = null;
                    connectedVendorId = null;
                    connectedName = null;
                    linkConnected = false;
                    deviceInfoReceived = false;
                    recoveringConnection = false;
                    functionControl = null;
                    autoHeartEnabled = null;
                    autoOxygenEnabled = null;
                    autoMeasureIntervalMinutes = 5;
                    activeMeasurement = null;
                    activeSportMode = null;
                    activeSportType = null;
                    result.success(null);
                    break;
                case "getDeviceDetails":
                    result.success(linkConnected && deviceInfoReceived ? deviceDetails() : null);
                    break;
                case "getCapabilities":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                    } else {
                        if (functionControl == null) helper.getSendDataManager().sendAsynInfo();
                        result.success(capabilities());
                    }
                    break;
                case "syncHealthData":
                    startSync(result, false);
                    break;
                case "readAutoMeasureSettings":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                        return;
                    }
                    if (autoHeartEnabled != null && autoOxygenEnabled != null) {
                        result.success(autoMeasureSettings());
                        return;
                    }
                    if (pendingAutoSettings != null) {
                        result.error("AUTO_MEASURE_READ_BUSY", "正在读取自动健康检测设置", null);
                        return;
                    }
                    pendingAutoSettings = result;
                    helper.getSendDataManager().sendAsynInfo();
                    settingsDeadline = () -> failPendingAutoSettings(
                            "AUTO_MEASURE_READ_FAILED", "暂时未收到戒指自动检测设置");
                    main.postDelayed(settingsDeadline, SETTINGS_MS);
                    break;
                case "setAutoMeasureSetting":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                        return;
                    }
                    String settingType = call.argument("type");
                    Boolean settingEnabled = call.argument("enabled");
                    if (settingEnabled == null ||
                            !("heartRate".equals(settingType) ||
                                    "bloodOxygen".equals(settingType))) {
                        result.error("COOLWEAR_FEATURE_UNVERIFIED", "此自动检测项目不受支持", null);
                        return;
                    }
                    boolean heartEnabled = Boolean.TRUE.equals(autoHeartEnabled);
                    boolean oxygenEnabled = Boolean.TRUE.equals(autoOxygenEnabled);
                    if ("heartRate".equals(settingType)) heartEnabled = settingEnabled;
                    if ("bloodOxygen".equals(settingType)) oxygenEnabled = settingEnabled;
                    helper.getSendBlueData().sendHeartAutoSwitch(
                            heartEnabled ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE,
                            oxygenEnabled ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE,
                            autoMeasureIntervalMinutes);
                    autoHeartEnabled = heartEnabled;
                    autoOxygenEnabled = oxygenEnabled;
                    result.success(null);
                    break;
                case "triggerDeviceAction":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                        return;
                    }
                    String feature = call.argument("feature");
                    Boolean actionEnabled = call.argument("enabled");
                    boolean enabled = actionEnabled == null || actionEnabled;
                    if ("find_watch".equals(feature)) {
                        if (enabled) helper.getSendBlueData().sendFindDevice();
                    } else if ("camera".equals(feature) &&
                            functionControl != null &&
                            functionControl.isHasGestureSupported()) {
                        helper.getSendBlueData().sendPhotoSwitch(enabled);
                    } else {
                        result.error("COOLWEAR_FEATURE_UNVERIFIED", "此戒指功能不受支持", null);
                        return;
                    }
                    result.success(null);
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
                case "startSport":
                    if (activeMeasurement != null) {
                        result.error("MEASUREMENT_ACTIVE", "请先结束当前健康测量", null);
                        return;
                    }
                    String sportMode = call.argument("mode");
                    if (activeSportType != null) {
                        result.error("SPORT_ACTIVE", "戒指运动已经开始", null);
                        return;
                    }
                    sendSportCommand(result, sportMode,
                            K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_START, false);
                    break;
                case "pauseSport":
                    sendSportCommand(result, activeSportMode,
                            K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_PAUSE, true);
                    break;
                case "resumeSport":
                    sendSportCommand(result, activeSportMode,
                            K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_CONTINUE, true);
                    break;
                case "stopSport":
                    sendSportCommand(result, activeSportMode,
                            K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP, true);
                    break;
                case "readSportRecords":
                    startSync(result, true);
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
        } else if ("hrv".equals(metric)) {
            helper.getSendBlueData().sendRriHrvCmd(state);
        } else if ("stress".equals(metric)) {
            helper.getSendBlueData().sendStressSwitch(state);
        }
    }

    public void dispose() {
        if (scanDeadline != null) main.removeCallbacks(scanDeadline);
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        failPendingAutoSettings("BRIDGE_DISPOSED", "戒指连接已关闭");
        failPendingSync("BRIDGE_DISPOSED", "戒指连接已关闭");
        if (helper != null) {
            helper.stopScan();
            helper.disConnect();
        }
        sink = null;
    }
}
