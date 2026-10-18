#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "QRingConnectionPolicy.h"

// Synthetic radio/defaults only. The test runner injects the actual production
// remove/disconnect/reconcile method bodies; no CoreBluetooth device is used.
typedef NS_ENUM(NSInteger, CBPeripheralState) { CBPeripheralStateDisconnected, CBPeripheralStateConnecting, CBPeripheralStateConnected, CBPeripheralStateDisconnecting };
typedef NS_ENUM(NSInteger, QCState) { QCStateUnkown, QCStateUnbind, QCStateConnecting, QCStateConnected, QCStateDisconnecting, QCStateDisconnected };
static NSString *const QCLastConnectedIdentifier = @"synthetic-only";
static BOOL bound;
static NSUInteger queued, checked;
static void (^nextPoll)(void);
static void check(BOOL value) { checked++; if (!value) { fputs("Synthetic cancellation assertion failed\n", stderr); exit(1); } }
static void queuePoll(__unused dispatch_time_t when, __unused dispatch_queue_t queue, dispatch_block_t block) { queued++; nextPoll = [block copy]; }
#define dispatch_after queuePoll

@interface SyntheticPeripheral : NSObject
@property(nonatomic) CBPeripheralState state;
@end
@implementation SyntheticPeripheral
@end
@interface SyntheticRadio : NSObject
@property(nonatomic) BOOL closes;
@property(nonatomic) BOOL throws;
@property(nonatomic) NSUInteger cancels;
- (void)cancelPeripheralConnection:(SyntheticPeripheral *)peripheral;
@end
@implementation SyntheticRadio
- (void)cancelPeripheralConnection:(SyntheticPeripheral *)peripheral {
    self.cancels++;
    if (self.throws) @throw [NSException exceptionWithName:@"SyntheticCancellation" reason:nil userInfo:nil];
    if (self.closes) peripheral.state = CBPeripheralStateDisconnected;
}
@end
@interface SyntheticDefaults : NSObject
+ (instancetype)standardUserDefaults;
- (void)removeObjectForKey:(NSString *)key;
- (void)synchronize;
@end
@implementation SyntheticDefaults
+ (instancetype)standardUserDefaults { return [self new]; }
- (void)removeObjectForKey:(__unused NSString *)key { bound = NO; }
- (void)synchronize {}
@end
#define NSUserDefaults SyntheticDefaults
@interface QCSDKManager : NSObject
+ (instancetype)shareInstance;
- (void)removeAllPeripheral;
@end
@implementation QCSDKManager
+ (instancetype)shareInstance { return [self new]; }
- (void)removeAllPeripheral {}
@end
@compatibility_alias CBPeripheral SyntheticPeripheral;
@interface SyntheticCentral : NSObject
@property(nonatomic, strong) SyntheticRadio *centerManager;
@property(nonatomic, strong) SyntheticPeripheral *connectedPeripheral;
@property(nonatomic) NSUInteger operationGeneration;
@property(nonatomic) QCState deviceState;
@property(nonatomic) BOOL suppressAutoReconnect;
@property(nonatomic) BOOL appManagedConnections;
- (void)stopScan;
- (void)stopTimer;
- (BOOL)isBindDevice;
- (SyntheticPeripheral *)lastPeripheral;
- (void)remove;
- (void)disconnect;
- (void)reconcileCancellation:(SyntheticPeripheral *)peripheral generation:(NSUInteger)generation attempts:(NSUInteger)attempts;
@end
@implementation SyntheticCentral
- (void)stopScan {}
- (void)stopTimer {}
- (BOOL)isBindDevice { return bound; }
- (SyntheticPeripheral *)lastPeripheral { return self.connectedPeripheral; }
// ACTUAL_CANCELLATION_METHODS
@end

static SyntheticCentral *make(CBPeripheralState state) {
    nextPoll = nil; queued = 0; bound = YES;
    SyntheticCentral *central = [SyntheticCentral new];
    central.appManagedConnections = YES;
    central.centerManager = [SyntheticRadio new];
    central.connectedPeripheral = [SyntheticPeripheral new];
    central.connectedPeripheral.state = state;
    return central;
}
static void poll(void) { void (^block)(void) = nextPoll; nextPoll = nil; check(block != nil); block(); }
int main(void) { @autoreleasepool {
    for (unsigned bits = 0; bits < 16; bits++) check(QRingCanFinishCancellation(bits & 1, bits & 2, bits & 4, bits & 8) == (bits == 15));
    for (NSInteger state = CBPeripheralStateConnecting; state <= CBPeripheralStateDisconnecting; state++) {
        SyntheticCentral *central = make(state);
        central.centerManager.closes = YES;
        [central remove]; // No delegate callback: real method must reconcile.
        check(central.centerManager.cancels == 1);
        check(central.deviceState == QCStateUnbind && central.connectedPeripheral == nil);
        check(!central.suppressAutoReconnect && !bound && queued == 0);

        central = make(state);
        [central remove];
        check(central.deviceState == QCStateDisconnecting && queued == 1);
        check(central.connectedPeripheral != nil && central.suppressAutoReconnect);
        central.connectedPeripheral.state = CBPeripheralStateDisconnected;
        poll();
        check(central.deviceState == QCStateUnbind && central.connectedPeripheral == nil);
    }
    SyntheticCentral *central = make(CBPeripheralStateConnecting);
    [central remove];
    central.operationGeneration++;
    central.connectedPeripheral.state = CBPeripheralStateDisconnected;
    poll();
    check(central.connectedPeripheral != nil && central.deviceState == QCStateDisconnecting);

    central = make(CBPeripheralStateConnecting);
    [central remove];
    SyntheticPeripheral *replacement = [SyntheticPeripheral new];
    replacement.state = CBPeripheralStateConnected;
    central.connectedPeripheral = replacement;
    poll();
    check(central.connectedPeripheral == replacement && central.deviceState == QCStateDisconnecting);

    central = make(CBPeripheralStateConnected);
    [central remove];
    poll(); // A deadline/poll never proves closure while radio is still live.
    check(central.deviceState == QCStateDisconnecting && queued == 2);
    check(central.connectedPeripheral.state == CBPeripheralStateConnected);

    central = make(CBPeripheralStateConnected);
    central.centerManager.throws = YES;
    [central remove];
    check(central.deviceState == QCStateDisconnecting && queued == 1);

    central = make(CBPeripheralStateConnecting);
    central.centerManager.closes = YES;
    [central disconnect];
    check(central.deviceState == QCStateDisconnected && bound);
    check(central.connectedPeripheral == nil && !central.suppressAutoReconnect);

    central = make(CBPeripheralStateDisconnected);
    [central remove];
    check(central.deviceState == QCStateUnbind && central.centerManager.cancels == 0);
    printf("QRing actual cancellation methods: %lu assertions passed\n", (unsigned long)checked);
} return 0; }
