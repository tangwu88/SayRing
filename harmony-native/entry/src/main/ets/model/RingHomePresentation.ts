import type { HealthRecord, WearableCapabilities, WearableMetricKey, WearableSnapshot, WearableConnectionPhase } from './WearableContracts';

export function ringMetricSupported(caps: WearableCapabilities, key: WearableMetricKey): boolean {
  if (key === 'activity') return caps.activity;
  if (key === 'sleep') return caps.sleep;
  if (key === 'heart') return caps.heart;
  if (key === 'oxygen') return caps.oxygen;
  if (key === 'pressure') return caps.pressure;
  if (key === 'glucose') return caps.glucose;
  if (key === 'temperature') return caps.temperature;
  if (key === 'hrv') return caps.hrv;
  if (key === 'ecg') return caps.ecg;
  if (key === 'bodyComposition') return caps.bodyComposition;
  if (key === 'bloodComponents') return caps.bloodComponents;
  return caps.sport;
}

export function ringMetricVisible(snapshot: WearableSnapshot, phase: WearableConnectionPhase, key: WearableMetricKey): boolean {
  return snapshot.connected && !!snapshot.deviceKey && (phase === 'connected' || phase === 'syncing') &&
    key !== 'sport' && ringMetricSupported(snapshot.capabilities, key);
}

export interface RingActivitySummary { steps?: number; distance?: number; calories?: number; }
export function ringTodayActivity(records: HealthRecord[], deviceKey: string, now: number): RingActivitySummary {
  if (!deviceKey || !Number.isFinite(now)) return {};
  const day = new Date(now).toDateString();
  const current = records.filter(record => record.deviceKey === deviceKey && record.metric === 'activity' &&
    Number.isFinite(record.timestamp) && record.timestamp <= now + 1000 && new Date(record.timestamp).toDateString() === day)
    .sort((a, b) => b.timestamp - a.timestamp);
  return ringActivitySummary(current[0]);
}
export function ringActivitySummary(record: HealthRecord | undefined): RingActivitySummary {
  const summary: RingActivitySummary = {};
  if (!record || record.metric !== 'activity') return summary;
  for (const item of record.values) {
    if (!Number.isFinite(item.value) || item.value < 0) continue;
    if (['steps', '步数'].includes(item.name) && ['steps', '步', ''].includes(item.unit)) summary.steps = item.value;
    if (['distance', '距离'].includes(item.name) && ['km', '公里'].includes(item.unit)) summary.distance = item.value;
    if (['distance', '距离'].includes(item.name) && ['m', '米'].includes(item.unit)) summary.distance = item.value / 1000;
    if (['calories', '热量', '卡路里'].includes(item.name) && ['kcal', '千卡'].includes(item.unit)) summary.calories = item.value;
  }
  return summary;
}
export function ringActivityText(value: number | undefined, decimals: number = 0): string {
  return value === undefined || !Number.isFinite(value) ? '--' : value.toFixed(decimals);
}
export function ringActivityProgress(value: number | undefined, goal: number): number {
  return value === undefined || !Number.isFinite(value) || !Number.isFinite(goal) || goal <= 0 ? 0 : Math.max(0, Math.min(100, value * 100 / goal));
}
