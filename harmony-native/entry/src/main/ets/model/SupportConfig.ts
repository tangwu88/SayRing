import { ApiError } from './Contracts';

export interface SupportConfig {
  configured: boolean;
  phone: string;
  officialAccount: string;
  serviceHours: string;
  message: string;
}

export function emptySupportConfig(): SupportConfig {
  return { configured: false, phone: '', officialAccount: '', serviceHours: '', message: '' };
}

function boundedText(value: Object | undefined, maximum: number): string {
  if (typeof value !== 'string') return '';
  const text = value.trim();
  return text.length <= maximum ? text : '';
}

export function parseSupportConfig(data: Object | undefined): SupportConfig {
  const value = data as Record<string, Object>;
  if (!value || typeof value['configured'] !== 'boolean') {
    throw new ApiError('客服信息暂时无法读取，请稍后重试', 503);
  }
  const message = boundedText(value['message'], 300);
  if (value['configured'] !== true) {
    return { ...emptySupportConfig(), message };
  }
  const phone = boundedText(value['phone'], 32);
  const officialAccount = boundedText(value['officialAccount'] ?? value['wechatOfficialAccount'], 100);
  const serviceHours = boundedText(value['serviceHours'], 200);
  const validPhone = !phone || /^[+0-9][0-9()\-\s]{4,31}$/.test(phone);
  if (!validPhone || (!phone && !officialAccount)) {
    throw new ApiError('客服信息配置不完整，请稍后重试', 503);
  }
  return { configured: true, phone, officialAccount, serviceHours, message };
}
