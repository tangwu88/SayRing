import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import test from 'node:test';

test('production iOS core initialization does not require undeclared goal commands', {skip: process.platform !== 'darwin'}, async (t) => {
  const source = readFileSync(new URL('../ios/Runner/QRingWearableBridge.m', import.meta.url), 'utf8');
  const receiptAndCore = source.slice(source.indexOf('- (NSString *)factoryInitializationKey:'), source.indexOf('- (void)resetFirstMemberRing:'))
    .replaceAll('NSUserDefaults.standardUserDefaults', 'self.fixtureDefaults');
  const profile = source.slice(source.indexOf('- (void)writeProfileWithCompletion:'), source.indexOf('- (void)readDeviceDetailsWithCompletion:'));
  const handshake = source.slice(source.indexOf('- (void)resolveCapabilities {'), source.indexOf('// setTime may succeed'));
  assert(receiptAndCore.length > 500 && profile.length > 500 && handshake.length > 500);
  const dir = mkdtempSync(join(tmpdir(), 'sayring-core-initialization-'));
  try {
    writeFileSync(join(dir, 'main.m'), `#import <Foundation/Foundation.h>
typedef void (^QRingNext)(void);
typedef void (^FlutterResult)(id);
typedef void (^ProfileSuccess)(BOOL,BOOL,NSInteger,NSInteger,NSInteger,NSInteger,NSInteger,NSInteger,NSInteger);
static void QRingOnMain(dispatch_block_t operation) {operation();}
static void RingControlTrace(NSString *stage, NSDictionary *payload) {}
@interface DefaultsFixture : NSObject
@property(nonatomic,strong) NSMutableDictionary *values;
@end
@implementation DefaultsFixture
- (instancetype)init {if ((self=[super init])) self.values=[NSMutableDictionary new];return self;}
- (id)objectForKey:(NSString *)key {return self.values[key];}
- (void)setObject:(id)value forKey:(NSString *)key {self.values[key]=value;}
- (BOOL)synchronize {return YES;}
@end
@interface PeripheralFixture : NSObject
@property(nonatomic,strong) NSUUID *identifier;
@end
@implementation PeripheralFixture
@end
@interface CentralFixture : NSObject
@property(nonatomic,strong) PeripheralFixture *connectedPeripheral;
@end
@implementation CentralFixture
- (void)disconnect {}
@end
static void (^timeSuccess)(NSDictionary *);
static dispatch_block_t timeFailure, profileFailure;
static ProfileSuccess profileSuccess;
static NSUInteger goalReads, goalWrites, resetRequests, profileWrites;
@interface QCSDKCmdCreator : NSObject
+ (void)setTime:(NSDate *)date success:(void (^)(NSDictionary *))success failed:(dispatch_block_t)fail;
+ (void)setTimeFormatTwentyfourHourFormat:(BOOL)a metricSystem:(BOOL)b gender:(NSInteger)c age:(NSInteger)d height:(NSInteger)e weight:(NSInteger)f sbpBase:(NSInteger)g dbpBase:(NSInteger)h hrAlarmValue:(NSInteger)i success:(ProfileSuccess)success fail:(dispatch_block_t)fail;
+ (void)getStepTargetInfoWithSuccess:(id)success fail:(id)fail;
+ (void)setStepTarget:(NSInteger)a calorieTarget:(NSInteger)b distanceTarget:(NSInteger)c sportDurationTarget:(NSInteger)d sleepDurationTarget:(NSInteger)e success:(id)success fail:(id)fail;
+ (void)resetBandToFacotrySuccess:(id)success fail:(id)fail;
@end
@implementation QCSDKCmdCreator
+ (void)setTime:(NSDate *)date success:(void (^)(NSDictionary *))success failed:(dispatch_block_t)fail {timeSuccess=[success copy];timeFailure=[fail copy];}
+ (void)setTimeFormatTwentyfourHourFormat:(BOOL)a metricSystem:(BOOL)b gender:(NSInteger)c age:(NSInteger)d height:(NSInteger)e weight:(NSInteger)f sbpBase:(NSInteger)g dbpBase:(NSInteger)h hrAlarmValue:(NSInteger)i success:(ProfileSuccess)success fail:(dispatch_block_t)fail {profileWrites++;profileSuccess=[success copy];profileFailure=[fail copy];}
+ (void)getStepTargetInfoWithSuccess:(id)success fail:(id)fail {goalReads++;}
+ (void)setStepTarget:(NSInteger)a calorieTarget:(NSInteger)b distanceTarget:(NSInteger)c sportDurationTarget:(NSInteger)d sleepDurationTarget:(NSInteger)e success:(id)success fail:(id)fail {goalWrites++;}
+ (void)resetBandToFacotrySuccess:(id)success fail:(id)fail {resetRequests++;}
@end
@interface CoreHarness : NSObject
@property(nonatomic,copy) NSString *connectedID, *recoveryContext;
@property(nonatomic,strong) NSDictionary *featureList;
@property(nonatomic,strong) NSNumber *factoryResetGeneration, *factoryInitializingGeneration, *factoryTimeHandshakeGeneration;
@property(nonatomic,strong) DefaultsFixture *fixtureDefaults;
@property(nonatomic,strong) CentralFixture *central;
@property(nonatomic,strong) NSMutableArray *events;
@property(nonatomic,copy) FlutterResult pendingConnect;
@property(nonatomic) BOOL recoveryConnecting;
@property(nonatomic) NSUInteger connectionGeneration, connectDeadlineGeneration, failures, details;
@end
@implementation CoreHarness
- (BOOL)isCurrentConnection:(NSUInteger)generation {return generation==self.connectionGeneration;}
- (BOOL)isResolved {return self.featureList.count>0 && !self.pendingConnect && !self.recoveryConnecting;}
- (NSInteger)profileNumber:(NSString *)key fallback:(NSInteger)fallback minimum:(NSInteger)minimum maximum:(NSInteger)maximum {return fallback;}
- (void)resolveExtendedCapabilities:(NSDictionary *)features generation:(NSUInteger)generation attempt:(NSUInteger)attempt completion:(void (^)(NSDictionary *))completion {completion(features);}
- (void)failConnect:(NSString *)code message:(NSString *)message {self.failures++;}
- (void)readDeviceDetailsWithCompletion:(QRingNext)completion {self.details++;completion();}
- (NSDictionary *)deviceDetails {return @{@"id":self.connectedID};}
- (NSDictionary *)capabilities {return @{@"supportsHistorySync":self.factoryInitializationPending ? @NO : @YES};}
- (void)emit:(NSString *)type payload:(NSDictionary *)payload {[self.events addObject:@{@"type":type,@"payload":payload}];}
${receiptAndCore}
${profile}
${handshake}
@end
int main(int argc, const char **argv) { @autoreleasepool {
    NSString *scenario=argc>1 ? @(argv[1]) : @"legacy-pending";
    NSString *ring=@"00000000-0000-0000-0000-000000000001";
    CoreHarness *h=[CoreHarness new];h.fixtureDefaults=[DefaultsFixture new];h.events=[NSMutableArray new];
    h.connectedID=ring;h.recoveryContext=@"env:owner-a";h.connectionGeneration=2;h.factoryResetGeneration=@1;
    h.central=[CentralFixture new];h.central.connectedPeripheral=[PeripheralFixture new];h.central.connectedPeripheral.identifier=[[NSUUID alloc] initWithUUIDString:ring];
    NSMutableDictionary *receipt=[@{@"schemaVersion":@1,@"id":ring.lowercaseString,@"context":@"env:owner-a",@"acknowledged":@YES,@"initialized":@NO} mutableCopy];
    if ([scenario isEqual:@"fresh-receipt"]) {receipt[@"coreInitializationVersion"]=@1;receipt[@"coreInitialized"]=@NO;receipt[@"targetInitializationStatus"]=@"unknown";}
    if ([scenario isEqual:@"missing-ack"]) receipt[@"acknowledged"]=@NO;
    if ([scenario isEqual:@"legacy-complete"]) receipt[@"initialized"]=@YES;
    if ([scenario isEqual:@"unknown-core-version"]) {receipt[@"coreInitializationVersion"]=@99;receipt[@"coreInitialized"]=@YES;}
    BOOL noReceipt=[scenario isEqual:@"existing-member"];
    if (!noReceipt) [h saveFactoryInitialization:receipt identifier:ring context:h.recoveryContext];
    if (!noReceipt && ![scenario isEqual:@"legacy-complete"]) NSCAssert(h.factoryInitializationPending,@"Reading a receipt never upgrades it");
    if ([scenario isEqual:@"same-reset-connection"]) h.factoryResetGeneration=@3;
    if ([scenario isEqual:@"without-time-handshake"]) {
        h.featureList=@{@"realFeature":@YES};
        [h writeProfileWithCompletion:^{}];
    } else {
        [h resolveCapabilities];
        if ([scenario isEqual:@"time-failed"]) timeFailure();
        else if ([scenario isEqual:@"empty-features"]) timeSuccess(@{});
        else timeSuccess(@{@"realFeature":@YES});
    }
    if ([scenario isEqual:@"time-failed"] || [scenario isEqual:@"empty-features"]) {
        NSCAssert(profileWrites==0 && h.factoryInitializationPending,@"Failed fresh time/features cannot initialize");
    } else {
        NSCAssert(profileWrites==1,@"One real profile write per handshake");
        if ([scenario isEqual:@"owner-changed"]) h.recoveryContext=@"env:owner-b";
        if ([scenario isEqual:@"target-changed"]) h.connectedID=@"00000000-0000-0000-0000-000000000002";
        if ([scenario isEqual:@"generation-changed"]) h.connectionGeneration++;
        if ([scenario isEqual:@"rearm-cancelled"]) {h.factoryInitializingGeneration=@(h.connectionGeneration);[h writeProfileWithCompletion:^{}];h.factoryInitializingGeneration=nil;}
        if ([scenario isEqual:@"profile-failed"]) profileFailure();
        profileSuccess(YES,YES,0,30,170,65,0,0,0);
        profileSuccess(YES,YES,0,30,170,65,0,0,0); // Duplicate/late success cannot finish twice.
    }
    NSCAssert(goalReads==0 && goalWrites==0 && resetRequests==0,@"Core setup must not issue undeclared goals or repeat reset");
    h.connectedID=ring;h.recoveryContext=@"env:owner-a";
    NSDictionary *stored=[h factoryInitialization:ring context:h.recoveryContext];
    BOOL blocked=[@[@"missing-ack",@"same-reset-connection",@"without-time-handshake",@"time-failed",@"empty-features",@"owner-changed",@"target-changed",@"generation-changed",@"profile-failed",@"rearm-cancelled"] containsObject:scenario];
    if (blocked) NSCAssert(h.factoryInitializationPending && ![stored[@"coreInitialized"] isEqual:@YES],@"Unconfirmed or retired setup remains pending");
    else if (noReceipt) NSCAssert(stored==nil,@"An existing member must not gain a reset receipt");
    else if ([scenario isEqual:@"legacy-complete"]) NSCAssert(!h.factoryInitializationPending && [stored[@"initialized"] isEqual:@YES],@"Confirmed legacy receipt remains compatible");
    else {
        NSCAssert(!h.factoryInitializationPending && [stored[@"coreInitializationVersion"] isEqual:@1] && [stored[@"coreInitialized"] isEqual:@YES],@"Fresh confirmed core setup unlocks history");
        NSCAssert([stored[@"initialized"] isEqual:@NO] && [stored[@"targetInitializationStatus"] isEqual:@"unknown"],@"Optional targets must never be falsely marked complete");
        NSDictionary *last=h.events.lastObject;
        NSCAssert([last[@"type"] isEqual:@"ringInitialization"] && [last[@"payload"][@"status"] isEqual:@"complete"],@"Handshake publishes final initialization status");
        NSCAssert(h.details==1,@"Duplicate profile callbacks cannot repeat handshake completion");
    }
    return 0;
}}
`);
    execFileSync('xcrun', ['clang', '-fobjc-arc', '-framework', 'Foundation', join(dir, 'main.m'), '-o', join(dir, 'core-test')], {timeout: 30000, stdio: 'pipe'});
    for (const scenario of ['legacy-pending', 'fresh-receipt', 'legacy-complete', 'existing-member', 'unknown-core-version', 'missing-ack', 'same-reset-connection', 'without-time-handshake', 'time-failed', 'empty-features', 'owner-changed', 'target-changed', 'generation-changed', 'profile-failed', 'rearm-cancelled']) {
      await t.test(scenario, () => execFileSync(join(dir, 'core-test'), [scenario], {timeout: 10000, stdio: 'pipe'}));
    }
  } finally {
    rmSync(dir, {recursive: true, force: true});
  }
});
