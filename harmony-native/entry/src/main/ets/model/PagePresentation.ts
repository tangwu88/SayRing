import type { CareField, CareMetric, CareRecord } from './CareContracts';

export interface SummaryLabel { label: string; value: string; }
export interface PageLayout { contentWidth: number; singleColumn: boolean; fontScale: number; }

export function pageLayout(width: number, scale: number): PageLayout {
  const contentWidth = Math.min(720, Number.isFinite(width) && width > 0 ? width : 390);
  const fontScale = Number.isFinite(scale) && scale > 0 ? scale : 1;
  return { contentWidth, fontScale, singleColumn: contentWidth < 360 || fontScale > 1.3 };
}

export function controlHeight(minimum: number, fontScale: number): number {
  return Math.max(48, minimum, Math.ceil(24 * fontScale + 24));
}

function formatted(value: number, unit: string): string {
  return `${Number(value.toFixed(1))}${unit ? ' ' + unit : ''}`;
}

function validField(record: CareRecord, label: string): CareField | undefined {
  return record.fields.find(field => field.label === label && Number.isFinite(field.value) && field.value > 0);
}

// Match the iOS selected-day summary. Composite/ECG records are not averaged.
export function careDaySummary(metric: CareMetric): SummaryLabel[] {
  if (metric.state !== 'ready' || metric.records.length === 0) return [];
  const records = metric.records.slice().sort((a, b) => a.order - b.order);
  const result: SummaryLabel[] = [{ label: '记录数', value: `${records.length} 条` }];
  if (['ecg', 'body', 'blood'].includes(metric.key)) return result;
  if (metric.key === 'pressure') {
    const paired = records.filter(record => validField(record, '收缩压') && validField(record, '舒张压'));
    if (paired.length === 0) return result;
    const high = paired.map(record => validField(record, '收缩压')!.value);
    const low = paired.map(record => validField(record, '舒张压')!.value);
    const pair = (a: number, b: number): string => `${Number(a.toFixed(1))}/${Number(b.toFixed(1))} mmHg`;
    result.push({ label: '最近', value: pair(high[high.length - 1], low[low.length - 1]) },
      { label: '平均', value: pair(high.reduce((a, b) => a + b, 0) / high.length, low.reduce((a, b) => a + b, 0) / low.length) },
      { label: '最高', value: pair(high.reduce((a, b) => Math.max(a, b)), low.reduce((a, b) => Math.max(a, b))) },
      { label: '最低', value: pair(high.reduce((a, b) => Math.min(a, b)), low.reduce((a, b) => Math.min(a, b))) });
    return result;
  }
  const labels: Record<string, string> = { heart: '心率', oxygen: '血氧', glucose: '血糖', temperature: '体温', hrv: 'HRV', sleep: '睡眠' };
  const values: CareField[] = [];
  records.forEach((record: CareRecord) => {
    const value = validField(record, labels[metric.key] || metric.title);
    if (value) values.push(value);
  });
  if (values.length === 0) return result;
  const unit = values[0].unit;
  const matching = values.filter(field => field.unit === unit).map(field => field.value);
  result.push({ label: '最近', value: formatted(matching[matching.length - 1], unit) },
    { label: '平均', value: formatted(matching.reduce((a, b) => a + b, 0) / matching.length, unit) },
    { label: '最高', value: formatted(matching.reduce((a, b) => Math.max(a, b)), unit) },
    { label: '最低', value: formatted(matching.reduce((a, b) => Math.min(a, b)), unit) });
  return result;
}

export function waveformPageCount(sampleCount: number): number { return Math.max(1, Math.ceil(sampleCount / 1000)); }

export function waveformPageLabel(sampleCount: number, segment: number, frequency: number): string {
  const page = Math.max(0, Math.min(waveformPageCount(sampleCount) - 1, Math.floor(segment)));
  const start = page * 1000;
  const end = Math.min(sampleCount, start + 1000);
  if (frequency > 0 && Number.isFinite(frequency)) return `${Number((start / frequency).toFixed(1))}–${Number((end / frequency).toFixed(1))} 秒`;
  return `${start + 1}–${end} / ${sampleCount} 个采样点`;
}
