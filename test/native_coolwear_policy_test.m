#import <Foundation/Foundation.h>
#import "../ios/Runner/CoolWearPolicy.h"
#import "../ios/Runner/CoolWearRecovery.h"
#import "../ios/Runner/CoolWearHistory.h"
#import "../ios/Runner/CoolWearMonitoring.h"
#import "../ios/Runner/CoolWearControls.h"

@interface CWCallbackQueue : NSObject
@property(nonatomic, copy) dispatch_block_t callback;
- (void)finish;
@end
@implementation CWCallbackQueue
- (void)finish {
    dispatch_block_t callback = self.callback;
    if (callback) callback();
    // Same ordering as the supplied SDK: callback before clearing current cmd.
    self.callback = nil;
}
@end

int main(void) {
    @autoreleasepool {
        for (NSNumber *mode in @[@0, @1, @2, @3, @4, @5]) NSCAssert([CoolWearGestureMode(mode) isEqual:mode], @"valid gesture rejected");
        for (id raw in @[@YES, @(-1), @6, @1.5, @"4", NSNull.null]) NSCAssert(!CoolWearGestureMode(raw), @"invalid gesture accepted");
        NSCAssert([CoolWearCallReminder(@{@"onoff": @0}) isEqual:@0], @"disabled reminder lost");
        NSCAssert([CoolWearCallReminder(@{@"onoff": @1}) isEqual:@1], @"enabled reminder lost");
        NSCAssert(!CoolWearCallReminder(@{}) && !CoolWearCallReminder(@{@"onoff": @2}), @"unknown reminder fabricated");
        for (NSUInteger mask = 0; mask < 8; mask++) {
            NSCAssert(CoolWearCameraShutter(@{@"takePhoto": @1}, mask & 1, mask & 2, mask & 4) == (mask == 7), @"unsafe shutter event");
        }
        NSCAssert(!CoolWearCameraShutter(@{}, YES, YES, YES) && !CoolWearCameraShutter(@{@"takePhoto": @0}, YES, YES, YES), @"missing/stop shutter interpreted as a photo");
        CWCallbackQueue *queue = [CWCallbackQueue new];
        __weak CWCallbackQueue *weakQueue = queue;
        __block BOOL followupCompleted = NO;
        queue.callback = ^{ weakQueue.callback = ^{ followupCompleted = YES; }; };
        [queue finish];
        NSCAssert(queue.callback == nil && !followupCompleted, @"inline queue regression not reproduced");
        queue.callback = ^{
            CoolWearAfterSDKCallback(^{
                weakQueue.callback = ^{ followupCompleted = YES; };
                [weakQueue finish];
            });
        };
        [queue finish];
        NSCAssert(!followupCompleted, @"SDK callback deferred work ran inline");
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1];
        while (!followupCompleted && deadline.timeIntervalSinceNow > 0)
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        NSCAssert(followupCompleted, @"deferred followup lost its callback");
        NSString *uuid = @"11111111-2222-4333-8444-555555555555";
        NSCAssert(CoolWearRecoveryTargetValid(uuid, @"HR01", @"env:owner"), @"exact recovery rejected");
        for (NSString *bad in @[@"", @"HR01", @"not-a-uuid"])
            NSCAssert(!CoolWearRecoveryTargetValid(bad, @"HR01", @"env:owner"), @"arbitrary target accepted");
        NSCAssert(!CoolWearRecoveryTargetValid(uuid, @"HR02", @"env:owner"), @"unconfirmed model accepted");
        NSCAssert(!CoolWearRecoveryTargetValid(uuid, @"HR01", @""), @"missing owner accepted");
        NSCAssert(CoolWearRecoveryMatches(uuid, @"hr01", uuid, @"HR01", @"env:owner", 2, 2), @"bound target lost");
        NSCAssert(!CoolWearRecoveryMatches(nil, @"HR01", uuid, @"HR01", @"env:owner", 2, 2), @"missing UUID accepted");
        NSCAssert(!CoolWearRecoveryMatches(@"AAAAAAAA-2222-4333-8444-555555555555", @"HR01", uuid, @"HR01", @"env:owner", 2, 2), @"same-name foreign ring adopted");
        NSCAssert(!CoolWearRecoveryMatches(uuid, @"HR05", uuid, @"HR01", @"env:owner", 2, 2), @"changed model adopted");
        NSCAssert(!CoolWearRecoveryMatches(uuid, @"HR01", uuid, @"HR01", @"env:owner", 1, 2), @"late callback adopted");
        NSDictionary *names = @{@"hr01": @"HR01", @" Hr05_12ab ": @"HR05", @"K80-7F": @"K80",
            @"r7": @"R7", @"R7y": @"R7Y", @"r7pro_001": @"R7Pro", @"HR01-legacy": @"HR01",
            @"R7_AA:BB:CC:DD:EE:FF": @"R7"};
        for (NSString *name in names) NSCAssert([CoolWearModel(name) isEqualToString:names[name]], @"confirmed name rejected");
        for (NSString *name in @[@"", @"R21", @"Q_Ring", @"K800", @"K80Pro", @"R70", @"R7Y2", @"R7Pro2", @"R7Protein", @"HR05-unknown", @"R7_abcd/../../", @"R7_1234567890123"])
            NSCAssert(CoolWearModel(name) == nil, @"unconfirmed candidate accepted");
        NSCAssert(CoolWearModel(nil) == nil, @"nil name accepted");
        NSDictionary *all = @{@"manualHr": @1, @"hasHR24h": @1, @"showO2": @1, @"hrvSupport": @1, @"temp_supported": @1, @"showBP": @1};
        NSDictionary *resolved = CoolWearCapabilities(all, YES);
        NSCAssert([resolved[@"supportsHistorySync"] isEqual:@YES], @"mapped history unavailable");
        NSCAssert([CoolWearCapabilities(all, NO)[@"supportsHistorySync"] isEqual:@NO], @"pre-handshake history exposed");
        NSCAssert(([resolved[@"metrics"] isEqual:@[@"heart_rate", @"blood_oxygen", @"hrv", @"body_temperature"]]), @"unsupported metric enabled");
        NSCAssert(([resolved[@"manualMetrics"] isEqual:@[@"heart_rate", @"blood_oxygen", @"hrv"]]), @"manual mapping incorrect");
        NSCAssert([CoolWearCapabilities(all, NO)[@"metrics"] count] == 0, @"pre-handshake metrics exposed");
        NSDictionary *automatic = CoolWearCapabilities(@{@"hasHR24h": @1, @"manualHr": @0, @"showO2": @0}, YES);
        NSCAssert([automatic[@"manualMetrics"] count] == 0, @"automatic-only HR permits manual measurement");
        NSCAssert(([automatic[@"historyMetrics"] isEqual:@[@"heart_rate"]]), @"automatic heart history lost");
        NSCAssert([CoolWearCapabilities(@{@"manualHr": @"1", @"showO2": @2}, YES)[@"metrics"] count] == 0, @"malformed flags coerced");
        NSCAssert([CoolWearCapabilities(@{@"manualHr": @1.5, @"showO2": @(NAN)}, YES)[@"metrics"] count] == 0, @"fractional flags coerced");
        NSCAssert(CoolWearHasKnownCapabilities(@{@"manualHr": @NO, @"showO2": @YES}), @"real Boolean flags rejected");
        NSCAssert(!CoolWearHasKnownCapabilities(@{@"manualHr": @2, @"showO2": @1.5}), @"invalid capability response accepted");
        __block NSUInteger completions = 0;
        NSDictionary *monitor = @{@"onoff":@1, @"hr24hOnoff":@0, @"oxOnOff":@0, @"time":@60};
        NSDictionary *monitorFlags = @{@"hasHR24h":@1, @"O2_auto_switch":@1};
        NSCAssert(CoolWearMonitoringSnapshot(monitor).count == 4, @"real complete setting rejected");
        NSCAssert(([CoolWearMonitoringSettings(monitor, monitorFlags) isEqual:@{@"heartRate":@YES,@"heartRate24h":@NO,@"bloodOxygen":@NO}]), @"switch mapping incorrect");
        NSDictionary *changed = CoolWearMonitoringChange(monitor, monitorFlags, @"bloodOxygen", YES);
        NSCAssert(([changed isEqual:@{@"onoff":@1,@"hr24hOnoff":@0,@"oxOnOff":@1,@"time":@60}]), @"single switch reset another raw field");
        NSCAssert(CoolWearMonitoringSettings(monitor, @{}).count == 1, @"unsupported switches exposed");
        NSCAssert(CoolWearMonitoringChange(monitor, @{}, @"heartRate24h", YES) == nil, @"unconfirmed continuous HR enabled");
        NSCAssert(CoolWearMonitoringChange(monitor, monitorFlags, @"sleep", YES) == nil, @"invented sleep switch");
        for (NSString *key in monitor) {
            NSMutableDictionary *invalid = [monitor mutableCopy]; [invalid removeObjectForKey:key];
            NSCAssert(CoolWearMonitoringSnapshot(invalid) == nil, @"partial snapshot accepted");
            invalid[key] = @"1";
            NSCAssert(CoolWearMonitoringSnapshot(invalid) == nil, @"coerced string setting");
        }
        NSCAssert(CoolWearMonitoringSnapshot(@{@"onoff":@2,@"hr24hOnoff":@0,@"oxOnOff":@0,@"time":@60}) == nil, @"invalid switch accepted");
        NSCAssert(CoolWearMonitoringSnapshot(@{@"onoff":@1,@"hr24hOnoff":@0,@"oxOnOff":@0,@"time":@256}) == nil, @"invalid interval byte accepted");
        __block id response = nil;
        CoolWearCompletion once = CoolWearCompleteOnce(^(id value) { completions++; response = value; });
        once(@"sdk_error");
        once(@"second_completion");
        NSCAssert(completions == 1 && [response isEqual:@"sdk_error"], @"request completed twice");
        NSCAssert([CoolWearMeasurementValue(@"heart_rate", @{@"heartNum": @76}) isEqual:@76], @"real heart rejected");
        NSCAssert([CoolWearMeasurementValue(@"blood_oxygen", @{@"oxygen": @98}) isEqual:@98], @"real oxygen rejected");
        for (id value in @[@0, @(-1), @251, @YES, @"76", NSNull.null, @(NAN), @(INFINITY)])
            NSCAssert(CoolWearMeasurementValue(@"heart_rate", @{@"heartNum": value}) == nil, @"invalid heart accepted");
        NSCAssert(CoolWearMeasurementValue(@"blood_oxygen", @{@"oxygen": @101}) == nil, @"invalid oxygen accepted");
        NSCAssert(CoolWearMeasurementValue(@"stress", @{@"oxygen": @50}) == nil, @"unverified metric accepted");
        NSCAssert(CoolWearMeasurementValue(@"heart_rate", @{}) == nil, @"missing value invented");
        NSCAssert([CoolWearCapabilities(@{@"hrvSupport": @"1", @"temp_supported": @2}, YES)[@"metrics"] count] == 0, @"unconfirmed advanced capability exposed");
        NSDictionary *hrv = @{@"time": @1791000000, @"meanRR": @800, @"sdnn": @42,
            @"rmssd": @35, @"pnn50": @0, @"meanHR": @75, @"validCount": @80,
            @"rejectedCount": @0, @"quality": @3, @"flags": @0};
        NSDictionary *values = CoolWearRriHrvValues(hrv);
        NSCAssert([values[@"value"] isEqual:@42] && [values[@"sdnn"] isEqual:@42] && [values[@"rmssd"] isEqual:@35], @"HRV milliseconds changed");
        NSCAssert([values[@"pnn"] isEqual:@0] && [values[@"rejectedCount"] isEqual:@0], @"real zero auxiliary fields lost");
        NSCAssert(CoolWearRriHrvValues(@{@"heartNum": @42}) == nil, @"legacy ambiguous HRV accepted");
        for (NSString *key in hrv) {
            if ([key isEqual:@"time"]) continue;
            NSMutableDictionary *missing = [hrv mutableCopy];
            [missing removeObjectForKey:key];
            NSCAssert(CoolWearRriHrvValues(missing) == nil, @"partial metrics accepted");
            for (id invalid in @[@YES, @"1", NSNull.null, @(NAN), @(INFINITY), @(-1), @1.5]) {
                NSMutableDictionary *malformed = [hrv mutableCopy];
                malformed[key] = invalid;
                NSCAssert(CoolWearRriHrvValues(malformed) == nil, @"invalid RRI field accepted");
            }
        }
        for (NSDictionary *invalid in @[@{@"quality": @0}, @{@"quality": @4}, @{@"validCount": @1}, @{@"sdnn": @0}, @{@"sdnn": @1001}, @{@"meanRR": @0}, @{@"pnn50": @101}]) {
            NSMutableDictionary *sample = [hrv mutableCopy]; [sample addEntriesFromDictionary:invalid];
            NSCAssert(CoolWearRriHrvValues(sample) == nil, @"invalid RRI quality or range accepted");
        }
        for (NSNumber *quality in @[@1, @2, @3]) {
            NSMutableDictionary *sample = [hrv mutableCopy]; sample[@"quality"] = quality;
            NSCAssert([CoolWearRriHrvValues(sample)[@"sdkQuality"] isEqual:quality], @"SDK quality replaced");
        }
        NSCAssert([CoolWearSkinTemperatureValues(@{@"tempNum": @33.6})[@"value"] isEqual:@33.6], @"temperature divided twice");
        for (id invalid in @[@336, @3.36, @19.9, @45.1, @YES, @"33.6", @(NAN), @(INFINITY), NSNull.null])
            NSCAssert(CoolWearSkinTemperatureValues(@{@"tempNum": invalid}) == nil, @"invalid temperature accepted");
        NSDate *now = [NSDate dateWithTimeIntervalSince1970:1791000000];
        NSCAssert([CoolWearSampleDate(@1791000000, now) isEqual:now], @"SDK seconds changed");
        for (id time in @[@1791000000000, @0, @1, @1791000121, @1791000000.5, @YES, @"1791000000", @(NAN)])
            NSCAssert(CoolWearSampleDate(time, now) == nil, @"invalid time accepted");
        NSDictionary *batch = @{@"curItemCount": @1, @"hrvMetricsInfos": @[hrv]};
        NSCAssert([CoolWearMetricSamples(batch, @"hrvMetricsInfos") count] == 1, @"single batch lost");
        NSCAssert([CoolWearMetricSamples(@[batch, batch], @"hrvMetricsInfos") count] == 2, @"batch array lost");
        NSCAssert([CoolWearMetricSamples(@{@"curItemCount": @2, @"hrvMetricsInfos": @[hrv]}, @"hrvMetricsInfos") count] == 0, @"incomplete batch accepted");
        NSCAssert([CoolWearMetricSamples(@{@"curItemCount": @YES, @"hrvMetricsInfos": @[hrv]}, @"hrvMetricsInfos") count] == 0, @"Boolean count accepted");
        NSCAssert([CoolWearMetricSamples(NSNull.null, @"hrvMetricsInfos") count] == 0, @"invalid batch accepted");
        CoolWearHistoryBatch *history = [CoolWearHistoryBatch new];
        NSCAssert([[history status] isEqual:@"not_received"], @"missing callback claimed complete");
        NSDictionary *last = @{@"curItemCount":@1, @"remainItemCount":@0, @"heartInfos":@[@{@"time":@1791000000,@"heartNum":@76}]};
        NSDictionary *first = @{@"curItemCount":@1, @"remainItemCount":@1, @"heartInfos":@[@{@"time":@1790999940,@"heartNum":@75}]};
        [history accept:first key:@"heartInfos"];
        [history accept:first key:@"heartInfos"];
        NSCAssert(history.rows.count == 1 && [[history status] isEqual:@"partial"], @"duplicate packet completed sync");
        [history accept:last key:@"heartInfos"];
        NSCAssert([[history status] isEqual:@"complete"], @"complete batch lost");
        CoolWearHistoryBatch *reverse = [CoolWearHistoryBatch new];
        [reverse accept:last key:@"heartInfos"]; [reverse accept:first key:@"heartInfos"];
        NSCAssert([[reverse status] isEqual:@"complete"] && reverse.rows.count == 2, @"out-of-order batch lost");
        CoolWearHistoryBatch *empty = [CoolWearHistoryBatch new];
        [empty accept:@{@"curItemCount":@0,@"remainItemCount":@0,@"heartInfos":@[]} key:@"heartInfos"];
        NSCAssert([[empty status] isEqual:@"no_data"], @"empty data is failure");
        [empty accept:@{@"curItemCount":@1,@"remainItemCount":@0,@"heartInfos":@[]} key:@"heartInfos"];
        NSCAssert([[empty status] isEqual:@"partial"], @"missing rows claimed complete");
        NSArray *sleep = @[@{@"SleepStartTime":@1790990000,@"SleepType":@1},
            @{@"SleepStartTime":@1790990060,@"SleepType":@2},
            @{@"SleepStartTime":@1790993660,@"SleepType":@3},
            @{@"SleepStartTime":@1790997260,@"SleepType":@4}];
        NSArray *closed = CoolWearClosedSleepSummaries(sleep, now);
        NSCAssert(closed.count == 1 && [closed[0][@"values"][@"value"] doubleValue] == 2, @"bounded sleep durations incorrect");
        NSCAssert(CoolWearClosedSleepSummaries([sleep subarrayWithRange:NSMakeRange(0,3)], now).count == 0, @"missing end invented");
        NSCAssert(CoolWearClosedSleepSummaries([sleep subarrayWithRange:NSMakeRange(1,3)], now).count == 0, @"missing start invented");
        NSMutableArray *conflicting = [sleep mutableCopy]; [conflicting addObject:@{@"SleepStartTime":@1790993660,@"SleepType":@5}];
        NSCAssert(CoolWearClosedSleepSummaries(conflicting, now).count == 0, @"conflicting stage accepted");
        NSCAssert(CoolWearUnsigned(@0.5,1) == nil && CoolWearUnsigned(@YES,1) == nil, @"invalid charging flag accepted");
        puts("CoolWear native history/battery/name/capability/RRI policy: PASS (synthetic inputs, not hardware acceptance)");
    }
    return 0;
}
