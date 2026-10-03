import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';

const read = (name) => readFileSync(new URL(`../${name}`, import.meta.url), 'utf8');
const bridge = read('ios/Runner/CoolWearWearableBridge.m');
const project = read('ios/Runner.xcodeproj/project.pbxproj');

test('mapped iOS history remains capability gated and reports per-metric status', () => {
  const policy = read('ios/Runner/CoolWearPolicy.h');
  assert.match(policy, /@"supportsHistorySync": @\(resolved\)/);
  assert.match(bridge, /@"statuses": statuses/);
  assert.match(bridge, /if \(metric\) \[metrics addObject:metric\]/);
  assert.match(bridge, /sync == weakSelf.syncGeneration/);
  assert.match(policy, /@"manualMetrics": manual/);
  assert.match(read('lib/services/app_controller.dart'), /capabilities\?\.supportsHistorySync == false/);
  assert.match(read('lib/ui/pages.dart'), /Key\('device-sync-data'\)/);
});

test('iOS permission status readers are compiled for declared uses only', () => {
  const podfile = read('ios/Podfile');
  assert.match(podfile, /target.name == 'permission_handler_apple'/);
  for (const permission of ['BLUETOOTH', 'LOCATION_WHENINUSE', 'CAMERA', 'NOTIFICATIONS']) {
    assert.ok(podfile.includes(`PERMISSION_${permission}=1`));
  }
  assert.doesNotMatch(podfile, /PERMISSION_(?:PHOTOS|CONTACTS|LOCATION_ALWAYS|MICROPHONE)=1/);
  const plist = read('ios/Runner/Info.plist');
  for (const key of ['NSBluetoothAlwaysUsageDescription', 'NSLocationWhenInUseUsageDescription', 'NSCameraUsageDescription']) {
    assert.ok(plist.includes(key));
  }
});

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
  const mixed = bridge.match(/if \(type.integerValue == DATA_TYPE_DEV_SYNC\) \{([\s\S]*?)\n    \}/)?.[1];
  assert.ok(mixed);
  assert.match(mixed, /receiveData:child depth:/);
  assert.doesNotMatch(mixed, /result\(|completeSync|pendingSync|healthRecord/);
  assert.match(bridge, /COOLWEAR_FEATURE_UNVERIFIED/);
  assert.match(bridge, /CoolWearUnsigned\(info\[@"DataType"\], 255\)/);
  const history = bridge.slice(bridge.indexOf('NSString *historyKey'), bridge.indexOf('if (type.integerValue == DATA_TYPE_REAL_HRV_METRICS)'));
  assert.doesNotMatch(history, /\[self finishSync\]/);
  assert.match(bridge, /25 \* NSEC_PER_SEC/);
  assert.match(bridge, /\[weakSelf finalizeSleepHistory\];\s*\[weakSelf finishSync\]/);
  assert.match(bridge, /type.integerValue == 6 \? @\[\] : batch.rows.allValues/);
  assert.match(bridge, /if \(!\[metric isEqual:@"sleep"\]\)/);
  const sleep = bridge.slice(bridge.indexOf('- (void)finalizeSleepHistory'), bridge.indexOf('- (void)readBattery'));
  assert.match(sleep, /\[\[batch status\] isEqual:@"complete"\]/);
});

test('measurement is session guarded and requires a real fresh sample', () => {
  assert.match(bridge, /measurement == self.measurementGeneration/);
  assert.match(bridge, /CoolWearMeasurementValue\(metric, sample\)/);
  assert.match(bridge, /timeIntervalSinceDate:self.measurementStart/);
  assert.match(bridge, /if \(!value \|\| !date/);
  assert.match(bridge, /@"origin": @"app_measurement"/);
  assert.match(bridge, /@"sourceModel": CoolWearModel\(self.targetName\)/);
});

test('RRI uses the new command and explicit metrics, never ambiguous legacy HRV', () => {
  assert.match(bridge, /CE_SyncRRIHRVCmd \*cmd/);
  assert.match(bridge, /DATA_TYPE_REAL_HRV_METRICS/);
  assert.match(read('ios/Runner/CoolWearHistory.h'), /@61:@"hrvMetricsInfos"/);
  assert.doesNotMatch(bridge, /CE_SyncHRVCmd \*|== DATA_TYPE_REAL_HRV\b|== DATA_TYPE_HISTORY_HRV\b/);
  assert.match(bridge, /CoolWearRriHrvValues\(sample\)/);
  assert.match(read('ios/Runner/CoolWearHistory.h'), /CoolWearSkinTemperatureValues\(sample\)/);
  assert.match(bridge, /origin:@"watch_history"/);
});

test('passive handshake data is delivered only after the account-owned Dart session is ready', () => {
  assert.match(bridge, /getCapabilities[\s\S]*?\[self enableDataDelivery\]/);
  assert.match(bridge, /!self.dataDeliveryReady \|\| !\[\[self capabilities\]\[@"historyMetrics"\]/);
  const cancel = bridge.slice(bridge.indexOf('- (void)beginCancellation:'), bridge.indexOf('- (void)checkCancellation'));
  assert.match(cancel, /self.dataDeliveryReady = NO/);
  assert.match(cancel, /\[self.pendingPassiveRecords removeAllObjects\]/);
  assert.match(bridge, /resolved\[@"firmwareVersion"\] = self.deviceInfo/);
});

test('SDK exceptions cannot acknowledge a failed scan or complete a request twice', () => {
  assert.match(bridge, /result = CoolWearCompleteOnce\(result\)/);
  const exception = bridge.slice(bridge.indexOf('@catch (NSException *exception)'));
  assert.ok(exception.indexOf('self.pendingScan = nil') < exception.indexOf('[self beginCancellation:nil]'));
  assert.match(exception, /for \(CoolWearCompletion completion in pending\) completion\(failure\)/);
  assert.match(exception, /self.cancelling = YES/);
  assert.match(bridge, /CoolWearHasKnownCapabilities\(data\)/);
});
