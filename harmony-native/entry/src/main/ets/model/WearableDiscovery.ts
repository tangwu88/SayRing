// Discovery identity is separate from a verified hardware address. Some Vep
// firmware uses a different manufacturer ID, as permitted by the iOS SDK.
export interface DiscoveryPacket {
  id: string;
  name: string;
  rssi: number;
  connectable: boolean;
  data: number[];
}

interface AdvertisementField { type: number; bytes: number[]; }
interface CachedPacket { packet: DiscoveryPacket; updatedAt: number; }

function fields(data: number[]): AdvertisementField[] {
  const result: AdvertisementField[] = [];
  for (let offset = 0; offset < data.length;) {
    const size = data[offset];
    if (!Number.isInteger(size) || size <= 0 || offset + size >= data.length) break;
    result.push({ type: data[offset + 1], bytes: data.slice(offset + 2, offset + size + 1) });
    offset += size + 1;
  }
  return result;
}

export function advertisedName(data: number[]): string {
  const all = fields(data);
  const name = all.find((field: AdvertisementField) => field.type === 9) ??
    all.find((field: AdvertisementField) => field.type === 8);
  if (!name) return '';
  try {
    return decodeURIComponent(name.bytes.map((byte: number) => `%${byte.toString(16).padStart(2, '0')}`).join(''))
      .replace(/[\u0000-\u001f\u007f]/g, '').trim();
  } catch { return ''; }
}

export function knownWearableName(name: string): 'Vep' | 'Yuc' | '' {
  const normalized = name.replace(/[\u0000-\u001f\u007f]/g, '').trim();
  if (/W8/i.test(normalized)) return 'Yuc';
  // Explicit product names only; never expose every nearby BLE peripheral as a watch.
  return /^(?:SD[ _-]*WATCH[ _-]*)?(?:ET488|W9S?)(?:[ _-]+[A-F0-9]{4,6})?$/i.test(normalized) ? 'Vep' : '';
}

export function mergeAdvertisement(previous: number[], incoming: number[]): number[] {
  const merged: AdvertisementField[] = fields(previous);
  fields(incoming).forEach((field: AdvertisementField) => {
    const existing = merged.findIndex((item: AdvertisementField) => item.type === field.type);
    if (existing >= 0) merged[existing] = field;
    else merged.push(field);
  });
  const output: number[] = [];
  merged.forEach((field: AdvertisementField) => {
    if (field.bytes.length > 253 || output.length + field.bytes.length + 2 > 512) return;
    output.push(field.bytes.length + 1, field.type);
    field.bytes.forEach((byte: number) => output.push(byte));
  });
  return output;
}

export class DiscoveryPacketCache {
  private packets: Map<string, CachedPacket> = new Map();

  clear(): void { this.packets.clear(); }

  observe(packet: DiscoveryPacket, now: number): DiscoveryPacket {
    this.packets.forEach((cached: CachedPacket, id: string) => {
      if (now - cached.updatedAt > 12000) this.packets.delete(id);
    });
    const previous = this.packets.get(packet.id)?.packet;
    const data = mergeAdvertisement(previous?.data ?? [], packet.data);
    const name = packet.name.trim() || advertisedName(data) || previous?.name || '';
    const result: DiscoveryPacket = { id: packet.id, name: name, rssi: packet.rssi,
      connectable: packet.connectable, data: data };
    if (!packet.id || !Number.isFinite(packet.rssi)) return result;
    // Eviction remains deterministic and bounded, even in a crowded public place.
    if (!this.packets.has(packet.id) && this.packets.size >= 256) {
      let oldestKey = '';
      let oldestTime = Infinity;
      this.packets.forEach((value: CachedPacket, key: string) => {
        if (value.updatedAt < oldestTime) { oldestKey = key; oldestTime = value.updatedAt; }
      });
      this.packets.delete(oldestKey);
    }
    this.packets.set(packet.id, { packet: result, updatedAt: now });
    return result;
  }
}
