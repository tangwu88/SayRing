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
    // QCSleepModel realBegin/End reconstruct each effective interval. Equal and
    // overlapping intervals must not be counted twice; conflicting stages stay
    // unknown rather than selecting an arbitrary health classification.
    NSMutableArray *valid = [NSMutableArray array];
    for (NSDictionary *segment in segments) {
        NSDate *begin = segment[@"begin"], *end = segment[@"end"];
        if (![begin isKindOfClass:NSDate.class] || ![end isKindOfClass:NSDate.class] ||
            [end compare:begin] != NSOrderedDescending || [end timeIntervalSinceDate:begin] > 86400) { continue; }
        [valid addObject:[segment mutableCopy]];
    }
    NSMutableSet *boundaries = [NSMutableSet set];
    for (NSDictionary *segment in valid) { [boundaries addObject:segment[@"begin"]]; [boundaries addObject:segment[@"end"]]; }
    NSArray *ordered = [boundaries.allObjects sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *normalized = [NSMutableArray array];
    for (NSUInteger index = 0; index + 1 < ordered.count; index++) {
        NSDate *begin = ordered[index], *end = ordered[index + 1];
        NSMutableSet *types = [NSMutableSet set];
        for (NSDictionary *segment in valid) {
            if ([segment[@"begin"] compare:begin] != NSOrderedDescending && [segment[@"end"] compare:end] != NSOrderedAscending) {
                [types addObject:segment[@"type"] ?: @0];
            }
        }
        if (!types.count) { continue; }
        [normalized addObject:@{@"begin": begin, @"end": end, @"type": types.count == 1 ? types.anyObject : @0}];
    }
    double minutes[5] = {0, 0, 0, 0, 0};
    for (NSDictionary *segment in normalized) {
        NSInteger type = [segment[@"type"] integerValue];
        NSDate *begin = segment[@"begin"], *end = segment[@"end"];
        if (type < 1 || type > 4) { continue; }
        minutes[type] += [end timeIntervalSinceDate:begin] / 60;
    }
    double asleep = minutes[2] + minutes[3] + minutes[4];
    if (asleep <= 0 || asleep + minutes[1] > 1440) { return nil; }
    return @{@"value": @(asleep / 60), @"lightHours": @(minutes[2] / 60),
             @"deepHours": @(minutes[3] / 60), @"remHours": @(minutes[4] / 60),
             @"awakeMinutes": @(minutes[1])};
}

static inline NSString *QRingSleepISO(NSDate *date) {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    return [formatter stringFromDate:date];
}

/// Capture once before the relative-day SDK request. The callback can arrive
/// after midnight or after a phone timezone change without moving its SDK day.
static inline NSDictionary *QRingSleepRequestContext(NSDate *dayStart, NSTimeZone *timezone) {
    NSInteger seconds = [timezone secondsFromGMTForDate:dayStart];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:seconds];
    NSString *offset = [NSString stringWithFormat:@"%@%02ld:%02ld", seconds < 0 ? @"-" : @"+",
                        (long)(labs(seconds) / 3600), (long)((labs(seconds) / 60) % 60)];
    return @{@"dayStart": dayStart, @"sdkDate": [formatter stringFromDate:dayStart],
             @"timezone": offset, @"offsetSeconds": @(seconds)};
}

static inline NSString *QRingSleepStage(NSInteger type) {
    switch (type) {
        case 1: return @"awake";
        case 2: return @"light";
        case 3: return @"deep";
        case 4: return @"rem";
        case 5: return @"notWorn";
        default: return @"unknown";
    }
}

/// JSON-safe raw SDK rows accompany the timeline, so normalization never erases
/// the packet that supplied an interval. Night and nap classifications stay apart.
static inline NSDictionary *QRingSleepTimeline(NSArray<NSDictionary *> *night,
                                               NSArray<NSDictionary *> *naps,
                                               NSString *deviceId, NSString *sdkDate,
                                               NSString *timezone, NSDate *readAt) {
    NSMutableArray *sessions = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    double reportedMinutes = 0;
    for (NSInteger category = 0; category < 2; category++) {
        NSArray *input = category == 0 ? (night ?: @[]) : (naps ?: @[]);
        NSMutableArray *raw = [NSMutableArray array];
        NSMutableArray *segments = [NSMutableArray array];
        for (NSDictionary *item in input) {
            NSMutableDictionary *original = [item mutableCopy];
            NSDate *begin = item[@"begin"], *end = item[@"end"];
            original[@"begin"] = [begin isKindOfClass:NSDate.class] ? QRingSleepISO(begin) : NSNull.null;
            original[@"end"] = [end isKindOfClass:NSDate.class] ? QRingSleepISO(end) : NSNull.null;
            [raw addObject:original];
            NSInteger type = [item[@"type"] integerValue];
            if (QRingNumberInRange(item[@"minutes"], 0, 1440)) { reportedMinutes += [item[@"minutes"] doubleValue]; }
            if (![begin isKindOfClass:NSDate.class] || ![end isKindOfClass:NSDate.class] ||
                [end compare:begin] != NSOrderedDescending || [end timeIntervalSinceDate:begin] > 86400 ||
                [end timeIntervalSinceDate:readAt] > 300) { continue; }
            NSString *key = [NSString stringWithFormat:@"%.0f|%.0f|%ld", begin.timeIntervalSince1970, end.timeIntervalSince1970, (long)type];
            if ([seen containsObject:key]) { continue; }
            [seen addObject:key];
            NSMutableDictionary *segment = [@{@"startAt": QRingSleepISO(begin), @"endAt": QRingSleepISO(end),
                                              @"stage": QRingSleepStage(type), @"rawStage": @(type)} mutableCopy];
            if (QRingNumberInRange(item[@"minutes"], 0, 1440)) { segment[@"reportedMinutes"] = item[@"minutes"]; }
            [segments addObject:segment];
        }
        [segments sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
            return [left[@"startAt"] compare:right[@"startAt"]];
        }];
        if (raw.count || segments.count) {
            [sessions addObject:@{@"kind": category == 0 ? @"night" : @"nap", @"segments": segments, @"rawSegments": raw}];
        }
    }
    return @{@"deviceId": deviceId, @"sdkDate": sdkDate, @"timezone": timezone,
             @"readAt": QRingSleepISO(readAt), @"sessions": sessions, @"revision": @0,
             @"rawSummary": @{@"reportedTotalMinutes": @(reportedMinutes)}};
}

static inline BOOL QRingSleepTimelineHasConflictingSessions(NSDictionary *timeline) {
    NSArray *sessions = timeline[@"sessions"];
    for (NSUInteger left = 0; left < sessions.count; left++) {
        for (NSUInteger right = left + 1; right < sessions.count; right++) {
            for (NSDictionary *a in sessions[left][@"segments"]) {
                for (NSDictionary *b in sessions[right][@"segments"]) {
                    if ([a[@"startAt"] compare:b[@"endAt"]] == NSOrderedAscending &&
                        [b[@"startAt"] compare:a[@"endAt"]] == NSOrderedAscending) { return YES; }
                }
            }
        }
    }
    // Check the union, not the sum of overlapping raw rows in one session.
    // This also includes unknown/not-worn intervals, which are not sleep hours.
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSMutableArray *ranges = [NSMutableArray array];
    for (NSDictionary *session in sessions) {
        for (NSDictionary *segment in session[@"segments"]) {
            NSDate *begin = [formatter dateFromString:segment[@"startAt"]], *end = [formatter dateFromString:segment[@"endAt"]];
            if (!begin || !end || begin.timeIntervalSince1970 < 946684800 || [end compare:begin] != NSOrderedDescending) { return YES; }
            [ranges addObject:@{@"begin": begin, @"end": end}];
        }
    }
    [ranges sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"begin"] compare:right[@"begin"]];
    }];
    NSTimeInterval covered = 0;
    NSDate *previousEnd = nil;
    for (NSDictionary *range in ranges) {
        NSDate *begin = range[@"begin"], *end = range[@"end"];
        if (!previousEnd || [begin compare:previousEnd] != NSOrderedAscending) {
            covered += [end timeIntervalSinceDate:begin];
        } else if ([end compare:previousEnd] == NSOrderedDescending) {
            covered += [end timeIntervalSinceDate:previousEnd];
        }
        if (!previousEnd || [end compare:previousEnd] == NSOrderedDescending) { previousEnd = end; }
    }
    if (covered > 86400) { return YES; }
    return NO;
}
