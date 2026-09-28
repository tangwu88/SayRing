import { ApiError } from './Contracts';
import type { AppUpdateInfo } from './ExperienceContracts';
import { GLOBAL_BUNDLE, GLOBAL_DOWNLOAD_PAGE } from './GlobalConfiguration';

export function parseGlobalUpdate(data: Object | undefined, currentBuild: number): AppUpdateInfo {
  const root = data as Record<string, Object>;
  if (!root || root['realm'] !== 'global' || root['schemaVersion'] !== 1 || !Array.isArray(root['releases'])) {
    throw new ApiError('update_unavailable', 503);
  }
  const release = (root['releases'] as Record<string, Object>[]).find(item => item['platform'] === 'harmonyos');
  if (!release || release['packageId'] !== GLOBAL_BUNDLE ||
    typeof release['versionName'] !== 'string' || !Number.isSafeInteger(release['buildNumber']) ||
    Number(release['buildNumber']) <= 0) throw new ApiError('update_unavailable', 503);
  if (release['status'] !== 'available') {
    return { latestVersion: String(release['versionName']), latestBuild: currentBuild,
      minimumSupportedBuild: 0, releaseNotes: '', destinationUrl: '', hasUpdate: false, required: false };
  }
  const destination = release['destination'] as Record<string, Object>;
  if (!destination || !['direct', 'market'].includes(String(destination['kind'] ?? ''))) {
    throw new ApiError('update_unavailable', 503);
  }
  if (destination['kind'] === 'direct') {
    const fileName = String(destination['fileName'] ?? ''), path = String(destination['url'] ?? '');
    const validPath = path === `/global/down/files/${fileName}` ||
      path === `/global/api/saydian-app/v2/support/app-package/${fileName}`;
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]*\.hap$/.test(fileName) || fileName.includes('..') ||
      !validPath || !/^[a-f0-9]{64}$/i.test(String(destination['sha256'] ?? '')) ||
      !Number.isSafeInteger(destination['sizeBytes']) || Number(destination['sizeBytes']) <= 0) {
      throw new ApiError('update_unavailable', 503);
    }
  } else {
    const marketUrl = String(destination['url'] ?? '');
    if (!/^https:\/\/[^/@\s]+(?:\/|$)/.test(marketUrl) || marketUrl.includes('\\')) {
      throw new ApiError('update_unavailable', 503);
    }
  }
  return { latestVersion: String(release['versionName']), latestBuild: Number(release['buildNumber']),
    minimumSupportedBuild: 0, releaseNotes: '', destinationUrl: GLOBAL_DOWNLOAD_PAGE,
    hasUpdate: currentBuild < Number(release['buildNumber']), required: false };
}
