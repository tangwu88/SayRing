import { AlarmClockControl, AlarmClockItem, VPBleSDK } from '@veepoo/vpble-sdk';
import { vepWearable } from './VepWearableService';
import {
  AlarmsResult, AssertDeviceSession, DeviceSettingsPort, SettingsResult, UnitsResult,
  WatchAlarm, WatchUnitField, WatchUnits, copyWatchUnits, deleteWatchAlarm, readWatchAlarms, readWatchUnits,
  saveWatchAlarm, saveWatchUnit
} from '../model/DeviceSettingsTransactions';

class VepSettingsPort implements DeviceSettingsPort {
  private sdk: VPBleSDK;
  constructor(sdk: VPBleSDK) { this.sdk = sdk; }
  async readUnits(): Promise<UnitsResult> {
    const result = await this.sdk.configService.getSwitchConfig();
    return { success: result.success, errorMessage: result.errorMessage,
      data: result.data ? copyWatchUnits(result.data) : undefined };
  }
  async writeUnits(config: WatchUnits): Promise<SettingsResult> {
    // SDK 1.0.0 setUnitValue also overwrites timeFormat from the phone clock.
    // Only the complete fresh read / single-field edit / complete readback path is safe.
    const result = await this.sdk.configService.setSwitchConfig(copyWatchUnits(config));
    return { success: result.success, errorMessage: result.errorMessage };
  }
  async readAlarms(): Promise<AlarmsResult> {
    const result = await this.sdk.alarmClockService.readAll();
    return { success: result.success, errorMessage: result.errorMessage,
      data: result.data?.map((alarm: AlarmClockItem): WatchAlarm => {
        return { id: alarm.alarmClockId, enabled: alarm.enabled, time: alarm.time, label: alarm.labels,
          days: [alarm.repeat.monday, alarm.repeat.tuesday, alarm.repeat.wednesday, alarm.repeat.thursday,
            alarm.repeat.friday, alarm.repeat.saturday, alarm.repeat.sunday] };
      }) };
  }
  async writeAlarm(alarm: WatchAlarm): Promise<SettingsResult> {
    const item: AlarmClockItem = { alarmClockId: alarm.id, enabled: alarm.enabled, time: alarm.time, labels: alarm.label,
      repeat: { monday: alarm.days[0], tuesday: alarm.days[1], wednesday: alarm.days[2], thursday: alarm.days[3],
        friday: alarm.days[4], saturday: alarm.days[5], sunday: alarm.days[6] } };
    return this.sdk.alarmClockService.set(item, AlarmClockControl.SET);
  }
  async deleteAlarm(id: number): Promise<SettingsResult> { return this.sdk.alarmClockService.delete(id); }
}

export class VepDeviceSettingsAdapter {
  async readUnits(): Promise<WatchUnits> {
    return vepWearable.runDeviceCommand('读取手表单位', async (current: AssertDeviceSession): Promise<WatchUnits> =>
      readWatchUnits(new VepSettingsPort(VPBleSDK.getInstance()), current));
  }
  async setUnit(field: WatchUnitField, value: number, expected: number): Promise<WatchUnits> {
    return vepWearable.runDeviceCommand('保存手表单位', async (current: AssertDeviceSession): Promise<WatchUnits> =>
      saveWatchUnit(new VepSettingsPort(VPBleSDK.getInstance()), current, field, value, expected));
  }
  async readAlarms(): Promise<WatchAlarm[]> {
    return vepWearable.runDeviceCommand('读取闹钟', async (current: AssertDeviceSession): Promise<WatchAlarm[]> => {
      this.requireAlarm(); return readWatchAlarms(new VepSettingsPort(VPBleSDK.getInstance()), current);
    });
  }
  async setAlarm(draft: WatchAlarm, expected?: WatchAlarm): Promise<WatchAlarm[]> {
    return vepWearable.runDeviceCommand('保存闹钟', async (current: AssertDeviceSession): Promise<WatchAlarm[]> => {
      this.requireAlarm(); return saveWatchAlarm(new VepSettingsPort(VPBleSDK.getInstance()), current, draft, expected);
    });
  }
  async deleteAlarm(expected: WatchAlarm): Promise<WatchAlarm[]> {
    return vepWearable.runDeviceCommand('删除闹钟', async (current: AssertDeviceSession): Promise<WatchAlarm[]> => {
      this.requireAlarm(); return deleteWatchAlarm(new VepSettingsPort(VPBleSDK.getInstance()), current, expected);
    });
  }
  private requireAlarm(): void {
    if (!vepWearable.currentSnapshot().capabilities.alarm) throw new Error('当前手表不支持闹钟管理');
  }
}
export const vepDeviceSettings: VepDeviceSettingsAdapter = new VepDeviceSettingsAdapter();
