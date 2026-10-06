#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Product scope for every user of this iOS release. This has no remote,
// account, review-device, build-mode or persisted-setting override.
static inline BOOL SRActivitySleepMetricAllowed(id metric) {
    return [metric isKindOfClass:NSString.class] &&
        [@[@"steps", @"distance", @"calories", @"sleep"] containsObject:metric];
}

static inline BOOL SRActivitySleepFeatureAllowed(id feature) {
    return [feature isKindOfClass:NSString.class] &&
        [@[@"find_watch", @"camera", @"gesture_control", @"call_reminder",
           @"notifications", @"phone_calls", @"contacts", @"alarms", @"weather",
           @"world_clock", @"screen_display", @"watch_faces", @"photo_watch_face",
           @"firmware_upgrade", @"units"] containsObject:feature];
}

static inline BOOL SRActivitySleepCommandAllowed(NSString *method, NSDictionary *arguments) {
    if ([@[@"startMeasurement", @"stopMeasurement", @"readAutoMeasureSettings",
           @"setAutoMeasureSetting", @"readAutoMeasureIntervals", @"setAutoMeasureInterval",
           @"readHeartRateWarning", @"setHeartRateWarning", @"calibrateBloodPressure",
           @"calibrateBloodGlucose", @"readHealthAssessment", @"writeHealthAssessment"] containsObject:method]) return NO;
    if ([@[@"readDeviceFeature", @"writeDeviceFeature", @"triggerDeviceAction"] containsObject:method])
        return SRActivitySleepFeatureAllowed(arguments[@"feature"]);
    return [@[@"scanDevices", @"stopScan", @"connect", @"disconnect", @"getDeviceDetails",
        @"getCapabilities", @"syncHealthData", @"startSport", @"stopSport", @"readSportRecords",
        @"configureRecoveryTarget", @"prepareRememberedDevice", @"lookupBondedDevice",
        @"listBondedDevices", @"getWatchFaceProfile", @"getNativeWatchFaceCatalog",
        @"downloadNativeWatchFace", @"saveGalleryImage"] containsObject:method];
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
    result[@"manualMetrics"] = @[];
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
                result[@"statuses"] = SRActivitySleepKeepFields(source[@"statuses"], @[@"steps", @"distance", @"calories", @"sleep"]);
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
    if ([type isEqual:@"measurementProgress"]) return nil;
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
