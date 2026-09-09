import {
  AutoMeasureConfig, BtState, ContactItem, FeatureModuleSwitch, HealthReminderConfig,
  DialTransferState, MeasureTimeSlot, MsgSwitchConfig, PhotoControlPush, PhotoTakeState, RaiseToWakeConfig,
  SDKEventType, SedentaryReminderConfig, VPBleSDK, WeatherInfo, WeatherUnit, WorldClockItem
} from '@veepoo/vpble-sdk';
import { fileIo } from '@kit.CoreFileKit';
import { vepWearable } from './VepWearableService';
import {
  WatchAssessmentSetting, WatchAutoMeasureSetting, WatchContact, WatchNotificationKey,
  WatchNotificationSetting, WatchPhoneState, WatchPhotoDialProfile, WatchReminder,
  WatchScreenSetting, WatchWeatherSetting, WatchWorldClock, assessmentLabel,
  autoMeasureLabel, emptyPhoneState, emptyScreenSetting,
  nextWatchItemId, notificationLabel, normalizedTime, watchContactError
} from '../model/DeviceFeatureContracts';

export type CameraRemoteListener = (captureRequested: boolean, message: string) => void;
export type PhotoDialProgressListener = (progress: number, message: string) => void;

function requireSuccess(success: boolean, message: string, vendorMessage?: string): void {
  if (!success) throw new Error(vendorMessage || message);
}

export class VepDeviceFeatureAdapter {
  private sdk: VPBleSDK = VPBleSDK.getInstance();
  private cameraListener: CameraRemoteListener | undefined = undefined;
  private cameraEventsAttached: boolean = false;

  private requireVep(feature: string): void {
    const snapshot = vepWearable.currentSnapshot();
    if (!snapshot.connected) throw new Error('请先连接手表');
    if (snapshot.provider !== 'Vep') throw new Error(`当前 W8 SDK 暂未开放${feature}`);
  }

  private async command<T>(name: string, feature: string,
    action: (current: () => void) => Promise<T>): Promise<T> {
    this.requireVep(feature);
    return vepWearable.runDeviceCommand(name, action);
  }

  async readPhoneState(): Promise<WatchPhoneState> {
    return this.command('读取蓝牙通话', '蓝牙通话设置', async (current: () => void): Promise<WatchPhoneState> => {
      const result = await this.sdk.btService.getBtStatus(); current();
      requireSuccess(result.success && result.data !== undefined, '蓝牙通话状态读取失败', result.errorMessage);
      if (!result.data) return emptyPhoneState();
      return {
        enabled: result.data.btSwitch > 0,
        connected: result.data.btState === BtState.CONNECTED,
        autoReconnect: result.data.btSwitch === 1,
        multimediaEnabled: result.data.multimediaSwitch > 0,
        paired: result.data.paired > 0
      };
    });
  }

  async connectPhoneAudio(): Promise<WatchPhoneState> {
    return this.command('连接蓝牙通话', '蓝牙通话设置', async (current: () => void): Promise<WatchPhoneState> => {
      await this.sdk.btService.connectBt(); current();
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500)); current();
      const result = await this.sdk.btService.getBtStatus(); current();
      requireSuccess(result.success && result.data !== undefined, '蓝牙通话连接状态读取失败', result.errorMessage);
      if (!result.data) return emptyPhoneState();
      return {
        enabled: result.data.btSwitch > 0,
        connected: result.data.btState === BtState.CONNECTED,
        autoReconnect: result.data.btSwitch === 1,
        multimediaEnabled: result.data.multimediaSwitch > 0,
        paired: result.data.paired > 0
      };
    });
  }

  async readContacts(): Promise<WatchContact[]> {
    return this.command('读取联系人', '联系人', async (current: () => void): Promise<WatchContact[]> => {
      const result = await this.sdk.contactService.list(); current();
      requireSuccess(result.success && result.data !== undefined, '联系人读取失败', result.errorMessage);
      return (result.data ?? []).map((item: ContactItem): WatchContact => ({
        id: item.id, name: item.name.trim(), phone: item.phone.trim(), sos: item.sos === true
      })).sort((a: WatchContact, b: WatchContact) => a.id - b.id);
    });
  }

  async saveContact(draft: WatchContact, expected?: WatchContact): Promise<WatchContact[]> {
    const error = watchContactError(draft);
    if (error) throw new Error(error);
    return this.command('保存联系人', '联系人', async (current: () => void): Promise<WatchContact[]> => {
      const beforeResult = await this.sdk.contactService.list(); current();
      requireSuccess(beforeResult.success && beforeResult.data !== undefined, '联系人读取失败', beforeResult.errorMessage);
      const before = beforeResult.data ?? [];
      if (expected) {
        const currentItem = before.find((item: ContactItem) => item.id === expected.id);
        if (!currentItem || currentItem.name !== expected.name || currentItem.phone !== expected.phone ||
          currentItem.sos !== expected.sos) throw new Error('联系人已变化，请重新读取后再修改');
      }
      const id = draft.id > 0 ? draft.id : nextWatchItemId(before.map((item: ContactItem) => item.id));
      const item: ContactItem = { id: id, name: draft.name.replace(/\s+/g, ' ').trim(),
        phone: draft.phone.replace(/[\s-]/g, '').trim(), sos: draft.sos };
      const saved = await this.sdk.contactService.save(item, false); current();
      requireSuccess(saved.success, '联系人保存失败', saved.errorMessage);
      const readback = await this.sdk.contactService.list(); current();
      requireSuccess(readback.success && readback.data !== undefined, '联系人保存后读取失败', readback.errorMessage);
      const confirmed = (readback.data ?? []).find((value: ContactItem) => value.id === id);
      if (!confirmed || confirmed.name !== item.name || confirmed.phone !== item.phone) {
        throw new Error('手表尚未确认联系人已保存');
      }
      return (readback.data ?? []).map((value: ContactItem): WatchContact => ({
        id: value.id, name: value.name, phone: value.phone, sos: value.sos
      })).sort((a: WatchContact, b: WatchContact) => a.id - b.id);
    });
  }

  async deleteContact(expected: WatchContact): Promise<WatchContact[]> {
    return this.command('删除联系人', '联系人', async (current: () => void): Promise<WatchContact[]> => {
      const before = await this.sdk.contactService.list(); current();
      requireSuccess(before.success && before.data !== undefined, '联系人读取失败', before.errorMessage);
      const currentItem = (before.data ?? []).find((item: ContactItem) => item.id === expected.id);
      if (!currentItem || currentItem.name !== expected.name || currentItem.phone !== expected.phone) {
        throw new Error('联系人已变化，请重新读取后再删除');
      }
      const removed = await this.sdk.contactService.delete(expected.id); current();
      requireSuccess(removed.success, '联系人删除失败', removed.errorMessage);
      const readback = await this.sdk.contactService.list(); current();
      requireSuccess(readback.success && readback.data !== undefined, '联系人删除后读取失败', readback.errorMessage);
      if ((readback.data ?? []).some((item: ContactItem) => item.id === expected.id)) {
        throw new Error('手表尚未确认联系人已删除');
      }
      return (readback.data ?? []).map((value: ContactItem): WatchContact => ({
        id: value.id, name: value.name, phone: value.phone, sos: value.sos
      })).sort((a: WatchContact, b: WatchContact) => a.id - b.id);
    });
  }

  async setSosContact(expected: WatchContact): Promise<WatchContact[]> {
    return this.command('设置 SOS 联系人', '联系人', async (current: () => void): Promise<WatchContact[]> => {
      const before = await this.sdk.contactService.list(); current();
      requireSuccess(before.success && before.data !== undefined, '联系人读取失败', before.errorMessage);
      const target = (before.data ?? []).find((item: ContactItem) => item.id === expected.id);
      if (!target || target.name !== expected.name || target.phone !== expected.phone) {
        throw new Error('联系人已变化，请重新读取后再设置');
      }
      for (const item of (before.data ?? []).filter((value: ContactItem) => value.sos && value.id !== target.id)) {
        const cleared = await this.sdk.contactService.save({ id: item.id, name: item.name, phone: item.phone, sos: false }, true); current();
        requireSuccess(cleared.success, '原 SOS 联系人取消失败', cleared.errorMessage);
      }
      const saved = await this.sdk.contactService.save({ id: target.id, name: target.name, phone: target.phone, sos: true }, true); current();
      requireSuccess(saved.success, 'SOS 联系人设置失败', saved.errorMessage);
      const readback = await this.sdk.contactService.list(); current();
      requireSuccess(readback.success && readback.data !== undefined, 'SOS 联系人设置后读取失败', readback.errorMessage);
      const sosItems = (readback.data ?? []).filter((item: ContactItem) => item.sos);
      if (sosItems.length !== 1 || sosItems[0].id !== target.id) throw new Error('手表尚未确认新的 SOS 联系人');
      return (readback.data ?? []).map((value: ContactItem): WatchContact => ({
        id: value.id, name: value.name, phone: value.phone, sos: value.sos
      })).sort((a: WatchContact, b: WatchContact) => a.id - b.id);
    });
  }

  async readNotifications(): Promise<WatchNotificationSetting[]> {
    return this.command('读取消息通知', '消息通知', async (current: () => void): Promise<WatchNotificationSetting[]> => {
      const result = await this.sdk.configService.getMsgSwitchConfig(); current();
      requireSuccess(result.success && result.data !== undefined, '消息通知设置读取失败', result.errorMessage);
      return this.notificationSettings(result.data as MsgSwitchConfig);
    });
  }

  async setNotification(key: WatchNotificationKey, enabled: boolean): Promise<WatchNotificationSetting[]> {
    return this.command('保存消息通知', '消息通知', async (current: () => void): Promise<WatchNotificationSetting[]> => {
      const result = await this.sdk.configService.setSingleMsgSwitch(key, enabled); current();
      requireSuccess(result.success, '消息通知设置保存失败', result.errorMessage);
      const readback = await this.sdk.configService.getMsgSwitchConfig(); current();
      requireSuccess(readback.success && readback.data !== undefined, '消息通知保存后读取失败', readback.errorMessage);
      const settings = this.notificationSettings(readback.data as MsgSwitchConfig);
      const confirmed = settings.find((item: WatchNotificationSetting) => item.key === key);
      if (!confirmed || confirmed.enabled !== enabled) throw new Error('手表尚未确认消息通知设置');
      return settings;
    });
  }

  async readWeather(): Promise<WatchWeatherSetting> {
    return this.command('读取天气设置', '天气', async (current: () => void): Promise<WatchWeatherSetting> => {
      const result = await this.sdk.weatherService.getInfo(); current();
      requireSuccess(result.success && result.data !== undefined, '天气设置读取失败', result.errorMessage);
      return { enabled: result.data?.enabled === true, celsius: result.data?.unit !== WeatherUnit.FAHRENHEIT };
    });
  }

  async saveWeather(value: WatchWeatherSetting): Promise<WatchWeatherSetting> {
    return this.command('保存天气设置', '天气', async (current: () => void): Promise<WatchWeatherSetting> => {
      const info: WeatherInfo = { enabled: value.enabled,
        unit: value.celsius ? WeatherUnit.CELSIUS : WeatherUnit.FAHRENHEIT };
      const saved = await this.sdk.weatherService.setInfo(info); current();
      requireSuccess(saved.success, '天气设置保存失败', saved.errorMessage);
      const readback = await this.sdk.weatherService.getInfo(); current();
      requireSuccess(readback.success && readback.data !== undefined, '天气设置保存后读取失败', readback.errorMessage);
      const confirmed: WatchWeatherSetting = { enabled: readback.data?.enabled === true,
        celsius: readback.data?.unit !== WeatherUnit.FAHRENHEIT };
      if (confirmed.enabled !== value.enabled || confirmed.celsius !== value.celsius) {
        throw new Error('手表尚未确认天气设置');
      }
      return confirmed;
    });
  }

  async readWorldClocks(): Promise<WatchWorldClock[]> {
    return this.command('读取世界时钟', '世界时钟', async (current: () => void): Promise<WatchWorldClock[]> => {
      const result = await this.sdk.worldClockService.list(); current();
      requireSuccess(result.success && result.data !== undefined, '世界时钟读取失败', result.errorMessage);
      return (result.data ?? []).map((item: WorldClockItem): WatchWorldClock => ({
        id: item.clockId, city: item.city.trim(), utcOffsetMinutes: item.timeZone * 15
      })).sort((a: WatchWorldClock, b: WatchWorldClock) => a.id - b.id);
    });
  }

  async addWorldClock(city: string, utcOffsetMinutes: number): Promise<WatchWorldClock[]> {
    const normalizedCity = city.replace(/\s+/g, ' ').trim();
    if (!normalizedCity || normalizedCity.length > 30) throw new Error('请选择有效城市');
    if (!Number.isInteger(utcOffsetMinutes) || utcOffsetMinutes < -720 || utcOffsetMinutes > 840 || utcOffsetMinutes % 15 !== 0) {
      throw new Error('城市时区无效');
    }
    return this.command('添加世界时钟', '世界时钟', async (current: () => void): Promise<WatchWorldClock[]> => {
      const before = await this.sdk.worldClockService.list(); current();
      requireSuccess(before.success && before.data !== undefined, '世界时钟读取失败', before.errorMessage);
      const id = nextWatchItemId((before.data ?? []).map((item: WorldClockItem) => item.clockId));
      const saved = await this.sdk.worldClockService.add({ clockId: id, city: normalizedCity,
        timeZone: utcOffsetMinutes / 15 }); current();
      requireSuccess(saved.success, '世界时钟添加失败', saved.errorMessage);
      const readback = await this.sdk.worldClockService.list(); current();
      requireSuccess(readback.success && readback.data !== undefined, '世界时钟添加后读取失败', readback.errorMessage);
      if (!(readback.data ?? []).some((item: WorldClockItem) => item.clockId === id && item.city === normalizedCity)) {
        throw new Error('手表尚未确认世界时钟已添加');
      }
      return (readback.data ?? []).map((item: WorldClockItem): WatchWorldClock => ({
        id: item.clockId, city: item.city, utcOffsetMinutes: item.timeZone * 15
      })).sort((a: WatchWorldClock, b: WatchWorldClock) => a.id - b.id);
    });
  }

  async deleteWorldClock(expected: WatchWorldClock): Promise<WatchWorldClock[]> {
    return this.command('删除世界时钟', '世界时钟', async (current: () => void): Promise<WatchWorldClock[]> => {
      const before = await this.sdk.worldClockService.list(); current();
      requireSuccess(before.success && before.data !== undefined, '世界时钟读取失败', before.errorMessage);
      const item = (before.data ?? []).find((value: WorldClockItem) => value.clockId === expected.id);
      if (!item || item.city !== expected.city || item.timeZone * 15 !== expected.utcOffsetMinutes) {
        throw new Error('世界时钟已变化，请重新读取后再删除');
      }
      const removed = await this.sdk.worldClockService.delete(expected.id); current();
      requireSuccess(removed.success, '世界时钟删除失败', removed.errorMessage);
      const readback = await this.sdk.worldClockService.list(); current();
      requireSuccess(readback.success && readback.data !== undefined, '世界时钟删除后读取失败', readback.errorMessage);
      if ((readback.data ?? []).some((value: WorldClockItem) => value.clockId === expected.id)) {
        throw new Error('手表尚未确认世界时钟已删除');
      }
      return (readback.data ?? []).map((value: WorldClockItem): WatchWorldClock => ({
        id: value.clockId, city: value.city, utcOffsetMinutes: value.timeZone * 15
      })).sort((a: WatchWorldClock, b: WatchWorldClock) => a.id - b.id);
    });
  }

  async readReminders(): Promise<WatchReminder[]> {
    return this.command('读取健康提醒', '健康提醒', async (current: () => void): Promise<WatchReminder[]> => {
      const items: WatchReminder[] = [];
      const health = await this.sdk.reminderService.getAllHealthReminders(); current();
      if (health.success && health.data) {
        health.data.forEach((item: HealthReminderConfig) => items.push({ id: `health-${item.type}`, type: item.type,
          label: item.type === 1 ? '喝水提醒' : '健康提醒', startTime: item.startTime, endTime: item.endTime,
          intervalMinutes: item.intervalMinutes, enabled: item.enabled, sedentary: false }));
      }
      const sedentary = await this.sdk.reminderService.getSedentaryReminder(); current();
      if (sedentary.success && sedentary.data) {
        items.unshift({ id: 'sedentary', type: -1, label: '久坐提醒', startTime: sedentary.data.startTime,
          endTime: sedentary.data.endTime, intervalMinutes: sedentary.data.intervalMinutes,
          enabled: sedentary.data.enabled, sedentary: true });
      }
      if (!health.success && !sedentary.success) {
        throw new Error(health.errorMessage || sedentary.errorMessage || '健康提醒读取失败');
      }
      return items;
    });
  }

  async saveReminder(value: WatchReminder): Promise<WatchReminder[]> {
    return this.command('保存健康提醒', '健康提醒', async (current: () => void): Promise<WatchReminder[]> => {
      const start = normalizedTime(value.startTime, '08:00'), end = normalizedTime(value.endTime, '22:00');
      const interval = Math.max(15, Math.min(240, Math.round(value.intervalMinutes)));
      if (value.sedentary) {
        const config: SedentaryReminderConfig = { startTime: start, endTime: end,
          intervalMinutes: interval, enabled: value.enabled };
        const result = await this.sdk.reminderService.setSedentaryReminder(config); current();
        requireSuccess(result.success, '久坐提醒保存失败', result.errorMessage);
      } else {
        const config: HealthReminderConfig = { type: value.type, startTime: start, endTime: end,
          intervalMinutes: interval, enabled: value.enabled };
        const result = await this.sdk.reminderService.setHealthReminder(config); current();
        requireSuccess(result.success, '健康提醒保存失败', result.errorMessage);
      }
      return this.readRemindersInside(current);
    });
  }

  async readAutoMeasure(): Promise<WatchAutoMeasureSetting[]> {
    return this.command('读取健康监测', '健康监测', async (current: () => void): Promise<WatchAutoMeasureSetting[]> =>
      this.readAutoMeasureInside(current));
  }

  async saveAutoMeasure(value: WatchAutoMeasureSetting): Promise<WatchAutoMeasureSetting[]> {
    return this.command('保存健康监测', '健康监测', async (current: () => void): Promise<WatchAutoMeasureSetting[]> => {
      const currentItems = await this.readAutoMeasureConfigs(current);
      const config = currentItems.find((item: AutoMeasureConfig) => item.feature === value.feature);
      if (!config) throw new Error('此监测项目已变化，请重新读取');
      const interval = config.intervalModifiable ? Math.max(config.stepUnit, Math.round(value.intervalMinutes)) : config.measureInterval;
      const slot: MeasureTimeSlot = { startTime: normalizedTime(value.startTime, config.currentTimeSlot.startTime),
        stopTime: normalizedTime(value.endTime, config.currentTimeSlot.stopTime) };
      const result = await this.sdk.autoMeasureService.setConfig({ feature: config.feature, enabled: value.enabled,
        measureInterval: interval, currentTimeSlot: slot }); current();
      requireSuccess(result.success, '健康监测设置保存失败', result.errorMessage);
      const readback = await this.readAutoMeasureInside(current);
      const confirmed = readback.find((item: WatchAutoMeasureSetting) => item.feature === value.feature);
      if (!confirmed || confirmed.enabled !== value.enabled ||
        (config.intervalModifiable && confirmed.intervalMinutes !== interval)) {
        throw new Error('手表尚未确认健康监测设置');
      }
      return readback;
    });
  }

  async readAssessments(): Promise<WatchAssessmentSetting[]> {
    return this.command('读取辅助评估', '辅助评估', async (current: () => void): Promise<WatchAssessmentSetting[]> => {
      const result = await this.sdk.featureModuleService.getSwitches(); current();
      requireSuccess(result.success && result.data !== undefined, '辅助评估设置读取失败', result.errorMessage);
      return (result.data ?? []).map((item: FeatureModuleSwitch): WatchAssessmentSetting => ({
        dataType: item.dataType, label: assessmentLabel(item.dataType), enabled: item.enabled
      }));
    });
  }

  async saveAssessment(value: WatchAssessmentSetting): Promise<WatchAssessmentSetting[]> {
    return this.command('保存辅助评估', '辅助评估', async (current: () => void): Promise<WatchAssessmentSetting[]> => {
      const saved = await this.sdk.featureModuleService.setSwitch(value.dataType, value.enabled); current();
      requireSuccess(saved.success, '辅助评估设置保存失败', saved.errorMessage);
      const readback = await this.sdk.featureModuleService.getSwitches(); current();
      requireSuccess(readback.success && readback.data !== undefined, '辅助评估保存后读取失败', readback.errorMessage);
      const confirmed = (readback.data ?? []).find((item: FeatureModuleSwitch) => item.dataType === value.dataType);
      if (!confirmed || confirmed.enabled !== value.enabled) throw new Error('手表尚未确认辅助评估设置');
      return (readback.data ?? []).map((item: FeatureModuleSwitch): WatchAssessmentSetting => ({
        dataType: item.dataType, label: assessmentLabel(item.dataType), enabled: item.enabled
      }));
    });
  }

  async readScreen(): Promise<WatchScreenSetting> {
    return this.command('读取屏幕显示', '屏幕显示', async (current: () => void): Promise<WatchScreenSetting> => {
      const value = emptyScreenSetting();
      const brightness = await this.sdk.deviceControlService.getScreenBright(); current();
      if (brightness.success && brightness.data) {
        value.durationSupported = true; value.durationSeconds = brightness.data.duration;
      }
      const wrist = await this.sdk.deviceControlService.getRaiseToWake(); current();
      if (wrist.success && wrist.data) {
        value.raiseToWakeSupported = true; value.raiseToWakeEnabled = wrist.data.enabled;
        value.raiseToWakeStartTime = wrist.data.startTime; value.raiseToWakeEndTime = wrist.data.endTime;
        value.raiseToWakeLevel = wrist.data.level;
      }
      if (!value.durationSupported && !value.raiseToWakeSupported) {
        throw new Error(brightness.errorMessage || wrist.errorMessage || '屏幕显示设置读取失败');
      }
      return value;
    });
  }

  async saveScreen(value: WatchScreenSetting): Promise<WatchScreenSetting> {
    return this.command('保存屏幕显示', '屏幕显示', async (current: () => void): Promise<WatchScreenSetting> => {
      if (value.durationSupported) {
        const result = await this.sdk.deviceControlService.setScreenBright(Math.max(1, Math.min(120,
          Math.round(value.durationSeconds)))); current();
        requireSuccess(result.success, '亮屏时长保存失败', result.errorMessage);
      }
      if (value.raiseToWakeSupported) {
        const config: RaiseToWakeConfig = { enabled: value.raiseToWakeEnabled,
          startTime: normalizedTime(value.raiseToWakeStartTime, '00:00'),
          endTime: normalizedTime(value.raiseToWakeEndTime, '23:59'),
          level: Math.max(1, Math.min(10, Math.round(value.raiseToWakeLevel))) };
        const result = await this.sdk.deviceControlService.setRaiseToWake(config); current();
        requireSuccess(result.success, '抬腕亮屏设置保存失败', result.errorMessage);
      }
      return this.readScreenInside(current);
    });
  }

  setCameraListener(listener?: CameraRemoteListener): void {
    this.cameraListener = listener;
    if (this.cameraEventsAttached) return;
    this.sdk.on(SDKEventType.PHOTO_CONTROL, this.onPhotoControl);
    this.cameraEventsAttached = true;
  }

  async setCameraRemote(enabled: boolean): Promise<void> {
    return this.command(enabled ? '开启相机遥控' : '关闭相机遥控', '相机遥控',
      async (current: () => void): Promise<void> => {
        const result = await this.sdk.deviceControlService.controlPhoto(enabled); current();
        requireSuccess(result.success, enabled ? '相机遥控开启失败' : '相机遥控关闭失败', result.errorMessage);
      });
  }

  async readPhotoDialProfile(): Promise<WatchPhotoDialProfile> {
    return this.command('读取照片表盘规格', '照片表盘', async (current: () => void): Promise<WatchPhotoDialProfile> => {
      const profile = await this.sdk.dialService.readPhotoDial(); current();
      if (!profile.success) return { supported: false, width: 0, height: 0,
        message: profile.errorMessage || '手表未返回照片表盘规格' };
      const size = await this.sdk.dialService.getDialScreenSize(); current();
      if (!size || size.width <= 0 || size.height <= 0) return { supported: false, width: 0, height: 0,
        message: '手表未返回有效表盘尺寸' };
      return { supported: true, width: size.width, height: size.height,
        message: `手表表盘尺寸 ${size.width} × ${size.height}` };
    });
  }

  async installPhotoDial(uri: string, listener: PhotoDialProgressListener): Promise<void> {
    if (!uri.trim()) throw new Error('请先选择一张照片');
    return this.command('安装照片表盘', '照片表盘', async (current: () => void): Promise<void> => {
      const opened = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      let bytes: Uint8Array;
      try {
        const size = fileIo.statSync(opened.fd).size;
        if (!Number.isSafeInteger(size) || size <= 0) throw new Error('所选照片不可用');
        if (size > 12 * 1024 * 1024) throw new Error('照片过大，请选择 12 MB 以内的图片');
        bytes = new Uint8Array(size);
        let offset = 0;
        while (offset < size) {
          const count = fileIo.readSync(opened.fd, bytes.buffer, { offset: offset, length: size - offset });
          if (count <= 0) break;
          offset += count;
        }
        if (offset !== size) throw new Error('照片读取不完整，请重新选择');
      } finally { fileIo.closeSync(opened); }
      const result = await this.sdk.dialService.transferZKPhotoDial(bytes.buffer,
        (state: DialTransferState, progress: number, message?: string): void => {
          listener(Math.max(0, Math.min(100, Math.round(progress))), message ?? '');
        });
      current();
      requireSuccess(result.success, '照片表盘安装失败', result.errorMessage);
    });
  }

  private notificationSettings(config: MsgSwitchConfig): WatchNotificationSetting[] {
    const values: Array<[WatchNotificationKey, number]> = [
      ['call', config.call], ['sms', config.sms], ['wechat', config.wechat], ['qq', config.qq],
      ['whatsapp', config.whatsapp], ['dingTalk', config.dingTalk], ['wechatWork', config.wechatWork],
      ['tiktok', config.tiktok], ['telegram', config.telegram], ['other', config.other]
    ];
    return values.filter((item: [WatchNotificationKey, number]) => item[1] !== 0)
      .map((item: [WatchNotificationKey, number]): WatchNotificationSetting => ({
        key: item[0], label: notificationLabel(item[0]), enabled: item[1] === 1
      }));
  }

  private async readRemindersInside(current: () => void): Promise<WatchReminder[]> {
    const items: WatchReminder[] = [];
    const health = await this.sdk.reminderService.getAllHealthReminders(); current();
    if (health.success && health.data) health.data.forEach((item: HealthReminderConfig) => items.push({
      id: `health-${item.type}`, type: item.type, label: item.type === 1 ? '喝水提醒' : '健康提醒',
      startTime: item.startTime, endTime: item.endTime, intervalMinutes: item.intervalMinutes,
      enabled: item.enabled, sedentary: false
    }));
    const sedentary = await this.sdk.reminderService.getSedentaryReminder(); current();
    if (sedentary.success && sedentary.data) items.unshift({ id: 'sedentary', type: -1, label: '久坐提醒',
      startTime: sedentary.data.startTime, endTime: sedentary.data.endTime,
      intervalMinutes: sedentary.data.intervalMinutes, enabled: sedentary.data.enabled, sedentary: true });
    if (!health.success && !sedentary.success) throw new Error(health.errorMessage || sedentary.errorMessage || '健康提醒读取失败');
    return items;
  }

  private async readAutoMeasureConfigs(current: () => void): Promise<AutoMeasureConfig[]> {
    const result = await this.sdk.autoMeasureService.readConfig(); current();
    requireSuccess(result.success && result.data !== undefined, '健康监测设置读取失败', result.errorMessage);
    return result.data ?? [];
  }

  private async readAutoMeasureInside(current: () => void): Promise<WatchAutoMeasureSetting[]> {
    const result = await this.readAutoMeasureConfigs(current);
    return result.map((item: AutoMeasureConfig): WatchAutoMeasureSetting => ({
      feature: item.feature, label: autoMeasureLabel(item.feature), enabled: item.enabled,
      intervalMinutes: item.measureInterval, minimumIntervalMinutes: Math.max(1, item.stepUnit),
      intervalModifiable: item.intervalModifiable, timeSlotModifiable: item.timeSlotModifiable,
      startTime: item.currentTimeSlot.startTime, endTime: item.currentTimeSlot.stopTime
    }));
  }

  private async readScreenInside(current: () => void): Promise<WatchScreenSetting> {
    const value = emptyScreenSetting();
    const brightness = await this.sdk.deviceControlService.getScreenBright(); current();
    if (brightness.success && brightness.data) {
      value.durationSupported = true; value.durationSeconds = brightness.data.duration;
    }
    const wrist = await this.sdk.deviceControlService.getRaiseToWake(); current();
    if (wrist.success && wrist.data) {
      value.raiseToWakeSupported = true; value.raiseToWakeEnabled = wrist.data.enabled;
      value.raiseToWakeStartTime = wrist.data.startTime; value.raiseToWakeEndTime = wrist.data.endTime;
      value.raiseToWakeLevel = wrist.data.level;
    }
    if (!value.durationSupported && !value.raiseToWakeSupported) throw new Error('屏幕显示设置读取失败');
    return value;
  }

  private onPhotoControl = (payload: ESObject): void => {
    const data = payload as PhotoControlPush;
    const capture = data.success === true && data.take === PhotoTakeState.CAPTURE;
    const message = capture ? '已收到手表拍照指令' : data.take === PhotoTakeState.ENTER ? '手表已进入相机遥控' :
      data.take === PhotoTakeState.STOP_EXIT ? '手表已退出相机遥控' : '相机遥控状态已更新';
    this.cameraListener?.(capture, message);
  };
}

export const vepDeviceFeatures: VepDeviceFeatureAdapter = new VepDeviceFeatureAdapter();
