import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Measures unthinned local artifacts, not App Store download size.
export function measureBundle(appPath, ipaPath, mode) {
  if (!['Profile', 'Release'].includes(mode)) throw new Error('Use Profile or Release');
  if (!appPath.endsWith('.app') || !fs.lstatSync(appPath).isDirectory()) {
    throw new Error('Expected an existing .app directory');
  }
  if (!ipaPath.endsWith('.ipa') || !fs.lstatSync(ipaPath).isFile()) {
    throw new Error('Expected an existing .ipa file');
  }
  const bytes = { runner: 0, flutterEngine: 0, dartApp: 0, vendorFrameworks: 0, assets: 0, other: 0 };
  function walk(dir, prefix = '') {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const relative = prefix + entry.name;
      const full = path.join(dir, entry.name);
      // Symlink contents must not be followed or counted twice.
      if (entry.isSymbolicLink()) continue;
      if (entry.isDirectory()) { walk(full, relative + '/'); continue; }
      if (!entry.isFile()) continue;
      let bucket = 'other';
      if (relative === 'Runner') bucket = 'runner';
      else if (relative.includes('/flutter_assets/')) bucket = 'assets';
      else if (relative.startsWith('Frameworks/Flutter.framework/')) bucket = 'flutterEngine';
      else if (relative.startsWith('Frameworks/App.framework/')) bucket = 'dartApp';
      else if (relative.startsWith('Frameworks/')) bucket = 'vendorFrameworks';
      bytes[bucket] += fs.statSync(full).size;
    }
  }
  walk(appPath);
  return { schema: 1, mode, appBytes: Object.values(bytes).reduce((a, b) => a + b, 0), ipaBytes: fs.statSync(ipaPath).size, bytes };
}

export function compareReports(current, baseline) {
  if (current.schema !== baseline.schema || current.mode !== baseline.mode) {
    throw new Error('Comparison requires matching schema and build mode');
  }
  for (const report of [current, baseline]) {
    if (report.schema !== 1 || !['Profile', 'Release'].includes(report.mode)) {
      throw new Error('Unsupported size report');
    }
    if (![report.appBytes, report.ipaBytes].every(value => Number.isSafeInteger(value) && value >= 0)) {
      throw new Error('Size report bytes must be non-negative integers');
    }
  }
  return {
    appBytesSaved: baseline.appBytes - current.appBytes,
    ipaBytesSaved: baseline.ipaBytes - current.ipaBytes,
    ipaPercentSaved: baseline.ipaBytes > 0 ? 100 * (baseline.ipaBytes - current.ipaBytes) / baseline.ipaBytes : null,
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [app, ipa, mode, baselinePath] = process.argv.slice(2);
    if (!app || !ipa || !mode) throw new Error('Usage: node tool/measure_ios_bundle.mjs APP IPA Profile|Release [BASELINE_JSON]');
    const report = measureBundle(app, ipa, mode);
    if (baselinePath) report.comparison = compareReports(report, JSON.parse(fs.readFileSync(baselinePath, 'utf8')));
    console.log(JSON.stringify(report, null, 2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
