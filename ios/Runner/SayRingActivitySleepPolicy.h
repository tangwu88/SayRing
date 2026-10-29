#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Fixed read-only ceiling for users and reviewers. No persisted, account,
// review-device or build-mode override can extend this catalogue.
static inline NSArray<NSString *> *SRReadOnlyHealthCatalogue(void) {
    return @[@"heart_rate", @"hrv", @"blood_oxygen", @"body_temperature", @"stress"];
}

// Each adapter translation unit owns its short-lived in-memory lease.
static inline NSMutableDictionary *SRReadOnlyHealthLease(void) {
    static NSMutableDictionary *lease;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lease = [NSMutableDictionary dictionary]; });
    return lease;
}

static inline NSArray<NSString *> *SRManualHealthCatalogue(void) {
    return @[@"heart_rate", @"hrv", @"blood_oxygen"];
}

static inline NSMutableDictionary *SRManualHealthLease(void) {
    static NSMutableDictionary *lease;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lease = [NSMutableDictionary dictionary]; });
    return lease;
}

static inline void SRCloseReadOnlyHealthLease(void) {
    NSMutableDictionary *lease = SRReadOnlyHealthLease();
    @synchronized (lease) { [lease removeAllObjects]; }
}

static inline BOOL SRConfigureHealthLease(NSDictionary *arguments, NSMutableDictionary *lease, NSArray *catalogue) {
    id metrics = arguments[@"metrics"], seconds = arguments[@"validForSeconds"];
    if (![metrics isKindOfClass:NSArray.class] || ![seconds isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)seconds) == CFBooleanGetTypeID() ||
        [seconds doubleValue] != [seconds integerValue] || [seconds integerValue] < 0 || [seconds integerValue] > 300) {
        @synchronized (lease) { [lease removeAllObjects]; } return NO;
    }
    for (id metric in metrics) if (![metric isKindOfClass:NSString.class] || ![catalogue containsObject:metric]) {
        @synchronized (lease) { [lease removeAllObjects]; } return NO;
    }
    if ([seconds integerValue] == 0) {
        @synchronized (lease) { [lease removeAllObjects]; } return [metrics count] == 0;
    }
    @synchronized (lease) {
        lease[@"metrics"] = [metrics copy];
        lease[@"deadline"] = @(NSProcessInfo.processInfo.systemUptime + [seconds integerValue]);
    }
    return YES;
}

static inline BOOL SRConfigureReadOnlyHealthLease(NSDictionary *arguments) {
    return SRConfigureHealthLease(arguments, SRReadOnlyHealthLease(), SRReadOnlyHealthCatalogue());
}

static inline BOOL SRConfigureManualHealthLease(NSDictionary *arguments) {
    return SRConfigureHealthLease(arguments, SRManualHealthLease(), SRManualHealthCatalogue());
}

static inline BOOL SRActivitySleepMetricAllowed(id metric) {
    if (![metric isKindOfClass:NSString.class]) return NO;
    if ([@[@"steps", @"distance", @"calories", @"sleep"] containsObject:metric]) return YES;
    NSMutableDictionary *lease = SRReadOnlyHealthLease();
    @synchronized (lease) {
        return NSProcessInfo.processInfo.systemUptime < [lease[@"deadline"] doubleValue] &&
            [lease[@"metrics"] containsObject:metric];
    }
}

// A read lease alone never grants a start command. This distinct lease is
// requested only by the new binary's fixed manual feature scope, not by a
// server field or a reviewer/account/build-mode exception.
static inline BOOL SRManualHealthMetricAllowed(id metric) {
    if (!SRActivitySleepMetricAllowed(metric) || ![SRManualHealthCatalogue() containsObject:metric]) return NO;
    NSMutableDictionary *lease = SRManualHealthLease();
    @synchronized (lease) {
        return NSProcessInfo.processInfo.systemUptime < [lease[@"deadline"] doubleValue] &&
            [lease[@"metrics"] containsObject:metric];
    }
}

static inline BOOL SRActivitySleepFeatureAllowed(id feature) {
    return [feature isKindOfClass:NSString.class] &&
        [@[@"find_watch", @"camera", @"gesture_control", @"call_reminder",
           @"notifications", @"phone_calls", @"contacts", @"alarms", @"weather",
           @"world_clock", @"screen_display", @"watch_faces", @"photo_watch_face",
           @"firmware_upgrade", @"units", @"health_monitoring"] containsObject:feature];
}

static inline BOOL SRActivitySleepCommandAllowed(NSString *method, NSDictionary *arguments) {
    // Personal reminder haptics are an explicitly requested physical action,
    // not a physiological measurement grant. Each vendor still checks the
    // current exact target, resolved capabilities and supported model.
    if ([method isEqual:@"pulseHealthReminder"]) {
        id identifier = arguments[@"expectedDeviceId"];
        return [identifier isKindOfClass:NSString.class] &&
            [[NSUUID alloc] initWithUUIDString:identifier] != nil;
    }
    if ([method isEqual:@"startMeasurement"]) return SRManualHealthMetricAllowed(arguments[@"metric"]);
    // Cleanup remains available after expiry/revocation, never a new start.
    if ([method isEqual:@"stopMeasurement"]) return [SRManualHealthCatalogue() containsObject:arguments[@"metric"] ?: NSNull.null];
    if ([@[@"readHeartRateWarning", @"setHeartRateWarning", @"calibrateBloodPressure",
           @"calibrateBloodGlucose", @"readHealthAssessment", @"writeHealthAssessment"] containsObject:method]) return NO;
    if ([@[@"readDeviceFeature", @"writeDeviceFeature", @"triggerDeviceAction"] containsObject:method])
        return SRActivitySleepFeatureAllowed(arguments[@"feature"]);
    return [@[@"scanDevices", @"stopScan", @"connect", @"disconnect", @"getDeviceDetails",
        @"getCapabilities", @"syncHealthData", @"clearRingHistory", @"startSport", @"stopSport", @"readSportRecords",
        @"configureRecoveryTarget", @"prepareRememberedDevice", @"lookupBondedDevice",
        @"listBondedDevices", @"getWatchFaceProfile", @"getNativeWatchFaceCatalog",
        @"downloadNativeWatchFace", @"saveGalleryImage", @"readAutoMeasureSettings",
        @"setAutoMeasureSetting", @"readAutoMeasureIntervals", @"setAutoMeasureInterval"] containsObject:method];
}

static inline NSArray *SRActivitySleepFilterNames(id source, BOOL features) {
    NSMutableArray *result = [NSMutableArray array];
    if ([source isKindOfClass:NSArray.class]) for (id value in source)
        if (features ? SRActivitySleepFeatureAllowed(value) : SRActivitySleepMetricAllowed(value)) [result addObject:value];
    return result;
}

static inline NSDictionary *SRActivitySleepCapabilities(NSDictionary *source) {
    NSMutableDictionary *result = [source mutableCopy];
    for (NSString *key in @[@"metrics", @"historyMetrics"])
        if (source[key]) result[key] = SRActivitySleepFilterNames(source[key], NO);
    NSMutableArray *manual = [NSMutableArray array];
    if ([source[@"manualMetrics"] isKindOfClass:NSArray.class]) for (id metric in source[@"manualMetrics"])
        if (SRManualHealthMetricAllowed(metric)) [manual addObject:metric];
    result[@"manualMetrics"] = manual;
    for (NSString *key in @[@"features", @"integratedFeatures"])
        result[key] = SRActivitySleepFilterNames(source[key], YES);
    return result;
}

static inline NSDictionary *SRActivitySleepKeepFields(NSDictionary *source, NSArray<NSString *> *keys) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *key in keys) if (source[key]) result[key] = source[key];
    return result;
}

static inline NSDictionary *SRActivitySleepTimeline(NSDictionary *source) {
    NSMutableDictionary *result = [source mutableCopy];
    if ([source[@"rawSummary"] isKindOfClass:NSDictionary.class]) {
        result[@"rawSummary"] = SRActivitySleepKeepFields(source[@"rawSummary"], @[
            @"totalSeconds", @"deepSeconds", @"lightSeconds", @"awakeSeconds",
            @"remSeconds", @"napSeconds", @"reportedTotalMinutes", @"wakeCount"
        ]);
    }
    return result;
}

static inline NSDictionary *_Nullable SRActivitySleepRecord(id source) {
    if (![source isKindOfClass:NSDictionary.class] || !SRActivitySleepMetricAllowed(source[@"type"])) return nil;
    if ([source[@"origin"] isEqual:@"app_measurement"] && !SRManualHealthMetricAllowed(source[@"type"])) return nil;
    NSMutableDictionary *result = [SRActivitySleepKeepFields(source, @[
        @"id", @"type", @"unit", @"measuredAt", @"timezone", @"deviceId", @"firmwareVersion",
        @"quality", @"source", @"origin", @"rawVersion", @"sourceModel", @"sourceVendor",
        @"sourceDeviceCategory", @"sourceApp", @"sleepTimeline"
    ]) mutableCopy];
    id values = source[@"values"];
    if (![values isKindOfClass:NSDictionary.class]) return nil;
    result[@"values"] = SRActivitySleepKeepFields(values, [source[@"type"] isEqual:@"sleep"] ? @[
        @"value", @"deepHours", @"lightHours", @"remHours", @"awakeMinutes",
        @"startTime", @"endTime", @"sleepStartTime", @"sleepEndTime"
    ] : @[@"value"]);
    if ([result[@"sleepTimeline"] isKindOfClass:NSDictionary.class])
        result[@"sleepTimeline"] = SRActivitySleepTimeline(result[@"sleepTimeline"]);
    return result;
}

static inline NSArray *SRActivitySleepRecords(id source) {
    NSMutableArray *records = [NSMutableArray array];
    if ([source isKindOfClass:NSArray.class]) for (id item in source) {
        NSDictionary *record = SRActivitySleepRecord(item);
        if (record) [records addObject:record];
    }
    return records;
}

static inline NSDictionary *SRActivitySleepSport(NSDictionary *source) {
    return SRActivitySleepKeepFields(source, @[
        @"id", @"mode", @"startedAt", @"endedAt", @"durationSeconds", @"distanceMeters",
        @"calories", @"steps", @"source", @"deviceId", @"firmwareVersion", @"origin",
        @"sourceModel", @"sourceVendor", @"sourceDeviceCategory", @"sourceApp"
    ]);
}

// Errors and unrelated metadata retain their actual type and value.
static inline id _Nullable SRActivitySleepResult(NSString *method, id _Nullable source) {
    if ([method isEqual:@"getCapabilities"] && [source isKindOfClass:NSDictionary.class])
        return SRActivitySleepCapabilities(source);
    if ([method isEqual:@"syncHealthData"]) {
        if ([source isKindOfClass:NSArray.class]) return SRActivitySleepRecords(source);
        if ([source isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *result = [source mutableCopy];
            result[@"records"] = SRActivitySleepRecords(source[@"records"]);
            if ([source[@"statuses"] isKindOfClass:NSDictionary.class])
                result[@"statuses"] = SRActivitySleepKeepFields(source[@"statuses"], SRActivitySleepFilterNames([source[@"statuses"] allKeys], NO));
            return result;
        }
    }
    if ([method isEqual:@"readSportRecords"] && [source isKindOfClass:NSArray.class]) {
        NSMutableArray *result = [NSMutableArray array];
        for (id record in source) if ([record isKindOfClass:NSDictionary.class]) [result addObject:SRActivitySleepSport(record)];
        return result;
    }
    return source;
}

static inline NSDictionary *_Nullable SRActivitySleepEvent(NSString *type, NSDictionary *payload) {
    if ([@[@"capabilities", @"capabilitiesUpdated"] containsObject:type]) return SRActivitySleepCapabilities(payload);
    if ([type isEqual:@"healthRecord"]) return SRActivitySleepRecord(payload);
    if ([type isEqual:@"measurementProgress"]) return SRManualHealthMetricAllowed(payload[@"metric"]) ? payload : nil;
    if (payload[@"metric"] && !SRActivitySleepMetricAllowed(payload[@"metric"])) return nil;
    if ([@[@"sportData", @"sportRecord"] containsObject:type]) return SRActivitySleepSport(payload);
    if ([payload[@"sleepTimeline"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *result = [payload mutableCopy];
        result[@"sleepTimeline"] = SRActivitySleepTimeline(payload[@"sleepTimeline"]);
        return result;
    }
    return payload;
}

NS_ASSUME_NONNULL_END
