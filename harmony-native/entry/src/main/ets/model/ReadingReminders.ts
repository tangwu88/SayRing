import type { HealthRecord, MeasurementState, WearableMetricKey, WearableSnapshot } from './WearableContracts';

export type ReadingRule = 'high' | 'low' | 'oxygen' | 'hrv' | 'temperature';
export interface ReadingSettings {
  highEnabled: boolean; lowEnabled: boolean; oxygenEnabled: boolean; hrvEnabled: boolean; temperatureEnabled: boolean;
  high: number; low: number; oxygen: number; hrvReference?: number; hrvDropPercent: number;
  skinReference?: number; skinRise: number; hrvDevice: string; hrvFirmware: string; skinDevice: string; skinFirmware: string;
  phoneSound: boolean; reduceMotion: boolean;
  stepGoal: number; distanceGoal: number; calorieGoal: number;
}
export interface PersonalReadingEvent {
  id: string; rule: ReadingRule; metric: WearableMetricKey; value: number; unit: string;
  boundary: number; measuredAt: number; deviceKey: string; firmware: string;
}
export interface ReadingNotice { token: number; preview: boolean; event?: PersonalReadingEvent; reduceMotion: boolean; phoneSound: boolean; }
export function defaultReadingSettings(): ReadingSettings {
  return { highEnabled: false, lowEnabled: false, oxygenEnabled: false, hrvEnabled: false, temperatureEnabled: false,
    high: 120, low: 40, oxygen: 92, hrvDropPercent: 30, skinRise: 0.8,
    hrvDevice: '', hrvFirmware: '', skinDevice: '', skinFirmware: '', phoneSound: true, reduceMotion: true,
    stepGoal: 10000, distanceGoal: 6, calorieGoal: 800 };
}
export function parseReadingSettings(input: Object | undefined): ReadingSettings {
  const value = input as Partial<ReadingSettings> | undefined;
  const defaults = defaultReadingSettings();
  if (!value) return defaults;
  const result: ReadingSettings = { ...defaults, ...value };
  result.highEnabled = value.highEnabled === true; result.lowEnabled = value.lowEnabled === true;
  result.oxygenEnabled = value.oxygenEnabled === true; result.hrvEnabled = value.hrvEnabled === true;
  result.temperatureEnabled = value.temperatureEnabled === true;
  result.hrvDevice = typeof value.hrvDevice === 'string' ? value.hrvDevice.slice(0, 160) : '';
  result.hrvFirmware = typeof value.hrvFirmware === 'string' ? value.hrvFirmware.slice(0, 80) : '';
  result.skinDevice = typeof value.skinDevice === 'string' ? value.skinDevice.slice(0, 160) : '';
  result.skinFirmware = typeof value.skinFirmware === 'string' ? value.skinFirmware.slice(0, 80) : '';
  result.phoneSound = value.phoneSound !== false; result.reduceMotion = value.reduceMotion !== false;
  if (readingSettingsError(result)) return defaults;
  return result;
}
export function readingSettingsError(value: ReadingSettings): string {
  if (![value.high, value.low, value.oxygen, value.hrvDropPercent, value.skinRise,
    value.stepGoal, value.distanceGoal, value.calorieGoal].every(Number.isFinite)) return '请填写有效的数字';
  if (value.low < 20 || value.high > 250 || value.high <= value.low) return '心率上限需大于下限，范围为20～250次/分';
  if (value.oxygen < 70 || value.oxygen > 100) return '血氧参考范围为70%～100%';
  if (value.hrvDropPercent < 1 || value.hrvDropPercent > 90) return 'HRV变化幅度范围为1%～90%';
  if (value.skinRise < 0.1 || value.skinRise > 5) return '皮温变化幅度范围为0.1～5℃';
  if (value.stepGoal < 1 || value.stepGoal > 100000 || value.distanceGoal <= 0 || value.distanceGoal > 200 ||
    value.calorieGoal < 1 || value.calorieGoal > 10000) return '请填写合理的活动目标';
  if (value.hrvEnabled && (!Number.isFinite(value.hrvReference) || (value.hrvReference ?? 0) <= 0 || (value.hrvReference ?? 0) > 500)) return '请先填写个人HRV参考值';
  if (value.temperatureEnabled && (!Number.isFinite(value.skinReference) || (value.skinReference ?? 0) < 10 || (value.skinReference ?? 0) > 50)) return '请先填写个人皮温参考值';
  if ((value.hrvEnabled && (!value.hrvDevice || !value.hrvFirmware)) ||
    (value.temperatureEnabled && (!value.skinDevice || !value.skinFirmware))) return '请连接戒指并完成信息读取后设置个人参考';
  return '';
}
export function readingRuleTitle(rule: ReadingRule): string {
  if (rule === 'high') return '心率偏高'; if (rule === 'low') return '心率偏低';
  if (rule === 'oxygen') return '血氧偏低'; if (rule === 'hrv') return 'HRV个人参考变化';
  return '皮温个人参考变化';
}
export function readingRuleMetric(rule: ReadingRule): WearableMetricKey {
  return rule === 'high' || rule === 'low' ? 'heart' : rule;
}
export function readingRuleEnabled(settings: ReadingSettings, rule: ReadingRule): boolean {
  if (rule === 'high') return settings.highEnabled; if (rule === 'low') return settings.lowEnabled;
  if (rule === 'oxygen') return settings.oxygenEnabled; if (rule === 'hrv') return settings.hrvEnabled;
  return settings.temperatureEnabled;
}
export function setReadingRule(settings: ReadingSettings, rule: ReadingRule, enabled: boolean): ReadingSettings {
  const result = { ...settings };
  if (rule === 'high') result.highEnabled = enabled; else if (rule === 'low') result.lowEnabled = enabled;
  else if (rule === 'oxygen') result.oxygenEnabled = enabled; else if (rule === 'hrv') result.hrvEnabled = enabled;
  else result.temperatureEnabled = enabled;
  return result;
}
export function setReadingNumber(settings: ReadingSettings, field: string, text: string): ReadingSettings {
  const value = text.trim() ? Number(text) : NaN, result = { ...settings };
  if (field === 'high') result.high = value; else if (field === 'low') result.low = value;
  else if (field === 'oxygen') result.oxygen = value; else if (field === 'hrvReference') result.hrvReference = value;
  else if (field === 'hrvDropPercent') result.hrvDropPercent = value; else if (field === 'skinReference') result.skinReference = value;
  else if (field === 'skinRise') result.skinRise = value; else if (field === 'stepGoal') result.stepGoal = value;
  else if (field === 'distanceGoal') result.distanceGoal = value; else if (field === 'calorieGoal') result.calorieGoal = value;
  return result;
}
export function readingNumber(settings: ReadingSettings, field: string): string {
  let value: number | undefined = undefined;
  if (field === 'high') value = settings.high; else if (field === 'low') value = settings.low;
  else if (field === 'oxygen') value = settings.oxygen; else if (field === 'hrvReference') value = settings.hrvReference;
  else if (field === 'hrvDropPercent') value = settings.hrvDropPercent; else if (field === 'skinReference') value = settings.skinReference;
  else if (field === 'skinRise') value = settings.skinRise; else if (field === 'stepGoal') value = settings.stepGoal;
  else if (field === 'distanceGoal') value = settings.distanceGoal; else if (field === 'calorieGoal') value = settings.calorieGoal;
  return typeof value === 'number' && Number.isFinite(value) ? String(value) : '';
}
export function setReadingSound(settings: ReadingSettings, enabled: boolean): ReadingSettings { return { ...settings, phoneSound: enabled }; }
export function setReadingMotion(settings: ReadingSettings, reduced: boolean): ReadingSettings { return { ...settings, reduceMotion: reduced }; }
export function skinValue(record: HealthRecord): number | undefined {
  const item = record.values.find(value => ['skinTemperature', '皮肤温度', '体表温度'].includes(value.name) && ['℃', '°C', 'C'].includes(value.unit));
  return item && Number.isFinite(item.value) && item.value >= 10 && item.value <= 50 ? item.value : undefined;
}
export function supportedReadingRules(snapshot: WearableSnapshot): ReadingRule[] {
  if (!snapshot.connected || !snapshot.deviceKey) return [];
  const result: ReadingRule[] = [];
  if (snapshot.capabilities.heart) result.push('high', 'low');
  if (snapshot.capabilities.oxygen) result.push('oxygen');
  // The current Vep adapter exposes passive HRV only. Never promote it to a manual command.
  if (snapshot.capabilities.hrv && snapshot.provider === 'Yuc') result.push('hrv');
  if (snapshot.capabilities.temperature && snapshot.records.some(record =>
    record.deviceKey === snapshot.deviceKey && record.metric === 'temperature' && skinValue(record) !== undefined)) result.push('temperature');
  return result;
}
export function evaluatePersonalReading(settings: ReadingSettings, snapshot: WearableSnapshot, record: HealthRecord,
  completed: MeasurementState, startedAt: number, now: number): PersonalReadingEvent | undefined {
  if (readingSettingsError(settings) || !snapshot.connected || !snapshot.deviceKey || record.deviceKey !== snapshot.deviceKey ||
    record.source !== 'app_measurement' || !record.id || !Number.isFinite(record.timestamp) ||
    record.timestamp < startedAt || record.timestamp > now + 1000 || now - record.timestamp > 90000 ||
    completed.metric !== record.metric || completed.running || completed.progress !== 100) return undefined;
  const supported = supportedReadingRules(snapshot);
  for (const rule of supported) {
    if (!readingRuleEnabled(settings, rule) || readingRuleMetric(rule) !== record.metric) continue;
    const unit = rule === 'oxygen' ? '%' : rule === 'hrv' ? 'ms' : rule === 'temperature' ? '℃' : 'bpm';
    const item = record.values.find(value => unit === 'bpm' ? ['bpm', '次/分', '次/分钟'].includes(value.unit) :
      unit === 'ms' ? ['ms', '毫秒'].includes(value.unit) : unit === '%' ? value.unit === '%' : false);
    const value = rule === 'temperature' ? skinValue(record) : item?.value;
    if (value === undefined || !Number.isFinite(value)) continue;
    if ((unit === 'bpm' && (value < 20 || value > 250)) || (unit === '%' && (value <= 0 || value > 100)) ||
      (unit === 'ms' && (value <= 0 || value > 500))) continue;
    if (rule === 'hrv' && (settings.hrvDevice !== snapshot.deviceKey || settings.hrvFirmware !== snapshot.firmware)) continue;
    if (rule === 'temperature' && (settings.skinDevice !== snapshot.deviceKey || settings.skinFirmware !== snapshot.firmware)) continue;
    const boundary = rule === 'high' ? settings.high : rule === 'low' ? settings.low : rule === 'oxygen' ? settings.oxygen :
      rule === 'hrv' ? (settings.hrvReference ?? 0) * (1 - settings.hrvDropPercent / 100) : (settings.skinReference ?? 0) + settings.skinRise;
    if ((rule === 'high' || rule === 'temperature') ? value <= boundary : value >= boundary) continue;
    return { id: `${record.id}:${rule}`, rule, metric: record.metric, value, unit, boundary,
      measuredAt: record.timestamp, deviceKey: record.deviceKey, firmware: snapshot.firmware };
  }
  return undefined;
}
