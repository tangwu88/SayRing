#import <Foundation/Foundation.h>
#import "ios/Runner/CoolWearRecovery.h"

// 这里只替换 CoreBluetooth/Flutter 及 SDK I/O。恢复、状态处理和取消完成判定
// 从生产 .m 提取后编译；不把宿主夹具冒充真实手机或真实 SDK 的无线验收。
typedef NS_ENUM(NSInteger, CBPeripheralState) {
    CBPeripheralStateDisconnected, CBPeripheralStateConnecting,
    CBPeripheralStateConnected, CBPeripheralStateDisconnecting
};
typedef NS_ENUM(NSInteger, CBManagerState) { CBManagerStatePoweredOff = 4, CBManagerStatePoweredOn = 5 };
typedef NS_ENUM(NSInteger, ProductStatus) {
    ProductStatus_none, ProductStatus_powerOff, ProductStatus_searching,
    ProductStatus_connecting, ProductStatus_disconnected, ProductStatus_connected,
    ProductStatus_completed
};
typedef void (^FlutterResult)(id);
@interface FlutterError : NSObject
@end
@implementation FlutterError
@end
@interface FlutterMethodCall : NSObject
@property(nonatomic, copy) NSString *method;
+ (instancetype)methodCallWithMethodName:(NSString *)name arguments:(id)arguments;
@end
@implementation FlutterMethodCall
+ (instancetype)methodCallWithMethodName:(NSString *)name arguments:(id)arguments {
    (void)arguments; FlutterMethodCall *call = [self new]; call.method = name; return call;
}
@end
@interface CBPeripheral : NSObject
@property(nonatomic) CBPeripheralState state;
@end
@implementation CBPeripheral
@end
@interface CEConnector : NSObject
@property(nonatomic, strong) CBPeripheral *peripheral;
@end
@implementation CEConnector
@end
@interface CE_Cmd : NSObject
@property(nonatomic) NSInteger overtime;
@property(nonatomic) NSInteger repeatSendTimes;
@end
@implementation CE_Cmd
@end
@interface CE_SyncTimeCmd : CE_Cmd
- (instancetype)initWithAbsTime:(double)time offset:(NSInteger)offset format:(int)format mdFormat:(int)mdFormat;
@end
@implementation CE_SyncTimeCmd
- (instancetype)initWithAbsTime:(double)time offset:(NSInteger)offset format:(int)format mdFormat:(int)mdFormat {
    (void)time; (void)offset; (void)format; (void)mdFormat; return [super init];
}
@end
@interface CE_RequestDevInfoCmd : CE_Cmd
@end
@implementation CE_RequestDevInfoCmd
@end
@interface CE_RequestAllInfoCmd : CE_Cmd
@end
@implementation CE_RequestAllInfoCmd
@end
@interface CE_SensorCmd : NSObject
+ (void)open;
@end
@implementation CE_SensorCmd
+ (void)open {}
@end
@interface CEProductK6 : NSObject {
    NSString *_lastConnectUUId;
}
@property(nonatomic, strong) NSString *lastConnectUUId;
@property(nonatomic, strong) NSString *UUIDStr;
@property(nonatomic) CBManagerState state;
@property(nonatomic) ProductStatus status;
@property(nonatomic, strong) CEConnector *connect;
- (void)sendCmdToDevice:(CE_Cmd *)command complete:(void (^)(NSError *))complete;
@end
@implementation CEProductK6
- (NSString *)lastConnectUUId {
    // 对照原版 f56c3960 SDK：nil 会按类名从 NSUserDefaults 再次加载 UUID；
    // setter 只改内存。因此“属性赋 nil”并不等于停用旧 SDK 自动恢复。
    if (!_lastConnectUUId) {
        NSString *stored = [NSUserDefaults.standardUserDefaults stringForKey:NSStringFromClass(self.class)];
        if (stored.length) _lastConnectUUId = stored;
    }
    return _lastConnectUUId;
}
- (void)setLastConnectUUId:(NSString *)value { _lastConnectUUId = value; }
- (void)sendCmdToDevice:(CE_Cmd *)command complete:(void (^)(NSError *))complete {
    (void)command; (void)complete;
    [NSException raise:@"UnexpectedIO" format:@"Recovery must not send setting or measurement commands"];
}
@end

static NSMutableArray<dispatch_block_t> *scheduled;
static void CWAfter(dispatch_time_t time, dispatch_queue_t queue, dispatch_block_t block) {
    (void)time; (void)queue; [scheduled addObject:[block copy]];
}
#define dispatch_after CWAfter
static void CoolWearOnMain(dispatch_block_t block) { block(); }

@interface CoolWearWearableBridge : NSObject
@property(nonatomic, strong) CEProductK6 *product;
@property(nonatomic, strong) CBPeripheral *target;
@property(nonatomic, copy) NSString *targetName;
@property(nonatomic) BOOL cancelling;
@property(nonatomic) BOOL awaitingInfo;
@property(nonatomic) NSUInteger cancellationChecks;
@property(nonatomic) NSUInteger connectionGeneration;
@property(nonatomic) NSUInteger recoveryGeneration;
@property(nonatomic, copy) NSString *recoveryID;
@property(nonatomic, copy) NSString *recoveryName;
@property(nonatomic, copy) NSString *recoveryContext;
@property(nonatomic) BOOL recoveryScanning;
@property(nonatomic) BOOL recoveryConnecting;
@property(nonatomic, copy) FlutterResult pendingConnect;
@property(nonatomic, copy) FlutterResult pendingDisconnect;
@property(nonatomic, copy) FlutterResult pendingScan;
@property(nonatomic) BOOL resolved;
@property(nonatomic) NSUInteger cancellations;
@property(nonatomic) NSUInteger searches;
@property(nonatomic) NSUInteger recoverySchedules;
@property(nonatomic) NSUInteger disconnectedEvents;
@property(nonatomic) BOOL holdSDKPeripheral;
- (void)disableVendorRecovery;
- (void)receiveStatus:(ProductStatus)status;
- (void)attemptRecovery:(NSUInteger)generation;
- (void)checkCancellation;
- (void)failConnection:(NSString *)code message:(NSString *)message;
- (FlutterError *)error:(NSString *)code message:(NSString *)message;
- (void)connectionNote:(NSString *)cause appInitiated:(BOOL)app;
- (void)emit:(NSString *)type payload:(NSDictionary *)payload;
- (BOOL)isResolved;
- (BOOL)matchesTarget;
- (void)scheduleRecovery;
- (void)beginCancellation:(FlutterResult)result;
- (void)handle:(FlutterMethodCall *)call result:(FlutterResult)result;
@end
@implementation CoolWearWearableBridge
// PRODUCTION_RECOVERY_METHODS
- (FlutterError *)error:(NSString *)code message:(NSString *)message { (void)code; (void)message; return [FlutterError new]; }
- (void)connectionNote:(NSString *)cause appInitiated:(BOOL)app { (void)cause; (void)app; }
- (void)emit:(NSString *)type payload:(NSDictionary *)payload {
    (void)payload; if ([type isEqual:@"disconnected"]) self.disconnectedEvents++;
}
- (BOOL)isResolved { return self.resolved; }
- (BOOL)matchesTarget { return self.resolved; }
- (void)scheduleRecovery { self.recoverySchedules++; }
- (void)beginCancellation:(FlutterResult)result {
    (void)result; self.cancellations++; self.cancelling = YES;
    if (!self.holdSDKPeripheral) self.product.connect.peripheral = nil;
    [self checkCancellation];
}
- (void)handle:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqual:@"scanDevices"]) { self.searches++; result(@[]); }
    else [NSException raise:@"UnexpectedIO" format:@"No candidate should be invented"];
}
@end

static void Require(BOOL condition, NSString *message) {
    if (!condition) [NSException raise:@"TestFailure" format:@"%@", message];
}
static CoolWearWearableBridge *Session(CBPeripheralState state) {
    CoolWearWearableBridge *bridge = [CoolWearWearableBridge new];
    bridge.product = [CEProductK6 new]; bridge.product.state = CBManagerStatePoweredOn;
    bridge.product.connect = [CEConnector new];
    bridge.target = [CBPeripheral new]; bridge.target.state = state;
    bridge.product.connect.peripheral = bridge.target;
    bridge.recoveryID = @"10000000-0000-4000-8000-000000000001";
    bridge.recoveryName = @"HR05"; bridge.recoveryContext = @"test:owner";
    bridge.recoveryGeneration = 7; return bridge;
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        (void)argc; scheduled = [NSMutableArray array];
        NSString *scenario = @(argv[1]);
        NSString *cacheKey = NSStringFromClass(CEProductK6.class);
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        [defaults removeObjectForKey:cacheKey];
        CoolWearWearableBridge *b = Session(CBPeripheralStateDisconnected);
        if ([scenario isEqual:@"legacy-cache"]) {
            [defaults setObject:@"10000000-0000-4000-8000-000000000002" forKey:cacheKey];
            [defaults setObject:@"preserved" forKey:@"test-health-and-binding-data"];
            b.product.UUIDStr = @"10000000-0000-4000-8000-000000000002";
            [b disableVendorRecovery];
            Require(b.product.lastConnectUUId == nil, @"nil setter revived legacy SDK recovery target");
            Require(b.product.UUIDStr == nil, @"SDK UUID still armed");
            Require([[defaults stringForKey:@"test-health-and-binding-data"] isEqual:@"preserved"], @"Unrelated account data changed");
            Require([b.recoveryName isEqual:@"HR05"] && b.recoveryID.length > 0, @"Owner-scoped binding changed");
            [defaults removeObjectForKey:@"test-health-and-binding-data"];
        } else if ([scenario isEqual:@"none-disconnected"]) {
            [b receiveStatus:ProductStatus_none];
            Require(b.cancellations == 1 && !b.target && b.disconnectedEvents == 1 && b.recoverySchedules == 1,
                @"SDK none left the physically disconnected target blocking recovery");
            [b attemptRecovery:7]; Require(b.searches == 1, @"Recovery did not resume");
        } else if ([scenario isEqual:@"none-connected"] || [scenario isEqual:@"none-connecting"]) {
            b.target.state = [scenario isEqual:@"none-connected"] ? CBPeripheralStateConnected : CBPeripheralStateConnecting;
            [b receiveStatus:ProductStatus_none];
            Require(b.cancellations == 0 && b.target != nil, @"An idle status alone cancelled a live/pending link");
        } else if ([scenario isEqual:@"lost-status"]) {
            [b attemptRecovery:7];
            Require(b.cancellations == 1 && !b.target, @"Physically closed stale target blocked recovery forever");
            [b attemptRecovery:7]; Require(b.searches == 1, @"Backstop never resumed exact-target search");
        } else if ([scenario isEqual:@"handshake-pending"]) {
            b.pendingConnect = ^(id value) { (void)value; };
            [b attemptRecovery:7];
            Require(b.cancellations == 0 && b.searches == 0 && b.pendingConnect != nil, @"Retry interrupted handshake");
        } else if ([scenario isEqual:@"cancellation-barrier"]) {
            b.holdSDKPeripheral = YES;
            b.product.connect.peripheral = [CBPeripheral new]; b.product.connect.peripheral.state = CBPeripheralStateConnected;
            [b receiveStatus:ProductStatus_none]; [b attemptRecovery:7];
            Require(b.cancelling && b.target != nil && b.searches == 0, @"Unconfirmed SDK cancellation opened another connection");
        } else if ([scenario isEqual:@"settled-cancellation"]) {
            b.cancelling = YES; b.cancellationChecks = 49; b.product.connect.peripheral = nil;
            [b attemptRecovery:7];
            Require(!b.cancelling && b.target == nil && b.disconnectedEvents == 1, @"Late physical close kept recovery blocked");
            [b attemptRecovery:7]; Require(b.searches == 1, @"Settled cancellation did not resume recovery");
        } else if ([scenario isEqual:@"generation"]) {
            [b attemptRecovery:6]; Require(b.cancellations == 0 && b.searches == 0, @"Stale timer changed current session");
        } else if ([scenario isEqual:@"unconfigured"]) {
            b.recoveryID = nil; [b attemptRecovery:7];
            Require(b.cancellations == 0 && b.searches == 0, @"Revoked recovery still acted");
        } else if ([scenario isEqual:@"healthy"]) {
            b.target.state = CBPeripheralStateConnected; b.resolved = YES; [b attemptRecovery:7];
            Require(b.cancellations == 0 && b.searches == 0, @"Healthy link was disturbed");
        } else if ([scenario isEqual:@"stale-ended-status"]) {
            for (NSNumber *status in @[@(ProductStatus_disconnected), @(ProductStatus_powerOff)]) {
                b = Session(CBPeripheralStateConnected); b.product.status = ProductStatus_completed; b.resolved = YES;
                [b receiveStatus:status.integerValue];
                Require(b.cancellations == 0 && b.target != nil && b.disconnectedEvents == 0 && b.recoverySchedules == 0,
                    @"Delayed ended notification cancelled the already verified live connection");
            }
        } else if ([scenario isEqual:@"sdk-ended-live-peripheral"]) {
            b = Session(CBPeripheralStateConnected); b.product.status = ProductStatus_disconnected; b.resolved = NO;
            b.holdSDKPeripheral = YES; [b receiveStatus:ProductStatus_disconnected];
            Require(b.cancelling && b.cancellations == 1 && b.target != nil && b.searches == 0,
                @"A current SDK disconnect was ignored or physical-close barrier was bypassed");
        } else if ([scenario isEqual:@"radio-off-live-peripheral"]) {
            b = Session(CBPeripheralStateConnected); b.product.status = ProductStatus_completed; b.resolved = YES;
            b.product.state = CBManagerStatePoweredOff; b.holdSDKPeripheral = YES;
            [b receiveStatus:ProductStatus_powerOff];
            Require(b.cancelling && b.cancellations == 1, @"Actual Bluetooth power off was ignored");
        } else if ([scenario isEqual:@"ordinary-disconnect"]) {
            for (NSNumber *status in @[@(ProductStatus_disconnected), @(ProductStatus_powerOff)]) {
                b = Session(CBPeripheralStateDisconnected); [b receiveStatus:status.integerValue];
                Require(b.cancellations == 1 && b.target == nil && b.recoverySchedules == 1, @"Existing disconnect path regressed");
            }
        } else Require(NO, @"Unknown scenario");
        [defaults removeObjectForKey:cacheKey];
        puts("PASS");
    }
    return 0;
}
