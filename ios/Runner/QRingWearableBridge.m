#import "QRingWearableBridge.h"
#import "QCCentralManager.h"

#import <QCBandSDK/QCBandSDK.h>

typedef void (^QRingNext)(void);

@interface QRingWearableBridge () <FlutterStreamHandler, QCCentralManagerDelegate>
@property(nonatomic, strong) FlutterMethodChannel *methodChannel;
@property(nonatomic, strong) FlutterEventChannel *eventChannel;
@property(nonatomic, copy, nullable) FlutterEventSink eventSink;
@property(nonatomic, strong) QCCentralManager *central;
@property(nonatomic, strong) NSMutableDictionary<NSString *, QCBlePeripheral *> *scanned;
@property(nonatomic, copy, nullable) FlutterResult pendingScan;
@property(nonatomic, copy, nullable) FlutterResult pendingConnect;
@property(nonatomic, copy, nullable) FlutterResult pendingSync;
@property(nonatomic, copy, nullable) NSDictionary *featureList;
@property(nonatomic, copy, nullable) NSDictionary *profile;
@property(nonatomic, copy) NSString *connectedID;
@property(nonatomic, copy) NSString *connectedName;
@property(nonatomic, copy) NSString *firmware;
@property(nonatomic, strong, nullable) NSNumber *battery;
@property(nonatomic, strong, nullable) NSNumber *charging;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *syncRecords;
@property(nonatomic, copy, nullable) NSString *activeMetric;
@property(nonatomic, copy, nullable) NSString *activeSportMode;
@property(nonatomic, assign) NSInteger activeSportType;
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
    _central.delegate = self;
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
    [self.central stopScan];
    self.central.delegate = nil;
    [self.methodChannel setMethodCallHandler:nil];
    [self.eventChannel setStreamHandler:nil];
    self.eventSink = nil;
}

- (FlutterError *)error:(NSString *)code message:(NSString *)message {
    return [FlutterError errorWithCode:code message:message details:nil];
}

- (void)emit:(NSString *)type payload:(NSDictionary *)payload {
    if (self.eventSink) {
        self.eventSink(@{@"type": type, @"payload": payload ?: @{}});
    }
}

- (BOOL)isQRingName:(NSString *)name {
    NSString *upper = [[name ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([upper hasPrefix:@"Q_"] || [upper hasPrefix:@"O_"]) { return YES; }
    if (![upper hasPrefix:@"R22_"] || upper.length != 8) { return NO; }
    NSString *suffix = [upper substringFromIndex:4];
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
    return [suffix rangeOfCharacterFromSet:nonHex].location == NSNotFound;
}

- (BOOL)isResolved {
    return self.central.deviceState == QCStateConnected && self.featureList.count > 0 && self.connectedID.length > 0;
}

- (BOOL)feature:(NSString *)key {
    return key.length > 0 && [self.featureList[key] boolValue];
}

- (void)startScan:(FlutterResult)result {
    if (self.pendingScan) {
        self.pendingScan([self scanPayloads]);
    }
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
    if (!self.pendingScan) { return; }
    FlutterResult result = self.pendingScan;
    self.pendingScan = nil;
    result([self scanPayloads]);
}

- (void)connect:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *identifier = [arguments[@"id"] isKindOfClass:NSString.class] ? arguments[@"id"] : @"";
    QCBlePeripheral *item = self.scanned[identifier];
    if (!item || ![self isQRingName:item.peripheral.name]) {
        result([self error:@"QRING_DEVICE_UNVERIFIED" message:@"请重新搜索并选择 QRing 戒指"]);
        return;
    }
    if (self.pendingConnect) {
        result([self error:@"CONNECT_BUSY" message:@"戒指正在连接，请稍候"]);
        return;
    }
    [self finishScan];
    self.pendingConnect = result;
    self.featureList = nil;
    self.profile = [arguments[@"profile"] isKindOfClass:NSDictionary.class] ? arguments[@"profile"] : @{};
    self.connectedID = identifier;
    self.connectedName = item.peripheral.name ?: @"QRing";
    [self.central connect:item.peripheral timeout:12 deviceType:QCDeviceTypeRing];
}

- (void)resolveCapabilities {
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator setTime:NSDate.date success:^(NSDictionary *featureList) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (featureList.count == 0) {
            [self failConnect:@"QRING_HANDSHAKE_FAILED" message:@"戒指未返回功能列表，请重试"];
            return;
        }
        self.featureList = featureList;
        [self writeProfile];
        [QCSDKCmdCreator alertBindingSuccess:nil fail:nil];
        [self readDeviceDetails];
        FlutterResult result = self.pendingConnect;
        self.pendingConnect = nil;
        if (result) { result(nil); }
        [self emit:@"deviceDetails" payload:[self deviceDetails]];
        [self emit:@"capabilitiesUpdated" payload:[self capabilities]];
    } failed:^{
        [weakSelf failConnect:@"QRING_HANDSHAKE_FAILED" message:@"戒指能力读取失败，请靠近手机后重试"];
    }];
}

- (NSInteger)profileNumber:(NSString *)key fallback:(NSInteger)fallback minimum:(NSInteger)minimum maximum:(NSInteger)maximum {
    NSNumber *raw = [self.profile[key] isKindOfClass:NSNumber.class] ? self.profile[key] : nil;
    NSInteger value = raw ? raw.integerValue : fallback;
    return MIN(maximum, MAX(minimum, value));
}

- (void)writeProfile {
    NSInteger gender = [self profileNumber:@"gender" fallback:1 minimum:1 maximum:2] == 2 ? 1 : 0;
    [QCSDKCmdCreator setTimeFormatTwentyfourHourFormat:YES
                                          metricSystem:YES
                                                gender:gender
                                                   age:[self profileNumber:@"age" fallback:30 minimum:5 maximum:120]
                                                height:[self profileNumber:@"heightCm" fallback:170 minimum:80 maximum:240]
                                                weight:[self profileNumber:@"weightKg" fallback:65 minimum:20 maximum:250]
                                               sbpBase:0 dbpBase:0 hrAlarmValue:0
                                               success:^(__unused BOOL a, __unused BOOL b, __unused NSInteger c, __unused NSInteger d, __unused NSInteger e, __unused NSInteger f, __unused NSInteger g, __unused NSInteger h, __unused NSInteger i) {}
                                                  fail:^{}];
}

- (void)readDeviceDetails {
    __weak typeof(self) weakSelf = self;
    [QCSDKCmdCreator readBatterySuccess:^(int battery, BOOL charging) {
        if (battery < 0 || battery > 100) { return; }
        weakSelf.battery = @(battery);
        weakSelf.charging = @(charging);
        [weakSelf emit:@"deviceDetails" payload:[weakSelf deviceDetails]];
    } failed:^{}];
    [QCSDKCmdCreator getDeviceSoftAndHardVersionSuccess:^(NSString *software, __unused NSString *hardware) {
        weakSelf.firmware = software ?: @"";
        [weakSelf emit:@"deviceDetails" payload:[weakSelf deviceDetails]];
    } fail:^{}];
}

- (void)failConnect:(NSString *)code message:(NSString *)message {
    FlutterResult result = self.pendingConnect;
    self.pendingConnect = nil;
    if (result) { result([self error:code message:message]); }
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
            @"chargeState": self.charging.boolValue ? @"charging" : @"normal",
            @"updatedAt": [self iso:NSDate.date],
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
    [self emit:@"measurementProgress" payload:@{@"metric": metric, @"progress": @5}];
    NSInteger timeout = type == QCMeasuringTypeHRV ? 80 : 30;
    __weak typeof(self) weakSelf = self;
    [[QCSDKManager shareInstance] startToMeasuringWithOperateType:type timeout:timeout measuringHandle:^(id value) {
        [weakSelf emitMeasurementValue:value metric:metric terminal:NO];
    } completedHandle:^(BOOL success, id value, NSError *error) {
        if (!success || !value) {
            [weakSelf emit:@"error" payload:@{
                @"code": error.code == -3 ? @"MEASUREMENT_NOT_WORN" : @"MEASUREMENT_FAILED",
                @"message": error.code == -3 ? @"未检测到正确佩戴，请调整戒指后重试" : @"戒指未返回有效测量结果，请保持静止后重试",
            }];
        } else {
            [weakSelf emitMeasurementValue:value metric:metric terminal:YES];
        }
        weakSelf.activeMetric = nil;
    }];
    result(nil);
}

- (void)emitMeasurementValue:(id)value metric:(NSString *)metric terminal:(BOOL)terminal {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    NSString *unit = @"";
    if ([value isKindOfClass:NSNumber.class] && [(NSNumber *)value doubleValue] > 0) {
        values[@"value"] = value;
        if ([metric isEqualToString:@"heart_rate"]) { unit = @"bpm"; }
        else if ([metric isEqualToString:@"blood_oxygen"]) { unit = @"%"; }
        else if ([metric isEqualToString:@"hrv"]) { unit = @"ms"; }
        else if ([metric isEqualToString:@"body_temperature"]) { unit = @"℃"; }
    } else if ([value isKindOfClass:NSDictionary.class]) {
        NSNumber *sbp = @([value[@"sbp"] integerValue]);
        NSNumber *dbp = @([value[@"dbp"] integerValue]);
        if (sbp.integerValue > 0 && dbp.integerValue > 0) {
            values[@"systolic"] = sbp;
            values[@"diastolic"] = dbp;
            unit = @"mmHg";
        }
    }
    if (values.count == 0) { return; }
    if (terminal) { [self emit:@"measurementProgress" payload:@{@"metric": metric, @"progress": @100}]; }
    [self emit:@"healthRecord" payload:[self record:metric date:NSDate.date values:values unit:unit origin:@"app_measurement"]];
}

- (void)stopMeasurement:(NSString *)metric result:(FlutterResult)result {
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
    return @{
        @"id": [NSString stringWithFormat:@"%@|%@|%.0f|%@", scopedID, metric, millis, values],
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
        @"rawVersion": @1,
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
    [self.syncRecords removeAllObjects];
    [self syncDay:0 phase:0];
}

- (void)syncDay:(NSInteger)day phase:(NSInteger)phase {
    if (!self.pendingSync) { return; }
    if (day >= 7) { [self finishHealthSync]; return; }
    [self emit:@"syncProgress" payload:@{@"deviceId": self.connectedID, @"progress": @(MIN(0.98, (day * 7.0 + phase) / 49.0))}];
    __weak typeof(self) weakSelf = self;
    switch (phase) {
        case 0:
            [QCSDKCmdCreator getSportDetailDataByDay:day sportDatas:^(NSArray<QCSportModel *> *sports) {
                for (QCSportModel *item in sports) {
                    NSDate *date = [weakSelf parseDateTime:item.happenDate fallback:[weakSelf dayStart:day]];
                    [weakSelf addSingle:@"steps" date:date value:item.totalStepCount unit:@"步" minimum:1 maximum:1000000];
                    [weakSelf addSingle:@"distance" date:date value:item.distance / 1000.0 unit:@"km" minimum:0.001 maximum:10000];
                    [weakSelf addSingle:@"calories" date:date value:item.calories unit:@"kcal" minimum:0.01 maximum:100000];
                }
                [weakSelf syncDay:day phase:1];
            } fail:^{ [weakSelf syncDay:day phase:1]; }];
            break;
        case 1:
            [QCSDKCmdCreator getFulldaySleepDetailDataByDay:day sleepDatas:^(NSArray<QCSleepModel *> *sleeps, NSArray<QCSleepModel *> *naps) {
                NSMutableArray *all = [NSMutableArray arrayWithArray:sleeps ?: @[]];
                [all addObjectsFromArray:naps ?: @[]];
                NSInteger total = [QCSleepModel sleepDuration:all];
                if (total > 0) {
                    NSDate *date = [weakSelf dayStart:day];
                    [weakSelf.syncRecords addObject:[weakSelf record:@"sleep" date:date values:@{@"value": @(total / 60.0)} unit:@"h" origin:@"watch_history"]];
                }
                [weakSelf syncDay:day phase:2];
            } fail:^{ [weakSelf syncDay:day phase:2]; }];
            break;
        case 2:
            [QCSDKCmdCreator getSchedualHeartRateDataWithDayIndexs:@[@(day)] success:^(NSArray<QCSchedualHeartRateModel *> *models) {
                for (QCSchedualHeartRateModel *model in models) {
                    NSDate *base = [weakSelf parseDateTime:[model.date stringByAppendingString:@" 00:00:00"] fallback:[weakSelf dayStart:day]];
                    NSInteger seconds = MAX(60, model.secondInterval);
                    [model.heartRates enumerateObjectsUsingBlock:^(NSNumber *number, NSUInteger index, BOOL *stop) {
                        [weakSelf addSingle:@"heart_rate" date:[base dateByAddingTimeInterval:index * seconds] value:number.doubleValue unit:@"bpm" minimum:20 maximum:300];
                    }];
                }
                [weakSelf syncDay:day phase:3];
            } fail:^{ [weakSelf syncDay:day phase:3]; }];
            break;
        case 3:
            if (![self feature:QCBandFeatureBloodOxygen]) { [self syncDay:day phase:4]; return; }
            [QCSDKCmdCreator getBloodOxygenDataWithIntervalByDayIndex:day finished:^(NSInteger interval, NSArray *values, __unused NSError *error) {
                NSDate *base = [weakSelf dayStart:day];
                [values enumerateObjectsUsingBlock:^(id value, NSUInteger index, BOOL *stop) {
                    double amount = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : ([value isKindOfClass:QCBloodOxygenModel.class] ? [(QCBloodOxygenModel *)value soa2] : 0);
                    NSDate *date = [value isKindOfClass:QCBloodOxygenModel.class] ? [(QCBloodOxygenModel *)value date] : [base dateByAddingTimeInterval:index * MAX(1, interval) * 60];
                    [weakSelf addSingle:@"blood_oxygen" date:date value:amount unit:@"%" minimum:50 maximum:100];
                }];
                [weakSelf syncDay:day phase:4];
            }];
            break;
        case 4:
            if (![self feature:QCBandFeatureStress]) { [self syncDay:day phase:5]; return; }
            [QCSDKCmdCreator getPressureSamplesWithDayIndexes:@[@(day)] finished:^(NSArray<QCPressureDayModel *> *days, __unused NSError *error) {
                for (QCPressureDayModel *model in days) {
                    for (QCPressureSampleModel *sample in model.samples) {
                        [weakSelf addSingle:@"stress" date:sample.time value:sample.value unit:@"" minimum:1 maximum:100];
                    }
                }
                [weakSelf syncDay:day phase:5];
            }];
            break;
        case 5:
            if (![self feature:QCBandFeatureHRV]) { [self syncDay:day phase:6]; return; }
            [QCSDKCmdCreator getHRVSamplesWithDayIndexes:@[@(day)] finished:^(NSArray<QCHRVDayModel *> *days, __unused NSError *error) {
                for (QCHRVDayModel *model in days) {
                    for (QCHRVSampleModel *sample in model.samples) {
                        [weakSelf addSingle:@"hrv" date:sample.time value:sample.value unit:@"ms" minimum:1 maximum:1000];
                    }
                }
                [weakSelf syncDay:day phase:6];
            }];
            break;
        case 6:
            if (![self feature:QCBandFeatureTemperature]) { [self syncDay:day + 1 phase:0]; return; }
            [QCSDKCmdCreator getTemperatureDataWithIntervalByDayIndex:day finished:^(NSInteger interval, NSArray *values, __unused NSError *error) {
                NSDate *base = [weakSelf dayStart:day];
                [values enumerateObjectsUsingBlock:^(id value, NSUInteger index, BOOL *stop) {
                    double amount = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : ([value isKindOfClass:QCTemperatureModel.class] ? [(QCTemperatureModel *)value temperature] : 0);
                    NSDate *date = [value isKindOfClass:QCTemperatureModel.class] ? [(QCTemperatureModel *)value time] : [base dateByAddingTimeInterval:index * MAX(1, interval) * 60];
                    [weakSelf addSingle:@"body_temperature" date:date value:amount unit:@"℃" minimum:20 maximum:45];
                }];
                [weakSelf syncDay:day + 1 phase:0];
            }];
            break;
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

- (void)handleCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *arguments = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};
    if ([call.method isEqualToString:@"scanDevices"]) { [self startScan:result]; }
    else if ([call.method isEqualToString:@"lookupBondedDevice"]) { result(nil); }
    else if ([call.method isEqualToString:@"stopScan"]) { [self finishScan]; result(nil); }
    else if ([call.method isEqualToString:@"connect"]) { [self connect:arguments result:result]; }
    else if ([call.method isEqualToString:@"disconnect"]) { [self.central disconnect]; self.featureList = nil; result(nil); }
    else if ([call.method isEqualToString:@"getDeviceDetails"]) { result([self isResolved] ? [self deviceDetails] : nil); }
    else if ([call.method isEqualToString:@"getCapabilities"]) { result([self isResolved] ? [self capabilities] : [self error:@"CAPABILITIES_UNAVAILABLE" message:@"请先连接戒指"]); }
    else if ([call.method isEqualToString:@"syncHealthData"]) { [self syncHealth:result]; }
    else if ([call.method isEqualToString:@"startMeasurement"]) { [self startMeasurement:arguments[@"metric"] result:result]; }
    else if ([call.method isEqualToString:@"stopMeasurement"]) { [self stopMeasurement:arguments[@"metric"] result:result]; }
    else if ([call.method isEqualToString:@"startSport"]) { [self startSport:arguments[@"mode"] result:result]; }
    else if ([call.method isEqualToString:@"stopSport"]) { [self stopSport:result]; }
    else if ([call.method isEqualToString:@"readSportRecords"]) { [self readSportRecords:result]; }
    else if ([call.method isEqualToString:@"readAutoMeasureSettings"]) { [self readAutoSettings:result]; }
    else if ([call.method isEqualToString:@"setAutoMeasureSetting"]) { [self setAutoSetting:arguments[@"type"] enabled:[arguments[@"enabled"] boolValue] result:result]; }
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
    }
}

- (void)scanPeripheralFinish { [self finishScan]; }

- (void)didState:(QCState)state {
    if (state == QCStateConnected) { [self resolveCapabilities]; return; }
    if (state == QCStateDisconnected || state == QCStateUnbind) {
        NSString *retired = self.connectedID;
        self.featureList = nil;
        self.activeMetric = nil;
        self.activeSportType = -1;
        if (self.pendingConnect) { [self failConnect:@"QRING_DISCONNECTED" message:@"戒指连接中断，请靠近手机后重试"]; }
        else if (retired.length) { [self emit:@"disconnected" payload:@{@"deviceId": retired}]; }
    }
}

- (void)didFailConnected:(__unused CBPeripheral *)peripheral error:(__unused NSError *)error {
    [self failConnect:@"QRING_CONNECT_FAILED" message:@"戒指连接失败，请靠近手机后重试"];
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
