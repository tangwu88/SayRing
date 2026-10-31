#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
typedef void (^QRingNext)(void);
typedef void (^FlutterResult)(id);
static NSString *const QCBandFeatureGestureControl = @"gesture";
static NSString *const QCBandFeatureTouchControl = @"touch";
static NSString *const QCBandFeatureGestureControlMusic = @"music";
static NSString *const QCBandFeatureGestureControlTakePhoto = @"photo";
static NSUInteger checks, extendedReads;
static NSMutableArray<QRingNext> *queued;
static void (^timeSuccess)(NSDictionary *);
static void (^extendedSuccess)(NSDictionary *);
static QRingNext extendedFailure;
static void check(BOOL ok) { checks++; if (!ok) { fprintf(stderr,"Capability fallback assertion failed at %lu\n",(unsigned long)checks); exit(1); } }
static void QRingOnMain(QRingNext block) { block(); }
static void RingControlTrace(__unused NSString *phase, __unused NSDictionary *data) {}
static void __attribute__((unused)) queue(__unused dispatch_queue_t q, dispatch_block_t block) { [queued addObject:[block copy]]; }
static dispatch_time_t syntheticTime(__unused dispatch_time_t t, int64_t delta) { return delta; }
#define dispatch_time syntheticTime
static void later(dispatch_time_t t, __unused dispatch_queue_t q, dispatch_block_t block) { if (t < 5 * NSEC_PER_SEC) [queued addObject:[block copy]]; }
#define dispatch_async queue
#define dispatch_after later
static void drain(void) { while (queued.count) { QRingNext b=queued.firstObject; [queued removeObjectAtIndex:0]; b(); } }
@interface QCSDKCmdCreator:NSObject
+ (void)setTime:(NSDate *)date success:(void (^)(NSDictionary *))success failed:(QRingNext)fail;
+ (void)getDeviceFeatureConfigSuccess:(void (^)(NSDictionary *))success fail:(QRingNext)fail;
@end
@implementation QCSDKCmdCreator
+ (void)setTime:(__unused NSDate *)date success:(void (^)(NSDictionary *))success failed:(__unused QRingNext)fail { timeSuccess=success; }
+ (void)getDeviceFeatureConfigSuccess:(void (^)(NSDictionary *))success fail:(QRingNext)fail { extendedReads++; extendedSuccess=success; extendedFailure=fail; }
@end
@interface Peripheral:NSObject
@property(nonatomic,strong) NSUUID *identifier;
@end
@implementation Peripheral
@end
@interface Central:NSObject
@property(nonatomic,strong) Peripheral *connectedPeripheral;
@property(nonatomic) NSUInteger disconnectCalls;
- (void)disconnect;
@end
@implementation Central
- (void)disconnect { self.disconnectCalls++; }
@end
@interface Bridge:NSObject
@property(nonatomic,strong) Central *central;
@property(nonatomic,copy) NSString *connectedID;
@property(nonatomic) NSUInteger connectionGeneration;
@property(nonatomic) NSUInteger connectDeadlineGeneration;
@property(nonatomic) BOOL live;
@property(nonatomic) BOOL recoveryConnecting;
@property(nonatomic,copy) FlutterResult pendingConnect;
@property(nonatomic,copy) NSDictionary *featureList;
@property(nonatomic) NSUInteger profileCalls, detailCalls, probeCalls, readyCalls, failedCalls;
@property(nonatomic,strong) NSMutableArray *events;
- (void)resolveCapabilities;
- (BOOL)isCurrentConnection:(NSUInteger)generation;
- (void)failConnect:(NSString *)code message:(NSString *)message;
- (void)writeProfileWithCompletion:(QRingNext)completion;
- (void)readDeviceDetailsWithCompletion:(QRingNext)completion;
- (void)probeRemoteCamera:(QRingNext)completion;
- (void)emit:(NSString *)event payload:(NSDictionary *)payload;
- (NSDictionary *)deviceDetails;
- (NSDictionary *)capabilities;
@end
@interface Bridge (Extended)
- (void)resolveExtendedCapabilities:(NSDictionary *)features generation:(NSUInteger)generation attempt:(NSUInteger)attempt completion:(void (^)(NSDictionary *))completion;
@end
@implementation Bridge
- (BOOL)isCurrentConnection:(NSUInteger)generation { return self.live && generation == self.connectionGeneration; }
- (void)failConnect:(__unused NSString *)code message:(__unused NSString *)message { self.failedCalls++; }
- (void)writeProfileWithCompletion:(QRingNext)completion { self.profileCalls++; completion(); }
- (void)readDeviceDetailsWithCompletion:(QRingNext)completion { self.detailCalls++; completion(); }
- (void)probeRemoteCamera:(QRingNext)completion { self.probeCalls++; completion(); }
- (void)emit:(NSString *)event payload:(__unused NSDictionary *)payload { [self.events addObject:event]; }
- (NSDictionary *)deviceDetails { return @{}; }
- (NSDictionary *)capabilities { return self.featureList; }
// PRODUCTION_METHODS
@end
static Bridge *make(void) {
    queued=[NSMutableArray new]; extendedReads=0; timeSuccess=nil; extendedSuccess=nil; extendedFailure=nil;
    Bridge *b=[Bridge new]; b.live=YES; b.connectedID=@"00000000-0000-0000-0000-000000000001"; b.central=[Central new]; b.central.connectedPeripheral=[Peripheral new]; b.central.connectedPeripheral.identifier=[[NSUUID alloc] initWithUUIDString:b.connectedID]; b.events=[NSMutableArray new];
    __weak Bridge *weak=b; b.pendingConnect=^(__unused id value) { weak.readyCalls++; }; return b;
}
int main(void) { @autoreleasepool {
    Bridge *b=make(); [b resolveCapabilities]; timeSuccess(@{@"heart":@YES});
    check(b.readyCalls==0 && b.profileCalls==0); // partial setTime is not full capability proof
    drain(); check(extendedReads==1); extendedSuccess(@{QCBandFeatureGestureControl:@YES,QCBandFeatureGestureControlMusic:@YES,QCBandFeatureGestureControlTakePhoto:@YES});
    check(b.readyCalls==1 && b.probeCalls==1 && [b.featureList[QCBandFeatureGestureControl] isEqual:@YES] && [b.featureList[@"heart"] isEqual:@YES]);
    drain(); check(b.failedCalls==0 && b.readyCalls==1);
    b=make(); [b resolveCapabilities]; timeSuccess(@{QCBandFeatureGestureControl:@YES,QCBandFeatureGestureControlMusic:@YES});
    check(b.readyCalls==1 && b.probeCalls==1 && extendedReads==0); drain(); check(extendedReads==0);
    b=make(); [b resolveCapabilities]; timeSuccess(@{@"heart":@YES}); drain(); void (^oldSuccess)(NSDictionary *)=extendedSuccess; extendedFailure(); drain(); check(extendedReads==2 && b.readyCalls==0); oldSuccess(@{QCBandFeatureGestureControl:@YES}); check(b.readyCalls==0 && b.featureList==nil); extendedSuccess(@{QCBandFeatureTouchControl:@YES}); check(b.readyCalls==1 && [b.featureList[QCBandFeatureTouchControl] isEqual:@YES]); extendedSuccess(@{QCBandFeatureGestureControl:@YES}); check(b.readyCalls==1 && b.featureList[QCBandFeatureGestureControl]==nil);
    b=make(); [b resolveCapabilities]; timeSuccess(@{@"heart":@YES}); drain(); extendedSuccess(@{}); check(b.readyCalls==1 && b.featureList[QCBandFeatureGestureControl]==nil && b.featureList[QCBandFeatureTouchControl]==nil); drain(); check(extendedReads==1);
    b=make(); [b resolveCapabilities]; timeSuccess(@{@"heart":@YES}); drain(); extendedFailure(); drain(); extendedFailure(); drain(); check(extendedReads==2 && b.readyCalls==1 && b.failedCalls==0 && b.central.disconnectCalls==0 && b.featureList[QCBandFeatureGestureControl]==nil);
    b=make(); [b resolveCapabilities]; timeSuccess(@{@"heart":@YES}); b.connectionGeneration++; drain(); check(extendedReads==0 && b.readyCalls==0 && b.probeCalls==0);
    b=make(); [b resolveCapabilities]; timeSuccess(@{@"heart":@YES}); drain(); b.connectionGeneration++; extendedSuccess(@{QCBandFeatureGestureControl:@YES}); check(b.readyCalls==0 && b.featureList==nil && b.probeCalls==0);
    b=make(); [b resolveCapabilities]; timeSuccess(@{@"heart":@YES}); drain(); b.connectionGeneration++; extendedFailure(); drain(); check(extendedReads==1 && b.readyCalls==0);
    printf("QRing actual capability handshake: %lu assertions passed\n",(unsigned long)checks);
} return 0; }
