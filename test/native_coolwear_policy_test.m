#import <Foundation/Foundation.h>
#import "../ios/Runner/CoolWearPolicy.h"

int main(void) {
    @autoreleasepool {
        NSDictionary *names = @{@"hr01": @"HR01", @" Hr05_12ab ": @"HR05", @"K80-7F": @"K80",
            @"r7": @"R7", @"R7y": @"R7Y", @"r7pro_001": @"R7Pro", @"HR01-legacy": @"HR01",
            @"R7_AA:BB:CC:DD:EE:FF": @"R7"};
        for (NSString *name in names) NSCAssert([CoolWearModel(name) isEqualToString:names[name]], @"confirmed name rejected");
        for (NSString *name in @[@"", @"R21", @"Q_Ring", @"K800", @"K80Pro", @"R70", @"R7Y2", @"R7Pro2", @"R7Protein", @"HR05-unknown", @"R7_abcd/../../", @"R7_1234567890123"])
            NSCAssert(CoolWearModel(name) == nil, @"unconfirmed candidate accepted");
        NSCAssert(CoolWearModel(nil) == nil, @"nil name accepted");
        NSDictionary *all = @{@"manualHr": @1, @"hasHR24h": @1, @"showO2": @1, @"hrvSupport": @1, @"temp_supported": @1, @"showBP": @1};
        NSDictionary *resolved = CoolWearCapabilities(all, YES);
        NSCAssert([resolved[@"supportsHistorySync"] isEqual:@NO], @"unmapped history exposed");
        NSCAssert([CoolWearCapabilities(all, NO)[@"supportsHistorySync"] isEqual:@NO], @"pre-handshake history exposed");
        NSCAssert(([resolved[@"metrics"] isEqual:@[@"heart_rate", @"blood_oxygen", @"hrv", @"body_temperature"]]), @"unsupported metric enabled");
        NSCAssert(([resolved[@"manualMetrics"] isEqual:@[@"heart_rate", @"blood_oxygen", @"hrv"]]), @"manual mapping incorrect");
        NSCAssert([CoolWearCapabilities(all, NO)[@"metrics"] count] == 0, @"pre-handshake metrics exposed");
        NSDictionary *automatic = CoolWearCapabilities(@{@"hasHR24h": @1, @"manualHr": @0, @"showO2": @0}, YES);
        NSCAssert([automatic[@"manualMetrics"] count] == 0, @"automatic-only HR permits manual measurement");
        NSCAssert([automatic[@"metrics"] count] == 0, @"unmapped automatic history exposed");
        NSCAssert([CoolWearCapabilities(@{@"manualHr": @"1", @"showO2": @2}, YES)[@"metrics"] count] == 0, @"malformed flags coerced");
        NSCAssert([CoolWearCapabilities(@{@"manualHr": @1.5, @"showO2": @(NAN)}, YES)[@"metrics"] count] == 0, @"fractional flags coerced");
        NSCAssert(CoolWearHasKnownCapabilities(@{@"manualHr": @NO, @"showO2": @YES}), @"real Boolean flags rejected");
        NSCAssert(!CoolWearHasKnownCapabilities(@{@"manualHr": @2, @"showO2": @1.5}), @"invalid capability response accepted");
        __block NSUInteger completions = 0;
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
        puts("CoolWear native name/capability/RRI/skin-temperature policy: PASS (synthetic inputs, not hardware acceptance)");
    }
    return 0;
}
