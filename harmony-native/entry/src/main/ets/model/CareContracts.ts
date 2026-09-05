import { ApiError, stableIdentity } from './Contracts';

// Only these normalized values reach ArkUI. Raw account rows/tokens are never retained.
export interface CareMember { relationId: number; memberId: number; name: string; mobile: string; }
export interface CareInvitation { id: number; inviterId: number; name: string; mobile: string; state: string; }
export interface CareOption { key: string; label: string; }
export interface CareShareSettings { enabled: string[]; unknown: string[]; }
export interface CareMetricSpec { key: string; title: string; endpoint: string; type: string; unit: string; }
export interface CareField { label: string; value: number; unit: string; }
export interface CareRecord { id: string; time: string; order: number; fields: CareField[]; samples: number[]; frequency: number; }
export interface CareMetric { key: string; title: string; unit: string; state: string; message: string; records: CareRecord[]; }

export const CARE_OPTIONS: CareOption[] = [
  { key: 'steps', label: '步数' }, { key: 'reliang', label: '卡路里' }, { key: 'juli', label: '距离' },
  { key: 'sleep', label: '总睡眠' }, { key: 'bloodPressure', label: '血压' }, { key: 'bloodGlucose', label: '血糖' },
  { key: 'bloodOxygen', label: '血氧' }, { key: 'bodyTemperature', label: '体温' }, { key: 'ecg', label: '心电图' },
  { key: 'heartReat', label: '心率' }, { key: 'HRV', label: 'HRV' },
  { key: 'bodycomposition', label: '身体成分' }, { key: 'bloodcomposition', label: '血液成分' }
];

export function careGroupOptions(daily: boolean): CareOption[] {
  return daily ? CARE_OPTIONS.slice(0, 4) : CARE_OPTIONS.slice(4);
}

export function toggleCareGroup(settings: CareShareSettings, daily: boolean): CareShareSettings {
  const keys = careGroupOptions(daily).map((option: CareOption) => option.key);
  const all = keys.every((key: string) => settings.enabled.includes(key));
  const enabled = settings.enabled.filter((key: string) => !keys.includes(key));
  return { enabled: all ? enabled : [...enabled, ...keys], unknown: [...settings.unknown] };
}
const DAILY: string = '/api/v1/member/daily-date/preview';
export const CARE_METRICS: CareMetricSpec[] = [
  { key: 'heart', title: '心率', endpoint: DAILY, type: 'pulseReat', unit: '次/分' },
  { key: 'pressure', title: '血压', endpoint: DAILY, type: 'BloodPressure', unit: 'mmHg' },
  { key: 'glucose', title: '血糖', endpoint: DAILY, type: 'BloodGlucose', unit: 'mmol/L' },
  { key: 'oxygen', title: '血氧', endpoint: DAILY, type: 'bloodOxygen', unit: '%' },
  { key: 'temperature', title: '体温', endpoint: DAILY, type: 'BodyTemperature', unit: '℃' },
  { key: 'hrv', title: 'HRV', endpoint: DAILY, type: 'HRV', unit: 'ms' },
  { key: 'sleep', title: '睡眠', endpoint: DAILY, type: 'sleep', unit: '分钟' },
  { key: 'ecg', title: '心电', endpoint: '/api/v1/member/e-c-g/preview', type: '', unit: '' },
  { key: 'body', title: '身体成分', endpoint: '/api/v1/member/bodycomposition/preview', type: '', unit: '' },
  { key: 'blood', title: '血液成分', endpoint: '/api/v1/member/bloodcomposition/preview', type: '', unit: '' }
];

function object(value: Object | undefined): Record<string, Object> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Object> : {};
}
function text(value: Object | undefined, limit: number = 128): string {
  return typeof value === 'string' ? value.replace(/[\x00-\x1f\x7f]/g, '').trim().slice(0, limit) : '';
}
export function careId(value: Object | undefined): number {
  if (typeof value !== 'string' && typeof value !== 'number') return 0;
  const id = stableIdentity(value);
  if (!/^\d+$/.test(id)) return 0;
  const number = Number(id);
  return Number.isSafeInteger(number) && number > 0 ? number : 0;
}
function list(data: Object | undefined): Object[] {
  const values = Array.isArray(data) ? data : object(data)['list'];
  if (!Array.isArray(values)) throw new ApiError('关爱列表格式异常，请重新读取');
  return values as Object[];
}
export function parseCareMembers(data: Object | undefined, ownId: string): CareMember[] {
  const result: CareMember[] = [];
  const seen: Set<number> = new Set();
  list(data).forEach((raw: Object) => {
    const row = object(raw);
    const member = object(row['member'] ?? row['to_member'] ?? row['care_member']);
    const relationId = careId(row['id']);
    const memberId = careId(row['to_member_id']) || careId(member['id']);
    if (!relationId || !memberId) throw new ApiError('关爱成员身份不完整，请重新读取');
    if (String(memberId) === ownId) return;
    if (seen.has(relationId)) {
      if (result.some((item: CareMember) => item.relationId === relationId && item.memberId !== memberId)) throw new ApiError('关爱成员关系冲突，请重新读取');
      return;
    }
    seen.add(relationId);
    // `to_member_id` is authoritative even when the backend nests a different member row.
    const identityMatches = careId(member['id']) === memberId;
    result.push({ relationId: relationId, memberId: memberId,
      name: identityMatches ? text(member['nickname']) || '关爱成员' : '关爱成员',
      mobile: identityMatches ? text(member['mobile'], 32) : '' });
  });
  return result;
}
export function parseCareInvitations(data: Object | undefined, ownId: string): CareInvitation[] {
  const result: CareInvitation[] = [];
  const seen: Set<number> = new Set();
  list(data).forEach((raw: Object) => {
    const row = object(raw), id = careId(row['id']), inviterId = careId(row['member_id']);
    const recipientId = careId(row['to_member_id']);
    if (!id || !inviterId || !recipientId) throw new ApiError('关爱邀请身份不完整，请重新读取');
    if (String(recipientId) !== ownId || String(inviterId) === ownId) return;
    const status = String(row['examine_status'] ?? row['examineStatus'] ?? '').trim().toLowerCase();
    const state = ['0', 'pending', 'waiting'].includes(status) ? 'pending' :
      status === '1' ? 'accepted' : status === '2' ? 'rejected' : 'other';
    if (seen.has(id)) {
      const previous = result.find((item: CareInvitation) => item.id === id);
      if (previous && (previous.inviterId !== inviterId || previous.state !== state)) previous.state = 'other';
      return;
    }
    seen.add(id);
    const candidates: Object[] = [row['inviter'], row['from_member'], row['fromMember'], row['member']];
    let member: Record<string, Object> = {};
    candidates.forEach((candidate: Object) => {
      const parsed = object(candidate);
      if (!careId(member['id']) && careId(parsed['id'] ?? parsed['member_id']) === inviterId) member = parsed;
    });
    result.push({ id: id, inviterId: inviterId, name: text(member['nickname']) || '关爱邀请人',
      mobile: text(member['mobile'], 32), state: state });
  });
  return result;
}
export function careMobileValidation(mobile: string, ownMobile: string): string {
  if (!/^\d{6,20}$/.test(mobile.trim())) return '请输入正确的手机号';
  return ownMobile.trim() && mobile.trim() === ownMobile.trim() ? '不能添加当前登录账号作为关爱成员' : '';
}
export function parseCareSettings(data: Object | undefined): CareShareSettings {
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new ApiError('共享设置格式异常，未更改授权');
  let raw: Object | undefined = object(data)['setting'];
  if (raw === undefined || raw === null || raw === '') raw = [];
  if (typeof raw === 'string') {
    try { raw = JSON.parse(raw) as Object; }
    catch { throw new ApiError('共享设置格式异常，未更改授权'); }
  }
  if (!Array.isArray(raw)) throw new ApiError('共享设置格式异常，未更改授权');
  const enabled: string[] = [], unknown: string[] = [];
  const known = CARE_OPTIONS.map((option: CareOption) => option.key);
  (raw as Object[]).forEach((value: Object) => {
    if (typeof value !== 'string' || !/^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(value)) throw new ApiError('共享设置包含无法识别的内容，未更改授权');
    const target = known.includes(value) ? enabled : unknown;
    if (!target.includes(value)) target.push(value);
  });
  return { enabled: enabled.sort(), unknown: unknown.sort() };
}
export function careSettingsBody(memberId: number, settings: CareShareSettings): string {
  if (!careId(memberId)) throw new ApiError('成员身份无效');
  const known = CARE_OPTIONS.map((option: CareOption) => option.key);
  if (settings.enabled.some((key: string) => !known.includes(key))) throw new ApiError('不能新增本版不支持的共享项目');
  // Validate again at the write boundary; preserve unsupported historical keys unchanged.
  const parsed = parseCareSettings({ setting: [...settings.enabled, ...settings.unknown] });
  return JSON.stringify({ type: 0, to_member_id: memberId, setting: [...parsed.enabled, ...parsed.unknown].sort() });
}

export function chinaDay(now: number = Date.now()): string { return new Date(now + 8 * 3600000).toISOString().slice(0, 10); }
export function chinaDaySeconds(day: string): number {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) throw new ApiError('日期格式不正确');
  const milliseconds = Date.parse(`${day}T00:00:00+08:00`);
  if (!Number.isFinite(milliseconds) || chinaDay(milliseconds) !== day) throw new ApiError('日期不存在');
  return milliseconds / 1000;
}
export function shiftChinaDay(day: string, offset: number): string {
  return chinaDay(chinaDaySeconds(day) * 1000 + offset * 86400000);
}
function decode(value: Object | undefined, depth: number = 0): Object | undefined {
  if (typeof value !== 'string' || depth > 3) return value;
  const trimmed = value.trim();
  if (!/^[\[{"]/.test(trimmed)) return value;
  try { return decode(JSON.parse(trimmed) as Object, depth + 1); } catch { return value; }
}
function number(value: Object | undefined): number | undefined {
  const raw = decode(value);
  if (Array.isArray(raw)) {
    for (const item of raw as Object[]) { const parsed = number(item); if (parsed !== undefined) return parsed; }
    return undefined;
  }
  if (typeof raw !== 'number' && typeof raw !== 'string') return undefined;
  if (typeof raw === 'string' && !/^\s*\d+(?:\.\d+)?\s*$/.test(raw)) return undefined;
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 && parsed < 1000000000 && parsed !== 2147483647 ? parsed : undefined;
}
function first(record: Record<string, Object>, keys: string[]): number | undefined {
  for (const key of keys) { const value = number(record[key]); if (value !== undefined) return value; }
  return undefined;
}
function field(fields: CareField[], label: string, value: number | undefined, unit: string): void {
  if (value !== undefined) fields.push({ label: label, value: value, unit: unit });
}
function nested(record: Record<string, Object>, keys: string[]): Record<string, Object> {
  const result: Record<string, Object> = {};
  keys.forEach((key: string) => {
    const inner = object(decode(record[key]));
    Object.keys(inner).forEach((name: string) => { if (result[name] === undefined) result[name] = inner[name]; });
  });
  Object.keys(record).forEach((name: string) => result[name] = record[name]);
  return result;
}
function recordTime(row: Record<string, Object>, day: string, index: number): CareRecord {
  let display = '时间未提供', order = -1;
  const candidates: Object[] = [row['timestamp'], row['measuredAt'], row['date'], row['time'], row['hourse'], row['created_at']];
  for (const candidate of candidates) {
    if (candidate === undefined || candidate === null) continue;
    const value = String(candidate).trim();
    const clock = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(value);
    if (clock) {
      const h = Number(clock[1]), m = Number(clock[2]), s = Number(clock[3] || 0);
      if (h < 24 && m < 60 && s < 60) { display = value; order = chinaDaySeconds(day) + h * 3600 + m * 60 + s; break; }
    }
    let parsed: number = NaN;
    if (/^\d{10,13}$/.test(value)) parsed = Number(value) * (value.length <= 10 ? 1000 : 1);
    else if (/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}/.test(value)) {
      const iso = value.replace(' ', 'T');
      parsed = Date.parse(/[zZ]|[+-]\d{2}:?\d{2}$/.test(iso) ? iso : `${iso}+08:00`);
    }
    if (Number.isFinite(parsed)) { display = new Date(parsed + 8 * 3600000).toISOString().replace('T', ' ').slice(0, 19); order = parsed / 1000; break; }
  }
  return { id: `${careId(row['id']) || 0}-${order}-${index}`, time: display, order: order, fields: [], samples: [], frequency: 0 };
}
function normalizedRecord(spec: CareMetricSpec, raw: Object, day: string, index: number, allowGeneric: boolean): CareRecord {
  const initial = object(raw);
  const row = nested(initial, ['data', 'ecgData', 'item', 'result']);
  const result = recordTime(row, day, index), fields = result.fields;
  if (spec.key === 'pressure') {
    const value = decode(row['bloodPressure']), inner = object(value);
    const pair = Array.isArray(value) ? value as Object[] : typeof value === 'string' ? value.split(/[/,\-]/) : [];
    const high = first(row, ['bloodPressureHigh', 'highPressure', 'systolic']) ?? first(inner, ['bloodPressureHigh', 'highPressure', 'systolic', 'high']) ?? number(pair[0]);
    const low = first(row, ['bloodPressureLow', 'lowPressure', 'diastolic']) ?? first(inner, ['bloodPressureLow', 'lowPressure', 'diastolic', 'low']) ?? number(pair[1]);
    if (high !== undefined && low !== undefined) { field(fields, '收缩压', high, spec.unit); field(fields, '舒张压', low, spec.unit); }
  } else if (spec.key === 'ecg') {
    field(fields, '心率', first(row, ['meanHeartRate', 'aveHeart', 'heartRate', 'heart']), '次/分');
    field(fields, 'HRV', first(row, ['averageHRV', 'aveHrv', 'hrv', 'HRVData']), 'ms');
    field(fields, 'QT', first(row, ['averageTimeInterval', 'aveQT', 'qtTime', 'qt']), 'ms');
    const frequency = first(row, ['sampleFrequency', 'frequency', 'uploadFrequency']);
    result.frequency = frequency !== undefined && frequency >= 50 && frequency <= 1000 ? frequency : 0;
    for (const key of ['samples', 'totalArray', 'filterSignals', 'waveformData']) {
      const samples = decode(row[key]);
      if (!Array.isArray(samples)) continue;
      const values = (samples as Object[]).map((item: Object) => typeof item === 'number' ? item :
        typeof item === 'string' && /^\s*[+-]?\d+(?:\.\d+)?\s*$/.test(item) ? Number(item) : NaN);
      // Never delete invalid samples and splice disconnected signal segments together.
      if (values.length > 1 && values.length <= 100000 && values.every((item: number) => Number.isFinite(item) && Math.abs(item) < 1000000000)) { result.samples = values; break; }
    }
  } else if (spec.key === 'body') {
    field(fields, 'BMI', first(row, ['BMI', 'bmi']), '');
    field(fields, '体脂率', first(row, ['bodyFatRate']), '%');
    field(fields, '脂肪量', first(row, ['fatRate', 'fatMass']), 'kg');
    field(fields, '去脂体重', first(row, ['FFM', 'fatFreeMass']), 'kg');
    field(fields, '肌肉率', first(row, ['muscleRate']), '%');
    field(fields, '肌肉量', first(row, ['muscleMass']), 'kg');
    field(fields, '皮下脂肪率', first(row, ['subcutaneousFat']), '%');
    field(fields, '骨骼肌率', first(row, ['skeletalMuscleRate']), '%');
    field(fields, '体水分率', first(row, ['bodyWater', 'bodyWaterRate']), '%');
    field(fields, '水分量', first(row, ['waterContent', 'waterMass']), 'kg');
    field(fields, '骨量', first(row, ['boneMass']), 'kg');
    field(fields, '蛋白质率', first(row, ['proteinProportion', 'proteinRate']), '%');
    field(fields, '蛋白质量', first(row, ['proteinMass']), 'kg');
    field(fields, '基础代谢', first(row, ['basalMetabolicRate']), 'kcal');
  } else if (spec.key === 'blood') {
    field(fields, '尿酸', first(row, ['uricAcidVal', 'uricAcid']), 'μmol/L');
    field(fields, '总胆固醇', first(row, ['cholesterol', 'totalCholesterol']), 'mmol/L');
    field(fields, '甘油三酯', first(row, ['triacylglycerol', 'triglycerides']), 'mmol/L');
    field(fields, '高密度脂蛋白', first(row, ['highDensity', 'highDensityLipoprotein']), 'mmol/L');
    field(fields, '低密度脂蛋白', first(row, ['lowDensity', 'lowDensityLipoprotein']), 'mmol/L');
  } else {
    let value: number | undefined = undefined;
    const generic = allowGeneric ? number(row['value']) : undefined;
    if (spec.key === 'heart') value = first(row, ['pulseReat', 'heartReat']) ?? generic;
    else if (spec.key === 'glucose') value = first(row, ['bloodGlucose']) ?? generic;
    else if (spec.key === 'hrv') value = first(row, ['HRVData', 'hrv']) ?? generic;
    else if (spec.key === 'oxygen') value = first(row, ['bloodOxygen', 'oxygen']) ?? first(object(decode(row['bloodOxygen'])), ['oxygens', 'bloodOxygen', 'value']) ?? generic;
    else if (spec.key === 'temperature') value = first(row, ['bodyTemperature', 'temperature']) ?? first(object(decode(row['bodyTemperature'])), ['bodyTemperature', 'temperature', 'value']) ?? generic;
    else if (spec.key === 'sleep') value = first(row, ['sleepMinutes']) ?? first(object(decode(row['sleepData'])), ['allSleepTime', 'sleepMinutes']) ?? generic;
    field(fields, spec.title, value, spec.unit);
  }
  return result;
}
function chartRows(spec: CareMetricSpec, payload: Record<string, Object>): Object[] {
  const categories = payload['categories'], series = payload['series'];
  if (!Array.isArray(categories) || !Array.isArray(series)) return [];
  const result: Object[] = [];
  (categories as Object[]).slice(0, 3000).forEach((category: Object, index: number) => {
    const row: Record<string, Object> = { time: category };
    (series as Object[]).forEach((raw: Object, seriesIndex: number) => {
      const data = object(raw), values = data['data'];
      if (!Array.isArray(values) || index >= values.length) return;
      const name = text(data['name'] ?? data['title']).toLowerCase();
      if (spec.key === 'pressure') {
        if (/收缩|高压|systolic|high/.test(name)) row['bloodPressureHigh'] = values[index];
        else if (/舒张|低压|diastolic|low/.test(name)) row['bloodPressureLow'] = values[index];
      } else if (seriesIndex === 0) {
        if (spec.key === 'heart') row['pulseReat'] = values[index];
        else if (spec.key === 'glucose') row['bloodGlucose'] = values[index];
        else if (spec.key === 'oxygen') row['bloodOxygen'] = values[index];
        else if (spec.key === 'temperature') row['bodyTemperature'] = values[index];
        else if (spec.key === 'hrv') row['HRVData'] = values[index];
        else if (spec.key === 'sleep' && /总|total/.test(name)) row['sleepMinutes'] = values[index];
      }
      else if (spec.key === 'sleep' && /总|total/.test(name)) row['sleepMinutes'] = values[index];
    });
    result.push(row);
  });
  return result;
}
export function careMetricState(spec: CareMetricSpec, state: string, message: string): CareMetric {
  return { key: spec.key, title: spec.title, unit: spec.unit, state: state, message: message, records: [] };
}
export function parseCareMetric(spec: CareMetricSpec, data: Object | undefined, day: string, allowGeneric: boolean = true): CareMetric {
  chinaDaySeconds(day);
  if (!Array.isArray(data) && (!data || typeof data !== 'object')) throw new ApiError('成员数据格式异常');
  const payload = object(data);
  let rows: Object[] = Array.isArray(data) ? data as Object[] : Array.isArray(payload['list']) ? payload['list'] as Object[] :
    Array.isArray(payload['data']) ? payload['data'] as Object[] : chartRows(spec, payload);
  if (rows.length > 3000) throw new ApiError('当日记录较多，暂时无法全部显示');
  const records: CareRecord[] = [];
  const seen: Set<string> = new Set();
  rows.forEach((raw: Object, index: number) => {
    const record = normalizedRecord(spec, raw, day, index, allowGeneric);
    if (record.fields.length === 0 && record.samples.length === 0) return;
    if (record.order >= 0 && (record.order < chinaDaySeconds(day) || record.order >= chinaDaySeconds(day) + 86400)) return;
    const fingerprint = `${record.order}|${JSON.stringify(record.fields)}|${JSON.stringify(record.samples)}`;
    if (record.order >= 0 && seen.has(fingerprint)) return;
    seen.add(fingerprint); records.push(record);
  });
  records.sort((a: CareRecord, b: CareRecord) => b.order - a.order);
  return { key: spec.key, title: spec.title, unit: spec.unit, state: records.length ? 'ready' : 'empty',
    message: records.length ? `共 ${records.length} 条共享记录` : '对方当日没有可共享的该项记录', records: records };
}
export function careNumber(value: number): string { return Number(value.toFixed(2)).toString(); }
export function careRecordText(record: CareRecord): string {
  return record.fields.map((item: CareField) => `${item.label} ${careNumber(item.value)}${item.unit ? ` ${item.unit}` : ''}`).join(' · ') ||
    (record.samples.length > 1 ? `已收到 ${record.samples.length} 个原始波形点` : '暂无可展示数值');
}
export function careMetricLatest(metric: CareMetric): string {
  if (metric.records.length === 0) return metric.message;
  // Without a trustworthy time, never label array order as the newest measurement.
  return `${metric.records[0].order < 0 ? '记录' : '最近'}：${careRecordText(metric.records[0])}`;
}
