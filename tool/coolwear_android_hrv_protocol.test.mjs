import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {after, before, test} from 'node:test';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const source = read('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java');
const mapper = read('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRecordMapper.java');
const productionMethods = (text, name) => {
  const matches = [...text.matchAll(new RegExp('\\n    (?:private|public) [^\\n]+ ' + name + '\\(', 'g'))];
  assert.ok(matches.length, 'Missing production method: ' + name);
  return matches.map(match => {
    let end = text.indexOf('{', match.index), depth = 0;
    for (; end < text.length; end++) {
      if (text[end] === '{') depth++;
      else if (text[end] === '}' && --depth === 0) return text.slice(match.index, end + 1);
    }
    throw new Error('Unclosed production method: ' + name);
  }).join('\n');
};

let folder;
let javaHome = process.env.JAVA_HOME;
if (!javaHome && process.platform === 'darwin') {
  javaHome = execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding:'utf8'}).trim();
}
const java = name => javaHome ? join(javaHome, 'bin', name) : name;

before(() => {
  const names = ['onHrvValues', 'onStressCompatValues', 'setMeasurement', 'emitMeasurement'];
  // Include the old timer method when running this regression against an old
  // checkout, so failures prove protocol behavior instead of missing stubs.
  if (source.includes('private void cancelHrvFallback(')) names.push('cancelHrvFallback');
  const methods = names.map(name => productionMethods(source, name)).join('\n');
  folder = mkdtempSync(join(tmpdir(), 'sayring-coolwear-hrv-'));
  const file = join(folder, 'CoolWearHrvProtocolHarness.java');
  writeFileSync(file, read('tool/fixtures/CoolWearHrvProtocolHarness.java')
    .replace('// PRODUCTION_METHODS', methods)
    .replace('// PRODUCTION_RECORD_METHOD', productionMethods(mapper, 'healthRecord')));
  execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-d', folder, file], {stdio:'pipe'});
});

after(() => { if (folder) rmSync(folder, {recursive:true, force:true}); });

for (const [scenario, title] of [
  ['legacy-hrv', 'legacy type 45 cannot emit or collect HRV while a manual HRV session is active'],
  ['hrv-command', 'HRV starts and stops only the explicit RRI protocol without touching stress type 45'],
  ['rri-fields', 'new RRI callback preserves explicit SDNN, RMSSD and RRI milliseconds'],
  ['rri-quality', 'invalid RRI quality or sample counts cannot complete a manual measurement'],
  ['rri-quality-boundaries', 'valid RRI quality and sample boundaries retain the actual SDK fields'],
  ['rri-version', 'real HRV emission uses version 2 and retains the original record provenance'],
  ['other-versions', 'real non-HRV measurement emissions preserve version 1'],
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
