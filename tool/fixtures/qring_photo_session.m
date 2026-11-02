#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
typedef void (^QRingNext)(void);
typedef void (^FlutterResult)(id);
static NSString *const QCBandFeatureGestureControl = @"gesture";
static NSString *const QCBandFeatureTouchControl = @"touch";
static NSMutableArray<QRingNext> *queued, *timers;
static QRingNext enterSuccess, enterFail, holdSuccess, holdFail, exitSuccess, exitFail;
static NSUInteger enterCalls, exitCalls, checks;
static BOOL callbacksBeforeEnter;
static void check(BOOL value) { checks++; if (!value) { fprintf(stderr,"Photo session assertion failed at %lu\n",(unsigned long)checks); exit(1); } }
static void RingControlTrace(__unused NSString *stage, __unused NSDictionary *values) {}
static void hop(__unused dispatch_queue_t q, dispatch_block_t block) { [queued addObject:[block copy]]; }
static dispatch_time_t fakeTime(__unused dispatch_time_t t, int64_t delta) { return delta; }
static void later(dispatch_time_t t, __unused dispatch_queue_t q, dispatch_block_t block) { if (t == 8 * NSEC_PER_SEC) [timers addObject:[block copy]]; }
#define dispatch_async hop
#define dispatch_time fakeTime
#define dispatch_after later
static void drain(void) { while (queued.count) { QRingNext block=queued.firstObject; [queued removeObjectAtIndex:0]; block(); } }
@interface FlutterError:NSObject
@property(nonatomic,copy) NSString *code;
@property(nonatomic,copy) NSDictionary *details;
+ (instancetype)errorWithCode:(NSString *)code message:(NSString *)message details:(NSDictionary *)details;
@end
@implementation FlutterError
+ (instancetype)errorWithCode:(NSString *)code message:(__unused NSString *)message details:(NSDictionary *)details {
    FlutterError *e=[self new]; e.code=code; e.details=details; return e;
}
@end
@interface QCSDKManager:NSObject
@property(nonatomic,copy) QRingNext switchToPicture, takePicture, stopTakePicture;
+ (instancetype)shareInstance;
@end
@implementation QCSDKManager
+ (instancetype)shareInstance { static QCSDKManager *sdk; if (!sdk) sdk=[self new]; return sdk; }
@end
@interface QCSDKCmdCreator:NSObject
+ (void)switchToPhotoUISuccess:(QRingNext)success fail:(QRingNext)fail;
+ (void)holdPhotoUISuccess:(QRingNext)success fail:(QRingNext)fail;
+ (void)stopTakingPhotoSuccess:(QRingNext)success fail:(QRingNext)fail;
@end
@implementation QCSDKCmdCreator
+ (void)switchToPhotoUISuccess:(QRingNext)success fail:(QRingNext)fail {
    enterCalls++; enterSuccess=success; enterFail=fail;
    QCSDKManager *sdk=QCSDKManager.shareInstance;
    callbacksBeforeEnter = sdk.switchToPicture && sdk.takePicture && sdk.stopTakePicture;
}
+ (void)holdPhotoUISuccess:(QRingNext)success fail:(QRingNext)fail { holdSuccess=success; holdFail=fail; }
+ (void)stopTakingPhotoSuccess:(QRingNext)success fail:(QRingNext)fail { exitCalls++; exitSuccess=success; exitFail=fail; }
@end
@interface Bridge:NSObject
@property(nonatomic,copy) NSDictionary *featureList;
@property(nonatomic) BOOL resolved, live, remoteCameraActive, readingDetails;
@property(nonatomic) NSUInteger connectionGeneration, remoteCameraEpoch, cameraOperation, cameraPoisonGeneration, remoteCameraPoisonGeneration;
@property(nonatomic) NSInteger activeSportType;
@property(nonatomic,copy) NSString *connectedID, *activeMetric;
@property(nonatomic,strong) id pendingSync;
@property(nonatomic,copy) FlutterResult pendingCamera;
@property(nonatomic,strong) NSMutableArray *events, *results;
- (BOOL)isResolved;
- (BOOL)isCurrentConnection:(NSUInteger)generation;
- (BOOL)supportsGesture;
- (BOOL)cameraFlag:(NSString *)key;
- (BOOL)canOpenRemoteCamera;
- (FlutterError *)error:(NSString *)code message:(NSString *)message;
- (void)emit:(NSString *)event payload:(NSDictionary *)payload;
- (void)registerRemoteCameraCallbacks;
- (void)resetRemoteCamera;
- (void)cameraShutter:(NSNotification *)notification;
- (void)cameraStopped:(NSNotification *)notification;
- (void)scheduleCameraKeepAlive:(NSUInteger)epoch;
- (void)remoteCameraAction:(NSInteger)action result:(FlutterResult)result;
- (void)finishCamera:(id)value;
@end
@implementation Bridge
- (BOOL)isResolved { return self.resolved; }
- (BOOL)isCurrentConnection:(NSUInteger)generation { return self.live && generation==self.connectionGeneration; }
- (FlutterError *)error:(NSString *)code message:(__unused NSString *)message { FlutterError *e=[FlutterError new];e.code=code;return e; }
- (void)emit:(NSString *)event payload:(__unused NSDictionary *)payload { [self.events addObject:event]; }
// PRODUCTION_METHODS
@end
static Bridge *make(void) {
    queued=[NSMutableArray new];timers=[NSMutableArray new];enterCalls=0;exitCalls=0;callbacksBeforeEnter=NO;
    QCSDKManager *sdk=QCSDKManager.shareInstance;sdk.switchToPicture=nil;sdk.takePicture=nil;sdk.stopTakePicture=nil;
    enterSuccess=nil;enterFail=nil;exitSuccess=nil;exitFail=nil;holdSuccess=nil;holdFail=nil;
    Bridge *b=[Bridge new];b.live=YES;b.resolved=YES;b.connectionGeneration=3;b.activeSportType=-1;
    b.connectedID=@"test-only-target";b.featureList=@{QCBandFeatureGestureControl:@YES};b.events=[NSMutableArray new];b.results=[NSMutableArray new];return b;
}
static void request(Bridge *b, NSInteger action) {
    __weak Bridge *weak=b;
    [b remoteCameraAction:action result:^(id value) { [weak.results addObject:value ?: NSNull.null]; }];
}
static BOOL lastError(Bridge *b, NSString *code) { return [b.results.lastObject isKindOfClass:FlutterError.class] && [((FlutterError *)b.results.lastObject).code isEqual:code]; }
int main(void) { @autoreleasepool {
    Bridge *b=make();check([b canOpenRemoteCamera]);check(enterCalls==0 && exitCalls==0);
    request(b,4);check(callbacksBeforeEnter);check(!b.remoteCameraActive && b.results.count==0);
    QCSDKManager.shareInstance.takePicture();drain();check(b.events.count==0);
    enterSuccess();drain();check(b.remoteCameraActive && b.results.count==1 && b.results.lastObject==NSNull.null);
    QRingNext stale=QCSDKManager.shareInstance.takePicture;
    QCSDKManager.shareInstance.takePicture();drain();check([b.events containsObject:@"cameraShutter"]);
    NSUInteger events=b.events.count;[b resetRemoteCamera];stale();drain();check(b.events.count==events+1); // only stopped
    check(!QCSDKManager.shareInstance.takePicture && !QCSDKManager.shareInstance.switchToPicture && !QCSDKManager.shareInstance.stopTakePicture);

    b=make();request(b,4);[b resetRemoteCamera];enterSuccess();drain();
    check(lastError(b,@"QRING_CONTROL_CANCELLED") && !b.remoteCameraActive);
    b=make();request(b,4);QCSDKManager.shareInstance.stopTakePicture();drain();enterSuccess();drain();
    check(lastError(b,@"QRING_CONTROL_CANCELLED") && !b.remoteCameraActive);

    b=make();request(b,4);QRingNext lateAck=enterSuccess;enterFail();drain();
    check(lastError(b,@"QRING_ACTION_FAILED") && [b canOpenRemoteCamera] && !b.remoteCameraActive);
    request(b,4);check(enterCalls==2);lateAck();drain();check(!b.remoteCameraActive && b.results.count==1);
    enterSuccess();drain();check(b.remoteCameraActive && b.results.count==2);

    b=make();b.cameraPoisonGeneration=b.connectionGeneration;request(b,4);check(enterCalls==1);
    QRingNext timeout=timers.lastObject;timeout();drain();
    check(b.remoteCameraPoisonGeneration==3 && b.cameraPoisonGeneration==3 && !b.remoteCameraActive);
    request(b,4);check(lastError(b,@"QRING_CONTROL_UNCONFIRMED") && enterCalls==1);
    b.connectionGeneration++;request(b,4);check(enterCalls==2);

    b=make();request(b,4);QRingNext oldTake=QCSDKManager.shareInstance.takePicture;
    b.connectionGeneration++;enterSuccess();oldTake();drain();check(!b.remoteCameraActive && b.results.count==0 && b.events.count==0);
    b=make();b.featureList=@{};check(![b canOpenRemoteCamera]);request(b,4);check(lastError(b,@"QRING_FEATURE_UNVERIFIED") && enterCalls==0);
    b=make();b.readingDetails=YES;request(b,4);check(lastError(b,@"DEVICE_BUSY") && enterCalls==0);
    check([((FlutterError *)b.results.lastObject).details[@"retryableCameraReadBusy"] isEqual:@YES]);
    b.readingDetails=NO;request(b,4);check(enterCalls==1);enterSuccess();drain();check(b.remoteCameraActive);
    b.pendingSync=@YES;request(b,4);check(lastError(b,@"DEVICE_BUSY") && !((FlutterError *)b.results.lastObject).details && enterCalls==1);
    b=make();b.pendingSync=@YES;request(b,4);check(lastError(b,@"DEVICE_BUSY") && enterCalls==0 && [((FlutterError *)b.results.lastObject).details[@"retryableCameraReadBusy"] isEqual:@YES]);
    b.remoteCameraPoisonGeneration=b.connectionGeneration;request(b,4);check(lastError(b,@"QRING_CONTROL_UNCONFIRMED") && !((FlutterError *)b.results.lastObject).details && enterCalls==0);
    b=make();request(b,4);b.readingDetails=YES;request(b,4);check(lastError(b,@"DEVICE_BUSY") && !((FlutterError *)b.results.lastObject).details && enterCalls==1);
    b=make();b.activeMetric=@"measurement";b.readingDetails=YES;request(b,4);check(lastError(b,@"DEVICE_BUSY") && !((FlutterError *)b.results.lastObject).details && enterCalls==0);
    b=make();b.readingDetails=YES;request(b,6);check(lastError(b,@"DEVICE_BUSY") && !((FlutterError *)b.results.lastObject).details && exitCalls==0);
    b=make();request(b,4);enterSuccess();drain();request(b,6);check(!b.remoteCameraActive && exitCalls==1);exitSuccess();drain();check(b.results.count==2);
    printf("QRing on-entry photo session: %lu assertions passed\n",(unsigned long)checks);
} return 0; }
