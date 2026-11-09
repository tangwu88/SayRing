import { ble, constant } from '@kit.ConnectivityKit';
import { COOLWEAR_SERVICE, CoolWearPacket, CoolWearReadDecoder, CoolWearReadResult,
  coolWearQuery, coolWearAck, coolWearFirmware, coolWearBattery, coolWearCapabilitiesQuery, coolWearCapabilities, CoolWearCapabilities } from '../model/CoolWearReadProtocol';

// A temporary, explicitly selected target. Never creates a persistent binding
// or reports SDK capabilities. Leaving the page/owner cancels every callback.
export class CoolWearReadOnlySession {
  private generation: number = 0;
  private client: ble.GattClientDevice | undefined = undefined;
  private rejectPending: ((reason: Error) => void) | undefined = undefined;
  cancel(): void {
    ++this.generation;
    this.rejectPending?.(new Error('连接验证已取消'));
    this.rejectPending = undefined;
    const client = this.client; this.client = undefined;
    if (client) { try { client.disconnect(); } catch {} try { client.close(); } catch {} }
  }
  async read(target: string, current: () => boolean, onProgress: (message: string) => void = () => {}, readCapabilities: boolean = false): Promise<CoolWearReadResult> {
    this.cancel();
    if (!target || !current()) throw new Error('请重新选择设备');
    const generation = this.generation, client = ble.createGattClientDevice(target);
    this.client = client;
    const active = (): boolean => generation === this.generation && current() && this.client === client;
    const assertCurrent = (): void => { if (!active()) throw new Error('账号或设备已变化'); };
    let timer: number = -1, ownerTimer: number = -1;
    const result = new Promise<CoolWearReadResult>((resolve, reject) => {
      this.rejectPending = reject;
      let phase = '蓝牙连接';
      const progress = (next: string): void => { phase = next; if (active()) onProgress(`正在${next}…`); };
      timer = setTimeout(() => reject(new Error(`${phase}超时，本次验证已结束`)), 18000);
      ownerTimer = setInterval(() => { if (!active()) reject(new Error('连接验证已取消')); }, 200);
      const decoder = new CoolWearReadDecoder();
      let writer: ble.BLECharacteristic | undefined = undefined;
      let notifier: ble.BLECharacteristic | undefined = undefined;
      let connecting: boolean = false, batteryRequested: boolean = false, firmware: string = '';
      let battery: number | undefined = undefined, charging: boolean | undefined = undefined;
      let capabilities: CoolWearCapabilities | undefined = undefined, capabilitiesRequested: boolean = false;
      let writeQueue: Promise<void> = Promise.resolve();
      const write = (bytes: number[]): Promise<void> => {
        writeQueue = writeQueue.then(async (): Promise<void> => {
          assertCurrent(); if (!writer) throw new Error('设备没有可用的数据通道');
          const value: ble.BLECharacteristic = { serviceUuid: writer.serviceUuid, characteristicUuid: writer.characteristicUuid,
            characteristicValue: new Uint8Array(bytes).buffer, descriptors: writer.descriptors };
          await client.writeCharacteristicValue(value, writer.properties?.writeNoResponse ? ble.GattWriteType.WRITE_NO_RESPONSE : ble.GattWriteType.WRITE);
          assertCurrent();
        });
        return writeQueue;
      };
      client.on('BLECharacteristicChange', (value: ble.BLECharacteristic) => {
        if (!active() || !notifier || value.serviceUuid.toLowerCase() !== COOLWEAR_SERVICE ||
          value.characteristicUuid.toLowerCase() !== notifier.characteristicUuid.toLowerCase()) return;
        const bytes = Array.from(new Uint8Array(value.characteristicValue));
        // Structural diagnostics only: no address, payload or health values.
        console.warn(`[RingRead] bytes=${bytes.length}, page=${bytes[0]}, role=${bytes[0] === 0 ? bytes[1] : -1}, pages=${bytes[0] === 0 ? bytes[2] : -1}, cmd=${bytes.length >= 10 && bytes[0] === 0 ? bytes[4] : -1}, type=${bytes.length >= 10 && bytes[0] === 0 ? bytes[5] : -1}, size=${bytes.length >= 10 && bytes[0] === 0 ? bytes[8] + bytes[9] * 256 : -1}`);
        const packet = decoder.accept(bytes, Date.now());
        if (!packet) return;
        if (packet.command === 1) write(coolWearAck(packet)).catch(() => reject(new Error('设备确认未完成')));
        if (packet.type === 2) {
          firmware = coolWearFirmware(packet.body) ?? '';
          if (firmware && !batteryRequested) {
            batteryRequested = true;
            progress('读取电量');
            write(coolWearQuery(3, 2, packet.role)).catch(reject);
          }
        }
        if (packet.type === 3) { battery = coolWearBattery(packet.body); charging = packet.body.length > 1 && packet.body[1] <= 1 ? packet.body[1] === 1 : undefined; }
        if (packet.type === 22 && readCapabilities && capabilitiesRequested) capabilities = coolWearCapabilities(packet.body);
        if (firmware && battery !== undefined && readCapabilities && !capabilitiesRequested) {
          capabilitiesRequested = true; progress('读取戒指能力'); write(coolWearCapabilitiesQuery(3, packet.role)).catch(reject);
        }
        if (firmware && battery !== undefined && (!readCapabilities || capabilities !== undefined)) {
          writeQueue.then(() => { if (active()) resolve(readCapabilities ? { firmware, battery, charging, capabilities } : { firmware, battery, charging }); }).catch(reject);
        }
      });
      client.on('BLEConnectionStateChange', (event: ble.BLEConnectionChangeState) => {
        if (!active() || event.deviceId.toUpperCase() !== target.toUpperCase()) return;
        if (event.state === constant.ProfileConnectionState.STATE_DISCONNECTED) { reject(new Error('设备已断开，请稍后重试')); return; }
        if (event.state !== constant.ProfileConnectionState.STATE_CONNECTED || connecting) return;
        connecting = true;
        const initialize = async (): Promise<void> => {
          progress('读取蓝牙服务');
          const services = await client.getServices(); assertCurrent();
          const service = services.find(item => item.serviceUuid.toLowerCase() === COOLWEAR_SERVICE);
          if (!service) throw new Error('该设备没有匹配的数据服务');
          const notify = service.characteristics.filter(item => item.properties?.notify);
          const writes = service.characteristics.filter(item => item.properties?.write || item.properties?.writeNoResponse);
          if (notify.length !== 1 || writes.length !== 1) throw new Error('设备数据通道尚未确认');
          notifier = notify[0]; writer = writes[0];
          progress('开启设备通知');
          await client.setCharacteristicChangeNotification(notifier, true); assertCurrent();
          progress('读取设备信息');
          await write(coolWearQuery(2, 1));
        };
        initialize().catch(reject);
      });
      try { client.connect(); } catch { reject(new Error('无法建立设备连接')); }
    });
    try { const value = await result; assertCurrent(); return value; }
    finally {
      clearTimeout(timer); clearInterval(ownerTimer);
      if (this.client === client) { this.rejectPending = undefined; this.cancel(); }
      else { try { client.close(); } catch {} }
    }
  }
}
