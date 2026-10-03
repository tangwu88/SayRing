#import <Foundation/Foundation.h>
#import <math.h>

// Names select the vendor transport, never infer a feature from the model.
static inline NSString *CoolWearModel(NSString *name) {
    if (![name isKindOfClass:NSString.class]) return nil;
    NSString *value = [[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([value hasPrefix:@"HR01-"]) return @"HR01";
    static NSRegularExpression *pattern;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pattern = [NSRegularExpression regularExpressionWithPattern:@"^(HR01|HR05|K80|R7PRO|R7Y|R7)(?:[-_ ](?:[0-9A-F]{1,12}|(?:[0-9A-F]{2}:){5}[0-9A-F]{2}))?$" options:0 error:nil];
    });
    NSTextCheckingResult *match = [pattern firstMatchInString:value options:0 range:NSMakeRange(0, value.length)];
    if (!match) return nil;
    NSString *model = [value substringWithRange:[match rangeAtIndex:1]];
    return [model isEqualToString:@"R7PRO"] ? @"R7Pro" : model;
}

static inline NSNumber *CoolWearNumber(id value) {
    // No coercion of missing, Boolean, strings, NaN or infinity to health data.
    if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return nil;
    return isfinite([value doubleValue]) ? value : nil;
}

static inline BOOL CoolWearFlag(NSDictionary *flags, NSString *key) {
    id value = flags[key];
    return [value isKindOfClass:NSNumber.class] && [value doubleValue] == 1;
}

static inline BOOL CoolWearHasKnownCapabilities(NSDictionary *flags) {
    for (NSString *key in @[@"manualHr", @"showO2", @"hasHR24h"]) {
        id value = flags[key];
        if ([value isKindOfClass:NSNumber.class] &&
            ([value doubleValue] == 0 || [value doubleValue] == 1)) return YES;
    }
    return NO;
}

typedef void (^CoolWearCompletion)(id value);

// Every bridge completion runs on the main queue. A vendor exception may occur
// after it has completed a command; never complete that Flutter request twice.
static inline CoolWearCompletion CoolWearCompleteOnce(CoolWearCompletion completion) {
    __block BOOL completed = NO;
    return [^(id value) {
        if (completed) return;
        completed = YES;
        completion(value);
    } copy];
}

static inline NSDictionary *CoolWearCapabilities(NSDictionary *flags, BOOL resolved) {
    NSMutableArray *metrics = [NSMutableArray array];
    NSMutableArray *manual = [NSMutableArray array];
    // Automatic history transport is not yet mapped on iOS. A device flag by
    // itself must not expose a metric that this bridge cannot read.
    if (resolved && CoolWearFlag(flags, @"manualHr")) [metrics addObject:@"heart_rate"];
    if (resolved && CoolWearFlag(flags, @"manualHr")) [manual addObject:@"heart_rate"];
    if (resolved && CoolWearFlag(flags, @"showO2")) {
        [metrics addObject:@"blood_oxygen"];
        [manual addObject:@"blood_oxygen"];
    }
    // HRV/temperature/sleep/workouts/controls need their own real mapping and
    // acceptance. SDK support alone is not bridge integration.
    return @{@"resolved": @(resolved), @"metrics": metrics, @"manualMetrics": manual,
             @"sportModes": @[], @"features": @[], @"integratedFeatures": @[],
             @"supportsBackgroundSync": @NO, @"supportsSportPause": @NO,
             @"supportsWatchFaces": @NO, @"supportsOta": @NO};
}

static inline NSNumber *CoolWearMeasurementValue(NSString *metric, NSDictionary *sample) {
    NSString *key = [metric isEqualToString:@"heart_rate"] ? @"heartNum" : @"oxygen";
    NSNumber *value = CoolWearNumber(sample[key]);
    double maximum = [metric isEqualToString:@"heart_rate"] ? 250 : 100;
    if (![metric isEqualToString:@"heart_rate"] && ![metric isEqualToString:@"blood_oxygen"]) return nil;
    return value && value.doubleValue > 0 && value.doubleValue <= maximum ? value : nil;
}
