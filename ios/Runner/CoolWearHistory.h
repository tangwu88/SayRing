#pragma once
#import "CoolWearPolicy.h"

// Supplied SDK guide: 5 activity, 6 sleep, 8 heart, 40 oxygen,
// 47 temperature and 61 new RRI-HRV. Type 9 is only an envelope.
static inline NSString *CoolWearHistoryKey(NSInteger type) {
    return @{@5:@"sportInfos", @6:@"sleepInfos", @8:@"heartInfos",
             @40:@"data", @47:@"tempInfos", @61:@"hrvMetricsInfos"}[@(type)];
}
static inline NSString *CoolWearHistoryMetric(NSInteger type) {
    return @{@5:@"steps", @6:@"sleep", @8:@"heart_rate", @40:@"blood_oxygen",
             @47:@"body_temperature", @61:@"hrv"}[@(type)];
}

// Packet accounting is independent of callback ordering. Only explicit batch
// counts can establish completion, never a command ACK or mixed envelope.
@interface CoolWearHistoryBatch : NSObject
@property(nonatomic) NSUInteger expected;
@property(nonatomic) BOOL finalSeen;
@property(nonatomic) BOOL malformed;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *rows;
- (void)accept:(id)packet key:(NSString *)key;
- (NSString *)status;
@end
@implementation CoolWearHistoryBatch
- (instancetype)init {
    if ((self = [super init])) _rows = [NSMutableDictionary dictionary];
    return self;
}
- (void)accept:(id)packet key:(NSString *)key {
    if (![packet isKindOfClass:NSDictionary.class]) { self.malformed = YES; return; }
    NSNumber *count = CoolWearUnsigned(packet[@"curItemCount"], 255);
    NSNumber *remain = CoolWearUnsigned(packet[@"remainItemCount"], 65535);
    id rows = packet[key];
    if (!count || !remain || ![rows isKindOfClass:NSArray.class] || [rows count] != count.unsignedIntegerValue) {
        self.malformed = YES; return;
    }
    self.expected = MAX(self.expected, count.unsignedIntegerValue + remain.unsignedIntegerValue);
    self.finalSeen |= remain.unsignedIntegerValue == 0;
    for (id row in rows) {
        if (![row isKindOfClass:NSDictionary.class] || self.rows.count >= 16384 ||
            ![NSJSONSerialization isValidJSONObject:row]) { self.malformed = YES; continue; }
        NSData *bytes = [NSJSONSerialization dataWithJSONObject:row options:NSJSONWritingSortedKeys error:nil];
        NSString *fingerprint = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
        if (fingerprint) self.rows[fingerprint] = row;
    }
}
- (NSString *)status {
    if (!self.malformed && self.finalSeen && self.rows.count >= self.expected)
        return self.rows.count ? @"complete" : @"no_data";
    return self.rows.count || self.malformed || self.finalSeen ? @"partial" : @"not_received";
}
@end

static inline NSDictionary *CoolWearHistoryValues(NSInteger type, NSDictionary *sample) {
    if (type == 61) return CoolWearRriHrvValues(sample);
    if (type == 47) return CoolWearSkinTemperatureValues(sample);
    if (type == 8 || type == 40) {
        NSNumber *value = CoolWearMeasurementValue(CoolWearHistoryMetric(type), sample);
        return value ? @{@"value": value} : nil;
    }
    if (type == 5) {
        NSNumber *steps = CoolWearUnsigned(sample[@"walkSteps"], 1000000);
        // iOS guide does not specify distance/calorie scale. Do not copy the
        // Android scale into a different SDK or silently invent those units.
        return steps ? @{@"value": steps} : nil;
    }
    return nil;
}

// The supplied guide explicitly frames START(1) -> WAKEUP(4). Only bounded
// DEEP(2)/LIGHT(3) intervals count as sleep. Unknown codes stay unknown. No
// guessed terminal timestamp, REM, naps or SDK ownership date are produced.
static inline NSArray<NSDictionary *> *CoolWearClosedSleepSummaries(NSArray *rows, NSDate *now) {
    NSMutableDictionary *byTime = [NSMutableDictionary dictionary];
    NSMutableSet *conflicts = [NSMutableSet set];
    for (id row in rows) {
        if (![row isKindOfClass:NSDictionary.class]) continue;
        NSDate *date = CoolWearSampleDate(row[@"SleepStartTime"], now);
        NSNumber *stage = CoolWearUnsigned(row[@"SleepType"], 255);
        if (!date || !stage) continue;
        NSNumber *time = @((long long)date.timeIntervalSince1970);
        if (byTime[time] && ![byTime[time][@"SleepType"] isEqual:stage]) [conflicts addObject:time];
        byTime[time] = row;
    }
    NSArray *times = [[byTime allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *result = [NSMutableArray array];
    NSNumber *start = nil, *previous = nil;
    NSInteger previousStage = -1;
    double deep = 0, light = 0;
    for (NSNumber *time in times) {
        NSInteger stage = [byTime[time][@"SleepType"] integerValue];
        if ([conflicts containsObject:time]) { start = nil; previous = nil; continue; }
        if (stage == 1) { start = time; previous = time; previousStage = stage; deep = light = 0; continue; }
        if (!start || !previous) continue;
        double seconds = time.doubleValue - previous.doubleValue;
        if (time.doubleValue - start.doubleValue > 86400 || seconds <= 0) { start = nil; previous = nil; continue; }
        if (previousStage == 2) deep += seconds;
        if (previousStage == 3) light += seconds;
        if (stage == 4) {
            if (deep + light > 0) [result addObject:@{@"time":time, @"values":@{
                @"value":@((deep + light) / 3600), @"deepHours":@(deep / 3600), @"lightHours":@(light / 3600)}}];
            start = nil; previous = nil;
        } else { previous = time; previousStage = stage; }
    }
    return result;
}
