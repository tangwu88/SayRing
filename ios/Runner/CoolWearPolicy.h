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
    // Only the new RRI-HRV 60/61 results have confirmed millisecond fields.
    // Legacy type 42/45 heartNum is deliberately not interpreted as HRV.
    if (resolved && CoolWearFlag(flags, @"hrvSupport")) {
        [metrics addObject:@"hrv"];
        [manual addObject:@"hrv"];
    }
    // Temperature is a passive history result, never a manual command.
    if (resolved && CoolWearFlag(flags, @"temp_supported")) [metrics addObject:@"body_temperature"];
    // A passive result is not a completed full-history read. Sleep, workouts
    // and controls remain closed until their own transport is implemented.
    return @{@"resolved": @(resolved), @"metrics": metrics, @"manualMetrics": manual,
             @"sportModes": @[], @"features": @[], @"integratedFeatures": @[],
             @"supportsBackgroundSync": @NO, @"supportsHistorySync": @NO,
             @"supportsSportPause": @NO,
             @"supportsWatchFaces": @NO, @"supportsOta": @NO};
}

static inline NSNumber *CoolWearMeasurementValue(NSString *metric, NSDictionary *sample) {
    NSString *key = [metric isEqualToString:@"heart_rate"] ? @"heartNum" : @"oxygen";
    NSNumber *value = CoolWearNumber(sample[key]);
    double maximum = [metric isEqualToString:@"heart_rate"] ? 250 : 100;
    if (![metric isEqualToString:@"heart_rate"] && ![metric isEqualToString:@"blood_oxygen"]) return nil;
    return value && value.doubleValue > 0 && value.doubleValue <= maximum ? value : nil;
}

static inline NSNumber *CoolWearUnsigned(id value, NSUInteger maximum) {
    NSNumber *number = CoolWearNumber(value);
    double raw = number.doubleValue;
    return number && raw >= 0 && raw <= maximum && floor(raw) == raw ? number : nil;
}

// SDK DataStruct.h and the supplied CE_K6Protocol parser agree on these names
// and units. Keep them separate from the ambiguous legacy heartNum protocol.
static inline NSDictionary *CoolWearRriHrvValues(NSDictionary *sample) {
    if (![sample isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *limits = @{@"meanRR": @65535, @"sdnn": @1000, @"rmssd": @65535,
        @"pnn50": @100, @"meanHR": @255, @"validCount": @255,
        @"rejectedCount": @255, @"quality": @3, @"flags": @255};
    for (NSString *key in limits) {
        if (!CoolWearUnsigned(sample[key], [limits[key] unsignedIntegerValue])) return nil;
    }
    if ([sample[@"sdnn"] doubleValue] <= 0 || [sample[@"meanRR"] doubleValue] <= 0 ||
        [sample[@"validCount"] unsignedIntegerValue] < 2 || [sample[@"quality"] integerValue] == 0) return nil;
    return @{@"value": sample[@"sdnn"], @"sdnn": sample[@"sdnn"], @"rmssd": sample[@"rmssd"],
        @"rri": sample[@"meanRR"], @"pnn": sample[@"pnn50"], @"heartRate": sample[@"meanHR"],
        @"validCount": sample[@"validCount"], @"rejectedCount": sample[@"rejectedCount"],
        @"sdkQuality": sample[@"quality"], @"sdkFlags": sample[@"flags"]};
}

static inline NSDictionary *CoolWearSkinTemperatureValues(NSDictionary *sample) {
    if (![sample isKindOfClass:NSDictionary.class]) return nil;
    // tempNum is already Celsius (the SDK has applied /10 and one-decimal
    // formatting). Do not divide again or relabel it as core temperature.
    NSNumber *value = CoolWearNumber(sample[@"tempNum"]);
    return value && value.doubleValue >= 20 && value.doubleValue <= 45 ? @{@"value": value} : nil;
}

static inline NSDate *CoolWearSampleDate(id value, NSDate *now) {
    NSNumber *seconds = CoolWearUnsigned(value, UINT32_MAX);
    if (!seconds || seconds.doubleValue < 1420070400 || seconds.doubleValue > now.timeIntervalSince1970 + 120) return nil;
    return [NSDate dateWithTimeIntervalSince1970:seconds.doubleValue];
}

static inline NSArray<NSDictionary *> *CoolWearMetricSamples(id data, NSString *key) {
    NSArray *batches = [data isKindOfClass:NSDictionary.class] ? @[data] :
        ([data isKindOfClass:NSArray.class] ? data : @[]);
    if (batches.count > 512) return @[];
    NSMutableArray *samples = [NSMutableArray array];
    for (id batch in batches) {
        if (![batch isKindOfClass:NSDictionary.class]) continue;
        id rows = batch[key];
        NSNumber *count = CoolWearUnsigned(batch[@"curItemCount"], 255);
        if (![rows isKindOfClass:NSArray.class] || !count || [rows count] != count.unsignedIntegerValue) continue;
        for (id row in rows) if ([row isKindOfClass:NSDictionary.class]) [samples addObject:row];
    }
    return samples;
}
