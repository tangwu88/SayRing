#import "CoolWearWearableBridge.h"
#import "CoolWearPolicy.h"
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
@end

@implementation CoolWearWearableBridge

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    if (!(self = [super init])) return nil;
    _scanned = [NSMutableDictionary dictionary];
    _scanServices = [NSMutableDictionary dictionary];
    _observers = [NSMutableArray array];
    _pendingPassiveRecords = [NSMutableDictionary dictionary];
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
    if (self.sink) self.sink(@{@"type": type, @"payload": payload ?: @{}});
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
            if (![weakSelf isResolved]) return;
            if ([note.name isEqualToString:UIApplicationDidBecomeActiveNotification]) [CE_SensorCmd open];
            else [CE_SensorCmd close];
        }];
        [self.observers addObject:observer];
    }
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
        @"updatedAt": [NSISO8601DateFormatter.new stringFromDate:self.batteryDate]};
    return value;
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
    [self.pendingPassiveRecords removeAllObjects];
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
    for (CE_Cmd *cmd in @[[CE_RequestDevInfoCmd new], [CE_RequestAllInfoCmd new]]) {
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
    [self emit:@"connected" payload:[self details]];
    [self emit:@"capabilities" payload:CoolWearCapabilities(self.flags, YES)];
    result(nil);
}

- (void)receiveData:(NSDictionary *)info depth:(NSUInteger)depth measurement:(NSUInteger)measurement {
    if (depth > 3 || ![info isKindOfClass:NSDictionary.class] || ![self matchesTarget] ||
        self.product.status != ProductStatus_completed ||
        ([info[@"error_msg"] isKindOfClass:NSString.class] && [info[@"error_msg"] length] > 0)) return;
    NSNumber *type = CoolWearNumber(info[@"DataType"]);
    if (!type) return;
    id data = info[@"Data"];
    if (type.integerValue == DATA_TYPE_DEV_SYNC) {
        // This is a mixed-data envelope, NOT a history-completion marker.
        if ([data isKindOfClass:NSArray.class]) for (id child in data) [self receiveData:child depth:depth + 1 measurement:measurement];
        return;
    }
    // History can be pushed while metadata is still being read. Retain only
    // validated records for this exact connection, then deliver after Dart
    // has installed the account-owned connected-device session.
    if (type.integerValue == DATA_TYPE_HISTORY_TEMP || type.integerValue == DATA_TYPE_HISTORY_HRV_METRICS) {
        NSString *metric = type.integerValue == DATA_TYPE_HISTORY_TEMP ? @"body_temperature" : @"hrv";
        NSString *key = type.integerValue == DATA_TYPE_HISTORY_TEMP ? @"tempInfos" : @"hrvMetricsInfos";
        for (NSDictionary *sample in CoolWearMetricSamples(data, key)) {
            NSDictionary *values = [metric isEqualToString:@"hrv"] ? CoolWearRriHrvValues(sample) : CoolWearSkinTemperatureValues(sample);
            NSDate *date = CoolWearSampleDate(sample[@"time"], NSDate.date);
            if (!values || !date) continue;
            NSDictionary *record = [self record:metric values:values date:date origin:@"watch_history"];
            if ([self isResolved] && self.dataDeliveryReady) [self emitPassiveRecord:record];
            else if (self.pendingPassiveRecords.count < 16384) self.pendingPassiveRecords[record[@"id"]] = record;
        }
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
            self.charging = charger && (charger.integerValue == 0 || charger.integerValue == 1) ? charger : nil;
            if ([self isResolved]) [self emit:@"deviceDetails" payload:[self details]];
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
    for (NSString *field in [[values allKeys] sortedArrayUsingSelector:@selector(compare:)]) [key appendFormat:@"|%@=%@", field, values[field]];
    NSData *bytes = [key dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
    NSMutableString *identifier = [NSMutableString string];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [identifier appendFormat:@"%02x", digest[i]];
    NSInteger minutes = [NSTimeZone.localTimeZone secondsFromGMTForDate:date] / 60;
    NSString *offset = [NSString stringWithFormat:@"%@%02ld:%02ld", minutes < 0 ? @"-" : @"+", (long)labs(minutes) / 60, (long)labs(minutes) % 60];
    return @{@"id": identifier, @"type": metric, @"values": values,
        @"unit": [metric isEqualToString:@"hrv"] ? @"ms" : @"℃", @"measuredAt": timestamp, @"timezone": offset,
        @"deviceId": [@"coolwear:" stringByAppendingString:self.target.identifier.UUIDString], @"firmwareVersion": self.deviceInfo[@"version"] ?: @"",
        @"quality": @"device_reported", @"source": @"wearable", @"origin": origin, @"rawVersion": @2,
        @"sourceModel": CoolWearModel(self.targetName), @"sourceVendor": @"coolwear", @"sourceDeviceCategory": @"ring", @"sourceApp": @"say-ring"};
}

- (void)emitPassiveRecord:(NSDictionary *)record {
    NSString *flag = [record[@"type"] isEqualToString:@"hrv"] ? @"hrvSupport" : @"temp_supported";
    if (![self isResolved] || !self.dataDeliveryReady || !CoolWearFlag(self.flags, flag)) return;
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
}

- (void)failConnection:(NSString *)code message:(NSString *)message {
    FlutterResult connect = self.pendingConnect;
    self.pendingConnect = nil;
    if (connect) connect([self error:code message:message]);
    [self beginCancellation:nil];
}

- (void)beginCancellation:(FlutterResult)result {
    [self finishScan];
    self.connectionGeneration++;
    self.measurementGeneration++;
    self.activeMetric = nil;
    self.dataDeliveryReady = NO;
    [self.pendingPassiveRecords removeAllObjects];
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
    if (!self.product.connect.peripheral || self.product.connect.peripheral.state == CBPeripheralStateDisconnected) {
        self.cancelling = NO;
        self.target = nil;
        self.targetName = nil;
        [self emit:@"disconnected" payload:@{}];
        FlutterResult result = self.pendingDisconnect;
        self.pendingDisconnect = nil;
        if (result) result(nil);
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
    @try {
        if ([call.method isEqualToString:@"scanDevices"]) [self startScan:result];
        else if ([call.method isEqualToString:@"stopScan"]) { [self finishScan]; result(nil); }
        else if ([call.method isEqualToString:@"connect"]) [self connect:args result:result];
        else if ([call.method isEqualToString:@"disconnect"]) {
            if (self.cancelling) { result([self error:@"CONNECT_BUSY" message:@"戒指正在断开，请稍候"]); return; }
            [self beginCancellation:result];
        } else if ([call.method isEqualToString:@"getDeviceDetails"]) result([self isResolved] ? [self details] : nil);
        else if ([call.method isEqualToString:@"getCapabilities"]) {
            result(CoolWearCapabilities(self.flags, [self isResolved]));
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
        self.pendingScan = nil;
        self.pendingConnect = nil;
        self.pendingMeasurement = nil;
        self.pendingDisconnect = nil;
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
    [self beginCancellation:nil];
    for (id observer in self.observers) [NSNotificationCenter.defaultCenter removeObserver:observer];
    [self.observers removeAllObjects];
    [self.methods setMethodCallHandler:nil];
    [self.events setStreamHandler:nil];
    self.sink = nil;
}
@end
