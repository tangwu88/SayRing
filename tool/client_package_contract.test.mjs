import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';

const read = path => fs.readFileSync(path, 'utf8');
const sha = path => crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex');

test('packaging does not alter the supplied branding originals', () => {
  assert.equal(sha('assets/branding/ai-health-manager-doctor.png'), 'd57f2b5edb7ce3bed6d31cca21f47d2d2f464da9e7db19a7c36d8423219e7f3c');
  assert.equal(sha('assets/branding/saidian-brand-lockup.png'), '376bc24d9f7ea1d49f1e9b8896bc8bbd5b209d969305db480f715d181a121ebc');
  const manifest = read('pubspec.yaml');
  assert.doesNotMatch(manifest, /- assets\/branding\/saidian-brand-lockup\.png/);
  assert.doesNotMatch(manifest, /- assets\/branding\/ai-health-manager-doctor\.png/);
  assert.match(manifest, /- assets\/branding\/ai-health-manager-doctor-optimized\.png/);
  assert.ok(fs.statSync('assets/branding/ai-health-manager-doctor-optimized.png').size < fs.statSync('assets/branding/ai-health-manager-doctor.png').size);
  assert.match(read('lib/ui/pages/dashboard.dart'), /ai-health-manager-doctor-optimized\.png/);
});

test('non-Debug packaging strips only local symbols and keeps dSYM', () => {
  const project = read('ios/Runner.xcodeproj/project.pbxproj');
  for (const id of ['249021D4217E4FDB00AE95B9', '97C147071CF9000F007C117D']) {
    const start = project.indexOf(id + ' /*');
    const block = project.slice(start, project.indexOf('\n\t\t};', start));
    assert.match(block, /ENABLE_TESTABILITY = NO;/);
    assert.match(block, /DEPLOYMENT_POSTPROCESSING = YES;/);
    assert.match(block, /STRIP_INSTALLED_PRODUCT = YES;/);
    assert.match(block, /STRIP_STYLE = "non-global";/);
  }
  const debugStart = project.indexOf('97C147061CF9000F007C117D /* Debug */ =');
  const debug = project.slice(debugStart, project.indexOf('\n\t\t};', debugStart));
  assert.doesNotMatch(debug, /DEPLOYMENT_POSTPROCESSING = YES;/);
  assert.doesNotMatch(debug, /ENABLE_TESTABILITY = NO;/);
  assert.match(project, /DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";/);
  assert.match(read('.github/workflows/ci.yml'), /-configuration Debug/);
  assert.match(read('ios/RunnerTests/RunnerTests.swift'), /@testable import Runner/);
});
