#import <Foundation/Foundation.h>

// App modes are shared with LuckRing; QRing's firmware enum is different.
static inline NSInteger QRingGestureRawMode(NSInteger mode) {
    switch (mode) {
        case 0: return 0; case 1: return 2; case 2: return 1;
        case 3: return 4; case 4: return 5; case 5: return 6;
        default: return -1;
    }
}

static inline NSInteger QRingGestureAppMode(NSInteger raw) {
    for (NSInteger mode = 0; mode <= 5; mode++) {
        if (QRingGestureRawMode(mode) == raw) { return mode; }
    }
    return -1; // Preserve other firmware modes; never label them as closed.
}

static inline BOOL QRingGestureReadbackMatches(NSDictionary *before,
                                                NSDictionary *actual,
                                                NSInteger expectedMode) {
    if (!before || !actual || expectedMode < 0 || expectedMode > 9 ||
        ![actual[@"mode"] isEqual:@(expectedMode)] ||
        ![before[@"touch"] isEqual:actual[@"touch"]] ||
        ![before[@"duration"] isEqual:actual[@"duration"]]) {
        return NO;
    }
    if ([before[@"strength"] isEqual:actual[@"strength"]]) { return YES; }

    // R8 initializes an unused gesture strength from 0 to 1 on first enable.
    // Accept only that observed transition after an independent successful read;
    // keep sending the original value and retain the firmware's returned value.
    return [before[@"touch"] isEqual:@NO] &&
        [before[@"mode"] isEqual:@0] &&
        [before[@"strength"] isEqual:@0] && expectedMode != 0 &&
        [actual[@"strength"] isEqual:@1];
}

static inline NSDictionary *QRingGestureSnapshot(NSDictionary *raw, NSArray *modes) {
    if (!raw) { return nil; }
    NSMutableDictionary *value = [raw mutableCopy];
    value[@"rawMode"] = raw[@"mode"];
    value[@"enabled"] = [raw[@"mode"] integerValue] != 0 ? @YES : @NO;
    value[@"confirmedMode"] = @(QRingGestureAppMode([raw[@"mode"] integerValue]));
    value[@"availableModes"] = modes;
    value[@"readbackVerified"] = @YES;
    return value;
}
