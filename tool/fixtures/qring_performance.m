#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

// Production method bodies are injected by the Node runner. SDK callbacks and
// deadlines below are synthetic; this is not a CoreBluetooth/device benchmark.
typedef void (^QRingNext)(void);
static void QRingOnMain(QRingNext block) { block(); }
static void RingControlTrace(__unused NSString *stage, __unused NSDictionary *metadata) {}
static NSUInteger checked, batteryCalls, firmwareCalls;
static void (^batterySuccess)(int, BOOL);
static QRingNext batteryFailure, firmwareFailure;
static void (^firmwareSuccess)(NSString *, NSString *);
static NSMutableArray<QRingNext> *deadlines;
static NSMutableArray<QRingNext> *immediate;
static void check(BOOL value) { checked++; if (!value) { fputs("Synthetic performance assertion failed\n", stderr); exit(1); } }
static void queueDeadline(__unused dispatch_time_t when, __unused dispatch_queue_t queue, dispatch_block_t block) { [deadlines addObject:[block copy]]; }
static void queueImmediate(__unused dispatch_queue_t queue, dispatch_block_t block) { [immediate addObject:[block copy]]; }
#define dispatch_after queueDeadline
#define dispatch_async queueImmediate

@interface QCSDKCmdCreator : NSObject
+ (void)readBatterySuccess:(void (^)(int, BOOL))success failed:(QRingNext)failure;
+ (void)getDeviceSoftAndHardVersionSuccess:(void (^)(NSString *, NSString *))success fail:(QRingNext)failure;
@end
@implementation QCSDKCmdCreator
+ (void)readBatterySuccess:(void (^)(int, BOOL))success failed:(QRingNext)failure {
    batteryCalls++; batterySuccess = success; batteryFailure = failure;
}
+ (void)getDeviceSoftAndHardVersionSuccess:(void (^)(NSString *, NSString *))success fail:(QRingNext)failure {
    firmwareCalls++; firmwareSuccess = success; firmwareFailure = failure;
}
@end

@interface SyntheticBridge : NSObject
@property(nonatomic) NSUInteger connectionGeneration;
@property(nonatomic) BOOL live;
@property(nonatomic) BOOL readingDetails;
@property(nonatomic) NSTimeInterval recoveryRetryNotBefore;
@property(nonatomic) NSUInteger recoveryCalls;
@property(nonatomic, copy) NSString *firmware;
@property(nonatomic, strong) NSNumber *battery;
@property(nonatomic, strong) NSNumber *charging;
@property(nonatomic, strong) NSDate *batteryUpdatedAt;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *syncRecords;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *events;
- (BOOL)isCurrentConnection:(NSUInteger)generation;
- (void)emit:(NSString *)type payload:(NSDictionary *)payload;
- (void)readDeviceDetailsWithCompletion:(QRingNext)completion;
- (void)publishCurrentActivityFromIndex:(NSUInteger)firstRecord;
- (void)scheduleRecoveryAfterDisconnect;
- (void)startAutomaticRecovery;
@end
@implementation SyntheticBridge
- (BOOL)isCurrentConnection:(NSUInteger)generation { return self.live && generation == self.connectionGeneration; }
- (void)emit:(NSString *)type payload:(NSDictionary *)payload { check([type isEqual:@"healthRecord"]); [self.events addObject:payload]; }
- (void)startAutomaticRecovery { self.recoveryCalls++; }
// ACTUAL_PERFORMANCE_METHODS
@end

static SyntheticBridge *make(void) {
    batteryCalls = 0; firmwareCalls = 0;
    batterySuccess = nil; batteryFailure = nil; firmwareSuccess = nil; firmwareFailure = nil;
    deadlines = [NSMutableArray new]; immediate = [NSMutableArray new];
    SyntheticBridge *bridge = [SyntheticBridge new];
    bridge.live = YES; bridge.connectionGeneration = 1; bridge.firmware = @"";
    bridge.syncRecords = [NSMutableArray new]; bridge.events = [NSMutableArray new];
    return bridge;
}
static NSDictionary *record(NSString *metric, NSString *date, NSNumber *value) {
    return @{@"type": metric, @"measuredAt": date, @"values": @{@"value": value}, @"id": [metric stringByAppendingString:date]};
}

int main(void) { @autoreleasepool {
    SyntheticBridge *bridge = make();
    [bridge scheduleRecoveryAfterDisconnect];
    check(immediate.count == 1 && deadlines.count == 0 && bridge.recoveryCalls == 0);
    immediate[0](); check(bridge.recoveryCalls == 1);
    bridge = make();
    [bridge scheduleRecoveryAfterDisconnect]; bridge.connectionGeneration++;
    immediate[0](); check(bridge.recoveryCalls == 0);
    bridge = make(); bridge.recoveryRetryNotBefore = NSProcessInfo.processInfo.systemUptime + 2;
    [bridge scheduleRecoveryAfterDisconnect];
    check(immediate.count == 0 && deadlines.count == 1 && bridge.recoveryCalls == 0);
    bridge.recoveryRetryNotBefore = 0; deadlines[0](); check(bridge.recoveryCalls == 1);
    bridge = make(); bridge.recoveryRetryNotBefore = NSProcessInfo.processInfo.systemUptime + 2;
    [bridge scheduleRecoveryAfterDisconnect]; bridge.connectionGeneration++;
    deadlines[0](); check(bridge.recoveryCalls == 0);
    bridge = make();
    __block NSUInteger completed = 0;
    QRingNext finish = ^{ completed++; };
    [bridge readDeviceDetailsWithCompletion:finish];
    check(bridge.readingDetails && completed == 0 && batteryCalls == 1 && firmwareCalls == 0);
    batterySuccess(60, NO);
    check(completed == 0 && firmwareCalls == 1 && [bridge.battery isEqual:@60]);
    firmwareSuccess(@"hardware", @"synthetic-firmware");
    check(completed == 1 && !bridge.readingDetails && [bridge.firmware isEqual:@"synthetic-firmware"]);
    deadlines[0](); check(completed == 1);
    [bridge readDeviceDetailsWithCompletion:finish];
    batterySuccess(61, YES);
    check(completed == 2 && firmwareCalls == 1 && batteryCalls == 2);
    check([bridge.battery isEqual:@61] && [bridge.charging isEqual:@YES] && bridge.batteryUpdatedAt != nil);
    // A new connection clears firmware in the real disconnect handler.
    bridge.connectionGeneration++; bridge.firmware = @"";
    [bridge readDeviceDetailsWithCompletion:finish]; batterySuccess(62, NO);
    check(firmwareCalls == 2); firmwareSuccess(@"hardware", @"new-firmware");
    check(completed == 3 && [bridge.firmware isEqual:@"new-firmware"]);

    bridge = make(); completed = 0;
    [bridge readDeviceDetailsWithCompletion:finish]; batteryFailure();
    check(firmwareCalls == 1 && bridge.battery == nil);
    firmwareFailure(); check(completed == 1 && bridge.firmware.length == 0);
    [bridge readDeviceDetailsWithCompletion:finish]; batterySuccess(50, NO);
    check(firmwareCalls == 2); deadlines[1]();
    firmwareSuccess(@"hardware", @"too-late");
    check(completed == 2 && bridge.firmware.length == 0 && !bridge.readingDetails);

    bridge = make(); completed = 0;
    [bridge readDeviceDetailsWithCompletion:finish];
    bridge.connectionGeneration++; bridge.readingDetails = YES;
    batterySuccess(99, NO); deadlines[0]();
    check(completed == 1 && bridge.battery == nil && bridge.firmware.length == 0 && bridge.readingDetails);
    bridge = make(); completed = 0;
    [bridge readDeviceDetailsWithCompletion:finish]; bridge.live = NO;
    batterySuccess(99, NO);
    check(completed == 1 && bridge.battery == nil && firmwareCalls == 0);

    bridge = make();
    [bridge.syncRecords addObject:record(@"steps", @"2026-10-19T11:00:00.000Z", @1000)];
    [bridge.syncRecords addObjectsFromArray:@[
        record(@"steps", @"2026-10-20T02:00:00.000Z", @50),
        record(@"distance", @"2026-10-20T02:00:00.000Z", @0.1),
        record(@"steps", @"2026-10-20T03:00:00.000Z", @100),
        record(@"calories", @"2026-10-20T03:00:00.000Z", @10),
        record(@"sleep", @"2026-10-20T03:00:00.000Z", @6),
        record(@"heart_rate", @"2026-10-20T03:00:00.000Z", @60),
        record(@"steps", @"2026-10-20T01:00:00.000Z", @30)
    ]];
    NSArray *before = bridge.syncRecords.copy;
    [bridge publishCurrentActivityFromIndex:1];
    check(bridge.events.count == 3 && [bridge.syncRecords isEqual:before]);
    for (NSDictionary *event in bridge.events) {
        check([@[@"steps", @"distance", @"calories"] containsObject:event[@"type"]]);
        check([bridge.syncRecords containsObject:event]);
        if ([event[@"type"] isEqual:@"steps"]) check([event[@"values"][@"value"] isEqual:@100]);
    }
    [bridge.events removeAllObjects];
    [bridge publishCurrentActivityFromIndex:bridge.syncRecords.count];
    [bridge publishCurrentActivityFromIndex:bridge.syncRecords.count + 1];
    check(bridge.events.count == 0 && [bridge.syncRecords isEqual:before]);
    bridge.live = NO;
    [bridge publishCurrentActivityFromIndex:1];
    check(bridge.events.count == 0);
    puts([[NSString stringWithFormat:@"QRing actual performance methods: %lu assertions passed (synthetic SDK, not hardware timing)", (unsigned long)checked] UTF8String]);
} return 0; }
