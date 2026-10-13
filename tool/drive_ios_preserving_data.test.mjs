import assert from 'node:assert/strict';
import {test} from 'node:test';
import {preservingDriveArgs} from './drive_ios_preserving_data.mjs';

test('device integration tests retain the app after success or failure', () => {
  const args = preservingDriveArgs(['--profile', '--use-application-binary=.build/verified/Runner.app']);
  assert.equal(args[0], 'drive');
  assert.ok(args.includes('--keep-app-running'));
});
test('integration tests reject uninstalling and unverified build fallback', () => {
  assert.throws(() => preservingDriveArgs(['--profile']), /verified/);
  assert.throws(() => preservingDriveArgs(['--profile', '--use-application-binary=']), /verified/);
  assert.throws(() => preservingDriveArgs(['--use-application-binary=.build/verified/Runner.app']), /Profile/);
  assert.throws(() => preservingDriveArgs(['--profile', '--debug', '--use-application-binary=.build/verified/Runner.app']), /Profile/);
  for (const flag of ['--no-keep-app-running', '--uninstall-only']) {
    assert.throws(() => preservingDriveArgs(['--use-application-binary=.build/verified/Runner.app', flag]), /prohibited/);
  }
});
