// Read-only interoperability baseline verified against the owner-supplied
// CEProtocolB(1) encoder. No setting, binding, measurement or history writes.
export const COOLWEAR_SERVICE = '0000f618-0000-1000-8000-00805f9b34fb';
export interface CoolWearPacket { role: number; sequence: number; command: number; type: number; body: number[]; }
export interface CoolWearReadResult { firmware: string; battery?: number; charging?: boolean; }
export function coolWearQuery(type: number, sequence: number, role: number = 1): number[] {
  if (![2, 3].includes(type) || !Number.isInteger(sequence) || sequence < 0 || sequence > 255 ||
    !Number.isInteger(role) || role < 0 || role > 255) throw new Error('Unsupported read');
  const bytes: number[] = new Array(20).fill(0);
  bytes[1] = role; bytes[3] = sequence; bytes[4] = 3; bytes[5] = type;
  return bytes;
}
export function coolWearAck(packet: CoolWearPacket): number[] {
  if (![2, 3].includes(packet.type) || packet.command !== 1) throw new Error('Unsupported acknowledgement');
  const bytes = coolWearQuery(packet.type, packet.sequence, packet.role);
  bytes[4] = 4; bytes[8] = 1; bytes[10] = 1;
  return bytes;
}
export class CoolWearReadDecoder {
  private pending: CoolWearPacket | undefined = undefined;
  private size: number = 0;
  private index: number = 0;
  private updatedAt: number = 0;
  clear(): void { this.pending = undefined; this.size = 0; this.index = 0; }
  accept(bytes: number[], now: number): CoolWearPacket | undefined {
    if (now - this.updatedAt > 3000) this.clear();
    this.updatedAt = now;
    if (bytes.length < 1 || bytes.length > 20 || bytes.some(byte => !Number.isInteger(byte) || byte < 0 || byte > 255)) { this.clear(); return undefined; }
    if (bytes[0] === 0) {
      this.clear();
      if (bytes.length < 10) return undefined;
      const command = bytes[4] & 15, size = bytes[8] | (bytes[9] << 8);
      if (![1, 2].includes(command) || ![2, 3].includes(bytes[5]) || size < 1 || size > 64 ||
        bytes[2] !== Math.max(0, Math.ceil((size - 10) / 19)) || bytes.length < 10 + Math.min(size, 10)) return undefined;
      // The original Analysis updates its devType from the peer header (e.g.
      // 101 on R7 Ultra); this is a framing field, not device authentication.
      this.pending = { role: bytes[1], sequence: bytes[3], command, type: bytes[5], body: bytes.slice(10, 10 + Math.min(size, 10)) };
      this.size = size;
    } else {
      if (!this.pending || bytes[0] !== this.index + 1) { this.clear(); return undefined; }
      if (bytes.length < 1 + Math.min(19, this.size - this.pending.body.length)) { this.clear(); return undefined; }
      this.index = bytes[0];
      this.pending.body.push(...bytes.slice(1, 1 + Math.min(19, this.size - this.pending.body.length)));
    }
    if (!this.pending || this.pending.body.length !== this.size) return undefined;
    const result = this.pending; this.clear(); return result;
  }
}
export function coolWearFirmware(body: number[]): string | undefined {
  if (body.length < (body[0] === 12 ? 7 : 6)) return undefined;
  return body.slice(1, 6).join('.');
}
export function coolWearBattery(body: number[]): number | undefined {
  return body.length >= 1 && Number.isInteger(body[0]) && body[0] >= 0 && body[0] <= 100 ? body[0] : undefined;
}
