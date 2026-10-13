import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [original, prepared] = process.argv.slice(2);
if (!original || !prepared) {
  throw new Error('Usage: node tool/verify_qring_sdk_copy.mjs ORIGINAL_AAR PREPARED_AAR');
}
const entries = path => execFileSync('unzip', ['-Z1', path], {encoding: 'utf8'})
  .trim().split('\n').filter(name => !name.endsWith('/')).sort();
const read = (path, name) => execFileSync('unzip', ['-p', path, name], {maxBuffer: 64 * 1024 * 1024});
const names = entries(original);
assert.deepEqual(entries(prepared), names, 'SDK file entries must be unchanged');
for (const name of names) {
  const before = read(original, name);
  const after = read(prepared, name);
  if (name !== 'proguard.txt') {
    assert.ok(before.equals(after), `SDK content changed: ${name}`);
    continue;
  }
  const lines = buffer => buffer.toString('utf8').split(/\r?\n/).filter(line => line.trim());
  const sourceRules = lines(before);
  assert.equal(sourceRules.filter(line => line.trim() === '-printmapping map.txt').length, 2);
  assert.deepEqual(lines(after), sourceRules.filter(line => line.trim() !== '-printmapping map.txt'),
    'Only the two vendor mapping-output directives may be removed');
}
console.log(`QRing SDK copy verified: ${names.length} unchanged entries; only mapping-output rules removed`);
