#import <Foundation/Foundation.h>
#import "../../ios/Runner/QRingCameraPolicy.h"

int main(void) {
    @autoreleasepool {
        for (NSInteger mode = 0; mode <= 9; mode++) {
            NSDictionary *gesture = QRingCameraSnapshot(mode, 7, NO, 0);
            NSCAssert([gesture[@"enabled"] boolValue] == (mode == 5), @"wrong QRing mode");
            NSCAssert([gesture[@"strength"] integerValue] == 7, @"strength lost");
            NSDictionary *touch = QRingCameraSnapshot(mode, 1, YES, 8);
            NSCAssert([touch[@"duration"] integerValue] == 8, @"duration lost");
        }
        for (NSNumber *mode in @[@(-1), @10])
            NSCAssert(!QRingCameraSnapshot(mode.integerValue, 1, NO, 0), @"unknown mode accepted");
        for (NSNumber *strength in @[@0, @11])
            NSCAssert(!QRingCameraSnapshot(5, strength.integerValue, NO, 0), @"unknown strength accepted");
        for (NSNumber *duration in @[@0, @11])
            NSCAssert(!QRingCameraSnapshot(5, 1, YES, duration.integerValue), @"unknown sleep duration accepted");
        puts("QRing camera policy passed");
    }
    return 0;
}
