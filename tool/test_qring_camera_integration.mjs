import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('QRing native controls require real flags, serialized stages and verified readback', () => {
  const ios = read('ios/Runner/QRingWearableBridge.m');
  const android = read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  assert.match(ios, /cameraFlag:QCBandFeatureGestureControlTakePhoto/);
  assert.match(ios, /cameraFlag:QCBandFeatureGestureControl/);
  assert.match(ios, /cameraFlag:QCBandFeatureTouchControl/);
  assert.match(ios, /getTouchControlOfScreenDevieFinshed:finish/);
  assert.match(ios, /setGestureControl:expected strength:strength/);
  for (const stage of [0, 1, 2]) {
    assert.ok(ios.includes(`cameraPhase != ${stage}`));
    assert.ok(android.includes(`cameraPhase != ${stage}`));
  }
  assert.match(ios, /connection == weakSelf.connectionGeneration && \[weakSelf isResolved\]/);
  assert.match(ios, /cameraPoisonGeneration = connection/);
  assert.match(ios, /readback\[@"mode"\].*!= expected/);
  assert.match(android, /isCurrentConnection\(connection, id\) && resolved\(\)/);
  assert.match(android, /cameraPoisonConnection = connection/);
  assert.match(android, /!response.isRead\(\)\s*\|\|/);
  assert.match(android, /response.isTouch\(\) != touch/);
  assert.match(android, /getWriteInstance\(expected, touch, strength, duration\)/);
  assert.match(android, /expectedMode/);
  assert.match(ios, /expectedMode/);
  for (const bridge of [ios, android]) {
    assert.ok(bridge.includes('QRING_CONTROL_CHANGED'));
    assert.ok(bridge.includes('QRING_CONTROL_UNCONFIRMED'));
  }
  // Persistent HID control and the ACK-confirmed Photo UI are separate.
  assert.match(ios, /@"supportsOta": @NO/);
  assert.match(android, /put\("supportsOta", false\)/);
  assert.match(ios, /switchToPhotoUISuccess/);
  assert.match(ios, /holdPhotoUISuccess/);
  assert.match(android, /new CameraReq/);
  assert.match(ios, /if \(self.remoteCameraSupported\).*addObject:@"camera"/);
  assert.match(android, /if \(remoteCameraSupported\).*features.add\("camera"\)/);
});

test('legacy QRing HID settings stay isolated from the Photo UI entry', () => {
  const page = read('lib/ui/pages/qring_camera.dart');
  assert.match(page, /expectedMode.*mode/);
  assert.match(page, /healthUiOwnerKey/);
  assert.match(page, /_snapshot = null/);
  assert.match(page, /具体动作以设备说明为准/);
  assert.doesNotMatch(page, /CameraController|triggerDeviceAction|摇动戒指/);
  assert.doesNotMatch(read('lib/ui/pages/devices.dart'), /device-functions-firmware/);
  assert.match(read('lib/ui/pages/devices.dart'), /device-firmware-upgrade/);
  assert.doesNotMatch(read('lib/ui/pages/devices.dart'), /builder:.*QRingCameraPage/);
});

test('QRing photo sessions confirm ACKs, keep alive and fence old shutter events', () => {
  const ios = read('ios/Runner/QRingWearableBridge.m');
  const android = read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  for (const source of [ios, android]) {
    assert.match(source, /probeRemoteCamera/);
    assert.match(source, /remoteCameraEpoch/);
    assert.match(source, /cameraRemoteStopped/);
    assert.match(source, /waitToStopCamera/);
    assert.match(source, /remoteCameraSupported = accepted/);
    assert.match(source, /DEVICE_BUSY/);
  }
  assert.match(ios, /name:OdmBandTakePictureNotification/);
  assert.match(android, /CameraNotifyRsp.ACTION_TAKE_PHOTO/);
  assert.match(android, /manager.removeOutCameraListener\(\)/);
  assert.match(ios, /removeObserver:self name:OdmBandTakePictureNotification/);
  const ui = read('lib/ui/prototype/device_features.dart');
  assert.match(ui, /_galleryPermissionDenied = error.code == 'PHOTO_PERMISSION_DENIED'/);
  assert.match(ui, /key: const ValueKey\('camera-photo-settings-button'\)/);
  assert.match(ui, /onPressed: openAppSettings/);
  assert.match(ui, /_galleryPermissionDenied = false/);
});
