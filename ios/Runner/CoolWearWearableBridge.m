#import "CoolWearWearableBridge.h"
#import "CoolWearPolicy.h"
#import "CoolWearHistory.h"
#import "CoolWearRecovery.h"
#import "CoolWearMonitoring.h"
#import "CoolWearControls.h"
#import "SayRingActivitySleepPolicy.h"
#import <BluetoothLibrary/BluetoothLibrary.h>
#import <CommonCrypto/CommonDigest.h>

static void CoolWearOnMain(dispatch_block_t block) {
    if (NSThread.isMainThread) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

@interface CoolWearWearableBridge () <FlutterStreamHandler>
@property(nonatomic, strong) FlutterMethodChannel *methods;
@property(nonatomic, strong) FlutterEventChannel *events;
@property(nonatomic, copy) FlutterEventSink sink;
@property(nonatomic, strong) CEProductK6 *product;
@property(nonatomic, strong) NSMutableDictionary<NSString *, SearchPeripheral *> *scanned;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *scanServices;
@property(nonatomic, copy) FlutterResult pendingScan;
@property(nonatomic, copy) FlutterResult pendingConnect;
@property(nonatomic, copy) FlutterResult pendingDisconnect;
@property(nonatomic, copy) FlutterResult pendingMeasurement;
@property(nonatomic, strong) CBPeripheral *target;
@property(nonatomic, copy) NSString *targetName;
@property(nonatomic, copy) NSDictionary *deviceInfo;
@property(nonatomic, copy) NSDictionary *flags;
@property(nonatomic, strong) NSNumber *battery;
@property(nonatomic, strong) NSDate *batteryDate;
@property(nonatomic, strong) NSNumber *charging;
@property(nonatomic, copy) NSString *activeMetric;
@property(nonatomic, strong) NSDate *measurementStart;
@property(nonatomic) BOOL emittedMeasurement;
@property(nonatomic) BOOL awaitingInfo;
@property(nonatomic) BOOL cancelling;
@property(nonatomic) NSUInteger cancellationChecks;
@property(nonatomic) NSUInteger connectionGeneration;
@property(nonatomic) NSUInteger scanGeneration;
@property(nonatomic) NSUInteger measurementGeneration;
@property(nonatomic, strong) NSMutableArray *observers;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *pendingPassiveRecords;
@property(nonatomic) BOOL dataDeliveryReady;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, CoolWearHistoryBatch *> *historyBatches;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *historyRecords;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, CoolWearHistoryBatch *> *syncBatches;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *syncRecords;
@property(nonatomic) BOOL historySnapshotDelivered;
@property(nonatomic, copy) FlutterResult pendingSync;
@property(nonatomic, copy) FlutterResult pendingBattery;
@property(nonatomic) NSUInteger syncGeneration;
@property(nonatomic) NSUInteger batteryGeneration;
@property(nonatomic, copy) NSString *recoveryID;
@property(nonatomic, copy) NSString *recoveryName;
@property(nonatomic, copy) NSString *recoveryContext;
@property(nonatomic) NSUInteger recoveryGeneration;
@property(nonatomic) BOOL recoveryScheduled;
@property(nonatomic) BOOL recoveryScanning;
@property(nonatomic) BOOL recoveryConnecting;
@property(nonatomic) BOOL passiveSleepScheduled;
@property(nonatomic, copy) NSDictionary *monitoringSnapshot;
@property(nonatomic, copy) NSDictionary *monitoringExpected;
@property(nonatomic, copy) FlutterResult pendingMonitoringRead;
@property(nonatomic, copy) FlutterResult pendingMonitoringWrite;
@property(nonatomic) BOOL monitoringReadbackRequested;
@property(nonatomic) BOOL monitoringReadbackAcknowledged;
@property(nonatomic, copy) NSDictionary *monitoringReadbackSnapshot;
@property(nonatomic) NSUInteger monitoringGeneration;
@property(nonatomic, copy) FlutterResult pendingFind;
@property(nonatomic) NSUInteger findGeneration;
@property(nonatomic) BOOL findSupported;
@property(nonatomic) BOOL findProbing;
@property(nonatomic, copy) FlutterResult pendingControl;
@property(nonatomic) NSUInteger controlGeneration;
@property(nonatomic) BOOL cameraActive;
@property(nonatomic, strong) NSNumber *gestureMode;
@property(nonatomic, strong) NSNumber *callReminder;
@property(nonatomic, strong) NSNumber *controlExpectedCall;
@property(nonatomic, strong) NSNumber *controlReadbackCall;
@property(nonatomic) BOOL controlReadingCall;
@property(nonatomic) BOOL controlReadbackAcknowledged;
@property(nonatomic) BOOL controlIsWrite;
@end

@implementation CoolWearWearableBridge

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    if (!(self = [super init])) return nil;
    _scanned = [NSMutableDictionary dictionary];
    _scanServices = [NSMutableDictionary dictionary];
    _observers = [NSMutableArray array];
    _pendingPassiveRecords = [NSMutableDictionary dictionary];
    _historyBatches = [NSMutableDictionary dictionary];
    _historyRecords = [NSMutableDictionary dictionary];
    _syncBatches = [NSMutableDictionary dictionary];
    _syncRecords = [NSMutableDictionary dictionary];
    // Lazily initialize the vendor singleton only when the user requests a
    // scan/connect. Never read/adopt its installation-wide saved device.
    _methods = [FlutterMethodChannel methodChannelWithName:@"cc.saidian.ring/commands" binaryMessenger:messenger];
    _events = [FlutterEventChannel eventChannelWithName:@"cc.saidian.ring/events" binaryMessenger:messenger];
    [_events setStreamHandler:self];
    __weak typeof(self) weakSelf = self;
    [_methods setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        CoolWearOnMain(^{ [weakSelf handle:call result:result]; });
    }];
    return self;
}

- (FlutterError *)error:(NSString *)code message:(NSString *)message {
    return [FlutterError errorWithCode:code message:message details:nil];
}

- (void)emit:(NSString *)type payload:(NSDictionary *)payload {
    NSDictionary *permitted = SRActivitySleepEvent(type, payload ?: @{});
    if (self.sink && permitted) self.sink(@{@"type": type, @"payload": permitted});
}

- (void)disableVendorRecovery {
    self.product.lastConnectUUId = nil;
    self.product.UUIDStr = nil;
    // Do not call startAutoConnect/saveConnectedUUid: account-owned Flutter
    // recovery is the only authority permitted to choose the exact target.
}

- (void)initializeSDK {
    if (self.product) return;
    self.product = [CEProductK6 shareInstance];
    [self disableVendorRecovery];
    [self.product cleanCmdQueue];
    [self.product.connect cancel];
    self.product.connect.time = 0;
    __weak typeof(self) weakSelf = self;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSString *name in @[ScanPeripheralsNoticeKey, ProductStatusChangeNoticeKey, CEProductK6ReceiveDataNoticeKey]) {
        id observer = [center addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
            NSUInteger generation = weakSelf.connectionGeneration;
            NSUInteger scan = weakSelf.scanGeneration;
            NSUInteger measurement = weakSelf.measurementGeneration;
            CoolWearOnMain(^{
                if (!weakSelf || generation != weakSelf.connectionGeneration) return;
                if ([note.name isEqualToString:ScanPeripheralsNoticeKey]) {
                    if (scan == weakSelf.scanGeneration) [weakSelf receiveScan:note.object];
                } else if ([note.name isEqualToString:ProductStatusChangeNoticeKey]) {
                    [weakSelf receiveStatus:[note.object integerValue]];
                } else {
                    [weakSelf receiveData:note.userInfo depth:0 measurement:measurement];
                }
            });
        }];
        [self.observers addObject:observer];
    }
    for (NSString *name in @[UIApplicationDidBecomeActiveNotification, UIApplicationDidEnterBackgroundNotification]) {
        id observer = [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            [weakSelf scheduleRecovery];
            if ([note.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) weakSelf.cameraActive = NO;
            if (![weakSelf isResolved]) return;
            if ([note.name isEqualToString:UIApplicationDidBecomeActiveNotification]) [CE_SensorCmd open];
            else [CE_SensorCmd close];
        }];
        [self.observers addObject:observer];
    }
}

- (void)configureRecovery:(NSDictionary *)args result:(FlutterResult)result {
    NSString *identifier = [args[@"id"] isKindOfClass:NSString.class] ? args[@"id"] : nil;
    NSString *name = [args[@"name"] isKindOfClass:NSString.class] ? args[@"name"] : nil;
    NSString *context = [args[@"context"] isKindOfClass:NSString.class] ? args[@"context"] : nil;
    if (identifier && !CoolWearRecoveryTargetValid(identifier, name, context)) {
        result([self error:@"COOLWEAR_RECOVERY_TARGET_INVALID" message:@"请重新确认绑定设备"]); return;
    }
    identifier = identifier ? [[NSUUID alloc] initWithUUIDString:identifier].UUIDString : nil;
    if ([self.recoveryID isEqual:identifier] && [self.recoveryContext isEqual:context] &&
        [self.recoveryName isEqual:name]) { [self scheduleRecovery]; result(nil); return; }
    BOOL retireOperation = self.recoveryScanning || self.recoveryConnecting;
    self.recoveryGeneration++;
    self.recoveryScheduled = NO;
    self.recoveryScanning = NO;
    self.recoveryConnecting = NO;
    self.recoveryID = identifier;
    self.recoveryName = identifier ? name : nil;
    self.recoveryContext = identifier ? context : nil;
    // Clearing/replacing a target drains its original SDK request before the
    // router may start a manually selected device or another account.
    if (retireOperation) {
        [self beginCancellation:^(id value) { result(value); }];
    } else result(nil);
    if (identifier) { [self initializeSDK]; [self scheduleRecovery]; }
}

- (void)scheduleRecovery {
    if (!self.recoveryID || self.recoveryScheduled || [self isResolved]) return;
    self.recoveryScheduled = YES;
    NSUInteger generation = self.recoveryGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!weakSelf || generation != weakSelf.recoveryGeneration) return;
        weakSelf.recoveryScheduled = NO;
        [weakSelf attemptRecovery:generation];
    });
}

- (void)attemptRecovery:(NSUInteger)generation {
    if (generation != self.recoveryGeneration || !self.recoveryID || [self isResolved]) return;
    if (self.cancelling || self.target || self.pendingConnect || self.pendingScan ||
        self.product.state != CBManagerStatePoweredOn) { [self scheduleRecovery]; return; }
    self.recoveryScanning = YES;
    [self emit:@"recoveryState" payload:@{@"status": @"waiting", @"deviceId": self.recoveryID}];
    __weak typeof(self) weakSelf = self;
    [self handle:[FlutterMethodCall methodCallWithMethodName:@"scanDevices" arguments:nil] result:^(id response) {
        if (!weakSelf || generation != weakSelf.recoveryGeneration) return;
        weakSelf.recoveryScanning = NO;
        if ([response isKindOfClass:NSArray.class]) for (NSDictionary *device in response) {
            if (!CoolWearRecoveryMatches(device[@"id"], device[@"name"], weakSelf.recoveryID,
                weakSelf.recoveryName, weakSelf.recoveryContext, generation, weakSelf.recoveryGeneration)) continue;
            weakSelf.recoveryConnecting = YES;
            [weakSelf emit:@"recoveryState" payload:@{@"status": @"connecting", @"deviceId": weakSelf.recoveryID}];
            [weakSelf handle:[FlutterMethodCall methodCallWithMethodName:@"connect" arguments:@{@"id": weakSelf.recoveryID}] result:^(id error) {
                if (!weakSelf || generation != weakSelf.recoveryGeneration) return;
                weakSelf.recoveryConnecting = NO;
                if (error) [weakSelf scheduleRecovery];
            }];
            return;
        }
        // A finite scan with no matching advertisement is not the end of the
        // binding. Continue after a pause until cancelled by its owner.
        [weakSelf scheduleRecovery];
    }];
}

- (BOOL)matchesTarget {
    return self.target && !self.cancelling &&
        [self.product.peripheral.identifier isEqual:self.target.identifier] &&
        self.target.state == CBPeripheralStateConnected && CoolWearModel(self.targetName) != nil;
}

- (BOOL)isResolved {
    return [self matchesTarget] && self.product.status == ProductStatus_completed &&
        !self.awaitingInfo && !self.pendingConnect && self.deviceInfo.count > 0 && self.flags.count > 0;
}

- (NSDictionary *)details {
    NSMutableDictionary *value = [@{@"id": self.target.identifier.UUIDString ?: @"",
        @"name": self.targetName ?: @"", @"model": CoolWearModel(self.targetName) ?: @""} mutableCopy];
    NSString *mac = [self.deviceInfo[@"macAddr"] isKindOfClass:NSString.class] ? self.deviceInfo[@"macAddr"] : nil;
    NSRegularExpression *macPattern = [NSRegularExpression regularExpressionWithPattern:@"^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$" options:0 error:nil];
    if (mac && [macPattern firstMatchInString:mac options:0 range:NSMakeRange(0, mac.length)]) value[@"hardwareAddress"] = mac;
    if ([self.deviceInfo[@"version"] isKindOfClass:NSString.class]) value[@"firmwareVersion"] = self.deviceInfo[@"version"];
    if (self.battery) value[@"batteryPercent"] = self.battery;
    if (self.batteryDate) value[@"battery"] = @{@"value": self.battery, @"scale": @100, @"isPercent": @YES,
        @"chargeState": self.charging ? (self.charging.boolValue ? @"charging" : @"normal") : @"unknown",
        @"updatedAt": [NSISO8601DateFormatter.new stringFromDate:self.batteryDate],
        @"chargingUpdatedAt": [NSISO8601DateFormatter.new stringFromDate:self.batteryDate]};
    return value;
}

- (NSDictionary *)capabilities {
    NSMutableDictionary *value = [CoolWearCapabilities(self.flags, [self isResolved]) mutableCopy];
    NSMutableArray *metrics = [value[@"metrics"] mutableCopy];
    if ([self isResolved]) for (NSNumber *type in @[@5, @6]) {
        CoolWearHistoryBatch *batch = self.historyBatches[type];
        if (batch && !batch.malformed && (batch.rows.count || batch.finalSeen)) [metrics addObject:CoolWearHistoryMetric(type.integerValue)];
    }
    value[@"metrics"] = metrics;
    value[@"historyMetrics"] = metrics;
    NSMutableArray *features = [NSMutableArray array];
    // The SDK has no optional find flag. A real stop-command ACK after this
    // exact handshake proves the protocol, not the presence of a vibrator.
    if ([self isResolved] && self.findSupported) [features addObject:@"find_watch"];
    if ([self isResolved] && CoolWearFlag(self.flags, @"gestureSupport")) {
        [features addObjectsFromArray:@[@"camera", @"gesture_control"]];
    }
    // Only an actual type 122 settings response proves call-reminder support.
    if ([self isResolved] && self.callReminder) [features addObject:@"call_reminder"];
    if ([self isResolved] && CoolWearMonitoringSettings(self.monitoringSnapshot, self.flags).count) {
        [features addObject:@"health_monitoring"];
    }
    value[@"features"] = features;
    value[@"integratedFeatures"] = features;
    return value;
}

- (NSDictionary *)callReminderSettings {
    return self.callReminder ? @{@"incomingCall": @(self.callReminder.boolValue),
        @"systemNotificationAuthorized": @(self.target.ancsAuthorized)} : @{};
}

- (void)finishControl:(FlutterError *)error {
    FlutterResult result = self.pendingControl;
    BOOL write = self.controlIsWrite;
    self.pendingControl = nil;
    self.controlExpectedCall = nil;
    self.controlReadbackCall = nil;
    self.controlReadingCall = NO;
    self.controlReadbackAcknowledged = NO;
    self.controlGeneration++;
    if (result) result(error ?: (write ? nil : [self callReminderSettings]));
}

- (void)finishControlReadbackIfReady {
    if (!self.pendingControl || !self.controlReadingCall || !self.controlReadbackAcknowledged || !self.controlReadbackCall) return;
    BOOL matches = !self.controlExpectedCall || [self.controlExpectedCall isEqual:self.controlReadbackCall];
    [self finishControl:matches ? nil : [self error:@"COOLWEAR_CONTROL_NOT_SAVED" message:@"戒指未保存设置，请刷新"]];
}

- (void)requestCallReadback:(NSUInteger)operation connection:(NSUInteger)connection {
    if (operation != self.controlGeneration || connection != self.connectionGeneration || !self.pendingControl || ![self isResolved]) return;
    self.controlReadingCall = YES;
    self.controlReadbackCall = nil;
    self.controlReadbackAcknowledged = NO;
    CE_RequestAllInfoCmd *query = [CE_RequestAllInfoCmd new];
    query.overtime = 8; query.repeatSendTimes = 0;
    __weak typeof(self) weakSelf = self;
    [self.product sendCmdToDevice:query complete:^(NSError *error) {
        CoolWearAfterSDKCallback(^{
            if (operation != weakSelf.controlGeneration || connection != weakSelf.connectionGeneration || !weakSelf.pendingControl) return;
            if (error) [weakSelf finishControl:[weakSelf error:@"COOLWEAR_CONTROL_READ_FAILED" message:@"读取来电提醒失败"]];
            else { weakSelf.controlReadbackAcknowledged = YES; [weakSelf finishControlReadbackIfReady]; }
        });
    }];
}

- (void)sendControl:(NSDictionary *)args action:(BOOL)action write:(BOOL)write operation:(NSUInteger)operation connection:(NSUInteger)connection {
    if (operation != self.controlGeneration || connection != self.connectionGeneration || !self.pendingControl || ![self isResolved]) return;
    __weak typeof(self) weakSelf = self;
    if (self.pendingBattery || self.pendingFind) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [weakSelf sendControl:args action:action write:write operation:operation connection:connection];
        });
        return;
    }
    NSString *feature = args[@"feature"];
    if (!action && !write) { [self requestCallReadback:operation connection:connection]; return; }
    CE_Cmd *command;
    NSNumber *mode;
    if (action) command = [[CE_SendPhotoCmd alloc] initWithOnoff:[args[@"enabled"] boolValue] ? 1 : 0];
    else if ([feature isEqual:@"gesture_control"]) {
        mode = CoolWearGestureMode(args[@"values"][@"mode"]);
        CE_GestureCmd *gesture = [CE_GestureCmd new]; gesture.type = (Control_type)mode.unsignedIntegerValue; command = gesture;
    } else command = [[YD_SyncCallAlarmCmd alloc] initWithOnoff:self.controlExpectedCall.integerValue];
    command.overtime = 8; command.repeatSendTimes = 0; command.noCallback = NO;
    [self.product sendCmdToDevice:command complete:^(NSError *error) {
        CoolWearAfterSDKCallback(^{
            if (operation != weakSelf.controlGeneration || connection != weakSelf.connectionGeneration || !weakSelf.pendingControl) return;
            if (error) { [weakSelf finishControl:[weakSelf error:@"COOLWEAR_CONTROL_FAILED" message:@"戒指未确认指令，请重试"]]; return; }
            if ([feature isEqual:@"call_reminder"]) [weakSelf requestCallReadback:operation connection:connection];
            else {
                if (action) weakSelf.cameraActive = [args[@"enabled"] boolValue] && UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
                else weakSelf.gestureMode = mode;
                [weakSelf finishControl:nil];
            }
        });
    }];
}

- (void)control:(NSDictionary *)args action:(BOOL)action write:(BOOL)write result:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    NSString *feature = [args[@"feature"] isKindOfClass:NSString.class] ? args[@"feature"] : @"";
    BOOL gesture = [feature isEqual:@"gesture_control"], photo = [feature isEqual:@"camera"], call = [feature isEqual:@"call_reminder"];
    if (!(gesture || photo || call) || (photo != action) ||
        ((gesture || photo) && !CoolWearFlag(self.flags, @"gestureSupport")) || (call && !self.callReminder)) {
        result([self error:@"COOLWEAR_FEATURE_UNVERIFIED" message:@"此戒指不支持此功能"]); return;
    }
    NSDictionary *values = [args[@"values"] isKindOfClass:NSDictionary.class] ? args[@"values"] : @{};
    id enabled = action ? args[@"enabled"] : values[@"incomingCall"];
    if ((action || (call && write)) && (![enabled isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID())) {
        result([self error:@"INVALID_SETTING" message:@"开关参数无效"]); return;
    }
    if (gesture && write && !CoolWearGestureMode(values[@"mode"])) { result([self error:@"INVALID_SETTING" message:@"手势模式无效"]); return; }
    if (gesture && !write) { result(self.gestureMode ? @{@"confirmedMode": self.gestureMode} : @{}); return; }
    if (self.pendingControl || self.pendingSync || self.activeMetric || self.pendingMonitoringRead || self.pendingMonitoringWrite || (self.pendingFind && !self.findProbing)) {
        result([self error:@"DEVICE_BUSY" message:@"戒指忙，请稍后重试"]); return;
    }
    if (photo && ![enabled boolValue]) self.cameraActive = NO;
    self.pendingControl = result;
    self.controlIsWrite = write || action;
    self.controlExpectedCall = call && write ? @([enabled boolValue] ? 1 : 0) : nil;
    NSUInteger operation = ++self.controlGeneration, connection = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    // One bounded operation includes a queued optional probe and fresh readback.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 28 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (operation != weakSelf.controlGeneration || connection != weakSelf.connectionGeneration || !weakSelf.pendingControl) return;
        [weakSelf finishControl:[weakSelf error:@"COOLWEAR_CONTROL_TIMEOUT" message:@"戒指未响应，请重试"]];
        [weakSelf beginCancellation:nil]; [weakSelf emit:@"disconnected" payload:@{}]; [weakSelf scheduleRecovery];
    });
    [self sendControl:args action:action write:write operation:operation connection:connection];
}

- (void)finishFind:(FlutterError *)error {
    FlutterResult result = self.pendingFind;
    self.pendingFind = nil;
    self.findProbing = NO;
    self.findGeneration++;
    if (result) result(error);
}

- (void)sendFind:(BOOL)enabled operation:(NSUInteger)operation connection:(NSUInteger)connection {
    if (operation != self.findGeneration || connection != self.connectionGeneration || ![self isResolved] || !self.pendingFind) return;
    __weak typeof(self) weakSelf = self;
    if (self.pendingBattery) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [weakSelf sendFind:enabled operation:operation connection:connection];
        });
        return;
    }
    YD_SyncFindDevCmd *command = [[YD_SyncFindDevCmd alloc] initWithOnoff:enabled ? 1 : 0];
    command.overtime = 8;
    command.repeatSendTimes = 0; // Never repeat a physical reminder automatically.
    command.noCallback = NO; // Require the device response, not just a BLE write.
    [self.product sendCmdToDevice:command complete:^(NSError *error) {
        CoolWearAfterSDKCallback(^{
            if (operation != weakSelf.findGeneration || connection != weakSelf.connectionGeneration || !weakSelf.pendingFind) return;
            weakSelf.findSupported = error == nil;
            [weakSelf finishFind:error ? [weakSelf error:@"COOLWEAR_FIND_FAILED" message:@"查找指令未确认，请重试"] : nil];
            [weakSelf emit:@"capabilitiesUpdated" payload:[weakSelf capabilities]];
        });
    }];
}

- (void)findDevice:(NSDictionary *)args probe:(BOOL)probe result:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    id enabled = args[@"enabled"];
    if (![args[@"feature"] isEqual:@"find_watch"] || ![enabled isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID()) {
        result([self error:@"INVALID_SETTING" message:@"查找参数无效"]); return;
    }
    if (self.pendingControl || self.pendingFind || self.pendingSync || self.activeMetric || self.pendingMonitoringRead || self.pendingMonitoringWrite) {
        result([self error:@"DEVICE_BUSY" message:@"戒指忙，请稍后重试"]); return;
    }
    self.pendingFind = result;
    self.findProbing = probe;
    NSUInteger operation = ++self.findGeneration, connection = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 22 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (operation != weakSelf.findGeneration || connection != weakSelf.connectionGeneration || !weakSelf.pendingFind) return;
        BOOL probing = weakSelf.findProbing;
        [weakSelf finishFind:[weakSelf error:@"COOLWEAR_FIND_TIMEOUT" message:@"戒指未响应查找指令"]];
        weakSelf.findSupported = NO;
        if (probing) {
            // An optional stop probe must not cause endless disconnect/reconnect
            // loops on rings that do not implement find. No physical alert ran.
            [weakSelf.product cleanCmdQueue];
            [weakSelf emit:@"capabilitiesUpdated" payload:[weakSelf capabilities]];
            return;
        }
        // Drain stale commands before any new target or retry can use the SDK.
        [weakSelf beginCancellation:nil];
        [weakSelf emit:@"disconnected" payload:@{}];
        [weakSelf scheduleRecovery];
    });
    [self sendFind:[enabled boolValue] operation:operation connection:connection];
}

- (void)finishMonitoring:(FlutterError *)error {
    FlutterResult read = self.pendingMonitoringRead, write = self.pendingMonitoringWrite;
    self.pendingMonitoringRead = nil;
    self.pendingMonitoringWrite = nil;
    self.monitoringExpected = nil;
    self.monitoringReadbackRequested = NO;
    self.monitoringReadbackAcknowledged = NO;
    self.monitoringReadbackSnapshot = nil;
    self.monitoringGeneration++;
    if (read) read(error ?: CoolWearMonitoringSettings(self.monitoringSnapshot, self.flags));
    if (write) write(error);
}

- (void)finishMonitoringReadbackIfReady {
    if (!self.monitoringReadbackAcknowledged || !self.monitoringReadbackSnapshot ||
        (!self.pendingMonitoringRead && !self.pendingMonitoringWrite)) return;
    NSDictionary *snapshot = self.monitoringReadbackSnapshot;
    BOOL matches = !self.pendingMonitoringWrite || [snapshot isEqual:self.monitoringExpected];
    [self finishMonitoring:matches ? nil : [self error:@"AUTO_MEASURE_WRITE_FAILED" message:@"戒指未保存该设置，请刷新"]];
}

- (void)requestMonitoringReadback:(NSUInteger)operation connection:(NSUInteger)connection {
    if (operation != self.monitoringGeneration || connection != self.connectionGeneration || ![self isResolved]) return;
    self.monitoringReadbackRequested = YES;
    self.monitoringReadbackAcknowledged = NO;
    self.monitoringReadbackSnapshot = nil;
    CE_RequestAllInfoCmd *command = [CE_RequestAllInfoCmd new];
    command.overtime = 8; command.repeatSendTimes = 1;
    __weak typeof(self) weakSelf = self;
    [self.product sendCmdToDevice:command complete:^(NSError *error) {
        CoolWearAfterSDKCallback(^{
            if (operation != weakSelf.monitoringGeneration || connection != weakSelf.connectionGeneration) return;
            if (error) [weakSelf finishMonitoring:[weakSelf error:@"AUTO_MEASURE_READ_FAILED" message:@"读取健康监测设置失败"]];
            else {
                weakSelf.monitoringReadbackAcknowledged = YES;
                [weakSelf finishMonitoringReadbackIfReady];
            }
        });
    }];
}

- (void)monitoring:(NSDictionary *)args write:(BOOL)write result:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    if (self.pendingControl || (self.pendingFind && !self.findProbing) || self.pendingSync || self.activeMetric || self.pendingMonitoringRead || self.pendingMonitoringWrite) {
        result([self error:@"CONNECT_BUSY" message:@"戒指忙，请稍后重试"]); return;
    }
    NSDictionary *expected = nil;
    if (write) {
        NSString *type = [args[@"type"] isKindOfClass:NSString.class] ? args[@"type"] : @"";
        id enabled = args[@"enabled"];
        if (![enabled isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID()) {
            result([self error:@"INVALID_SETTING" message:@"开关参数无效"]); return;
        }
        expected = CoolWearMonitoringChange(self.monitoringSnapshot, self.flags, type, [enabled boolValue]);
        if (!expected) { result([self error:@"READ_REQUIRED" message:@"请先刷新戒指支持的监测设置"]); return; }
    }
    NSUInteger operation = ++self.monitoringGeneration, connection = self.connectionGeneration;
    self.monitoringExpected = expected;
    if (write) self.pendingMonitoringWrite = result;
    else self.pendingMonitoringRead = result;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (write ? 48 : 28) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (operation == weakSelf.monitoringGeneration && connection == weakSelf.connectionGeneration)
            [weakSelf finishMonitoring:[weakSelf error:@"AUTO_MEASURE_READ_TIMEOUT" message:@"健康监测设置未确认，请刷新"]];
    });
    [self sendMonitoring:write operation:operation connection:connection];
}

- (void)sendMonitoring:(BOOL)write operation:(NSUInteger)operation connection:(NSUInteger)connection {
    if (operation != self.monitoringGeneration || connection != self.connectionGeneration || ![self isResolved]) return;
    __weak typeof(self) weakSelf = self;
    if (self.pendingBattery || self.pendingFind) {
        // Reserve the settings operation before waiting. Future battery polls,
        // sync and measurement cannot steal the command queue; cancellation and
        // the bounded operation timeout invalidate this deferred send.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [weakSelf sendMonitoring:write operation:operation connection:connection];
        });
        return;
    }
    if (!write) { [self requestMonitoringReadback:operation connection:connection]; return; }
    NSDictionary *expected = self.monitoringExpected;
    YD_SyncAutoHeartCmd *command = [YD_SyncAutoHeartCmd new];
    command.onoff = [expected[@"onoff"] unsignedCharValue];
    command.hr24hOnoff = [expected[@"hr24hOnoff"] unsignedCharValue];
    command.O2_onoff = [expected[@"oxOnOff"] unsignedCharValue];
    command.time = [expected[@"time"] unsignedCharValue];
    command.overtime = 8; command.repeatSendTimes = 1;
    [self.product sendCmdToDevice:command complete:^(NSError *error) {
        CoolWearAfterSDKCallback(^{
            if (operation != weakSelf.monitoringGeneration || connection != weakSelf.connectionGeneration) return;
            if (error) [weakSelf finishMonitoring:[weakSelf error:@"AUTO_MEASURE_WRITE_FAILED" message:@"健康监测设置保存失败"]];
            else [weakSelf requestMonitoringReadback:operation connection:connection]; // ACK alone is not saved state.
        });
    }];
}

- (NSDictionary *)syncSnapshot {
    NSMutableDictionary *statuses = [NSMutableDictionary dictionary];
    NSMutableSet *metrics = [NSMutableSet setWithArray:[self capabilities][@"historyMetrics"]];
    // A malformed observed batch must remain visible in the result even if
    // it cannot enable a current device capability.
    for (NSNumber *type in self.syncBatches) {
        NSString *metric = CoolWearHistoryMetric(type.integerValue);
        if (metric) [metrics addObject:metric];
    }
    for (NSString *metric in metrics) {
        CoolWearHistoryBatch *batch = nil;
        for (NSNumber *type in self.syncBatches) if ([CoolWearHistoryMetric(type.integerValue) isEqual:metric]) batch = self.syncBatches[type];
        statuses[metric] = batch ? [batch status] : @"not_received";
        if ([metric isEqual:@"sleep"] && batch.rows.count && CoolWearClosedSleepSummaries(batch.rows.allValues, NSDate.date).count == 0) statuses[metric] = @"partial";
    }
    return @{@"records": self.syncRecords.allValues, @"statuses": statuses};
}

- (void)finishSync {
    FlutterResult result = self.pendingSync;
    self.pendingSync = nil;
    if (result) result([self syncSnapshot]);
}

- (void)finalizeSleepHistory {
    [self finalizeSleepBatch:self.syncBatches[@6] syncRecords:self.syncRecords];
}

- (void)schedulePassiveSleepHistory {
    if (self.passiveSleepScheduled || !self.dataDeliveryReady || ![self isResolved] || !self.historyBatches[@6]) return;
    self.passiveSleepScheduled = YES;
    NSUInteger generation = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!weakSelf || generation != weakSelf.connectionGeneration) return;
        weakSelf.passiveSleepScheduled = NO;
        // This only processes real packets already received. No extra BLE
        // command or long-running sync lock may block manual measurements.
        if (weakSelf.dataDeliveryReady) [weakSelf finalizeSleepBatch:weakSelf.historyBatches[@6] syncRecords:nil];
    });
}

- (void)finalizeSleepBatch:(CoolWearHistoryBatch *)batch syncRecords:(NSMutableDictionary *)records {
    // Do not infer stage durations across a packet gap or publish an interim
    // summary as a second observation. Only the settled, validated batch may
    // update a stable session-end record.
    if (![[batch status] isEqual:@"complete"] || ![self isResolved]) return;
    for (NSDictionary *row in batch.rows.allValues) {
        if (!CoolWearSampleDate(row[@"SleepStartTime"], NSDate.date) || !CoolWearUnsigned(row[@"SleepType"], 255)) {
            batch.malformed = YES;
            return;
        }
    }
    for (NSDictionary *sample in CoolWearClosedSleepSummaries(batch.rows.allValues, NSDate.date)) {
        NSDate *date = CoolWearSampleDate(sample[@"time"], NSDate.date);
        if (!date) continue;
        NSDictionary *record = [self record:@"sleep" values:sample[@"values"] date:date origin:@"watch_history"];
        if (records) records[record[@"id"]] = record;
        if ([self.historyRecords[record[@"id"]] isEqual:record]) continue;
        self.historyRecords[record[@"id"]] = record;
        [self emitPassiveRecord:record];
    }
}

- (void)readBattery:(FlutterResult)result {
    if (![self isResolved]) { result(nil); return; }
    if (self.pendingControl || self.pendingFind || self.pendingBattery || self.pendingSync || self.activeMetric || self.pendingMonitoringRead || self.pendingMonitoringWrite) { result([self details]); return; }
    self.pendingBattery = result;
    NSUInteger generation = self.connectionGeneration, read = ++self.batteryGeneration;
    CE_RequestBatteryCmd *cmd = [CE_RequestBatteryCmd new];
    cmd.overtime = 6; cmd.repeatSendTimes = 0;
    __weak typeof(self) weakSelf = self;
    [self.product sendCmdToDevice:cmd complete:^(NSError *error) {
        CoolWearOnMain(^{
            if (!error || generation != weakSelf.connectionGeneration || read != weakSelf.batteryGeneration) return;
            FlutterResult completion = weakSelf.pendingBattery; weakSelf.pendingBattery = nil;
            if (completion) completion([weakSelf details]);
        });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (generation != weakSelf.connectionGeneration || read != weakSelf.batteryGeneration) return;
        FlutterResult completion = weakSelf.pendingBattery; weakSelf.pendingBattery = nil;
        if (completion) completion([weakSelf details]);
    });
}

- (void)syncHistory:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    if (self.pendingControl || self.pendingFind || self.pendingSync || self.pendingBattery || self.activeMetric || self.pendingMonitoringRead || self.pendingMonitoringWrite) { result([self error:@"DEVICE_BUSY" message:@"设备忙，请稍后重试"]); return; }
    self.pendingSync = result;
    [self.syncBatches removeAllObjects]; [self.syncRecords removeAllObjects];
    if (!self.historySnapshotDelivered) {
        [self.syncBatches addEntriesFromDictionary:self.historyBatches];
        [self.syncRecords addEntriesFromDictionary:self.historyRecords];
        self.historySnapshotDelivered = YES;
    }
    NSUInteger generation = self.connectionGeneration, sync = ++self.syncGeneration;
    [CE_SensorCmd open];
    CE_SyncTimeCmd *cmd = [[CE_SyncTimeCmd alloc] initWithAbsTime:NSDate.date.timeIntervalSince1970
        offset:[NSTimeZone.localTimeZone secondsFromGMT] format:1 mdFormat:0];
    cmd.overtime = 6; cmd.repeatSendTimes = 0;
    // The vendor pushes history automatically; this ACK is never completion.
    [self.product sendCmdToDevice:cmd complete:^(NSError *error) {}];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (generation == weakSelf.connectionGeneration && sync == weakSelf.syncGeneration) {
            [weakSelf finalizeSleepHistory];
            [weakSelf finishSync];
        }
    });
}

- (void)receiveScan:(id)values {
    if (!self.pendingScan || ![values isKindOfClass:NSArray.class]) return;
    for (id value in values) {
        if (![value isKindOfClass:SearchPeripheral.class]) continue;
        SearchPeripheral *item = value;
        if (!item.peripheral || !CoolWearModel(item.name)) continue;
        NSString *identifier = item.peripheral.identifier.UUIDString;
        BOOL fresh = !self.scanned[identifier];
        self.scanned[identifier] = item;
        if (fresh) {
            NSString *service = self.product.sid;
            NSArray *services = item.advertisementData[CBAdvertisementDataServiceUUIDsKey];
            if ([services containsObject:[CBUUID UUIDWithString:@"F618"]]) service = @"F618";
            else if ([services containsObject:[CBUUID UUIDWithString:@"F818"]]) service = @"F818";
            self.scanServices[identifier] = service;
        }
        if (fresh) [self emit:@"scanDevice" payload:[self scanPayload:item]];
        if (self.recoveryScanning && CoolWearRecoveryMatches(identifier, item.name,
            self.recoveryID, self.recoveryName, self.recoveryContext,
            self.recoveryGeneration, self.recoveryGeneration)) { [self finishScan]; return; }
    }
}

- (NSDictionary *)scanPayload:(SearchPeripheral *)item {
    return @{@"id": item.peripheral.identifier.UUIDString, @"name": [item.name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],
        @"model": CoolWearModel(item.name), @"rssi": item.rssi ?: @0};
}

- (void)finishScan {
    self.scanGeneration++;
    [self.product stopScan];
    FlutterResult result = self.pendingScan;
    self.pendingScan = nil;
    if (!result) return;
    NSMutableArray *values = [NSMutableArray array];
    for (SearchPeripheral *item in self.scanned.allValues) [values addObject:[self scanPayload:item]];
    result(values);
}

- (void)startScan:(FlutterResult)result {
    [self initializeSDK];
    if (self.cancelling || self.pendingConnect || self.target) { result([self error:@"CONNECT_BUSY" message:@"请先结束当前 CoolWear 戒指连接再搜索"]); return; }
    if (self.product.state == CBManagerStateUnauthorized) { result([self error:@"BLUETOOTH_PERMISSION_REQUIRED" message:@"请在系统设置中允许 Say Ring 使用蓝牙"]); return; }
    if (self.product.state == CBManagerStatePoweredOff) { result([self error:@"BLUETOOTH_OFF" message:@"请先打开蓝牙"]); return; }
    [self finishScan];
    [self.scanned removeAllObjects];
    [self.scanServices removeAllObjects];
    self.pendingScan = result;
    NSUInteger generation = ++self.scanGeneration;
    [self startScanWhenReady:generation attempt:0];
}

- (void)startScanWhenReady:(NSUInteger)generation attempt:(NSUInteger)attempt {
    if (!self.pendingScan || generation != self.scanGeneration) return;
    if (self.product.state != CBManagerStatePoweredOn) {
        if (attempt >= 10 || self.product.state == CBManagerStatePoweredOff || self.product.state == CBManagerStateUnauthorized || self.product.state == CBManagerStateUnsupported) {
            FlutterResult result = self.pendingScan;
            self.pendingScan = nil;
            self.scanGeneration++;
            result([self error:@"BLUETOOTH_UNAVAILABLE" message:@"蓝牙尚未就绪，请检查系统蓝牙和权限后重试"]);
            return;
        }
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(), ^{
            [weakSelf startScanWhenReady:generation attempt:attempt + 1];
        });
        return;
    }
    // Both service IDs are declared by CEProductK6. Keep the vendor's real
    // SearchPeripheral parsing; don't fabricate candidates from arbitrary BLE.
    self.product.sid = @"F618";
    [self.product startScan];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!weakSelf.pendingScan || generation != weakSelf.scanGeneration) return;
        [weakSelf.product stopScan];
        weakSelf.product.sid = @"F818";
        [weakSelf.product startScan];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (generation == weakSelf.scanGeneration) [weakSelf finishScan];
    });
}

- (void)connect:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *identifier = [arguments[@"id"] isKindOfClass:NSString.class] ? arguments[@"id"] : @"";
    SearchPeripheral *item = self.scanned[identifier];
    if (!item || ![item.peripheral.identifier.UUIDString isEqualToString:identifier] || !CoolWearModel(item.name)) {
        result([self error:@"COOLWEAR_DEVICE_UNVERIFIED" message:@"请重新搜索并选择 CoolWear 戒指"]); return;
    }
    if (self.target || self.pendingConnect || self.cancelling) { result([self error:@"CONNECT_BUSY" message:@"请先结束当前戒指连接"]); return; }
    [self finishScan];
    [self disableVendorRecovery];
    self.connectionGeneration++;
    NSUInteger generation = self.connectionGeneration;
    self.target = item.peripheral;
    self.targetName = item.name;
    self.deviceInfo = nil;
    self.flags = nil;
    self.battery = nil;
    self.batteryDate = nil;
    self.charging = nil;
    self.awaitingInfo = NO;
    self.dataDeliveryReady = NO;
    self.monitoringSnapshot = nil;
    self.findSupported = NO;
    self.cameraActive = NO;
    self.gestureMode = nil;
    self.callReminder = nil;
    [self.pendingPassiveRecords removeAllObjects];
    [self.historyBatches removeAllObjects];
    [self.historyRecords removeAllObjects];
    [self.syncBatches removeAllObjects]; [self.syncRecords removeAllObjects];
    self.historySnapshotDelivered = NO;
    self.pendingConnect = result;
    self.product.searchPeripheral = item;
    self.product.sid = self.scanServices[identifier] ?: @"F618";
    [self.product connect:item.peripheral];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (generation == weakSelf.connectionGeneration && weakSelf.pendingConnect)
            [weakSelf failConnection:@"COOLWEAR_CONNECT_TIMEOUT" message:@"戒指握手或能力读取超时，请靠近手机后重试"];
    });
}

- (void)receiveStatus:(ProductStatus)status {
    [self disableVendorRecovery];
    if (self.cancelling) { [self checkCancellation]; return; }
    if (!self.target) return;
    if (status == ProductStatus_powerOff || status == ProductStatus_disconnected) {
        [self failConnection:@"COOLWEAR_DISCONNECTED" message:@"戒指连接已断开"]; return;
    }
    if (status != ProductStatus_completed || ![self matchesTarget] || !self.pendingConnect || self.awaitingInfo) return;
    self.awaitingInfo = YES;
    [CE_SensorCmd open];
    NSUInteger generation = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    // Request actual metadata and mixed capability data, not just a BLE link.
    CE_SyncTimeCmd *time = [[CE_SyncTimeCmd alloc] initWithAbsTime:NSDate.date.timeIntervalSince1970
        offset:[NSTimeZone.localTimeZone secondsFromGMT] format:1 mdFormat:0];
    for (CE_Cmd *cmd in @[time, [CE_RequestDevInfoCmd new], [CE_RequestAllInfoCmd new]]) {
        cmd.overtime = 8;
        cmd.repeatSendTimes = 0;
        [self.product sendCmdToDevice:cmd complete:^(NSError *error) {
            CoolWearOnMain(^{
                if (error && generation == weakSelf.connectionGeneration && weakSelf.pendingConnect)
                    [weakSelf failConnection:@"COOLWEAR_HANDSHAKE_FAILED" message:@"戒指未返回有效设备信息，请重试"];
            });
        }];
    }
}

- (void)finishHandshakeIfReady {
    if (!self.pendingConnect || !self.awaitingInfo || ![self matchesTarget] || !self.deviceInfo.count || !self.flags.count) return;
    self.awaitingInfo = NO;
    FlutterResult result = self.pendingConnect;
    self.pendingConnect = nil;
    [self emit:self.recoveryConnecting ? @"reconnected" : @"connected" payload:[self details]];
    [self emit:@"capabilities" payload:[self capabilities]];
    result(nil);
    NSUInteger connection = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    CoolWearAfterSDKCallback(^{
        if (connection != weakSelf.connectionGeneration || ![weakSelf isResolved]) return;
        // A harmless stop probe leaves no ringing active and never chooses a target.
        [weakSelf findDevice:@{@"feature": @"find_watch", @"enabled": @NO} probe:YES result:^(id response) {}];
    });
}

- (void)receiveData:(NSDictionary *)info depth:(NSUInteger)depth measurement:(NSUInteger)measurement {
    if (depth > 3 || ![info isKindOfClass:NSDictionary.class] || ![self matchesTarget] ||
        self.product.status != ProductStatus_completed ||
        ([info[@"error_msg"] isKindOfClass:NSString.class] && [info[@"error_msg"] length] > 0)) return;
    NSNumber *type = CoolWearUnsigned(info[@"DataType"], 255);
    if (!type) return;
    id data = info[@"Data"];
    if (type.integerValue == DATA_TYPE_PHOTOGRAPH_ONOFF) {
        if (CoolWearCameraShutter(data, self.cameraActive, [self isResolved], UIApplication.sharedApplication.applicationState == UIApplicationStateActive))
            [self emit:@"cameraShutter" payload:@{@"deviceId": self.target.identifier.UUIDString}];
        return;
    }
    if (type.integerValue == DATA_TYPE_CALL_ALARM) {
        NSNumber *value = CoolWearCallReminder(data);
        if (value) {
            self.callReminder = value;
            if (self.controlReadingCall && self.pendingControl) { self.controlReadbackCall = value; [self finishControlReadbackIfReady]; }
            if ([self isResolved]) [self emit:@"capabilitiesUpdated" payload:[self capabilities]];
        }
        return;
    }
    if (type.integerValue == DATA_TYPE_HEART_AUTO_SWITCH) {
        NSDictionary *snapshot = CoolWearMonitoringSnapshot(data);
        if (snapshot) {
            self.monitoringSnapshot = snapshot;
            if ([self isResolved]) [self emit:@"capabilitiesUpdated" payload:[self capabilities]];
            if (self.monitoringReadbackRequested && (self.pendingMonitoringRead || self.pendingMonitoringWrite)) {
                self.monitoringReadbackSnapshot = snapshot;
                [self finishMonitoringReadbackIfReady];
            }
        }
        return;
    }
    if (type.integerValue == DATA_TYPE_DEV_SYNC) {
        // This is a mixed-data envelope, NOT a history-completion marker.
        if ([data isKindOfClass:NSArray.class]) for (id child in data) [self receiveData:child depth:depth + 1 measurement:measurement];
        return;
    }
    // History can be pushed while metadata is still being read. Retain only
    // validated records for this exact connection, then deliver after Dart
    // has installed the account-owned connected-device session.
    NSString *historyKey = CoolWearHistoryKey(type.integerValue);
    if (historyKey) {
        // The SDK can push mixed history on connection. Do not retain or
        // publish physiological child packets in this iOS release.
        if (!SRActivitySleepMetricAllowed(CoolWearHistoryMetric(type.integerValue))) return;
        CoolWearHistoryBatch *batch = self.historyBatches[type];
        if (!batch) self.historyBatches[type] = batch = [CoolWearHistoryBatch new];
        NSArray *packets = [data isKindOfClass:NSArray.class] ? data : @[data ?: NSNull.null];
        if (packets.count > 512) { batch.malformed = YES; return; }
        for (id packet in packets) [batch accept:packet key:historyKey];
        if (self.pendingSync) {
            CoolWearHistoryBatch *syncBatch = self.syncBatches[type];
            if (!syncBatch) self.syncBatches[type] = syncBatch = [CoolWearHistoryBatch new];
            if (syncBatch != batch) for (id packet in packets) [syncBatch accept:packet key:historyKey];
        }
        NSString *metric = CoolWearHistoryMetric(type.integerValue);
        // Sleep is finalized once the bounded sync window has settled.
        NSArray *samples = type.integerValue == 6 ? @[] : batch.rows.allValues;
        for (NSDictionary *sample in samples) {
            NSDictionary *values = type.integerValue == 6 ? sample[@"values"] : CoolWearHistoryValues(type.integerValue, sample);
            NSDate *date = CoolWearSampleDate(sample[type.integerValue == 5 ? @"startSecs" : @"time"], NSDate.date);
            if (!values || !date) { batch.malformed = YES; self.syncBatches[type].malformed = YES; continue; }
            NSDictionary *record = [self record:metric values:values date:date origin:@"watch_history"];
            if (self.pendingSync) self.syncRecords[record[@"id"]] = record;
            if (self.historyRecords[record[@"id"]]) continue;
            if (self.historyRecords.count >= 16384) { batch.malformed = YES; break; }
            self.historyRecords[record[@"id"]] = record;
            if ([self isResolved] && self.dataDeliveryReady) [self emitPassiveRecord:record];
            else self.pendingPassiveRecords[record[@"id"]] = record;
        }
        if ([self isResolved]) [self emit:@"capabilitiesUpdated" payload:[self capabilities]];
        if (type.integerValue == 6) [self schedulePassiveSleepHistory];
        // A final packet may precede earlier packets. Collect the complete
        // bounded window before evaluating each metric; never end on type 9
        // or the first apparently complete batch.
        return;
    }
    if (type.integerValue == DATA_TYPE_REAL_HRV_METRICS) {
        if (![self isResolved] || measurement != self.measurementGeneration || self.emittedMeasurement ||
            ![self.activeMetric isEqualToString:@"hrv"]) return;
        for (NSDictionary *sample in CoolWearMetricSamples(data, @"hrvMetricsInfos")) {
            NSDictionary *values = CoolWearRriHrvValues(sample);
            NSDate *date = CoolWearSampleDate(sample[@"time"], NSDate.date);
            if (!values || !date || [date timeIntervalSinceDate:self.measurementStart] < -2) continue;
            self.emittedMeasurement = YES;
            [self emit:@"healthRecord" payload:[self record:@"hrv" values:values date:date origin:@"app_measurement"]];
            break;
        }
        return;
    }
    if (![data isKindOfClass:NSDictionary.class]) return;
    if (self.pendingConnect && self.awaitingInfo && type.integerValue == DATA_TYPE_DEVINFO) {
        if ([data[@"version"] isKindOfClass:NSString.class] && [data[@"version"] length] > 0 && CoolWearNumber(data[@"hardware_id"])) self.deviceInfo = data;
    } else if (self.pendingConnect && self.awaitingInfo && type.integerValue == DATA_TYPE_FUNCTION_CONTROL) {
        if (CoolWearHasKnownCapabilities(data)) self.flags = data;
    } else if (type.integerValue == DATA_TYPE_BATTERY_INFO) {
        NSNumber *value = CoolWearNumber(data[@"battery_capacity"]);
        if (value && value.doubleValue >= 0 && value.doubleValue <= 100) {
            self.battery = value;
            self.batteryDate = NSDate.date;
            NSNumber *charger = CoolWearNumber(data[@"charger_status"]);
            self.charging = CoolWearUnsigned(charger, 1);
            if ([self isResolved]) [self emit:@"deviceDetails" payload:[self details]];
            FlutterResult result = self.pendingBattery; self.pendingBattery = nil;
            if (result) result([self details]);
        }
    } else if ([self isResolved] && measurement == self.measurementGeneration && !self.emittedMeasurement) {
        NSString *metric = type.integerValue == DATA_TYPE_REAL_HEART ? @"heart_rate" : type.integerValue == DATA_TYPE_REAL_O2 ? @"blood_oxygen" : nil;
        if (metric && [metric isEqualToString:self.activeMetric]) {
            id values = data[[metric isEqualToString:@"heart_rate"] ? @"heartInfos" : @"data"];
            if ([values isKindOfClass:NSArray.class]) for (id sample in values) {
                if (![sample isKindOfClass:NSDictionary.class]) continue;
                NSNumber *value = CoolWearMeasurementValue(metric, sample);
                NSNumber *time = CoolWearNumber(sample[@"time"]);
                NSDate *date = time && time.doubleValue > 0 ? [NSDate dateWithTimeIntervalSince1970:time.doubleValue] : nil;
                // Require a fresh real SDK timestamp; no replacement health
                // reading or historical sample is labeled as a live result.
                if (!value || !date || [date timeIntervalSinceDate:self.measurementStart] < -2 || [date timeIntervalSinceNow] > 120) continue;
                self.emittedMeasurement = YES;
                NSString *timestamp = [NSISO8601DateFormatter.new stringFromDate:date];
                NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%@", self.target.identifier.UUIDString, metric, timestamp, value];
                unsigned char digest[CC_SHA256_DIGEST_LENGTH];
                NSData *bytes = [key dataUsingEncoding:NSUTF8StringEncoding];
                CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
                NSMutableString *identifier = [NSMutableString string];
                for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [identifier appendFormat:@"%02x", digest[i]];
                NSInteger minutes = [NSTimeZone.localTimeZone secondsFromGMTForDate:date] / 60;
                NSString *offset = [NSString stringWithFormat:@"%@%02ld:%02ld", minutes < 0 ? @"-" : @"+", (long)labs(minutes) / 60, (long)labs(minutes) % 60];
                [self emit:@"healthRecord" payload:@{@"id": identifier, @"type": metric, @"values": @{@"value": value},
                    @"unit": [metric isEqualToString:@"heart_rate"] ? @"bpm" : @"%", @"measuredAt": timestamp, @"timezone": offset,
                    @"deviceId": [@"coolwear:" stringByAppendingString:self.target.identifier.UUIDString], @"firmwareVersion": self.deviceInfo[@"version"] ?: @"",
                    @"quality": @"device_reported", @"source": @"wearable", @"origin": @"app_measurement", @"rawVersion": @1,
                    @"sourceModel": CoolWearModel(self.targetName), @"sourceVendor": @"coolwear", @"sourceDeviceCategory": @"ring", @"sourceApp": @"say-ring"}];
                break;
            }
        }
    }
    [self finishHandshakeIfReady];
}

- (NSDictionary *)record:(NSString *)metric values:(NSDictionary *)values date:(NSDate *)date origin:(NSString *)origin {
    NSString *timestamp = [NSISO8601DateFormatter.new stringFromDate:date];
    NSMutableString *key = [NSMutableString stringWithFormat:@"coolwear-v2|%@|%@|%@|%@", self.target.identifier.UUIDString, metric, timestamp, origin];
    if (![metric isEqual:@"sleep"]) for (NSString *field in [[values allKeys] sortedArrayUsingSelector:@selector(compare:)]) [key appendFormat:@"|%@=%@", field, values[field]];
    NSData *bytes = [key dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
    NSMutableString *identifier = [NSMutableString string];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [identifier appendFormat:@"%02x", digest[i]];
    NSInteger minutes = [NSTimeZone.localTimeZone secondsFromGMTForDate:date] / 60;
    NSString *offset = [NSString stringWithFormat:@"%@%02ld:%02ld", minutes < 0 ? @"-" : @"+", (long)labs(minutes) / 60, (long)labs(minutes) % 60];
    return @{@"id": identifier, @"type": metric, @"values": values,
        @"unit": @{@"heart_rate":@"bpm", @"blood_oxygen":@"%", @"hrv":@"ms", @"body_temperature":@"℃", @"steps":@"steps", @"sleep":@"h"}[metric] ?: @"", @"measuredAt": timestamp, @"timezone": offset,
        @"deviceId": [@"coolwear:" stringByAppendingString:self.target.identifier.UUIDString], @"firmwareVersion": self.deviceInfo[@"version"] ?: @"",
        @"quality": @"device_reported", @"source": @"wearable", @"origin": origin, @"rawVersion": @2,
        @"sourceModel": CoolWearModel(self.targetName), @"sourceVendor": @"coolwear", @"sourceDeviceCategory": @"ring", @"sourceApp": @"say-ring"};
}

- (void)emitPassiveRecord:(NSDictionary *)record {
    if (![self isResolved] || !self.dataDeliveryReady || ![[self capabilities][@"historyMetrics"] containsObject:record[@"type"]]) return;
    NSMutableDictionary *resolved = [record mutableCopy];
    resolved[@"firmwareVersion"] = self.deviceInfo[@"version"] ?: @"";
    [self emit:@"healthRecord" payload:resolved];
}

- (void)enableDataDelivery {
    if (![self isResolved]) return;
    self.dataDeliveryReady = YES;
    NSArray *records = self.pendingPassiveRecords.allValues;
    [self.pendingPassiveRecords removeAllObjects];
    for (NSDictionary *record in records) [self emitPassiveRecord:record];
    [self schedulePassiveSleepHistory];
}

- (void)failConnection:(NSString *)code message:(NSString *)message {
    FlutterResult connect = self.pendingConnect;
    self.pendingConnect = nil;
    if (connect) connect([self error:code message:message]);
    [self beginCancellation:nil];
}

- (void)beginCancellation:(FlutterResult)result {
    [self finishControl:[self error:@"CONNECT_CANCELLED" message:@"连接已取消"]];
    self.cameraActive = NO;
    self.gestureMode = nil;
    self.callReminder = nil;
    [self finishScan];
    self.connectionGeneration++;
    [self finishFind:[self error:@"CONNECT_CANCELLED" message:@"连接已取消"]];
    self.findSupported = NO;
    [self finishMonitoring:[self error:@"CONNECT_CANCELLED" message:@"连接已取消"]];
    self.monitoringSnapshot = nil;
    self.syncGeneration++;
    self.batteryGeneration++;
    [self finishSync];
    FlutterResult batteryResult = self.pendingBattery; self.pendingBattery = nil;
    if (batteryResult) batteryResult(nil);
    self.measurementGeneration++;
    self.activeMetric = nil;
    self.dataDeliveryReady = NO;
    self.passiveSleepScheduled = NO;
    [self.pendingPassiveRecords removeAllObjects];
    [self.historyBatches removeAllObjects];
    [self.historyRecords removeAllObjects];
    self.awaitingInfo = NO;
    self.flags = nil;
    self.deviceInfo = nil;
    self.pendingDisconnect = result;
    self.cancelling = YES;
    self.cancellationChecks = 0;
    FlutterResult connect = self.pendingConnect;
    self.pendingConnect = nil;
    if (connect) connect([self error:@"CONNECT_CANCELLED" message:@"连接已取消"]);
    FlutterResult measurement = self.pendingMeasurement;
    self.pendingMeasurement = nil;
    if (measurement) measurement([self error:@"MEASUREMENT_CANCELLED" message:@"测量已取消"]);
    [self disableVendorRecovery];
    [self.product cleanCmdQueue];
    [self.product.connect cancel];
    [self checkCancellation];
    NSUInteger generation = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (generation != weakSelf.connectionGeneration || !weakSelf.pendingDisconnect) return;
        FlutterResult result = weakSelf.pendingDisconnect;
        weakSelf.pendingDisconnect = nil;
        result([weakSelf error:@"COOLWEAR_DISCONNECT_TIMEOUT" message:@"SDK 尚未确认断开，请稍候再试"]);
        // Keep the cancellation barrier, never let another target race it.
    });
}

- (void)checkCancellation {
    if (!self.cancelling) return;
    if ((!self.product.connect.peripheral || self.product.connect.peripheral.state == CBPeripheralStateDisconnected) &&
        (!self.target || self.target.state == CBPeripheralStateDisconnected)) {
        self.cancelling = NO;
        self.target = nil;
        self.targetName = nil;
        [self emit:@"disconnected" payload:@{}];
        FlutterResult result = self.pendingDisconnect;
        self.pendingDisconnect = nil;
        if (result) result(nil);
        [self scheduleRecovery];
        return;
    }
    if (++self.cancellationChecks > 48) return; // Later SDK status may settle it.
    NSUInteger generation = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(), ^{
        if (generation == weakSelf.connectionGeneration) [weakSelf checkCancellation];
    });
}

- (void)measurement:(NSString *)metric enabled:(BOOL)enabled result:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    if (self.pendingMeasurement) { result([self error:@"MEASUREMENT_BUSY" message:@"测量指令正在处理"]); return; }
    if (self.pendingControl || self.pendingFind || self.pendingSync || self.pendingBattery || self.pendingMonitoringRead || self.pendingMonitoringWrite) { result([self error:@"DEVICE_BUSY" message:@"设备忙，请稍后重试"]); return; }
    NSArray *manual = CoolWearCapabilities(self.flags, YES)[@"manualMetrics"];
    if (![manual containsObject:metric]) { result([self error:@"COOLWEAR_FEATURE_UNVERIFIED" message:@"此戒指未确认支持这项 iOS 测量"]); return; }
    if (enabled && self.activeMetric) { result([self error:@"MEASUREMENT_BUSY" message:@"请先结束当前测量"]); return; }
    if (!enabled && ![metric isEqualToString:self.activeMetric]) { result(nil); return; }
    self.measurementGeneration++;
    NSUInteger measurement = self.measurementGeneration;
    NSUInteger generation = self.connectionGeneration;
    self.activeMetric = enabled ? metric : nil;
    self.emittedMeasurement = NO;
    self.measurementStart = enabled ? NSDate.date : nil;
    self.pendingMeasurement = result;
    CE_Cmd *command;
    if ([metric isEqualToString:@"heart_rate"]) {
        CE_SyncHeartRateCmd *cmd = [CE_SyncHeartRateCmd new]; cmd.status = enabled ? 1 : 0; command = cmd;
    } else if ([metric isEqualToString:@"hrv"]) {
        CE_SyncRRIHRVCmd *cmd = [CE_SyncRRIHRVCmd new]; cmd.status = enabled ? 1 : 0; command = cmd;
    } else {
        CE_SyncHeartO2Cmd *cmd = [CE_SyncHeartO2Cmd new]; cmd.status = enabled ? 1 : 0; command = cmd;
    }
    command.overtime = 8;
    command.repeatSendTimes = 0;
    __weak typeof(self) weakSelf = self;
    [self.product sendCmdToDevice:command complete:^(NSError *error) {
        CoolWearOnMain(^{
            if (generation != weakSelf.connectionGeneration || measurement != weakSelf.measurementGeneration || !weakSelf.pendingMeasurement) return;
            FlutterResult completion = weakSelf.pendingMeasurement;
            weakSelf.pendingMeasurement = nil;
            if (error) {
                weakSelf.activeMetric = nil;
                weakSelf.measurementGeneration++;
                completion([weakSelf error:@"COOLWEAR_MEASUREMENT_FAILED" message:@"戒指测量指令未完成，请重试"]);
            } else completion(nil); // ACK is not a health reading.
        });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (generation != weakSelf.connectionGeneration || measurement != weakSelf.measurementGeneration || !weakSelf.pendingMeasurement) return;
        FlutterResult completion = weakSelf.pendingMeasurement;
        weakSelf.pendingMeasurement = nil;
        [weakSelf beginCancellation:nil]; // Drain the SDK before another attempt.
        completion([weakSelf error:@"COOLWEAR_MEASUREMENT_TIMEOUT" message:@"戒指测量指令超时，请重新连接后重试"]);
    });
}

- (void)handle:(FlutterMethodCall *)call result:(FlutterResult)result {
    result = CoolWearCompleteOnce(result);
    NSDictionary *args = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};
    if (!SRActivitySleepCommandAllowed(call.method, args)) {
        result([self error:@"FEATURE_UNAVAILABLE" message:@"此版本仅提供活动与睡眠记录"]); return;
    }
    FlutterResult completion = result;
    result = ^(id value) { completion(SRActivitySleepResult(call.method, value)); };
    @try {
        if ([call.method isEqualToString:@"configureRecoveryTarget"]) [self configureRecovery:args result:result];
        else if ([call.method isEqualToString:@"scanDevices"]) [self startScan:result];
        else if ([call.method isEqualToString:@"stopScan"]) { [self finishScan]; result(nil); }
        else if ([call.method isEqualToString:@"connect"]) [self connect:args result:result];
        else if ([call.method isEqualToString:@"disconnect"]) {
            // Explicit disconnect is also used by unbind/logout. Let the
            // owner-scoped router re-arm only if a binding still exists.
            self.recoveryGeneration++;
            self.recoveryID = nil;
            self.recoveryName = nil;
            self.recoveryContext = nil;
            self.recoveryScheduled = NO;
            self.recoveryScanning = NO;
            self.recoveryConnecting = NO;
            if (self.cancelling) { result([self error:@"CONNECT_BUSY" message:@"戒指正在断开，请稍候"]); return; }
            [self beginCancellation:result];
        } else if ([call.method isEqualToString:@"getDeviceDetails"]) [self readBattery:result];
        else if ([call.method isEqualToString:@"triggerDeviceAction"]) {
            if ([args[@"feature"] isEqual:@"camera"]) [self control:args action:YES write:YES result:result];
            else [self findDevice:args probe:NO result:result];
        }
        else if ([call.method isEqualToString:@"readDeviceFeature"] || [call.method isEqualToString:@"writeDeviceFeature"])
            [self control:args action:NO write:[call.method isEqualToString:@"writeDeviceFeature"] result:result];
        else if ([call.method isEqualToString:@"syncHealthData"]) [self syncHistory:result];
        else if ([call.method isEqualToString:@"readAutoMeasureSettings"]) [self monitoring:args write:NO result:result];
        else if ([call.method isEqualToString:@"setAutoMeasureSetting"]) [self monitoring:args write:YES result:result];
        else if ([call.method isEqualToString:@"readAutoMeasureIntervals"]) result(@{}); // Unit is undocumented; preserve the raw byte.
        else if ([call.method isEqualToString:@"getCapabilities"]) {
            result([self capabilities]);
            [self enableDataDelivery];
        }
        else if ([call.method isEqualToString:@"startMeasurement"] || [call.method isEqualToString:@"stopMeasurement"]) {
            NSString *metric = [args[@"metric"] isKindOfClass:NSString.class] ? args[@"metric"] : @"";
            [self measurement:metric enabled:[call.method isEqualToString:@"startMeasurement"] result:result];
        } else result([self error:@"COOLWEAR_FEATURE_UNVERIFIED" message:@"这项 CoolWear iOS 功能尚未完成 SDK 数据验证"]);
    } @catch (NSException *exception) {
        // No raw vendor exception, identity or health payload in logs/results.
        // Complete this request exactly once, even if the exception occurred
        // after it became a pending connection or measurement operation.
        FlutterError *failure = [self error:@"COOLWEAR_SDK_ERROR" message:@"戒指 SDK 操作异常，请重试"];
        NSMutableArray<CoolWearCompletion> *pending = [NSMutableArray array];
        if (self.pendingScan) [pending addObject:self.pendingScan];
        if (self.pendingConnect) [pending addObject:self.pendingConnect];
        if (self.pendingMeasurement) [pending addObject:self.pendingMeasurement];
        if (self.pendingDisconnect) [pending addObject:self.pendingDisconnect];
        if (self.pendingSync) [pending addObject:self.pendingSync];
        if (self.pendingBattery) [pending addObject:self.pendingBattery];
        if (self.pendingMonitoringRead) [pending addObject:self.pendingMonitoringRead];
        if (self.pendingMonitoringWrite) [pending addObject:self.pendingMonitoringWrite];
        if (self.pendingFind) [pending addObject:self.pendingFind];
        if (self.pendingControl) [pending addObject:self.pendingControl];
        self.pendingScan = nil;
        self.pendingConnect = nil;
        self.pendingMeasurement = nil;
        self.pendingDisconnect = nil;
        self.pendingSync = nil;
        self.pendingBattery = nil;
        self.pendingMonitoringRead = nil;
        self.pendingMonitoringWrite = nil;
        self.pendingFind = nil;
        self.pendingControl = nil;
        @try {
            [self beginCancellation:nil];
        } @catch (NSException *cancelException) {
            // If even vendor cancellation throws, keep a fail-closed barrier.
            // Existing SDK status callbacks may later confirm disconnection.
            self.connectionGeneration++;
            self.scanGeneration++;
            self.measurementGeneration++;
            self.cancelling = YES;
            self.activeMetric = nil;
            self.awaitingInfo = NO;
            self.flags = nil;
            self.deviceInfo = nil;
        }
        for (CoolWearCompletion completion in pending) completion(failure);
        result(failure);
    }
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events { self.sink = events; return nil; }
- (FlutterError *)onCancelWithArguments:(id)arguments { self.sink = nil; return nil; }
- (void)dispose {
    self.recoveryGeneration++;
    self.recoveryID = nil;
    [self beginCancellation:nil];
    for (id observer in self.observers) [NSNotificationCenter.defaultCenter removeObserver:observer];
    [self.observers removeAllObjects];
    [self.methods setMethodCallHandler:nil];
    [self.events setStreamHandler:nil];
    self.sink = nil;
}
@end
