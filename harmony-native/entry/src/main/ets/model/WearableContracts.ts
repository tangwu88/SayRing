// Pure wearable contracts shared by ArkTS and host-side tests.

export type WearableProvider = 'Vep' | 'Yuc';
export type WearableConnectionPhase = 'idle' | 'permission' | 'scanning' | 'connecting' |
  'authenticating' | 'connected' | 'syncing' | 'disconnecting' | 'error';
export type WearableMetricKey = 'activity' | 'sleep' | 'heart' | 'pressure' | 'oxygen' |
  'temperature' | 'glucose' | 'hrv' | 'ecg' | 'bodyComposition' | 'bloodComponents' | 'sport';
export type WearableRecordSource = 'watch_history' | 'app_measurement';

export interface WearableDevice {
  key: string;
  provider: WearableProvider;
  name: string;
  transportId: string;
  mac: string;
  rssi: number;
  connectable: boolean;
}

export interface WearableCapabilities {
  activity: boolean;
  sleep: boolean;
  heart: boolean;
  pressure: boolean;
  oxygen: boolean;
  temperature: boolean;
  glucose: boolean;
  hrv: boolean;
  ecg: boolean;
  bodyComposition: boolean;
  bloodComponents: boolean;
  sport: boolean;
  alarm: boolean;
  sedentaryReminder: boolean;
  notification: boolean;
  findDevice: boolean;
  dial: boolean;
}

export interface WearableFeatureWire {
  bloodPressure?: number;
  bloodOxygen?: number;
  heartRateFunction?: number;
  dailyDataDays?: number;
  sleepFlag?: number;
  bodyTemp?: number;
  bloodGlucose?: number;
  hrv?: number;
  ecgFunction?: number;
  bodyComposition?: number;
  bloodComposition?: number;
  sportModeCount?: number;
  newAlarm?: number;
  healthReminder?: number;
  messageNotifyPackets?: number;
  findBand?: number;
  uiStyleCount?: number;
  moreWatchfaceCount?: number;
  customWatchfaceCount?: number;
}

export interface BatteryState {
  available: boolean;
  hasPercentage: boolean;
  level: number;
  levelGrade: number;
  charging: boolean;
  lowBattery: boolean;
  updatedAt: number;
}

export interface HealthValue {
  name: string;
  value: number;
  unit: string;
}

export interface HealthRecord {
  id: string;
  deviceKey: string;
  metric: WearableMetricKey;
  timestamp: number;
  source: WearableRecordSource;
  values: HealthValue[];
  samples: number[];
  sampleFrequency: number;
}

export interface WearableDeviceSettings {
  loadedAt: number;
  unitSystem: string;
  timeFormat: string;
  automaticHealth: string;
  sedentaryReminder: string;
  messageReminder: string;
  alarms: string[];
}

export interface WearableDial {
  key: string;
  path: string;
  fileName: string;
  uuid: string;
  selected: boolean;
}

export interface WearableSnapshot {
  connected: boolean;
  deviceKey: string;
  deviceName: string;
  mac: string;
  model: string;
  firmware: string;
  capabilities: WearableCapabilities;
  battery: BatteryState;
  records: HealthRecord[];
  settings: WearableDeviceSettings;
  dials: WearableDial[];
  currentDialKey: string;
  originalDialKey: string;
  syncedAt: number;
  message: string;
}

export interface MeasurementState {
  metric: WearableMetricKey | '';
  running: boolean;
  progress: number;
  status: string;
  values: HealthValue[];
  samples: number[];
  sampleFrequency: number;
}

export const WEARABLE_SCAN_TIMEOUT_MS: number = 12000;
export const WEARABLE_CONNECT_TIMEOUT_MS: number = 45000;
// JL-based W9 devices keep initializing the secondary channel after the SDK
// reports a successful connection. Health commands must wait for that window.
export const WEARABLE_AUTO_SYNC_DELAY_MS: number = 12000;
export const WEARABLE_RECONNECT_DELAYS_MS: number[] = [2000, 5000, 10000];
// A vendor stop acknowledgement must never keep the UI in a measuring state.
export const WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS: number = 3500;

export function isOneShotMeasurementMetric(metric: WearableMetricKey): boolean {
  return metric === 'oxygen';
}

export function retainedMeasurementValues(current: HealthValue[], previous: HealthValue[]): HealthValue[] {
  return (current.length > 0 ? current : previous).slice();
}

export function cleanDeviceName(value: string): string {
  const name = typeof value === 'string' ? value.replace(/[\x00-\x1f\x7f]/g, '').replace(/\s+/g, ' ').trim() : '';
  return name ? name.slice(0, 80) : '未知设备';
}

export function wearableProviderForName(value: string): WearableProvider {
  return /W8/i.test(cleanDeviceName(value)) ? 'Yuc' : 'Vep';
}

export function normalizeMac(value: string): string {
  const mac = typeof value === 'string' ? value.trim().toUpperCase().replace(/-/g, ':') : '';
  if (!/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/.test(mac) || mac === '00:00:00:00:00:00') return '';
  return mac;
}

export function wearableDeviceKey(provider: WearableProvider, transportId: string, mac: string): string {
  const verifiedMac = normalizeMac(mac);
  const stable = verifiedMac || (typeof transportId === 'string' ? transportId.trim() : '');
  return stable ? `${provider.toLowerCase()}:${stable}` : '';
}

export function createWearableDevice(provider: WearableProvider, name: string, transportId: string,
  mac: string, rssi: number, connectable: boolean): WearableDevice | undefined {
  const cleanTransport = typeof transportId === 'string' ? transportId.trim().slice(0, 160) : '';
  const key = wearableDeviceKey(provider, cleanTransport, mac);
  if (!key || !Number.isFinite(rssi)) return undefined;
  return {
    key: key,
    provider: provider,
    name: cleanDeviceName(name),
    transportId: cleanTransport,
    mac: normalizeMac(mac),
    rssi: Math.max(-127, Math.min(20, Math.round(rssi))),
    connectable: connectable === true
  };
}

export function mergeWearableDevices(current: WearableDevice[], incoming: WearableDevice[]): WearableDevice[] {
  const merged: Map<string, WearableDevice> = new Map();
  current.forEach((device: WearableDevice) => merged.set(device.key, device));
  incoming.forEach((device: WearableDevice) => {
    const sameTransport = Array.from(merged.values()).find((item: WearableDevice) =>
      item.provider === device.provider && item.transportId === device.transportId);
    // A later SDK packet can add the real MAC. It must enrich the discovered
    // transport, not add a second row; later name-only packets cannot erase it.
    const mac = device.mac || sameTransport?.mac || '';
    const next = createWearableDevice(device.provider, device.name, device.transportId,
      mac, device.rssi, device.connectable);
    if (!next) return;
    if (sameTransport) merged.delete(sameTransport.key);
    merged.set(next.key, next);
  });
  return Array.from(merged.values()).sort((a: WearableDevice, b: WearableDevice) => {
    if (a.provider !== b.provider) return a.provider === 'Vep' ? -1 : 1;
    if (a.rssi !== b.rssi) return b.rssi - a.rssi;
    return a.name.localeCompare(b.name);
  });
}

export function wearableIdentifierText(device: WearableDevice): string {
  if (device.mac) return `MAC · ${device.mac}`;
  const id = device.transportId;
  const shortId = id.length > 24 ? `${id.slice(0, 10)}…${id.slice(-8)}` : id;
  return `设备标识 · ${shortId || '未提供'}`;
}

export function emptyCapabilities(): WearableCapabilities {
  return {
    activity: false, sleep: false, heart: false, pressure: false, oxygen: false,
    temperature: false, glucose: false, hrv: false, ecg: false, bodyComposition: false,
    bloodComponents: false, sport: false, alarm: false, sedentaryReminder: false,
    notification: false, findDevice: false, dial: false
  };
}

export function capabilitiesFromFeatureList(feature?: WearableFeatureWire): WearableCapabilities {
  if (!feature) return emptyCapabilities();
  return {
    activity: (feature.dailyDataDays ?? 0) > 0,
    sleep: (feature.sleepFlag ?? 0) > 0 || (feature.dailyDataDays ?? 0) > 0,
    // The vendor protocol uses an inverted heart-rate flag: 0 is supported and 1 is unsupported.
    heart: feature.heartRateFunction !== undefined && feature.heartRateFunction !== 1,
    pressure: (feature.bloodPressure ?? 0) > 0,
    oxygen: (feature.bloodOxygen ?? 0) > 0,
    temperature: (feature.bodyTemp ?? 0) > 0,
    glucose: (feature.bloodGlucose ?? 0) > 0,
    hrv: (feature.hrv ?? 0) > 0,
    ecg: (feature.ecgFunction ?? 0) > 0,
    bodyComposition: (feature.bodyComposition ?? 0) > 0,
    bloodComponents: (feature.bloodComposition ?? 0) > 0,
    sport: (feature.sportModeCount ?? 0) > 0,
    alarm: (feature.newAlarm ?? 0) > 0,
    sedentaryReminder: (feature.healthReminder ?? 0) > 0,
    notification: (feature.messageNotifyPackets ?? 0) > 0,
    findDevice: (feature.findBand ?? 0) > 0,
    dial: (feature.uiStyleCount ?? 0) > 0 || (feature.moreWatchfaceCount ?? 0) > 0 ||
      (feature.customWatchfaceCount ?? 0) > 0
  };
}

export function emptyBattery(): BatteryState {
  return { available: false, hasPercentage: false, level: 0, levelGrade: 0,
    charging: false, lowBattery: false, updatedAt: 0 };
}

export function batteryText(battery: BatteryState): string {
  if (!battery.available) return '未知';
  const power = battery.hasPercentage ? `${Math.max(0, Math.min(100, Math.round(battery.level)))}%` :
    battery.levelGrade > 0 ? `${Math.round(battery.levelGrade)} 格` : '未知';
  return battery.charging ? `${power} · 充电中` : battery.lowBattery ? `${power} · 低电量` : power;
}

export function healthValue(name: string, value: number, unit: string): HealthValue | undefined {
  if (!Number.isFinite(value) || value <= 0) return undefined;
  return { name: name.slice(0, 40), value: value, unit: unit.slice(0, 20) };
}

export function boundedHealthValue(name: string, value: number, unit: string,
  minimum: number, maximum: number): HealthValue | undefined {
  if (!Number.isFinite(minimum) || !Number.isFinite(maximum) || minimum > maximum ||
    !Number.isFinite(value) || value < minimum || value > maximum) return undefined;
  return { name: name.slice(0, 40), value: value, unit: unit.slice(0, 20) };
}

function roundedKilometers(value: number): number {
  return Math.round(value * 1000) / 1000;
}

// The current Harmony SDK exposes the daily distance as metres on ET488,
// while an older vendor sample labels the same field as kilometres. Use the
// step count to accept an already-normalized kilometre value without dividing
// it a second time. More than 10 metres per step is not a plausible daily
// walking/running distance and therefore identifies the metre representation.
export function activityDistanceKilometers(value: number, steps: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  const safeSteps = Number.isFinite(steps) && steps > 0 ? steps : 0;
  const rawLooksLikeMeters = safeSteps > 0 && value > Math.max(0.05, safeSteps * 0.01);
  return roundedKilometers(rawLooksLikeMeters ? value / 1000 : value);
}

// Sport history uses metre-based protocol fields (allDistance), matching the
// iOS bridge and the vendor's real-time Harmony sample.
export function sportDistanceKilometers(value: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  return roundedKilometers(value / 1000);
}

// Repair records written by the first Harmony build, which stored metre values
// with a km label. This is deliberately conservative and idempotent so a valid
// kilometre record is never divided again on the next app launch.
export function normalizeLegacyDistanceRecord(record: HealthRecord): HealthRecord {
  if (record.metric !== 'activity' && record.metric !== 'sport') return record;
  const distanceIndex = record.values.findIndex((item: HealthValue) =>
    item.name === '距离' && ['km', '公里', '千米'].includes(item.unit));
  if (distanceIndex < 0) return record;
  const distance = record.values[distanceIndex];
  const steps = record.values.find((item: HealthValue) => item.name === '步数')?.value ?? 0;
  let normalized = activityDistanceKilometers(distance.value, steps);
  if (record.metric === 'sport' && steps <= 0 && distance.value > 300) {
    normalized = sportDistanceKilometers(distance.value);
  }
  if (normalized <= 0 || normalized === distance.value) return record;
  const values = record.values.slice();
  values[distanceIndex] = { name: distance.name, value: normalized, unit: 'km' };
  return { ...record, values: values };
}

export function latestMetricRecord(records: HealthRecord[], metric: WearableMetricKey): HealthRecord | undefined {
  return records.filter((record: HealthRecord) => record.metric === metric && Number.isFinite(record.timestamp))
    .sort((a: HealthRecord, b: HealthRecord) => b.timestamp - a.timestamp)[0];
}

export function healthRecordText(record?: HealthRecord): string {
  if (!record) return '暂无记录';
  if (record.values.length === 0 && record.metric === 'ecg' && record.samples.length > 1) {
    return `真实心电波形 ${record.samples.length} 点`;
  }
  if (record.values.length === 0) return '暂无记录';
  return record.values.map((item: HealthValue) => `${item.name} ${formatHealthNumber(item.value)}${item.unit}`).join(' · ');
}

export function emptyDeviceSettings(): WearableDeviceSettings {
  return {
    loadedAt: 0,
    unitSystem: '未读取',
    timeFormat: '未读取',
    automaticHealth: '未读取',
    sedentaryReminder: '未读取',
    messageReminder: '未读取',
    alarms: []
  };
}

export function formatHealthNumber(value: number): string {
  if (!Number.isFinite(value)) return '--';
  return Math.abs(value - Math.round(value)) < 0.001 ? `${Math.round(value)}` : value.toFixed(1);
}

export function emptyWearableSnapshot(): WearableSnapshot {
  return {
    connected: false, deviceKey: '', deviceName: '', mac: '', model: '', firmware: '',
    capabilities: emptyCapabilities(), battery: emptyBattery(), records: [], settings: emptyDeviceSettings(),
    dials: [], currentDialKey: '', originalDialKey: '', syncedAt: 0, message: ''
  };
}

export function emptyMeasurement(): MeasurementState {
  return { metric: '', running: false, progress: 0, status: '', values: [], samples: [], sampleFrequency: 0 };
}

export function isCurrentConnectionGeneration(expected: number, current: number): boolean {
  return Number.isSafeInteger(expected) && expected > 0 && expected === current;
}
