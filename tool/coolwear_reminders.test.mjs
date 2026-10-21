import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync, readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
import {tmpdir} from 'node:os';

test('native reminders preserve schedules, validate fields and shared monitoring interval', {skip: process.platform !== 'darwin'}, () => {
  const dir = mkdtempSync(join(tmpdir(), 'sayring-reminders-'));
  try {
    for (const name of ['native_coolwear_policy_test', 'native_coolwear_reminders_test']) {
      const binary = join(dir, name);
      execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation', `test/${name}.m`, '-o', binary], {stdio: 'pipe'});
      assert.match(execFileSync(binary, {encoding: 'utf8'}), /PASS|passed/);
    }
  } finally {
    rmSync(dir, {recursive: true, force: true});
  }
});

test('reminder writes require fresh revision, SDK acknowledgement and matching readback', () => {
  const source = readFileSync('ios/Runner/CoolWearWearableBridge.m', 'utf8');
  assert.match(source, /snapshotRevision.*reminderRevision:payload/);
  assert.match(source, /payload isEqual:self.remindersExpected/);
  assert.match(source, /!self.remindersAcknowledged.*self.remindersReadback.count != self.remindersAwaited.count/);
  assert.match(source, /operation != weakSelf.remindersGeneration.*connection != weakSelf.connectionGeneration/);
  assert.match(source, /finishReminders:.*CONNECT_CANCELLED/);
  assert.match(source, /self.probingReminders \|\| self.pendingReminders \|\| self.pendingControl/);
  assert.match(source, /repeatSendTimes = 0; query.noCallback = NO/);
  assert.match(source, /self.messageReminderConfirmed = nil/);
  assert.doesNotMatch(readFileSync('ios/Runner/SayRingActivitySleepPolicy.h', 'utf8').split('static inline BOOL SRActivitySleepFeatureAllowed')[1].split('static inline BOOL SRActivitySleepCommandAllowed')[0], /health_reminders/);
});
