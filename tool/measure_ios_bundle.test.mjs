import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { measureBundle, compareReports } from './measure_ios_bundle.mjs';

test('measures each byte once without following external symlinks', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ring-size-test-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const app = path.join(dir, 'Runner.app'), ipa = path.join(dir, 'ring.ipa');
  const fixtures = { Runner: 11, 'Frameworks/Flutter.framework/Flutter': 13, 'Frameworks/App.framework/App': 17, 'Frameworks/App.framework/flutter_assets/logo.png': 19, 'Frameworks/Vendor.framework/Vendor': 23, 'Info.plist': 29 };
  for (const [name, size] of Object.entries(fixtures)) {
    const file = path.join(app, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, Buffer.alloc(size));
  }
  fs.writeFileSync(ipa, Buffer.alloc(31));
  fs.symlinkSync(dir, path.join(app, 'external'));
  const report = measureBundle(app, ipa, 'Profile');
  assert.deepEqual(report.bytes, { runner: 11, flutterEngine: 13, dartApp: 17, vendorFrameworks: 23, assets: 19, other: 29 });
  assert.equal(report.appBytes, 112);
  assert.equal(report.ipaBytes, 31);
  assert.throws(() => measureBundle(app, ipa, 'Debug'), /Profile or Release/);
  assert.throws(() => measureBundle(dir, ipa, 'Profile'), /\.app/);
  assert.throws(() => measureBundle(app, app, 'Profile'), /\.ipa/);
});

test('comparisons reject unlike modes and preserve negative savings', () => {
  const baseline = { schema: 1, mode: 'Profile', appBytes: 100, ipaBytes: 50 };
  assert.deepEqual(compareReports({ ...baseline, appBytes: 90, ipaBytes: 55 }, baseline), { appBytesSaved: 10, ipaBytesSaved: -5, ipaPercentSaved: -10 });
  assert.throws(() => compareReports({ ...baseline, mode: 'Release' }, baseline), /matching/);
  assert.equal(compareReports(baseline, { ...baseline, ipaBytes: 0 }).ipaPercentSaved, null);
});

test('malformed baselines cannot produce misleading savings', () => {
  const report = { schema: 1, mode: 'Profile', appBytes: 100, ipaBytes: 50 };
  for (const invalid of [undefined, -1, NaN, Infinity, 1.5, '50']) {
    assert.throws(() => compareReports(report, { ...report, ipaBytes: invalid }), /non-negative integers/);
  }
  assert.throws(() => compareReports({ ...report, schema: 2 }, { ...report, schema: 2 }), /Unsupported/);
});
