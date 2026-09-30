#import <Foundation/Foundation.h>
#import <math.h>

// Foundation-only mapping keeps SDK payload/unit handling executable in host
// tests. Inputs are SDK values, never synthetic defaults or clinical ranges.
static inline BOOL QRingNumberInRange(id value, double minimum, double maximum) {
    return [value isKindOfClass:NSNumber.class] && isfinite([value doubleValue]) &&
        [value doubleValue] >= minimum && [value doubleValue] <= maximum;
}

static inline BOOL QRingIs260918StressCompletion(id value) {
    if (![value isKindOfClass:NSDictionary.class] || [value count] != 2) { return NO; }
    id stress = value[@"sbp"], unused = value[@"dbp"];
    return [stress isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)stress) != CFBooleanGetTypeID() &&
        QRingNumberInRange(unused, 0, 0) &&
        CFGetTypeID((__bridge CFTypeRef)unused) != CFBooleanGetTypeID();
}

static inline NSDictionary *QRingMeasurementValues(NSString *metric, id value) {
    if ([metric isEqualToString:@"stress"] && [value isKindOfClass:NSDictionary.class]) {
        // Pinned QCBandSDK 1.0.0 (260918) disagrees with its header: its timeout
        // completed callback wraps the real stress value as {sbp: stress, dbp: 0}.
        // Only unwrap this exact shape for stress, never a blood-pressure pair.
        // The caller must still require SDK success/completion and disable all
        // SDK defaults. The normal numeric/range validation below is unchanged.
        if (!QRingIs260918StressCompletion(value)) { return nil; }
        value = value[@"sbp"];
    }
    if ([metric isEqualToString:@"body_temperature"]) {
        // QCBandSDK 1.0.0 (260918) manual callbacks return tenths of a degree:
        // notifyRealTimeBodyTemperature/measuringTimeoutAction add 200 to the
        // encoded integer. History QCTemperatureModel.temperature is already C
        // and does not pass through this manual-measurement adapter.
        if (![value isKindOfClass:NSNumber.class]) { return nil; }
        value = @([value doubleValue] / 10.0);
    }
    if ([metric isEqualToString:@"blood_pressure"]) {
        if (![value isKindOfClass:NSDictionary.class]) { return nil; }
        // The SDK documents pressure fields as numeric strings or numbers.
        id rawSbp = value[@"sbp"], rawDbp = value[@"dbp"];
        if (![rawSbp respondsToSelector:@selector(doubleValue)] || ![rawDbp respondsToSelector:@selector(doubleValue)]) { return nil; }
        NSNumber *sbp = @([rawSbp doubleValue]), *dbp = @([rawDbp doubleValue]);
        return QRingNumberInRange(sbp, 60, 300) && QRingNumberInRange(dbp, 20, 200) && sbp.doubleValue > dbp.doubleValue
            ? @{@"systolic": sbp, @"diastolic": dbp} : nil;
    }
    NSDictionary *limits = @{
        @"heart_rate": @[@20, @300], @"blood_oxygen": @[@2, @100],
        @"hrv": @[@1, @1000], @"stress": @[@1, @100],
        @"body_temperature": @[@20, @45],
    };
    NSArray *range = limits[metric];
    return range && QRingNumberInRange(value, [range[0] doubleValue], [range[1] doubleValue]) ? @{@"value": value} : nil;
}

// getSportDetailDataByDay yields per-slot amounts. The shared health contract
// expects cumulative snapshots. Preserve actual SDK dates; never infer slots
// from array position, mix days, count duplicates, or reinterpret iOS kcal.
static inline NSArray<NSDictionary *> *QRingCumulativeActivitySamples(NSArray<NSDictionary *> *slots, NSDate *dayStart, NSDate *dayEnd, NSDate *now) {
    NSMutableDictionary<NSDate *, NSDictionary *> *unique = [NSMutableDictionary dictionary];
    for (NSDictionary *slot in slots) {
        NSDate *date = slot[@"date"];
        if (![date isKindOfClass:NSDate.class] || [date compare:dayStart] == NSOrderedAscending ||
            [date compare:dayEnd] != NSOrderedAscending || [date compare:now] == NSOrderedDescending) { continue; }
        if (!QRingNumberInRange(slot[@"steps"], 0, 1000000) ||
            !QRingNumberInRange(slot[@"distance"], 0, 10000000) ||
            !QRingNumberInRange(slot[@"calories"], 0, 100000)) { continue; }
        NSDictionary *old = unique[date];
        unique[date] = @{
            @"steps": @(MAX([old[@"steps"] doubleValue], [slot[@"steps"] doubleValue])),
            @"distance": @(MAX([old[@"distance"] doubleValue], [slot[@"distance"] doubleValue])),
            @"calories": @(MAX([old[@"calories"] doubleValue], [slot[@"calories"] doubleValue])),
        };
    }
    NSMutableArray *result = [NSMutableArray array];
    double steps = 0, distance = 0, calories = 0;
    for (NSDate *date in [unique.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *slot = unique[date];
        steps += [slot[@"steps"] doubleValue];
        distance += [slot[@"distance"] doubleValue];
        calories += [slot[@"calories"] doubleValue];
        [result addObject:@{@"date": date, @"steps": @(steps), @"distance": @(distance / 1000.0), @"calories": @(calories)}];
    }
    return result;
}

static inline NSDictionary *QRingSleepStageValues(NSArray<NSDictionary *> *segments) {
    // QCSleepModel.realEffectiveMinutes is minutes, unlike Android's seconds.
    NSMutableSet *seen = [NSMutableSet set];
    double minutes[5] = {0, 0, 0, 0, 0};
    for (NSDictionary *segment in segments) {
        NSInteger type = [segment[@"type"] integerValue];
        NSDate *begin = segment[@"begin"], *end = segment[@"end"];
        if (type < 1 || type > 4 || ![begin isKindOfClass:NSDate.class] || ![end isKindOfClass:NSDate.class] ||
            [end compare:begin] != NSOrderedDescending || !QRingNumberInRange(segment[@"minutes"], 1, 1440)) { continue; }
        NSString *key = [NSString stringWithFormat:@"%.0f|%.0f", begin.timeIntervalSince1970, end.timeIntervalSince1970];
        if ([seen containsObject:key]) { continue; }
        [seen addObject:key];
        minutes[type] += [segment[@"minutes"] doubleValue];
    }
    double asleep = minutes[2] + minutes[3] + minutes[4];
    if (asleep <= 0 || asleep + minutes[1] > 1440) { return nil; }
    return @{@"value": @(asleep / 60), @"lightHours": @(minutes[2] / 60),
             @"deepHours": @(minutes[3] / 60), @"remHours": @(minutes[4] / 60),
             @"awakeMinutes": @(minutes[1])};
}
