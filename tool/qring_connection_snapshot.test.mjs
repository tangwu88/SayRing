import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

const root = fileURLToPath(new URL('../', import.meta.url));
const source = readFileSync(new URL('../ios/Runner/QRingWearableBridge.m', import.meta.url), 'utf8');
const method = signature => {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1);
  return source.slice(start, source.indexOf('\n- (', start + 1));
};

test('actual QRing connection snapshot exposes only the current ready radio without SDK work', {skip: process.platform !== 'darwin'}, () => {
  const methods = ['- (BOOL)isResolved', '- (NSDictionary *_Nullable)deviceSnapshot', '- (NSDictionary *)deviceDetails']
    .map(method).join('\n');
  const fixture = `#import <Foundation/Foundation.h>
#import "SayRingActivitySleepPolicy.h"
typedef NS_ENUM(NSInteger, QCState) {QCStateDisconnected, QCStateConnected};
typedef NS_ENUM(NSInteger, CBPeripheralState) {CBPeripheralStateDisconnected, CBPeripheralStateConnected};
@interface Radio:NSObject
@property(nonatomic,strong) NSUUID *identifier;
@property(nonatomic) CBPeripheralState state;
@end
@implementation Radio
@end
@interface Central:NSObject
@property(nonatomic,strong) Radio *connectedPeripheral;
@property(nonatomic) QCState deviceState;
@end
@implementation Central
@end
@interface Bridge:NSObject
@property(nonatomic,strong) Central *central;
@property(nonatomic,strong) NSDictionary *featureList;
@property(nonatomic,copy) NSString *connectedID, *connectedName, *firmware;
@property(nonatomic,strong) NSNumber *battery, *charging;
@property(nonatomic,strong) NSDate *batteryUpdatedAt;
@property(nonatomic,strong) id pendingConnect;
@property(nonatomic) BOOL recoveryConnecting, cancellingConnection;
@end
@implementation Bridge
- (NSString *)iso:(NSDate *)date {return date ? @"synthetic-date" : @"";}
${methods}
@end
int main(void) { @autoreleasepool {
    Bridge *b=[Bridge new];b.central=[Central new];b.central.connectedPeripheral=[Radio new];
    b.connectedID=@"00000000-0000-0000-0000-000000000001";b.connectedName=@"R8_fixture";
    b.central.connectedPeripheral.identifier=[[NSUUID alloc] initWithUUIDString:b.connectedID];
    b.central.connectedPeripheral.state=CBPeripheralStateConnected;b.central.deviceState=QCStateConnected;
    b.featureList=@{@"actualFeature":@YES};
    NSCAssert(SRActivitySleepCommandAllowed(@"getDeviceSnapshot",@{}),@"Snapshot must pass public command policy");
    NSDictionary *snapshot=[b deviceSnapshot];
    NSCAssert([snapshot[@"id"] isEqual:b.connectedID] && snapshot[@"battery"]==nil && snapshot[@"firmwareVersion"]==nil,@"Optional values remain unknown without any SDK reads");
    b.battery=@61;b.charging=@NO;b.batteryUpdatedAt=[NSDate date];b.firmware=@"actual-firmware";
    snapshot=[b deviceSnapshot];
    NSCAssert([snapshot[@"batteryPercent"] isEqual:@61] && [snapshot[@"firmwareVersion"] isEqual:@"actual-firmware"],@"Confirmed current-session metadata is retained");
    b.pendingConnect=@YES;NSCAssert([b deviceSnapshot]==nil,@"Pending handshake cannot become ready");b.pendingConnect=nil;
    b.recoveryConnecting=YES;NSCAssert([b deviceSnapshot]==nil,@"Recovery handshake cannot become ready");b.recoveryConnecting=NO;
    b.cancellingConnection=YES;NSCAssert([b deviceSnapshot]==nil,@"Cancelling transport cannot become ready");b.cancellingConnection=NO;
    b.featureList=nil;NSCAssert([b deviceSnapshot]==nil,@"Missing real capabilities cannot become ready");b.featureList=@{@"actualFeature":@YES};
    b.central.connectedPeripheral.state=CBPeripheralStateDisconnected;NSCAssert([b deviceSnapshot]==nil,@"Stale connected state cannot revive closed radio");b.central.connectedPeripheral.state=CBPeripheralStateConnected;
    b.central.connectedPeripheral.identifier=[[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000002"];
    NSCAssert([b deviceSnapshot]==nil,@"A different current radio cannot return the previous target");
    puts("QRing snapshot: actual resolved/radio/target guards and unknown metadata passed");
} return 0; }`;
  const directory = mkdtempSync(join(tmpdir(), 'sayring-qring-snapshot-'));
  try {
    const file = join(directory, 'snapshot.m');
    const executable = join(directory, 'snapshot');
    writeFileSync(file, fixture);
    execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation',
      '-I', join(root, 'ios/Runner'), file, '-o', executable], {stdio: 'pipe'});
    process.stdout.write(execFileSync(executable, [], {encoding: 'utf8'}));
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
});
