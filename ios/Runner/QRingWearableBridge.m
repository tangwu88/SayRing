#import "QRingWearableBridge.h"
#import "QCCentralManager.h"
#import "QRingRecordMapping.h"
#import "QRingCameraPolicy.h"
#import "SayRingActivitySleepPolicy.h"

#import <QCBandSDK/QCBandSDK.h>
#import <CommonCrypto/CommonDigest.h>

typedef void (^QRingNext)(void);

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
@property(nonatomic, assign) NSUInteger measurementGeneration;
@property(nonatomic, assign) NSUInteger syncGeneration;
@property(nonatomic, assign) BOOL readingDetails;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *syncRecords;
@property(nonatomic, copy, nullable) NSString *activeMetric;
@property(nonatomic, copy, nullable) NSString *activeSportMode;
@property(nonatomic, assign) NSInteger activeSportType;
@property(nonatomic, copy) NSString *recoveryTargetID;
@property(nonatomic, copy) NSString *recoveryContext;
@property(nonatomic, copy) NSString *recoveryTargetName;
@property(nonatomic, copy) NSDictionary *recoveryProfile;
@property(nonatomic, assign) BOOL recoveryConnecting;
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
    NSString *upper = [[name ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    // User-confirmed R2 family, including R21; capabilities still require a handshake.
    return [upper hasPrefix:@"Q_"] || [upper hasPrefix:@"O_"] || [upper hasPrefix:@"R2"];
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
    self.pendingConnect = result;
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
        self.central.hasPendingRestoredCancellations ||
        self.central.bleState != QCBluetoothStatePoweredOn || self.pendingConnect ||
        self.pendingDisconnect || self.cancellingConnection || self.recoveryConnecting || [self isResolved]) { return; }
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.recoveryTargetID];
    if (!uuid) { return; }
    NSArray<CBPeripheral *> *items = [self.central.centerManager retrievePeripheralsWithIdentifiers:@[uuid]];
    for (CBPeripheral *peripheral in items) {
        if (![peripheral.identifier isEqual:uuid] || ![self isQRingName:peripheral.name]) { continue; }
        self.connectedID = self.recoveryTargetID;
        self.connectedName = peripheral.name;
        self.profile = self.recoveryProfile ?: @{};
        self.featureList = nil;
        self.connectionGeneration++;
        self.recoveryConnecting = YES;
        [self emit:@"recoveryState" payload:@{@"status": @"waiting", @"deviceId": self.connectedID}];
        // CoreBluetooth owns one indefinite pending request until proximity.
        // Only the SDK handshake receives a deadline after the radio connects.
        [self.central connect:peripheral timeout:0 deviceType:QCDeviceTypeRing];
        return;
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
    [self.central disconnect];
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
    [self startAutomaticRecovery];
    result(nil);
}

- (void)resolveCapabilities {
    if (self.connectedID.length == 0 || ![self.central.connectedPeripheral.identifier.UUIDString isEqualToString:self.connectedID]) {
        [self.central disconnect];
        return;
    }
    NSUInteger generation = ++self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator setTime:NSDate.date success:^(NSDictionary *featureList) {
      QRingOnMain(^{
        __strong typeof(weakSelf) self = weakSelf;
        if (![self isCurrentConnection:generation]) { return; }
        if (featureList.count == 0) {
            [self failConnect:@"QRING_HANDSHAKE_FAILED" message:@"戒指未返回功能列表，请重试"];
            return;
        }
        self.featureList = featureList;
        // QRing has one command channel. Finish setup/details before Flutter
        // can start history sync or a measurement on that channel.
        [self writeProfileWithCompletion:^{
          QRingOnMain(^{
            if (![weakSelf isCurrentConnection:generation]) { return; }
            [weakSelf readDeviceDetailsWithCompletion:^{
                if (![weakSelf isCurrentConnection:generation]) { return; }
                [weakSelf probeRemoteCamera:^{
                if (![weakSelf isCurrentConnection:generation]) { return; }
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

- (BOOL)isCurrentConnection:(NSUInteger)generation {
    return generation == self.connectionGeneration && self.central.deviceState == QCStateConnected;
}

- (NSInteger)profileNumber:(NSString *)key fallback:(NSInteger)fallback minimum:(NSInteger)minimum maximum:(NSInteger)maximum {
    NSNumber *raw = [self.profile[key] isKindOfClass:NSNumber.class] ? self.profile[key] : nil;
    NSInteger value = raw ? raw.integerValue : fallback;
    return MIN(maximum, MAX(minimum, value));
}

- (void)writeProfileWithCompletion:(QRingNext)completion {
    NSInteger gender = [self profileNumber:@"gender" fallback:1 minimum:1 maximum:2] == 2 ? 1 : 0;
    [QCSDKCmdCreator setTimeFormatTwentyfourHourFormat:YES
                                          metricSystem:YES
                                                gender:gender
                                                   age:[self profileNumber:@"age" fallback:30 minimum:5 maximum:120]
                                                height:[self profileNumber:@"heightCm" fallback:170 minimum:80 maximum:240]
                                                weight:[self profileNumber:@"weightKg" fallback:65 minimum:20 maximum:250]
                                               sbpBase:0 dbpBase:0 hrAlarmValue:0
                                               success:^(__unused BOOL a, __unused BOOL b, __unused NSInteger c, __unused NSInteger d, __unused NSInteger e, __unused NSInteger f, __unused NSInteger g, __unused NSInteger h, __unused NSInteger i) { completion(); }
                                                  fail:completion];
}

- (void)readDeviceDetailsWithCompletion:(QRingNext)completion {
    NSUInteger generation = self.connectionGeneration;
    self.readingDetails = YES;
    __block BOOL finished = NO;
    __weak typeof(self) weakSelf = self;
    QRingNext finish = ^{
        if (finished) { return; }
        finished = YES;
        if (generation == weakSelf.connectionGeneration) { weakSelf.readingDetails = NO; }
        completion();
    };
    QRingNext readFirmware = ^{
        if (finished || ![weakSelf isCurrentConnection:generation]) { finish(); return; }
        // The bundled SDK invokes this callback as (hardware, software).
        [QCSDKCmdCreator getDeviceSoftAndHardVersionSuccess:^(__unused NSString *hardware, NSString *software) {
          QRingOnMain(^{
            if (!finished && [weakSelf isCurrentConnection:generation]) {
                weakSelf.firmware = software ?: @"";
            }
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
        readFirmware();
      });
    } failed:^{ QRingOnMain(readFirmware); }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), finish);
}

- (void)failConnect:(NSString *)code message:(NSString *)message {
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
    self.measurementGeneration++;
    QCMeasuringType type = [self measurementType:metric];
    self.activeMetric = nil;
    if (type == QCMeasuringTypeUnkown) { result(nil); return; }
    [[QCSDKManager shareInstance] stopToMeasuringWithOperateType:type completedHandle:^(__unused BOOL success, __unused NSError *error) {}];
    result(nil);
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
    if (!isfinite(value) || value < minimum || value > maximum) { return; }
    [self.syncRecords addObject:[self record:metric date:date values:@{@"value": @(value)} unit:unit origin:@"watch_history"]];
}

- (void)syncHealth:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    if (self.pendingSync) { result([self error:@"SYNC_BUSY" message:@"戒指数据正在同步"]); return; }
    self.pendingSync = result;
    NSUInteger generation = ++self.syncGeneration;
    [self.syncRecords removeAllObjects];
    [self syncDay:0 phase:0];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (weakSelf.pendingSync && generation == weakSelf.syncGeneration) {
            FlutterResult pending = weakSelf.pendingSync;
            weakSelf.pendingSync = nil;
            weakSelf.syncGeneration++;
            pending([weakSelf error:@"QRING_SYNC_TIMEOUT" message:@"戒指数据同步超时，请靠近手机后重试"]);
        }
    });
}

- (void)syncDay:(NSInteger)day phase:(NSInteger)phase {
    if (!self.pendingSync) { return; }
    if (day >= 7) { [self finishHealthSync]; return; }
    // This release requests only activity and sleep history from QRing.
    if (phase >= 2) { [self syncDay:day + 1 phase:0]; return; }
    [self emit:@"syncProgress" payload:@{@"deviceId": self.connectedID, @"progress": @(MIN(0.98, (day * 2.0 + phase) / 14.0))}];
    __weak typeof(self) weakSelf = self;
    NSUInteger syncGeneration = self.syncGeneration;
    NSUInteger connectionGeneration = self.connectionGeneration;
    BOOL (^current)(void) = ^BOOL {
        return weakSelf.pendingSync && syncGeneration == weakSelf.syncGeneration && [weakSelf isCurrentConnection:connectionGeneration];
    };
    switch (phase) {
        case 0: {
            [QCSDKCmdCreator getSportDetailDataByDay:day sportDatas:^(NSArray<QCSportModel *> *sports) {
                if (!current()) { return; }
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
                [weakSelf syncDay:day phase:1];
            } fail:^{ if (current()) { [weakSelf syncDay:day phase:1]; } }];
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
                [weakSelf syncDay:day phase:2];
            } fail:^{
                if (!current()) { return; }
                [weakSelf emit:@"sleepReadStatus" payload:@{@"deviceId": scopedId, @"sdkDate": sdkDate, @"status": @"failed"}];
                [weakSelf syncDay:day phase:2];
            }];
            break;
        }
        case 2: {
            [QCSDKCmdCreator getSchedualHeartRateDataWithDayIndexs:@[@(day)] success:^(NSArray<QCSchedualHeartRateModel *> *models) {
                if (!current()) { return; }
                for (QCSchedualHeartRateModel *model in models) {
                    NSDate *base = [weakSelf parseDateTime:[model.date stringByAppendingString:@" 00:00:00"] fallback:[weakSelf dayStart:day]];
                    NSInteger seconds = MAX(60, model.secondInterval);
                    [model.heartRates enumerateObjectsUsingBlock:^(NSNumber *number, NSUInteger index, BOOL *stop) {
                        [weakSelf addSingle:@"heart_rate" date:[base dateByAddingTimeInterval:index * seconds] value:number.doubleValue unit:@"bpm" minimum:20 maximum:300];
                    }];
                }
                [weakSelf syncDay:day phase:3];
            } fail:^{ if (current()) { [weakSelf syncDay:day phase:3]; } }];
            break;
        }
        case 3: {
            if (![self feature:QCBandFeatureBloodOxygen]) { [self syncDay:day phase:4]; return; }
            [QCSDKCmdCreator getBloodOxygenDataWithIntervalByDayIndex:day finished:^(NSInteger interval, NSArray *values, __unused NSError *error) {
                if (!current()) { return; }
                NSDate *base = [weakSelf dayStart:day];
                [values enumerateObjectsUsingBlock:^(id value, NSUInteger index, BOOL *stop) {
                    double amount = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : ([value isKindOfClass:QCBloodOxygenModel.class] ? [(QCBloodOxygenModel *)value soa2] : 0);
                    NSDate *date = [value isKindOfClass:QCBloodOxygenModel.class] ? [(QCBloodOxygenModel *)value date] : [base dateByAddingTimeInterval:index * MAX(1, interval) * 60];
                    [weakSelf addSingle:@"blood_oxygen" date:date value:amount unit:@"%" minimum:50 maximum:100];
                }];
                [weakSelf syncDay:day phase:4];
            }];
            break;
        }
        case 4: {
            if (![self feature:QCBandFeatureStress]) { [self syncDay:day phase:5]; return; }
            [QCSDKCmdCreator getPressureSamplesWithDayIndexes:@[@(day)] finished:^(NSArray<QCPressureDayModel *> *days, __unused NSError *error) {
                if (!current()) { return; }
                for (QCPressureDayModel *model in days) {
                    for (QCPressureSampleModel *sample in model.samples) {
                        [weakSelf addSingle:@"stress" date:sample.time value:sample.value unit:@"" minimum:1 maximum:100];
                    }
                }
                [weakSelf syncDay:day phase:5];
            }];
            break;
        }
        case 5: {
            if (![self feature:QCBandFeatureHRV]) { [self syncDay:day phase:6]; return; }
            [QCSDKCmdCreator getHRVSamplesWithDayIndexes:@[@(day)] finished:^(NSArray<QCHRVDayModel *> *days, __unused NSError *error) {
                if (!current()) { return; }
                for (QCHRVDayModel *model in days) {
                    for (QCHRVSampleModel *sample in model.samples) {
                        [weakSelf addSingle:@"hrv" date:sample.time value:sample.value unit:@"ms" minimum:1 maximum:1000];
                    }
                }
                [weakSelf syncDay:day phase:6];
            }];
            break;
        }
        case 6: {
            if (![self feature:QCBandFeatureTemperature]) { [self syncDay:day + 1 phase:0]; return; }
            [QCSDKCmdCreator getTemperatureDataWithIntervalByDayIndex:day finished:^(NSInteger interval, NSArray *values, __unused NSError *error) {
                if (!current()) { return; }
                NSDate *base = [weakSelf dayStart:day];
                [values enumerateObjectsUsingBlock:^(id value, NSUInteger index, BOOL *stop) {
                    double amount = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : ([value isKindOfClass:QCTemperatureModel.class] ? [(QCTemperatureModel *)value temperature] : 0);
                    NSDate *date = [value isKindOfClass:QCTemperatureModel.class] ? [(QCTemperatureModel *)value time] : [base dateByAddingTimeInterval:index * MAX(1, interval) * 60];
                    [weakSelf addSingle:@"body_temperature" date:date value:amount unit:@"℃" minimum:20 maximum:45];
                }];
                [weakSelf syncDay:day + 1 phase:0];
            }];
            break;
        }
        default: [self syncDay:day + 1 phase:0]; break;
    }
}

- (void)finishHealthSync {
    FlutterResult result = self.pendingSync;
    self.pendingSync = nil;
    if (result) { result(self.syncRecords.copy); }
}

- (void)readAutoSettings:(FlutterResult)result {
    if (![self isResolved]) { result([self error:@"NOT_CONNECTED" message:@"请先连接戒指"]); return; }
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator getSchedualHeartRateStatusWithSuccess:^(BOOL enabled) {
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

- (void)setAutoSetting:(NSString *)type enabled:(BOOL)enabled result:(FlutterResult)result {
    if ([type isEqualToString:@"heartRate"]) {
        [QCSDKCmdCreator setSchedualHeartRateStatus:enabled success:^(__unused BOOL state) { result(nil); } fail:^{ result([self error:@"QRING_SETTING_FAILED" message:@"自动心率设置失败"]); }];
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
            weakSelf.cameraPoisonGeneration = connection;
            finish();
        }
    });
    void (^exit)(BOOL) = ^(BOOL accepted) {
        // Always defer past the SDK's callback queue cleanup.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done || operation != weakSelf.cameraOperation || ![weakSelf isCurrentConnection:connection]) { return; }
            [QCSDKCmdCreator stopTakingPhotoSuccess:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (done || operation != weakSelf.cameraOperation || ![weakSelf isCurrentConnection:connection]) { return; }
                    weakSelf.remoteCameraSupported = accepted;
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

- (void)finishCamera:(id)value {
    FlutterResult pending = self.pendingCamera;
    if (!pending) { return; }
    self.pendingCamera = nil;
    self.cameraOperation++;
    pending(value);
}

- (void)readCameraTouch:(BOOL)touch completion:(void (^)(NSDictionary *, NSError *))completion {
    // Start the next SDK command outside its response callback stack.
    void (^finish)(QCTouchGestureControlType, NSInteger, BOOL, NSInteger, NSError *) =
    ^(QCTouchGestureControlType mode, NSInteger strength, __unused BOOL sleeping, NSInteger duration, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error ? nil : QRingCameraSnapshot(mode, strength, touch, duration), error);
        });
    };
    if (!touch) {
        [QCSDKCmdCreator getGestureControlFinshed:^(QCTouchGestureControlType mode, NSInteger strength, BOOL sleeping, NSError *error) {
            finish(mode, strength, sleeping, 0, error);
        }];
    } else if ([self cameraFlag:QCBandFeatureTouchControlOfScreenDevice]) {
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
    if (!SRActivitySleepCommandAllowed(call.method, arguments)) {
        result([self error:@"FEATURE_UNAVAILABLE" message:@"此版本仅提供活动与睡眠记录"]); return;
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
    NSSet *commands = [NSSet setWithArray:@[@"syncHealthData", @"startMeasurement", @"startSport", @"readSportRecords", @"readAutoMeasureSettings", @"setAutoMeasureSetting", @"triggerDeviceAction", @"readDeviceFeature", @"writeDeviceFeature"]];
    if ((self.pendingCamera || self.remoteCameraActive) && [commands containsObject:call.method]) {
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
    else if ([call.method isEqualToString:@"getDeviceDetails"]) {
        if (![self isResolved]) { result(nil); return; }
        BOOL fresh = self.batteryUpdatedAt && [NSDate.date timeIntervalSinceDate:self.batteryUpdatedAt] < 15;
        if (fresh || self.remoteCameraActive || self.pendingCamera || self.pendingConnect || self.pendingSync || self.activeMetric || self.activeSportType >= 0 || self.readingDetails) {
            result([self deviceDetails]);
        } else {
            [self readDeviceDetailsWithCompletion:^{ result([self isResolved] ? [self deviceDetails] : nil); }];
        }
    }
    else if ([call.method isEqualToString:@"getCapabilities"]) { result([self isResolved] ? [self capabilities] : [self error:@"CAPABILITIES_UNAVAILABLE" message:@"请先连接戒指"]); }
    else if ([call.method isEqualToString:@"readDeviceFeature"]) { [self cameraControl:arguments write:NO result:result]; }
    else if ([call.method isEqualToString:@"writeDeviceFeature"]) { [self cameraControl:arguments write:YES result:result]; }
    else if ([call.method isEqualToString:@"syncHealthData"]) { [self syncHealth:result]; }
    else if ([call.method isEqualToString:@"startMeasurement"]) { [self startMeasurement:arguments[@"metric"] result:result]; }
    else if ([call.method isEqualToString:@"stopMeasurement"]) { [self stopMeasurement:arguments[@"metric"] result:result]; }
    else if ([call.method isEqualToString:@"startSport"]) { [self startSport:arguments[@"mode"] result:result]; }
    else if ([call.method isEqualToString:@"stopSport"]) { [self stopSport:result]; }
    else if ([call.method isEqualToString:@"readSportRecords"]) { [self readSportRecords:result]; }
    else if ([call.method isEqualToString:@"readAutoMeasureSettings"]) { [self readAutoSettings:result]; }
    else if ([call.method isEqualToString:@"setAutoMeasureSetting"]) { [self setAutoSetting:arguments[@"type"] enabled:[arguments[@"enabled"] boolValue] result:result]; }
    else if ([call.method isEqualToString:@"triggerDeviceAction"] && [arguments[@"feature"] isEqualToString:@"camera"]) {
        [self remoteCameraAction:[arguments[@"enabled"] isEqual:@NO] ? 6 : 4 result:result];
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
        self.featureList = nil;
        self.activeMetric = nil;
        self.activeSportType = -1;
        if (self.pendingConnect) { [self failConnect:@"QRING_DISCONNECTED" message:@"戒指连接中断，请靠近手机后重试"]; }
        else if (retired.length) { [self emit:@"disconnected" payload:@{@"deviceId": retired}]; }
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [weakSelf startAutomaticRecovery]; });
    }
}

- (void)didConnectTransport:(CBPeripheral *)peripheral {
    if (self.recoveryConnecting &&
        [peripheral.identifier.UUIDString isEqualToString:self.connectedID]) {
        [self scheduleConnectDeadline];
    }
}

- (void)didFailConnected:(__unused CBPeripheral *)peripheral error:(__unused NSError *)error {
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
