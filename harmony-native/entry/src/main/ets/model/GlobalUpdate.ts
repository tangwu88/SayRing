import { ApiError } from './Contracts';
import type { AppUpdateInfo } from './ExperienceContracts';
import { GLOBAL_BUNDLE, GLOBAL_ORIGIN } from './GlobalConfiguration';

export function parseGlobalUpdate(data: Object | undefined, currentBuild: number): AppUpdateInfo {
  const root = data as Record<string, Object>;
  if (!root || root['realm'] !== 'global' || root['schemaVersion'] !== 1 || !Array.isArray(root['releases'])) {
    throw new ApiError('update_unavailable', 503);
  }
  const release = (root['releases'] as Record<string, Object>[]).find(item => item['platform'] === 'harmonyos');
  if (!release || release['packageId'] !== GLOBAL_BUNDLE || release['status'] !== 'available' ||
    typeof release['versionName'] !== 'string' || !Number.isSafeInteger(release['buildNumber']) ||
    Number(release['buildNumber']) <= 0) throw new ApiError('update_unavailable', 503);
  const destination = release['destination'] as Record<string, Object>;
  if (!destination || destination['kind'] !== 'direct') throw new ApiError('update_unavailable', 503);
  const fileName = String(destination['fileName'] ?? ''), path = String(destination['url'] ?? '');
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*\.hap$/.test(fileName) || fileName.includes('..') ||
    path !== `/global/down/files/${fileName}` || !/^[a-f0-9]{64}$/i.test(String(destination['sha256'] ?? '')) ||
    !Number.isSafeInteger(destination['sizeBytes']) || Number(destination['sizeBytes']) <= 0) {
    throw new ApiError('update_unavailable', 503);
  }
  return { latestVersion: String(release['versionName']), latestBuild: Number(release['buildNumber']),
    minimumSupportedBuild: 0, releaseNotes: '', destinationUrl: GLOBAL_ORIGIN + path,
    hasUpdate: currentBuild < Number(release['buildNumber']), required: false };
}
