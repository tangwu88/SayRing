export type YucMetricKey = 'activity' | 'sleep' | 'heart' | 'pressure' | 'oxygen' |
  'temperature' | 'glucose' | 'hrv' | 'ecg' | 'bodyComposition' | 'bloodComponents' | 'sport';
export type YucSportMode = 'running' | 'walking' | 'cycling' | 'hiking';

export interface YucCapabilities {
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

export interface YucSportCapability {
  modes: YucSportMode[];
  supportsPause: boolean;
  protocol: 'none' | 'mode' | 'realtime';
}

// Pure Yucheng/W8 protocol contracts. Keeping these conversions outside the
// vendor HAR makes them executable by the host-side regression suite.
export interface YucFeatureFlags {
  step: boolean;
  sleep: boolean;
  heart: boolean;
  pressure: boolean;
  oxygen: boolean;
  temperature: boolean;
  glucose: boolean;
  hrv: boolean;
  ecg: boolean;
  sport: boolean;
  sportPause: boolean;
  outdoorRunning: boolean;
  outdoorWalking: boolean;
  cycling: boolean;
  hiking: boolean;
  alarm: boolean;
  sedentaryReminder: boolean;
  notification: boolean;
  findDevice: boolean;
}

export interface YucDeviceMetadata {
  mac: string;
  model: string;
  firmware: string;
  batteryLevel: number;
  batteryState: number;
}

export interface YucRealtimeHealth {
  metric: YucMetricKey | '';
  values: YucNamedValue[];
  samples: number[];
  sampleFrequency: number;
}

export interface YucNamedValue {
  name: string;
  value: number;
  unit: string;
}

export function emptyYucFeatureFlags(): YucFeatureFlags {
  return {
    step: false, sleep: false, heart: false, pressure: false, oxygen: false,
    temperature: false, glucose: false, hrv: false, ecg: false, sport: false,
    sportPause: false, outdoorRunning: false, outdoorWalking: false, cycling: false,
    hiking: false, alarm: false, sedentaryReminder: false, notification: false,
    findDevice: false
  };
}

export function yucCapabilitiesFromFlags(flags?: YucFeatureFlags): YucCapabilities {
  if (!flags) return {
    activity: false, sleep: false, heart: false, pressure: false, oxygen: false,
    temperature: false, glucose: false, hrv: false, ecg: false,
    bodyComposition: false, bloodComponents: false, sport: false, alarm: false,
    sedentaryReminder: false, notification: false, findDevice: false, dial: false
  };
  return {
    activity: flags.step,
    sleep: flags.sleep,
    heart: flags.heart,
    pressure: flags.pressure,
    oxygen: flags.oxygen,
    temperature: flags.temperature,
    glucose: flags.glucose,
    hrv: flags.hrv,
    ecg: flags.ecg,
    // The 2.1.5 public API has no complete body-composition measurement command.
    bodyComposition: false,
    // Individual uric-acid/lipid commands cannot safely be presented as one
    // complete blood-component measurement until the device reports all values.
    bloodComponents: false,
    sport: flags.sport,
    alarm: flags.alarm,
    sedentaryReminder: flags.sedentaryReminder,
    notification: flags.notification,
    findDevice: flags.findDevice,
    // W8/JL installed-dial access needs a separate RCSP lifecycle. Do not mix
    // it with the Vep dial protocol merely because the firmware advertises it.
    dial: false
  };
}

export function yucSportCapabilityFromFlags(flags?: YucFeatureFlags): YucSportCapability {
  if (!flags || !flags.sport) return { modes: [], supportsPause: false, protocol: 'none' };
  const modes: YucSportMode[] = [];
  if (flags.outdoorRunning) modes.push('running');
  if (flags.outdoorWalking) modes.push('walking');
  if (flags.cycling) modes.push('cycling');
  if (flags.hiking) modes.push('hiking');
  return {
    modes: modes,
    supportsPause: flags.sportPause,
    protocol: modes.length > 0 ? 'realtime' : 'none'
  };
}

// Values are defined by the W8 SDK 2.1.5 appRunMode contract, not the Vep
// sport protocol. In particular, 0x06 means rope skipping and must never be
// used as the fallback for running.
export function yucSportModeProtocolValue(mode: YucSportMode): number {
  if (mode === 'walking') return 0x10;
  if (mode === 'cycling') return 0x03;
  if (mode === 'hiking') return 0x1B;
  return 0x0F;
}

export function yucSportModeFromProtocolValue(value: number): YucSportMode | '' {
  if (value === 0x0F || value === 0x01) return 'running';
  if (value === 0x10 || value === 0x08) return 'walking';
  if (value === 0x03 || value === 0x13) return 'cycling';
  if (value === 0x1B || value === 0x0B) return 'hiking';
  return '';
}

export function yucDecimalValue(integer: number, fraction: number, fractionScale: number = 10): number {
  if (!Number.isFinite(integer) || !Number.isFinite(fraction) || !Number.isFinite(fractionScale) || fractionScale <= 0) return 0;
  const sign = integer < 0 ? -1 : 1;
  return Math.round((integer + sign * Math.abs(fraction) / fractionScale) * 100) / 100;
}

export function yucValidTimestamp(value: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  // SDK 2.1.5 returns milliseconds. Keep compatibility with plug-in payloads
  // expressed as Unix seconds without ever multiplying a millisecond value.
  const timestamp = value < 100000000000 ? value * 1000 : value;
  return timestamp >= 946684800000 && timestamp <= Date.now() + 86400000 ? Math.round(timestamp) : 0;
}
