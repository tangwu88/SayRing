#import <Foundation/Foundation.h>

// QRing uses mode 5 for photo control. CoolWear's mode numbers are unrelated.
static inline NSDictionary *QRingCameraSnapshot(NSInteger mode, NSInteger strength,
                                                 BOOL touch, NSInteger duration,
                                                 BOOL screenTouch) {
    // Ordinary touch does not populate this reserved field. R8 gesture firmware
    // also returns a successful zero-strength snapshot while switched off.
    // Keep the actual zero instead of inventing a sensitivity. Mode writes must
    // still preserve the snapshot and pass independent readback verification.
    // The screen-device SDK does not provide comparable field evidence.
    NSInteger minimumStrength = screenTouch ? 1 : 0;
    if (mode < 0 || mode > 9 || strength < minimumStrength || strength > 10 ||
        (touch && (duration < 1 || duration > 10))) { return nil; }
    return @{@"mode": @(mode), @"enabled": @(mode == 5), @"strength": @(strength),
             @"touch": @(touch), @"duration": @(duration)};
}
