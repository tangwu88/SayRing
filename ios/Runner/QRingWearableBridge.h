#import <Flutter/Flutter.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Flutter bridge for the QRing QCBand SDK. The implementation only accepts
/// peripherals seen in the current Q_/O_ scan and resolves features from the
/// device response before exposing any health capability.
@interface QRingWearableBridge : NSObject

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
- (void)dispose;

@end

NS_ASSUME_NONNULL_END
