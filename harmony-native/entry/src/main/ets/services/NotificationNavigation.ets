import type { Want } from '@kit.AbilityKit';
import { normalizeNotificationPayload } from '../model/NotificationPayload';
import type { NotificationPayload } from '../model/NotificationPayload';

export const PENDING_NOTIFICATION_ROUTE: string = 'saydian.pending.notification.route';
export const NOTIFICATION_REVISION: string = 'saydian.notification.revision';
export const CARE_ARRIVAL_REVISION: string = 'saydian.care.arrival.revision';
const NOTIFICATION_OWNER: string = 'saydian.notification.owner';
const PENDING_NOTIFICATION_OWNER: string = 'saydian.pending.notification.owner';
const delivered: Map<string, string> = new Map();
const clicked: Set<string> = new Set();
let arrivalListener: ((payload: NotificationPayload, opened: boolean) => void) | undefined = undefined;

export function observeNotificationArrival(listener: (payload: NotificationPayload, opened: boolean) => void): void {
  arrivalListener = listener;
}

export function notificationInboxChanged(): void {
  initializeNotificationNavigation();
  AppStorage.setOrCreate<number>(NOTIFICATION_REVISION, (AppStorage.get<number>(NOTIFICATION_REVISION) ?? 0) + 1);
}

export function setNotificationOwner(ownerId: string): void {
  const previous = AppStorage.get<string>(NOTIFICATION_OWNER) ?? '';
  if (previous && previous !== ownerId) clearNotificationSession();
  AppStorage.setOrCreate<string>(NOTIFICATION_OWNER, ownerId);
  const pendingOwner = AppStorage.get<string>(PENDING_NOTIFICATION_OWNER) ?? '';
  if (ownerId && pendingOwner && ownerId !== pendingOwner) {
    AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_ROUTE, '');
    AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_OWNER, '');
  }
}

export function notificationMatchesOwner(ownerId: string): boolean {
  const pendingOwner = AppStorage.get<string>(PENDING_NOTIFICATION_OWNER) ?? '';
  return !pendingOwner || pendingOwner === ownerId;
}

export function initializeNotificationNavigation(): void {
  if (!AppStorage.has(PENDING_NOTIFICATION_ROUTE)) AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_ROUTE, '');
  if (!AppStorage.has(NOTIFICATION_REVISION)) AppStorage.setOrCreate<number>(NOTIFICATION_REVISION, 0);
  if (!AppStorage.has(CARE_ARRIVAL_REVISION)) AppStorage.setOrCreate<number>(CARE_ARRIVAL_REVISION, 0);
}

export function captureNotificationRoute(want: Want): void {
  captureNotificationEvent(want.parameters as Object, true);
}

// Store only a bounded event fingerprint. The signed-in API supplies the inbox,
// invitation state and health values; a push is never an authority for those.
export function captureNotificationEvent(value: Object | undefined, opened: boolean): void {
  const payload = normalizeNotificationPayload(value);
  if (!payload || (!opened && !payload.eventId)) return;
  const row: Record<string, Object> = value && typeof value === 'object' ? value as Record<string, Object> : {};
  const localOwner = typeof row['local_notice_owner'] === 'string' ? row['local_notice_owner'] as string : '';
  const currentOwner = AppStorage.get<string>(NOTIFICATION_OWNER) ?? '';
  if (localOwner && currentOwner && localOwner !== currentOwner) return;
  initializeNotificationNavigation();
  if (payload.eventId) {
    const fingerprint = `${payload.eventType}:${payload.entityId}`;
    const prior = delivered.get(payload.eventId);
    if (prior !== undefined && prior !== fingerprint) return;
    if (prior === undefined) {
      delivered.set(payload.eventId, fingerprint);
      if (delivered.size > 200) {
        const oldest = Array.from(delivered.keys())[0];
        delivered.delete(oldest); clicked.delete(oldest);
      }
      if (!localOwner) arrivalListener?.(payload, opened);
      notificationInboxChanged();
    }
    if (opened) {
      if (clicked.has(payload.eventId)) return;
      clicked.add(payload.eventId);
    }
  }
  if (opened) {
    AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_OWNER, localOwner);
    AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_ROUTE, payload.route);
  }
}

export function clearNotificationSession(): void {
  delivered.clear(); clicked.clear();
  AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_ROUTE, '');
  AppStorage.setOrCreate<string>(PENDING_NOTIFICATION_OWNER, '');
}
