#import <Foundation/Foundation.h>

// QRing uses mode 5 for photo control. CoolWear's mode numbers are unrelated.
static inline NSDictionary *QRingCameraSnapshot(NSInteger mode, NSInteger strength,
                                                 BOOL touch, NSInteger duration) {
    if (mode < 0 || mode > 9 || strength < 1 || strength > 10 ||
        (touch && (duration < 1 || duration > 10))) { return nil; }
    return @{@"mode": @(mode), @"enabled": @(mode == 5), @"strength": @(strength),
             @"touch": @(touch), @"duration": @(duration)};
}
