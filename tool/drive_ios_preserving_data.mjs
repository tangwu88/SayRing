import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

// Flutter drive's default cleanup uninstalls the app, even after a failed test.
// Only drive an explicitly selected, already verified binary and retain it.
export function preservingDriveArgs(args) {
  if (args.some(arg => arg === '--no-keep-app-running' || arg === '--uninstall-only')) {
    throw new Error('Destructive integration-test cleanup is prohibited');
  }
  const binaries = args.filter(arg => arg.startsWith('--use-application-binary='));
  if (binaries.length !== 1 || !binaries[0].slice('--use-application-binary='.length).trim()) {
    throw new Error('Use an explicitly verified signed Profile application binary');
  }
  if (!args.includes('--profile') || args.includes('--debug') || args.includes('--release')) {
    throw new Error('Only verified Profile device tests are allowed');
  }
  return ['drive', '--keep-app-running', ...args.filter(arg => arg !== '--keep-app-running')];
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const args = preservingDriveArgs(process.argv.slice(2));
    const result = spawnSync(process.env.FLUTTER_BIN ?? 'flutter', args, {stdio: 'inherit'});
    if (result.error) throw result.error;
    process.exitCode = result.status ?? 1;
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
