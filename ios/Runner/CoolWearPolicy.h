#pragma once
#import <Foundation/Foundation.h>
#import <math.h>

// Names select the vendor transport, never infer a feature from the model.
static inline NSString *CoolWearModel(NSString *name) {
    if (![name isKindOfClass:NSString.class]) return nil;
    NSString *value = [[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([value hasPrefix:@"R1"] || [value hasPrefix:@"R2"] || [value containsString:@"R7C"]) return nil;
    if ([value containsString:@"R8"] || [value containsString:@"R21"] || [value containsString:@"R22"]) return nil;
    if ([value containsString:@"HR01"]) return @"HR01";
    if ([value containsString:@"HR05"]) return @"HR05";
    NSString *model = [value stringByReplacingOccurrencesOfString:@"[\\s_-]+" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, value.length)];
    if ([model containsString:@"R7ULTRA"]) return @"R7Ultra";
    if ([model containsString:@"R7PRO"]) return @"R7Pro";
    if ([value containsString:@"R7Y"]) return @"R7Y";
    if ([value containsString:@"R7"]) return @"R7";
    if ([value containsString:@"K80"]) return @"K80";
    return nil;
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
    if (resolved && (CoolWearFlag(flags, @"manualHr") || CoolWearFlag(flags, @"hasHR24h"))) [metrics addObject:@"heart_rate"];
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
    return @{@"resolved": @(resolved), @"metrics": metrics, @"manualMetrics": manual,
             @"historyMetrics": metrics,
             @"sportModes": @[], @"features": @[], @"integratedFeatures": @[],
             @"supportsBackgroundSync": @NO, @"supportsHistorySync": @(resolved),
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
