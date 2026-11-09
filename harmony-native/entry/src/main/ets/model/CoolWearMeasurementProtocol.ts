import { coolWearQuery } from './CoolWearReadProtocol';
import type { CoolWearCapabilities } from './CoolWearReadProtocol';

export type CoolWearManualMetric = 'heart' | 'oxygen';
export interface CoolWearManualReading { metric: CoolWearManualMetric; value: number; unit: string; receivedAt: number; }
export function coolWearManualValue(metric: CoolWearManualMetric, body: number[]): number | undefined {
  if (!body.length || body[0] === 0 || body.some(byte => !Number.isInteger(byte) || byte < 0 || byte > 255)) return undefined;
  const value = metric === 'heart' ? body[1] : body.length >= 5 ? body[4] : undefined;
  return value !== undefined && value > 0 && value <= (metric === 'oxygen' ? 100 : 250) ? value : undefined;
}

// Original live heart (type 7) strips a three-byte prefix, then parses
// five-byte K6_HeartStruct records. Oxygen (type 20) uses five-byte records.
// Match Android's currentTimestamp bound; never replace an unknown device time.
export function coolWearTimedManualValue(metric: CoolWearManualMetric, body: number[], now: number): number | undefined {
  const offset = metric === 'heart' ? 3 : 0;
  if (body.length < offset + 5 || (body.length - offset) % 5 !== 0 || body.some(b => !Number.isInteger(b) || b < 0 || b > 255)) return undefined;
  for (let i = offset; i + 5 <= body.length; i += 5) {
    const time = (body[i] + body[i + 1] * 256 + body[i + 2] * 65536 + body[i + 3] * 16777216) * 1000;
    const value = body[i + 4];
    if (time >= 1420070400000 && Math.abs(time - now) <= 600000 && value > 0 && value <= (metric === 'heart' ? 250 : 100)) return value;
  }
  return undefined;
}

export function coolWearManualEnded(metric: CoolWearManualMetric, body: number[]): boolean {
  return body.length === 1 && body[0] === (metric === 'heart' ? 0x10 : 0x30);
}

// Matches K6_DATA_TYPE_REAL_HR / REAL_O2.toCEDevData. Deliberately
// separate from the read-only transport; this does not itself send a command.
export function coolWearMeasurementCommand(metric: CoolWearManualMetric, enabled: boolean,
  sequence: number, role: number, capabilities: CoolWearCapabilities): number[] {
  if (metric !== 'heart' && metric !== 'oxygen') throw new Error('Unsupported measurement');
  if (typeof enabled !== 'boolean') throw new Error('Invalid measurement state');
  if (enabled && (metric === 'heart' ? capabilities.heartManual !== true : capabilities.oxygenManual !== true)) {
    throw new Error('设备未确认支持此项测量');
  }
  const bytes = coolWearQuery(2, sequence, role);
  bytes[4] = 1; bytes[5] = metric === 'heart' ? 24 : 20;
  bytes[8] = metric === 'heart' ? 1 : 5;
  bytes[10] = enabled ? 1 : 0;
  return bytes;
}
