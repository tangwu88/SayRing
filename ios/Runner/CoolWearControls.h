#pragma once
#import "CoolWearPolicy.h"

// Supplied CE_GestureCmd Control_type: none, video, music, reader, photo, phone.
// A command ACK confirms a mode request, not a gesture or a physical actuator.
static inline NSNumber *CoolWearGestureMode(id raw) {
    if ([raw isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)raw) == CFBooleanGetTypeID()) return nil;
    return CoolWearUnsigned(raw, 5);
}

static inline NSNumber *CoolWearCallReminder(id raw) {
    return [raw isKindOfClass:NSDictionary.class] ? CoolWearUnsigned(raw[@"onoff"], 1) : nil;
}

static inline BOOL CoolWearCameraShutter(id raw, BOOL active, BOOL resolved, BOOL foreground) {
    NSNumber *value = [raw isKindOfClass:NSDictionary.class] ? CoolWearUnsigned(raw[@"takePhoto"], 1) : nil;
    return active && resolved && foreground && value && value.integerValue == 1;
}
