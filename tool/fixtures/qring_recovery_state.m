#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

// Only radio/SDK boundaries and the clock are synthetic. The runner injects
// actual bridge and central methods, including their delegate callback order.
// No CoreBluetooth device, user defaults, account or health data is accessed.
typedef void (^QRingNext)(void);
static void RingControlTrace(__unused NSString *stage, __unused NSDictionary *metadata) {}
typedef void (^FlutterResult)(id);
typedef NS_ENUM(NSInteger, CBPeripheralState) { CBPeripheralStateDisconnected, CBPeripheralStateConnecting, CBPeripheralStateConnected, CBPeripheralStateDisconnecting };
typedef NS_ENUM(NSInteger, QCState) { QCStateUnkown, QCStateUnbind, QCStateConnecting, QCStateConnected, QCStateDisconnecting, QCStateDisconnected };
typedef NS_ENUM(NSInteger, QCBluetoothState) { QCBluetoothStateUnkown, QCBluetoothStateResetting, QCBluetoothStateUnsupported, QCBluetoothStateUnauthorized, QCBluetoothStatePoweredOff, QCBluetoothStatePoweredOn };
typedef NS_ENUM(NSInteger, QCDeviceType) { QCDeviceTypeUnkown, QCDeviceTypeWatch, QCDeviceTypeRing };
static NSString *const QCLastConnectedIdentifier = @"synthetic-only";
static NSUInteger checked;
static NSTimeInterval now;
static NSMutableArray<QRingNext> *immediate, *deadlines;
static NSMutableArray<NSNumber *> *delays;
static void (^registrationResult)(BOOL);
static void check(BOOL value, NSString *message) {
    checked++;
    if (!value) { fprintf(stderr, "Synthetic recovery assertion failed: %s\n", message.UTF8String); exit(1); }
}
@interface SyntheticProcessInfo : NSObject
+ (instancetype)processInfo;
- (NSTimeInterval)systemUptime;
@end
@implementation SyntheticProcessInfo
+ (instancetype)processInfo { return [self new]; }
- (NSTimeInterval)systemUptime { return now; }
@end
#define NSProcessInfo SyntheticProcessInfo
static dispatch_time_t syntheticTime(__unused dispatch_time_t when, int64_t delta) { return delta; }
static void queueDeadline(dispatch_time_t when, __unused dispatch_queue_t queue, dispatch_block_t block) {
    [deadlines addObject:[block copy]]; [delays addObject:@((NSTimeInterval)when / NSEC_PER_SEC)];
}
static void queueImmediate(__unused dispatch_queue_t queue, dispatch_block_t block) { [immediate addObject:[block copy]]; }
#define dispatch_time syntheticTime
#define dispatch_after queueDeadline
#define dispatch_async queueImmediate

@interface CBPeripheral : NSObject
@property(nonatomic) CBPeripheralState state;
@property(nonatomic, strong) NSUUID *identifier;
@property(nonatomic, copy) NSString *name;
@end
@implementation CBPeripheral
@end
@interface CBCentralManager : NSObject
@property(nonatomic, strong) CBPeripheral *available;
@property(nonatomic) NSUInteger retrievals;
- (NSArray<CBPeripheral *> *)retrievePeripheralsWithIdentifiers:(NSArray<NSUUID *> *)identifiers;
@end
@implementation CBCentralManager
- (NSArray<CBPeripheral *> *)retrievePeripheralsWithIdentifiers:(NSArray<NSUUID *> *)identifiers {
    self.retrievals++;
    check(identifiers.count == 1, @"recovery must retrieve only one exact UUID");
    return self.available ? @[self.available] : @[];
}
@end
@interface QCSDKManager : NSObject
+ (instancetype)shareInstance;
- (void)removePeripheral:(CBPeripheral *)peripheral;
- (void)removeAllPeripheral;
- (void)addPeripheral:(CBPeripheral *)peripheral finished:(void (^)(BOOL))finished;
@end
@implementation QCSDKManager
+ (instancetype)shareInstance { return [self new]; }
- (void)removePeripheral:(__unused CBPeripheral *)peripheral {}
- (void)removeAllPeripheral {}
- (void)addPeripheral:(__unused CBPeripheral *)peripheral finished:(void (^)(BOOL))finished { registrationResult = [finished copy]; }
@end
@interface SyntheticDefaults : NSObject
+ (instancetype)standardUserDefaults;
- (void)setValue:(id)value forKey:(NSString *)key;
- (void)synchronize;
@end
@implementation SyntheticDefaults
+ (instancetype)standardUserDefaults { return [self new]; }
- (void)setValue:(__unused id)value forKey:(__unused NSString *)key { check(NO, @"fixture must never save an SDK target"); }
- (void)synchronize {}
@end
#define NSUserDefaults SyntheticDefaults

@protocol SyntheticDelegate <NSObject>
- (void)didState:(QCState)state;
- (void)didFailConnected:(CBPeripheral *)peripheral error:(NSError *)error;
- (void)didConnectTransport:(CBPeripheral *)peripheral;
@end
@interface SyntheticCentral : NSObject
@property(nonatomic, weak) id<SyntheticDelegate> delegate;
@property(nonatomic, strong) CBCentralManager *centerManager;
@property(nonatomic, strong) CBPeripheral *connectedPeripheral;
@property(nonatomic) QCState deviceState;
@property(nonatomic) QCBluetoothState bleState;
@property(nonatomic) BOOL appManagedConnections, suppressAutoReconnect, bound, hasPendingRestoredCancellations;
@property(nonatomic) NSUInteger operationGeneration, connects, disconnects;
- (void)stopTimer;
- (BOOL)isBindDevice;
- (BOOL)finishRestoredCancellation:(CBPeripheral *)peripheral;
- (void)startToReconnect;
- (void)disconnect;
- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout deviceType:(QCDeviceType)type;
- (void)registerConnectedPeripheral:(CBPeripheral *)peripheral;
- (void)notifyConnectFailed:(CBPeripheral *)peripheral error:(NSError *)error;
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
@end
@interface SyntheticBridge : NSObject<SyntheticDelegate>
@property(nonatomic, strong) SyntheticCentral *central;
@property(nonatomic, copy) NSString *connectedID, *connectedName, *recoveryTargetID, *recoveryTargetName, *recoveryContext;
@property(nonatomic, copy) NSDictionary *profile, *recoveryProfile, *featureList;
@property(nonatomic, copy) FlutterResult pendingConnect, pendingDisconnect, pendingSync;
@property(nonatomic) BOOL recoveryConnecting, cancellingConnection, readingDetails, remoteCameraSupported;
@property(nonatomic) NSTimeInterval recoveryRetryNotBefore;
@property(nonatomic) NSUInteger connectionGeneration, connectDeadlineGeneration, measurementGeneration, syncGeneration;
@property(nonatomic, strong) NSNumber *battery, *charging;
@property(nonatomic, strong) NSDate *batteryUpdatedAt;
@property(nonatomic, copy) NSString *firmware, *activeMetric, *activeSportMode;
@property(nonatomic) NSInteger activeSportType;
@property(nonatomic, strong) NSMutableArray *events;
- (id)error:(NSString *)code message:(NSString *)message;
- (void)emit:(NSString *)type payload:(NSDictionary *)payload;
- (void)resolveCapabilities;
- (void)resetRemoteCamera;
- (void)finishCamera:(id)error;
- (BOOL)isQRingName:(NSString *)name;
- (BOOL)isResolved;
- (void)startAutomaticRecovery;
- (void)scheduleRecoveryAfterDisconnect;
- (void)failConnect:(NSString *)code message:(NSString *)message;
- (void)didBluetoothState:(QCBluetoothState)state;
@end
@implementation SyntheticCentral
@synthesize deviceState = _deviceState;
- (void)stopTimer {}
- (BOOL)isBindDevice { return self.bound; }
- (BOOL)finishRestoredCancellation:(__unused CBPeripheral *)peripheral { return NO; }
- (void)startToReconnect { check(NO, @"bundled SDK must not independently reconnect"); }
- (void)disconnect { self.disconnects++; }
- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout deviceType:(QCDeviceType)type {
    check(timeout == 0 && type == QCDeviceTypeRing, @"recovery must use one indefinite ring request");
    self.connects++; self.operationGeneration++; self.connectedPeripheral = peripheral;
    peripheral.state = CBPeripheralStateConnecting; self.deviceState = QCStateConnecting;
}
// ACTUAL_CENTRAL_METHODS
@end
@implementation SyntheticBridge
- (id)error:(NSString *)code message:(NSString *)message { return @{ @"code": code, @"message": message }; }
- (void)emit:(NSString *)type payload:(NSDictionary *)payload { [self.events addObject:@{ @"type": type, @"payload": payload }]; }
- (void)resolveCapabilities {}
- (void)resetRemoteCamera {}
- (void)finishCamera:(__unused id)error {}
- (void)didConnectTransport:(__unused CBPeripheral *)peripheral {}
- (BOOL)isQRingName:(NSString *)name { return [name isEqual:@"R21_fixture"]; }
// ACTUAL_BRIDGE_METHODS
@end

static CBPeripheral *peripheral(NSString *identifier) {
    CBPeripheral *value = [CBPeripheral new];
    value.identifier = [[NSUUID alloc] initWithUUIDString:identifier];
    value.name = @"R21_fixture"; value.state = CBPeripheralStateConnected;
    return value;
}
static SyntheticBridge *make(void) {
    now = 100; registrationResult = nil;
    immediate = [NSMutableArray new]; deadlines = [NSMutableArray new]; delays = [NSMutableArray new];
    SyntheticBridge *bridge = [SyntheticBridge new];
    bridge.central = [SyntheticCentral new]; bridge.central.centerManager = [CBCentralManager new];
    CBPeripheral *ring = peripheral(@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE");
    bridge.central.connectedPeripheral = ring; bridge.central.centerManager.available = ring;
    bridge.central.deviceState = QCStateConnected; bridge.central.bleState = QCBluetoothStatePoweredOn;
    bridge.central.operationGeneration = 10; bridge.central.bound = YES; bridge.central.appManagedConnections = YES;
    bridge.central.delegate = bridge;
    bridge.connectionGeneration = 20; bridge.connectedID = ring.identifier.UUIDString;
    bridge.connectedName = ring.name; bridge.recoveryTargetID = ring.identifier.UUIDString;
    bridge.recoveryTargetName = ring.name; bridge.recoveryContext = @"synthetic:owner-a";
    bridge.recoveryProfile = @{}; bridge.featureList = @{ @"known": @YES };
    bridge.events = [NSMutableArray new]; bridge.activeSportType = -1; bridge.firmware = @"fixture";
    return bridge;
}
static NSError *failure(void) { return [NSError errorWithDomain:@"synthetic" code:6 userInfo:nil]; }
static void beginRecovery(SyntheticBridge *bridge) {
    bridge.featureList = nil; bridge.recoveryConnecting = YES;
    bridge.central.connectedPeripheral.state = CBPeripheralStateConnecting;
    bridge.central.deviceState = QCStateConnecting;
}
static void nativeFailure(SyntheticBridge *bridge) {
    CBPeripheral *ring = bridge.central.connectedPeripheral;
    ring.state = CBPeripheralStateDisconnected;
    [bridge.central centralManager:bridge.central.centerManager didFailToConnectPeripheral:ring error:failure()];
}
static void checkCooldown(SyntheticBridge *bridge) {
    check(bridge.recoveryRetryNotBefore == 102, @"failed handshake must preserve the two-second cooldown before flags are cleared");
    check(immediate.count == 0 && deadlines.count == 1 && delays[0].doubleValue == 2, @"state-first/failure-second callbacks must queue only the delayed retry");
    check(!bridge.recoveryConnecting && bridge.pendingConnect == nil, @"failed attempt must be retired");
    now = 101.9; [bridge startAutomaticRecovery];
    check(bridge.central.connects == 0, @"foreground or Bluetooth callbacks must not bypass cooldown");
    now = 102; deadlines[0]();
    check(bridge.central.connects == 1 && bridge.recoveryConnecting, @"retry must resume at cooldown expiry");
    check([bridge.connectedID isEqual:bridge.recoveryTargetID], @"retry must retain the exact original target");
    check([bridge.recoveryContext isEqual:@"synthetic:owner-a"] && bridge.central.bound, @"retry must preserve owner and binding");
}

int main(int argc, const char *argv[]) { @autoreleasepool {
    NSString *scenario = argc > 1 ? @(argv[1]) : @"";
    SyntheticBridge *bridge = make();
    if ([scenario isEqual:@"automatic-failure"]) {
        beginRecovery(bridge); nativeFailure(bridge); checkCooldown(bridge);
        check(bridge.central.disconnects == 0, @"an already failed radio must not receive another cancellation");
    } else if ([scenario isEqual:@"sdk-registration-failure"]) {
        beginRecovery(bridge); bridge.central.connectedPeripheral.state = CBPeripheralStateConnected;
        [bridge.central registerConnectedPeripheral:bridge.central.connectedPeripheral];
        check(registrationResult != nil, @"SDK registration callback must be pending");
        registrationResult(NO); checkCooldown(bridge);
    } else if ([scenario isEqual:@"explicit-failure"]) {
        __block NSUInteger results = 0;
        beginRecovery(bridge); bridge.recoveryConnecting = NO;
        bridge.pendingConnect = ^(id result) { results++; check([result[@"code"] isEqual:@"QRING_DISCONNECTED"], @"explicit failure must complete its original request"); };
        nativeFailure(bridge); checkCooldown(bridge);
        check(results == 1, @"explicit connect must complete exactly once");
    } else if ([scenario isEqual:@"ordinary-disconnect"]) {
        CBPeripheral *ring = bridge.central.connectedPeripheral; ring.state = CBPeripheralStateDisconnected;
        [bridge.central centralManager:bridge.central.centerManager didDisconnectPeripheral:ring error:failure()];
        check(bridge.recoveryRetryNotBefore == 0, @"established-session drop must not acquire handshake cooldown");
        check(immediate.count == 1 && deadlines.count == 0, @"ordinary proximity drop must re-arm next main-loop turn");
        immediate[0]();
        check(bridge.central.connects == 1 && bridge.recoveryConnecting, @"ordinary drop must reconnect immediately");
        check(bridge.central.disconnects == 0 && bridge.central.bound, @"ordinary drop must neither cancel again nor unbind");
    } else if ([scenario isEqual:@"stale-callbacks"]) {
        CBPeripheral *old = bridge.central.connectedPeripheral;
        [bridge.central registerConnectedPeripheral:old];
        void (^oldSDK)(BOOL) = [registrationResult copy];
        CBPeripheral *new = peripheral(@"FFFFFFFF-BBBB-CCCC-DDDD-EEEEEEEEEEEE");
        bridge.central.operationGeneration++; bridge.connectionGeneration++;
        bridge.central.connectedPeripheral = new; bridge.central.centerManager.available = new;
        bridge.connectedID = new.identifier.UUIDString; bridge.recoveryTargetID = new.identifier.UUIDString;
        NSUInteger generation = bridge.connectionGeneration;
        old.state = CBPeripheralStateDisconnected;
        [bridge.central centralManager:bridge.central.centerManager didFailToConnectPeripheral:old error:failure()];
        oldSDK(NO);
        check(bridge.connectionGeneration == generation && bridge.central.deviceState == QCStateConnected, @"old-target transport/SDK failures must not retire a new session");
        check(bridge.central.disconnects == 0 && bridge.recoveryRetryNotBefore == 0, @"old failures must not cancel or delay the new target");
        // The same peripheral can be reused by CoreBluetooth; its current radio
        // state must also reject an old failure after a new attempt has started.
        beginRecovery(bridge);
        [bridge.central centralManager:bridge.central.centerManager didFailToConnectPeripheral:new error:failure()];
        check(bridge.recoveryConnecting && bridge.connectionGeneration == generation, @"same-target stale failure must not interrupt a new connecting radio");
        new.state = CBPeripheralStateConnected; bridge.recoveryConnecting = NO;
        bridge.central.deviceState = QCStateConnected; bridge.featureList = @{ @"known": @YES };
        [bridge.central centralManager:bridge.central.centerManager didFailToConnectPeripheral:new error:failure()];
        check([bridge isResolved] && bridge.connectionGeneration == generation, @"same-target stale failure must not interrupt an established radio");
        check(immediate.count == 0 && deadlines.count == 0, @"stale callbacks must not schedule recovery");
    } else if ([scenario isEqual:@"cancel-and-owner"]) {
        beginRecovery(bridge); bridge.recoveryRetryNotBefore = 105;
        nativeFailure(bridge);
        check(bridge.recoveryRetryNotBefore >= 105, @"a failure must not shorten an existing later retry barrier");
        NSUInteger calls = bridge.central.connects;
        bridge.connectionGeneration++; bridge.recoveryTargetID = @""; bridge.recoveryContext = @"";
        now = 106; for (QRingNext block in deadlines.copy) block(); for (QRingNext block in immediate.copy) block();
        [bridge startAutomaticRecovery];
        check(bridge.central.connects == calls, @"retired owner/generation must not reconnect");
        bridge = make(); beginRecovery(bridge); bridge.cancellingConnection = YES;
        bridge.pendingDisconnect = ^(__unused id result) {};
        bridge.recoveryTargetID = @""; bridge.recoveryContext = @"";
        bridge.central.connectedPeripheral.state = CBPeripheralStateDisconnected;
        [bridge.central centralManager:bridge.central.centerManager didDisconnectPeripheral:bridge.central.connectedPeripheral error:nil];
        check(bridge.recoveryRetryNotBefore == 0, @"intentional cancellation must not be classified as handshake failure");
        for (QRingNext block in immediate.copy) block();
        check(bridge.central.connects == 0 && bridge.central.bound, @"intentional cancellation must not reconnect or remove binding in this bridge fixture");
    } else if ([scenario isEqual:@"power-state-diagnostic"]) {
        for (NSNumber *state in @[@(QCBluetoothStatePoweredOff), @(QCBluetoothStateResetting)]) {
            bridge = make(); beginRecovery(bridge);
            NSString *target = bridge.recoveryTargetID, *owner = bridge.recoveryContext;
            bridge.central.bleState = state.integerValue;
            [bridge didBluetoothState:state.integerValue];
            bridge.central.connectedPeripheral.state = CBPeripheralStateDisconnected;
            bridge.central.bleState = QCBluetoothStatePoweredOn;
            [bridge didBluetoothState:QCBluetoothStatePoweredOn];
            check([bridge.recoveryTargetID isEqual:target] && [bridge.recoveryContext isEqual:owner] && bridge.central.bound, @"power state changes must preserve exact owner and binding");
            check(bridge.central.disconnects == 0, @"power diagnostics must not force cancellation");
            printf("Power state %ld without disconnect callback: attempts=%lu pending=%s targetPreserved=YES (diagnostic only)\n", (long)state.integerValue, (unsigned long)bridge.central.connects, bridge.recoveryConnecting ? "YES" : "NO");
        }
    } else { check(NO, @"unknown scenario"); }
    printf("QRing recovery %s: %lu assertions passed (synthetic callbacks, not device timing)\n", scenario.UTF8String, (unsigned long)checked);
} return 0; }
