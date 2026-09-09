export const DEFAULT_API_READ_TIMEOUT_MS: number = 15000;
export const AI_API_READ_TIMEOUT_MS: number = 5 * 60 * 1000;

export function apiReadTimeout(milliseconds: number | undefined): number {
  if (milliseconds === undefined) return DEFAULT_API_READ_TIMEOUT_MS;
  if (!Number.isSafeInteger(milliseconds) || milliseconds < DEFAULT_API_READ_TIMEOUT_MS ||
    milliseconds > AI_API_READ_TIMEOUT_MS) return DEFAULT_API_READ_TIMEOUT_MS;
  return milliseconds;
}
