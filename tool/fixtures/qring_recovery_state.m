#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "QRingNamePolicy.h"

// Only radio/SDK boundaries and the clock are synthetic. The runner injects
// actual bridge and central methods, including their delegate callback order.
// No CoreBluetooth device, user defaults, account or health data is accessed.
typedef void (^QRingNext)(void);
static void RingControlTrace(__unused NSString *stage, __unused NSDictionary *metadata) {}
typedef void (^FlutterResult)(id);
typedef NS_ENUM(NSInteger, CBPeripheralState) { CBPeripheralStateDisconnected, CBPeripheralStateConnecting, CBPeripheralStateConnected, CBPeripheralStateDisconnecting };
typedef NS_ENUM(NSInteger, QCState) { QCStateUnkown, QCStateUnbind, QCStateConnecting, QCStateConnected, QCStateDisconnecting, QCStateDisconnected };
typedef NS_ENUM(NSInteger, QCBluetoothState) { QCBluetoothStateUnkown, QCBluetoothStateResetting, QCBluetoothStateUnsupported, QCBluetoothStateUnauthorized, QCBluetoothStatePoweredOff, QCBluetoothStatePoweredOn };
typedef NS_ENUM(NSInteger, CBManagerState) { CBManagerStateUnknown, CBManagerStateResetting, CBManagerStateUnsupported, CBManagerStateUnauthorized, CBManagerStatePoweredOff, CBManagerStatePoweredOn };
typedef NS_ENUM(NSInteger, QCDeviceType) { QCDeviceTypeUnkown, QCDeviceTypeWatch, QCDeviceTypeRing };
static NSString *const QCLastConnectedIdentifier = @"synthetic-only";
static NSString *const CBErrorDomain = @"CBErrorDomain";
static NSString *const CBAdvertisementDataLocalNameKey = @"LocalName";
static NSString *const QCBANDSDKSERVERUUID1 = @"7905FFF0-B5CE-4E99-A40F-4B1E122D00D0";
static NSString *const QCBANDSDKSERVERUUID2 = @"FEE7";
static NSUInteger checked;
static NSUInteger sdkRemovalCalls;
static NSTimeInterval now;
static NSMutableArray<QRingNext> *immediate, *deadlines;
static NSMutableArray<NSNumber *> *delays;
static void (^registrationResult)(BOOL);
static NSUInteger registrationCount;
static NSString *allowedRegistrationID;
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
@interface CBUUID : NSObject
@property(nonatomic, copy) NSString *UUIDString;
+ (instancetype)UUIDWithString:(NSString *)string;
@end
@implementation CBUUID
+ (instancetype)UUIDWithString:(NSString *)string {
    CBUUID *uuid = [CBUUID new];
    uuid.UUIDString = string.uppercaseString;
    return uuid;
}
@end
@interface QCBlePeripheral : NSObject
@property(nonatomic,strong) CBPeripheral *peripheral;
@property(nonatomic,strong) NSNumber *RSSI;
@property(nonatomic,copy) NSString *mac;
@property(nonatomic,copy) NSString *selectionName;
@property(nonatomic,strong) NSDictionary *advertisementData;
@property(nonatomic) BOOL isPaired;
@end
@implementation QCBlePeripheral
@end
@interface CBCentralManager : NSObject
@property(nonatomic, strong) CBPeripheral *available;
@property(nonatomic) NSUInteger retrievals;
@property(nonatomic) CBManagerState state;
@property(nonatomic) NSUInteger cancellations;
- (NSArray<CBPeripheral *> *)retrievePeripheralsWithIdentifiers:(NSArray<NSUUID *> *)identifiers;
- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral;
@end
@implementation CBCentralManager
- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral {
    self.cancellations++;
    peripheral.state = CBPeripheralStateDisconnected;
}
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
- (void)removeAllPeripheral { sdkRemovalCalls++; }
- (void)addPeripheral:(__unused CBPeripheral *)peripheral finished:(void (^)(BOOL))finished { registrationCount++; registrationResult = [finished copy]; }
@end
@interface SyntheticDefaults : NSObject
+ (instancetype)standardUserDefaults;
- (void)setValue:(id)value forKey:(NSString *)key;
- (void)synchronize;
@end
@implementation SyntheticDefaults
+ (instancetype)standardUserDefaults { return [self new]; }
- (void)setValue:(id)value forKey:(NSString *)key { check([key isEqual:QCLastConnectedIdentifier] && [value isEqual:allowedRegistrationID], @"only an explicitly expected successful SDK registration can be saved"); }
- (void)synchronize {}
@end
#define NSUserDefaults SyntheticDefaults

@protocol SyntheticDelegate <NSObject>
- (void)didState:(QCState)state;
- (void)didFailConnected:(CBPeripheral *)peripheral error:(NSError *)error;
- (void)didConnectTransport:(CBPeripheral *)peripheral;
@optional
- (void)didScanPeripherals:(NSArray<QCBlePeripheral *> *)peripherals;
- (void)didDisconnectTransport:(CBPeripheral *)peripheral error:(NSError *)error;
- (void)didBluetoothState:(QCBluetoothState)state;
@end
@interface SyntheticCentral : NSObject
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<CBPeripheral *> *> *systemLinksByService;
@property(nonatomic,strong) NSMutableArray<QCBlePeripheral *> *peripherals;
@property(nonatomic) NSUInteger registrationGeneration;
@property(nonatomic, weak) id<SyntheticDelegate> delegate;
@property(nonatomic, strong) CBCentralManager *centerManager;
@property(nonatomic, strong) CBPeripheral *connectedPeripheral;
@property(nonatomic) QCState deviceState;
@property(nonatomic) QCBluetoothState bleState;
@property(nonatomic) BOOL appManagedConnections, suppressAutoReconnect, bound, hasPendingRestoredCancellations;
@property(nonatomic) NSUInteger operationGeneration, connects, disconnects, scans, scanStops;
@property(nonatomic) BOOL isScanning;
- (void)scanWithTimeout:(NSInteger)timeout;
- (void)stopScan;
- (void)stopTimer;
- (BOOL)isBindDevice;
- (BOOL)finishRestoredCancellation:(CBPeripheral *)peripheral;
- (void)startToReconnect;
- (void)disconnect;
- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout deviceType:(QCDeviceType)type;
- (void)registerConnectedPeripheral:(CBPeripheral *)peripheral;
- (void)notifyConnectFailed:(CBPeripheral *)peripheral error:(NSError *)error;
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral;
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
- (void)centralManagerDidUpdateState:(CBCentralManager *)central;
@end
@interface SyntheticBridge : NSObject<SyntheticDelegate>
@property(nonatomic, strong) SyntheticCentral *central;
@property(nonatomic, copy) NSString *connectedID, *connectedName, *recoveryTargetID, *recoveryTargetName, *recoveryContext;
@property(nonatomic, copy) NSDictionary *profile, *recoveryProfile, *featureList;
@property(nonatomic, copy) FlutterResult pendingConnect, pendingDisconnect, pendingSync, pendingScan;
@property(nonatomic, copy) NSString *selectionTargetID;
@property(nonatomic,strong) NSMutableDictionary *scanned;
@property(nonatomic) BOOL recoveryConnecting, cancellingConnection, readingDetails, remoteCameraSupported, recoveryScanning;
@property(nonatomic) NSUInteger recoveryScanGeneration;
@property(nonatomic) NSTimeInterval recoveryRetryNotBefore;
@property(nonatomic) NSUInteger connectionGeneration, connectDeadlineGeneration, measurementGeneration, syncGeneration, resolutions;
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
- (void)connectRecoveredPeripheral:(CBPeripheral *)peripheral;
- (void)finishScan;
- (NSArray *)scanPayloads;
- (void)didScanPeripherals:(NSArray<QCBlePeripheral *> *)peripherals;
- (void)scanPeripheralFinish;
- (void)scheduleRecoveryAfterDisconnect;
- (void)failConnect:(NSString *)code message:(NSString *)message;
- (void)didBluetoothState:(QCBluetoothState)state;
@end
@implementation SyntheticCentral
@synthesize deviceState = _deviceState;
- (NSArray<CBPeripheral *> *)retrieveConnectPeripheral:(NSArray<CBUUID *> *)services {
    NSMutableOrderedSet *matches = [NSMutableOrderedSet orderedSet];
    for (CBUUID *service in services) {
        [matches addObjectsFromArray:self.systemLinksByService[service.UUIDString] ?: @[]];
    }
    return matches.array;
}
- (void)stopTimer {}
- (NSString *)macFromAdvertisementData:(NSDictionary *)ad { return ad[@"testMAC"]; }
- (void)stopScan { self.isScanning = NO; self.scanStops++; }
- (void)scanWithTimeout:(NSInteger)timeout {
    check(timeout == 8, @"cache-miss scan must be bounded");
    self.scans++; self.isScanning = YES;
}
- (BOOL)isBindDevice { return self.bound; }
- (BOOL)finishRestoredCancellation:(__unused CBPeripheral *)peripheral { return NO; }
- (void)startToReconnect { check(NO, @"bundled SDK must not independently reconnect"); }
- (void)disconnect {
    self.disconnects++; self.operationGeneration++;
    if (self.connectedPeripheral.state != CBPeripheralStateDisconnected) self.deviceState = QCStateDisconnecting;
    else { self.connectedPeripheral = nil; self.deviceState = QCStateDisconnected; }
}
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
- (void)resolveCapabilities { self.resolutions++; }
- (void)resetRemoteCamera {}
- (void)finishCamera:(__unused id)error {}
- (void)didConnectTransport:(__unused CBPeripheral *)peripheral {}
// ACTUAL_BRIDGE_METHODS
@end

static CBPeripheral *peripheral(NSString *identifier) {
    CBPeripheral *value = [CBPeripheral new];
    value.identifier = [[NSUUID alloc] initWithUUIDString:identifier];
    value.name = @"R21_fixture"; value.state = CBPeripheralStateConnected;
    return value;
}
static SyntheticBridge *make(void) {
    now = 100; registrationResult = nil; sdkRemovalCalls = 0;
    registrationCount = 0; allowedRegistrationID = nil;
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
    bridge.scanned = [NSMutableDictionary new]; bridge.events = [NSMutableArray new]; bridge.activeSportType = -1; bridge.firmware = @"fixture";
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
    if ([scenario isEqual:@"advertisement-only-name"]) {
        CBPeripheral *ring = peripheral(NSUUID.UUID.UUIDString);
        ring.name = nil;
        bridge.central.peripherals = [NSMutableArray array];
        bridge.central.isScanning = YES;
        bridge.pendingScan = ^(__unused id value) {};
        void (^advertise)(id) = ^(id name) {
            [bridge.central centralManager:bridge.central.centerManager didDiscoverPeripheral:ring
                        advertisementData:name ? @{CBAdvertisementDataLocalNameKey:name} : @{} RSSI:@(-58)];
        };
        advertise(nil); advertise(@42);
        check(bridge.scanned.count == 0, @"an empty or malformed advertisement must not authorize a new candidate");
        advertise(@"R7Pro");
        check(bridge.scanned.count == 0, @"another provider must not enter this channel");
        advertise(@"SD_RING_R8"); advertise(@"SD_RING_R8");
        NSArray *choices = [bridge scanPayloads];
        check(choices.count == 1 && [choices[0][@"id"] isEqual:ring.identifier.UUIDString] &&
              [choices[0][@"name"] isEqual:@"SD_RING_R8"] && [choices[0][@"rssi"] isEqual:@(-58)],
              @"a real local name arriving later on the same UUID must reveal the advertised ring");
        check(bridge.events.count == 1 && bridge.central.connects == 0, @"duplicate advertisements must not duplicate the row or trigger a connection");
        [bridge.central centralManager:bridge.central.centerManager didDiscoverPeripheral:ring
                     advertisementData:@{@"testMAC": @"AA:BB:CC:DD:EE:FF"} RSSI:@(-53)];
        check([[[bridge scanPayloads].firstObject objectForKey:@"hardwareAddress"] isEqual:@"AA:BB:CC:DD:EE:FF"],
              @"a later address without a name must update only the already named UUID");
        ring.name = @"HR05";
        check([bridge scanPayloads].count == 0, @"an incompatible system name must veto the earlier advertisement");
        ring.name = @"SD_RING_R8"; advertise(@"HR05");
        check([bridge scanPayloads].count == 0, @"an incompatible advertised name must veto the earlier system name");
        bridge.central.isScanning = NO;
        advertise(@"R8");
        check([bridge scanPayloads].count == 0, @"a late discovery callback must not mutate the retired scan");
    } else if ([scenario isEqual:@"registration-idempotence"]) {
        CBPeripheral *ring = bridge.central.connectedPeripheral;
        bridge.central.deviceState = QCStateConnecting;
        [bridge.central registerConnectedPeripheral:ring];
        [bridge.central centralManager:bridge.central.centerManager didConnectPeripheral:ring];
        check(registrationCount == 1, @"overlapping cached transport and didConnect must start only one SDK registration");
        allowedRegistrationID = ring.identifier.UUIDString;
        registrationResult(YES); registrationResult(NO);
        [bridge.central centralManager:bridge.central.centerManager didConnectPeripheral:ring];
        check(registrationCount == 1 && bridge.central.deviceState == QCStateConnected &&
              bridge.central.disconnects == 0, @"late callbacks must not restart registration or tear down the ready link");
        bridge.central.deviceState = QCStateDisconnecting;
        CBPeripheral *other = peripheral(NSUUID.UUID.UUIDString);
        [bridge.central centralManager:bridge.central.centerManager didConnectPeripheral:other];
        check(bridge.central.centerManager.cancellations == 0, @"cancelling the current target must not disconnect another peripheral");
        [bridge.central centralManager:bridge.central.centerManager didConnectPeripheral:ring];
        check(bridge.central.centerManager.cancellations == 1, @"a pending cancellation still cancels the exact target");
    } else if ([scenario isEqual:@"system-connected-selection"]) {
        CBPeripheral *ring = peripheral(NSUUID.UUID.UUIDString);
        ring.name = @"SD_RING_R8";
        ring.state = CBPeripheralStateDisconnected;
        CBPeripheral *otherModel = peripheral(NSUUID.UUID.UUIDString);
        otherModel.name = @"HR05";
        CBPeripheral *generic = peripheral(NSUUID.UUID.UUIDString);
        generic.state = CBPeripheralStateDisconnected;
        for (NSString *service in @[@"DE5BF728-D711-4E47-AF26-65E3012A5DC7", @"6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E"]) {
            bridge.central.systemLinksByService = @{service: @[ring, otherModel], @"1800": @[generic]};
            NSArray *choices = [bridge systemConnectedDevicesForSelection];
            check(choices.count == 1 && [choices[0][@"id"] isEqual:ring.identifier.UUIDString],
                  @"vendor service alone must reveal the exact disconnected R8, excluding wrong-provider and generic-only candidates");
            QCBlePeripheral *item = bridge.scanned[ring.identifier.UUIDString];
            check(item.peripheral == ring, @"manual choice must retain the exact peripheral for a later tap");
            [bridge.scanned removeAllObjects];
            bridge.pendingScan = ^(__unused id result) {};
            [bridge didScanPeripherals:@[item]];
            check([bridge.events.lastObject[@"payload"] isEqual:choices[0]] && [[bridge scanPayloads] isEqual:choices],
                  @"manual list, live search event and completed search must show the same device without fabricated RSSI or MAC");
            item.RSSI = @127;
            check([bridge scanPayloads].firstObject[@"rssi"] == nil, @"reserved RSSI must be omitted");
            item.RSSI = @(-52);
            check([[bridge scanPayloads].firstObject[@"rssi"] isEqual:@(-52)], @"retain real advertisement strength");
        }
        ring.state = CBPeripheralStateConnected;
        bridge.central.systemLinksByService = @{QCBANDSDKSERVERUUID2: @[ring], @"1812": @[ring]};
        check([bridge systemConnectedDevicesForSelection].count == 1, @"legacy services returning the same UUID yield one choice");
        bridge.central.bleState = QCBluetoothStatePoweredOff;
        check([bridge systemConnectedDevicesForSelection].count == 0, @"powered-off radio has no system candidates");
        check(bridge.central.connects == 0 && ![bridge.recoveryTargetID isEqual:ring.identifier.UUIDString],
              @"manual discovery must not connect or replace the current owner target");
    } else if ([scenario isEqual:@"automatic-failure"]) {
        beginRecovery(bridge); nativeFailure(bridge); checkCooldown(bridge);
        check(bridge.central.disconnects == 0, @"an already failed radio must not receive another cancellation");
    } else if ([scenario isEqual:@"sdk-registration-failure"] || [scenario isEqual:@"sdk-unbound-cache"] || [scenario isEqual:@"sdk-cancelled-owner"]) {
        BOOL nativeBound = ![scenario isEqual:@"sdk-unbound-cache"];
        bridge.central.bound = nativeBound;
        beginRecovery(bridge); CBPeripheral *ring = bridge.central.connectedPeripheral;
        ring.state = CBPeripheralStateConnected;
        [bridge.central registerConnectedPeripheral:ring];
        check(registrationResult != nil, @"SDK registration callback must be pending");
        void (^oldSDK)(BOOL) = registrationResult;
        registrationResult(NO);
        check(bridge.recoveryRetryNotBefore == 102, @"failed handshake must preserve the two-second cooldown before flags are cleared");
        check(bridge.central.disconnects == 1 && bridge.cancellingConnection, @"SDK failure on a live radio must cancel that transport before retry");
        check(bridge.central.deviceState == QCStateDisconnecting && ring.state == CBPeripheralStateConnected, @"requesting cancellation must not pretend the radio is closed");
        now = 102; for (QRingNext block in deadlines.copy) block();
        [bridge startAutomaticRecovery];
        check(bridge.central.connects == 0, @"cooldown expiry must not bypass actual cancellation");
        [deadlines removeAllObjects]; [delays removeAllObjects]; [immediate removeAllObjects];
        BOOL revoked = [scenario isEqual:@"sdk-cancelled-owner"];
        if (revoked) { bridge.connectionGeneration++; bridge.recoveryTargetID=@""; bridge.recoveryContext=@""; }
        ring.state = CBPeripheralStateDisconnected;
        [bridge.central centralManager:bridge.central.centerManager didDisconnectPeripheral:ring error:nil];
        check(!bridge.cancellingConnection && immediate.count == 1, @"confirmed radio closure must retire cancellation and rearm recovery");
        immediate[0]();
        if (revoked) {
            check(bridge.central.connects == 0 && !bridge.recoveryConnecting, @"owner revoked while cancelling must not reconnect after radio closure");
            oldSDK(NO); check(bridge.central.connects == 0, @"old callback must not revive a revoked owner");
        } else {
            check(bridge.central.connects == 1 && bridge.recoveryConnecting, @"closed failed transport must retry once with a fresh session");
            oldSDK(NO);
            check(bridge.central.connects == 1 && bridge.recoveryConnecting, @"late old registration failure cannot cancel the new attempt");
            check([bridge.connectedID isEqual:bridge.recoveryTargetID] && [bridge.recoveryContext isEqual:@"synthetic:owner-a"] && bridge.central.bound == nativeBound, @"SDK failure cleanup must preserve exact owner and binding");
        }
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
        bridge.central.deviceState = QCStateConnecting;
        [bridge.central registerConnectedPeripheral:old];
        void (^oldSDK)(BOOL) = [registrationResult copy];
        CBPeripheral *new = peripheral(@"FFFFFFFF-BBBB-CCCC-DDDD-EEEEEEEEEEEE");
        bridge.central.operationGeneration++; bridge.connectionGeneration++;
        bridge.central.connectedPeripheral = new; bridge.central.centerManager.available = new;
        bridge.central.deviceState = QCStateConnected;
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
    } else if ([scenario isEqual:@"duplicate-state"]) {
        bridge.central.deviceState = QCStateConnecting;
        bridge.central.deviceState = QCStateConnected;
        bridge.central.deviceState = QCStateConnected;
        check(bridge.resolutions == 1, @"same connected state must not restart SDK preparation");
        CBPeripheral *ring = bridge.central.connectedPeripheral;
        ring.state = CBPeripheralStateDisconnected;
        [bridge.central centralManager:bridge.central.centerManager didDisconnectPeripheral:ring error:failure()];
        NSUInteger generation = bridge.connectionGeneration;
        bridge.central.deviceState = QCStateDisconnected;
        check(bridge.connectionGeneration == generation && immediate.count == 1, @"duplicate disconnected state must not retire or duplicate recovery");
    } else if ([scenario isEqual:@"unnamed-exact-recovery"]) {
        bridge.central.connectedPeripheral = nil;
        bridge.central.deviceState = QCStateDisconnected;
        bridge.connectedID = @"";
        bridge.featureList = nil;
        CBPeripheral *same = peripheral(bridge.recoveryTargetID);
        same.name = nil;
        same.state = CBPeripheralStateDisconnected;
        bridge.central.centerManager.available = same;
        [bridge startAutomaticRecovery];
        check(bridge.central.connects == 1 && bridge.central.connectedPeripheral == same && bridge.recoveryConnecting,
              @"an exact owner-bound UUID must recover when CoreBluetooth omits the cached name");
        check([bridge.connectedName isEqual:bridge.recoveryTargetName],
              @"the validated saved name must remain available for the recovered session");
        bridge = make();
        bridge.central.connectedPeripheral = nil;
        bridge.central.deviceState = QCStateDisconnected;
        bridge.connectedID = @"";
        bridge.featureList = nil;
        bridge.recoveryTargetName = @"other-provider";
        CBPeripheral *unnamed = peripheral(bridge.recoveryTargetID);
        unnamed.name = nil;
        unnamed.state = CBPeripheralStateDisconnected;
        bridge.central.centerManager.available = unnamed;
        [bridge startAutomaticRecovery];
        check(bridge.central.connects == 0,
              @"an unverified saved name must not authorize a nameless radio");
        bridge = make();
        bridge.central.connectedPeripheral = nil;
        bridge.central.deviceState = QCStateDisconnected;
        bridge.connectedID = @"";
        bridge.featureList = nil;
        CBPeripheral *other = peripheral(bridge.recoveryTargetID);
        other.name = @"other-provider";
        other.state = CBPeripheralStateDisconnected;
        bridge.central.centerManager.available = other;
        [bridge startAutomaticRecovery];
        check(bridge.central.connects == 0,
              @"a conflicting current name must not be ignored just because the UUID was saved");
    } else if ([scenario hasPrefix:@"cache-"]) {
        bridge.central.connectedPeripheral = nil;
        bridge.central.deviceState = QCStateDisconnected;
        bridge.connectedID = @""; bridge.featureList = nil;
        [immediate removeAllObjects]; [deadlines removeAllObjects]; [delays removeAllObjects];
        CBPeripheral *target = peripheral(bridge.recoveryTargetID);
        target.state = CBPeripheralStateDisconnected;
        bridge.central.centerManager.available = [scenario isEqual:@"cache-hit-pending"] ? target : nil;
        [bridge startAutomaticRecovery];
        if ([scenario isEqual:@"cache-hit-pending"]) {
            check(bridge.central.connects == 1 && bridge.recoveryConnecting && !bridge.recoveryScanning,
                  @"cached target must retain a real indefinite radio request");
            [bridge startAutomaticRecovery];
            now += 60; [bridge startAutomaticRecovery];
            check(bridge.central.connects == 1 && bridge.central.scans == 0,
                  @"valid pending proximity request must never fall back or restart");
        } else {
            check(bridge.central.scans == 1 && bridge.recoveryScanning && !bridge.recoveryConnecting,
                  @"empty cache must start bounded discovery instead of a fake pending connection");
            [bridge startAutomaticRecovery];
            check(bridge.central.scans == 1 && bridge.central.connects == 0,
                  @"repeated foreground callbacks cannot duplicate discovery");
            QCBlePeripheral *other = [QCBlePeripheral new];
            other.peripheral = peripheral(@"FFFFFFFF-BBBB-CCCC-DDDD-EEEEEEEEEEEE");
            [bridge didScanPeripherals:@[other]];
            check(immediate.count == 0 && bridge.central.connects == 0,
                  @"another ring with the same verified name must never be adopted");
            QCBlePeripheral *match = [QCBlePeripheral new]; match.peripheral = target;
            match.selectionName = @"HR05";
            [bridge didScanPeripherals:@[match]];
            check(immediate.count == 0 && bridge.central.connects == 0,
                  @"even the saved UUID cannot adopt a conflicting advertised provider");
            match.selectionName = nil;
            if ([scenario isEqual:@"cache-miss-timeout"]) {
                [bridge scanPeripheralFinish];
                check(!bridge.recoveryScanning && delays.lastObject.doubleValue == 2 && bridge.central.connects == 0,
                      @"empty discovery must schedule a bounded retry without pretending connected");
                now += 1; [bridge startAutomaticRecovery];
                check(bridge.central.scans == 1, @"cache-miss retry cooldown must be retained");
                now += 1; deadlines.lastObject();
                check(bridge.central.scans == 2 && bridge.recoveryScanning,
                      @"no-cache recovery must resume discovery after its cooldown");
            } else {
                [bridge didScanPeripherals:@[other, match]];
                check(immediate.count == 1 && bridge.central.connects == 0,
                      @"synchronous scan publication must defer connection until scan setup returns");
                if ([scenario isEqual:@"cache-miss-owner-cancel"]) {
                    bridge.recoveryTargetID = @""; bridge.recoveryContext = @""; [bridge finishScan];
                } else if ([scenario isEqual:@"cache-miss-target-change"]) {
                    bridge.recoveryTargetID = other.peripheral.identifier.UUIDString;
                    bridge.recoveryContext = @"synthetic:owner-b";
                } else if ([scenario isEqual:@"cache-miss-power-off"]) {
                    bridge.central.bleState = QCBluetoothStatePoweredOff;
                    [bridge didBluetoothState:QCBluetoothStatePoweredOff];
                }
                immediate[0]();
                if ([scenario isEqual:@"cache-miss-discovery"]) {
                    check(bridge.central.connects == 1 && bridge.central.connectedPeripheral == target &&
                          bridge.recoveryConnecting && !bridge.recoveryScanning && !bridge.central.isScanning,
                          @"exact discovered UUID must stop scan and enter one real pending request");
                    [bridge didScanPeripherals:@[match]];
                    check(bridge.central.connects == 1, @"late discovery cannot repeat a connection");
                    check([bridge.recoveryContext isEqual:@"synthetic:owner-a"] && bridge.central.bound,
                          @"cache fallback preserves binding and exact owner");
                } else {
                    check(bridge.central.connects == 0,
                          @"cancelled owner, changed target or radio loss must reject deferred discovery");
                }
            }
        }
    } else if ([scenario isEqual:@"power-state-recovery"]) {
        for (NSNumber *state in @[@(CBManagerStatePoweredOff), @(CBManagerStateResetting)]) {
            for (NSNumber *pending in @[@NO, @YES]) {
            bridge = make(); if (pending.boolValue) beginRecovery(bridge);
            NSString *target = bridge.recoveryTargetID, *owner = bridge.recoveryContext;
            CBPeripheral *retired = bridge.central.connectedPeripheral;
            bridge.central.centerManager.state = state.integerValue;
            [bridge.central centralManagerDidUpdateState:bridge.central.centerManager];
            check(bridge.central.connectedPeripheral == nil && !bridge.recoveryConnecting && bridge.connectedID.length == 0,
                  @"radio loss must retire stale transport even without disconnect callback");
            check(bridge.central.centerManager.cancellations == 1, @"radio loss must cancel pending transport");
            [bridge.central centralManagerDidUpdateState:bridge.central.centerManager];
            check(bridge.central.centerManager.cancellations == 1, @"duplicate radio state must not cancel twice");
            CBPeripheral *fresh = peripheral(target); fresh.state = CBPeripheralStateDisconnected;
            bridge.central.centerManager.available = fresh;
            bridge.central.centerManager.state = CBManagerStatePoweredOn;
            [bridge.central centralManagerDidUpdateState:bridge.central.centerManager];
            if (pending.boolValue) {
                check(bridge.central.connects == 0 && deadlines.count == 1,
                      @"interrupted handshake must keep its recovery cooldown");
                now = 102; deadlines[0]();
            }
            check(bridge.central.connects == 1 && bridge.central.connectedPeripheral == fresh,
                  @"power return must request one fresh exact-UUID transport");
            NSUInteger generation = bridge.connectionGeneration;
            retired.state = CBPeripheralStateConnected;
            [bridge.central centralManager:bridge.central.centerManager didConnectPeripheral:retired];
            check(bridge.central.connectedPeripheral == fresh && registrationResult == nil,
                  @"late old connect must not register stale transport");
            retired.state = CBPeripheralStateDisconnected;
            [bridge.central centralManager:bridge.central.centerManager didDisconnectPeripheral:retired error:failure()];
            check(bridge.connectionGeneration == generation && bridge.central.connects == 1,
                  @"late old callback must not retire fresh recovery");
            check([bridge.recoveryTargetID isEqual:target] && [bridge.recoveryContext isEqual:owner] && bridge.central.bound, @"power state changes must preserve exact owner and binding");
            printf("Power state %ld pending=%s: attempts=%lu targetPreserved=YES (synthetic callbacks)\n", (long)state.integerValue, pending.boolValue ? "YES" : "NO", (unsigned long)bridge.central.connects);
            }
        }
        bridge = make(); beginRecovery(bridge);
        bridge.central.centerManager.state = CBManagerStatePoweredOff;
        [bridge.central centralManagerDidUpdateState:bridge.central.centerManager];
        bridge.recoveryTargetID = @""; bridge.recoveryContext = @"";
        bridge.central.centerManager.state = CBManagerStatePoweredOn;
        [bridge.central centralManagerDidUpdateState:bridge.central.centerManager];
        now = 102; for (QRingNext deadline in deadlines) deadline();
        check(bridge.central.connects == 0, @"revoked owner must never restart recovery");
        bridge = make(); bridge.central.bound = NO;
        CBPeripheral *orphan = bridge.central.connectedPeripheral;
        bridge.central.centerManager.state = CBManagerStatePoweredOff;
        [bridge.central centralManagerDidUpdateState:bridge.central.centerManager];
        NSUInteger removals = sdkRemovalCalls;
        orphan.state = CBPeripheralStateDisconnected;
        [bridge.central centralManager:bridge.central.centerManager didDisconnectPeripheral:orphan error:failure()];
        check(bridge.central.connectedPeripheral == nil && bridge.central.deviceState == QCStateUnbind &&
              sdkRemovalCalls == removals, @"late disconnect after radio loss and unbind must not reset SDK again");
    } else { check(NO, @"unknown scenario"); }
    printf("QRing recovery %s: %lu assertions passed (synthetic callbacks, not device timing)\n", scenario.UTF8String, (unsigned long)checked);
} return 0; }
