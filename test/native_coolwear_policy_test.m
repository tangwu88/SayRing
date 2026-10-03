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
        NSCAssert(([resolved[@"metrics"] isEqual:@[@"heart_rate", @"blood_oxygen"]]), @"unsupported metric enabled");
        NSCAssert(([resolved[@"manualMetrics"] isEqual:@[@"heart_rate", @"blood_oxygen"]]), @"manual mapping incorrect");
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
        puts("CoolWear native name/capability/value policy: PASS (synthetic inputs, not hardware acceptance)");
    }
    return 0;
}
