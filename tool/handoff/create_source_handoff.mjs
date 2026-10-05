import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, writeFileSync} from 'node:fs';
import {basename, dirname, isAbsolute, join, relative, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';

const checksum = data => createHash('sha256').update(data).digest('hex');
const git = (repo, args) => execFileSync('git', ['-C', repo, ...args], {
  encoding: 'utf8', maxBuffer: 32 * 1024 * 1024,
});

export function assertSafeTrackedPaths(paths) {
  const forbidden = /(^|\/)(?:\.env(?:\..*)?|\.build|build|\.dart_tool|node_modules|Pods|Local\.xcconfig|local\.properties|key\.properties|dev\.json|credentials[^/]*|[^/]*\.(?:p12|p8|jks|keystore|mobileprovision|db|sqlite|sqlite3))($|\/)/i;
  for (const path of paths) {
    if (isAbsolute(path) || path.split('/').includes('..') || forbidden.test(path)) {
      throw new Error(`Unsafe tracked handoff path: ${path}`);
    }
  }
}

export function assertSayRingIdentity(repo) {
  const declarations = [
    ['android/app/build.gradle.kts', /applicationId\s*=\s*"cn\.saydian\.ring"/],
    ['ios/Flutter/Debug.xcconfig', /^SAIDIAN_BUNDLE_IDENTIFIER\s*=\s*cn\.saydian\.ring\s*$/m],
    ['ios/Flutter/Release.xcconfig', /^SAIDIAN_BUNDLE_IDENTIFIER\s*=\s*cn\.saydian\.ring\s*$/m],
  ];
  for (const [path, expected] of declarations) {
    if (!existsSync(join(repo, path)) || !expected.test(readFileSync(join(repo, path), 'utf8'))) {
      throw new Error(`Not the expected Say Ring product: ${path}`);
    }
  }
}

export function createHandoff(repoPath, destination) {
  const repo = realpathSync(git(resolve(repoPath), ['rev-parse', '--show-toplevel']).trim());
  const output = join(realpathSync(dirname(resolve(destination))), basename(destination));
  const within = relative(repo, output);
  if (within === '' || (!isAbsolute(within) && within !== '..' && !within.startsWith(`..${sep}`))) {
    throw new Error('Handoff must be outside the source worktree');
  }
  if (existsSync(output) || existsSync(`${output}.zip`)) {
    throw new Error('Refusing to overwrite an existing handoff');
  }
  if (git(repo, ['status', '--porcelain']).trim()) {
    throw new Error('Commit and verify the worktree before packaging');
  }
  const commit = git(repo, ['rev-parse', 'HEAD']).trim();
  const branch = git(repo, ['symbolic-ref', '--short', 'HEAD']).trim();
  git(repo, ['check-ref-format', `refs/heads/${branch}`]);
  const paths = git(repo, ['ls-files', '-z']).split('\0').filter(Boolean);
  assertSafeTrackedPaths(paths);
  assertSayRingIdentity(repo);

  // Scan the tracked snapshot only. This is not a full history/security audit.
  const obviousSecret = /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{36,}\b|\bAKIA[A-Z0-9]{16}\b/;
  for (const path of paths) {
    const file = join(repo, path);
    const stat = lstatSync(file);
    if (!stat.isSymbolicLink() && stat.size <= 2 * 1024 * 1024 && obviousSecret.test(readFileSync(file, 'utf8'))) {
      throw new Error(`Potential secret in tracked source: ${path}`);
    }
  }
  mkdirSync(output);
  git(repo, ['bundle', 'create', join(output, 'source.bundle'), `refs/heads/${branch}`]);
  writeFileSync(join(output, 'IMPORT.sh'), readFileSync(join(repo, 'tool/handoff/IMPORT.sh')), {mode: 0o755});
  writeFileSync(join(output, 'COMMIT.txt'), `${commit}\n`);
  writeFileSync(join(output, 'BRANCH.txt'), `${branch}\n`);
  writeFileSync(join(output, 'README.md'), readFileSync(join(repo, 'docs/SAY-RING-DEVELOPER-HANDOFF-20261005.md')));
  writeFileSync(join(output, 'MANIFEST.json'), JSON.stringify({
    product: 'Say Ring', bundleId: 'cn.saydian.ring', commit, branch,
    source: 'https://github.com/tangwu88/SayRing.git',
    format: 'offline Git bundle; current branch and its reachable history only',
    trackedFiles: paths.length,
    excluded: ['untracked/ignored files', 'signing keys', 'machine configuration', 'device backups', 'photos and health databases', 'build output'],
    securityBoundary: 'Snapshot path and obvious-secret checks are not a full history audit. Vendor SDKs are licensed; use only for authorized Say Ring development.',
  }, null, 2) + '\n');
  const files = ['source.bundle', 'IMPORT.sh', 'COMMIT.txt', 'BRANCH.txt', 'README.md', 'MANIFEST.json'];
  writeFileSync(join(output, 'SHA256SUMS.txt'), files.map(name => `${checksum(readFileSync(join(output, name)))}  ${name}`).join('\n') + '\n');
  if (git(repo, ['rev-parse', 'HEAD']).trim() !== commit || git(repo, ['status', '--porcelain']).trim()) {
    throw new Error('Source changed while packaging; keep the partial directory for inspection and retry with a new output');
  }
  execFileSync('zip', ['-q', '-9', `${output}.zip`, ...files, 'SHA256SUMS.txt'], {cwd: output});
  const zipHash = checksum(readFileSync(`${output}.zip`));
  writeFileSync(`${output}.zip.sha256`, `${zipHash}  ${output.split('/').at(-1)}.zip\n`);
  return {commit, branch, directory: output, zip: `${output}.zip`, sha256: zipHash};
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 4) throw new Error('Usage: node tool/handoff/create_source_handoff.mjs REPO NEW_ABSOLUTE_OUTPUT_DIRECTORY');
  console.log(JSON.stringify(createHandoff(process.argv[2], process.argv[3]), null, 2));
}
