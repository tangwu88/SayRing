#import <Foundation/Foundation.h>
#import "../../ios/Runner/QRingConnectionPolicy.h"

int main(void) {
    @autoreleasepool {
        for (NSUInteger mask = 0; mask < 16; mask++) {
            NSCAssert(QRingCanFinishCancellation(mask & 1, mask & 2, mask & 4, mask & 8) == (mask == 15),
                      @"old operation, wrong target or live radio released cancellation");
        }
        puts("QRing cancellation policy: 16 combinations passed");
    }
    return 0;
}
