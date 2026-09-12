export type WatchUnitField = 'unitSystem' | 'tempUnit' | 'timeFormat';
// Preserve every field from the locked SDK's complete B8 configuration.
export interface WatchUnits {
  unitSystem: number; timeFormat: number; heartRateAutoDetect: number; bloodPressureAutoDetect: number;
  sportOverloadReminder: number; vitalSignsBroadcast: number; findPhoneDisplay: number; stopwatchDisplay: number;
  spo2LowNotification: number; ledLevel: number; hrvAutoDetect: number; autoAnswerCall: number;
  btDisconnectReminder: number; sosPageDisplay: number; ppgAutoMeasure: number; precisionSleep: number;
  musicControl: number; longPressUnlock: number; messageScreenOn: number; tempAutoMonitor: number;
  tempUnit: number; ecgAlwaysOn: number; bloodGlucoseSwitch: number; metSwitch: number;
  pressureSwitch: number; bloodGlucoseUnit: number; bloodCompositionSwitch: number; uricAcidUnit: number;
  bloodLipidUnit: number; fallDetection: number; abnormalHRTrend: number; skinElectricUnit: number;
}
export interface WatchAlarm { id: number; enabled: boolean; time: string; days: boolean[]; label: string; }
export interface SettingsResult { success: boolean; errorMessage?: string; }
export interface UnitsResult extends SettingsResult { data?: WatchUnits; }
export interface AlarmsResult extends SettingsResult { data?: WatchAlarm[]; }
export interface DeviceSettingsPort {
  readUnits(): Promise<UnitsResult>;
  writeUnits(config: WatchUnits): Promise<SettingsResult>;
  readAlarms(): Promise<AlarmsResult>;
  writeAlarm(alarm: WatchAlarm): Promise<SettingsResult>;
  deleteAlarm(id: number): Promise<SettingsResult>;
}
export type AssertDeviceSession = () => void;

export async function refreshSummaryOnSettingsReturn(from: string, parent: string,
  refresh: () => Promise<boolean>): Promise<boolean | undefined> {
  if (parent !== 'device-settings' || !['device-units', 'device-alarms'].includes(from)) return undefined;
  return refresh();
}

export function emptyWatchUnits(): WatchUnits {
  return {
    unitSystem: 0, timeFormat: 0, heartRateAutoDetect: 0, bloodPressureAutoDetect: 0,
    sportOverloadReminder: 0, vitalSignsBroadcast: 0, findPhoneDisplay: 0, stopwatchDisplay: 0,
    spo2LowNotification: 0, ledLevel: 0, hrvAutoDetect: 0, autoAnswerCall: 0,
    btDisconnectReminder: 0, sosPageDisplay: 0, ppgAutoMeasure: 0, precisionSleep: 0,
    musicControl: 0, longPressUnlock: 0, messageScreenOn: 0, tempAutoMonitor: 0,
    tempUnit: 0, ecgAlwaysOn: 0, bloodGlucoseSwitch: 0, metSwitch: 0,
    pressureSwitch: 0, bloodGlucoseUnit: 0, bloodCompositionSwitch: 0, uricAcidUnit: 0,
    bloodLipidUnit: 0, fallDetection: 0, abnormalHRTrend: 0, skinElectricUnit: 0
  };
}
export function copyWatchUnits(config: WatchUnits): WatchUnits {
  return {
    unitSystem: config.unitSystem, timeFormat: config.timeFormat,
    heartRateAutoDetect: config.heartRateAutoDetect, bloodPressureAutoDetect: config.bloodPressureAutoDetect,
    sportOverloadReminder: config.sportOverloadReminder, vitalSignsBroadcast: config.vitalSignsBroadcast,
    findPhoneDisplay: config.findPhoneDisplay, stopwatchDisplay: config.stopwatchDisplay,
    spo2LowNotification: config.spo2LowNotification, ledLevel: config.ledLevel,
    hrvAutoDetect: config.hrvAutoDetect, autoAnswerCall: config.autoAnswerCall,
    btDisconnectReminder: config.btDisconnectReminder, sosPageDisplay: config.sosPageDisplay,
    ppgAutoMeasure: config.ppgAutoMeasure, precisionSleep: config.precisionSleep,
    musicControl: config.musicControl, longPressUnlock: config.longPressUnlock,
    messageScreenOn: config.messageScreenOn, tempAutoMonitor: config.tempAutoMonitor,
    tempUnit: config.tempUnit, ecgAlwaysOn: config.ecgAlwaysOn,
    bloodGlucoseSwitch: config.bloodGlucoseSwitch, metSwitch: config.metSwitch,
    pressureSwitch: config.pressureSwitch, bloodGlucoseUnit: config.bloodGlucoseUnit,
    bloodCompositionSwitch: config.bloodCompositionSwitch, uricAcidUnit: config.uricAcidUnit,
    bloodLipidUnit: config.bloodLipidUnit, fallDetection: config.fallDetection,
    abnormalHRTrend: config.abnormalHRTrend, skinElectricUnit: config.skinElectricUnit
  };
}
function watchUnitValues(config: WatchUnits): number[] {
  return [config.unitSystem, config.timeFormat, config.heartRateAutoDetect, config.bloodPressureAutoDetect,
    config.sportOverloadReminder, config.vitalSignsBroadcast, config.findPhoneDisplay, config.stopwatchDisplay,
    config.spo2LowNotification, config.ledLevel, config.hrvAutoDetect, config.autoAnswerCall,
    config.btDisconnectReminder, config.sosPageDisplay, config.ppgAutoMeasure, config.precisionSleep,
    config.musicControl, config.longPressUnlock, config.messageScreenOn, config.tempAutoMonitor,
    config.tempUnit, config.ecgAlwaysOn, config.bloodGlucoseSwitch, config.metSwitch,
    config.pressureSwitch, config.bloodGlucoseUnit, config.bloodCompositionSwitch, config.uricAcidUnit,
    config.bloodLipidUnit, config.fallDetection, config.abnormalHRTrend, config.skinElectricUnit];
}
export function completeWatchUnits(config: WatchUnits): boolean {
  // Unknown byte values are preserved; missing fields are never defaulted into a write.
  return watchUnitValues(config).every((value: number) => Number.isInteger(value) && value >= 0 && value <= 255);
}
function sameWatchUnits(a: WatchUnits, b: WatchUnits): boolean {
  const expected = watchUnitValues(a), actual = watchUnitValues(b);
  return expected.every((value: number, index: number) => value === actual[index]);
}
export function supportedWatchUnit(value: number): boolean { return value === 1 || value === 2; }
export function watchUnitChoiceLabel(field: WatchUnitField, value: number): string {
  if (field === 'timeFormat') return value === 1 ? '24 小时' : '12 小时';
  if (field === 'unitSystem') return value === 1 ? '公制（千米）' : '英制（英里）';
  return value === 1 ? '摄氏度（℃）' : '华氏度（℉）';
}
export function copyWatchAlarm(alarm: WatchAlarm): WatchAlarm {
  return { id: alarm.id, enabled: alarm.enabled, time: alarm.time, days: alarm.days.slice(), label: alarm.label };
}
export function newWatchAlarm(): WatchAlarm {
  return { id: -1, enabled: true, time: '08:00', days: [true, true, true, true, true, true, true], label: '闹钟' };
}
export function sameWatchAlarm(a: WatchAlarm, b: WatchAlarm): boolean {
  return a.id === b.id && a.enabled === b.enabled && a.time === b.time && a.label === b.label &&
    a.days.length === b.days.length && a.days.every((day: boolean, index: number) => day === b.days[index]);
}
export function alarmRepeatText(days: boolean[]): string {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  const selected = names.filter((_name: string, index: number) => days[index]);
  if (selected.length === 0) return '仅一次';
  if (selected.length === 7) return '每天';
  if (days.slice(0, 5).every((day: boolean) => day) && !days[5] && !days[6]) return '工作日';
  if (days.slice(0, 5).every((day: boolean) => !day) && days[5] && days[6]) return '周末';
  return selected.join('、');
}
function utf8Bytes(text: string): number {
  let bytes = 0;
  for (let i = 0; i < text.length; i++) {
    const point = text.codePointAt(i) ?? 0;
    if (point >= 0xD800 && point <= 0xDFFF) return Number.MAX_SAFE_INTEGER;
    bytes += point < 0x80 ? 1 : point < 0x800 ? 2 : point < 0x10000 ? 3 : 4;
    if (point >= 0x10000) i++;
  }
  return bytes;
}
export function alarmDraftError(alarm: WatchAlarm): string {
  if (!Number.isInteger(alarm.id) || alarm.id < -1 || alarm.id > 255) return '闹钟编号无效，请重新读取';
  if (!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(alarm.time)) return '请选择有效时间';
  if (alarm.days.length !== 7 || alarm.days.some((day: boolean) => typeof day !== 'boolean')) return '请选择有效重复日期';
  if (typeof alarm.enabled !== 'boolean') return '请选择是否启用闹钟';
  if (/[\u0000-\u001f\u007f]/.test(alarm.label)) return '提醒名称不能包含换行或控制字符';
  // The locked official demo documents a 21-byte UTF-8 label, not 21 characters.
  if (utf8Bytes(alarm.label) > 21) return '提醒名称过长，请精简后再保存';
  return '';
}
export function nextWatchAlarmId(alarms: WatchAlarm[]): number {
  for (let id = 1; id <= 255; id++) {
    if (!alarms.some((alarm: WatchAlarm) => alarm.id === id)) return id;
  }
  throw new Error('闹钟数量已达上限');
}
function requireResult(result: SettingsResult, fallback: string): void {
  if (!result.success) throw new Error(fallback);
}
export async function readWatchUnits(port: DeviceSettingsPort, current: AssertDeviceSession): Promise<WatchUnits> {
  current();
  const result = await port.readUnits();
  current(); requireResult(result, '戒指单位暂时无法读取，请重试');
  if (!result.data) throw new Error('戒指未返回单位设置');
  if (!completeWatchUnits(result.data)) throw new Error('戒指设置不完整，请重新读取');
  return copyWatchUnits(result.data);
}
export async function saveWatchUnit(port: DeviceSettingsPort, current: AssertDeviceSession,
  field: WatchUnitField, value: number, expected: number): Promise<WatchUnits> {
  if (!['unitSystem', 'tempUnit', 'timeFormat'].includes(field) || !supportedWatchUnit(value)) throw new Error('单位选项无效');
  const before = await readWatchUnits(port, current);
  if (!supportedWatchUnit(before[field])) throw new Error('当前戒指不支持此单位设置');
  if (before[field] === value) return before;
  if (before[field] !== expected) throw new Error('戒指设置已变化，请重新读取后再修改');
  const intended = copyWatchUnits(before);
  if (field === 'unitSystem') intended.unitSystem = value;
  else if (field === 'tempUnit') intended.tempUnit = value;
  else intended.timeFormat = value;
  current(); const written = await port.writeUnits(copyWatchUnits(intended)); current();
  requireResult(written, '单位保存失败，请重新读取后重试');
  const actual = await readWatchUnits(port, current);
  if (actual[field] !== value) throw new Error('尚未确认单位已保存，请重新读取');
  if (!sameWatchUnits(intended, actual)) throw new Error('戒指其他设置已变化，请重新读取');
  return actual;
}
export async function readWatchAlarms(port: DeviceSettingsPort, current: AssertDeviceSession): Promise<WatchAlarm[]> {
  current(); const result = await port.readAlarms(); current();
  requireResult(result, '闹钟暂时无法读取，请重试');
  if (!result.data) throw new Error('戒指未返回闹钟列表');
  const ids: Set<number> = new Set();
  for (const alarm of result.data) {
    if (alarm.id < 0 || alarmDraftError(alarm) || ids.has(alarm.id)) throw new Error('闹钟数据暂时无法识别，请重新读取');
    ids.add(alarm.id);
  }
  return result.data.map((alarm: WatchAlarm) => copyWatchAlarm(alarm));
}
function requireUnchanged(alarms: WatchAlarm[], expected: WatchAlarm): void {
  const current = alarms.find((alarm: WatchAlarm) => alarm.id === expected.id);
  if (!current || !sameWatchAlarm(current, expected)) throw new Error('此闹钟已变化，请重新读取后再修改');
}
function otherAlarmsMatch(before: WatchAlarm[], after: WatchAlarm[], id: number): boolean {
  const old = before.filter((alarm: WatchAlarm) => alarm.id !== id);
  const actual = after.filter((alarm: WatchAlarm) => alarm.id !== id);
  return old.length === actual.length && old.every((alarm: WatchAlarm) =>
    actual.some((item: WatchAlarm) => sameWatchAlarm(alarm, item)));
}
export async function saveWatchAlarm(port: DeviceSettingsPort, current: AssertDeviceSession,
  draft: WatchAlarm, expected?: WatchAlarm): Promise<WatchAlarm[]> {
  const error = alarmDraftError(draft);
  if (error) throw new Error(error);
  const item = copyWatchAlarm(draft);
  const previous = expected ? copyWatchAlarm(expected) : undefined;
  const before = await readWatchAlarms(port, current);
  if (item.id < 0) item.id = nextWatchAlarmId(before);
  else {
    if (!previous || previous.id !== item.id) throw new Error('请重新读取闹钟后再修改');
    requireUnchanged(before, previous);
  }
  current(); const written = await port.writeAlarm(item); current();
  requireResult(written, '闹钟保存失败，请重新读取后重试');
  const actual = await readWatchAlarms(port, current);
  if (!actual.some((alarm: WatchAlarm) => sameWatchAlarm(alarm, item)) || !otherAlarmsMatch(before, actual, item.id)) {
    throw new Error('尚未确认闹钟已保存，请重新读取');
  }
  return actual;
}
export async function deleteWatchAlarm(port: DeviceSettingsPort, current: AssertDeviceSession,
  expected: WatchAlarm): Promise<WatchAlarm[]> {
  const previous = copyWatchAlarm(expected);
  const before = await readWatchAlarms(port, current);
  requireUnchanged(before, previous);
  current(); const deleted = await port.deleteAlarm(previous.id); current();
  requireResult(deleted, '闹钟删除失败，请重新读取后重试');
  const actual = await readWatchAlarms(port, current);
  if (actual.some((alarm: WatchAlarm) => alarm.id === previous.id) || !otherAlarmsMatch(before, actual, previous.id)) {
    throw new Error('尚未确认闹钟已删除，请重新读取');
  }
  return actual;
}
