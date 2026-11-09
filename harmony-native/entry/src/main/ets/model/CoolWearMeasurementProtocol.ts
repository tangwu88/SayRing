import { coolWearQuery } from './CoolWearReadProtocol';
import type { CoolWearCapabilities } from './CoolWearReadProtocol';

export type CoolWearManualMetric = 'heart' | 'oxygen';

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
