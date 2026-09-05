import type { Want } from '@kit.AbilityKit';
import { notificationRoute } from '../model/PushPaymentContracts';

export const PENDING_NOTIFICATION_ROUTE: string = 'saydian.pending.notification.route';

export function initializeNotificationNavigation(): void {
  AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_ROUTE, '');
}

export function captureNotificationRoute(want: Want): void {
  const route = notificationRoute(want.parameters as Object);
  if (route) AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_ROUTE, route);
}
