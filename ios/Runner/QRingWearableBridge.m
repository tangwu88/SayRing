#import "QRingWearableBridge.h"
#import "QCCentralManager.h"
#import "QRingRecordMapping.h"
#import "QRingNamePolicy.h"
#import "QRingCameraPolicy.h"
#import "QRingGesturePolicy.h"
#import "SayRingActivitySleepPolicy.h"

#import <QCBandSDK/QCBandSDK.h>
#import <CommonCrypto/CommonDigest.h>

typedef void (^QRingNext)(void);

// Bounded Debug-only diagnostics; never record identity or health payloads.
static void RingControlTrace(NSString *phase, NSDictionary *values) {
#if DEBUG
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"RingControlTrace.jsonl"];
    NSMutableDictionary *entry = [values mutableCopy];
    entry[@"phase"] = phase;
    entry[@"uptime"] = @(NSProcessInfo.processInfo.systemUptime);
    NSData *data = [NSJSONSerialization dataWithJSONObject:entry options:0 error:nil];
    if (!data) return;
    if ([NSFileManager.defaultManager attributesOfItemAtPath:path error:nil].fileSize > 65536) {
        [NSData.data writeToFile:path atomically:YES];
    }
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication}];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    @try {
        [file seekToEndOfFile]; [file writeData:data]; [file writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch (__unused NSException *exception) {} @finally { [file closeFile]; }
#else
    (void)phase; (void)values;
#endif
}

static void QRingOnMain(QRingNext block) {
    if (NSThread.isMainThread) { block(); }
    else { dispatch_async(dispatch_get_main_queue(), block); }
}

static void QRingMeasurementQA(NSString *metric, NSString *phase, id value, BOOL success, NSError *error, NSTimeInterval startedAt) {
    // Explicit local QA opt-in only. Do not print raw payloads, readings, errors'
    // userInfo, account information, or peripheral identity into the console.
    if (![NSProcessInfo.processInfo.environment[@"SAY_RING_QA_MEASUREMENT"] isEqualToString:@"1"]) { return; }
    NSString *kind = !value ? @"missing" : [value isKindOfClass:NSNumber.class] ? @"number" :
        QRingIs260918StressCompletion(value) ? @"260918_stress_wrapper" :
        [value isKindOfClass:NSDictionary.class] ? @"dictionary" : @"other";
    NSLog(@"[QRingMeasurementQA] metric=%@ phase=%@ payload=%@ accepted=%d sdkSuccess=%d errorCode=%ld elapsedSeconds=%.1f",
          metric, phase, kind, QRingMeasurementValues(metric, value) != nil, success,
          (long)error.code, NSProcessInfo.processInfo.systemUptime - startedAt);
}

@interface QRingWearableBridge () <FlutterStreamHandler, QCCentralManagerDelegate>
@property(nonatomic, strong) FlutterMethodChannel *methodChannel;
@property(nonatomic, strong) FlutterEventChannel *eventChannel;
@property(nonatomic, copy, nullable) FlutterEventSink eventSink;
@property(nonatomic, strong) QCCentralManager *central;
@property(nonatomic, strong) NSMutableDictionary<NSString *, QCBlePeripheral *> *scanned;
@property(nonatomic, copy, nullable) FlutterResult pendingScan;
@property(nonatomic, copy, nullable) NSString *selectionTargetID;
@property(nonatomic, copy, nullable) FlutterResult pendingConnect;
@property(nonatomic, copy, nullable) FlutterResult pendingSync;
@property(nonatomic, copy, nullable) NSDictionary *featureList;
@property(nonatomic, copy, nullable) NSDictionary *profile;
@property(nonatomic, copy) NSString *connectedID;
@property(nonatomic, copy) NSString *connectedName;
@property(nonatomic, copy) NSString *firmware;
@property(nonatomic, strong, nullable) NSNumber *battery;
@property(nonatomic, strong, nullable) NSNumber *charging;
@property(nonatomic, strong, nullable) NSDate *batteryUpdatedAt;
@property(nonatomic, assign) NSUInteger connectionGeneration;
@property(nonatomic, assign) NSUInteger disconnectGeneration;
@property(nonatomic, assign) NSUInteger measurementGeneration;
@property(nonatomic, assign) NSUInteger manualPolicyGeneration;
@property(nonatomic, assign) NSUInteger syncGeneration;
@property(nonatomic, assign) NSUInteger syncPhaseGeneration;
@property(nonatomic, assign) BOOL readingDetails;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *syncRecords;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *syncStatuses;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableIndexSet *> *syncCompletedDays;
@property(nonatomic, copy, nullable) NSString *activeMetric;
@property(nonatomic, copy, nullable) NSString *activeSportMode;
@property(nonatomic, assign) NSInteger activeSportType;
@property(nonatomic, copy) NSString *recoveryTargetID;
@property(nonatomic, copy) NSString *recoveryContext;
@property(nonatomic, copy) NSString *recoveryTargetName;
@property(nonatomic, copy) NSDictionary *recoveryProfile;
@property(nonatomic, assign) BOOL recoveryConnecting;
@property(nonatomic, assign) NSTimeInterval recoveryRetryNotBefore;
@property(nonatomic, assign) BOOL cancellingConnection;
@property(nonatomic, copy, nullable) FlutterResult pendingDisconnect;
@property(nonatomic, assign) NSUInteger connectDeadlineGeneration;
@property(nonatomic, copy, nullable) FlutterResult pendingCamera;
@property(nonatomic, assign) NSUInteger cameraOperation;
@property(nonatomic, assign) NSInteger cameraPhase;
@property(nonatomic, assign) NSUInteger cameraPoisonGeneration;
@property(nonatomic, assign) BOOL remoteCameraSupported;
@property(nonatomic, assign) BOOL remoteCameraActive;
@property(nonatomic, assign) NSUInteger remoteCameraEpoch;
@property(nonatomic) NSUInteger monitoringPoisonGeneration;
@property(nonatomic, strong) NSNumber *factoryResetGeneration;
@property(nonatomic, strong) NSNumber *factoryInitializingGeneration;
@end

@implementation QRingWearableBridge

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    self = [super init];
    if (!self) { return nil; }
    _scanned = [NSMutableDictionary dictionary];
    _syncRecords = [NSMutableArray array];
    _connectedID = @"";
    _connectedName = @"";
    _firmware = @"";
    _activeSportType = -1;
    _central = [QCCentralManager shared];
    _central.appManagedConnections = YES;
    _central.delegate = self;
    [QCSDKManager shareInstance].debug = NO;
    [QCSDKManager shareInstance].disableDefaultMeasuringValues = YES;
    _methodChannel = [FlutterMethodChannel methodChannelWithName:@"cc.saidian.ring/qring/commands"
                                                 binaryMessenger:messenger];
    _eventChannel = [FlutterEventChannel eventChannelWithName:@"cc.saidian.ring/qring/events"
                                               binaryMessenger:messenger];
    [_eventChannel setStreamHandler:self];
    __weak typeof(self) weakSelf = self;
    [_methodChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf handleCall:call result:result];
        });
    }];
    return self;
}

- (void)dispose {
    [self resetRemoteCamera];
    [self finishCamera:[self error:@"BRIDGE_DISPOSED" message:@"戒指通信已关闭"]];
    self.recoveryTargetID = @"";
    self.recoveryContext = @"";
    self.connectionGeneration++;
    self.connectDeadlineGeneration++;
    self.recoveryConnecting = NO;
    [self.central stopScan];
    if (self.pendingDisconnect) {
        FlutterResult pending = self.pendingDisconnect;
        self.pendingDisconnect = nil;
        pending([self error:@"BRIDGE_DISPOSED" message:@"戒指通信已关闭"]);
    }
    self.central.delegate = nil;
    [self.central disconnect];
    self.pendingConnect = nil;
    self.pendingDisconnect = nil;
    [self.methodChannel setMethodCallHandler:nil];
    [self.eventChannel setStreamHandler:nil];
    self.eventSink = nil;
}

- (FlutterError *)error:(NSString *)code message:(NSString *)message {
    return [FlutterError errorWithCode:code message:message details:nil];
}

- (void)emit:(NSString *)type payload:(NSDictionary *)payload {
    NSDictionary *permitted = SRActivitySleepEvent(type, payload ?: @{});
    if (self.eventSink && permitted) {
        self.eventSink(@{@"type": type, @"payload": permitted});
    }
}

- (BOOL)isQRingName:(NSString *)name {
    return QRingIsSupportedName(name);
}

- (BOOL)isResolved {
    return self.central.deviceState == QCStateConnected && self.featureList.count > 0 && self.connectedID.length > 0 &&
        !self.pendingConnect && !self.recoveryConnecting && !self.cancellingConnection;
}

- (BOOL)feature:(NSString *)key {
    return key.length > 0 && [self.featureList[key] boolValue];
}

- (void)startScan:(FlutterResult)result {
    if (self.pendingScan) {
        [self finishScan];
    }
    self.selectionTargetID = nil;
    [self.scanned removeAllObjects];
    self.pendingScan = result;
    [self.central scanWithTimeout:10];
}

- (NSArray *)scanPayloads {
    NSMutableArray *values = [NSMutableArray array];
    for (QCBlePeripheral *item in self.scanned.allValues) {
        NSString *name = item.peripheral.name ?: @"QRing";
        NSString *identifier = item.peripheral.identifier.UUIDString ?: @"";
        if (identifier.length == 0 || ![self isQRingName:name]) { continue; }
        [values addObject:@{
            @"id": identifier,
            @"name": name,
            @"model": name,
            @"hardwareAddress": item.mac ?: @"",
            @"rssi": item.RSSI ?: @0,
        }];
    }
    return values;
}

- (void)finishScan {
    [self.central stopScan];
    self.selectionTargetID = nil;
    if (!self.pendingScan) { return; }
    FlutterResult result = self.pendingScan;
    self.pendingScan = nil;
    result([self scanPayloads]);
}

- (void)prepareRememberedDevice:(NSDictionary *)arguments result:(FlutterResult)result {
    // Manual selection only: exact last successful UUID from the current App
    // environment, never the demo's installation-wide saved target. UUID
    // retrieval is not an OS bond and does not authorize automatic recovery.
    NSString *identifier = [arguments[@"id"] isKindOfClass:NSString.class] ? arguments[@"id"] : nil;
    NSUUID *uuid = identifier ? [[NSUUID alloc] initWithUUIDString:identifier] : nil;
    if (!uuid || self.central.bleState != QCBluetoothStatePoweredOn) { result(nil); return; }
    NSArray<CBPeripheral *> *items = [self.central.centerManager retrievePeripheralsWithIdentifiers:@[uuid]];
    for (CBPeripheral *peripheral in items) {
        if (![peripheral.identifier isEqual:uuid] || ![self isQRingName:peripheral.name]) { continue; }
        // An existing OS link can handshake without advertising. Otherwise
        // refresh the exact target's advertisement instead of reusing a stale
        // retrieved object repeatedly. Do not adopt another ring by its name.
        if (peripheral.state == CBPeripheralStateConnected) {
            QCBlePeripheral *item = [QCBlePeripheral new];
            item.peripheral = peripheral;
            self.scanned[identifier] = item;
            result(@{@"id": identifier, @"name": peripheral.name, @"model": peripheral.name});
            return;
        }
    }
    [self startScan:^(id values) {
        if ([values isKindOfClass:NSArray.class]) {
            for (NSDictionary *device in values) {
                if ([device[@"id"] isEqualToString:identifier]) { result(device); return; }
            }
        }
        result(nil);
    }];
    self.selectionTargetID = identifier;
    // scanWithTimeout may synchronously publish an existing system link.
    if (self.scanned[identifier]) { [self finishScan]; }
}

- (void)connect:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *identifier = [arguments[@"id"] isKindOfClass:NSString.class] ? arguments[@"id"] : @"";
    QCBlePeripheral *item = self.scanned[identifier];
    if (!item || ![self isQRingName:item.peripheral.name]) {
        result([self error:@"QRING_DEVICE_UNVERIFIED" message:@"请重新搜索并选择 QRing 戒指"]);
        return;
    }
    if (self.pendingConnect || self.recoveryConnecting || self.cancellingConnection ||
        self.central.hasPendingRestoredCancellations) {
        result([self error:@"CONNECT_BUSY" message:@"戒指正在连接，请稍候"]);
        return;
    }
    [self finishScan];
    RingControlTrace(@"connection-requested", @{@"recovery": @NO});
    self.pendingConnect = result;
    self.recoveryRetryNotBefore = 0;
    self.featureList = nil;
    self.connectionGeneration++;
    self.battery = nil;
    self.charging = nil;
    self.batteryUpdatedAt = nil;
    self.firmware = @"";
    self.profile = [arguments[@"profile"] isKindOfClass:NSDictionary.class] ? arguments[@"profile"] : @{};
    self.connectedID = identifier;
    self.connectedName = item.peripheral.name ?: @"QRing";
    [self scheduleConnectDeadline];
    [self.central connect:item.peripheral timeout:12 deviceType:QCDeviceTypeRing];
}

- (void)scheduleConnectDeadline {
    NSUInteger deadline = ++self.connectDeadlineGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 35 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (weakSelf.connectDeadlineGeneration != deadline) { return; }
        if (weakSelf.pendingConnect || weakSelf.recoveryConnecting) {
            [weakSelf failConnect:@"QRING_CONNECT_TIMEOUT" message:@"戒指连接或能力读取超时，请靠近手机后重试"];
        }
    });
}

- (void)startAutomaticRecovery {
    if (self.recoveryTargetID.length == 0 || self.recoveryContext.length == 0 ||
        ![self isQRingName:self.recoveryTargetName] ||
        self.central.hasPendingRestoredCancellations ||
        self.central.bleState != QCBluetoothStatePoweredOn || self.pendingConnect ||
        self.pendingDisconnect || self.cancellingConnection || self.recoveryConnecting || [self isResolved] ||
        NSProcessInfo.processInfo.systemUptime < self.recoveryRetryNotBefore) { return; }
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.recoveryTargetID];
    if (!uuid) { return; }
    NSArray<CBPeripheral *> *items = [self.central.centerManager retrievePeripheralsWithIdentifiers:@[uuid]];
    for (CBPeripheral *peripheral in items) {
        if (![peripheral.identifier isEqual:uuid] ||
            (peripheral.name.length > 0 && ![self isQRingName:peripheral.name])) { continue; }
        // An exact owner-bound UUID can outlive CoreBluetooth's cached name.
        // The saved name was verified when this recovery context was armed.
        NSString *resolvedName = peripheral.name.length > 0 ? peripheral.name : self.recoveryTargetName;
        self.connectedID = self.recoveryTargetID;
        self.connectedName = resolvedName;
        self.profile = self.recoveryProfile ?: @{};
        self.featureList = nil;
        self.connectionGeneration++;
        self.recoveryConnecting = YES;
        RingControlTrace(@"connection-requested", @{@"recovery": @YES});
        [self emit:@"recoveryState" payload:@{@"status": @"waiting", @"deviceId": self.connectedID}];
        // CoreBluetooth owns one indefinite pending request until proximity.
        // Only the SDK handshake receives a deadline after the radio connects.
        [self.central connect:peripheral timeout:0 deviceType:QCDeviceTypeRing];
        return;
    }
}

- (void)scheduleRecoveryAfterDisconnect {
    NSUInteger generation = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    QRingNext recover = ^{
        if (generation == weakSelf.connectionGeneration) { [weakSelf startAutomaticRecovery]; }
    };
    NSTimeInterval delay = MAX(0, self.recoveryRetryNotBefore - NSProcessInfo.processInfo.systemUptime);
    // A normal proximity loss can re-arm immediately, after SDK teardown.
    // Preserve a cooldown after a failed handshake to prevent a retry loop.
    if (delay > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), recover);
    } else {
        dispatch_async(dispatch_get_main_queue(), recover);
    }
}

- (void)disconnectWithResult:(FlutterResult)result {
    [self finishScan];
    [self finishCamera:[self error:@"QRING_DISCONNECTED" message:@"戒指已断开"]];
    if (self.pendingDisconnect || self.cancellingConnection) {
        result([self error:@"RECOVERY_PENDING" message:@"戒指连接正在结束，请稍候"]); return;
    }
    self.recoveryTargetID = @"";
    self.recoveryContext = @"";
    self.recoveryConnecting = NO;
    self.recoveryRetryNotBefore = 0;
    self.connectDeadlineGeneration++;
    self.connectionGeneration++;
    if (self.pendingConnect) {
        FlutterResult connect = self.pendingConnect;
        self.pendingConnect = nil;
        connect([self error:@"CONNECT_CANCELLED" message:@"连接已取消"]);
    }
    self.pendingDisconnect = result;
    self.cancellingConnection = YES;
    NSUInteger cancellationGeneration = self.connectionGeneration;
    self.featureList = nil;
    [self.central remove];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!weakSelf.pendingDisconnect || weakSelf.connectionGeneration != cancellationGeneration) { return; }
        FlutterResult pending = weakSelf.pendingDisconnect;
        weakSelf.pendingDisconnect = nil;
        // Keep the cancellation barrier until the actual native callback.
        pending([weakSelf error:@"RECOVERY_PENDING" message:@"蓝牙连接尚未结束，请稍后重试"]);
    });
}

- (void)configureRecoveryTarget:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *identifier = [arguments[@"id"] isKindOfClass:NSString.class] ? arguments[@"id"] : nil;
    if (identifier.length == 0) {
        self.recoveryTargetID = @"";
        self.recoveryContext = @"";
        [self.central discardRestoredPeripheralsExceptIdentifier:@""];
        if (self.recoveryConnecting && ![self isResolved]) { [self disconnectWithResult:result]; }
        else { self.recoveryConnecting = NO; result(nil); }
        return;
    }
    NSString *name = [arguments[@"name"] isKindOfClass:NSString.class] ? arguments[@"name"] : nil;
    NSString *context = [arguments[@"context"] isKindOfClass:NSString.class] ? arguments[@"context"] : nil;
    if (![[NSUUID alloc] initWithUUIDString:identifier] || ![self isQRingName:name] || context.length == 0) {
        result([self error:@"QRING_DEVICE_UNVERIFIED" message:@"保存的戒指信息无效，请重新添加"]); return;
    }
    if (self.cancellingConnection) {
        result([self error:@"RECOVERY_PENDING" message:@"戒指连接正在结束，请稍候"]); return;
    }
    if (self.recoveryConnecting && (![self.recoveryTargetID isEqualToString:identifier] ||
        ![self.recoveryContext isEqualToString:context])) {
        result([self error:@"RECOVERY_PENDING" message:@"请先结束上一台戒指的连接"]); return;
    }
    self.recoveryTargetID = identifier;
    self.recoveryTargetName = name;
    self.recoveryContext = context;
    self.recoveryProfile = [arguments[@"profile"] isKindOfClass:NSDictionary.class] ? arguments[@"profile"] : @{};
    [self.central discardRestoredPeripheralsExceptIdentifier:identifier];
    // Explicit connection arms the owner only after the SDK handshake. Resume
    // initialization for this already selected target; never select or reset it.
    NSDictionary *intent = [self factoryInitialization:identifier context:context];
    if ([self isResolved] && [self.connectedID.lowercaseString isEqual:identifier.lowercaseString] &&
        intent && ![intent[@"initialized"] isEqual:@YES] &&
        ![self.factoryResetGeneration isEqual:@(self.connectionGeneration)]) {
        if ([self.factoryInitializingGeneration isEqual:@(self.connectionGeneration)]) {
            result([self error:@"DEVICE_BUSY" message:@"戒指正在初始化，请稍候"]); return;
        }
        NSUInteger generation = self.connectionGeneration;
        self.factoryInitializingGeneration = @(generation);
        self.profile = self.recoveryProfile;
        __weak typeof(self) weakSelf = self;
        __block BOOL finished = NO;
        QRingNext finish = ^{
            if (finished) return;
            finished = YES;
            if ([weakSelf.factoryInitializingGeneration isEqual:@(generation)]) weakSelf.factoryInitializingGeneration = nil;
            if ([weakSelf isCurrentConnection:generation] && [weakSelf.recoveryContext isEqual:context] &&
                [weakSelf.connectedID.lowercaseString isEqual:identifier.lowercaseString]) {
                [weakSelf emit:@"capabilitiesUpdated" payload:[weakSelf capabilities]];
                [weakSelf emitFactoryInitialization];
            }
            result(nil);
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12 * NSEC_PER_SEC), dispatch_get_main_queue(), finish);
        [self writeProfileWithCompletion:finish];
        return;
    }
    [self startAutomaticRecovery];
    result(nil);
}

- (void)resolveCapabilities {
    if (self.connectedID.length == 0 || ![self.central.connectedPeripheral.identifier.UUIDString isEqualToString:self.connectedID]) {
        [self.central disconnect];
        return;
    }
    NSUInteger generation = ++self.connectionGeneration;
    RingControlTrace(@"connection-sdk-registered", @{@"generation": @(generation)});
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator setTime:NSDate.date success:^(NSDictionary *featureList) {
      QRingOnMain(^{
        __strong typeof(weakSelf) self = weakSelf;
        if (![self isCurrentConnection:generation]) { return; }
        if (featureList.count == 0) {
            [self failConnect:@"QRING_HANDSHAKE_FAILED" message:@"戒指未返回功能列表，请重试"];
            return;
        }
        [self resolveExtendedCapabilities:featureList.copy generation:generation attempt:0 completion:^(NSDictionary *resolvedFeatures) {
        if (![self isCurrentConnection:generation]) { return; }
        self.featureList = [resolvedFeatures copy];
        RingControlTrace(@"connection-capabilities", @{@"generation": @(generation)});
        // QRing has one command channel. Finish setup/details before Flutter
        // can start history sync or a measurement on that channel.
        [self writeProfileWithCompletion:^{
          QRingOnMain(^{
            if (![weakSelf isCurrentConnection:generation]) { return; }
            RingControlTrace(@"connection-profile-finished", @{@"generation": @(generation)});
            [weakSelf readDeviceDetailsWithCompletion:^{
                if (![weakSelf isCurrentConnection:generation]) { return; }
                [weakSelf probeRemoteCamera:^{
                if (![weakSelf isCurrentConnection:generation]) { return; }
                RingControlTrace(@"connection-ready", @{@"generation": @(generation)});
                FlutterResult result = weakSelf.pendingConnect;
                weakSelf.pendingConnect = nil;
                weakSelf.connectDeadlineGeneration++;
                BOOL recovered = weakSelf.recoveryConnecting;
                weakSelf.recoveryConnecting = NO;
                if (result) { result(nil); }
                [weakSelf emit:@"deviceDetails" payload:[weakSelf deviceDetails]];
                [weakSelf emit:@"capabilitiesUpdated" payload:[weakSelf capabilities]];
                if (recovered) { [weakSelf emit:@"reconnected" payload:[weakSelf deviceDetails]]; }
                }];
            }];
          });
        }];
        }];
      });
    } failed:^{
      QRingOnMain(^{
        if ([weakSelf isCurrentConnection:generation]) {
            [weakSelf failConnect:@"QRING_HANDSHAKE_FAILED" message:@"戒指能力读取失败，请靠近手机后重试"];
        }
      });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if ([weakSelf isCurrentConnection:generation] && weakSelf.pendingConnect) {
            [weakSelf failConnect:@"QRING_HANDSHAKE_TIMEOUT" message:@"戒指连接准备超时，请靠近手机后重试"];
        }
    });
}

// setTime may succeed with only the basic time-response dictionary when its
// internal extended-feature read fails. Missing control bits are unknown until
// an independent extended read succeeds; never infer support from saved names.
- (void)resolveExtendedCapabilities:(NSDictionary *)features generation:(NSUInteger)generation attempt:(NSUInteger)attempt completion:(void (^)(NSDictionary *))completion {
    if (![self isCurrentConnection:generation]) { return; }
    if ([features[QCBandFeatureGestureControl] isEqual:@YES] ||
        [features[QCBandFeatureTouchControl] isEqual:@YES]) {
        completion(features); return;
    }
    if (attempt >= 2) {
        RingControlTrace(@"feature-config-unconfirmed", @{@"generation": @(generation)});
        // Preserve confirmed basic functions and the healthy radio link.
        // Failed reads cannot restore controls from a previous connection.
        completion(features); return;
    }
    __weak typeof(self) weakSelf = self;
    // Read-only retry, after the SDK has left its previous command callback.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (attempt == 0 ? 200 : 400) * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (![weakSelf isCurrentConnection:generation]) { return; }
        RingControlTrace(@"feature-config-read", @{@"generation": @(generation), @"attempt": @(attempt + 1)});
        __block BOOL answered = NO;
        QRingNext retry = ^{
            QRingOnMain(^{
                if (answered) { return; }
                answered = YES;
                [weakSelf resolveExtendedCapabilities:features generation:generation attempt:attempt + 1 completion:completion];
            });
        };
        [QCSDKCmdCreator getDeviceFeatureConfigSuccess:^(NSDictionary *extended) {
          QRingOnMain(^{
            if (answered || ![weakSelf isCurrentConnection:generation]) { return; }
            if (![extended isKindOfClass:NSDictionary.class]) { retry(); return; }
            answered = YES;
            NSMutableDictionary *merged = [features mutableCopy];
            [merged addEntriesFromDictionary:extended];
            RingControlTrace(@"feature-config-confirmed", @{@"generation": @(generation), @"gesture": @([extended[QCBandFeatureGestureControl] isEqual:@YES]), @"touch": @([extended[QCBandFeatureTouchControl] isEqual:@YES])});
            completion(merged.copy);
          });
        } fail:retry];
    });
}

- (BOOL)isCurrentConnection:(NSUInteger)generation {
    return generation == self.connectionGeneration && self.central.deviceState == QCStateConnected;
}

- (NSInteger)profileNumber:(NSString *)key fallback:(NSInteger)fallback minimum:(NSInteger)minimum maximum:(NSInteger)maximum {
    NSNumber *raw = [self.profile[key] isKindOfClass:NSNumber.class] ? self.profile[key] : nil;
    NSInteger value = raw ? raw.integerValue : fallback;
    return MIN(maximum, MAX(minimum, value));
}

- (NSString *)factoryInitializationKey:(NSString *)identifier context:(NSString *)context {
    return [NSString stringWithFormat:@"SayRing.factoryInitialization.v1.%@.%@", context ?: @"", identifier.lowercaseString ?: @""];
}

- (NSDictionary *)factoryInitialization:(NSString *)identifier context:(NSString *)context {
    if (!identifier.length || !context.length) return nil;
    id value = [NSUserDefaults.standardUserDefaults objectForKey:[self factoryInitializationKey:identifier context:context]];
    if (![value isKindOfClass:NSDictionary.class] || ![value[@"id"] isEqual:identifier.lowercaseString] ||
        ![value[@"context"] isEqual:context] || ![value[@"schemaVersion"] isEqual:@1]) return nil;
    return value;
}

- (BOOL)saveFactoryInitialization:(NSDictionary *)value identifier:(NSString *)identifier context:(NSString *)context {
    [NSUserDefaults.standardUserDefaults setObject:value forKey:[self factoryInitializationKey:identifier context:context]];
    return [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)updateFactoryInitialization:(NSString *)identifier context:(NSString *)context acknowledged:(BOOL)ack initialized:(BOOL)initialized {
    NSDictionary *stored = [self factoryInitialization:identifier context:context];
    if (!stored) return;
    NSMutableDictionary *value = [stored mutableCopy];
    if (ack) value[@"acknowledged"] = @YES;
    if (initialized) value[@"initialized"] = @YES;
    [self saveFactoryInitialization:value identifier:identifier context:context];
}

- (BOOL)factoryInitializationPending {
    NSDictionary *value = [self factoryInitialization:self.connectedID context:self.recoveryContext];
    return value && (![[value objectForKey:@"acknowledged"] isEqual:@YES] || ![[value objectForKey:@"initialized"] isEqual:@YES]);
}

- (void)emitFactoryInitialization {
    if (![self isResolved] || ![self factoryInitialization:self.connectedID context:self.recoveryContext]) return;
    [self emit:@"ringInitialization" payload:@{@"deviceId": self.connectedID,
        @"ownerKey": [self.recoveryContext componentsSeparatedByString:@":"].lastObject ?: @"",
        @"status": [self factoryInitializationPending] ? @"pending" : @"complete"}];
}

- (void)initializeFactoryTargetWithCompletion:(QRingNext)completion {
    NSString *identifier = self.connectedID, *context = self.recoveryContext;
    NSDictionary *intent = [self factoryInitialization:identifier context:context];
    if (!intent || [intent[@"initialized"] isEqual:@YES]) { completion(); return; }
    NSUInteger generation = self.connectionGeneration;
    BOOL rearming = [self.factoryInitializingGeneration isEqual:@(generation)];
    NSInteger target = [self profileNumber:@"targetSteps" fallback:8000 minimum:1000 maximum:100000];
    __weak typeof(self) weakSelf = self;
    __block BOOL finished = NO;
    QRingNext finish = ^{ if (!finished) { finished = YES; completion(); } };
    BOOL (^current)(void) = ^BOOL { return !finished && (!rearming || [weakSelf.factoryInitializingGeneration isEqual:@(generation)]) && [weakSelf isCurrentConnection:generation] &&
        [weakSelf.connectedID.lowercaseString isEqual:identifier.lowercaseString] && [weakSelf.recoveryContext isEqual:context]; };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (current()) finish();
    });
    // Preserve every other freshly read target; never guess calorie/distance
    // units or restore a previous wearer's reminder settings after a reset.
    [QCSDKCmdCreator getStepTargetInfoWithSuccess:^(NSInteger steps, NSInteger calories, NSInteger distance, NSInteger sport, NSInteger sleep) {
        QRingOnMain(^{
            if (!current()) return;
            [QCSDKCmdCreator setStepTarget:target calorieTarget:calories distanceTarget:distance sportDurationTarget:sport sleepDurationTarget:sleep success:^{
                QRingOnMain(^{
                    if (!current()) return;
                    [QCSDKCmdCreator getStepTargetInfoWithSuccess:^(NSInteger actual, NSInteger c, NSInteger d, NSInteger s, NSInteger n) {
                        QRingOnMain(^{
                            if (!current()) return;
                            if (actual == target && c == calories && d == distance && s == sport && n == sleep)
                                [weakSelf updateFactoryInitialization:identifier context:context acknowledged:NO initialized:YES];
                            finish();
                        });
                    } fail:^{ QRingOnMain(^{ if (current()) finish(); }); }];
                });
            } fail:^{ QRingOnMain(^{ if (current()) finish(); }); }];
        });
    } fail:^{ QRingOnMain(^{ if (current()) finish(); }); }];
}

- (void)resetFirstMemberRing:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *identifier = [arguments[@"id"] isKindOfClass:NSString.class] ? arguments[@"id"] : nil;
    NSString *owner = [arguments[@"ownerKey"] isKindOfClass:NSString.class] ? arguments[@"ownerKey"] : nil;
    if (![arguments[@"allowFactoryReset"] isEqual:@YES] || !owner.length || ![self isResolved] ||
        ![self.connectedID.lowercaseString isEqual:identifier.lowercaseString] ||
        ![self.recoveryContext hasSuffix:[@":" stringByAppendingString:owner]]) {
        result([self error:@"FACTORY_RESET_NOT_AUTHORIZED" message:@"首次绑定恢复出厂未获确认，未执行"]); return;
    }
    if (self.pendingSync || self.activeMetric || self.activeSportType >= 0 || self.readingDetails ||
        [self.factoryResetGeneration isEqual:@(self.connectionGeneration)] ||
        [self factoryInitialization:identifier context:self.recoveryContext]) {
        result([self error:@"DEVICE_BUSY" message:@"设备忙或已请求初始化，不会重复重置"]); return;
    }
    NSString *context = self.recoveryContext;
    NSDictionary *intent = @{@"schemaVersion": @1, @"id": identifier.lowercaseString,
        @"context": context, @"acknowledged": @NO, @"initialized": @NO};
    if (![self saveFactoryInitialization:intent identifier:identifier context:context]) {
        result([self error:@"INITIALIZATION_STORAGE_FAILED" message:@"初始化记录未能保存，未重置戒指"]); return;
    }
    self.factoryResetGeneration = @(self.connectionGeneration);
    NSUInteger generation = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator resetBandToFacotrySuccess:^{
        QRingOnMain(^{
            // Never attribute an SDK callback to another connection/owner.
            if (generation != weakSelf.connectionGeneration || ![weakSelf.recoveryContext isEqual:context] ||
                ![weakSelf.connectedID.lowercaseString isEqual:identifier.lowercaseString]) return;
            [weakSelf updateFactoryInitialization:identifier context:context acknowledged:YES initialized:NO];
            if ([weakSelf.connectedID.lowercaseString isEqual:identifier.lowercaseString] && [weakSelf.recoveryContext isEqual:context] && [weakSelf isResolved]) {
                [weakSelf emit:@"capabilitiesUpdated" payload:[weakSelf capabilities]];
                [weakSelf emitFactoryInitialization];
            }
        });
    } fail:^{ /* Ambiguous result stays pending; never retry the reset. */ }];
    result(@"factoryResetRequested");
}

- (void)writeProfileWithCompletion:(QRingNext)completion {
    NSUInteger generation = self.connectionGeneration;
    BOOL rearming = [self.factoryInitializingGeneration isEqual:@(generation)];
    NSString *identifier = self.connectedID, *context = self.recoveryContext;
    NSInteger gender = [self profileNumber:@"gender" fallback:1 minimum:1 maximum:2] == 2 ? 1 : 0;
    [QCSDKCmdCreator setTimeFormatTwentyfourHourFormat:YES
                                          metricSystem:YES
                                                gender:gender
                                                   age:[self profileNumber:@"age" fallback:30 minimum:5 maximum:120]
                                                height:[self profileNumber:@"heightCm" fallback:170 minimum:80 maximum:240]
                                                weight:[self profileNumber:@"weightKg" fallback:65 minimum:20 maximum:250]
                                               sbpBase:0 dbpBase:0 hrAlarmValue:0
                                               success:^(__unused BOOL a, __unused BOOL b, __unused NSInteger c, __unused NSInteger d, __unused NSInteger e, __unused NSInteger f, __unused NSInteger g, __unused NSInteger h, __unused NSInteger i) {
                                                   QRingOnMain(^{
                                                       if ((!rearming || [self.factoryInitializingGeneration isEqual:@(generation)]) &&
                                                           [self isCurrentConnection:generation] && [self.connectedID isEqual:identifier] &&
                                                           (self.recoveryContext == context || [self.recoveryContext isEqual:context])) [self initializeFactoryTargetWithCompletion:completion];
                                                   });
                                               }
                                                  fail:completion];
}

- (void)readDeviceDetailsWithCompletion:(QRingNext)completion {
    NSUInteger generation = self.connectionGeneration;
    self.readingDetails = YES;
    RingControlTrace(@"battery-start", @{@"generation": @(generation)});
    __block BOOL finished = NO;
    __weak typeof(self) weakSelf = self;
    QRingNext finish = ^{
        if (finished) { return; }
        finished = YES;
        if (generation == weakSelf.connectionGeneration) { weakSelf.readingDetails = NO; }
        RingControlTrace(@"details-finished", @{@"generation": @(generation)});
        completion();
    };
    QRingNext readFirmware = ^{
        if (finished || ![weakSelf isCurrentConnection:generation]) { finish(); return; }
        // Firmware is constant within this live connection. Battery polling
        // must not repeat this SDK command; disconnect clears the cache.
        // Empty/failed reads remain retryable on the next details request.
        if (weakSelf.firmware.length > 0) { finish(); return; }
        // The bundled SDK invokes this callback as (hardware, software).
        RingControlTrace(@"firmware-start", @{@"generation": @(generation)});
        [QCSDKCmdCreator getDeviceSoftAndHardVersionSuccess:^(__unused NSString *hardware, NSString *software) {
          QRingOnMain(^{
            if (!finished && [weakSelf isCurrentConnection:generation]) {
                weakSelf.firmware = software ?: @"";
            }
            RingControlTrace(@"firmware-finished", @{@"generation": @(generation)});
            finish();
          });
        } fail:^{ QRingOnMain(finish); }];
    };
    [QCSDKCmdCreator readBatterySuccess:^(int battery, BOOL charging) {
      QRingOnMain(^{
        if (finished || ![weakSelf isCurrentConnection:generation]) { finish(); return; }
        if (battery >= 0 && battery <= 100) {
            weakSelf.battery = @(battery);
            weakSelf.charging = @(charging);
            weakSelf.batteryUpdatedAt = NSDate.date;
        }
        RingControlTrace(@"battery-finished", @{@"generation": @(generation)});
        readFirmware();
      });
    } failed:^{ QRingOnMain(readFirmware); }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), finish);
}

- (void)failConnect:(NSString *)code message:(NSString *)message {
    self.recoveryRetryNotBefore = NSProcessInfo.processInfo.systemUptime + 2;
    self.connectionGeneration++;
    self.readingDetails = NO;
    self.connectDeadlineGeneration++;
    self.recoveryConnecting = NO;
    FlutterResult result = self.pendingConnect;
    self.pendingConnect = nil;
    if (result) { result([self error:code message:message]); }
    CBPeripheral *peripheral = self.central.connectedPeripheral;
    self.cancellingConnection = peripheral.state == CBPeripheralStateConnected ||
        peripheral.state == CBPeripheralStateConnecting || peripheral.state == CBPeripheralStateDisconnecting;
    [self.central disconnect];
}

- (void)startUnbind:(FlutterResult)result {
    if (self.pendingDisconnect) {
        result([self error:@"DISCONNECT_BUSY" message:@"正在解除绑定，请稍候"]);
        return;
    }
    [self finishScan];
    self.connectionGeneration++;
    if (self.pendingConnect) {
        FlutterResult pending = self.pendingConnect;
        self.pendingConnect = nil;
        pending([self error:@"QRING_CONNECT_CANCELLED" message:@"已取消戒指连接"]);
    }
    self.pendingDisconnect = result;
    NSUInteger generation = ++self.disconnectGeneration;
    // `disconnect` preserves the local UUID. The App action is an unbind, so
    // remove the saved UUID and cancel CoreBluetooth before reporting success.
    [self.central remove];
    if (self.central.deviceState == QCStateUnbind) {
        [self finishUnbind:generation];
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.disconnectGeneration || !self.pendingDisconnect) { return; }
        if (self.central.deviceState == QCStateUnbind) {
            [self finishUnbind:generation];
            return;
        }
        FlutterResult pending = self.pendingDisconnect;
        self.pendingDisconnect = nil;
        pending([self error:@"QRING_DISCONNECT_TIMEOUT" message:@"戒指仍在连接，请靠近手机后重试"]);
    });
}

- (void)finishUnbind:(NSUInteger)generation {
    if (generation != self.disconnectGeneration || !self.pendingDisconnect) { return; }
    FlutterResult pending = self.pendingDisconnect;
    self.pendingDisconnect = nil;
    pending(nil);
}

- (NSDictionary *)deviceDetails {
    NSMutableDictionary *value = [@{
        @"id": self.connectedID ?: @"",
        @"name": self.connectedName.length ? self.connectedName : @"QRing",
        @"model": self.connectedName.length ? self.connectedName : @"QRing",
    } mutableCopy];
    if (self.firmware.length) { value[@"firmwareVersion"] = self.firmware; }
    if (self.battery) {
        value[@"batteryPercent"] = self.battery;
        value[@"battery"] = @{
            @"value": self.battery,
            @"scale": @100,
            @"isPercent": @YES,
            @"chargeState": self.charging ? (self.charging.boolValue ? @"charging" : @"normal") : @"unknown",
            @"updatedAt": [self iso:self.batteryUpdatedAt],
            @"chargingUpdatedAt": [self iso:self.batteryUpdatedAt],
        };
    }
    return value;
}

- (NSDictionary *)capabilities {
    NSMutableArray *metrics = [NSMutableArray arrayWithArray:@[@"steps", @"distance", @"calories", @"sleep", @"heart_rate"]];
    NSMutableArray *manual = [NSMutableArray array];
    NSMutableArray *features = [NSMutableArray arrayWithObject:@"find_watch"];
    BOOL appManual = [self feature:QCBandFeatureAppManual];
    if ([self feature:QCBandFeatureManualHeartRate] || appManual) { [manual addObject:@"heart_rate"]; }
    if ([self feature:QCBandFeatureBloodOxygen]) {
        [metrics addObject:@"blood_oxygen"];
        if ([self feature:QCBandFeatureManualBloodOxygen] || appManual) { [manual addObject:@"blood_oxygen"]; }
    }
    if ([self feature:QCBandFeatureBloodPressure]) {
        [metrics addObject:@"blood_pressure"];
        if (appManual) { [manual addObject:@"blood_pressure"]; }
    }
    if ([self feature:QCBandFeatureStress]) {
        [metrics addObject:@"stress"];
        if (appManual) { [manual addObject:@"stress"]; }
    }
    if ([self feature:QCBandFeatureHRV]) {
        [metrics addObject:@"hrv"];
        if (appManual) { [manual addObject:@"hrv"]; }
    }
    if ([self feature:QCBandFeatureTemperature]) {
        [metrics addObject:@"body_temperature"];
        if (appManual) { [manual addObject:@"body_temperature"]; }
    }
    [features addObject:@"health_monitoring"];
    if (self.remoteCameraSupported) { [features addObject:@"camera"]; }
    if ([self supportsGesture]) { [features addObject:@"gesture_control"]; }
    NSArray *sports = @[@"running", @"indoor_running", @"walking", @"cycling", @"indoor_cycling", @"basketball", @"football", @"badminton", @"swimming", @"jump_rope", @"yoga", @"hiking", @"mountaineering"];
    return @{
        @"resolved": @([self isResolved]),
        @"metrics": metrics,
        @"manualMetrics": manual,
        @"sportModes": sports,
        @"features": features,
        @"integratedFeatures": features,
        @"supportsSportPause": @NO,
        @"supportsBackgroundSync": @NO,
        // Logical negation boxes as NSNumber(int), which Flutter decodes as 1/0.
        // This capability must cross the channel as an actual Boolean.
        @"supportsHistorySync": [self factoryInitializationPending] ? @NO : @YES,
        @"supportsWatchFaces": @NO,
        @"supportsOta": @NO,
    };
}

- (BOOL)supportsManualMetric:(NSString *)metric {
    return [[self capabilities][@"manualMetrics"] containsObject:metric ?: @""];
}

- (QCMeasuringType)measurementType:(NSString *)metric {
    if ([metric isEqualToString:@"heart_rate"]) { return QCMeasuringTypeHeartRate; }
    if ([metric isEqualToString:@"blood_pressure"]) { return QCMeasuringTypeBloodPressue; }
    if ([metric isEqualToString:@"blood_oxygen"]) { return QCMeasuringTypeBloodOxygen; }
    if ([metric isEqualToString:@"stress"]) { return QCMeasuringTypeStress; }
    if ([metric isEqualToString:@"hrv"]) { return QCMeasuringTypeHRV; }
    if ([metric isEqualToString:@"body_temperature"]) { return QCMeasuringTypeBodyTemperature; }
    return QCMeasuringTypeUnkown;
}

- (void)startMeasurement:(NSString *)metric result:(FlutterResult)result {
    if (!SRManualHealthMetricAllowed(metric)) { result([self error:@"FEATURE_UNAVAILABLE" message:@"此项测量暂未开放"]); return; }
    if (self.pendingSync || self.readingDetails || self.activeSportType >= 0) {
        result([self error:@"DEVICE_BUSY" message:@"设备忙，请稍后重试"]); return;
    }
    QCMeasuringType type = [self measurementType:metric];
    if (![self isResolved] || type == QCMeasuringTypeUnkown || ![self supportsManualMetric:metric]) {
        result([self error:@"QRING_FEATURE_UNVERIFIED" message:@"此项手动测量未获戒指确认"]);
        return;
    }
    if (self.activeMetric) {
        result([self error:@"MEASUREMENT_ACTIVE" message:@"已有健康测量正在进行"]);
        return;
    }
    self.activeMetric = metric;
    NSUInteger measurementGeneration = ++self.measurementGeneration;
    NSUInteger connectionGeneration = self.connectionGeneration;
    // The SDK supplies no real progress percentage; keep the UI indeterminate.
    [self emit:@"measurementProgress" payload:@{@"metric": metric, @"progress": @0}];
    NSInteger timeout = type == QCMeasuringTypeHRV ? 80 : 30;
    NSTimeInterval startedAt = NSProcessInfo.processInfo.systemUptime;
    __weak typeof(self) weakSelf = self;
    [[QCSDKManager shareInstance] startToMeasuringWithOperateType:type timeout:timeout measuringHandle:^(id value) {
      QRingOnMain(^{
        if (measurementGeneration != weakSelf.measurementGeneration || ![weakSelf isCurrentConnection:connectionGeneration]) { return; }
        QRingMeasurementQA(metric, @"intermediate", value, YES, nil, startedAt);
        [weakSelf emitMeasurementValue:value metric:metric terminal:NO];
      });
    } completedHandle:^(BOOL success, id value, NSError *error) {
      QRingOnMain(^{
        if (measurementGeneration != weakSelf.measurementGeneration || ![weakSelf isCurrentConnection:connectionGeneration]) { return; }
        QRingMeasurementQA(metric, @"completed", value, success, error, startedAt);
        if (!success || !value) {
            [weakSelf emit:@"error" payload:@{
                @"code": error.code == -3 ? @"MEASUREMENT_NOT_WORN" : @"MEASUREMENT_FAILED",
                @"message": error.code == -3 ? @"未检测到正确佩戴，请调整戒指后重试" : @"戒指未返回有效测量结果，请保持静止后重试",
            }];
        } else {
            [weakSelf emitMeasurementValue:value metric:metric terminal:YES];
        }
        weakSelf.activeMetric = nil;
      });
    }];
    result(nil);
}

- (void)emitMeasurementValue:(id)value metric:(NSString *)metric terminal:(BOOL)terminal {
    // Only the SDK's completed callback can finish the Flutter measurement.
    // A provisional/sentinel value must not stop the device before completion.
    if (!terminal) { return; }
    NSDictionary *values = QRingMeasurementValues(metric, value);
    if (!values) {
        NSString *message = [metric isEqualToString:@"stress"] ? @"本次压力测量未获得有效数据，请稍后重试" : @"戒指未返回有效测量结果，请保持正确佩戴后重试";
        [self emit:@"error" payload:@{@"code": @"MEASUREMENT_FAILED", @"message": message}];
        return;
    }
    NSString *unit = @{@"heart_rate": @"bpm", @"blood_oxygen": @"%", @"hrv": @"ms", @"body_temperature": @"℃", @"blood_pressure": @"mmHg"}[metric] ?: @"";
    [self emit:@"measurementProgress" payload:@{@"metric": metric, @"progress": @100}];
    [self emit:@"healthRecord" payload:[self record:metric date:NSDate.date values:values unit:unit origin:@"app_measurement"]];
}

- (void)stopMeasurement:(NSString *)metric result:(FlutterResult)result {
    if (self.activeMetric && ![self.activeMetric isEqualToString:metric]) { result(nil); return; }
    self.measurementGeneration++;
    QCMeasuringType type = [self measurementType:metric];
    self.activeMetric = nil;
    if (type == QCMeasuringTypeUnkown) { result(nil); return; }
    [[QCSDKManager shareInstance] stopToMeasuringWithOperateType:type completedHandle:^(__unused BOOL success, __unused NSError *error) {}];
    result(nil);
}

- (void)reconcileManualPolicy {
    NSString *metric = self.activeMetric;
    if (metric && !SRManualHealthMetricAllowed(metric)) {
        [self stopMeasurement:metric result:^(__unused id value) {}];
    }
}

- (NSInteger)sportType:(NSString *)mode {
    NSDictionary *types = @{
        @"walking": @4, @"jump_rope": @5, @"swimming": @6, @"running": @7,
        @"hiking": @8, @"cycling": @9, @"mountaineering": @20, @"badminton": @21,
        @"yoga": @22, @"indoor_cycling": @24, @"basketball": @31, @"football": @32,
        @"indoor_running": @40,
    };
    return [types[mode ?: @""] integerValue] ?: -1;
}

- (NSString *)sportMode:(NSInteger)type {
    NSDictionary *modes = @{
        @4: @"walking", @5: @"jump_rope", @6: @"swimming", @7: @"running",
        @8: @"hiking", @9: @"cycling", @20: @"mountaineering", @21: @"badminton",
        @22: @"yoga", @24: @"indoor_cycling", @31: @"basketball", @32: @"football",
        @40: @"indoor_running", @50: @"cycling", @51: @"indoor_cycling", @55: @"swimming",
        @56: @"swimming", @60: @"hiking",
    };
    return modes[@(type)];
}

- (void)startSport:(NSString *)mode result:(FlutterResult)result {
    NSInteger type = [self sportType:mode];
    if (![self isResolved] || type < 0 || self.activeMetric || self.activeSportType >= 0) {
        result([self error:@"QRING_SPORT_UNAVAILABLE" message:@"此运动模式当前无法开始"]);
        return;
    }
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator operateSportModeWithType:type state:QCSportStateStart finish:^(__unused id value, NSError *error) {
        if (error) { result([weakSelf error:@"QRING_SPORT_START_FAILED" message:@"戒指未能开始运动"]); return; }
        weakSelf.activeSportType = type;
        weakSelf.activeSportMode = mode;
        [weakSelf emit:@"sportState" payload:@{@"value": @"running", @"mode": mode ?: @""}];
        result(nil);
    }];
}

- (void)stopSport:(FlutterResult)result {
    if (self.activeSportType < 0) {
        result([self error:@"QRING_SPORT_UNAVAILABLE" message:@"当前没有正在进行的戒指运动"]);
        return;
    }
    NSInteger type = self.activeSportType;
    NSString *mode = self.activeSportMode ?: @"";
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator operateSportModeWithType:type state:QCSportStateStop finish:^(__unused id value, NSError *error) {
        if (error) { result([weakSelf error:@"QRING_SPORT_STOP_FAILED" message:@"戒指未能结束运动"]); return; }
        weakSelf.activeSportType = -1;
        weakSelf.activeSportMode = nil;
        [weakSelf emit:@"sportState" payload:@{@"value": @"stopped", @"mode": mode}];
        result(nil);
    }];
}

- (NSDictionary *)sportRecord:(OdmGeneralExerciseSummaryModel *)item {
    NSString *mode = [self sportMode:item.exerciseType];
    if (!mode || item.startTime <= 0) { return @{}; }
    NSDate *startedAt = [NSDate dateWithTimeIntervalSince1970:item.startTime];
    return @{
        @"id": [NSString stringWithFormat:@"qring:%@|sport|%ld|%.0f", self.connectedID, (long)item.exerciseType, item.startTime],
        @"mode": mode,
        @"startedAt": [self iso:startedAt],
        @"durationSeconds": @(MAX(0, item.duration)),
        @"distanceMeters": @(MAX(0, item.distance)),
        @"calories": @(MAX(0, item.calorie)),
        @"steps": @(MAX(0, item.steps)),
        @"heartRate": @(MAX(0, item.averageHR)),
        @"minimumHeartRate": @(MAX(0, item.lowestHR)),
        @"maximumHeartRate": @(MAX(0, item.highestHR)),
    };
}

- (void)readSportRecords:(FlutterResult)result {
    if ([self factoryInitializationPending]) { result([self error:@"INITIALIZATION_PENDING" message:@"戒指初始化尚未确认，历史同步已暂停"]); return; }
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    [QCSDKCmdCreator getSportRecordsFromLastTimeStamp:0 finish:^(NSArray<OdmGeneralExerciseSummaryModel *> *summaries, NSError *error) {
        if (error) { result([self error:@"QRING_SPORT_SYNC_FAILED" message:@"戒指运动记录读取失败"]); return; }
        NSMutableArray *records = [NSMutableArray array];
        for (OdmGeneralExerciseSummaryModel *item in summaries) {
            NSDictionary *record = [self sportRecord:item];
            if (record.count) { [records addObject:record]; }
        }
        result(records);
    }];
}

- (NSDate *)dayStart:(NSInteger)dayIndex {
    NSDate *today = [NSCalendar.currentCalendar startOfDayForDate:NSDate.date];
    return [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:-MAX(0, dayIndex) toDate:today options:0];
}

- (NSDate *)parseDateTime:(NSString *)value fallback:(NSDate *)fallback {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });
    return value.length ? ([formatter dateFromString:value] ?: fallback) : fallback;
}

- (NSString *)iso:(NSDate *)date {
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSISO8601DateFormatter new];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    });
    return [formatter stringFromDate:date ?: NSDate.date];
}

- (NSString *)timezone:(NSDate *)date {
    NSInteger seconds = [NSTimeZone.localTimeZone secondsFromGMTForDate:date];
    return [NSString stringWithFormat:@"%@%02ld:%02ld", seconds < 0 ? @"-" : @"+", (long)(labs(seconds) / 3600), (long)((labs(seconds) / 60) % 60)];
}

- (NSDictionary *)record:(NSString *)metric date:(NSDate *)date values:(NSDictionary *)values unit:(NSString *)unit origin:(NSString *)origin {
    NSString *scopedID = [@"qring:" stringByAppendingString:self.connectedID ?: @""];
    NSTimeInterval millis = floor(date.timeIntervalSince1970 * 1000.0);
    BOOL activity = [@[@"steps", @"distance", @"calories"] containsObject:metric];
    return @{
        @"id": [NSString stringWithFormat:@"%@|%@|%@%.0f|%@", scopedID, metric, activity ? @"v3|" : @"", millis, values],
        @"type": metric,
        @"values": values,
        @"unit": unit ?: @"",
        @"measuredAt": [self iso:date],
        @"timezone": [self timezone:date],
        @"deviceId": scopedID,
        @"firmwareVersion": self.firmware ?: @"",
        @"quality": @"device_reported",
        @"source": @"wearable",
        @"origin": origin ?: @"watch_history",
        @"rawVersion": activity ? @3 : @1,
        @"sourceModel": self.connectedName.length ? self.connectedName : @"QRing",
        @"sourceVendor": @"qring",
        @"sourceDeviceCategory": @"ring",
        @"sourceApp": @"say-ring",
    };
}

- (void)addSingle:(NSString *)metric date:(NSDate *)date value:(double)value unit:(NSString *)unit minimum:(double)minimum maximum:(double)maximum {
    if (!SRActivitySleepMetricAllowed(metric) || ![date isKindOfClass:NSDate.class] || [date timeIntervalSinceNow] > 300 ||
        !isfinite(value) || value < minimum || value > maximum) { return; }
    [self.syncRecords addObject:[self record:metric date:date values:@{@"value": @(value)} unit:unit origin:@"watch_history"]];
}

- (void)noteHistory:(NSString *)metric day:(NSInteger)day failed:(BOOL)failed {
    if (!SRActivitySleepMetricAllowed(metric) || day < 0 || day >= 7) return;
    if (failed) { self.syncStatuses[metric] = @"partial"; return; }
    if ([self.syncStatuses[metric] isEqual:@"partial"]) return;
    NSMutableIndexSet *days = self.syncCompletedDays[metric];
    if (!days) { days = [NSMutableIndexSet indexSet]; self.syncCompletedDays[metric] = days; }
    [days addIndex:(NSUInteger)day];
    if (days.count != 7) { self.syncStatuses[metric] = @"pending"; return; }
    BOOL hasData = NO;
    for (NSDictionary *record in self.syncRecords) if ([record[@"type"] isEqual:metric]) { hasData = YES; break; }
    self.syncStatuses[metric] = hasData ? @"complete" : @"no_data";
}

// Read the entire seven-day activity/sleep history before optional metrics.
- (void)advanceSyncDay:(NSInteger)day phase:(NSInteger)phase {
    if (phase == 0) [self syncDay:day phase:1];
    else if (phase == 1) [self syncDay:day + 1 phase:0];
    else if (phase < 6) [self syncDay:day phase:phase + 1];
    else [self syncDay:day + 1 phase:2];
}

- (void)finishTimedOutHealthSyncForGeneration:(NSUInteger)generation {
    if (!self.pendingSync || generation != self.syncGeneration) return;
    // Keep confirmed records, but never promote unfinished day ranges.
    self.syncGeneration++;
    [self finishHealthSync];
}

- (void)publishCurrentActivityFromIndex:(NSUInteger)firstRecord {
    // Surface today's real cumulative values before the remaining history.
    // Keep every slot in syncRecords for the final full-history result. Only
    // three notifications are needed, rather than one write per activity slot.
    NSMutableDictionary<NSString *, NSDictionary *> *latest = [NSMutableDictionary dictionary];
    for (NSUInteger index = firstRecord; index < self.syncRecords.count; index++) {
        NSDictionary *record = self.syncRecords[index];
        NSString *metric = record[@"type"];
        if (![@[@"steps", @"distance", @"calories"] containsObject:metric]) { continue; }
        NSDictionary *previous = latest[metric];
        if (!previous || [record[@"measuredAt"] compare:previous[@"measuredAt"]] == NSOrderedDescending) {
            latest[metric] = record;
        }
    }
    NSUInteger generation = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    QRingOnMain(^{
        if (![weakSelf isCurrentConnection:generation]) { return; }
        for (NSString *metric in @[@"steps", @"distance", @"calories"]) {
            if (latest[metric]) { [weakSelf emit:@"healthRecord" payload:latest[metric]]; }
        }
    });
}

- (void)syncHealth:(FlutterResult)result {
    if ([self factoryInitializationPending]) { result([self error:@"INITIALIZATION_PENDING" message:@"戒指初始化尚未确认，历史同步已暂停"]); return; }
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    if (self.activeMetric) { result([self error:@"MEASUREMENT_ACTIVE" message:@"测量中，请稍后同步"]); return; }
    if (self.pendingSync) { result([self error:@"SYNC_BUSY" message:@"戒指数据正在同步"]); return; }
    self.pendingSync = result;
    NSUInteger generation = ++self.syncGeneration;
    [self.syncRecords removeAllObjects];
    self.syncStatuses = [NSMutableDictionary dictionary];
    self.syncCompletedDays = [NSMutableDictionary dictionary];
    for (NSString *metric in [self capabilities][@"metrics"]) {
        if (SRActivitySleepMetricAllowed(metric)) self.syncStatuses[metric] = @"pending";
    }
    [self syncDay:0 phase:0];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [weakSelf finishTimedOutHealthSyncForGeneration:generation];
    });
}

- (void)syncDay:(NSInteger)day phase:(NSInteger)phase {
    if (!self.pendingSync) { return; }
    if (day >= 7) {
        if (phase == 0) [self syncDay:0 phase:2];
        else [self finishHealthSync];
        return;
    }
    if (phase >= 7) { [self syncDay:day + 1 phase:2]; return; }
    NSString *metric = @[@"steps", @"sleep", @"heart_rate", @"blood_oxygen", @"stress", @"hrv", @"body_temperature"][phase];
    if (!SRActivitySleepMetricAllowed(metric)) { [self advanceSyncDay:day phase:phase]; return; }
    NSInteger progressIndex = phase < 2 ? day * 2 + phase : 14 + day * 5 + phase - 2;
    [self emit:@"syncProgress" payload:@{@"deviceId": self.connectedID, @"progress": @(MIN(0.98, progressIndex / 49.0))}];
    __weak typeof(self) weakSelf = self;
    NSUInteger syncGeneration = self.syncGeneration;
    NSUInteger phaseGeneration = ++self.syncPhaseGeneration;
    NSUInteger connectionGeneration = self.connectionGeneration;
    BOOL (^current)(void) = ^BOOL {
        return weakSelf.pendingSync && syncGeneration == weakSelf.syncGeneration &&
            phaseGeneration == weakSelf.syncPhaseGeneration && [weakSelf isCurrentConnection:connectionGeneration];
    };
    switch (phase) {
        case 0: {
            [QCSDKCmdCreator getSportDetailDataByDay:day sportDatas:^(NSArray<QCSportModel *> *sports) {
                if (!current()) { return; }
                NSUInteger firstRecord = weakSelf.syncRecords.count;
                NSMutableArray *slots = [NSMutableArray array];
                for (QCSportModel *item in sports) {
                    NSDate *date = [weakSelf parseDateTime:item.happenDate fallback:nil];
                    if (date) { [slots addObject:@{@"date": date, @"steps": @(item.totalStepCount), @"distance": @(item.distance), @"calories": @(item.calories)}]; }
                }
                NSDate *begin = [weakSelf dayStart:day];
                NSDate *end = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:begin options:0];
                for (NSDictionary *sample in QRingCumulativeActivitySamples(slots, begin, end, NSDate.date)) {
                    [weakSelf addSingle:@"steps" date:sample[@"date"] value:[sample[@"steps"] doubleValue] unit:@"步" minimum:0 maximum:1000000];
                    [weakSelf addSingle:@"distance" date:sample[@"date"] value:[sample[@"distance"] doubleValue] unit:@"km" minimum:0 maximum:10000];
                    [weakSelf addSingle:@"calories" date:sample[@"date"] value:[sample[@"calories"] doubleValue] unit:@"kcal" minimum:0 maximum:100000];
                }
                for (NSString *activity in @[@"steps", @"distance", @"calories"]) [weakSelf noteHistory:activity day:day failed:NO];
                if (day == 0) { [weakSelf publishCurrentActivityFromIndex:firstRecord]; }
                [weakSelf advanceSyncDay:day phase:0];
            } fail:^{ if (current()) {
                for (NSString *activity in @[@"steps", @"distance", @"calories"]) [weakSelf noteHistory:activity day:day failed:YES];
                [weakSelf advanceSyncDay:day phase:0];
            } }];
            break;
        }
        case 1: {
            NSDictionary *requestDay = QRingSleepRequestContext([self dayStart:day], NSTimeZone.localTimeZone);
            NSDate *date = requestDay[@"dayStart"];
            NSString *sdkDate = requestDay[@"sdkDate"], *timezone = requestDay[@"timezone"];
            NSString *scopedId = [@"qring:" stringByAppendingString:self.connectedID ?: @""];
            NSDateFormatter *sleepFormatter = [NSDateFormatter new];
            sleepFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            sleepFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            sleepFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:[requestDay[@"offsetSeconds"] integerValue]];
            [QCSDKCmdCreator getFulldaySleepDetailDataByDay:day sleepDatas:^(NSArray<QCSleepModel *> *sleeps, NSArray<QCSleepModel *> *naps) {
                if (!current()) { return; }
                NSMutableArray *nightSegments = [NSMutableArray array], *napSegments = [NSMutableArray array];
                BOOL malformed = NO;
                for (NSInteger category = 0; category < 2; category++) {
                    NSArray *models = category == 0 ? (sleeps ?: @[]) : (naps ?: @[]);
                    NSMutableArray *target = category == 0 ? nightSegments : napSegments;
                    for (QCSleepModel *item in models) {
                        NSString *rawBegin = item.realBeginTime ?: @"", *rawEnd = item.realEndTime ?: @"";
                        NSDate *begin = rawBegin.length ? [sleepFormatter dateFromString:rawBegin] : nil;
                        NSDate *end = rawEnd.length ? [sleepFormatter dateFromString:rawEnd] : nil;
                        if (!begin || !end || [end compare:begin] != NSOrderedDescending ||
                            [end timeIntervalSinceDate:begin] > 86400 || [end timeIntervalSinceNow] > 300) { malformed = YES; }
                        [target addObject:@{@"type": @(item.type), @"begin": begin ?: (id)NSNull.null,
                                             @"end": end ?: (id)NSNull.null, @"minutes": @(item.realEffectiveMinutes),
                                             @"rawBegin": rawBegin, @"rawEnd": rawEnd,
                                             @"happenDate": item.happenDate ?: @"", @"endTime": item.endTime ?: @"",
                                             @"total": @(item.total), @"start": @(item.start), @"endMinutes": @(item.end),
                                             @"dataTypes": item.dataTypes ?: @"", @"dataMinutes": item.dataMinutes ?: @"",
                                             @"effectiveMinutes": @(item.effectiveMinutes), @"sleepQa": item.sleepQa ?: @"",
                                             @"dataType": @(item.dataType), @"isMidday": @(item.isMidday)}];
                    }
                }
                NSDictionary *timeline = QRingSleepTimeline(nightSegments, napSegments, scopedId, sdkDate,
                                                            timezone, NSDate.date);
                malformed = malformed || QRingSleepTimelineHasConflictingSessions(timeline);
                NSMutableArray *segments = [NSMutableArray arrayWithArray:nightSegments];
                [segments addObjectsFromArray:napSegments];
                NSDictionary *values = QRingSleepStageValues(segments);
                if (!malformed && values) {
                    NSMutableDictionary *record = [[weakSelf record:@"sleep" date:date values:values unit:@"h" origin:@"watch_history"] mutableCopy];
                    NSData *identity = [NSJSONSerialization dataWithJSONObject:@{@"device": scopedId, @"date": sdkDate, @"values": values}
                                                                        options:NSJSONWritingSortedKeys error:nil];
                    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
                    CC_SHA256(identity.bytes, (CC_LONG)identity.length, digest);
                    NSMutableString *identifier = [NSMutableString stringWithString:@"qring-sleep-v2-"];
                    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) { [identifier appendFormat:@"%02x", digest[index]]; }
                    record[@"id"] = identifier;
                    record[@"rawVersion"] = @2;
                    record[@"timezone"] = timezone;
                    record[@"sleepTimeline"] = timeline;
                    [weakSelf.syncRecords addObject:record];
                }
                NSMutableDictionary *status = [@{@"deviceId": scopedId, @"sdkDate": sdkDate,
                                                  @"status": malformed ? @"failed" : (segments.count ? @"complete" : @"noData")} mutableCopy];
                if (!malformed) { status[@"sleepTimeline"] = timeline; }
                [weakSelf emit:@"sleepReadStatus" payload:status];
                [weakSelf noteHistory:@"sleep" day:day failed:malformed];
                [weakSelf advanceSyncDay:day phase:1];
            } fail:^{
                if (!current()) { return; }
                [weakSelf emit:@"sleepReadStatus" payload:@{@"deviceId": scopedId, @"sdkDate": sdkDate, @"status": @"failed"}];
                [weakSelf noteHistory:@"sleep" day:day failed:YES];
                [weakSelf advanceSyncDay:day phase:1];
            }];
            break;
        }
        case 2: {
            [QCSDKCmdCreator getSchedualHeartRateDataWithDayIndexs:@[@(day)] success:^(NSArray<QCSchedualHeartRateModel *> *models) {
                if (!current()) { return; }
                for (QCSchedualHeartRateModel *model in models) {
                    if (![model isKindOfClass:QCSchedualHeartRateModel.class]) { [weakSelf noteHistory:@"heart_rate" day:day failed:YES]; continue; }
                    NSDate *base = [model.date isKindOfClass:NSString.class] ? [weakSelf parseDateTime:[model.date stringByAppendingString:@" 00:00:00"] fallback:nil] : nil;
                    NSInteger seconds = model.secondInterval;
                    if (!base || seconds < 1 || seconds > 86400 || ![model.heartRates isKindOfClass:NSArray.class]) { [weakSelf noteHistory:@"heart_rate" day:day failed:YES]; continue; }
                    [model.heartRates enumerateObjectsUsingBlock:^(NSNumber *number, NSUInteger index, BOOL *stop) {
                        if (![number isKindOfClass:NSNumber.class] || index * seconds >= 86400) return;
                        [weakSelf addSingle:@"heart_rate" date:[base dateByAddingTimeInterval:index * seconds] value:number.doubleValue unit:@"bpm" minimum:20 maximum:300];
                    }];
                }
                [weakSelf noteHistory:@"heart_rate" day:day failed:NO];
                [weakSelf advanceSyncDay:day phase:2];
            } fail:^{ if (current()) { [weakSelf noteHistory:@"heart_rate" day:day failed:YES]; [weakSelf advanceSyncDay:day phase:2]; } }];
            break;
        }
        case 3: {
            if (![self feature:QCBandFeatureBloodOxygen]) { [self advanceSyncDay:day phase:3]; return; }
            [QCSDKCmdCreator getBloodOxygenDataByDayIndex:day finished:^(NSArray *values, NSError *error) {
                if (!current()) { return; }
                BOOL malformed = error != nil;
                if (!error) for (id value in values) {
                    // Bare numbers do not establish observation timestamps.
                    if (![value isKindOfClass:QCBloodOxygenModel.class] || ![(QCBloodOxygenModel *)value date]) { malformed = YES; continue; }
                    [weakSelf addSingle:@"blood_oxygen" date:[value date] value:[(QCBloodOxygenModel *)value soa2] unit:@"%" minimum:50 maximum:100];
                }
                [weakSelf noteHistory:@"blood_oxygen" day:day failed:malformed];
                [weakSelf advanceSyncDay:day phase:3];
            }];
            break;
        }
        case 4: {
            if (![self feature:QCBandFeatureStress]) { [self advanceSyncDay:day phase:4]; return; }
            [QCSDKCmdCreator getPressureSamplesWithDayIndexes:@[@(day)] finished:^(NSArray<QCPressureDayModel *> *days, NSError *error) {
                if (!current()) { return; }
                if (!error) for (QCPressureDayModel *model in days) {
                    for (QCPressureSampleModel *sample in model.samples) {
                        [weakSelf addSingle:@"stress" date:sample.time value:sample.value unit:@"" minimum:1 maximum:100];
                    }
                }
                [weakSelf noteHistory:@"stress" day:day failed:error != nil];
                [weakSelf advanceSyncDay:day phase:4];
            }];
            break;
        }
        case 5: {
            if (![self feature:QCBandFeatureHRV]) { [self advanceSyncDay:day phase:5]; return; }
            [QCSDKCmdCreator getHRVSamplesWithDayIndexes:@[@(day)] finished:^(NSArray<QCHRVDayModel *> *days, NSError *error) {
                if (!current()) { return; }
                if (!error) for (QCHRVDayModel *model in days) {
                    for (QCHRVSampleModel *sample in model.samples) {
                        [weakSelf addSingle:@"hrv" date:sample.time value:sample.value unit:@"ms" minimum:1 maximum:1000];
                    }
                }
                [weakSelf noteHistory:@"hrv" day:day failed:error != nil];
                [weakSelf advanceSyncDay:day phase:5];
            }];
            break;
        }
        case 6: {
            if (![self feature:QCBandFeatureTemperature]) { [self advanceSyncDay:day phase:6]; return; }
            [QCSDKCmdCreator getSchedualTemperatureDataByDayIndex:day finished:^(NSArray *values, NSError *error) {
                if (!current()) { return; }
                BOOL malformed = error != nil;
                if (!error) for (id value in values) {
                    if (![value isKindOfClass:QCTemperatureModel.class] || ![(QCTemperatureModel *)value time]) { malformed = YES; continue; }
                    [weakSelf addSingle:@"body_temperature" date:[(QCTemperatureModel *)value time] value:[(QCTemperatureModel *)value temperature] unit:@"℃" minimum:20 maximum:45];
                }
                [weakSelf noteHistory:@"body_temperature" day:day failed:malformed];
                [weakSelf advanceSyncDay:day phase:6];
            }];
            break;
        }
        default: [self advanceSyncDay:day phase:6]; break;
    }
}

- (void)finishHealthSync {
    FlutterResult result = self.pendingSync;
    self.pendingSync = nil;
    for (NSString *metric in self.syncStatuses.allKeys) {
        if ([self.syncStatuses[metric] isEqual:@"pending"]) self.syncStatuses[metric] = @"partial";
    }
    if (result) { result(@{@"records": self.syncRecords.copy, @"statuses": self.syncStatuses.copy ?: @{}}); }
}

- (void)readAutoSettings:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator getSchedualHeartRateInfoWithSuccess:^(BOOL enabled, __unused NSInteger interval, __unused NSInteger minimum, __unused NSInteger low, __unused NSInteger high) {
        values[@"heartRate"] = @(enabled);
        [QCSDKCmdCreator getSchedualBOInfoSuccess:^(BOOL oxygen) {
            if ([weakSelf feature:QCBandFeatureBloodOxygen]) { values[@"bloodOxygen"] = @(oxygen); }
            [QCSDKCmdCreator getSchedualStressStatusWithFinshed:^(BOOL stress, NSError *stressError) {
                if (!stressError && [weakSelf feature:QCBandFeatureStress]) { values[@"stress"] = @(stress); }
                [QCSDKCmdCreator getSchedualHRVWithFinshed:^(BOOL hrv, NSError *hrvError) {
                    if (!hrvError && [weakSelf feature:QCBandFeatureHRV]) { values[@"hrv"] = @(hrv); }
                    result(values);
                }];
            }];
        } fail:^{ result(values); }];
    } fail:^{ result(values); }];
}

// The SDK documents minutes and a device-reported minimum. Never guess an
// interval from historical sample spacing. The newer `interval:` overload
// serializes a zero minimum/reserved byte (and its short form zeroes tips).
// The documented `timeInterval:` selector writes only enable/interval; verify
// a fresh complete response so firmware constraints and tips remain intact.
- (void)monitoringInterval:(NSNumber *)minutes type:(NSString *)type enabled:(NSNumber *)desiredEnabled result:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    if (self.monitoringPoisonGeneration == self.connectionGeneration) { result([self error:@"QRING_SETTING_UNCONFIRMED" message:@"请重新连接后读取监测设置"]); return; }
    if ((minutes || desiredEnabled) && (![type isEqualToString:@"heartRate"] || (minutes && (![minutes isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)minutes) == CFBooleanGetTypeID() ||
        minutes.doubleValue != minutes.integerValue || minutes.integerValue < 1 || minutes.integerValue > 255)))) {
        result([self error:@"UNSUPPORTED" message:@"此监测间隔未获戒指确认"]); return;
    }
    NSUInteger connection = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    __block BOOL done = NO;
    __block void (^readback)(NSInteger) = nil;
    void (^finish)(id) = ^(id value) {
        if (NSThread.isMainThread) {
            if (done) return;
            done = YES;
            readback = nil;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ result(value); });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (done) return;
                done = YES;
                readback = nil;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ result(value); });
            });
        }
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!done && [weakSelf isCurrentConnection:connection]) weakSelf.monitoringPoisonGeneration = connection;
        finish([weakSelf error:@"QRING_SETTING_TIMEOUT" message:@"监测设置未确认，请重连后刷新"]);
    });
    [QCSDKCmdCreator getSchedualHeartRateInfoWithSuccess:^(BOOL enabled, NSInteger interval, NSInteger minimum, NSInteger low, NSInteger high) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            if (done) return;
            if (![weakSelf isCurrentConnection:connection]) { finish([weakSelf error:@"QRING_SESSION_CHANGED" message:@"戒指连接已改变"]); return; }
            if (minimum < 1 || minimum > 255 || interval < minimum || interval > 255) {
                finish((minutes || desiredEnabled) ? [weakSelf error:@"UNSUPPORTED" message:@"戒指未返回有效监测间隔"] : @{}); return;
            }
            if (!minutes && !desiredEnabled) {
                finish(@{@"heartRate": @{@"minutes": @(interval), @"stepMinutes": @1,
                    @"minMinutes": @(minimum), @"maxMinutes": @255, @"canModify": @YES}}); return;
            }
            if ((minutes && !enabled) || (minutes && minutes.integerValue < minimum)) {
                finish([weakSelf error:@"UNSUPPORTED" message:@"请先开启监测并选择戒指允许的间隔"]); return;
            }
            BOOL expectedEnabled = desiredEnabled ? desiredEnabled.boolValue : enabled;
            NSInteger expectedInterval = minutes ? minutes.integerValue : interval;
            [QCSDKCmdCreator setSchedualHeartRateStatus:expectedEnabled timeInterval:expectedInterval success:^ {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (done) return;
                    if (![weakSelf isCurrentConnection:connection]) { finish([weakSelf error:@"QRING_SESSION_CHANGED" message:@"戒指连接已改变"]); return; }
                    // This SDK also accepts a delayed write ACK as a read
                    // response, yielding its default all-zero fields. Let the
                    // prior command retire, then require a real complete read.
                    readback = ^(NSInteger retries) {
                        if (done || ![weakSelf isCurrentConnection:connection]) return;
                        [QCSDKCmdCreator getSchedualHeartRateInfoWithSuccess:^(BOOL confirmed, NSInteger saved, NSInteger savedMinimum, NSInteger savedLow, NSInteger savedHigh) {
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                                if (done) return;
                                if (![weakSelf isCurrentConnection:connection]) { finish([weakSelf error:@"QRING_SESSION_CHANGED" message:@"戒指连接已改变"]); return; }
                                BOOL matches = confirmed == expectedEnabled && saved == expectedInterval && savedMinimum == minimum && savedLow == low && savedHigh == high;
                                if (!matches && retries > 0) {
                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ if (!done && readback) readback(retries - 1); });
                                    return;
                                }
                                if (matches) { finish(nil); }
                                else finish([FlutterError errorWithCode:@"READBACK_MISMATCH" message:@"戒指返回的监测配置与设置不一致，请刷新后重试" details:@{
                                    @"before": @{@"enabled": @(enabled), @"minutes": @(interval), @"minimum": @(minimum), @"lowTip": @(low), @"highTip": @(high)},
                                    @"expected": @{@"enabled": @(expectedEnabled), @"minutes": @(expectedInterval)},
                                    @"actual": @{@"enabled": @(confirmed), @"minutes": @(saved), @"minimum": @(savedMinimum), @"lowTip": @(savedLow), @"highTip": @(savedHigh)}
                                }]);
                            });
                        } fail:^{ finish([weakSelf error:@"QRING_SETTING_FAILED" message:@"监测设置读回失败"]); }];
                    };
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ if (!done && readback) readback(2); });
                });
            } fail:^{ finish([weakSelf error:@"QRING_SETTING_FAILED" message:@"监测间隔写入失败"]); }];
        });
    } fail:^{ finish((minutes || desiredEnabled) ? [weakSelf error:@"QRING_SETTING_FAILED" message:@"监测间隔读取失败"] : @{}); }];
}

- (void)setAutoSetting:(NSString *)type enabled:(BOOL)enabled result:(FlutterResult)result {
    if ([type isEqualToString:@"heartRate"]) {
        [self monitoringInterval:nil type:type enabled:@(enabled) result:result];
    } else if ([type isEqualToString:@"bloodOxygen"] && [self feature:QCBandFeatureBloodOxygen]) {
        [QCSDKCmdCreator setSchedualBOInfoOn:enabled success:^(__unused BOOL state) { result(nil); } fail:^{ result([self error:@"QRING_SETTING_FAILED" message:@"自动血氧设置失败"]); }];
    } else if ([type isEqualToString:@"stress"] && [self feature:QCBandFeatureStress]) {
        [QCSDKCmdCreator setSchedualStressStatus:enabled finshed:^(NSError *error) { result(error ? [self error:@"QRING_SETTING_FAILED" message:@"自动压力设置失败"] : nil); }];
    } else if ([type isEqualToString:@"hrv"] && [self feature:QCBandFeatureHRV]) {
        [QCSDKCmdCreator setSchedualHRVStatus:enabled finshed:^(NSError *error) { result(error ? [self error:@"QRING_SETTING_FAILED" message:@"自动 HRV 设置失败"] : nil); }];
    } else {
        result([self error:@"QRING_FEATURE_UNVERIFIED" message:@"此自动检测项目未获戒指确认"]);
    }
}

// Photo UI ACKs verify the session protocol; HID photo flags describe a
// different, persistent control mode and must not gate shake-to-shoot.
- (void)probeRemoteCamera:(QRingNext)completion {
    RingControlTrace(@"probe-start", @{@"gesture": @([self cameraFlag:QCBandFeatureGestureControl]), @"touch": @([self cameraFlag:QCBandFeatureTouchControl]), @"screenTouch": @([self cameraFlag:QCBandFeatureTouchControlOfScreenDevice]), @"generation": @(self.connectionGeneration)});
    self.remoteCameraSupported = NO;
    NSUInteger connection = self.connectionGeneration;
    NSUInteger operation = ++self.cameraOperation;
    __block BOOL done = NO;
    __weak typeof(self) weakSelf = self;
    QRingNext finish = ^{
        if (done || operation != weakSelf.cameraOperation || ![weakSelf isCurrentConnection:connection]) { return; }
        done = YES;
        weakSelf.cameraOperation++;
        completion();
    };
    if (![self cameraFlag:QCBandFeatureGestureControl] && ![self cameraFlag:QCBandFeatureTouchControl]) {
        finish(); return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!done && operation == weakSelf.cameraOperation) {
            RingControlTrace(@"probe-timeout", @{@"generation": @(connection)});
            weakSelf.cameraPoisonGeneration = connection;
            finish();
        }
    });
    void (^exit)(BOOL) = ^(BOOL accepted) {
        RingControlTrace(@"probe-enter", @{@"accepted": @(accepted), @"generation": @(connection)});
        // Always defer past the SDK's callback queue cleanup.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done || operation != weakSelf.cameraOperation || ![weakSelf isCurrentConnection:connection]) { return; }
            [QCSDKCmdCreator stopTakingPhotoSuccess:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (done || operation != weakSelf.cameraOperation || ![weakSelf isCurrentConnection:connection]) { return; }
                    weakSelf.remoteCameraSupported = accepted;
                    RingControlTrace(@"probe-exit-confirmed", @{@"generation": @(connection)});
                    finish();
                });
            } fail:^{ dispatch_async(dispatch_get_main_queue(), finish); }];
        });
    };
    [QCSDKCmdCreator switchToPhotoUISuccess:^{ exit(YES); } fail:^{ exit(NO); }];
}

- (void)resetRemoteCamera {
    BOOL wasActive = self.remoteCameraActive;
    self.remoteCameraActive = NO;
    self.remoteCameraEpoch++;
    [NSNotificationCenter.defaultCenter removeObserver:self name:OdmBandTakePictureNotification object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:OdmBandStopTakingPictureNotification object:nil];
    if (wasActive && self.connectedID.length) {
        [self emit:@"cameraRemoteStopped" payload:@{@"deviceId": self.connectedID}];
    }
}

- (void)stopRemoteCamera:(FlutterResult)result {
    [self resetRemoteCamera];
    [self waitToStopCamera:result connection:self.connectionGeneration deadline:NSProcessInfo.processInfo.systemUptime + 8];
}

- (void)waitToStopCamera:(FlutterResult)result connection:(NSUInteger)connection deadline:(NSTimeInterval)deadline {
    if (![self isCurrentConnection:connection] || ![self isResolved]) { result(nil); return; }
    if (self.pendingCamera && NSProcessInfo.processInfo.systemUptime < deadline) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 10), dispatch_get_main_queue(), ^{
            [weakSelf waitToStopCamera:result connection:connection deadline:deadline];
        });
        return;
    }
    [self remoteCameraAction:6 result:result];
}

- (void)cameraShutter:(NSNotification *)notification {
    // Capture the epoch before hopping threads so queued notifications cannot
    // become a shutter for a new session after backgrounding or reconnection.
    NSUInteger epoch = self.remoteCameraEpoch;
    NSUInteger connection = self.connectionGeneration;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.remoteCameraActive || epoch != self.remoteCameraEpoch || ![self isCurrentConnection:connection]) { return; }
        [self emit:@"cameraShutter" payload:@{@"deviceId": self.connectedID}];
    });
}

- (void)cameraStopped:(NSNotification *)notification {
    NSUInteger epoch = self.remoteCameraEpoch;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (epoch == self.remoteCameraEpoch) { [self resetRemoteCamera]; }
    });
}

- (void)scheduleCameraKeepAlive:(NSUInteger)epoch {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (epoch != weakSelf.remoteCameraEpoch || !weakSelf.remoteCameraActive || ![weakSelf isResolved]) { return; }
        [weakSelf remoteCameraAction:5 result:^(id value) {
            if ([value isKindOfClass:FlutterError.class]) { [weakSelf resetRemoteCamera]; }
            else if (epoch == weakSelf.remoteCameraEpoch) { [weakSelf scheduleCameraKeepAlive:epoch]; }
        }];
    });
}

- (void)remoteCameraAction:(NSInteger)action result:(FlutterResult)result {
    BOOL entering = action == 4;
    if (action == 6) { [self resetRemoteCamera]; }
    if (![self isResolved] || (entering && !self.remoteCameraSupported)) {
        result(entering ? [self error:@"QRING_FEATURE_UNVERIFIED" message:@"此戒指未确认支持相机遥控"] : nil); return;
    }
    if (self.pendingCamera || self.pendingSync || self.readingDetails || self.activeMetric || self.activeSportType >= 0) {
        result([self error:@"DEVICE_BUSY" message:@"设备忙，请稍后重试"]); return;
    }
    if (self.cameraPoisonGeneration == self.connectionGeneration) {
        result([self error:@"QRING_CONTROL_UNCONFIRMED" message:@"相机遥控未确认，请重新连接"]); return;
    }
    self.pendingCamera = result;
    NSUInteger operation = ++self.cameraOperation;
    NSUInteger connection = self.connectionGeneration;
    NSUInteger epoch = self.remoteCameraEpoch;
    __weak typeof(self) weakSelf = self;
    BOOL (^current)(void) = ^BOOL{
        return weakSelf.pendingCamera && operation == weakSelf.cameraOperation && [weakSelf isCurrentConnection:connection];
    };
    QRingNext success = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!current()) { return; }
            if (entering && epoch == weakSelf.remoteCameraEpoch) {
                weakSelf.remoteCameraActive = YES;
                [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(cameraShutter:) name:OdmBandTakePictureNotification object:nil];
                [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(cameraStopped:) name:OdmBandStopTakingPictureNotification object:nil];
                [weakSelf scheduleCameraKeepAlive:epoch];
            }
            [weakSelf finishCamera:nil];
        });
    };
    QRingNext fail = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!current()) { return; }
            [weakSelf resetRemoteCamera];
            [weakSelf finishCamera:[weakSelf error:@"QRING_ACTION_FAILED" message:@"相机遥控未开启，请重试"]];
        });
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!current()) { return; }
        weakSelf.cameraPoisonGeneration = connection;
        [weakSelf resetRemoteCamera];
        [weakSelf finishCamera:[weakSelf error:@"QRING_CONTROL_UNCONFIRMED" message:@"相机遥控未确认，请重新连接"]];
    });
    if (action == 4) { [QCSDKCmdCreator switchToPhotoUISuccess:success fail:fail]; }
    else if (action == 5) { [QCSDKCmdCreator holdPhotoUISuccess:success fail:fail]; }
    else { [QCSDKCmdCreator stopTakingPhotoSuccess:success fail:fail]; }
}

- (BOOL)cameraFlag:(NSString *)key {
    id value = self.featureList[key];
    return [value isKindOfClass:NSNumber.class] && [value doubleValue] == 1;
}

- (BOOL)supportsCamera {
    return [self isResolved] && [self cameraFlag:QCBandFeatureGestureControlTakePhoto] &&
        ([self cameraFlag:QCBandFeatureGestureControl] || [self cameraFlag:QCBandFeatureTouchControl]);
}

- (BOOL)supportsGesture {
    return [self isResolved] && ([self cameraFlag:QCBandFeatureGestureControl] ||
        [self cameraFlag:QCBandFeatureTouchControl]);
}

- (NSArray *)gestureModes {
    NSMutableArray *modes = [NSMutableArray arrayWithObject:@0];
    NSArray *flags = @[QCBandFeatureGestureControlVideo, QCBandFeatureGestureControlMusic,
        QCBandFeatureGestureControlEBook, QCBandFeatureGestureControlTakePhoto,
        QCBandFeatureGestureControlPhoneCall];
    for (NSUInteger index = 0; index < flags.count; index++) {
        if ([self cameraFlag:flags[index]]) { [modes addObject:@(index + 1)]; }
    }
    return modes;
}

- (void)gestureControl:(NSDictionary *)arguments write:(BOOL)write result:(FlutterResult)result {
    RingControlTrace(@"gesture-start", @{@"write": @(write), @"generation": @(self.connectionGeneration), @"poisoned": @(self.cameraPoisonGeneration == self.connectionGeneration), @"pendingSync": @(self.pendingSync != nil), @"pendingConnect": @(self.pendingConnect != nil), @"pendingCamera": @(self.pendingCamera != nil), @"readingDetails": @(self.readingDetails)});
    if (![self supportsGesture]) {
        result([self error:@"QRING_FEATURE_UNVERIFIED" message:@"此戒指未确认支持手势控制"]); return;
    }
    NSDictionary *values = [arguments[@"values"] isKindOfClass:NSDictionary.class] ? arguments[@"values"] : @{};
    id mode = values[@"mode"], expectedMode = values[@"expectedMode"];
    NSArray *modes = [self gestureModes];
    BOOL (^integer)(id) = ^BOOL(id value) {
        return [value isKindOfClass:NSNumber.class] &&
            CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID() &&
            [value doubleValue] == [value integerValue];
    };
    if (write && (!integer(mode) || ![modes containsObject:mode] || !integer(expectedMode) ||
        [expectedMode integerValue] < 0 || [expectedMode integerValue] > 9)) {
        result([self error:@"INVALID_GESTURE_MODE" message:@"请刷新后选择戒指支持的手势模式"]); return;
    }
    if (self.pendingCamera || self.pendingConnect || self.pendingSync || self.readingDetails ||
        self.activeMetric || self.activeSportType >= 0) {
        result([self error:@"DEVICE_BUSY" message:@"设备忙，请稍后重试"]); return;
    }
    if (self.cameraPoisonGeneration == self.connectionGeneration) {
        result([self error:@"QRING_CONTROL_RECONNECT" message:@"手势状态未确认，请重新连接"]); return;
    }
    // Share the control operation slot with HID camera and Photo UI commands.
    self.pendingCamera = result;
    self.cameraPhase = 0;
    NSUInteger operation = ++self.cameraOperation, connection = self.connectionGeneration;
    BOOL touch = ![self cameraFlag:QCBandFeatureGestureControl];
    NSInteger expected = write ? QRingGestureRawMode([mode integerValue]) : -1;
    __weak typeof(self) weakSelf = self;
    BOOL (^current)(void) = ^BOOL {
        return weakSelf.pendingCamera && operation == weakSelf.cameraOperation &&
            [weakSelf isCurrentConnection:connection];
    };
    __block void (^readback)(NSInteger);
    void (^finish)(id) = ^(id value) {
        readback = nil;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            if (current()) { [weakSelf finishCamera:value]; }
        });
    };
    void (^fail)(void) = ^{
        readback = nil; // Also release retry captures after cancellation/disconnect.
        if (!current()) { return; }
        weakSelf.cameraPoisonGeneration = connection;
        finish([weakSelf error:@"QRING_CONTROL_UNCONFIRMED" message:@"手势状态未确认，请重新连接"]);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), fail);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (!current()) { return; }
        [weakSelf readCameraTouch:touch completion:^(NSDictionary *snapshot, NSError *error) {
            if (!current() || weakSelf.cameraPhase != 0) { return; }
            if (error || !snapshot) { fail(); return; }
            if (!write) { finish(QRingGestureSnapshot(snapshot, modes)); return; }
            if (![snapshot[@"mode"] isEqual:expectedMode]) {
                finish([weakSelf error:@"QRING_CONTROL_CHANGED" message:@"戒指控制模式已改变，请刷新"]); return;
            }
            NSInteger strength = [snapshot[@"strength"] integerValue];
            NSInteger duration = [snapshot[@"duration"] integerValue];
            weakSelf.cameraPhase = 1;
            __block NSDictionary *confirmedReadback = nil;
            readback = ^(NSInteger attempt) {
                if (!current() || weakSelf.cameraPhase != 2) { readback = nil; return; }
                [weakSelf readCameraTouch:touch completion:^(NSDictionary *actual, NSError *readError) {
                    if (!current() || weakSelf.cameraPhase != 2) { readback = nil; return; }
                    BOOL matches = !readError && QRingGestureReadbackMatches(snapshot, actual, expected);
                    // The SDK's setter callback is send completion, not device
                    // confirmation. Require two equal independent reads so a
                    // delayed write response cannot alone confirm the setting.
                    if (matches && [confirmedReadback isEqualToDictionary:actual]) {
                        readback = nil; finish(nil); return;
                    }
                    confirmedReadback = matches ? [actual copy] : nil;
                    if (attempt >= 2) { readback = nil; fail(); return; }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                        if (readback) { readback(attempt + 1); }
                    });
                }];
            };
            void (^ack)(NSError *) = ^(NSError *writeError) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                    if (!current() || weakSelf.cameraPhase != 1) { readback = nil; return; }
                    if (writeError) { readback = nil; fail(); return; }
                    weakSelf.cameraPhase = 2;
                    if (readback) { readback(0); }
                });
            };
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                if (!current() || weakSelf.cameraPhase != 1) { readback = nil; return; }
                if (!touch) { [QCSDKCmdCreator setGestureControl:expected strength:strength finshed:ack]; }
                else if ([weakSelf cameraFlag:QCBandFeatureTouchControlOfScreenDevice]) {
                    [QCSDKCmdCreator setTouchControlOfScreenDevie:expected strength:strength duration:duration finshed:ack];
                } else { [QCSDKCmdCreator setTouchControl:expected strength:strength duration:duration finshed:ack]; }
            });
        }];
    });
}

- (void)finishCamera:(id)value {
    FlutterResult pending = self.pendingCamera;
    if (!pending) { return; }
    self.pendingCamera = nil;
    self.cameraOperation++;
    pending(value);
}

- (void)readCameraTouch:(BOOL)touch completion:(void (^)(NSDictionary *, NSError *))completion {
    BOOL screenTouch = touch && [self cameraFlag:QCBandFeatureTouchControlOfScreenDevice];
    // Start the next SDK command outside its response callback stack.
    void (^finish)(QCTouchGestureControlType, NSInteger, BOOL, NSInteger, NSError *) =
    ^(QCTouchGestureControlType mode, NSInteger strength, __unused BOOL sleeping, NSInteger duration, NSError *error) {
        RingControlTrace(@"control-snapshot", @{@"mode": @(mode), @"strength": @(strength), @"sleeping": @(sleeping), @"duration": @(duration), @"error": @(error != nil), @"errorCode": @(error.code), @"touch": @(touch), @"screenTouch": @(screenTouch), @"accepted": @(QRingCameraSnapshot(mode, strength, touch, duration, screenTouch) != nil)});
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error ? nil : QRingCameraSnapshot(mode, strength, touch, duration, screenTouch), error);
        });
    };
    if (!touch) {
        [QCSDKCmdCreator getGestureControlFinshed:^(QCTouchGestureControlType mode, NSInteger strength, BOOL sleeping, NSError *error) {
            finish(mode, strength, sleeping, 0, error);
        }];
    } else if (screenTouch) {
        [QCSDKCmdCreator getTouchControlOfScreenDevieFinshed:finish];
    } else {
        [QCSDKCmdCreator getTouchControlFinshed:finish];
    }
}

- (void)cameraControl:(NSDictionary *)arguments write:(BOOL)write result:(FlutterResult)result {
    if (![arguments[@"feature"] isEqual:@"camera"] || ![self supportsCamera]) {
        result([self error:@"QRING_FEATURE_UNVERIFIED" message:@"此戒指不支持拍照控制"]); return;
    }
    NSDictionary *values = [arguments[@"values"] isKindOfClass:NSDictionary.class] ? arguments[@"values"] : @{};
    id enabled = values[@"enabled"];
    id expectedMode = values[@"expectedMode"];
    if (write && (![enabled isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID() ||
        ![expectedMode isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)expectedMode) == CFBooleanGetTypeID() ||
        [expectedMode doubleValue] != [expectedMode integerValue] || [expectedMode integerValue] < 0 || [expectedMode integerValue] > 9)) {
        result([self error:@"INVALID_ARGUMENT" message:@"拍照设置无效"]); return;
    }
    if (self.pendingCamera || self.pendingConnect || self.pendingSync || self.readingDetails || self.activeMetric || self.activeSportType >= 0) {
        result([self error:@"DEVICE_BUSY" message:@"设备忙，请稍后重试"]); return;
    }
    if (self.cameraPoisonGeneration == self.connectionGeneration) {
        result([self error:@"QRING_CONTROL_RECONNECT" message:@"拍照状态未确认，请重新连接"]); return;
    }
    self.pendingCamera = result;
    self.cameraPhase = 0;
    NSUInteger operation = ++self.cameraOperation;
    NSUInteger connection = self.connectionGeneration;
    BOOL touch = ![self cameraFlag:QCBandFeatureGestureControl];
    __weak typeof(self) weakSelf = self;
    BOOL (^current)(void) = ^BOOL {
        return weakSelf.pendingCamera && operation == weakSelf.cameraOperation &&
            connection == weakSelf.connectionGeneration && [weakSelf isResolved];
    };
    void (^fail)(void) = ^{
        if (!current()) { return; }
        weakSelf.cameraPoisonGeneration = connection;
        [weakSelf finishCamera:[weakSelf error:@"QRING_CONTROL_UNCONFIRMED" message:@"拍照状态未确认，请重新连接"]];
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), fail);
    [self readCameraTouch:touch completion:^(NSDictionary *snapshot, NSError *error) {
        if (!current() || weakSelf.cameraPhase != 0) { return; }
        if (error || !snapshot) { fail(); return; }
        if (!write) { [weakSelf finishCamera:snapshot]; return; }
        NSInteger expected = [enabled boolValue] ? QCTouchGestureControlTypeTakePhoto : QCTouchGestureControlTypeOff;
        NSInteger mode = [snapshot[@"mode"] integerValue];
        if (mode != [expectedMode integerValue]) {
            [weakSelf finishCamera:[weakSelf error:@"QRING_CONTROL_CHANGED" message:@"戒指控制模式已改变，请刷新"]]; return;
        }
        // Disabling camera must never disable a different control selected elsewhere.
        if (![enabled boolValue] && mode != QCTouchGestureControlTypeTakePhoto && mode != QCTouchGestureControlTypeOff) {
            [weakSelf finishCamera:[weakSelf error:@"QRING_CONTROL_CHANGED" message:@"戒指控制模式已改变，请刷新"]]; return;
        }
        weakSelf.cameraPhase = 1;
        void (^finished)(NSError *) = ^(NSError *writeError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!current() || weakSelf.cameraPhase != 1) { return; }
                if (writeError) { fail(); return; }
                weakSelf.cameraPhase = 2;
                [weakSelf readCameraTouch:touch completion:^(NSDictionary *readback, NSError *readError) {
                    if (!current() || weakSelf.cameraPhase != 2) { return; }
                    if (readError || !readback || [readback[@"mode"] integerValue] != expected ||
                        ![snapshot[@"strength"] isEqual:readback[@"strength"]] ||
                        ![snapshot[@"duration"] isEqual:readback[@"duration"]]) { fail(); return; }
                    [weakSelf finishCamera:nil];
                }];
            });
        };
        NSInteger strength = [snapshot[@"strength"] integerValue];
        NSInteger duration = [snapshot[@"duration"] integerValue];
        if (!touch) {
            [QCSDKCmdCreator setGestureControl:expected strength:strength finshed:finished];
        } else if ([weakSelf cameraFlag:QCBandFeatureTouchControlOfScreenDevice]) {
            [QCSDKCmdCreator setTouchControlOfScreenDevie:expected strength:strength duration:duration finshed:finished];
        } else {
            [QCSDKCmdCreator setTouchControl:expected strength:strength duration:duration finshed:finished];
        }
    }];
}

- (void)handleCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *arguments = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};
    if ([call.method isEqualToString:@"configureManualHealthMetrics"]) {
        [self reconcileManualPolicy]; // Drain an expired operation before renewal.
        BOOL accepted = SRConfigureManualHealthLease(arguments);
        [self reconcileManualPolicy];
        NSUInteger generation = ++self.manualPolicyGeneration;
        if (accepted && [arguments[@"validForSeconds"] integerValue] > 0) {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, [arguments[@"validForSeconds"] integerValue] * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                if (generation == weakSelf.manualPolicyGeneration) [weakSelf reconcileManualPolicy];
            });
        }
        result(accepted ? nil : [self error:@"INVALID_HEALTH_POLICY" message:@"测量配置无效"]);
        return;
    }
    if ([call.method isEqualToString:@"configureReadOnlyHealthMetrics"]) {
        [self reconcileManualPolicy];
        BOOL accepted = SRConfigureReadOnlyHealthLease(arguments);
        [self reconcileManualPolicy];
        if (!accepted) {
            result([self error:@"INVALID_HEALTH_POLICY" message:@"健康数据配置无效"]);
        } else { result(nil); }
        return;
    }
    if (!SRActivitySleepCommandAllowed(call.method, arguments)) {
        result([self error:@"FEATURE_UNAVAILABLE" message:@"此功能暂未开放"]); return;
    }
    FlutterResult completion = result;
    result = ^(id value) { completion(SRActivitySleepResult(call.method, value)); };
    if ([@[@"connect", @"disconnect", @"configureRecoveryTarget"] containsObject:call.method]) {
        [self resetRemoteCamera];
        if (![call.method isEqualToString:@"configureRecoveryTarget"]) { self.remoteCameraSupported = NO; }
        [self finishCamera:[self error:@"QRING_DISCONNECTED" message:@"戒指连接已改变"]];
    }
    if ([call.method isEqualToString:@"triggerDeviceAction"] && [arguments[@"feature"] isEqualToString:@"camera"] && [arguments[@"enabled"] isEqual:@NO]) {
        [self stopRemoteCamera:result]; return;
    }
    if (self.monitoringPoisonGeneration == self.connectionGeneration &&
        [@[@"readAutoMeasureSettings", @"setAutoMeasureSetting", @"readAutoMeasureIntervals", @"setAutoMeasureInterval"] containsObject:call.method]) {
        result([self error:@"QRING_SETTING_UNCONFIRMED" message:@"请重新连接后读取监测设置"]); return;
    }
    NSSet *commands = [NSSet setWithArray:@[@"clearRingHistory", @"syncHealthData", @"startMeasurement", @"startSport", @"readSportRecords", @"readAutoMeasureSettings", @"setAutoMeasureSetting", @"readAutoMeasureIntervals", @"setAutoMeasureInterval", @"triggerDeviceAction", @"readDeviceFeature", @"writeDeviceFeature", @"pulseHealthReminder"]];
    if (([self.factoryResetGeneration isEqual:@(self.connectionGeneration)] ||
         [self.factoryInitializingGeneration isEqual:@(self.connectionGeneration)]) && [commands containsObject:call.method]) {
        result([self error:@"DEVICE_BUSY" message:@"戒指正在重置，请重新连接后继续"]); return;
    }
    if ((self.pendingCamera || self.remoteCameraActive || self.readingDetails) && [commands containsObject:call.method]) {
        result([self error:@"DEVICE_BUSY" message:@"设备忙，请稍后重试"]); return;
    }
    if ([call.method isEqualToString:@"scanDevices"]) { [self startScan:result]; }
    else if ([call.method isEqualToString:@"lookupBondedDevice"]) { result(nil); }
    else if ([call.method isEqualToString:@"listBondedDevices"]) { result(@[]); }
    else if ([call.method isEqualToString:@"prepareRememberedDevice"]) { [self prepareRememberedDevice:arguments result:result]; }
    else if ([call.method isEqualToString:@"configureRecoveryTarget"]) { [self configureRecoveryTarget:arguments result:result]; }
    else if ([call.method isEqualToString:@"stopScan"]) { [self finishScan]; result(nil); }
    else if ([call.method isEqualToString:@"connect"]) { [self connect:arguments result:result]; }
    else if ([call.method isEqualToString:@"disconnect"]) { [self disconnectWithResult:result]; }
    else if ([call.method isEqualToString:@"clearRingHistory"]) { [self resetFirstMemberRing:arguments result:result]; }
    else if ([call.method isEqualToString:@"getDeviceDetails"]) {
        if (![self isResolved]) { result(nil); return; }
        BOOL fresh = self.batteryUpdatedAt && [NSDate.date timeIntervalSinceDate:self.batteryUpdatedAt] < 15;
        if (fresh || [self.factoryInitializingGeneration isEqual:@(self.connectionGeneration)] || self.remoteCameraActive || self.pendingCamera || self.pendingConnect || self.pendingSync || self.activeMetric || self.activeSportType >= 0 || self.readingDetails) {
            result([self deviceDetails]);
        } else {
            [self readDeviceDetailsWithCompletion:^{ result([self isResolved] ? [self deviceDetails] : nil); }];
        }
    }
    else if ([call.method isEqualToString:@"getCapabilities"]) {
        [self emitFactoryInitialization];
        result([self isResolved] ? [self capabilities] : [self error:@"CAPABILITIES_UNAVAILABLE" message:@"请先连接戒指"]);
    }
    else if ([call.method isEqualToString:@"readDeviceFeature"] || [call.method isEqualToString:@"writeDeviceFeature"]) {
        BOOL write = [call.method isEqualToString:@"writeDeviceFeature"];
        if ([arguments[@"feature"] isEqual:@"gesture_control"]) { [self gestureControl:arguments write:write result:result]; }
        else { [self cameraControl:arguments write:write result:result]; }
    }
    else if ([call.method isEqualToString:@"syncHealthData"]) { [self syncHealth:result]; }
    else if ([call.method isEqualToString:@"startMeasurement"]) { [self startMeasurement:arguments[@"metric"] result:result]; }
    else if ([call.method isEqualToString:@"stopMeasurement"]) { [self stopMeasurement:arguments[@"metric"] result:result]; }
    else if ([call.method isEqualToString:@"startSport"]) { [self startSport:arguments[@"mode"] result:result]; }
    else if ([call.method isEqualToString:@"stopSport"]) { [self stopSport:result]; }
    else if ([call.method isEqualToString:@"readSportRecords"]) { [self readSportRecords:result]; }
    else if ([call.method isEqualToString:@"readAutoMeasureIntervals"]) { [self monitoringInterval:nil type:nil enabled:nil result:result]; }
    else if ([call.method isEqualToString:@"setAutoMeasureInterval"]) { [self monitoringInterval:arguments[@"minutes"] type:arguments[@"type"] enabled:nil result:result]; }
    else if ([call.method isEqualToString:@"readAutoMeasureSettings"]) { [self readAutoSettings:result]; }
    else if ([call.method isEqualToString:@"setAutoMeasureSetting"]) { [self setAutoSetting:arguments[@"type"] enabled:[arguments[@"enabled"] boolValue] result:result]; }
    else if ([call.method isEqualToString:@"triggerDeviceAction"] && [arguments[@"feature"] isEqualToString:@"camera"]) {
        [self remoteCameraAction:[arguments[@"enabled"] isEqual:@NO] ? 6 : 4 result:result];
    }
    else if ([call.method isEqualToString:@"pulseHealthReminder"]) {
        NSString *expected = [arguments[@"expectedDeviceId"] isKindOfClass:NSString.class] ? arguments[@"expectedDeviceId"] : nil;
        NSString *model = [self.connectedName.uppercaseString stringByReplacingOccurrencesOfString:@"[\\s_-]+" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, self.connectedName.length)];
        if (![self isResolved] || !expected.length || ![self.connectedID.lowercaseString isEqual:expected.lowercaseString] || ![model containsString:@"R8PRO"] || [model hasPrefix:@"R1"] || [model hasPrefix:@"R2"] || [model containsString:@"R7C"] || self.pendingSync || self.activeMetric) {
            result([self error:@"HAPTIC_UNAVAILABLE" message:@"此戒指暂不支持振动提醒"]); return;
        }
        NSUInteger generation = self.connectionGeneration;
        // This SDK exposes a single lookup event, not an ON/OFF switch.
        // Sending a second "OFF" lookup would issue a second physical alert.
        [QCSDKCmdCreator lookupDeviceSuccess:^{
            if (generation != self.connectionGeneration || ![self.connectedID.lowercaseString isEqual:expected.lowercaseString]) {
                result([self error:@"STALE_DEVICE_SESSION" message:@"戒指连接已变化"]); return;
            }
            result(@{@"accepted": @YES, @"acknowledged": @YES});
        } fail:^{ result([self error:@"HAPTIC_UNCONFIRMED" message:@"戒指未确认提醒，请重试"]); }];
    }
    else if ([call.method isEqualToString:@"triggerDeviceAction"] && [arguments[@"feature"] isEqualToString:@"find_watch"] && [self isResolved]) {
        [QCSDKCmdCreator lookupDeviceSuccess:^{ result(nil); } fail:^{ result([self error:@"QRING_ACTION_FAILED" message:@"查找戒指失败"]); }];
    } else { result(FlutterMethodNotImplemented); }
}

#pragma mark - QCCentralManagerDelegate

- (void)didScanPeripherals:(NSArray<QCBlePeripheral *> *)peripheralArr {
    for (QCBlePeripheral *item in peripheralArr) {
        NSString *name = item.peripheral.name ?: @"";
        NSString *identifier = item.peripheral.identifier.UUIDString ?: @"";
        if (![self isQRingName:name] || identifier.length == 0) { continue; }
        BOOL isNew = self.scanned[identifier] == nil;
        self.scanned[identifier] = item;
        if (isNew) {
            [self emit:@"scanDevice" payload:@{@"id": identifier, @"name": name, @"model": name, @"rssi": item.RSSI ?: @0}];
        }
        if ([identifier isEqualToString:self.selectionTargetID]) {
            [self finishScan];
            return;
        }
    }
}

- (void)scanPeripheralFinish { [self finishScan]; }

- (void)didState:(QCState)state {
    if (state == QCStateConnected) {
        [self resolveCapabilities]; return;
    }
    if (state == QCStateDisconnected || state == QCStateUnbind) {
        // The central reports state before its failure callback. Preserve the
        // failed handshake cooldown before retiring its in-flight flags; normal
        // established-session drops still re-arm on the next main-loop turn.
        BOOL handshakeInterrupted = (self.pendingConnect || self.recoveryConnecting) &&
            !self.pendingDisconnect && !self.cancellingConnection;
        if (handshakeInterrupted) {
            self.recoveryRetryNotBefore = MAX(self.recoveryRetryNotBefore,
                NSProcessInfo.processInfo.systemUptime + 2);
        }
        RingControlTrace(@"connection-disconnected", @{@"generation": @(self.connectionGeneration), @"handshakeInterrupted": @(handshakeInterrupted), @"intentional": @(self.pendingDisconnect != nil || self.cancellingConnection)});
        [self resetRemoteCamera];
        self.remoteCameraSupported = NO;
        [self finishCamera:[self error:@"QRING_DISCONNECTED" message:@"戒指已断开"]];
        self.connectDeadlineGeneration++;
        self.recoveryConnecting = NO;
        self.cancellingConnection = NO;
        if (self.pendingDisconnect) {
            FlutterResult pending = self.pendingDisconnect;
            self.pendingDisconnect = nil;
            pending(nil);
        }
        self.connectionGeneration++;
        self.measurementGeneration++;
        self.syncGeneration++;
        if (self.pendingSync) {
            FlutterResult pending = self.pendingSync;
            self.pendingSync = nil;
            pending([self error:@"QRING_DISCONNECTED" message:@"戒指连接中断，请重连后同步"]);
        }
        self.readingDetails = NO;
        self.battery = nil;
        self.charging = nil;
        self.batteryUpdatedAt = nil;
        self.firmware = @"";
        NSString *retired = self.connectedID;
        self.connectedID = @"";
        self.connectedName = @"";
        self.featureList = nil;
        self.activeMetric = nil;
        self.activeSportMode = nil;
        self.activeSportType = -1;
        if (self.pendingConnect) { [self failConnect:@"QRING_DISCONNECTED" message:@"戒指连接中断，请靠近手机后重试"]; }
        else {
            if (retired.length) { [self emit:@"disconnected" payload:@{@"deviceId": retired}]; }
            // SDK registration can fail while CoreBluetooth still owns a live
            // radio. Retire that exact transport before the next SDK attempt.
            CBPeripheral *failed = self.central.connectedPeripheral;
            if (handshakeInterrupted && failed && failed.state != CBPeripheralStateDisconnected) {
                self.cancellingConnection = YES;
                RingControlTrace(@"recovery-cancel-failed-transport", @{@"generation": @(self.connectionGeneration), @"radioState": @(failed.state)});
                [self.central disconnect];
            }
        }
        [self scheduleRecoveryAfterDisconnect];
    }
}

- (void)didConnectTransport:(CBPeripheral *)peripheral {
    RingControlTrace(@"connection-transport", @{@"generation": @(self.connectionGeneration), @"radioState": @(peripheral.state)});
    if (self.recoveryConnecting &&
        [peripheral.identifier.UUIDString isEqualToString:self.connectedID]) {
        [self scheduleConnectDeadline];
    }
}

- (void)didDisconnectTransport:(CBPeripheral *)peripheral error:(NSError *)error {
    RingControlTrace(@"transport-disconnected", @{@"code": @(error.code),
        @"coreBluetoothError": @([error.domain isEqualToString:CBErrorDomain]),
        @"radioState": @(peripheral.state), @"intentional": @(self.cancellingConnection || self.pendingDisconnect != nil)});
}

- (void)didFailConnected:(CBPeripheral *)peripheral error:(NSError *)error {
    NSString *cause = [error.domain isEqualToString:@"Connect fail"] ? @"sdk_registration" :
        [error.domain isEqualToString:CBErrorDomain] ? @"core_bluetooth" : @"other";
    RingControlTrace(@"connection-failed", @{@"cause": cause, @"code": @(error.code), @"radioState": @(peripheral.state)});
    if (self.pendingConnect || self.recoveryConnecting) {
        [self failConnect:@"QRING_CONNECT_FAILED" message:@"戒指连接失败，请靠近手机后重试"];
    }
}

- (void)didBluetoothState:(QCBluetoothState)state {
    if (state == QCBluetoothStatePoweredOn) { [self startAutomaticRecovery]; }
}

- (FlutterError *_Nullable)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.eventSink = events;
    return nil;
}

- (FlutterError *_Nullable)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

@end
