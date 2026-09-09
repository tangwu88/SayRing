import type { HealthRecord, HealthValue, WearableMetricKey } from './WearableContracts';
import type { DisplayUnits } from './DisplayPreferences';
import { displayHealthValue } from './DisplayPreferences';

export type TrendPeriod = 'day' | 'week' | 'month';
export interface TrendWindow { start: number; end: number; label: string; }
export interface TrendPoint { time: number; value: number; recordId: string; }
export interface TrendSeries { name: string; unit: string; points: TrendPoint[]; }
export interface TrendSummary { name: string; unit: string; count: number; min: number; max: number; average: number; change?: number; }

export function localDateKey(timestamp: number = Date.now()): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function localDate(day: string): Date {
  const values = day.split('-').map(Number);
  const date = new Date(values[0], values[1] - 1, values[2]);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !Number.isFinite(date.getTime()) || localDateKey(date.getTime()) !== day) throw new Error('日期无效');
  return date;
}

export function trendWindow(day: string, period: TrendPeriod): TrendWindow {
  const start = localDate(day);
  if (period === 'week') start.setDate(start.getDate() - (start.getDay() + 6) % 7);
  if (period === 'month') start.setDate(1);
  const end = new Date(start.getTime());
  if (period === 'month') end.setMonth(end.getMonth() + 1);
  else end.setDate(end.getDate() + (period === 'week' ? 7 : 1));
  const label = period === 'day' ? `${start.getFullYear()}年${start.getMonth() + 1}月${start.getDate()}日` :
    period === 'month' ? `${start.getFullYear()}年${start.getMonth() + 1}月` : `${localDateKey(start.getTime())} ～ ${localDateKey(end.getTime() - 1)}`;
  return { start: start.getTime(), end: end.getTime(), label };
}

export function shiftTrendDay(day: string, period: TrendPeriod, direction: number): string {
  const date = localDate(day);
  if (period === 'month') { date.setDate(1); date.setMonth(date.getMonth() + direction); }
  else date.setDate(date.getDate() + direction * (period === 'week' ? 7 : 1));
  return localDateKey(date.getTime());
}

export function trendRecords(records: HealthRecord[], metric: WearableMetricKey, deviceKey: string,
  window: TrendWindow): HealthRecord[] {
  const ids: Map<string, HealthRecord> = new Map();
  records.forEach((record: HealthRecord) => {
    if (record.metric === metric && record.deviceKey === deviceKey && Number.isFinite(record.timestamp) &&
      record.timestamp >= window.start && record.timestamp < window.end) ids.set(record.id, record);
  });
  return Array.from(ids.values()).sort((a: HealthRecord, b: HealthRecord) => a.timestamp - b.timestamp);
}

export function trendFieldNames(records: HealthRecord[]): string[] {
  const names: Set<string> = new Set();
  records.forEach((record: HealthRecord) => record.values.forEach((value: HealthValue) => {
    if (Number.isFinite(value.value)) names.add(value.name);
  }));
  return Array.from(names);
}

export function trendSeries(records: HealthRecord[], name: string, period: TrendPeriod, units: DisplayUnits): TrendSeries {
  const samples: TrendPoint[] = [];
  let unit = '';
  records.forEach((record: HealthRecord) => {
    const raw = record.values.find((value: HealthValue) => value.name === name && Number.isFinite(value.value));
    if (!raw) return;
    const value = displayHealthValue(raw, units);
    if (samples.length && unit !== value.unit) return; // Never mix differently scaled data.
    unit = value.unit;
    samples.push({ time: record.timestamp, value: value.value, recordId: record.id });
  });
  if (period === 'day') return { name, unit, points: samples };
  const groups: Map<string, TrendPoint[]> = new Map();
  samples.forEach((point: TrendPoint) => {
    const key = localDateKey(point.time); const group = groups.get(key) ?? [];
    group.push(point); groups.set(key, group);
  });
  const points: TrendPoint[] = [];
  groups.forEach((group: TrendPoint[], day: string) => {
    // Activity is a daily cumulative counter, not additive samples.
    const value = records[0]?.metric === 'activity' ? group.reduce((max: number, point: TrendPoint) => Math.max(max, point.value), -Infinity) :
      group.reduce((sum: number, point: TrendPoint) => sum + point.value, 0) / group.length;
    points.push({ time: localDate(day).getTime(), value, recordId: group[group.length - 1].recordId });
  });
  return { name, unit, points: points.sort((a: TrendPoint, b: TrendPoint) => a.time - b.time) };
}

export function trendSummary(records: HealthRecord[], previous: HealthRecord[], name: string, units: DisplayUnits): TrendSummary | undefined {
  if (records[0]?.metric === 'ecg') return undefined;
  const aggregation: TrendPeriod = records[0]?.metric === 'activity' ? 'month' : 'day';
  const series = trendSeries(records, name, aggregation, units);
  if (!series.points.length) return undefined;
  const values = series.points.map((point: TrendPoint) => point.value);
  const average = values.reduce((sum: number, value: number) => sum + value, 0) / values.length;
  const old = trendSeries(previous, name, aggregation, units);
  const prior = old.points.length && old.unit === series.unit ?
    old.points.reduce((sum: number, point: TrendPoint) => sum + point.value, 0) / old.points.length : undefined;
  return { name, unit: series.unit, count: values.length,
    min: values.reduce((min: number, value: number) => Math.min(min, value), Infinity),
    max: values.reduce((max: number, value: number) => Math.max(max, value), -Infinity),
    average, change: prior === undefined ? undefined : average - prior };
}

// Match the iOS chart: samples are spread by their display order so nearby
// measurements remain readable, while each TrendPoint keeps its real time.
export function spreadChartX(index: number, count: number, width: number): number {
  const safeWidth = Math.max(1, width);
  if (count <= 1) return safeWidth / 2;
  const safeIndex = Math.max(0, Math.min(count - 1, index));
  return safeIndex / (count - 1) * safeWidth;
}

export function spreadChartPoints(series: TrendSeries, min: number, max: number, width: number): number[][] {
  const span = Math.max(1, max - min);
  return series.points.map((point: TrendPoint, index: number) => [
    spreadChartX(index, series.points.length, width),
    144 - (point.value - min) / span * 128
  ]);
}

export function spreadChartIndex(x: number, width: number, count: number): number {
  if (count <= 1) return 0;
  const ratio = Math.max(0, Math.min(1, x / Math.max(1, width)));
  return Math.max(0, Math.min(count - 1, Math.round(ratio * (count - 1))));
}

// Plot only real samples, retaining first/last and local peaks. Statistics and
// record details continue to use every sample; drawing density is not storage.
export function plotSeries(series: TrendSeries, maximum: number = 256): TrendSeries {
  const limit = Math.max(4, Math.floor(maximum));
  if (series.points.length <= limit) return series;
  const source = series.points;
  const buckets = Math.floor((limit - 2) / 2);
  const points: TrendPoint[] = [source[0]];
  for (let bucket = 0; bucket < buckets; bucket++) {
    const start = 1 + Math.floor(bucket * (source.length - 2) / buckets);
    const end = 1 + Math.floor((bucket + 1) * (source.length - 2) / buckets);
    let low = start; let high = start;
    for (let i = start + 1; i < end; i++) {
      if (source[i].value < source[low].value) low = i;
      if (source[i].value > source[high].value) high = i;
    }
    points.push(source[Math.min(low, high)]);
    if (low !== high) points.push(source[Math.max(low, high)]);
  }
  points.push(source[source.length - 1]);
  return { name: series.name, unit: series.unit, points };
}

export function waveformPoints(samples: number[], width: number): number[][] {
  if (samples.length < 2 || samples.some((value: number) => !Number.isFinite(value))) return [];
  const min = samples.reduce((value: number, item: number) => Math.min(value, item), Infinity);
  const max = samples.reduce((value: number, item: number) => Math.max(value, item), -Infinity);
  return samples.map((value: number, index: number) => [index * width / (samples.length - 1), 112 - (value - min) / Math.max(1, max - min) * 104]);
}
