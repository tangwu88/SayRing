import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {existsSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, symlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
import {assertSafeTrackedPaths, assertSayRingIdentity, createHandoff} from './handoff/create_source_handoff.mjs';

test('handoff excludes secrets, databases and generated files without blocking SDKs', () => {
  assertSafeTrackedPaths(['config/dev.json.example', 'android/libs/qring.aar', 'ios/Vendor/SDK.framework/SDK']);
  for (const path of ['../file', '/file', '.build/private.json', 'android/key.properties', 'cert.p12', 'auth.p8', '.env.production', 'data.sqlite', 'ios/Flutter/Local.xcconfig']) {
    assert.throws(() => assertSafeTrackedPaths([path]), /Unsafe/);
  }
});

test('offline handoff imports exact committed files and fails closed on corruption or existing targets', t => {
  const root = mkdtempSync(join(tmpdir(), 'say-ring-handoff-test-'));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  const repo = join(root, 'source repo');
  mkdirSync(join(repo, 'tool/handoff'), {recursive: true});
  mkdirSync(join(repo, 'docs'));
  mkdirSync(join(repo, 'android/app'), {recursive: true});
  mkdirSync(join(repo, 'ios/Flutter'), {recursive: true});
  writeFileSync(join(repo, 'android/app/build.gradle.kts'), 'applicationId = "another.product"\n');
  assert.throws(() => assertSayRingIdentity(repo), /expected Say Ring/);
  writeFileSync(join(repo, 'android/app/build.gradle.kts'), 'applicationId = "cn.saydian.ring"\n');
  for (const mode of ['Debug', 'Release']) {
    writeFileSync(join(repo, `ios/Flutter/${mode}.xcconfig`), 'SAIDIAN_BUNDLE_IDENTIFIER = cn.saydian.ring\n');
  }
  writeFileSync(join(repo, 'tool/handoff/IMPORT.sh'), readFileSync(new URL('./handoff/IMPORT.sh', import.meta.url)));
  writeFileSync(join(repo, 'docs/SAY-RING-DEVELOPER-HANDOFF-20261005.md'), '# Fixture\n');
  writeFileSync(join(repo, 'README.md'), 'offline exact source\n');
  const git = (...args) => execFileSync('git', ['-C', repo, ...args], {encoding: 'utf8'});
  git('init', '-b', 'handoff-test');
  git('add', '.');
  git('-c', 'user.name=Handoff Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-m', 'fixture');
  writeFileSync(join(repo, 'README.md'), 'dirty');
  assert.throws(() => createHandoff(repo, join(root, 'dirty-package')), /Commit/);
  writeFileSync(join(repo, 'README.md'), 'offline exact source\n');
  assert.throws(() => createHandoff(repo, join(repo, 'inside')), /outside/);
  assert.throws(() => createHandoff(repo, join(repo, '..not-parent')), /outside/);
  const alias = join(root, 'source alias');
  symlinkSync(repo, alias, 'dir');
  assert.throws(() => createHandoff(repo, join(alias, 'inside')), /outside/);
  const result = createHandoff(repo, join(root, 'handoff package'));
  assert.throws(() => createHandoff(repo, result.directory), /overwrite/);
  execFileSync('unzip', ['-tq', result.zip]);
  const target = join(root, 'imported repo');
  execFileSync('sh', [join(result.directory, 'IMPORT.sh'), target]);
  assert.equal(execFileSync('git', ['-C', target, 'rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(), result.commit);
  assert.equal(readFileSync(join(target, 'README.md'), 'utf8'), 'offline exact source\n');
  assert.notEqual(spawnSync('sh', [join(result.directory, 'IMPORT.sh'), target]).status, 0);
  assert.equal(readFileSync(join(target, 'README.md'), 'utf8'), 'offline exact source\n');
  writeFileSync(join(result.directory, 'source.bundle'), 'corrupted');
  assert.notEqual(spawnSync('sh', [join(result.directory, 'IMPORT.sh'), join(root, 'must-not-import')]).status, 0);
  assert.equal(existsSync(join(root, 'must-not-import')), false);
});
