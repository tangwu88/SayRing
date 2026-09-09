import type { WearableCapabilities } from './WearableContracts';

export type WatchDeviceFeatureKey = 'photoDial' | 'camera' | 'phoneCalls' | 'contacts' |
  'notifications' | 'weather' | 'worldClock' | 'healthReminders' | 'healthMonitoring' |
  'healthAssessment' | 'screenDisplay';

export interface WatchDeviceFeatureSpec {
  key: WatchDeviceFeatureKey;
  title: string;
  subtitle: string;
}

export interface WatchPhoneState {
  enabled: boolean;
  connected: boolean;
  autoReconnect: boolean;
  multimediaEnabled: boolean;
  paired: boolean;
}

export interface WatchContact {
  id: number;
  name: string;
  phone: string;
  sos: boolean;
}

export type WatchNotificationKey = 'call' | 'sms' | 'wechat' | 'qq' | 'whatsapp' |
  'dingTalk' | 'wechatWork' | 'tiktok' | 'telegram' | 'other';

export interface WatchNotificationSetting {
  key: WatchNotificationKey;
  label: string;
  enabled: boolean;
}

export interface WatchWeatherSetting {
  enabled: boolean;
  celsius: boolean;
}

export interface WatchWorldClock {
  id: number;
  city: string;
  utcOffsetMinutes: number;
}

export interface WatchReminder {
  id: string;
  type: number;
  label: string;
  startTime: string;
  endTime: string;
  intervalMinutes: number;
  enabled: boolean;
  sedentary: boolean;
}

export interface WatchAutoMeasureSetting {
  feature: number;
  label: string;
  enabled: boolean;
  intervalMinutes: number;
  minimumIntervalMinutes: number;
  intervalModifiable: boolean;
  timeSlotModifiable: boolean;
  startTime: string;
  endTime: string;
}

export interface WatchAssessmentSetting {
  dataType: number;
  label: string;
  enabled: boolean;
}

export interface WatchScreenSetting {
  durationSupported: boolean;
  durationSeconds: number;
  raiseToWakeSupported: boolean;
  raiseToWakeEnabled: boolean;
  raiseToWakeStartTime: string;
  raiseToWakeEndTime: string;
  raiseToWakeLevel: number;
}

export interface WatchPhotoDialProfile {
  supported: boolean;
  width: number;
  height: number;
  message: string;
}

export const WATCH_DEVICE_FEATURES: WatchDeviceFeatureSpec[] = [
  { key: 'photoDial', title: '照片表盘', subtitle: '用自己的照片制作表盘' },
  { key: 'camera', title: '相机遥控', subtitle: '使用手表控制手机拍照' },
  { key: 'phoneCalls', title: '电话', subtitle: '管理手表蓝牙通话连接' },
  { key: 'contacts', title: '联系人', subtitle: '管理联系人和 SOS 紧急联系人' },
  { key: 'notifications', title: '消息通知', subtitle: '选择需要在手表提醒的消息' },
  { key: 'weather', title: '天气', subtitle: '设置手表天气显示与温度单位' },
  { key: 'worldClock', title: '世界时钟', subtitle: '管理手表中的其他城市时间' },
  { key: 'healthReminders', title: '健康提醒', subtitle: '设置久坐、饮水和日常提醒' },
  { key: 'healthMonitoring', title: '健康监测', subtitle: '设置自动检测和监测间隔' },
  { key: 'healthAssessment', title: '辅助评估', subtitle: '设置手表支持的辅助评估' },
  { key: 'screenDisplay', title: '屏幕显示', subtitle: '设置亮屏时长和抬腕亮屏' }
];

export function watchDeviceFeatureSupported(capabilities: WearableCapabilities,
  feature: WatchDeviceFeatureKey): boolean {
  if (feature === 'photoDial') return capabilities.photoDial;
  if (feature === 'camera') return capabilities.camera;
  if (feature === 'phoneCalls') return capabilities.phoneCalls;
  if (feature === 'contacts') return capabilities.contacts;
  if (feature === 'notifications') return capabilities.notification;
  if (feature === 'weather') return capabilities.weather;
  if (feature === 'worldClock') return capabilities.worldClock;
  if (feature === 'healthReminders') return capabilities.healthReminder;
  if (feature === 'healthMonitoring') return capabilities.healthMonitoring;
  if (feature === 'healthAssessment') return capabilities.healthAssessment;
  return capabilities.screenDisplay;
}

export function visibleWatchDeviceFeatures(capabilities: WearableCapabilities): WatchDeviceFeatureSpec[] {
  return WATCH_DEVICE_FEATURES.filter((item: WatchDeviceFeatureSpec) =>
    watchDeviceFeatureSupported(capabilities, item.key));
}

export function watchContactError(contact: WatchContact): string {
  const name = contact.name.replace(/\s+/g, ' ').trim();
  const phone = contact.phone.replace(/[\s-]/g, '').trim();
  if (!name) return '请输入联系人姓名';
  if (name.length > 20 || /[\x00-\x1f\x7f]/.test(name)) return '联系人姓名格式不正确';
  if (!/^\+?[0-9]{6,20}$/.test(phone)) return '请输入正确的联系电话';
  return '';
}

export function nextWatchItemId(ids: number[], maximum: number = 10): number {
  for (let candidate = 1; candidate <= maximum; ++candidate) {
    if (!ids.includes(candidate)) return candidate;
  }
  throw new Error('数量已达手表上限');
}

export function normalizedTime(value: string, fallback: string): string {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return fallback;
  const hour = Number(match[1]), minute = Number(match[2]);
  if (!Number.isInteger(hour) || !Number.isInteger(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return fallback;
  }
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

export function autoMeasureLabel(feature: number): string {
  if (feature === 0) return '心率自动检测';
  if (feature === 1) return '血压自动检测';
  if (feature === 2) return '血糖自动检测';
  if (feature === 3) return '压力自动检测';
  if (feature === 4) return '血氧自动检测';
  if (feature === 5) return '体温自动检测';
  if (feature === 6) return '洛伦兹散点自动检测';
  if (feature === 7) return 'HRV 自动检测';
  if (feature === 8) return '血液成分自动检测';
  return '健康自动检测';
}

export function assessmentLabel(dataType: number): string {
  const labels: string[] = ['血糖趋势评估', '血压趋势评估', '血氧趋势评估', '体温趋势评估',
    'HRV 评估', '压力评估', '活动强度评估', '血液成分评估', '身体成分评估',
    '综合健康评估', '情绪评估', '疲劳评估', '跌倒提醒', '皮肤状态评估'];
  return labels[dataType] ?? `辅助评估 ${dataType}`;
}

export function notificationLabel(key: WatchNotificationKey): string {
  if (key === 'call') return '来电提醒';
  if (key === 'sms') return '短信提醒';
  if (key === 'wechat') return '微信';
  if (key === 'qq') return 'QQ';
  if (key === 'whatsapp') return 'WhatsApp';
  if (key === 'dingTalk') return '钉钉';
  if (key === 'wechatWork') return '企业微信';
  if (key === 'tiktok') return '抖音';
  if (key === 'telegram') return 'Telegram';
  return '其他应用';
}

export function emptyPhoneState(): WatchPhoneState {
  return { enabled: false, connected: false, autoReconnect: false, multimediaEnabled: false, paired: false };
}

export function emptyScreenSetting(): WatchScreenSetting {
  return { durationSupported: false, durationSeconds: 0, raiseToWakeSupported: false,
    raiseToWakeEnabled: false, raiseToWakeStartTime: '00:00', raiseToWakeEndTime: '23:59', raiseToWakeLevel: 5 };
}

export function emptyPhotoDialProfile(): WatchPhotoDialProfile {
  return { supported: false, width: 0, height: 0, message: '' };
}
