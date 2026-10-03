import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';

const read = (name) => readFileSync(new URL(`../${name}`, import.meta.url), 'utf8');
const bridge = read('ios/Runner/CoolWearWearableBridge.m');
const project = read('ios/Runner.xcodeproj/project.pbxproj');

test('the shipped iPhone SDK binary is the untouched user-provided version', () => {
  const bytes = readFileSync(new URL('../ios/Runner/Vendor/BluetoothLibrary.framework/BluetoothLibrary', import.meta.url));
  assert.equal(createHash('sha256').update(bytes).digest('hex'), 'f56c39605abded5f57b7ab28f245d67218b9df9e8edbb7fe037755b8cd3ca624');
  assert.match(read('ios/Runner/Vendor/COOLWEAR-README.md'), /no simulator slice/);
});

test('the real bridge and framework are registered linked and signed for every device build', () => {
  assert.match(read('ios/Runner/AppDelegate.swift'), /coolwearWearableBridge = CoolWearWearableBridge\(messenger:/);
  assert.match(read('ios/Runner/Runner-Bridging-Header.h'), /#import "CoolWearWearableBridge.h"/);
  assert.match(project, /BluetoothLibrary.framework in Embed Frameworks[^\n]+CodeSignOnCopy/);
  assert.equal((project.match(/\n\s+BluetoothLibrary.framework,/g) ?? []).length, 3);
  assert.equal((project.match(/\n\s+CoolWearWearableBridge.m,/g) ?? []).length, 3);
});

test('discovery uses vendor peripheral models and two declared services', () => {
  assert.match(bridge, /isKindOfClass:SearchPeripheral.class/);
  assert.match(bridge, /self.product.sid = @"F618"/);
  assert.match(bridge, /weakSelf.product.sid = @"F818"/);
  assert.match(bridge, /self.product.sid = self.scanServices\[identifier\]/);
  assert.match(bridge, /startScanWhenReady:generation attempt:0/);
});

test('connection completion requires metadata and flags from the exact real target', () => {
  assert.match(bridge, /product.peripheral.identifier isEqual:self.target.identifier/);
  assert.match(bridge, /self.product.status == ProductStatus_completed/);
  assert.match(bridge, /self.deviceInfo.count > 0 && self.flags.count > 0/);
  assert.match(bridge, /generation != weakSelf.connectionGeneration/);
  assert.match(bridge, /30 \* NSEC_PER_SEC/);
});

test('installation-wide recovery and raw health logging are not imported', () => {
  assert.doesNotMatch(bridge, /\[(?:self\.|weakSelf\.)?product (?:startAutoConnect|saveConnectedUUid|releaseBind)\]/);
  assert.doesNotMatch(bridge, /NSLog\(|NSUserDefaults|receiveOriginalDataHandler\s*=|sendOriginalDataHandler\s*=/);
  assert.match(bridge, /lastConnectUUId = nil/);
  assert.match(bridge, /UUIDStr = nil/);
});

test('mixed data is never converted into fake history completion', () => {
  const mixed = bridge.slice(bridge.indexOf('type.integerValue == DATA_TYPE_DEV_SYNC'), bridge.indexOf('if (![data isKindOfClass:NSDictionary.class])'));
  assert.match(mixed, /receiveData:child depth:/);
  assert.doesNotMatch(mixed, /result\(|completeSync|pendingSync|healthRecord/);
  assert.match(bridge, /COOLWEAR_FEATURE_UNVERIFIED/);
});

test('measurement is session guarded and requires a real fresh sample', () => {
  assert.match(bridge, /measurement == self.measurementGeneration/);
  assert.match(bridge, /CoolWearMeasurementValue\(metric, sample\)/);
  assert.match(bridge, /timeIntervalSinceDate:self.measurementStart/);
  assert.match(bridge, /if \(!value \|\| !date/);
  assert.match(bridge, /@"origin": @"app_measurement"/);
  assert.match(bridge, /@"sourceModel": CoolWearModel\(self.targetName\)/);
});

test('SDK exceptions cannot acknowledge a failed scan or complete a request twice', () => {
  assert.match(bridge, /result = CoolWearCompleteOnce\(result\)/);
  const exception = bridge.slice(bridge.indexOf('@catch (NSException *exception)'));
  assert.ok(exception.indexOf('self.pendingScan = nil') < exception.indexOf('[self beginCancellation:nil]'));
  assert.match(exception, /for \(CoolWearCompletion completion in pending\) completion\(failure\)/);
  assert.match(exception, /self.cancelling = YES/);
  assert.match(bridge, /CoolWearHasKnownCapabilities\(data\)/);
});
