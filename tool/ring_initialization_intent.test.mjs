import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import test from 'node:test';

test('confirmed iOS factory reset requests a fresh connection without repeating reset', {skip:process.platform!=='darwin'}, () => {
  const source=readFileSync(new URL('../ios/Runner/QRingWearableBridge.m',import.meta.url),'utf8');
  const receipts=source.slice(source.indexOf('- (NSString *)factoryInitializationKey:'),source.indexOf('- (void)completeFactoryCoreInitializationForGeneration:'))
    .replaceAll('NSUserDefaults.standardUserDefaults','self.fixtureDefaults');
  const reset=source.slice(source.indexOf('- (void)resetFirstMemberRing:'),source.indexOf('- (void)writeProfileWithCompletion:'));
  const dir=mkdtempSync(join(tmpdir(),'sayring-init-reconnect-'));
  try {
    writeFileSync(join(dir,'main.m'), `#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
typedef void (^FlutterResult)(id);
static void (^resetSuccess)(void);
static NSUInteger resetRequests;
static void QRingOnMain(void (^operation)(void)) {operation();}
@interface DefaultsFixture : NSObject
@property(nonatomic,strong) NSMutableDictionary *values;
@end
@implementation DefaultsFixture
- (instancetype)init {if ((self=[super init])) self.values=[NSMutableDictionary new];return self;}
- (id)objectForKey:(NSString *)key {return self.values[key];}
- (void)setObject:(id)value forKey:(NSString *)key {self.values[key]=value;}
- (BOOL)synchronize {return YES;}
- (void)removePersistentDomainForName:(NSString *)name {[self.values removeAllObjects];}
@end
@interface QCSDKCmdCreator : NSObject
+ (void)resetBandToFacotrySuccess:(void (^)(void))success fail:(void (^)(void))failure;
@end
@implementation QCSDKCmdCreator
+ (void)resetBandToFacotrySuccess:(void (^)(void))success fail:(void (^)(void))failure {resetRequests++;resetSuccess=[success copy];}
@end
@interface ResetHarness : NSObject
@property(nonatomic,copy) NSString *connectedID, *recoveryContext, *activeMetric;
@property(nonatomic,strong) id pendingSync;
@property(nonatomic,strong) NSNumber *factoryResetGeneration;
@property(nonatomic,strong) DefaultsFixture *fixtureDefaults;
@property(nonatomic,strong) NSMutableArray *events;
@property(nonatomic) BOOL resolved, readingDetails;
@property(nonatomic) NSInteger activeSportType;
@property(nonatomic) NSUInteger connectionGeneration;
@end
@implementation ResetHarness
- (BOOL)isResolved {return self.resolved;}
- (id)error:(NSString *)code message:(NSString *)message {return code;}
- (NSDictionary *)capabilities {return @{};}
- (void)emit:(NSString *)event payload:(NSDictionary *)payload {if ([event isEqual:@"ringInitialization"]) [self.events addObject:payload];}
${receipts}
${reset}
@end
int main() { @autoreleasepool {
 NSString *suite=[@"sayring-reset-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString];
 DefaultsFixture *defaults=[DefaultsFixture new];
 ResetHarness *h=[ResetHarness new];h.fixtureDefaults=defaults;h.events=[NSMutableArray new];
 h.connectedID=@"RING-A";h.recoveryContext=@"env:owner-a";h.connectionGeneration=3;h.resolved=YES;h.activeSportType=-1;
 [h emitFactoryInitialization];NSCAssert(h.events.count==0,@"An existing member must not gain a reset state");
 NSDictionary *args=@{@"id":@"ring-a",@"ownerKey":@"owner-a",@"allowFactoryReset":@YES};
 __block id result;
 [h resetFirstMemberRing:args result:^(id value){result=value;}];
 NSCAssert([result isEqual:@"factoryResetRequested"] && resetRequests==1,@"One authorized reset dispatch");
 [h emitFactoryInitialization];
 NSCAssert([h.events.lastObject[@"status"] isEqual:@"pending"],@"Dispatch must remain unconfirmed");
 NSCAssert(![h.events.lastObject[@"requiresReconnect"] boolValue],@"No automatic reconnect from an ambiguous reset");
 resetSuccess(); // Firmware ACK, deliberately no BLE disconnect.
 NSDictionary *event=h.events.lastObject;
 NSCAssert([event[@"status"] isEqual:@"pending"] && [event[@"requiresReconnect"] isEqual:@YES],@"A confirmed reset on the same connection must request one fresh handshake");
 NSCAssert(CFGetTypeID((__bridge CFTypeRef)event[@"requiresReconnect"])==CFBooleanGetTypeID(),@"Reconnect signal must use the Flutter Boolean codec");
 NSCAssert([event[@"deviceId"] isEqual:@"RING-A"] && [event[@"ownerKey"] isEqual:@"owner-a"],@"Signal retains the exact owner and target");
 [h resetFirstMemberRing:args result:^(id value){result=value;}];
 NSCAssert([result isEqual:@"DEVICE_BUSY"] && resetRequests==1,@"Never repeat the destructive command");
 h.connectionGeneration=4;
 [h emitFactoryInitialization];
 NSCAssert([h.events.lastObject[@"requiresReconnect"] isEqual:@NO] && h.factoryInitializationPending,@"New handshake may initialize but must not restart recovery");
 [h updateFactoryInitialization:@"ring-a" context:@"env:owner-a" acknowledged:NO initialized:YES];
 [h emitFactoryInitialization];
 NSCAssert([h.events.lastObject[@"status"] isEqual:@"complete"] && [h.events.lastObject[@"requiresReconnect"] isEqual:@NO],@"Verified initialization unlocks history without another reconnect");
 NSUInteger count=h.events.count;
 h.recoveryContext=@"env:other";[h emitFactoryInitialization];
 h.recoveryContext=@"env:owner-a";h.connectedID=@"ring-b";[h emitFactoryInitialization];
 NSCAssert(h.events.count==count,@"Never signal a different owner or target");
 // A callback that arrives after its connection generation is retired remains
 // ambiguous. Do not reopen history or replay reset as part of this fix.
 h.connectedID=@"ring-c";h.connectionGeneration=5;
 NSDictionary *lateArgs=@{@"id":@"ring-c",@"ownerKey":@"owner-a",@"allowFactoryReset":@YES};
 [h resetFirstMemberRing:lateArgs result:^(id value){result=value;}];
 h.connectionGeneration=6;resetSuccess();[h emitFactoryInitialization];
 NSCAssert(h.factoryInitializationPending && [h.events.lastObject[@"requiresReconnect"] isEqual:@NO],@"Retired ACK must stay closed");
 [defaults removePersistentDomainForName:suite];return 0;
}}
`);
    execFileSync('xcrun',['clang','-fobjc-arc','-framework','Foundation','-framework','CoreFoundation',join(dir,'main.m'),'-o',join(dir,'reset-test')],{timeout:30000,stdio:'pipe'});
    execFileSync(join(dir,'reset-test'),[],{timeout:10000,stdio:'pipe'});
  } finally {rmSync(dir,{recursive:true,force:true});}
});

test('actual iOS history flag crosses the Flutter codec as Boolean for ready and pending rings', {skip:process.platform!=='darwin'}, () => {
  const source=readFileSync(new URL('../ios/Runner/QRingWearableBridge.m',import.meta.url),'utf8');
  const expression=source.match(/@"supportsHistorySync":\s*([^\n]+),/)[1];
  const dir=mkdtempSync(join(tmpdir(),'sayring-history-bool-'));
  try {
    writeFileSync(join(dir,'main.m'), `#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
@interface HistoryHarness : NSObject
@property(nonatomic) BOOL pending;
@end
@implementation HistoryHarness
- (BOOL)factoryInitializationPending {return self.pending;}
- (NSNumber *)reportedHistoryFlag {return ${expression};}
@end
int main() { @autoreleasepool {
 HistoryHarness *h=[HistoryHarness new];
 for (NSNumber *pending in @[@NO,@YES]) {
  h.pending=pending.boolValue;
  NSNumber *flag=[h reportedHistoryFlag];
  // Flutter's standard codec distinguishes CFBoolean from integer NSNumber.
  NSCAssert(CFGetTypeID((__bridge CFTypeRef)flag)==CFBooleanGetTypeID(),@"History capability must be a codec Boolean, never integer 1 or 0");
  NSCAssert(flag.boolValue!=h.pending,@"Ready history stays enabled; pending initialization stays closed");
 }
 return 0;
}}
`);
    execFileSync('xcrun',['clang','-fobjc-arc','-framework','Foundation','-framework','CoreFoundation',join(dir,'main.m'),'-o',join(dir,'history-bool-test')],{timeout:30000,stdio:'pipe'});
    execFileSync(join(dir,'history-bool-test'),[],{timeout:10000,stdio:'pipe'});
  } finally {rmSync(dir,{recursive:true,force:true});}
});

test('actual iOS initialization receipt survives restart and never crosses owner or target', {skip:process.platform!=='darwin'}, () => {
  const source=readFileSync(new URL('../ios/Runner/QRingWearableBridge.m',import.meta.url),'utf8');
  const start=source.indexOf('- (NSString *)factoryInitializationKey:');
  const end=source.indexOf('- (void)emitFactoryInitialization',start);
  assert(start>0 && end>start);
  const methods=source.slice(start,end).replaceAll('NSUserDefaults.standardUserDefaults','self.fixtureDefaults');
  const dir=mkdtempSync(join(tmpdir(),'sayring-init-intent-'));
  try {
    writeFileSync(join(dir,'main.m'), `#import <Foundation/Foundation.h>
@interface ReceiptHarness : NSObject
@property(nonatomic,copy) NSString *connectedID;
@property(nonatomic,copy) NSString *recoveryContext;
@property(nonatomic,strong) NSUserDefaults *fixtureDefaults;
@end
@implementation ReceiptHarness
${methods}
@end
int main() { @autoreleasepool {
 NSString *suite=[@"sayring-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString];
 NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
 ReceiptHarness *a=[ReceiptHarness new];a.fixtureDefaults=defaults;a.connectedID=@"RING-A";a.recoveryContext=@"env:owner-a";
 NSCAssert(!a.factoryInitializationPending,@"Old member must not acquire an initialization intent");
 NSDictionary *intent=@{@"schemaVersion":@1,@"id":@"ring-a",@"context":@"env:owner-a",@"acknowledged":@NO,@"initialized":@NO};
 NSCAssert([a saveFactoryInitialization:intent identifier:@"RING-A" context:@"env:owner-a"],@"Fixture store failed");
 NSCAssert(a.factoryInitializationPending,@"Dispatch is not a confirmed reset");
 ReceiptHarness *restart=[ReceiptHarness new];restart.fixtureDefaults=defaults;restart.connectedID=@"ring-a";restart.recoveryContext=@"env:owner-a";
 NSCAssert(restart.factoryInitializationPending,@"Restart must retain uncertainty without repeating a reset");
 restart.recoveryContext=@"env:owner-b";
 NSCAssert(!restart.factoryInitializationPending,@"Never adopt another owner from a receipt");
 [restart updateFactoryInitialization:@"ring-a" context:@"env:owner-b" acknowledged:YES initialized:YES];
 NSCAssert([restart factoryInitialization:@"ring-a" context:@"env:owner-b"]==nil,@"An ACK cannot create a different owner receipt");
 restart.recoveryContext=@"env:owner-a";restart.connectedID=@"ring-b";
 NSCAssert(!restart.factoryInitializationPending,@"Never adopt a different device from a receipt");
 restart.connectedID=@"ring-a";
 [restart updateFactoryInitialization:@"ring-a" context:@"env:owner-a" acknowledged:YES initialized:NO];
 NSCAssert(restart.factoryInitializationPending,@"Reset ACK alone must not open history");
 [restart updateFactoryInitialization:@"ring-a" context:@"env:owner-a" acknowledged:NO initialized:YES];
 NSCAssert(!restart.factoryInitializationPending,@"Both ACK and fresh target verification are required");
 NSCAssert(!a.factoryInitializationPending,@"Completion persists for the same exact owner and target");
 [defaults removePersistentDomainForName:suite];
 return 0;
}}
`);
    execFileSync('xcrun',['clang','-fobjc-arc','-framework','Foundation',join(dir,'main.m'),'-o',join(dir,'intent-test')],{timeout:30000,stdio:'pipe'});
    execFileSync(join(dir,'intent-test'),[],{timeout:10000,stdio:'pipe'});
  } finally {rmSync(dir,{recursive:true,force:true});}
});

test('actual iOS owner arming resumes initialization only on the already connected target, never reset', {skip:process.platform!=='darwin'}, () => {
  const source=readFileSync(new URL('../ios/Runner/QRingWearableBridge.m',import.meta.url),'utf8');
  const receipt=source.slice(source.indexOf('- (NSString *)factoryInitializationKey:'),source.indexOf('- (void)emitFactoryInitialization'))
    .replaceAll('NSUserDefaults.standardUserDefaults','self.fixtureDefaults');
  const configure=source.slice(source.indexOf('- (void)configureRecoveryTarget:'),source.indexOf('- (void)resolveCapabilities'));
  const dir=mkdtempSync(join(tmpdir(),'sayring-init-arm-'));
  try {
    writeFileSync(join(dir,'main.m'), `#import <Foundation/Foundation.h>
typedef void (^FlutterResult)(id);
typedef void (^QRingNext)(void);
@interface CentralFixture : NSObject
- (void)discardRestoredPeripheralsExceptIdentifier:(NSString *)identifier;
@end
@implementation CentralFixture
- (void)discardRestoredPeripheralsExceptIdentifier:(NSString *)identifier {}
@end
@interface ArmHarness : NSObject
@property(nonatomic,copy) NSString *connectedID, *recoveryContext, *recoveryTargetID, *recoveryTargetName;
@property(nonatomic,strong) NSDictionary *recoveryProfile, *profile;
@property(nonatomic,strong) NSNumber *factoryResetGeneration, *factoryInitializingGeneration;
@property(nonatomic,strong) NSUserDefaults *fixtureDefaults;
@property(nonatomic,strong) CentralFixture *central;
@property(nonatomic) BOOL recoveryConnecting, cancellingConnection, recoveryScanning;
@property(nonatomic) NSUInteger connectionGeneration, profileWrites, recoveries, scansFinished;
- (void)configureRecoveryTarget:(NSDictionary *)arguments result:(FlutterResult)result;
@end
@implementation ArmHarness
${receipt}
- (BOOL)isResolved {return self.connectedID.length>0;}
- (BOOL)isCurrentConnection:(NSUInteger)generation {return generation==self.connectionGeneration && [self isResolved];}
- (BOOL)isQRingName:(NSString *)name {return [name isEqual:@"R12"];}
- (id)error:(NSString *)code message:(NSString *)message {return code;}
- (void)disconnectWithResult:(FlutterResult)result {result(nil);}
- (void)finishScan {self.recoveryScanning=NO;self.scansFinished++;}
- (void)startAutomaticRecovery {self.recoveries++;}
- (void)emit:(NSString *)event payload:(NSDictionary *)payload {}
- (NSDictionary *)capabilities {return @{};}
- (void)emitFactoryInitialization {}
- (void)writeProfileWithCompletion:(QRingNext)completion {self.profileWrites++;completion();}
${configure}
@end
int main() { @autoreleasepool {
 NSString *suite=[@"sayring-arm-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString];
 NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
 NSString *ring=@"00000000-0000-0000-0000-000000000001";
 ArmHarness *a=[ArmHarness new];a.fixtureDefaults=defaults;a.central=[CentralFixture new];a.connectedID=ring;a.connectionGeneration=3;
 NSDictionary *args=@{@"id":ring,@"name":@"R12",@"context":@"env:owner-a",@"profile":@{@"targetSteps":@9000}};
 __block NSUInteger results=0;
 FlutterResult result=^(id error){NSCAssert(error==nil,@"Unexpected arming error");results++;};
 [a configureRecoveryTarget:args result:result];
 NSCAssert(a.profileWrites==0,@"An old member must not receive factory initialization");
 NSDictionary *intent=@{@"schemaVersion":@1,@"id":ring,@"context":@"env:owner-a",@"acknowledged":@YES,@"initialized":@NO};
 [a saveFactoryInitialization:intent identifier:ring context:@"env:owner-a"];
 a.recoveryContext=nil;
 [a configureRecoveryTarget:args result:result];
 NSCAssert(a.profileWrites==1 && [a.profile[@"targetSteps"] isEqual:@9000],@"Manual reconnect must initialize after the exact owner is armed");
 NSCAssert(a.factoryInitializingGeneration==nil,@"Operation barrier must finish");
 a.factoryResetGeneration=@3;
 [a configureRecoveryTarget:args result:result];
 NSCAssert(a.profileWrites==1,@"Never initialize during the reset connection");
 a.connectionGeneration=4;a.connectedID=@"00000000-0000-0000-0000-000000000002";
 [a configureRecoveryTarget:args result:result];
 NSCAssert(a.profileWrites==1,@"Receipt must not adopt a different connected device");
 a.connectedID=ring;a.recoveryScanning=YES;
 [a configureRecoveryTarget:@{@"id":ring,@"name":@"R12",@"context":@"env:owner-b"} result:result];
 NSCAssert(a.profileWrites==1,@"Never initialize a different owner from a receipt");
 NSCAssert(a.scansFinished==1 && !a.recoveryScanning,@"Owner change retires the previous recovery scan");
 NSCAssert(results==5,@"Each arming result must complete once");
 a.recoveryScanning=YES;
 [a configureRecoveryTarget:@{} result:result];
 NSCAssert(a.scansFinished==2 && !a.recoveryScanning && a.recoveryTargetID.length==0,@"Disarming must stop discovery without adopting a target");
 NSCAssert(results==6 && a.profileWrites==1,@"Disarming completes once without initialization");
 [defaults removePersistentDomainForName:suite];return 0;
}}
`);
    execFileSync('xcrun',['clang','-fobjc-arc','-framework','Foundation',join(dir,'main.m'),'-o',join(dir,'arm-test')],{timeout:30000,stdio:'pipe'});
    execFileSync(join(dir,'arm-test'),[],{timeout:10000,stdio:'pipe'});
  } finally {rmSync(dir,{recursive:true,force:true});}
});
