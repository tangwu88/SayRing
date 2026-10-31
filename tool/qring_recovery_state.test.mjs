import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const method = (source, signature) => {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `missing production method ${signature}`);
  const next = source.indexOf('\n- (', start + signature.length);
  const end = source.indexOf('\n@end', start + signature.length);
  return source.slice(start, next < 0 ? end : Math.min(next, end < 0 ? next : end));
};

function withFixture(run, transform = source => source, centralTransform = source => source) {
  const bridge = transform(process.env.SAY_RING_QRING_BRIDGE_SOURCE
    ? readFileSync(process.env.SAY_RING_QRING_BRIDGE_SOURCE, 'utf8')
    : read('ios/Runner/QRingWearableBridge.m'));
  const central = centralTransform(read('ios/Runner/QCCentralManager.m'));
  const bridgeMethods = [
    '- (BOOL)isResolved', '- (void)startAutomaticRecovery',
    '- (void)scheduleRecoveryAfterDisconnect', '- (void)failConnect:',
    '- (void)didState:', '- (void)didFailConnected:', '- (void)didBluetoothState:',
  ].map(signature => method(bridge, signature)).join('\n');
  const centralMethods = [
    '- (void)setDeviceState:', '- (void)registerConnectedPeripheral:',
    '- (void)notifyConnectFailed:',
    '- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:',
    '- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:',
    '- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:',
    '- (void)centralManagerDidUpdateState:',
  ].map(signature => method(central, signature)).join('\n');
  const source = read('tool/fixtures/qring_recovery_state.m')
    .replace('// ACTUAL_BRIDGE_METHODS', bridgeMethods)
    .replace('// ACTUAL_CENTRAL_METHODS', centralMethods);
  const temporary = mkdtempSync(join(tmpdir(), 'sayring-qring-recovery-state-'));
  try {
    const file = join(temporary, 'recovery.m');
    const executable = join(temporary, 'recovery');
    writeFileSync(file, source);
    execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
      '-Wno-unused-parameter', '-framework', 'Foundation', file, '-o', executable],
    {stdio: 'pipe'});
    run(executable);
  } finally {
    rmSync(temporary, {recursive: true, force: true});
  }
}

for (const scenario of ['automatic-failure', 'sdk-registration-failure', 'sdk-unbound-cache', 'sdk-cancelled-owner',
  'explicit-failure', 'ordinary-disconnect', 'stale-callbacks', 'cancel-and-owner', 'duplicate-state']) {
  test(`actual QRing recovery callbacks: ${scenario}`, {skip: process.platform !== 'darwin'}, () => {
    withFixture(executable => {
      const output = execFileSync(executable, [scenario], {encoding: 'utf8'});
      assert.match(output, /assertions passed \(synthetic callbacks, not device timing\)/);
      process.stdout.write(output);
    });
  });
}

test('Bluetooth off/reset retires stale transport and recovers exact target',
  {skip: process.platform !== 'darwin'}, () => {
    withFixture(executable => {
      const output = execFileSync(executable, ['power-state-recovery'], {encoding: 'utf8'});
      assert.match(output, /targetPreserved=YES/);
      process.stdout.write(output);
    });
  });

test('removing only the handshake cooldown rejects the original callback race',
  {skip: process.platform !== 'darwin'}, () => {
    withFixture(executable => {
      for (const scenario of ['automatic-failure', 'sdk-registration-failure']) {
        assert.throws(() => execFileSync(executable, [scenario], {stdio: 'pipe'}),
          error => error.status === 1 && /failed handshake must preserve the two-second cooldown/.test(error.stderr.toString()));
      }
      process.stdout.write('QRing missing-handshake-cooldown negative control rejected\n');
    }, source => {
      const block = /        BOOL handshakeInterrupted = \(self\.pendingConnect \|\| self\.recoveryConnecting\) &&\s*!self\.pendingDisconnect && !self\.cancellingConnection;\s*if \(handshakeInterrupted\) \{\s*self\.recoveryRetryNotBefore = MAX\(self\.recoveryRetryNotBefore,\s*NSProcessInfo\.processInfo\.systemUptime \+ 2\);\s*\}/;
      assert.match(source, block, 'production handshake cooldown must be present for the negative control');
      // Keep the captured flag for production debug tracing, so the negative
      // control fails on behavior rather than an undeclared local variable.
      return source.replace(block, value => value.slice(0, value.indexOf('\n        if (handshakeInterrupted)')));
    });
  });


test('failed live transport cannot be reused before actual closure', {skip: process.platform !== 'darwin'}, () => {
  withFixture(executable => {
    assert.throws(() => execFileSync(executable, ['sdk-registration-failure'], {stdio: 'pipe'}),
      error => error.status === 1 && /SDK failure on a live radio must cancel/.test(error.stderr.toString()));
  }, source => {
    const needle = 'if (handshakeInterrupted && failed && failed.state != CBPeripheralStateDisconnected)';
    assert.ok(source.includes(needle));
    return source.replace(needle, 'if (NO && handshakeInterrupted && failed && failed.state != CBPeripheralStateDisconnected)');
  });
});

test('repeated native state must not repeat preparation or recovery', {skip: process.platform !== 'darwin'}, () => {
  withFixture(executable => {
    assert.throws(() => execFileSync(executable, ['duplicate-state'], {stdio: 'pipe'}),
      error => error.status === 1 && /same connected state must not restart/.test(error.stderr.toString()));
  }, source => source, source => {
    const needle = '    if (_deviceState == deviceState) { return; }';
    assert.ok(source.includes(needle));
    return source.replace(needle, '');
  });
});
