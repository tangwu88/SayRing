import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {after, before, test} from 'node:test';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const source = read('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java');
const productionMethod = name => {
  const match = new RegExp('\\n    private [^\\n]+ ' + name + '\\(').exec(source);
  assert.ok(match, 'Missing production method: ' + name);
  let end = source.indexOf('{', match.index), depth = 0;
  for (; end < source.length; end++) {
    if (source[end] === '{') depth++;
    else if (source[end] === '}' && --depth === 0) return source.slice(match.index, end + 1);
  }
  throw new Error('Unclosed production method: ' + name);
};

let folder;
let javaHome = process.env.JAVA_HOME;
if (!javaHome && process.platform === 'darwin') {
  javaHome = execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding:'utf8'}).trim();
}
const java = name => javaHome ? join(javaHome, 'bin', name) : name;

before(() => {
  const names = ['onHrvValues', 'onStressCompatValues', 'setMeasurement'];
  // Include the old timer method when running this regression against an old
  // checkout, so failures prove protocol behavior instead of missing stubs.
  if (source.includes('private void cancelHrvFallback(')) names.push('cancelHrvFallback');
  const methods = names.map(productionMethod).join('\n');
  folder = mkdtempSync(join(tmpdir(), 'sayring-coolwear-hrv-'));
  const file = join(folder, 'CoolWearHrvProtocolHarness.java');
  writeFileSync(file, read('tool/fixtures/CoolWearHrvProtocolHarness.java')
    .replace('// PRODUCTION_METHODS', methods));
  execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-d', folder, file], {stdio:'pipe'});
});

after(() => { if (folder) rmSync(folder, {recursive:true, force:true}); });

for (const [scenario, title] of [
  ['legacy-hrv', 'legacy type 45 cannot emit or collect HRV while a manual HRV session is active'],
  ['hrv-command', 'HRV starts and stops only the explicit RRI protocol without touching stress type 45'],
  ['rri-fields', 'new RRI callback preserves explicit SDNN, RMSSD and RRI milliseconds'],
  ['stress-compat', 'legacy stress compatibility retains its existing range and commands'],
  ['callback-guards', 'inactive, disconnected and already completed manual sessions reject legacy callbacks'],
]) {
  test(title, () => {
    const result = spawnSync(java('java'), ['-cp', folder,
      'cc.saidian.saydian_app.CoolWearHrvProtocolHarness', scenario], {encoding:'utf8'});
    assert.equal(result.status, 0, result.stderr);
    process.stdout.write(result.stdout);
  });
}
