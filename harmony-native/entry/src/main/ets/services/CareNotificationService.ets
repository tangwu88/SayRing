import { common, wantAgent } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { notificationManager } from '@kit.NotificationKit';
import { ForegroundCareNotifications, parseCareNoticeState } from '../model/ForegroundCareNotifications';
import type { CareNoticeState, CareNoticeStore, CarePollPort, LocalCareNotice } from '../model/ForegroundCareNotifications';
import type { InboxMessage } from '../model/AccountPageContracts';
import type { HealthOwnerSession } from '../model/HealthUpload';
import type { NotificationPayload } from '../model/NotificationPayload';
import { saydianApi } from './SaydianApi';
import { CARE_ARRIVAL_REVISION, notificationInboxChanged, observeNotificationArrival, setNotificationOwner } from './NotificationNavigation';

class LocalCareNoticeStore implements CareNoticeStore {
  private context: common.UIAbilityContext;
  private queue: Promise<void> = Promise.resolve();
  constructor(context: common.UIAbilityContext) { this.context = context; }
  async read(ownerId: string): Promise<CareNoticeState> {
    await this.queue.catch(() => {});
    const store = await preferences.getPreferences(this.context, { name: 'saydian_care_notices' });
    return parseCareNoticeState(await store.get(`owner_${ownerId}`, '') as string);
  }
  async save(ownerId: string, state: CareNoticeState, assertCurrent: () => void): Promise<void> {
    const serialized = JSON.stringify(state);
    const operation = this.queue.catch(() => {}).then(async () => {
      assertCurrent();
      const store = await preferences.getPreferences(this.context, { name: 'saydian_care_notices' });
      assertCurrent(); await store.put(`owner_${ownerId}`, serialized); await store.flush();
      assertCurrent();
    });
    this.queue = operation; await operation;
  }
}

export class CareNotificationService {
  private context: common.UIAbilityContext | undefined = undefined;
  private coordinator: ForegroundCareNotifications | undefined = undefined;
  private stopObserving: (() => void) | undefined = undefined;
  private session: HealthOwnerSession = { ownerId: '', generation: 0 };
  private shown: Map<string, number> = new Map();
  private pendingRemoteIds: Set<string> = new Set();
  private foreground: boolean = false;
  private signOutGeneration: number = -1;
  private localFailure: string = '';

  attachContext(context: common.UIAbilityContext): void {
    this.context = context;
    if (this.coordinator) return;
    const port: CarePollPort = {
      readInvitations: () => saydianApi.careInvitations(), store: new LocalCareNoticeStore(context),
      now: () => Date.now(), schedule: (action, delayMs) => setTimeout(action, delayMs), cancel: (timer) => clearTimeout(timer),
      changed: () => { this.localFailure = ''; notificationInboxChanged(); },
      arrived: () => AppStorage.setOrCreate<number>(CARE_ARRIVAL_REVISION,
        (AppStorage.get<number>(CARE_ARRIVAL_REVISION) ?? 0) + 1),
      notify: (owner, notice, assertCurrent) => this.publish(owner, notice, assertCurrent),
      failed: () => { this.localFailure = '邀请暂未更新，将自动重试'; notificationInboxChanged(); }
    };
    this.coordinator = new ForegroundCareNotifications(port);
    this.coordinator.setForeground(this.foreground);
    this.stopObserving = saydianApi.observeSession((session: HealthOwnerSession) => this.sessionChanged(session));
    observeNotificationArrival((payload: NotificationPayload) => {
      if (payload.eventType !== 'care_invitation') return;
      if (this.signOutGeneration >= 0) return;
      if (!this.session.ownerId) {
        if (this.pendingRemoteIds.size < 200) this.pendingRemoteIds.add(payload.entityId);
        return;
      }
      this.coordinator?.remoteArrived(payload.entityId);
      this.cancelNotice(this.session.ownerId, Number(payload.entityId));
    });
  }

  private sessionChanged(session: HealthOwnerSession): void {
    if (session.ownerId !== this.session.ownerId || session.generation !== this.session.generation) {
      this.cancelOwnedNotices();
      if (this.session.ownerId) this.pendingRemoteIds.clear();
    }
    this.session = { ownerId: session.ownerId, generation: session.generation };
    setNotificationOwner(session.ownerId);
    this.coordinator?.setSession(session);
    if (session.generation !== this.signOutGeneration || !session.ownerId) this.signOutGeneration = -1;
    this.coordinator?.setForeground(this.foreground && this.signOutGeneration < 0);
    if (session.ownerId) {
      this.pendingRemoteIds.forEach((id: string) => this.coordinator?.remoteArrived(id));
      this.pendingRemoteIds.clear();
    }
  }

  beginSignOut(): void {
    this.signOutGeneration = this.session.generation;
    this.coordinator?.setForeground(false);
    this.cancelOwnedNotices();
  }

  private cancelOwnedNotices(): void {
    const ownerId = this.session.ownerId;
    this.coordinator?.currentInbox().forEach((item: InboxMessage) => this.cancelNotice(ownerId, -item.id));
    this.shown.forEach((id: number, label: string) => {
      if (label.startsWith(`saydian.care.${ownerId}.`)) notificationManager.cancel(id, label).catch(() => {});
    });
    this.shown.clear();
  }

  setForeground(value: boolean): void {
    this.foreground = value; this.coordinator?.setForeground(value && this.signOutGeneration < 0);
  }
  isForeground(): boolean { return this.foreground && this.signOutGeneration < 0; }
  refresh(): void { this.coordinator?.refresh(); }
  currentInbox(): InboxMessage[] { return this.coordinator?.currentInbox() ?? []; }
  failureMessage(): string { return this.localFailure; }
  async markRead(entityId: number): Promise<void> {
    const coordinator = this.coordinator;
    if (!coordinator) throw new Error('消息暂时无法更新');
    await coordinator.markRead(entityId);
    await this.cancelNotice(this.session.ownerId, entityId);
  }

  private async cancelNotice(ownerId: string, entityId: number): Promise<void> {
    if (!ownerId || !Number.isSafeInteger(entityId) || entityId <= 0) return;
    const label = `saydian.care.${ownerId}.${entityId}`;
    try { await notificationManager.cancel(this.notificationId(entityId), label); } catch {}
    this.shown.delete(label);
  }

  private notificationId(id: number): number { return 1000000000 + id % 1000000000; }

  private async publish(ownerId: string, notice: LocalCareNotice, assertCurrent: () => void): Promise<void> {
    const context = this.context;
    if (!context) return;
    assertCurrent();
    const enabled = await notificationManager.isNotificationEnabled();
    assertCurrent(); if (!enabled) return;
    const label = `saydian.care.${ownerId}.${notice.id}`;
    const id = this.notificationId(notice.id);
    const agent = await wantAgent.getWantAgent({
      wants: [{ bundleName: context.abilityInfo.bundleName, abilityName: context.abilityInfo.name,
        parameters: { schema_version: 1, event_id: label, event_type: 'care_invitation', entity_id: String(notice.id),
          route: 'care-invitations', local_notice_owner: ownerId } }],
      operationType: wantAgent.OperationType.START_ABILITY, requestCode: id,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    });
    assertCurrent();
    // appMessageId is the SDK's API 12+ cross-channel dedupe key; the server must use the same key.
    await notificationManager.publish({ id: id, label: label, appMessageId: label,
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION, isAlertOnce: true,
      content: { notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: '新的关爱邀请', text: '请打开赛电查看并选择是否接受' } }, wantAgent: agent });
    try { assertCurrent(); this.shown.set(label, id); }
    catch { await notificationManager.cancel(id, label).catch(() => {}); }
  }

  shutdown(): void {
    this.setForeground(false); this.stopObserving?.(); this.stopObserving = undefined;
    this.coordinator = undefined;
  }
}

export const careNotifications: CareNotificationService = new CareNotificationService();
