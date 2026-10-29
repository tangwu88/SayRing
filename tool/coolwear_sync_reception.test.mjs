import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';

test('real native reception counts remain unique, connected and session ready', {skip: process.platform !== 'darwin'}, () => {
  const source = readFileSync('ios/Runner/CoolWearWearableBridge.m', 'utf8');
  const method = source.slice(source.indexOf('- (void)publishSyncReception'), source.indexOf('- (void)finalizeSleepHistory'));
  assert.ok(method.length > 200);
  const directory = mkdtempSync(join(tmpdir(), 'sayring-reception-'));
  try {
    const program = `
#import <Foundation/Foundation.h>
@interface Target : NSObject
@property(nonatomic, strong) NSUUID *identifier;
@end
@implementation Target
@end
@interface ReceptionProbe : NSObject
@property(nonatomic) BOOL pendingSync, dataDeliveryReady, resolved;
@property(nonatomic) NSUInteger events;
@property(nonatomic) NSUInteger lastSyncReceptionCount;
@property(nonatomic, strong) Target *target;
@property(nonatomic, strong) NSMutableDictionary *syncRecords;
@property(nonatomic, copy) NSDictionary *lastPayload;
- (BOOL)isResolved;
- (void)emit:(NSString *)type payload:(NSDictionary *)payload;
- (void)publishSyncReception;
@end
@implementation ReceptionProbe
- (BOOL)isResolved { return self.resolved; }
- (void)emit:(NSString *)type payload:(NSDictionary *)payload {
  NSCAssert([type isEqual:@"syncRecords"], @"unexpected event");
  self.events++; self.lastPayload = payload;
}
${method}
@end
int main(void) { @autoreleasepool {
 ReceptionProbe *p = [ReceptionProbe new];
 p.target = [Target new]; p.target.identifier = [[NSUUID alloc] initWithUUIDString:@"11111111-2222-4333-8444-555555555555"];
 p.syncRecords = [@{@"a":@1, @"b":@2} mutableCopy];
 for (NSUInteger mask = 0; mask < 7; mask++) {
   p.pendingSync = mask & 1; p.dataDeliveryReady = mask & 2; p.resolved = mask & 4;
   [p publishSyncReception]; NSCAssert(p.events == 0, @"inactive or unowned count escaped");
 }
 p.pendingSync = p.dataDeliveryReady = p.resolved = YES;
 [p publishSyncReception];
 NSCAssert([p.lastPayload[@"receivedRecords"] isEqual:@2], @"actual record count lost");
 NSCAssert([p.lastPayload[@"deviceId"] isEqual:@"coolwear:11111111-2222-4333-8444-555555555555"], @"wrong device scope");
 p.syncRecords[@"a"] = @3; [p publishSyncReception];
 NSCAssert([p.lastPayload[@"receivedRecords"] isEqual:@2], @"duplicate callback inflated count");
 p.pendingSync = NO; [p publishSyncReception];
 NSCAssert(p.events == 1, @"duplicate or completed operation caused another refresh");
 puts("PASS actual scoped reception");
} }
`;
    const path = join(directory, 'probe.m');
    const binary = join(directory, 'probe');
    writeFileSync(path, program);
    execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation', path, '-o', binary], {stdio: 'pipe'});
    assert.match(execFileSync(binary, {encoding: 'utf8', timeout: 10000}), /PASS/);
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
});
