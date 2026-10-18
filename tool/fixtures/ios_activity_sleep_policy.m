#import "SayRingActivitySleepPolicy.h"

static NSUInteger checked = 0;
static void check(BOOL value) { checked++; if (!value) abort(); }

int main(void) { @autoreleasepool {
    for (NSString *metric in @[@"heart_rate", @"blood_oxygen", @"blood_pressure", @"blood_glucose", @"body_temperature", @"hrv", @"stress", @"ecg", @"body_composition", @"blood_composition", @"unknown"])
        check(!SRActivitySleepMetricAllowed(metric));
    for (NSString *metric in @[@"steps", @"distance", @"calories", @"sleep"]) check(SRActivitySleepMetricAllowed(metric));
    check(!SRActivitySleepMetricAllowed(NSNull.null));
    for (NSString *command in @[@"startMeasurement", @"stopMeasurement", @"readHeartRateWarning", @"setHeartRateWarning", @"calibrateBloodPressure", @"calibrateBloodGlucose", @"unknownCommand"])
        check(!SRActivitySleepCommandAllowed(command, @{}));
    for (NSString *command in @[@"readDeviceFeature", @"writeDeviceFeature", @"triggerDeviceAction"]) {
        for (NSString *feature in @[@"health_assessment", @"health_reminders", @"blood_pressure_calibration", @"blood_glucose_calibration", @"new_health_feature"])
            check(!SRActivitySleepCommandAllowed(command, @{@"feature": feature}));
        for (NSString *feature in @[@"camera", @"gesture_control", @"find_watch", @"call_reminder", @"health_monitoring"])
            check(SRActivitySleepCommandAllowed(command, @{@"feature": feature}));
    }
    for (NSString *command in @[@"scanDevices", @"connect", @"disconnect", @"configureRecoveryTarget", @"prepareRememberedDevice", @"syncHealthData", @"getDeviceDetails", @"stopSport", @"saveGalleryImage", @"readAutoMeasureSettings", @"setAutoMeasureSetting", @"readAutoMeasureIntervals", @"setAutoMeasureInterval"])
        check(SRActivitySleepCommandAllowed(command, @{}));

    NSDictionary *caps = @{@"resolved": @YES, @"metrics": @[@"steps", @"sleep", @"hrv"], @"historyMetrics": @[@"sleep", @"blood_oxygen"], @"manualMetrics": @[@"heart_rate"], @"features": @[@"camera", @"health_monitoring"], @"integratedFeatures": @[@"health_assessment", @"find_watch"], @"sportModes": @[@"walking"]};
    NSDictionary *filtered = SRActivitySleepCapabilities(caps);
    check([filtered[@"metrics"] isEqual:@[@"steps", @"sleep"]]);
    check([filtered[@"historyMetrics"] isEqual:@[@"sleep"]]);
    check([filtered[@"manualMetrics"] count] == 0);
    check([filtered[@"features"] isEqual:@[@"camera", @"health_monitoring"]]);
    check([filtered[@"integratedFeatures"] isEqual:@[@"find_watch"]]);
    check([filtered[@"sportModes"] isEqual:caps[@"sportModes"]]);
    check([SRActivitySleepEvent(@"capabilitiesUpdated", caps) isEqual:filtered]);
    check([caps[@"manualMetrics"] count] == 1); // Do not mutate device/source state.

    NSDictionary *sleep = @{@"id":@"synthetic-sleep", @"type":@"sleep", @"values":@{@"value":@7, @"deepHours":@2, @"heartRate":@90, @"score":@88}, @"measuredAt":@"2026-10-06T16:00:00Z", @"sleepTimeline":@{@"sdkDate":@"2026-10-07", @"sessions":@[]}, @"samples":@[@90]};
    NSDictionary *heart = @{@"id":@"synthetic-heart", @"type":@"heart_rate", @"values":@{@"value":@90}};
    NSDictionary *step = @{@"id":@"synthetic-steps", @"type":@"steps", @"values":@{@"value":@123, @"blood_oxygen":@98}};
    NSArray *records = SRActivitySleepResult(@"syncHealthData", @[sleep, heart, step, NSNull.null]);
    check(records.count == 2);
    check([records[0][@"values"] isEqual:@{@"value":@7, @"deepHours":@2}]);
    check([records[1][@"values"] isEqual:@{@"value":@123}]);
    check([records[0][@"sleepTimeline"] isEqual:sleep[@"sleepTimeline"]]);
    check(records[0][@"samples"] == nil);
    check(SRActivitySleepEvent(@"healthRecord", heart) == nil);
    check(SRActivitySleepEvent(@"measurementProgress", @{@"metric":@"heart_rate"}) == nil);
    check(SRActivitySleepEvent(@"healthDataReady", @{@"metric":@"ecg"}) == nil);
    check([SRActivitySleepEvent(@"healthDataReady", @{}) isEqual:@{}]);
    NSDictionary *timelineEvent = @{@"sleepTimeline":@{@"sdkDate":@"2026-10-07", @"rawSummary":@{@"deepSeconds":@7200, @"score":@95, @"meanHeartRate":@72}}};
    NSDictionary *timelineProjection = SRActivitySleepEvent(@"sleepDay", timelineEvent);
    check([timelineProjection[@"sleepTimeline"][@"rawSummary"] isEqual:@{@"deepSeconds":@7200}]);
    check([timelineEvent[@"sleepTimeline"][@"rawSummary"][@"score"] isEqual:@95]);
    check([SRActivitySleepEvent(@"reconnected", @{@"id":@"synthetic-target"}) isEqual:@{@"id":@"synthetic-target"}]);
    NSDictionary *batch = SRActivitySleepResult(@"syncHealthData", @{@"records":@[heart, step], @"statuses":@{@"steps":@"complete", @"blood_oxygen":@"partial", @"sleep":@"no_data"}});
    check([batch[@"records"] count] == 1);
    check([batch[@"statuses"] isEqual:@{@"steps":@"complete", @"sleep":@"no_data"}]);
    check(SRActivitySleepRecord(@{@"type":@"sleep", @"values":NSNull.null}) == nil);
    NSError *error = [NSError errorWithDomain:@"synthetic" code:1 userInfo:nil];
    check(SRActivitySleepResult(@"syncHealthData", error) == error);
    NSArray *sport = SRActivitySleepResult(@"readSportRecords", @[@{@"id":@"synthetic-sport", @"mode":@"walking", @"steps":@123, @"heartRate":@90, @"maximumHeartRate":@120}]);
    check([sport[0] isEqual:@{@"id":@"synthetic-sport", @"mode":@"walking", @"steps":@123}]);
    // Synthetic grants never bypass the hard manual/medical ceiling.
    check(SRConfigureReadOnlyHealthLease(@{@"metrics": @[@"heart_rate", @"hrv", @"blood_oxygen"], @"validForSeconds": @60}));
    check(SRActivitySleepMetricAllowed(@"heart_rate"));
    check(SRActivitySleepMetricAllowed(@"hrv"));
    check(!SRActivitySleepMetricAllowed(@"body_temperature"));
    check(!SRActivitySleepMetricAllowed(@"blood_pressure"));
    check(!SRActivitySleepCommandAllowed(@"startMeasurement", @{@"metric": @"heart_rate"}));
    check([SRActivitySleepRecord(heart)[@"values"] isEqual:@{@"value": @90}]);
    check([SRActivitySleepCapabilities(caps)[@"metrics"] isEqual:@[@"steps", @"sleep", @"hrv"]]);
    NSDictionary *granted = SRActivitySleepResult(@"syncHealthData", @{@"records":@[heart, step], @"statuses":@{@"heart_rate":@"complete", @"blood_pressure":@"partial", @"steps":@"no_data"}});
    check([granted[@"records"] count] == 2);
    check([granted[@"statuses"] isEqual:@{@"heart_rate":@"complete", @"steps":@"no_data"}]);
    check(!SRConfigureReadOnlyHealthLease(@{@"metrics": @[@"blood_pressure"], @"validForSeconds": @60}));
    check(!SRActivitySleepMetricAllowed(@"heart_rate"));
    check(!SRConfigureReadOnlyHealthLease(@{@"metrics": @[@"heart_rate"], @"validForSeconds": @YES}));
    check(!SRConfigureReadOnlyHealthLease(@{@"metrics": @[@"heart_rate"], @"validForSeconds": @301}));
    check(!SRConfigureReadOnlyHealthLease(@{@"metrics": @[@"heart_rate"], @"validForSeconds": @0}));
    check(SRConfigureReadOnlyHealthLease(@{@"metrics": @[], @"validForSeconds": @0}));
    check(!SRActivitySleepMetricAllowed(@"hrv"));
    check(SRActivitySleepMetricAllowed(@"sleep"));
    // The new binary must explicitly ACK the distinct manual lease. The read
    // grant above is not a server permission to start a physiological command.
    check(SRConfigureReadOnlyHealthLease(@{@"metrics": @[@"heart_rate", @"hrv", @"blood_oxygen", @"stress"], @"validForSeconds": @60}));
    check(!SRManualHealthMetricAllowed(@"heart_rate"));
    check(SRConfigureManualHealthLease(@{@"metrics": @[@"heart_rate", @"hrv", @"blood_oxygen"], @"validForSeconds": @60}));
    for (NSString *metric in SRManualHealthCatalogue()) {
        check(SRManualHealthMetricAllowed(metric));
        check(SRActivitySleepCommandAllowed(@"startMeasurement", @{@"metric":metric}));
        check(SRActivitySleepCommandAllowed(@"stopMeasurement", @{@"metric":metric}));
        check(SRActivitySleepEvent(@"measurementProgress", @{@"metric":metric, @"progress":@0}) != nil);
    }
    check([SRActivitySleepCapabilities(caps)[@"manualMetrics"] isEqual:@[@"heart_rate"]]);
    check(SRActivitySleepRecord(@{@"type":@"heart_rate", @"origin":@"app_measurement", @"values":@{@"value":@72}}) != nil);
    SRManualHealthLease()[@"deadline"] = @(NSProcessInfo.processInfo.systemUptime - 1);
    check(!SRManualHealthMetricAllowed(@"heart_rate"));
    check(!SRActivitySleepCommandAllowed(@"startMeasurement", @{@"metric":@"heart_rate"}));
    check(SRActivitySleepCommandAllowed(@"stopMeasurement", @{@"metric":@"heart_rate"}));
    check(!SRConfigureManualHealthLease(@{@"metrics":@[@"stress"], @"validForSeconds":@60}));
    check(!SRManualHealthMetricAllowed(@"heart_rate"));
    check(SRActivitySleepMetricAllowed(@"heart_rate"));
    check(SRActivitySleepCommandAllowed(@"stopMeasurement", @{@"metric":@"heart_rate"}));
    check(SRActivitySleepRecord(@{@"type":@"heart_rate", @"origin":@"app_measurement", @"values":@{@"value":@72}}) == nil);
    check(!SRConfigureManualHealthLease(@{@"metrics":@[@"heart_rate"], @"validForSeconds":@YES}));
    check(SRConfigureManualHealthLease(@{@"metrics":@[], @"validForSeconds":@0}));
    SRCloseReadOnlyHealthLease();
    printf("Activity/sleep + read-only native policy: %lu assertions passed\n", (unsigned long)checked);
} return 0; }
