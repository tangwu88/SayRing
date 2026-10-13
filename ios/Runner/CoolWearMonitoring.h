#pragma once
#import "CoolWearPolicy.h"
#import <dispatch/dispatch.h>

// The vendor queue clears curSendCmd/sendCallback AFTER invoking the callback.
// Never enqueue a follow-up synchronously, even when already on the main thread.
static inline void CoolWearAfterSDKCallback(dispatch_block_t block) {
    dispatch_async(dispatch_get_main_queue(), block);
}

// Supplied SDK type 128. Keep all four raw bytes: changing one switch must
// never reset the other switches or reinterpret the undocumented time unit.
static inline NSDictionary *CoolWearMonitoringSnapshot(id raw) {
    if (![raw isKindOfClass:NSDictionary.class]) return nil;
    NSMutableDictionary *value = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"onoff", @"hr24hOnoff", @"oxOnOff", @"time"]) {
        NSNumber *number = CoolWearUnsigned(raw[key], [key isEqual:@"time"] ? 255 : 1);
        if (!number) return nil;
        value[key] = number;
    }
    return value;
}

static inline NSDictionary *CoolWearMonitoringSettings(NSDictionary *snapshot, NSDictionary *flags) {
    if (!CoolWearMonitoringSnapshot(snapshot)) return @{};
    NSMutableDictionary *value = [@{@"heartRate": @([snapshot[@"onoff"] boolValue])} mutableCopy];
    if (CoolWearFlag(flags, @"hasHR24h")) value[@"heartRate24h"] = @([snapshot[@"hr24hOnoff"] boolValue]);
    if (CoolWearFlag(flags, @"O2_auto_switch")) value[@"bloodOxygen"] = @([snapshot[@"oxOnOff"] boolValue]);
    return value;
}

static inline NSDictionary *CoolWearMonitoringChange(NSDictionary *snapshot, NSDictionary *flags, NSString *type, BOOL enabled) {
    if (!CoolWearMonitoringSettings(snapshot, flags)[type]) return nil;
    NSString *key = @{@"heartRate": @"onoff", @"heartRate24h": @"hr24hOnoff", @"bloodOxygen": @"oxOnOff"}[type];
    if (!key) return nil;
    NSMutableDictionary *value = [snapshot mutableCopy];
    value[key] = @(enabled ? 1 : 0);
    return value;
}
