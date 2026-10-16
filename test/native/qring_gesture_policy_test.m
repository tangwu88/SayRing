#import <Foundation/Foundation.h>
#import "../../ios/Runner/QRingCameraPolicy.h"
#import "../../ios/Runner/QRingGesturePolicy.h"
int main(void) {
    @autoreleasepool {
        NSArray *expected = @[@0,@2,@1,@4,@5,@6];
        for (NSInteger app = 0; app < 6; app++) {
            NSInteger raw = QRingGestureRawMode(app);
            NSCAssert(raw == [expected[app] integerValue], @"wrong firmware mode");
            NSCAssert(QRingGestureAppMode(raw) == app, @"roundtrip failed");
            NSDictionary *snapshot = QRingGestureSnapshot(QRingCameraSnapshot(raw, 7, NO, 0), @[@0,@1,@4]);
            NSCAssert([snapshot[@"confirmedMode"] integerValue] == app, @"wrong UI mode");
            NSCAssert([snapshot[@"enabled"] boolValue] == (raw != 0), @"wrong enable state");
            NSCAssert(CFGetTypeID((__bridge CFTypeRef)snapshot[@"enabled"]) == CFBooleanGetTypeID(), @"Flutter needs a real boolean");
            NSCAssert([snapshot[@"strength"] integerValue] == 7, @"strength lost");
        }
        for (NSNumber *raw in @[@3,@7,@8,@9]) {
            NSDictionary *snapshot = QRingGestureSnapshot(QRingCameraSnapshot(raw.integerValue, 1, YES, 8), @[@0]);
            NSCAssert([snapshot[@"confirmedMode"] integerValue] == -1, @"unknown mislabeled");
            NSCAssert([snapshot[@"rawMode"] isEqual:raw], @"raw mode lost");
            NSCAssert([snapshot[@"duration"] integerValue] == 8, @"duration lost");
        }
        NSCAssert(QRingGestureRawMode(6) == -1 && QRingGestureRawMode(-1) == -1, @"invalid accepted");
        NSCAssert(!QRingGestureSnapshot(nil, @[]), @"invalid read accepted");
        puts("QRing gesture policy passed");
    }
    return 0;
}
