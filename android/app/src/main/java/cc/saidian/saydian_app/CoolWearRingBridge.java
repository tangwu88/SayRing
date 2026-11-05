package cc.saidian.saydian_app;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.IntentFilter;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.content.Intent;
import android.util.Log;

import androidx.core.app.NotificationManagerCompat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.Supplier;

import ce.com.cenewbluesdk.CEBC;
import ce.com.cenewbluesdk.entity.CEDevData;
import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean.SayRingHistoryObserver;
import ce.com.cenewbluesdk.entity.K6_sleepData;
import ce.com.cenewbluesdk.entity.MyBleDevice;
import ce.com.cenewbluesdk.entity.k6.K6_Action;
import ce.com.cenewbluesdk.entity.k6.K6_CESyncTime;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_BATTERY_INFO;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_FUNCTION_CONTROL;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_FIND_PHONE_OR_DEVICE;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_DRINK_ALARM;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_GESTURE_CONFIG;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_HEART_AUTO_SWITCH;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_HR_CONTROL;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_REAL_O2;
import ce.com.cenewbluesdk.entity.k6.K6_DevInfoStruct;
import ce.com.cenewbluesdk.entity.k6.K6_HeartStruct;
import ce.com.cenewbluesdk.entity.k6.K6_HrvStruct;
import ce.com.cenewbluesdk.entity.k6.K6_Mix_sport_Struct;
import ce.com.cenewbluesdk.entity.k6.K6_MessageNoticeStruct;
import ce.com.cenewbluesdk.entity.k6.K6_SEND_APP_SPORT_STRUCT;
import ce.com.cenewbluesdk.entity.k6.K6_Sport;
import ce.com.cenewbluesdk.entity.k6.K6_SittingRemind;
import ce.com.cenewbluesdk.entity.k6.K6_StressStruct;
import ce.com.cenewbluesdk.entity.k6.K6_TempStruct;
import ce.com.cenewbluesdk.entity.k6.k6_RRI_HRV_DATA;
import ce.com.cenewbluesdk.proxy.interfaces.K6BleDataResult;
import ce.com.cenewbluesdk.proxy.interfaces.OnScanDevListener;
import ce.com.cenewbluesdk.proxy.BleFactory;
import ce.com.cenewbluesdk.proxy.CEBluetoothProxyBase;
import ce.com.cenewbluesdk.proxy.sdkhelper.BluetoothHelper;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Fail-closed CoolWear ring adapter. A real device-info callback proves the
 * vendor protocol baseline; function flags still gate optional health features.
 * History completion and live sport state require their vendor callbacks.
 */
public final class CoolWearRingBridge
        implements MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private static final String TAG = "CoolWearRing";
    private static void profileTrace(String event) {
        // Profile-only structural diagnostics; no addresses, account/health data
        // or command payloads. Release optimization removes this branch.
        if ("profile".equals(BuildConfig.BUILD_TYPE)) System.err.println("SayRing BLE: " + event);
    }
    // Confirmed model families, not a substitute for vendor device-info and
    // function-control callbacks. QRing R2* names remain on their own SDK.
    private static final long SCAN_MS = 8_000L;
    private static final long CONNECT_MS = 28_000L;
    private static final long SETTINGS_MS = 5_000L;
    private static final String NOTIFICATION_PREFS = "coolwear_notification_settings";
    private static final String[] NOTIFICATION_KEYS = {"incomingCall", "sms", "wechat",
            "qq", "whatsapp", "dingtalk", "wecom", "tiktok", "telegram", "otherApps"};
    private static volatile CoolWearRingBridge activeBridge;

    private final Activity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final LinkedHashMap<String, Map<String, Object>> scanned = new LinkedHashMap<>();
    private BluetoothHelper helper;
    private long clockSynchronizationEpoch = -1L;
    private final CoolWearRecoveryTarget recoveryTarget = new CoolWearRecoveryTarget();
    private final CoolWearRecoveryTarget.Sdk recoverySdk = new CoolWearRecoveryTarget.Sdk() {
        @Override public void clearTarget() {
            CEBluetoothProxyBase proxy = BleFactory.getInstance().getK6Proxy();
            if (!"".equals(proxy.getBlueAddress()) ||
                    !"".equals(proxy.getConnectUtil().getBlueAddress())) {
                // 公开 setter 仅清 RAM 和 KEY_DEVMACADDRESS；不能替换为 unbindDevice。
                proxy.setBlueAddress("");
                if (!"".equals(proxy.getBlueAddress()) ||
                        !"".equals(proxy.getConnectUtil().getBlueAddress())) {
                    throw new IllegalStateException("Vendor recovery target was not cleared");
                }
            }
        }
        @Override public void setTarget(String target) {
            CEBluetoothProxyBase proxy = BleFactory.getInstance().getK6Proxy();
            proxy.setBlueAddress(target);
            if (!target.equals(proxy.getBlueAddress()) ||
                    !target.equals(proxy.getConnectUtil().getBlueAddress())) {
                throw new IllegalStateException("Vendor recovery target was not accepted");
            }
        }
        @Override public void disconnect() { if (helper != null) helper.disConnect(); }
    };
    private EventChannel.EventSink sink;
    private MethodChannel.Result pendingScan;
    private String scanExactTargetId;
    private MethodChannel.Result pendingConnect;
    private MethodChannel.Result pendingHealthSync;
    private MethodChannel.Result pendingSportSync;
    private MethodChannel.Result pendingAutoSettings;
    private MethodChannel.Result pendingReminders;
    private MethodChannel.Result pendingGesture;
    private String gesturePairingFailureCode;
    private String gesturePairingFailureMessage;
    private Runnable gestureDeadline;
    private final CoolWearGestureState gesture = new CoolWearGestureState();
    private Runnable remindersDeadline;
    private Runnable scanDeadline;
    private long scanGeneration;
    private BroadcastReceiver gestureBondReceiver;
    private Runnable connectDeadline;
    private Runnable syncDeadline;
    private CoolWearSyncWindow syncWindow;
    private CoolWearSyncWindow healthProgressWindow;
    private Runnable settingsDeadline;
    private String connectedId;
    private String connectedName;
    private MethodChannel.Result pendingHealthPulse;
    private Runnable healthPulseStop;
    private String healthPulseTarget;
    private long healthPulseEpoch;
    private String connectedVendorId;
    private String firmwareVersion;
    private String activeMeasurement;
    // SDK 回调可能先入队、后在主线程执行；取消/重开测量必须撤销旧代次。
    private volatile long measurementGeneration;
    private long measurementStartedAt;
    private boolean hrvRealtimeListenerReady;
    private int hrvLivePackets;
    private int hrvHistoryPackets;
    private int hrvLegacyPackets;
    private int hrvStressPackets;
    private volatile boolean linkConnected;
    private volatile long connectionEpoch;
    private long cameraSession;
    private long clearAttemptEpoch = -1;
    private volatile boolean deviceInfoReceived;
    private boolean recoveringConnection;
    private boolean resultEmitted;
    private Integer batteryPercent;
    private Boolean charging;
    private String batteryUpdatedAt;
    private long batteryQueryAt;
    private K6_DATA_TYPE_FUNCTION_CONTROL functionControl;
    private Boolean autoHeartEnabled;
    private Boolean autoOxygenEnabled;
    private int autoMeasureIntervalMinutes = 5;
    private K6_SittingRemind sittingReminder;
    private K6_DATA_TYPE_DRINK_ALARM drinkingReminder;
    private final LinkedHashMap<String, Map<String, Object>> syncedHealthRecords =
            new LinkedHashMap<>();
    private final LinkedHashMap<String, Map<String, Object>> syncedSportRecords =
            new LinkedHashMap<>();
    private final LinkedHashMap<Integer, CoolWearHistoryBatch> historyBatches = new LinkedHashMap<>();
    private final LinkedHashMap<Integer, CoolWearHistoryBatch> connectionHistoryBatches = new LinkedHashMap<>();
    private final LinkedHashMap<String, Map<String, Object>> connectionHealthRecords = new LinkedHashMap<>();
    private final Map<String, String> connectionRecordReceipts = new HashMap<>();
    private final String receiptNamespace = java.util.UUID.randomUUID().toString();
    private long receiptSequence;
    private final java.util.Set<Integer> requestedHistoryTypes = new java.util.HashSet<>();
    private volatile long historyRequestGeneration;
    private boolean historyObserverReady;
    private String activeSportMode;
    private boolean sportHeartStreamStarted;
    private Integer activeSportType;

    public CoolWearRingBridge(Activity activity, BinaryMessenger messenger) {
        this.activity = activity;
        activeBridge = this;
        new MethodChannel(messenger, "cc.saidian.ring/commands").setMethodCallHandler(this);
        new EventChannel(messenger, "cc.saidian.ring/events").setStreamHandler(this);
    }

    private void ensureSdk() {
        if (helper != null) {
            recoveryTarget.initializeIdle(recoverySdk);
            return;
        }
        helper = BluetoothHelper.getInstance();
        helper.init();
        helper.initProxy(activity.getApplicationContext());
        // 联合扫描和能力查询不能借安装缓存复活另一个账号/通道的旧戒指。
        recoveryTarget.initializeIdle(recoverySdk);
        configureScanCallback(scanGeneration);
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_BLUE_CONNECT_STATE_CHANGE,
                (K6BleDataResult<Integer>) status -> {
                    long generation = recoveryTarget.generation();
                    main.post(() -> {
                        if (activeBridge != this) return;
                        onConnectionState(status, generation);
                    });
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DEVINFO,
                (K6BleDataResult<K6_DevInfoStruct>) info -> {
                    long generation = recoveryTarget.generation();
                    main.post(() -> {
                        if (activeBridge != this || !recoveryTarget.isCurrent(generation) ||
                                !recoveryTarget.isActive()) return;
                        onDeviceInfo(info);
                    });
                    return false;
                });
        registerRemainingListeners();
        historyObserverReady = SayRingHistoryObserver.install(helper.getRcvDataManager(), packet -> {
            final long epoch = connectionEpoch;
            final long request = historyRequestGeneration;
            final String target = connectedId;
            final int type = packet.getDataType();
            final int itemLength = packet.getItemL();
            final int itemCount = packet.getItemNumber();
            final byte[] bytes = packet.getData() == null ? null : packet.getData().clone();
            main.post(() -> {
                if (activeBridge != this || epoch != connectionEpoch
                        || target == null || !target.equals(connectedId) || !linkConnected || !recoveryTarget.isActive()) return;
                if (BuildConfig.DEBUG) {
                    String evidence = CoolWearProtocolEvidence.describe(type, itemLength, itemCount, bytes);
                    if (evidence != null) Log.i(TAG, evidence);
                }
                if (request != historyRequestGeneration) return;
                receiveHistoryBatch(type, bytes);
            });
        });
    }

    private void configureScanCallback(final long generation) {
        helper.scanningDeviceInit(activity, new OnScanDevListener() {
            @Override public void onFindDev(ScanResult result) { }

            @Override public void onFindDevList(
                    ScanResult result, List<MyBleDevice> devices, MyBleDevice found) {
                final List<MyBleDevice> snapshot = devices == null ? null : new ArrayList<>(devices);
                main.post(() -> { if (generation == scanGeneration) receiveScannedDevices(snapshot); });
            }
        });
    }

    private void registerRemainingListeners() {
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_TIME_TYPE,
                (K6BleDataResult<K6_CESyncTime>) time -> {
                    if (time != null) {
                        final int format = time.getFormat(), mdFormat = time.getMdFormat();
                        postCurrentPacket(() -> synchronizeConnectionClock(format, mdFormat));
                    }
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
                K6_Action.RCVD.RCVD_SITTING_REMIND,
                (K6BleDataResult<K6_SittingRemind>) reminder -> {
                    if (reminder != null) main.post(() -> {
                        sittingReminder = reminder;
                        finishReminderReadIfReady();
                        if (linkConnected && deviceInfoReceived) emit("capabilitiesUpdated", capabilities());
                    });
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_K6_DATA_TYPE_DRINK_ALARM,
                (K6BleDataResult<K6_DATA_TYPE_DRINK_ALARM>) reminder -> {
                    if (reminder != null) main.post(() -> {
                        drinkingReminder = reminder;
                        finishReminderReadIfReady();
                        if (linkConnected && deviceInfoReceived) emit("capabilitiesUpdated", capabilities());
                    });
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_GESTURE_DATA,
                (K6BleDataResult<K6_DATA_TYPE_GESTURE_CONFIG>) value -> {
                    if (value != null) {
                        long generation = gesture.generation();
                        int mode = value.getControlType();
                        main.post(() -> onGestureMode(mode, generation));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_SPORT_HEART_FOR_SHOW,
                (K6BleDataResult<ArrayList<K6_HeartStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_HeartStruct> snapshot = new ArrayList<>(values);
                        postCurrentPacket(() -> onHeartValues(snapshot));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_REAL_O2,
                (K6BleDataResult<ArrayList<K6_DATA_TYPE_REAL_O2>>) values -> {
                    if (values != null) {
                        ArrayList<K6_DATA_TYPE_REAL_O2> snapshot = new ArrayList<>(values);
                        postCurrentPacket(() -> onOxygenValues(snapshot));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DAILY_HEART,
                (K6BleDataResult<ArrayList<K6_HeartStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_HeartStruct> snapshot = new ArrayList<>(values);
                        postHealthPacket(() -> CoolWearRecordMapper.heartRecords(
                                connectedId, firmwareVersion, snapshot));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_REAL_O2_HISTORY,
                (K6BleDataResult<ArrayList<K6_DATA_TYPE_REAL_O2>>) values -> {
                    if (values != null) {
                        ArrayList<K6_DATA_TYPE_REAL_O2> snapshot = new ArrayList<>(values);
                        postHealthPacket(() -> CoolWearRecordMapper.oxygenRecords(
                                connectedId, firmwareVersion, snapshot));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_SPORT_DATA,
                (K6BleDataResult<ArrayList<K6_Sport>>) values -> {
                    if (values != null) {
                        ArrayList<K6_Sport> snapshot = new ArrayList<>(values);
                        postHistoryPacket(() -> {
                            List<Map<String, Object>> records = CoolWearRecordMapper.activityRecords(
                                    connectedId, firmwareVersion, snapshot);
                            Log.i(TAG, "activity packet received; entries=" + snapshot.size()
                                    + ", valid records=" + records.size());
                            if (records.isEmpty() && !snapshot.isEmpty()) {
                                boolean dated = false, positive = false;
                                for (K6_Sport item : snapshot) {
                                    if (item == null) continue;
                                    dated |= CoolWearRecordMapper.historyTimestamp(item.getStarTime()) > 0;
                                    positive |= item.getWalkSteps() > 0 || item.getDistance() > 0
                                            || item.getCalories() > 0;
                                }
                                profileTrace("activity rejected; validDate=" + dated
                                        + "; positiveCounters=" + positive);
                            }
                            collectHealth(records);
                        });
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_K6_SLEEP_DATA,
                (K6BleDataResult<K6_sleepData>) value -> {
                    if (value != null) {
                        postHistoryPacket(() -> collectHealth(CoolWearRecordMapper.sleepRecords(
                                connectedId, firmwareVersion, value)));
                    }
                    return false;
                });
        hrvRealtimeListenerReady = CoolWearHrvListenerRouter.install(
                helper.getRcvDataManager(),
                values -> { postHrvPacket(values, false); return false; },
                values -> { postHrvPacket(values, true); return false; });
        hrvDiagnostic("listener", hrvRealtimeListenerReady ? "split_verified" : "passive_only");
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_DATA_TYPE_HR_CONTROL,
                (K6BleDataResult<K6_DATA_TYPE_HR_CONTROL>) value -> {
                    if (value == null) return false;
                    final long generation = measurementGeneration;
                    final int type = value.controlType;
                    final int state = value.controlState;
                    postCurrentPacket(() -> {
                        if (generation != measurementGeneration || !"hrv".equals(activeMeasurement)) return;
                        // 原厂仅定义 HR/BP/O2/ECG 控制类型，没有 HRV 完成/未佩戴契约。
                        // 仅作无健康值的诊断，不据此伪造 HRV 完成或提前停止。
                        hrvDiagnostic("control", "type=" + type + ",state=" + state);
                    });
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
                        final long generation = measurementGeneration;
                        postCurrentPacket(() -> {
                            if (generation != measurementGeneration) return;
                            onStressCompatValues(snapshot);
                        });
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_STRESS_SHOW,
                (K6BleDataResult<ArrayList<K6_StressStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_StressStruct> snapshot = new ArrayList<>(values);
                        final long generation = measurementGeneration;
                        postCurrentPacket(() -> {
                            if (generation != measurementGeneration) return;
                            onStressValues(snapshot);
                        });
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_SPORT_TEMP_FOR_SHOW,
                (K6BleDataResult<ArrayList<K6_TempStruct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_TempStruct> snapshot = new ArrayList<>(values);
                        postHealthPacket(() -> CoolWearRecordMapper.temperatureRecords(
                                connectedId, firmwareVersion, snapshot));
                    }
                    return false;
                });
        helper.getRcvDataManager().addBleDataResultListener(
                K6_Action.RCVD.RCVD_MIX_SPORT_DATA,
                (K6BleDataResult<ArrayList<K6_Mix_sport_Struct>>) values -> {
                    if (values != null) {
                        ArrayList<K6_Mix_sport_Struct> snapshot = new ArrayList<>(values);
                        postCurrentPacket(() -> collectSport(CoolWearRecordMapper.sportRecords(
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
        // RCVD_DATA_TYPE_DEV_SYNC is the mixed *settings* envelope in this
        // shipped SDK, not a history-transfer terminal. Never use it to report
        // complete history or an authoritative empty sports list.
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

    static String supportedModel(String name) {
        return RingNamePolicy.luckRingModel(name);
    }

    static boolean isExactSystemTarget(String requested, String actual, String name) {
        return requested != null && requested.matches("(?i)([0-9a-f]{2}:){5}[0-9a-f]{2}")
                && requested.equalsIgnoreCase(actual) && supportedModel(name) != null;
    }

    private Map<String, Object> matchingSystemTarget(
            String id, Iterable<BluetoothDevice> devices, boolean requireBond) {
        for (BluetoothDevice device : devices) {
            if (device == null || (requireBond && device.getBondState() != BluetoothDevice.BOND_BONDED)) continue;
            String address = device.getAddress();
            if (!id.equalsIgnoreCase(address)) continue;
            String name = device.getName();
            if (!isExactSystemTarget(id, address, name)) continue;
            Map<String, Object> value = new HashMap<>();
            value.put("id", id); // 保留原账号的设备键，厂商 SDK 使用规范 MAC。
            value.put("name", name.trim());
            value.put("model", supportedModel(name));
            value.put("hardwareAddress", address.toUpperCase(Locale.ROOT));
            if (requireBond) value.put("bonded", true);
            return value;
        }
        return null;
    }

    private Map<String, Object> findExactSystemTarget(String id, boolean includeConnected) {
        if (id == null || !id.matches("(?i)([0-9a-f]{2}:){5}[0-9a-f]{2}")) return null;
        BluetoothManager manager = (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        if (manager == null || manager.getAdapter() == null) return null;
        if (includeConnected) {
            Map<String, Object> current = matchingSystemTarget(
                    id, manager.getConnectedDevices(BluetoothProfile.GATT), false);
            if (current != null) return current;
        }
        return matchingSystemTarget(id, manager.getAdapter().getBondedDevices(), true);
    }

    private void lookupSystemTarget(MethodCall call, MethodChannel.Result result, boolean includeConnected) {
        String id = call.argument("id");
        Map<String, Object> candidate = findExactSystemTarget(id, includeConnected);
        if (candidate != null) {
            if (includeConnected) candidate.put("ownedSystemTarget", true);
            scanned.put(id, candidate);
        }
        result.success(candidate);
    }

    private Map<String, Object> currentConnectCandidate(String id) {
        Map<String, Object> candidate = scanned.get(id);
        if (candidate == null || !Boolean.TRUE.equals(candidate.get("ownedSystemTarget"))) return candidate;
        // 查询和点击之间可能已断开或换设备，旧快照不能交给 SDK 当作当前目标。
        return findExactSystemTarget(id, true);
    }

    private void receiveScannedDevices(List<MyBleDevice> devices) {
        if (pendingScan == null || devices == null) return;
        for (MyBleDevice device : devices) {
            if (device == null || device.getmBluetoothDevice() == null) continue;
            String name = device.getName();
            String address = device.getmBluetoothDevice().getAddress();
            // 精确恢复沿用绑定键的原大小写；普通扫描继续返回系统地址。
            String id = address != null && address.equalsIgnoreCase(scanExactTargetId) ? scanExactTargetId : address;
            String model = supportedModel(name);
            if (model == null || id == null || id.isEmpty()) continue;
            Map<String, Object> value = new HashMap<>();
            value.put("id", id);
            value.put("name", name.trim());
            value.put("model", model);
            value.put("rssi", device.getRssi());
            if (device.getmK6ManufacturerInfo() != null) {
                value.put("vendorId", device.getmK6ManufacturerInfo().name);
            }
            boolean fresh = !scanned.containsKey(id);
            scanned.put(id, value);
            if (fresh) emit("scanDevice", value);
            if (id.equalsIgnoreCase(scanExactTargetId)) {
                finishScan();
                return;
            }
        }
    }

    private void finishScan() {
        ++scanGeneration;
        if (scanDeadline != null) main.removeCallbacks(scanDeadline);
        scanDeadline = null;
        MethodChannel.Result result = pendingScan;
        pendingScan = null;
        scanExactTargetId = null;
        if (helper != null) helper.stopScan();
        if (result != null) result.success(new ArrayList<>(scanned.values()));
    }

    private void postHealthPacket(Supplier<List<Map<String, Object>>> records) {
        postHistoryPacket(() -> collectHealth(records.get()));
    }

    private void postHistoryPacket(Runnable receive) {
        final long ownerTarget = recoveryTarget.generation();
        final String target = connectedId;
        main.post(() -> {
            if (activeBridge != this || !recoveryTarget.isCurrent(ownerTarget) || !recoveryTarget.isActive()
                    || target == null || !target.equals(connectedId) || !linkConnected) return;
            receive.run();
        });
    }

    private void postCurrentPacket(Runnable receive) {
        final long epoch = connectionEpoch;
        final String target = connectedId;
        main.post(() -> {
            if (epoch != connectionEpoch || target == null || !target.equals(connectedId)
                    || !linkConnected || !deviceInfoReceived) return;
            receive.run();
        });
    }

    private void collectHealth(List<Map<String, Object>> records) {
        if (!linkConnected || records == null) return;
        boolean changed = false;
        String model = supportedModel(connectedName);
        for (Map<String, Object> record : records) {
            Object id = record.get("id");
            if (id == null || id.toString().trim().isEmpty()) continue;
            if (model != null) record.put("sourceModel", model);
            record.put("rawVersion", 2);
            // The SDK may push and ACK history before Flutter finishes the
            // account/connection handshake. Keep it for the explicit read;
            // early EventChannel delivery alone is not durable acceptance.
            Map<String, Object> previous = connectionHealthRecords.put(id.toString(), new HashMap<>(record));
            if (!record.equals(previous) || !connectionRecordReceipts.containsKey(id.toString())) {
                connectionRecordReceipts.put(id.toString(), receiptNamespace + ":" + (++receiptSequence));
            }
            if (healthProgressWindow == null) {
                if (deviceInfoReceived) emitHealthRecordWithReceipt(record);
                continue;
            }
            if (!record.equals(syncedHealthRecords.put(id.toString(), record))) {
                changed = true;
                // Persist each validated packet while the transfer is active.
                // A later disconnect must not discard all records merely
                // because another metric has not reached its terminal yet.
                if (deviceInfoReceived) emitHealthRecordWithReceipt(record);
            }
        }
        if (changed) noteSyncPacket();
        if (changed) {
            healthProgressWindow.received(SystemClock.elapsedRealtime());
            if (pendingHealthSync != null) {
                Map<String, Object> progress = new HashMap<>();
                progress.put("deviceId", connectedId);
                progress.put("receivedRecords", syncedHealthRecords.size());
                emit("syncRecords", progress);
            }
        }
    }

    private void collectSport(List<Map<String, Object>> records) {
        if (syncWindow == null || records == null) return;
        boolean received = false;
        for (Map<String, Object> record : records) {
            Object id = record.get("id");
            if (id == null || id.toString().trim().isEmpty()) continue;
            if (!record.equals(syncedSportRecords.put(id.toString(), record))) received = true;
        }
        if (received) noteSyncPacket();
    }

    private void noteSyncPacket() {
        if (syncWindow == null) return;
        syncWindow.received(SystemClock.elapsedRealtime());
    }

    private void requestHistoryType(int type) {
        CEBluetoothProxyBase proxy = currentReadProxy();
        requestedHistoryTypes.add(type);
        // Same public read-command envelope as SDK getDevInfo(): cmd=3.
        // No mixed-settings, time, user, reminder, pair or clear writes.
        proxy.sendData(new CEDevData(3, type));
        Log.i(TAG, "history read requested; type=" + type);
    }

    private static String historyMetric(int type) {
        switch (type) {
            case 5: return "steps";
            case 6: return "sleep";
            case 8: return "heart_rate";
            case 40: return "blood_oxygen";
            case 42: return "stress";
            case 47: return "body_temperature";
            case 61: return "hrv";
            default: return "sport";
        }
    }

    private void includeCapabilityHistory(boolean requestNow) {
        K6_DATA_TYPE_FUNCTION_CONTROL flags = functionControl;
        if (flags == null || (requestNow && (pendingHealthSync == null || syncWindow == null))) return;
        int[] types = {
                flags.isHasHR24H() || flags.isHr_measure_button() ? 8 : -1,
                flags.isHasO2() ? 40 : -1,
                flags.isHasHrvSupported() ? 61 : -1,
                flags.isHasHrvSupported() ? 42 : -1,
                flags.isHasTemperature() ? 47 : -1};
        for (int type : types) {
            if (type < 0 || historyBatches.containsKey(type)) continue;
            historyBatches.put(type, new CoolWearHistoryBatch());
            if (requestNow) requestHistoryType(type);
        }
    }

    private void emitHealthRecordWithReceipt(Map<String, Object> record) {
        Map<String, Object> payload = new HashMap<>(record);
        payload.put("_nativeReceipt", connectionRecordReceipts.get(String.valueOf(record.get("id"))));
        emit("healthRecord", payload);
    }

    private void acknowledgeHealthRecords(Map<String, String> receipts) {
        if (receipts == null) return;
        int released = 0;
        for (Map.Entry<String, String> entry : receipts.entrySet()) {
            if (entry.getValue() != null && entry.getValue().equals(connectionRecordReceipts.get(entry.getKey()))) {
                connectionRecordReceipts.remove(entry.getKey());
                connectionHealthRecords.remove(entry.getKey());
                released++;
            }
        }
        if (released > 0) Log.i(TAG, "history local persistence confirmed; records=" + released);
    }

    private void receiveHistoryBatch(int type, byte[] bytes) {
        if (type == 5 || type == 6 || type == 8 || type == 40 || type == 42 || type == 47 || type == 61) {
            connectionHistoryBatches.computeIfAbsent(type, ignored -> new CoolWearHistoryBatch()).accept(bytes);
        }
        CoolWearHistoryBatch batch = historyBatches.get(type);
        if (batch == null || !requestedHistoryTypes.contains(type) || syncWindow == null) return;
        if (bytes != null && bytes.length == 0 ? batch.acceptEmptyReply() : batch.accept(bytes)) noteSyncPacket();
        Log.i(TAG, "history batch; type=" + type + "; bytes=" + (bytes == null ? -1 : bytes.length)
                + "; remaining=" + (bytes == null || bytes.length < 3 ? -1 : ((bytes[0] & 255) | ((bytes[1] & 255) << 8)))
                + "; count=" + (bytes == null || bytes.length < 3 ? -1 : (bytes[2] & 255))
                + "; state=" + batch.status());
        if (pendingHealthSync != null && functionControl == null) return;
        for (CoolWearHistoryBatch value : historyBatches.values()) if (!value.complete()) return;
        // SDK parsers enqueue their public listeners before this observer. Those
        // listeners enqueue the mapped records once more on our main handler.
        // Drain that turn before returning ranges as complete to Flutter.
        final long request = historyRequestGeneration;
        main.post(() -> {
            if (request != historyRequestGeneration || syncWindow == null) return;
            if (pendingHealthSync != null && functionControl == null) return;
            for (CoolWearHistoryBatch value : historyBatches.values()) if (!value.complete()) return;
            finishHistorySync();
        });
    }

    private void finishHistorySync() {
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        syncDeadline = null;
        syncWindow = null;
        healthProgressWindow = null;
        ++historyRequestGeneration;
        Map<String, String> statuses = new LinkedHashMap<>();
        for (Map.Entry<Integer, CoolWearHistoryBatch> entry : historyBatches.entrySet()) {
            if (entry.getKey() != 10) statuses.put(historyMetric(entry.getKey()), entry.getValue().status());
        }
        if (statuses.containsKey("steps")) {
            statuses.put("distance", statuses.get("steps"));
            statuses.put("calories", statuses.get("steps"));
        }
        Map<String, Object> response = new HashMap<>();
        response.put("records", new ArrayList<>(syncedHealthRecords.values()));
        response.put("statuses", statuses);
        response.put("receipts", new HashMap<>(connectionRecordReceipts));
        MethodChannel.Result health = pendingHealthSync, sport = pendingSportSync;
        pendingHealthSync = null;
        pendingSportSync = null;
        historyBatches.clear();
        connectionHistoryBatches.clear();
        requestedHistoryTypes.clear();
        if (health != null) health.success(response);
        if (sport != null) sport.success(new ArrayList<>(syncedSportRecords.values()));
        Log.i(TAG, "history ranges confirmed; health records=" + syncedHealthRecords.size()
                + "; sport records=" + syncedSportRecords.size());
    }

    private void startSync(MethodChannel.Result result, boolean sportOnly) {
        if (!linkConnected || !deviceInfoReceived) {
            result.error("NOT_CONNECTED", "请先连接戒指", null);
            return;
        }
        if (!historyObserverReady) {
            result.error("COOLWEAR_HISTORY_UNAVAILABLE", "当前版本无法核验戒指历史数据", null);
            return;
        }
        if (sportOnly && syncWindow != null && pendingSportSync == null) {
            pendingSportSync = result;
            if (!historyBatches.containsKey(10)) {
                historyBatches.put(10, new CoolWearHistoryBatch());
                requestHistoryType(10);
            }
            return;
        }
        if (pendingHealthSync != null || pendingSportSync != null) {
            result.error("SYNC_BUSY", "戒指数据正在同步", null);
            return;
        }
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        final long request = ++historyRequestGeneration;
        historyBatches.clear();
        requestedHistoryTypes.clear();
        syncedHealthRecords.clear();
        syncedHealthRecords.putAll(connectionHealthRecords);
        syncedSportRecords.clear();
        if (sportOnly) {
            pendingSportSync = result;
            historyBatches.put(10, new CoolWearHistoryBatch());
        } else {
            pendingHealthSync = result;
            historyBatches.put(5, new CoolWearHistoryBatch());
            historyBatches.put(6, new CoolWearHistoryBatch());
            includeCapabilityHistory(false);
        }
        long started = SystemClock.elapsedRealtime();
        syncWindow = new CoolWearSyncWindow(started);
        healthProgressWindow = sportOnly ? null : new CoolWearSyncWindow(started);
        // Include spontaneous batches initiated by the foreground command,
        // including packets that arrive before the individual query is sent.
        requestedHistoryTypes.addAll(historyBatches.keySet());
        for (Integer type : new ArrayList<>(historyBatches.keySet())) {
            CoolWearHistoryBatch early = connectionHistoryBatches.get(type);
            if (early != null) historyBatches.put(type, early);
        }
        connectionHistoryBatches.clear();
        for (Map<String, Object> record : syncedHealthRecords.values()) {
            emitHealthRecordWithReceipt(record);
        }
        syncDeadline = new Runnable() {
            @Override public void run() {
                if (syncDeadline != this || syncWindow == null || request != historyRequestGeneration) return;
                long remaining = syncWindow.remaining(SystemClock.elapsedRealtime());
                if (remaining == 0) {
                    for (Map.Entry<Integer, CoolWearHistoryBatch> entry : historyBatches.entrySet()) {
                        Log.w(TAG, "history not confirmed; type=" + entry.getKey() + "; state=" + entry.getValue().status());
                    }
                    failPendingSync("COOLWEAR_SYNC_TIMEOUT", "戒指未返回完整同步确认，已保留收到的记录");
                    return;
                }
                main.postDelayed(this, Math.min(remaining, 1000));
            }
        };
        main.postDelayed(syncDeadline, 1000);
        try {
            helper.setEnableGsDataTrans(true);
            // LuckRing requestDataSync(): REQUEST DEV_SYNC(9), REQUEST REAL_SPORT(4).
            // The bundled SDK lacks these named wrappers. Use the same public
            // transport, without the unrelated settings writes of sendAsynInfo.
            requestRingInfo(CoolWearReadRequests.Kind.MIXED_INFO);
            CEBluetoothProxyBase proxy = currentReadProxy();
            proxy.sendData(new CEDevData(3, 4));
            int index = 0;
            for (Integer type : new ArrayList<>(historyBatches.keySet())) {
                main.postDelayed(() -> {
                    if (request != historyRequestGeneration || !linkConnected || syncWindow == null) return;
                    try { requestHistoryType(type); }
                    catch (RuntimeException error) { failPendingSync("COOLWEAR_SYNC_FAILED", "戒指数据同步启动失败，请重试"); }
                }, 450L * index++);
            }
        } catch (RuntimeException error) {
            failPendingSync("COOLWEAR_SYNC_FAILED", "戒指数据同步启动失败，请重试");
        }
    }

    private void failPendingSync(String code, String message) {
        Map<String, String> statuses = new LinkedHashMap<>();
        if (pendingHealthSync != null && functionControl == null) statuses.put("_capabilities", "not_received");
        for (Map.Entry<Integer, CoolWearHistoryBatch> entry : historyBatches.entrySet()) {
            if (entry.getKey() != 10) statuses.put(historyMetric(entry.getKey()), entry.getValue().status());
        }
        ++historyRequestGeneration;
        historyBatches.clear();
        connectionHistoryBatches.clear();
        requestedHistoryTypes.clear();
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        syncDeadline = null;
        syncWindow = null;
        healthProgressWindow = null;
        MethodChannel.Result healthResult = pendingHealthSync;
        MethodChannel.Result sportResult = pendingSportSync;
        pendingHealthSync = null;
        pendingSportSync = null;
        // The supplied mixed-settings packet is NOT a history terminal.
        // Preserve validated packets, never claim complete history on silence.
        List<Map<String, Object>> partialHealth = new ArrayList<>(syncedHealthRecords.values());
        List<Map<String, Object>> partialSport = new ArrayList<>(syncedSportRecords.values());
        if ("COOLWEAR_SYNC_TIMEOUT".equals(code)) {
            Log.w(TAG, "vendor sync timeout; health records=" + partialHealth.size()
                    + ", sport records=" + partialSport.size());
        }
        syncedHealthRecords.clear();
        syncedSportRecords.clear();
        if (healthResult != null && "COOLWEAR_SYNC_TIMEOUT".equals(code)) {
            Map<String, Object> partial = new HashMap<>();
            partial.put("records", partialHealth);
            partial.put("statuses", statuses);
            partial.put("receipts", new HashMap<>(connectionRecordReceipts));
            // Method delivery succeeded; range statuses remain incomplete.
            // Flutter persists the partial records, then returns false.
            healthResult.success(partial);
        } else if (healthResult != null) healthResult.error(code, message, null);
        if (sportResult != null) sportResult.error(code, message,
                "COOLWEAR_SYNC_TIMEOUT".equals(code) ? partialSport : null);
    }

    private void failConnect(String code, String message) {
        cancelHealthPulse(true);
        resetGesture(code, message);
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        connectDeadline = null;
        MethodChannel.Result result = pendingConnect;
        pendingConnect = null;
        linkConnected = false;
        deviceInfoReceived = false;
        functionControl = null;
        clearMeasurementSession("connection_failed");
        recoveringConnection = false;
        connectedId = null;
        connectedName = null;
        connectedVendorId = null;
        pauseSdkRecovery();
        if (result != null) result.error(code, message, null);
    }

    private void pauseSdkRecovery() {
        if (helper == null) return;
        try {
            recoveryTarget.pause(recoverySdk);
        } catch (RuntimeException error) {
            // 清理失败不能伪造成功、改业务绑定或发送恢复出厂；晚到回调仍会被撤销代次挡住。
            Log.w(TAG, "vendor recovery cache cleanup failed");
        }
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

    private void onConnectionState(Integer status, long generation) {
        profileTrace("vendor connection callback " + status);
        if (status == null) return;
        try {
            if (!recoveryTarget.acceptCallback(generation,
                    status == K6_Action.RCVD.BLUE_CONNECTED, recoverySdk)) return;
        } catch (RuntimeException error) {
            Log.w(TAG, "inactive vendor connection cleanup failed");
            return;
        }
        if (status == K6_Action.RCVD.BLUE_CONNECTED) {
            if (linkConnected) {
                Log.i(TAG, "duplicate connected callback ignored");
                return;
            }
            if (!linkConnected) {
                connectionEpoch++;
                connectionHealthRecords.clear();
                connectionRecordReceipts.clear();
                connectionHistoryBatches.clear();
            }
            if (connectedId == null) {
                pauseSdkRecovery();
                return;
            }
            linkConnected = true;
            Log.i(TAG, "vendor link connected");
            try {
                // The vendor demo persists all three scan identities after
                // BLUE_CONNECTED. Its transport uses these for follow-up
                // commands and direct reconnects.
                helper.getPersistent().setBlueAddress(connectedId.toUpperCase(Locale.ROOT));
                helper.getPersistent().setDevName(connectedName);
                if (connectedVendorId != null && !connectedVendorId.isEmpty()) {
                    helper.getPersistent().setDeviceId(connectedVendorId);
                }
                helper.getSendDataManager().getDevInfo();
                requestRingInfo(CoolWearReadRequests.Kind.MIXED_INFO);
            } catch (RuntimeException error) {
                Log.e(TAG, "vendor handshake rejected: " + error.getClass().getSimpleName());
                failConnect("COOLWEAR_HANDSHAKE_FAILED", "戒指信息读取失败，请重试");
                return;
            }
            completeConnectIfReady();
        } else if (status == K6_Action.RCVD.BLUE_DISCONNECT) {
            cancelHealthPulse(false);
            resetGesture("CONNECTION_DROPPED", "戒指连接中断");
            String retiredId = connectedId;
            linkConnected = false;
            deviceInfoReceived = false;
            functionControl = null;
            autoHeartEnabled = null;
            autoOxygenEnabled = null;
            failPendingAutoSettings("CONNECTION_DROPPED", "戒指连接中断，请靠近手机后重试");
            cancelReminderRead();
            sittingReminder = null;
            drinkingReminder = null;
            clearMeasurementSession("disconnected");
            activeSportMode = null;
            activeSportType = null;
            sportHeartStreamStarted = false;
            failPendingSync("CONNECTION_DROPPED", "戒指连接中断，请靠近手机后重试");
            connectionHealthRecords.clear();
            connectionRecordReceipts.clear();
            connectionHistoryBatches.clear();
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
        profileTrace("vendor device-info callback");
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

    private CEBluetoothProxyBase currentReadProxy() {
        CEBluetoothProxyBase proxy = BleFactory.getInstance().getK6Proxy();
        if (!linkConnected || connectedId == null
                || !connectedId.equalsIgnoreCase(proxy.getBlueAddress())) {
            throw new IllegalStateException("Read target changed");
        }
        return proxy;
    }

    private void requestRingInfo(CoolWearReadRequests.Kind... kinds) {
        CEBluetoothProxyBase proxy = currentReadProxy();
        for (CoolWearReadRequests.Kind kind : kinds) {
            proxy.sendData(CoolWearReadRequests.query(kind));
        }
    }

    private void synchronizeConnectionClock(int format, int mdFormat) {
        if (!linkConnected || !deviceInfoReceived || clockSynchronizationEpoch == connectionEpoch) return;
        clockSynchronizationEpoch = connectionEpoch;
        // 每条新连接最多一次；可选校时不插队干扰测量/同步，不阻塞握手，
        // 未回读到真实格式时不使用安装缓存猜测，更不重发整包默认设置。
        if (activeMeasurement != null || pendingHealthSync != null || pendingSportSync != null
                || pendingReminders != null || pendingAutoSettings != null || gesture.pending()) return;
        try {
            CEDevData clock = CoolWearReadRequests.connectionClockUpdate(
                    K6_CESyncTime.getCurrentTime(), format, mdFormat);
            currentReadProxy().sendData(clock);
        } catch (RuntimeException error) {
            Log.w(TAG, "optional clock synchronization skipped");
        }
    }

    private void onFunctionControl(K6_DATA_TYPE_FUNCTION_CONTROL control) {
        if (connectedId == null || control == null) return;
        functionControl = control;
        try { includeCapabilityHistory(true); }
        catch (RuntimeException error) { failPendingSync("COOLWEAR_SYNC_FAILED", "戒指数据同步启动失败，请重试"); }
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
        batteryUpdatedAt = java.time.Instant.now().toString();
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

    private boolean canReadReminders() {
        return linkConnected && deviceInfoReceived
                && (sittingReminder != null || drinkingReminder != null);
    }

    public static boolean isNotificationRelayReady() {
        CoolWearRingBridge bridge = activeBridge;
        return bridge != null && CoolWearNotificationPolicy.canRelay(
                supportedModel(bridge.connectedName), bridge.linkConnected,
                bridge.deviceInfoReceived, bridge.functionControl != null,
                bridge.sittingReminder != null || bridge.drinkingReminder != null);
    }

    public static void forwardNotification(String category, String title, String content) {
        CoolWearRingBridge bridge = activeBridge;
        if (bridge == null || !isNotificationRelayReady()) return;
        final long epoch = bridge.connectionEpoch;
        final String target = bridge.connectedId;
        bridge.main.post(() -> {
            if (activeBridge != bridge || epoch != bridge.connectionEpoch
                    || target == null || !target.equals(bridge.connectedId)
                    || !isNotificationRelayReady()) return;
            try {
                if ("incomingCall".equals(category)) {
                    bridge.helper.getSendBlueData().sendIncomingCall(title, "");
                    return;
                }
                byte type;
                switch (category) {
                    case "sms": type = K6_MessageNoticeStruct.TYPE_MSG; break;
                    case "wechat": type = K6_MessageNoticeStruct.TYPE_WX; break;
                    case "qq": type = K6_MessageNoticeStruct.TYPE_QQ; break;
                    case "whatsapp": type = K6_MessageNoticeStruct.TYPE_WHATSAPP; break;
                    case "telegram": type = K6_MessageNoticeStruct.TYPE_TELEGRAM; break;
                    default: type = K6_MessageNoticeStruct.TYPE_OTHER; break;
                }
                bridge.helper.getSendBlueData().sendPushMessage(title, type, content);
            } catch (RuntimeException error) {
                Log.w(TAG, "notification relay failed", error);
            }
        });
    }

    private Map<String, Object> notificationSettings() {
        Map<String, Object> value = new HashMap<>();
        android.content.SharedPreferences prefs = activity.getSharedPreferences(
                NOTIFICATION_PREFS, Context.MODE_PRIVATE);
        for (String key : NOTIFICATION_KEYS) value.put(key, prefs.getBoolean(key, false));
        value.put("supportedKeys", java.util.Arrays.asList(NOTIFICATION_KEYS));
        value.put("notificationAccess", NotificationManagerCompat
                .getEnabledListenerPackages(activity).contains(activity.getPackageName()));
        value.put("reminderStyle", "phoneRelay");
        return value;
    }

    private Map<String, Object> autoMeasureIntervals() {
        Map<String, Object> values = new HashMap<>();
        if (autoHeartEnabled != null) {
            values.put("heartRate", intervalSetting());
        }
        if (autoOxygenEnabled != null) {
            values.put("bloodOxygen", intervalSetting());
        }
        return values;
    }

    private Map<String, Object> intervalSetting() {
        Map<String, Object> value = new HashMap<>();
        value.put("minutes", autoMeasureIntervalMinutes);
        value.put("stepMinutes", 1);
        value.put("canModify", true);
        return value;
    }

    private void finishReminderReadIfReady() {
        if (pendingReminders == null || sittingReminder == null || drinkingReminder == null) return;
        if (remindersDeadline != null) main.removeCallbacks(remindersDeadline);
        remindersDeadline = null;
        MethodChannel.Result result = pendingReminders;
        pendingReminders = null;
        result.success(reminderSettings());
    }

    private Map<String, Object> reminderSettings() {
        List<Map<String, Object>> items = new ArrayList<>();
        if (sittingReminder != null) {
            Map<String, Object> sitting = new HashMap<>();
            sitting.put("id", "sedentary");
            sitting.put("label", "久坐提醒");
            sitting.put("enabled", sittingReminder.getSwitch_flag() == CEBC.OPENSTATUS.OPEN);
            sitting.put("startMinutes", sittingReminder.getStart_time_hour() * 60
                    + sittingReminder.getStart_time_min());
            sitting.put("endMinutes", sittingReminder.getEnd_time_hour() * 60
                    + sittingReminder.getEnd_time_min());
            sitting.put("repeat", Byte.toUnsignedInt(sittingReminder.getRepeat()));
            sitting.put("canEditInterval", false);
            items.add(sitting);
        }
        if (drinkingReminder != null) {
            int index = drinkingReminder.getInterval();
            int[] minutes = {30, 60, 120, 180};
            Map<String, Object> drinking = new HashMap<>();
            drinking.put("id", "drinking");
            drinking.put("label", "喝水提醒");
            drinking.put("enabled", drinkingReminder.getOnoff() == CEBC.OPENSTATUS.OPEN);
            drinking.put("startMinutes", drinkingReminder.getStart_hour() * 60
                    + drinkingReminder.getStart_min());
            drinking.put("endMinutes", drinkingReminder.getEnd_hour() * 60
                    + drinkingReminder.getEnd_min());
            drinking.put("intervalMinutes", index >= 0 && index < minutes.length
                    ? minutes[index] : 30);
            drinking.put("intervalChoices", java.util.Arrays.asList(30, 60, 120, 180));
            items.add(drinking);
        }
        Map<String, Object> value = new HashMap<>();
        value.put("items", items);
        return value;
    }

    private void cancelReminderRead() {
        if (remindersDeadline != null) main.removeCallbacks(remindersDeadline);
        remindersDeadline = null;
        if (pendingReminders != null) {
            pendingReminders.error("CONNECT_CANCELLED", "连接已断开", null);
            pendingReminders = null;
        }
    }

    private void readReminders(MethodChannel.Result result) {
        if (sittingReminder != null && drinkingReminder != null) {
            result.success(reminderSettings());
            return;
        }
        if (pendingReminders != null) {
            result.error("READ_BUSY", "正在读取戒指提醒设置", null);
            return;
        }
        pendingReminders = result;
        try {
            requestRingInfo(CoolWearReadRequests.Kind.SEDENTARY, CoolWearReadRequests.Kind.DRINKING);
        } catch (RuntimeException error) {
            pendingReminders = null;
            result.error("READ_FAILED", "戒指提醒设置读取未开始，请重试", null);
            return;
        }
        remindersDeadline = () -> {
            MethodChannel.Result pending = pendingReminders;
            pendingReminders = null;
            remindersDeadline = null;
            if (pending == null) return;
            if (sittingReminder != null || drinkingReminder != null) {
                pending.success(reminderSettings());
            } else {
                pending.error("READ_FAILED", "未收到戒指提醒设置", null);
            }
        };
        main.postDelayed(remindersDeadline, SETTINGS_MS);
    }

    private void writeReminder(Map<String, Object> values, MethodChannel.Result result) {
        String id = (String) values.get("id");
        Integer start = (Integer) values.get("startMinutes");
        Integer end = (Integer) values.get("endMinutes");
        boolean enabled = Boolean.TRUE.equals(values.get("enabled"));
        if (start == null || end == null || start < 0 || end > 1439 || start >= end) {
            result.error("INVALID_SETTINGS", "提醒时间范围无效", null);
            return;
        }
        if ("sedentary".equals(id) && sittingReminder != null) {
            int repeat = Byte.toUnsignedInt(sittingReminder.getRepeat());
            helper.getSendBlueData().sendSittingRemind(start / 60, start % 60,
                    end / 60, end % 60, repeat,
                    enabled ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE,
                    sittingReminder.getNoon_onoff());
            sittingReminder.setStart_time_hour(start / 60);
            sittingReminder.setStart_time_min(start % 60);
            sittingReminder.setEnd_time_hour(end / 60);
            sittingReminder.setEnd_time_min(end % 60);
            sittingReminder.setSwitch_flag(enabled
                    ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE);
        } else if ("drinking".equals(id) && drinkingReminder != null) {
            Integer interval = (Integer) values.get("intervalMinutes");
            int[] allowed = {30, 60, 120, 180};
            int index = -1;
            for (int i = 0; i < allowed.length; i++) {
                if (interval != null && allowed[i] == interval) index = i;
            }
            if (index < 0) {
                result.error("INVALID_SETTINGS", "喝水提醒频率无效", null);
                return;
            }
            helper.getSendBlueData().sendDrinkRemind(start / 60, start % 60,
                    end / 60, end % 60, index,
                    enabled ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE);
            drinkingReminder.setStart_hour(start / 60);
            drinkingReminder.setStart_min(start % 60);
            drinkingReminder.setEnd_hour(end / 60);
            drinkingReminder.setEnd_min(end % 60);
            drinkingReminder.setInterval(index);
            drinkingReminder.setOnoff(enabled
                    ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE);
        } else {
            result.error("COOLWEAR_FEATURE_UNVERIFIED", "此戒指提醒尚未读取或不受支持", null);
            return;
        }
        result.success(null);
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
        value.put("name", connectedName == null ? "CoolWear 戒指" : connectedName);
        String model = supportedModel(connectedName);
        if (model != null) value.put("model", model);
        value.put("hardwareAddress", connectedId);
        if (firmwareVersion != null && !firmwareVersion.isEmpty()) {
            value.put("firmwareVersion", firmwareVersion);
        }
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
                if (hrvRealtimeListenerReady) manual.add("hrv");
                // The vendor SDK exposes pressure as an HRV-derived algorithm
                // and does not publish a separate pressure capability bit.
                metrics.add("stress");
                manual.add("stress");
            }
            if (flags.isHasTemperature()) metrics.add("body_temperature");
        }
        value.put("metrics", metrics);
        value.put("historyMetrics", new ArrayList<>(metrics));
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
        if (canUseGesture()) features.add("gesture_control");
        if (flags != null && (flags.isHasHR24H() || flags.isHasO2())) {
            features.add("health_monitoring");
        }
        // A model name cannot establish settings support. A real settings
        // response proves this transport; unknown notification flags stay off.
        if (sittingReminder != null || drinkingReminder != null) {
            features.add("health_reminders");
        }
        if (isNotificationRelayReady()) {
            features.add("call_reminder");
            features.add("notifications");
        }
        value.put("features", features);
        // Every feature reported above is backed by this bridge. Flutter keeps
        // device-reported support separate from bridge integration so omitting
        // this field would hide otherwise usable ring controls.
        value.put("integratedFeatures", new ArrayList<>(features));
        value.put("supportsSportPause", linkConnected && deviceInfoReceived);
        value.put("supportsBackgroundSync", false);
        value.put("supportsWatchFaces", false);
        value.put("supportsOta", false);
        return value;
    }

    private boolean canUseGesture() {
        return CoolWearGestureState.supported(linkConnected, deviceInfoReceived,
                functionControl != null && functionControl.isHasGestureSupported());
    }

    private Map<String, Object> gestureSettings() {
        Map<String, Object> value = new HashMap<>();
        if (gesture.confirmedMode() != null) value.put("confirmedMode", gesture.confirmedMode());
        value.put("requiresReconnect", gesture.requiresReconnect());
        return value;
    }

    private void clearGestureWaiters() {
        if (gestureBondReceiver != null) {
            try { activity.unregisterReceiver(gestureBondReceiver); } catch (IllegalArgumentException ignored) { }
            gestureBondReceiver = null;
        }
        if (gestureDeadline != null) main.removeCallbacks(gestureDeadline);
        gestureDeadline = null;
    }

    private void finishGesture(String code, String message) {
        clearGestureWaiters();
        gesturePairingFailureCode = null;
        gesturePairingFailureMessage = null;
        MethodChannel.Result result = pendingGesture;
        pendingGesture = null;
        if (result != null) {
            if (code == null) result.success(null);
            else result.error(code, message, null);
        }
    }

    private void resetGesture(String code, String message) {
        gesture.reset();
        finishGesture(code, message);
    }

    private void onGestureMode(int mode, long generation) {
        if (!canUseGesture() || pendingGesture == null ||
                !gesture.confirm(mode, generation, android.os.SystemClock.elapsedRealtime())) return;
        clearGestureWaiters();
        if (gesturePairingFailureCode != null) {
            finishGesture(gesturePairingFailureCode,
                    gesturePairingFailureMessage + "；手势已关闭，请重新选择场景");
            return;
        }
        // The OEM enables the selected HID scene before requesting its OS bond.
        // A BLE connection/bond alone does not turn on the ring's HID service.
        if (mode != 0) {
            try {
                if (prepareGestureBond(mode)) return;
            } catch (SecurityException error) {
                rollbackGesturePairing("BLE_PERMISSION_REQUIRED", "蓝牙权限已变化");
                return;
            } catch (RuntimeException error) {
                rollbackGesturePairing("GESTURE_PAIRING_FAILED", "系统配对暂不可用");
                return;
            }
        }
        finishGesture(null, null);
    }

    private void rollbackGesturePairing(String code, String message) {
        if (pendingGesture == null) return;
        clearGestureWaiters();
        if (!canUseGesture()) {
            gesture.fail();
            finishGesture(code, message + "；手势关闭尚未确认，请重连后先关闭");
            return;
        }
        // Only this still-owned connection may undo its just-confirmed scene.
        // Do not report a closed mode until a separate mode-0 ACK arrives.
        gesturePairingFailureCode = code;
        gesturePairingFailureMessage = message;
        sendGestureMode(0);
    }

    private void writeGesture(Map<String, Object> values, MethodChannel.Result result) {
        if (!canUseGesture()) {
            result.error("COOLWEAR_FEATURE_UNVERIFIED", "当前戒指不支持手势控制", null);
            return;
        }
        Integer mode = CoolWearGestureState.validMode(values == null ? null : values.get("mode"));
        if (mode == null) {
            result.error("INVALID_GESTURE_MODE", "请选择有效的手势模式", null);
            return;
        }
        if (gesture.requiresReconnect()) {
            result.error("GESTURE_RECONNECT_REQUIRED", "重新连接后再设置手势", null);
            return;
        }
        if (pendingConnect != null || pendingScan != null || pendingHealthSync != null ||
                pendingSportSync != null || pendingAutoSettings != null || pendingReminders != null ||
                activeMeasurement != null || activeSportMode != null || pendingGesture != null) {
            result.error("OPERATION_BUSY", "请等待当前设备操作完成", null);
            return;
        }
        pendingGesture = result;
        try {
            sendGestureMode(mode);
        } catch (SecurityException error) {
            finishGesture("BLE_PERMISSION_REQUIRED", "蓝牙权限已变化，请重新允许");
        } catch (RuntimeException error) {
            finishGesture("GESTURE_PAIRING_FAILED", "系统配对暂不可用，请在手机蓝牙设置中检查后重试");
        }
    }

    // HID phone control needs the selected ring's OS bond, not merely its BLE
    // data connection. Never accept a bond belonging to another nearby ring.
    private boolean prepareGestureBond(final int mode) {
        BluetoothManager manager = (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        if (manager == null || manager.getAdapter() == null || connectedId == null) {
            finishGesture("BLUETOOTH_DISABLED", "请先开启手机蓝牙"); return true;
        }
        final BluetoothDevice device;
        try { device = manager.getAdapter().getRemoteDevice(connectedId.toUpperCase(Locale.ROOT)); }
        catch (IllegalArgumentException error) { finishGesture("INVALID_DEVICE", "设备信息无效，请重新连接"); return true; }
        if (device.getBondState() == BluetoothDevice.BOND_BONDED) return false;
        final long epoch = connectionEpoch;
        final String target = connectedId;
        gestureBondReceiver = new BroadcastReceiver() {
            @Override public void onReceive(Context context, Intent intent) {
                if (gestureBondReceiver != this) return;
                if (!BluetoothDevice.ACTION_BOND_STATE_CHANGED.equals(intent.getAction())) return;
                BluetoothDevice changed = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                if (changed == null || !target.equals(connectedId) ||
                        !RingGestureBondPolicy.accepts(target, epoch, changed.getAddress(),
                                connectionEpoch, pendingGesture != null)) return;
                int state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR);
                if (state == BluetoothDevice.BOND_BONDED) {
                    activity.unregisterReceiver(this); gestureBondReceiver = null;
                    if (gestureDeadline != null) main.removeCallbacks(gestureDeadline);
                    gestureDeadline = null;
                    if (!canUseGesture()) { finishGesture("NOT_CONNECTED", "戒指已断开，请重新连接"); return; }
                    finishGesture(null, null);
                } else if (state == BluetoothDevice.BOND_NONE) {
                    rollbackGesturePairing("GESTURE_PAIRING_CANCELLED", "系统配对未完成");
                }
            }
        };
        IntentFilter filter = new IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED);
        if (Build.VERSION.SDK_INT >= 33) activity.registerReceiver(gestureBondReceiver, filter, Context.RECEIVER_EXPORTED);
        else activity.registerReceiver(gestureBondReceiver, filter);
        gestureDeadline = () -> rollbackGesturePairing("GESTURE_PAIRING_TIMEOUT", "系统配对超时");
        main.postDelayed(gestureDeadline, 30_000L);
        if (device.getBondState() != BluetoothDevice.BOND_BONDING && !device.createBond()) {
            rollbackGesturePairing("GESTURE_PAIRING_FAILED", "无法发起系统配对");
        }
        return true;
    }

    private void sendGestureMode(int mode) {
        if (!gesture.begin(mode, android.os.SystemClock.elapsedRealtime())) {
            finishGesture("OPERATION_BUSY", "请重新连接后设置手势"); return;
        }
        gestureDeadline = () -> {
            gesture.fail();
            finishGesture("GESTURE_CONFIRMATION_TIMEOUT", gesturePairingFailureCode != null
                    ? "手势关闭尚未确认，请重连后先关闭" : "戒指未确认，重新连接后重试");
        };
        main.postDelayed(gestureDeadline, CoolWearGestureState.TIMEOUT_MS);
        try {
            // Use the OEM send API: its actual wire type is 44. The similarly
            // named entity.toCEDevData() emits 128 and is not this command.
            helper.getSendBlueData().sendGestureConfig(mode);
        } catch (RuntimeException error) {
            gesture.fail();
            finishGesture("GESTURE_SEND_FAILED", "手势设置失败，重新连接后重试");
        }
    }

    private void onHeartValues(List<K6_HeartStruct> values) {
        if (activeSportMode != null && linkConnected) {
            for (K6_HeartStruct value : values) {
                int bpm = value.getHeartNums();
                // This SDK callback is the live display channel, not history.
                // HR05 may send a zero/firmware-local timestamp here; do not
                // reject a valid live sample using history timestamp rules.
                if (bpm > 0 && bpm <= 250) {
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

    private void postHrvPacket(ArrayList<k6_RRI_HRV_DATA> values, boolean realtime) {
        final long generation = measurementGeneration;
        final List<k6_RRI_HRV_DATA> snapshot = values == null ? null : new ArrayList<>(values);
        if (realtime) postCurrentPacket(() -> onHrvValues(snapshot, true, generation));
        else postHistoryPacket(() -> onHrvValues(snapshot, false, generation));
    }

    private void hrvDiagnostic(String event, String reason) {
        if (!BuildConfig.DEBUG) return;
        // 不记录数值、时间戳、完整设备/账号标识或 SDK 原始包。
        Log.i(TAG, "manual HRV; event=" + event + ",reason=" + reason
                + ",generation=" + measurementGeneration + ",live=" + hrvLivePackets
                + ",history=" + hrvHistoryPackets + ",legacy=" + hrvLegacyPackets
                + ",stress=" + hrvStressPackets);
    }

    private void clearMeasurementSession(String reason) {
        if ("hrv".equals(activeMeasurement)) hrvDiagnostic("stop", reason);
        measurementGeneration++;
        measurementStartedAt = 0;
        activeMeasurement = null;
        resultEmitted = false;
    }

    private void onHrvValues(List<k6_RRI_HRV_DATA> values, boolean realtime, long generation) {
        // 被动历史和原始记录仍按原 mapper 入库；取消测量不删除戒指/手机历史。
        collectHealth(CoolWearRecordMapper.hrvRecords(connectedId, firmwareVersion, values));
        if (!"hrv".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        if (generation != measurementGeneration) {
            hrvDiagnostic("reject", "retired_session");
            return;
        }
        if (realtime) hrvLivePackets++; else hrvHistoryPackets++;
        hrvDiagnostic("packet", realtime ? "realtime_60" : "history_61_or_passive");
        if (!realtime) return;
        if (values == null || values.isEmpty()) {
            hrvDiagnostic("reject", "empty_packet");
            return;
        }
        for (k6_RRI_HRV_DATA value : values) {
            if (value == null) { hrvDiagnostic("reject", "null_sample"); continue; }
            long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
            int sdnn = value.getSdnn();
            int quality = value.getQuality();
            int validCount = value.getValid_count();
            if (sdnn <= 0 || sdnn > 1_000) { hrvDiagnostic("reject", "invalid_structure"); continue; }
            if (quality < 1 || quality > 3) { hrvDiagnostic("reject", "quality"); continue; }
            if (validCount < 2 || validCount > 255) { hrvDiagnostic("reject", "sample_count"); continue; }
            // 仅本轮实时结果可成为手动测量。时间无效不能改成 now，否则旧结果
            // 会变成“新测量”并可能触发健康提醒。2 秒仅容纳固件秒精度。
            if (time == 0 || time < measurementStartedAt - 2_000L
                    || time > System.currentTimeMillis() + 5_000L) {
                hrvDiagnostic("reject", "timestamp");
                continue;
            }
            Map<String, Object> measured = new LinkedHashMap<>();
            measured.put("value", sdnn);
            measured.put("sdnn", sdnn);
            measured.put("sdkQuality", quality);
            measured.put("validCount", validCount);
            if (value.getRmssd() > 0) measured.put("rmssd", value.getRmssd());
            if (value.getRri() > 0) measured.put("rri", value.getRri());
            hrvDiagnostic("accepted", "realtime_valid");
            emitMeasurement("hrv", time, measured, "ms");
            return;
        }
    }

    private void onStressValues(List<K6_StressStruct> values) {
        if ("hrv".equals(activeMeasurement)) {
            hrvStressPackets++;
            hrvDiagnostic("packet", "stress_compat_not_hrv");
        }
        collectHealth(CoolWearRecordMapper.stressRecords(
                connectedId, firmwareVersion, values));
        if (!"stress".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        Log.i(TAG, "manual stress callback received; source=stress, sample count="
                + values.size());
        for (K6_StressStruct value : values) {
            if (value == null) continue;
            long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
            int stress = value.getStressValue();
            if (BuildConfig.DEBUG) {
                Log.i(TAG, "manual stress sample; source=stress,validRange="
                        + (stress >= 1 && stress <= 100) + ",currentTime=" + (time != 0));
            }
            if (stress >= 1 && stress <= 100) {
                if (time == 0) time = System.currentTimeMillis();
                emitMeasurement("stress", time, stress, "");
                return;
            }
        }
        Log.i(TAG, "manual stress callback had no current valid sample; source=stress");
    }

    private void onStressCompatValues(List<K6_HrvStruct> values) {
        if ("hrv".equals(activeMeasurement)) {
            hrvLegacyPackets++;
            hrvDiagnostic("packet", "legacy_45_not_hrv");
        }
        // The SDK aliases legacy HRV and stress to DataType 45. Its one-byte
        // hrvNums has no confirmed millisecond/SDNN meaning; never emit it as HRV.
        if (!"stress".equals(activeMeasurement) || resultEmitted || !linkConnected) return;
        Log.i(TAG, "manual stress callback received; source=real_hrv, sample count="
                + values.size());
        for (K6_HrvStruct value : values) {
            if (value == null) continue;
            long time = CoolWearRecordMapper.currentTimestamp(value.getTime());
            int stress = value.getHrvNums();
            if (BuildConfig.DEBUG) {
                Log.i(TAG, "manual stress sample; source=real_hrv,validRange="
                        + (stress >= 1 && stress <= 100) + ",currentTime=" + (time != 0));
            }
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
        if ("hrv".equals(metric)) record.put("rawVersion", 2);
        String model = supportedModel(connectedName);
        if (model != null) record.put("sourceModel", model);
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
        if (!requiresActive && (pendingHealthSync != null || pendingSportSync != null)) {
            result.error("SYNC_BUSY", "请等待戒指同步结束后再开始运动", null);
            return;
        }
        helper.getSendBlueData().sendAppSport(type, status, 0, 0);
        if (!requiresActive) {
            activeSportType = type;
            activeSportMode = mode;
        }
        // App-sport control carries only state/time/distance in this SDK.
        // Open the documented HR channel explicitly, not a fake sport field.
        updateSportHeartStream(status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_START
                || status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_CONTINUE);
        if (status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP
                || status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP_FORCE) {
            activeSportType = null;
            activeSportMode = null;
        }
        result.success(null);
    }

    private void updateSportHeartStream(boolean enabled) {
        boolean canStart = enabled && functionControl != null
                && functionControl.isHr_measure_button();
        if (canStart == sportHeartStreamStarted) return;
        if (linkConnected && activeMeasurement == null) {
            helper.getSendBlueData().sendHeartRateSwitch(
                    canStart ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE);
        }
        sportHeartStreamStarted = canStart;
    }

    private void onSportUpdate(K6_SEND_APP_SPORT_STRUCT value) {
        int type = value.getType();
        int status = value.getStatus();
        String mode = CoolWearRecordMapper.sportMode(type);
        if (mode == null) mode = activeSportMode;
        Map<String, Object> data = new HashMap<>();
        if (value.getTime() > 0) data.put("durationSeconds", value.getTime());
        if (value.getDistance() > 0) data.put("distanceMeters", value.getDistance());
        if (!data.isEmpty()) emit("sportData", data);

        String state;
        if (status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP
                || status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_STOP_FORCE) {
            state = "stopped";
            updateSportHeartStream(false);
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

    private void setRemoteCamera(boolean enabled) {
        final long session = ++cameraSession;
        final long connection = connectionEpoch;
        final String id = connectedId;
        // 关闭或重新进入相机都换一次监听。旧手势即使排在主线程队列，也不能替新页面拍照。
        K6BleDataResult<Integer> listener = enabled ? state -> {
            if (state != null && state == CEBC.OPENSTATUS.OPEN) {
                main.post(() -> {
                    if (session != cameraSession || connection != connectionEpoch || activeBridge != this
                            || id == null || !id.equals(connectedId) || !linkConnected || !deviceInfoReceived) return;
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("deviceId", id);
                    emitOnMain("cameraShutter", payload);
                });
            }
            return false;
        } : null;
        helper.getRcvDataManager().addBleDataResultListener(K6_Action.RCVD.RCVD_TAKE_PHOTOS, listener);
        try {
            helper.getSendBlueData().sendPhotoSwitch(enabled);
        } catch (RuntimeException error) {
            cameraSession++;
            throw error;
        }
    }

    private void emit(String type, Map<String, Object> payload) {
        final long eventEpoch = connectionEpoch;
        final String eventTarget = connectedId;
        main.post(() -> {
            if (("healthRecord".equals(type) || "sportData".equals(type))
                    && (eventEpoch != connectionEpoch || eventTarget == null
                        || !eventTarget.equals(connectedId) || !linkConnected)) return;
            emitOnMain(type, payload);
        });
    }

    private void emitOnMain(String type, Map<String, Object> payload) {
        if (sink == null) return;
        Map<String, Object> event = new HashMap<>();
        event.put("type", type);
        event.put("payload", payload);
        sink.success(event);
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
            // 先查 Android 自己的连接/配对记录；查询不应启动厂商 SDK 的自动连接。
            if ("lookupOwnedSystemTarget".equals(call.method) || "lookupBondedDevice".equals(call.method)) {
                lookupSystemTarget(call, result, "lookupOwnedSystemTarget".equals(call.method));
                return;
            }
            ensureSdk();
            if (pendingGesture != null && !("disconnect".equals(call.method) ||
                    "getCapabilities".equals(call.method) || "getDeviceDetails".equals(call.method) ||
                    "stopScan".equals(call.method) ||
                    ("readDeviceFeature".equals(call.method) &&
                            "gesture_control".equals(call.argument("feature"))))) {
                result.error("OPERATION_BUSY", "请等待手势指令确认", null);
                return;
            }
            profileTrace("method " + call.method + "; link=" + linkConnected + "; info=" + deviceInfoReceived);
            switch (call.method) {
                case "clearRingHistory":
                    if (clearAttemptEpoch == connectionEpoch) {
                        result.error("RING_HISTORY_CLEAR_ALREADY_REQUESTED", "本次连接已请求清空，不会重复执行", null);
                        return;
                    }
                    String clearTarget = call.argument("id");
                    String clearOwner = call.argument("ownerKey");
                    if (!linkConnected || !deviceInfoReceived || connectedId == null ||
                            !connectedId.equalsIgnoreCase(clearTarget) || clearOwner == null || clearOwner.isEmpty()) {
                        result.error("STALE_DEVICE_SESSION", "戒指或账号已变化，未清空数据", null);
                        return;
                    }
                    if (pendingConnect != null || pendingHealthSync != null || pendingSportSync != null ||
                            pendingAutoSettings != null || pendingReminders != null || activeMeasurement != null || activeSportMode != null) {
                        result.error("DEVICE_BUSY", "设备忙，未发送清空指令", null);
                        return;
                    }
                    // History-only SDK operation; no factory reset or retry.
                    // This Android SDK exposes no clear-data ACK callback.
                    clearAttemptEpoch = connectionEpoch;
                    // 清空之前退役上一轮只等待晚到运动的窗口，不向新一轮交付旧缓存。
                    failPendingSync("CONNECT_CANCELLED", "戒指已开始初始化");
                    helper.getSendDataManager().sendClearData();
                    result.success("requested");
                    break;
                case "scanDevices":
                    if (pendingScan != null) {
                        result.error("SCAN_BUSY", "戒指扫描正在进行", null);
                        return;
                    }
                    String exactTarget = call.argument("exactTargetId");
                    if (exactTarget != null) exactTarget = exactTarget.toUpperCase(Locale.ROOT);
                    if (exactTarget != null && !BluetoothAdapter.checkBluetoothAddress(exactTarget)) {
                        result.error("INVALID_DEVICE", "无效的设备标识", null);
                        return;
                    }
                    helper.stopScan();
                    final long scan = ++scanGeneration;
                    configureScanCallback(scan);
                    scanned.clear();
                    pendingScan = result;
                    scanExactTargetId = exactTarget;
                    try { helper.startScan(); }
                    catch (RuntimeException error) {
                        pendingScan = null; finishScan();
                        result.error("COOLWEAR_SCAN_FAILED", "蓝牙扫描无法开始，请检查权限与蓝牙后重试", null);
                        break;
                    }
                    if (scan == scanGeneration && pendingScan != null) {
                        scanDeadline = () -> { if (scan == scanGeneration) finishScan(); };
                        main.postDelayed(scanDeadline, SCAN_MS);
                    }
                    break;
                case "stopScan":
                    finishScan();
                    result.success(null);
                    break;
                case "connect":
                    cancelHealthPulse(true);
                    String id = call.argument("id");
                    Map<String, Object> candidate = currentConnectCandidate(id);
                    if (id == null || candidate == null || pendingConnect != null) {
                        result.error("UNKNOWN_SCANNED_DEVICE", "请重新扫描并选择 CoolWear 戒指", null);
                        return;
                    }
                    finishScan();
                    resetGesture("CONNECT_CANCELLED", "连接目标已更换");
                    failPendingSync("CONNECT_CANCELLED", "连接目标已更换");
                    connectionHealthRecords.clear();
                    connectionRecordReceipts.clear();
                    connectionHistoryBatches.clear();
                    connectedId = id;
                    connectedName = (String) candidate.get("name");
                    connectedVendorId = (String) candidate.get("vendorId");
                    linkConnected = false;
                    deviceInfoReceived = false;
                    firmwareVersion = null;
                    functionControl = null;
                    autoHeartEnabled = null;
                    autoOxygenEnabled = null;
                    autoMeasureIntervalMinutes = 5;
                    sittingReminder = null;
                    drinkingReminder = null;
                    batteryPercent = null;
                    charging = null;
                    clearMeasurementSession("target_or_connection_changed");
                    activeSportMode = null;
                    activeSportType = null;
                    sportHeartStreamStarted = false;
                    recoveringConnection = false;
                    pendingConnect = result;
                    try {
                        // id 已通过本轮扫描/系统精确候选验证；仅此入口可以重新授予 SDK 目标。
                        recoveryTarget.activate(id.toUpperCase(Locale.ROOT), recoverySdk);
                        helper.connectDev(id.toUpperCase(Locale.ROOT), "");
                    } catch (RuntimeException error) {
                        failConnect("COOLWEAR_SDK_ERROR", "戒指通信失败，请重试");
                        break;
                    }
                    connectDeadline = () -> failConnect(
                            "COOLWEAR_HANDSHAKE_TIMEOUT", "戒指未完成设备信息握手，请重试");
                    main.postDelayed(connectDeadline, CONNECT_MS);
                    break;
                case "disconnect":
                    cancelHealthPulse(true);
                    resetGesture("CONNECT_CANCELLED", "连接已断开");
                    finishScan();
                    failPendingSync("CONNECT_CANCELLED", "连接已断开");
                    failPendingAutoSettings("CONNECT_CANCELLED", "连接已断开");
                    cancelReminderRead();
                    if (pendingConnect != null) failConnect("CONNECT_CANCELLED", "连接已取消");
                    else pauseSdkRecovery();
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
                    sittingReminder = null;
                    drinkingReminder = null;
                    clearMeasurementSession("target_or_connection_changed");
                    activeSportMode = null;
                    activeSportType = null;
                    result.success(null);
                    sportHeartStreamStarted = false;
                    break;
                case "getDeviceDetails":
                    // 电量只查询电量；不得为了刷新状态重发 SDK 的整包设置。
                    if (linkConnected && deviceInfoReceived && !gesture.pending() && pendingHealthSync == null && pendingSportSync == null &&
                            activeMeasurement == null && android.os.SystemClock.elapsedRealtime() - batteryQueryAt >= 8_000L) {
                        batteryQueryAt = android.os.SystemClock.elapsedRealtime();
                        try { requestRingInfo(CoolWearReadRequests.Kind.BATTERY); }
                        catch (RuntimeException error) { Log.w(TAG, "optional battery query skipped"); }
                    }
                    result.success(linkConnected && deviceInfoReceived ? deviceDetails() : null);
                    break;
                case "getCapabilities":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                    } else {
                        if (functionControl == null) {
                            try { requestRingInfo(CoolWearReadRequests.Kind.CAPABILITIES); }
                            catch (RuntimeException error) { Log.w(TAG, "optional capability query skipped"); }
                        }
                        result.success(capabilities());
                    }
                    break;
                case "acknowledgeHealthRecords":
                    Map<String, String> receipts = call.argument("receipts");
                    acknowledgeHealthRecords(receipts);
                    result.success(null);
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
                    try { requestRingInfo(CoolWearReadRequests.Kind.AUTO_MONITORING); }
                    catch (RuntimeException error) {
                        failPendingAutoSettings("AUTO_MEASURE_READ_FAILED", "戒指监测设置读取未开始，请重试");
                        return;
                    }
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
                case "readAutoMeasureIntervals":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                        return;
                    }
                    if (autoHeartEnabled == null || autoOxygenEnabled == null) {
                        result.error("AUTO_MEASURE_READ_FAILED", "请先读取戒指自动检测设置", null);
                        return;
                    }
                    result.success(autoMeasureIntervals());
                    break;
                case "setAutoMeasureInterval":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                        return;
                    }
                    String intervalType = call.argument("type");
                    Integer intervalMinutes = call.argument("minutes");
                    if (!("heartRate".equals(intervalType) || "bloodOxygen".equals(intervalType))
                            || intervalMinutes == null || intervalMinutes < 1 || intervalMinutes > 120
                            || autoHeartEnabled == null || autoOxygenEnabled == null) {
                        result.error("INVALID_INTERVAL", "请先读取设置并选择有效监测间隔", null);
                        return;
                    }
                    helper.getSendBlueData().sendHeartAutoSwitch(
                            autoHeartEnabled ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE,
                            autoOxygenEnabled ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE,
                            intervalMinutes);
                    autoMeasureIntervalMinutes = intervalMinutes;
                    result.success(null);
                    break;
                case "readDeviceFeature":
                    if ("gesture_control".equals(call.argument("feature"))) {
                        if (canUseGesture()) result.success(gestureSettings());
                        else result.error("COOLWEAR_FEATURE_UNVERIFIED", "当前戒指不支持手势控制", null);
                        return;
                    }
                    String readFeature = call.argument("feature");
                    if (("notifications".equals(readFeature) || "call_reminder".equals(readFeature))
                            && isNotificationRelayReady()) {
                        Map<String, Object> settings = notificationSettings();
                        if ("call_reminder".equals(readFeature)) {
                            settings.put("supportedKeys", java.util.Collections.singletonList("incomingCall"));
                        }
                        result.success(settings);
                    } else if ("health_reminders".equals(readFeature) && canReadReminders()) {
                        readReminders(result);
                    } else {
                        result.error("COOLWEAR_FEATURE_UNVERIFIED", "此戒指功能不受支持", null);
                    }
                    break;
                case "writeDeviceFeature":
                    if ("gesture_control".equals(call.argument("feature"))) {
                        writeGesture(call.argument("values"), result);
                        return;
                    }
                    String writeFeature = call.argument("feature");
                    Map<String, Object> notificationValues = call.argument("values");
                    if (notificationValues == null) {
                        result.error("INVALID_SETTINGS", "消息提醒设置无效", null);
                        return;
                    }
                    if ("health_reminders".equals(writeFeature)) {
                        if (canReadReminders()) writeReminder(notificationValues, result);
                        else result.error("COOLWEAR_FEATURE_UNVERIFIED", "请先读取戒指提醒设置", null);
                        break;
                    }
                    if (!("notifications".equals(writeFeature) || "call_reminder".equals(writeFeature))
                            || !isNotificationRelayReady()) {
                        result.error("COOLWEAR_FEATURE_UNVERIFIED", "此戒指功能不受支持", null);
                        return;
                    }
                    android.content.SharedPreferences.Editor editor = activity.getSharedPreferences(
                            NOTIFICATION_PREFS, Context.MODE_PRIVATE).edit();
                    for (String key : NOTIFICATION_KEYS) {
                        if (notificationValues.containsKey(key)
                                && !(notificationValues.get(key) instanceof Boolean)) {
                            result.error("INVALID_SETTINGS", "请选择有效的提醒开关", null);
                            return;
                        }
                    }
                    for (String key : NOTIFICATION_KEYS) {
                        if ("call_reminder".equals(writeFeature) && !"incomingCall".equals(key)) continue;
                        if (notificationValues.containsKey(key)) {
                            editor.putBoolean(key, Boolean.TRUE.equals(notificationValues.get(key)));
                        }
                    }
                    editor.apply();
                    result.success(null);
                    break;
                case "pulseHealthReminder":
                    pulseHealthReminder(call.argument("expectedDeviceId"), result);
                    break;
                case "triggerDeviceAction":
                    if (!linkConnected || !deviceInfoReceived) {
                        result.error("NOT_CONNECTED", "请先连接戒指", null);
                        return;
                    }
                    String feature = call.argument("feature");
                    Boolean actionEnabled = call.argument("enabled");
                    boolean enabled = actionEnabled == null || actionEnabled;
                    if ("notifications".equals(feature) && isNotificationRelayReady()) {
                        activity.startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS));
                    } else if ("find_watch".equals(feature)) {
                        if (enabled) helper.getSendBlueData().sendFindDevice();
                    } else if ("camera".equals(feature) &&
                            functionControl != null &&
                            functionControl.isHasGestureSupported()) {
                        setRemoteCamera(enabled);
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
                    startMeasurementSession(metric, result);
                    break;
                case "stopMeasurement":
                    String stopping = call.argument("metric");
                    Log.i(TAG, "manual measurement command stop: " + stopping);
                    stopMeasurementSession(stopping, result);
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

    private void startMeasurementSession(String metric, MethodChannel.Result result) {
        if (activeMeasurement != null) {
            result.error("MEASUREMENT_ACTIVE", "请先结束当前测量", null);
            return;
        }
        measurementGeneration++;
        measurementStartedAt = System.currentTimeMillis();
        activeMeasurement = metric;
        resultEmitted = false;
        hrvLivePackets = hrvHistoryPackets = hrvLegacyPackets = hrvStressPackets = 0;
        if ("hrv".equals(metric)) hrvDiagnostic("start", "command_62_requested");
        Log.i(TAG, "manual measurement command start: " + metric);
        try {
            setMeasurement(metric, true);
        } catch (RuntimeException error) {
            Map<String, Object> details = new HashMap<>();
            details.put("metric", metric);
            details.put("deviceId", connectedId);
            details.put("generation", measurementGeneration);
            if ("hrv".equals(metric)) hrvDiagnostic("command_error", "start_failed");
            clearMeasurementSession("start_failed");
            result.error("MEASUREMENT_START_FAILED", "测量启动失败，请重试", details);
            return;
        }
        // SDK 的发送 API 无 62 ACK；成功仅表示已提交命令，不是测量完成。
        if ("hrv".equals(metric)) hrvDiagnostic("start", "command_62_submitted");
        result.success(null);
    }

    private void stopMeasurementSession(String stopping, MethodChannel.Result result) {
        // 旧页面迟到的停止请求不能撤销后来开始的另一项测量。
        if (activeMeasurement != null && !activeMeasurement.equals(stopping)) {
            result.error("MEASUREMENT_ACTIVE", "当前正在进行另一项测量", null);
            return;
        }
        // 先撤销本轮，即使停止命令抛错，旧队列也不能完成下一轮测量。
        clearMeasurementSession("explicit_stop");
        if (stopping != null) {
            try { setMeasurement(stopping, false); }
            catch (RuntimeException error) {
                if ("hrv".equals(stopping)) hrvDiagnostic("command_error", "stop_failed");
                result.error("MEASUREMENT_STOP_FAILED", "停止测量未获确认", null);
                return;
            }
        }
        result.success(null);
    }

    private void setMeasurement(String metric, boolean enabled) {
        int state = enabled ? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE;
        if ("heart_rate".equals(metric)) {
            helper.getSendBlueData().sendHeartRateSwitch(state);
        } else if ("blood_oxygen".equals(metric)) {
            helper.getSendBlueData().sendBloodOxygenDetection(state);
        } else if ("hrv".equals(metric)) {
            // Only the RRI protocol reports explicit SDNN/RMSSD/RRI fields.
            // Do not start or stop the ambiguous legacy command shared with stress.
            helper.getSendBlueData().sendRriHrvCmd(state);
        } else if ("stress".equals(metric)) {
            helper.getSendBlueData().sendStressSwitch(state);
        }
    }

    private void cancelHealthPulse(boolean stop) {
        MethodChannel.Result pending = pendingHealthPulse;
        pendingHealthPulse = null;
        if (healthPulseStop != null) main.removeCallbacks(healthPulseStop);
        healthPulseStop = null;
        if (pending != null && stop && linkConnected && connectionEpoch == healthPulseEpoch
                && healthPulseTarget != null && healthPulseTarget.equals(connectedId)) {
            try { helper.getSendDataManager().sendK6_SEND_DATA_TYPE_FIND_PHONE(new K6_DATA_TYPE_FIND_PHONE_OR_DEVICE(0)); }
            catch (RuntimeException ignored) { /* Disconnect must remain usable. */ }
        }
        healthPulseTarget = null;
        if (pending != null) pending.error("HAPTIC_CANCELLED", "戒指连接已变化，提醒结果未确认", null);
    }

    private void pulseHealthReminder(String expected, MethodChannel.Result result) {
        if (!linkConnected || !deviceInfoReceived || expected == null || connectedId == null
                || !expected.equalsIgnoreCase(connectedId) || supportedModel(connectedName) == null
                || !RingNamePolicy.isVibratingReminderName(connectedName)) {
            result.error("HAPTIC_UNAVAILABLE", "此戒指暂不支持振动提醒", null); return;
        }
        if (pendingHealthPulse != null || pendingHealthSync != null || pendingSportSync != null || activeMeasurement != null) {
            result.error("DEVICE_BUSY", "戒指忙，请稍后重试", null); return;
        }
        pendingHealthPulse = result;
        healthPulseTarget = connectedId;
        healthPulseEpoch = connectionEpoch;
        try { helper.getSendDataManager().sendK6_SEND_DATA_TYPE_FIND_PHONE(new K6_DATA_TYPE_FIND_PHONE_OR_DEVICE(1)); }
        catch (RuntimeException failure) { cancelHealthPulse(true); return; }
        healthPulseStop = () -> {
            if (pendingHealthPulse != result) return;
            if (!linkConnected || connectionEpoch != healthPulseEpoch || !healthPulseTarget.equals(connectedId)) {
                cancelHealthPulse(false); return;
            }
            try {
                helper.getSendDataManager().sendK6_SEND_DATA_TYPE_FIND_PHONE(new K6_DATA_TYPE_FIND_PHONE_OR_DEVICE(0));
                pendingHealthPulse = null; healthPulseStop = null; healthPulseTarget = null;
                Map<String, Object> value = new HashMap<>();
                value.put("accepted", true); value.put("acknowledged", false);
                // These public SDK calls return void: no device ACK is claimed.
                result.success(value);
            } catch (RuntimeException failure) {
                cancelHealthPulse(false);
            }
        };
        main.postDelayed(healthPulseStop, 700L);
    }

    public void dispose() {
        clearMeasurementSession("disposed");
        cancelHealthPulse(true);
        resetGesture("BRIDGE_DISPOSED", "戒指连接已关闭");
        boolean ownsSdk = activeBridge == this;
        if (ownsSdk) activeBridge = null;
        linkConnected = false;
        deviceInfoReceived = false;
        if (scanDeadline != null) main.removeCallbacks(scanDeadline);
        if (connectDeadline != null) main.removeCallbacks(connectDeadline);
        if (syncDeadline != null) main.removeCallbacks(syncDeadline);
        failPendingAutoSettings("BRIDGE_DISPOSED", "戒指连接已关闭");
        cancelReminderRead();
        failPendingSync("BRIDGE_DISPOSED", "戒指连接已关闭");
        if (ownsSdk && helper != null) {
            helper.stopScan();
            pauseSdkRecovery();
        }
        sink = null;
    }
}
