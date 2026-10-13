#import <Foundation/Foundation.h>
#import "../../ios/Runner/QRingNamePolicy.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        NSArray<NSString *> *accepted = @[
            @"R8", @" device-r8-123 ", @"YC-R21-123", @"V-R22-123",
            @"Q_Ring", @"O_Ring", @"R2", @"r210", @"R22_C493_extra"
        ];
        NSArray<NSString *> *rejected = @[
            @"R7", @"K80", @"HR01", @"HR05", @"SD-RING-R7Ultra",
            @"Q_R7", @"O_K80", @"Q_HR01", @"R2-HR05",
            @"R8-R7", @"YC-R21-K80", @"Q_R22-HR05",
            @"unknown-R 8", @"Q Ring", @"Oura Ring", @"R1", @"R3", @""
        ];
        for (NSString *name in accepted) assert(QRingIsSupportedName(name));
        for (NSString *name in rejected) assert(!QRingIsSupportedName(name));
        assert(!QRingIsSupportedName(nil));
        printf("QRing iOS name policy: %lu cases passed\n",
               (unsigned long)(accepted.count + rejected.count + 1));
    }
    return 0;
}
