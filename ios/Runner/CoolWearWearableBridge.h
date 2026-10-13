#import <Flutter/Flutter.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface CoolWearWearableBridge : NSObject
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
- (void)dispose;
@end
NS_ASSUME_NONNULL_END
