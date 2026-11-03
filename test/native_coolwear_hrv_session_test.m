// Host-only transport fixture: the runner inserts the production start/stop
// method and type-60 receive branch. It does not load a vendor BLE SDK.
#import <Foundation/Foundation.h>
#import "ios/Runner/CoolWearPolicy.h"

typedef void (^FlutterResult)(id);
@interface FlutterError : NSObject
@property(nonatomic, copy) NSString *code;
@end
@implementation FlutterError
@end
@interface CE_Cmd : NSObject
@property(nonatomic) int status;
@property(nonatomic) int overtime;
@property(nonatomic) int repeatSendTimes;
@end
@implementation CE_Cmd
@end
@interface CE_SyncRRIHRVCmd : CE_Cmd @end
@implementation CE_SyncRRIHRVCmd @end
@interface CE_SyncHeartRateCmd : CE_Cmd @end
@implementation CE_SyncHeartRateCmd @end
@interface CE_SyncHeartO2Cmd : CE_Cmd @end
@implementation CE_SyncHeartO2Cmd @end

static NSMutableArray<dispatch_block_t> *timers;
static NSMutableArray<dispatch_block_t> *nextTurns;
static void TestAfter(dispatch_time_t time, dispatch_queue_t queue, dispatch_block_t block) {
    (void)time; (void)queue; [timers addObject:[block copy]];
}
#define dispatch_after TestAfter
static BOOL SRManualHealthMetricAllowed(NSString *metric) { return metric.length > 0; }
static void CoolWearOnMain(dispatch_block_t block) { block(); }
static void __attribute__((unused)) CoolWearAfterSDKCallback(dispatch_block_t block) { [nextTurns addObject:[block copy]]; }
static void Drain(void) {
    while (nextTurns.count) { dispatch_block_t block = nextTurns.firstObject; [nextTurns removeObjectAtIndex:0]; block(); }
}
#define DATA_TYPE_REAL_HRV_METRICS 60

@interface FakeProduct : NSObject
@property(nonatomic, strong) NSMutableArray<CE_Cmd *> *commands;
@property(nonatomic, strong) NSMutableArray<void (^)(NSError *)> *callbacks;
- (void)sendCmdToDevice:(CE_Cmd *)command complete:(void (^)(NSError *))callback;
@end
@implementation FakeProduct
- (instancetype)init { if ((self = [super init])) { _commands = [NSMutableArray array]; _callbacks = [NSMutableArray array]; } return self; }
- (void)sendCmdToDevice:(CE_Cmd *)command complete:(void (^)(NSError *))callback { [self.commands addObject:command]; [self.callbacks addObject:[callback copy]]; }
@end

@interface Session : NSObject
@property(nonatomic, strong) FakeProduct *product;
@property(nonatomic, copy) FlutterResult pendingMeasurement;
@property(nonatomic, copy) NSString *activeMetric;
@property(nonatomic, strong) NSDate *measurementStart;
@property(nonatomic, strong) NSDictionary *flags;
@property(nonatomic) NSUInteger measurementGeneration;
@property(nonatomic) NSUInteger connectionGeneration;
@property(nonatomic) BOOL emittedMeasurement;
@property(nonatomic) BOOL measurementAcknowledged;
@property(nonatomic, copy) NSDictionary *pendingHrvRecord;
@property(nonatomic) NSUInteger hrvReceivedPackets;
@property(nonatomic) NSUInteger hrvHistoryPackets;
@property(nonatomic) NSUInteger hrvRejectedSamples;
@property(nonatomic) NSUInteger hrvAcceptedSamples;
@property(nonatomic) BOOL probingReminders;
@property(nonatomic) BOOL pendingReminders;
@property(nonatomic) BOOL pendingControl;
@property(nonatomic) BOOL pendingFind;
@property(nonatomic) BOOL pendingSync;
@property(nonatomic) BOOL pendingBattery;
@property(nonatomic) BOOL pendingMonitoringRead;
@property(nonatomic) BOOL pendingMonitoringWrite;
@property(nonatomic) NSUInteger cancellationCount;
@property(nonatomic, strong) NSMutableArray *events;
- (void)measurement:(NSString *)metric enabled:(BOOL)enabled result:(FlutterResult)result;
- (void)receive:(NSDictionary *)sample type:(NSInteger)rawType generation:(NSUInteger)measurement;
@end
// Optional helpers are absent on the old production source used for red tests.
@interface Session (HrvHelpers)
- (void)hrvDiagnostic:(NSString *)stage type:(NSInteger)type sampleCount:(NSUInteger)sampleCount reason:(NSString *)reason;
- (void)publishPendingHrvRecord:(NSUInteger)generation measurement:(NSUInteger)measurement;
@end
@implementation Session
- (instancetype)init {
    if ((self = [super init])) { _product = [FakeProduct new]; _flags = @{@"hrvSupport":@1}; _events = [NSMutableArray array]; }
    return self;
}
- (BOOL)isResolved { return YES; }
- (FlutterError *)error:(NSString *)code message:(NSString *)message { (void)message; FlutterError *error = [FlutterError new]; error.code = code; return error; }
- (void)beginCancellation:(FlutterResult)result {
    // SDK cancellation itself is outside this fixture. Mirror only the existing
    // production generation invalidation, and count its invocation explicitly.
    self.cancellationCount++; self.connectionGeneration++; self.measurementGeneration++;
    self.activeMetric = nil; self.pendingHrvRecord = nil; self.measurementAcknowledged = NO;
    FlutterResult pending = self.pendingMeasurement; self.pendingMeasurement = nil;
    if (pending) pending([self error:@"MEASUREMENT_CANCELLED" message:@""]);
    if (result) result(nil);
}
- (NSDictionary *)record:(NSString *)metric values:(NSDictionary *)values date:(NSDate *)date origin:(NSString *)origin {
    return @{@"type":metric,@"values":values,@"date":date,@"origin":origin};
}
- (void)emit:(NSString *)type payload:(NSDictionary *)payload { [self.events addObject:@{@"type":type,@"payload":payload}]; }
// PRODUCTION_MEASUREMENT
// PRODUCTION_HRV_HELPERS
- (void)receive:(NSDictionary *)sample type:(NSInteger)rawType generation:(NSUInteger)measurement {
    NSNumber *type = @(rawType);
    id data = @{@"curItemCount":@1,@"hrvMetricsInfos":@[sample]};
    // PRODUCTION_HRV_RECEIVE
}
@end

static NSDictionary *Sample(Session *session) {
    return @{@"time":@(floor(session.measurementStart.timeIntervalSince1970)),@"meanRR":@800,
        @"sdnn":@42,@"rmssd":@35,@"pnn50":@0,@"meanHR":@75,@"validCount":@80,
        @"rejectedCount":@0,@"quality":@3,@"flags":@0};
}
static void Require(BOOL okay, NSString *reason) { if (!okay) { fprintf(stderr, "%s\n", reason.UTF8String); exit(1); } }
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        Require(argc == 2, @"scenario required");
        NSString *scenario = @(argv[1]);
        timers = [NSMutableArray array]; nextTurns = [NSMutableArray array];
        Session *s = [Session new];
        __block NSUInteger completions = 0; __block id lastResult;
        FlutterResult result = ^(id value) { completions++; lastResult = value; };
        [s measurement:@"hrv" enabled:YES result:result];
        void (^startAck)(NSError *) = s.product.callbacks[0];
        NSUInteger first = s.measurementGeneration;
        NSDictionary *sample = Sample(s);
        if ([scenario hasPrefix:@"early-"]) {
            [s receive:sample type:60 generation:first];
            Require(s.events.count == 0, @"valid result was emitted before start ACK");
            if ([scenario isEqual:@"early-result"]) {
                startAck(nil); Drain();
                Require(completions == 1 && !lastResult && s.events.count == 1, @"ACK did not release exactly one held result");
                Require(s.cancellationCount == 0, @"successful early result disconnected the ring");
            } else if ([scenario isEqual:@"early-failure"]) {
                startAck([NSError errorWithDomain:@"fixture" code:1 userInfo:nil]); Drain();
                Require(completions == 1 && [lastResult isKindOfClass:FlutterError.class] && !s.activeMetric && !s.events.count && !s.pendingHrvRecord, @"failed start published or retained a result");
            } else {
                timers[0](); Require(s.cancellationCount == 1, @"ACK timeout did not retain normal cancellation barrier");
                [s measurement:@"hrv" enabled:YES result:result];
                NSUInteger next = s.measurementGeneration;
                startAck(nil); Drain();
                Require(completions == 1 && s.measurementGeneration == next && s.pendingMeasurement && s.events.count == 0, @"late timed-out ACK changed new measurement");
            }
        } else if ([scenario isEqual:@"queued-restart"]) {
            [s receive:sample type:60 generation:first]; startAck(nil);
            [s measurement:@"hrv" enabled:NO result:^(id value) { (void)value; }];
            s.product.callbacks[1](nil);
            [s measurement:@"hrv" enabled:YES result:result];
            Drain();
            Require(s.events.count == 0 && s.pendingMeasurement, @"queued old result completed the new measurement");
        } else if ([scenario isEqual:@"disconnect-result"]) {
            [s receive:sample type:60 generation:first];
            [s beginCancellation:nil];
            [s measurement:@"hrv" enabled:YES result:result];
            startAck(nil); Drain();
            Require(s.events.count == 0 && s.pendingMeasurement && !s.pendingHrvRecord, @"disconnected result or ACK escaped its generation");
        } else if ([scenario isEqual:@"cancel-new-round"]) {
            [s measurement:@"hrv" enabled:NO result:^(id value) { (void)value; }];
            [s measurement:@"hrv" enabled:YES result:result];
            NSUInteger next = s.measurementGeneration;
            startAck(nil); Drain();
            [s receive:sample type:60 generation:first];
            Require(s.cancellationCount == 1 && s.measurementGeneration == next && s.pendingMeasurement && s.events.count == 0, @"old cancelled callback changed new round");
        } else {
            startAck(nil);
            if ([scenario isEqual:@"invalid-result"]) {
                NSMutableDictionary *invalid = [sample mutableCopy]; invalid[@"quality"] = @0;
                [s receive:invalid type:60 generation:first];
                invalid = [sample mutableCopy]; invalid[@"validCount"] = @1;
                [s receive:invalid type:60 generation:first];
                [s receive:sample type:61 generation:first];
                [s receive:sample type:60 generation:first + 1]; Drain();
                Require(!s.events.count && !s.emittedMeasurement && [s.activeMetric isEqual:@"hrv"], @"invalid/history/stale result completed HRV");
            } else {
                [s receive:sample type:60 generation:first]; Drain();
                [s receive:sample type:60 generation:first]; Drain();
                Require(s.events.count == 1 && completions == 1 && !lastResult, @"valid result lost or emitted twice");
                if ([scenario isEqual:@"stop-after-result"]) {
                    [s measurement:@"hrv" enabled:NO result:result]; s.product.callbacks[1](nil);
                    Require(!s.activeMetric && !s.pendingMeasurement && !s.cancellationCount && s.product.commands[1].status == 0, @"normal stop did not preserve the connection");
                }
            }
        }
        puts("PASS synthetic iOS HRV session; no real BLE or health data");
    }
    return 0;
}
