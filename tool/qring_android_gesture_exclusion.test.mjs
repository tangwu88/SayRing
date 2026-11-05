import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync} from 'node:fs';
import {execFileSync, spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {tmpdir} from 'node:os';

test('production QRing gesture writes confirm the other channel is closed before enabling', () => {
  const base = 'android/app/src/main/java/cc/saidian/saydian_app/';
  const source = readFileSync(base + 'QRingBridge.java', 'utf8');
  const names = ['gestureControl', 'closeOtherGestureControl', 'readOtherGestureClosed',
    'finishGestureAfterSettling', 'readGestureBack'];
  const method = name => {
    const start = new RegExp('\\n    private [^\\n]+ ' + name + '\\(').exec(source);
    assert.ok(start, name);
    const next = /\n    (?:private|public|protected) /.exec(source.slice(start.index + 1));
    return source.slice(start.index, next ? start.index + 1 + next.index : source.length);
  };
  const methods = names.map(method).join('\n');
  const folder = mkdtempSync(join(tmpdir(), 'sayring-qring-exclusion-'));
  const java = tool => process.env.JAVA_HOME ? join(process.env.JAVA_HOME, 'bin', tool) : tool;
  const fixture = readFileSync('tool/fixtures/QRingGestureExclusionHarness.java', 'utf8');
  try {
    const file = join(folder, 'QRingGestureExclusionHarness.java');
    const policies = ['QRingGesturePolicy', 'QRingCameraPolicy', 'QRingControlChannelState']
      .map(name => base + name + '.java');
    const run = body => {
      writeFileSync(file, fixture.replace('// PRODUCTION_METHODS', body));
      execFileSync(java('javac'), ['-encoding', 'UTF-8', '-Xlint:all', '-Werror', '-d', folder, file, ...policies]);
      return spawnSync(java('java'), ['-ea', '-cp', folder,
        'cc.saidian.saydian_app.QRingGestureExclusionHarness'], {encoding: 'utf8'});
    };
    const good = run(methods);
    assert.equal(good.status, 0, good.stderr);
    assert.match(good.stdout, /QRing exclusion PASS/);
    // Reproduce the old transition: immediately continue after changing only
    // the selected mode. The active second channel must make the test fail.
    const oldTransition = methods.replace('if (!supported) {', 'if (true) {');
    assert.notEqual(oldTransition, methods);
    const bad = run(oldTransition);
    assert.equal(bad.status, 1, bad.stderr);
    assert.match(bad.stderr, /other channel must close before selected write/);
  } finally { rmSync(folder, {recursive: true, force: true}); }
});
