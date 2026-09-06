import type { HealthRecord, HealthValue } from './WearableContracts';

export interface HealthOwnerSession { ownerId: string; generation: number; }
export interface HealthUploadRequest { path: string; body: string; recordIds: string[]; }
export interface HealthSyncResult { state: string; uploaded: number; pending: number; message: string; }

export const OWNED_HEALTH_TABLE = 'wearable_owned_health';
export const OWNED_BINDING_TABLE = 'wearable_owned_binding';
export const DEVICE_CLAIM_TABLE = 'wearable_device_claim';
export const UPSERT_OWNED_HEALTH_SQL = `INSERT INTO ${OWNED_HEALTH_TABLE} ` +
  '(owner_id,record_id,device_key,metric,recorded_at,source,payload,sync_state,updated_at) VALUES (?,?,?,?,?,?,?,?,?) ' +
  'ON CONFLICT(owner_id,record_id) DO UPDATE SET payload=excluded.payload, updated_at=excluded.updated_at, ' +
  `sync_state=CASE WHEN ${OWNED_HEALTH_TABLE}.payload=excluded.payload THEN ${OWNED_HEALTH_TABLE}.sync_state ELSE excluded.sync_state END`;
export const MARK_HEALTH_UPLOADED_SQL = `UPDATE ${OWNED_HEALTH_TABLE} SET sync_state='synced' WHERE owner_id=? AND record_id=? AND payload=?`;
// The original tables remain untouched. No implicit owner is assigned at migration or login.
export const HEALTH_OWNER_SCHEMA: string[] = [
  `CREATE TABLE IF NOT EXISTS ${OWNED_HEALTH_TABLE} (` +
    'owner_id TEXT NOT NULL, record_id TEXT NOT NULL, device_key TEXT NOT NULL, metric TEXT NOT NULL, ' +
    'recorded_at INTEGER NOT NULL, source TEXT NOT NULL, payload TEXT NOT NULL, ' +
    "sync_state TEXT NOT NULL DEFAULT 'pending', updated_at INTEGER NOT NULL, PRIMARY KEY(owner_id, record_id))",
  `CREATE INDEX IF NOT EXISTS idx_owned_health_range ON ${OWNED_HEALTH_TABLE} (owner_id, device_key, metric, recorded_at)`,
  `CREATE INDEX IF NOT EXISTS idx_owned_health_pending ON ${OWNED_HEALTH_TABLE} (owner_id, sync_state, recorded_at)`,
  `CREATE TABLE IF NOT EXISTS ${OWNED_BINDING_TABLE} (` +
    'owner_id TEXT PRIMARY KEY, provider TEXT NOT NULL, device_name TEXT NOT NULL, mac TEXT NOT NULL, updated_at INTEGER NOT NULL)',
  `CREATE TABLE IF NOT EXISTS ${DEVICE_CLAIM_TABLE} (` +
    'device_key TEXT PRIMARY KEY, owner_id TEXT NOT NULL, owned_since INTEGER NOT NULL)'
];

export function validHealthOwner(owner: string): boolean {
  return /^[A-Za-z0-9_-]{1,128}$/.test(owner) && owner !== 'legacy-unscoped';
}
export function sameHealthSession(left: HealthOwnerSession, right: HealthOwnerSession): boolean {
  return validHealthOwner(left.ownerId) && left.ownerId === right.ownerId && left.generation === right.generation;
}
export function ownershipStart(previousOwner: string, previousSince: number, owner: string, now: number, resume: boolean): number {
  return resume && validHealthOwner(owner) && previousOwner === owner && previousSince > 0 && previousSince <= now ? previousSince : now;
}
export function chinaHealthDayStart(timestamp: number): number {
  return Math.floor((timestamp + 28800000) / 86400000) * 86400000 - 28800000;
}
export function recordWithinOwnership(record: HealthRecord, ownedSince: number, now: number): boolean {
  if (!Number.isFinite(ownedSince) || ownedSince <= 0 || !Number.isFinite(record.timestamp) ||
    record.timestamp < ownedSince) return false;
  // Daily totals may include a previous wearer's data before a mid-day handover.
  if (record.metric === 'activity') return chinaHealthDayStart(record.timestamp) >= ownedSince &&
    chinaHealthDayStart(record.timestamp) <= chinaHealthDayStart(now);
  return record.timestamp <= now + 60000;
}
export function chinaHealthTime(timestamp: number): string {
  return new Date(timestamp + 28800000).toISOString().slice(0, 19).replace('T', ' ');
}
function value(record: HealthRecord, names: string[]): number | undefined {
  const item = record.values.find((field: HealthValue) => names.includes(field.name));
  return item && Number.isFinite(item.value) ? item.value : undefined;
}
function put(target: Record<string, Object>, key: string, number: number | undefined): void {
  if (number !== undefined) target[key] = number;
}
function dailyRow(record: HealthRecord): Record<string, Object> {
  const date = chinaHealthTime(record.timestamp).slice(0, 16) + ':00';
  const row: Record<string, Object> = { date: date, h: date.slice(11, 13),
    hourse: date.slice(11, 16), isHourse: date.slice(14, 16) === '00' ? 1 : 0 };
  const first = record.values[0]?.value;
  if (record.metric === 'heart') {
    const heart = value(record, ['心率']);
    if (heart !== undefined) { row['heartReat'] = heart; row['pulseReat'] = [heart]; }
  } else if (record.metric === 'pressure') {
    const high = value(record, ['收缩压']), low = value(record, ['舒张压']);
    if (high !== undefined && low !== undefined) row['bloodPressure'] = { bloodPressureHigh: high, bloodPressureLow: low };
  } else if (record.metric === 'oxygen' && first !== undefined) row['bloodOxygen'] = { oxygens: [first] };
  else if (record.metric === 'glucose') put(row, 'bloodGlucose', first);
  else if (record.metric === 'temperature' && first !== undefined) row['bodyTemperature'] = { bodyTemperature: first };
  else if (record.metric === 'hrv' && first !== undefined) row['HRVData'] = [first];
  else if (record.metric === 'sleep') {
    const sleep: Record<string, Object> = {};
    put(sleep, 'allSleepTime', value(record, ['总睡眠'])); put(sleep, 'deepSleepTime', value(record, ['深睡']));
    put(sleep, 'lowSleepTime', value(record, ['浅睡'])); put(sleep, 'wakeTime', value(record, ['清醒']));
    if (Object.keys(sleep).length) row['sleepData'] = sleep;
  }
  return row;
}
export function isDailyUpload(record: HealthRecord): boolean {
  return ['heart', 'pressure', 'oxygen', 'glucose', 'temperature', 'hrv', 'sleep'].includes(record.metric);
}
export function healthUploadSupported(record: HealthRecord): boolean {
  if (!Number.isFinite(record.timestamp) || record.timestamp <= 0 || record.metric === 'sport') return false;
  if (record.metric === 'ecg') return record.values.length > 0 ||
    (record.samples.length > 1 && Number.isFinite(record.sampleFrequency) && record.sampleFrequency > 0);
  return record.values.some((field: HealthValue) => Number.isFinite(field.value));
}

export function healthUploadRequests(records: HealthRecord[]): HealthUploadRequest[] {
  const requests: HealthUploadRequest[] = [];
  const daily: Map<string, Record<string, Object>> = new Map();
  const dailyIds: string[] = [];
  records.forEach((record: HealthRecord) => {
    if (!healthUploadSupported(record)) return;
    if (isDailyUpload(record)) {
      const row = dailyRow(record), date = String(row['date']);
      const existing = daily.get(date) ?? {};
      Object.keys(row).forEach((key: string) => existing[key] = row[key]);
      daily.set(date, existing); dailyIds.push(record.id); return;
    }
    const data: Record<string, Object> = {};
    let path = '';
    if (record.metric === 'activity') {
      put(data, 'steps_num', value(record, ['步数'])); put(data, 'reliang_num', value(record, ['热量']));
      put(data, 'juli_num', value(record, ['距离']));
      path = '/api/v1/member/jrjk';
    } else if (record.metric === 'bodyComposition') {
      put(data, 'BMI', value(record, ['BMI'])); put(data, 'bodyFatRate', value(record, ['体脂率']));
      put(data, 'fatRate', value(record, ['脂肪量'])); put(data, 'muscleMass', value(record, ['肌肉量']));
      put(data, 'bodyWater', value(record, ['水分率'])); put(data, 'boneMass', value(record, ['骨量']));
      put(data, 'basalMetabolicRate', value(record, ['基础代谢'])); path = '/api/v1/member/bodycomposition';
    } else if (record.metric === 'bloodComponents') {
      put(data, 'uricAcidVal', value(record, ['尿酸'])); put(data, 'cholesterol', value(record, ['总胆固醇']));
      put(data, 'triacylglycerol', value(record, ['甘油三酯'])); put(data, 'highDensity', value(record, ['高密度脂蛋白']));
      put(data, 'lowDensity', value(record, ['低密度脂蛋白'])); path = '/api/v1/member/bloodcomposition';
    } else if (record.metric === 'ecg') {
      put(data, 'meanHeartRate', value(record, ['平均心率', '心率'])); put(data, 'averageHRV', value(record, ['HRV']));
      put(data, 'averageTimeInterval', value(record, ['QT'])); put(data, 'SDNN', value(record, ['SDNN']));
      put(data, 'RMSSD', value(record, ['RMSSD'])); data['sampleFrequency'] = record.sampleFrequency;
      data['origin'] = record.source; path = '/api/v1/member/e-c-g';
    }
    if (!path || !Object.keys(data).length) return;
    data['date'] = chinaHealthTime(record.timestamp); data['record_id'] = record.id;
    const body: Record<string, Object> = record.metric === 'activity' ? data : { data: data };
    if (record.metric === 'ecg') body['totalArray'] = record.samples;
    requests.push({ path: path, body: JSON.stringify(body), recordIds: [record.id] });
  });
  if (dailyIds.length) requests.unshift({ path: '/api/v1/member/daily-date',
    body: JSON.stringify({ dailyDate: Array.from(daily.values()) }), recordIds: dailyIds });
  return requests;
}

export function assertHealthUploadAccepted(data: Object | undefined, ids: string[]): void {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return;
  const result = data as Record<string, Object>;
  for (const key of ['rejected', 'rejectedIds', 'rejected_ids', 'failed']) {
    const rejected = result[key];
    if ((Array.isArray(rejected) && rejected.length > 0) ||
      (typeof rejected === 'number' && rejected > 0) ||
      (rejected && typeof rejected === 'object' && Object.keys(rejected).length > 0)) {
      throw new Error('部分健康记录未被接收，已保留待上传记录');
    }
  }
  const accepted = result['acceptedIds'] ?? result['accepted_ids'];
  if (Array.isArray(accepted) && ids.some((id: string) => !(accepted as Object[]).includes(id))) {
    throw new Error('健康记录接收结果不完整，已保留待上传记录');
  }
}
