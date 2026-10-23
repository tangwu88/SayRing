import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import test from 'node:test';

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
@property(nonatomic) BOOL recoveryConnecting, cancellingConnection;
@property(nonatomic) NSUInteger connectionGeneration, profileWrites, recoveries;
- (void)configureRecoveryTarget:(NSDictionary *)arguments result:(FlutterResult)result;
@end
@implementation ArmHarness
${receipt}
- (BOOL)isResolved {return self.connectedID.length>0;}
- (BOOL)isCurrentConnection:(NSUInteger)generation {return generation==self.connectionGeneration && [self isResolved];}
- (BOOL)isQRingName:(NSString *)name {return [name isEqual:@"R12"];}
- (id)error:(NSString *)code message:(NSString *)message {return code;}
- (void)disconnectWithResult:(FlutterResult)result {result(nil);}
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
 a.connectedID=ring;
 [a configureRecoveryTarget:@{@"id":ring,@"name":@"R12",@"context":@"env:owner-b"} result:result];
 NSCAssert(a.profileWrites==1,@"Never initialize a different owner from a receipt");
 NSCAssert(results==5,@"Each arming result must complete once");
 [defaults removePersistentDomainForName:suite];return 0;
}}
`);
    execFileSync('xcrun',['clang','-fobjc-arc','-framework','Foundation',join(dir,'main.m'),'-o',join(dir,'arm-test')],{timeout:30000,stdio:'pipe'});
    execFileSync(join(dir,'arm-test'),[],{timeout:10000,stdio:'pipe'});
  } finally {rmSync(dir,{recursive:true,force:true});}
});
