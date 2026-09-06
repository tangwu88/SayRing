import type { CareInvitation } from './CareContracts';
import type { InboxMessage } from './AccountPageContracts';
import type { HealthOwnerSession } from './HealthUpload';

export interface LocalCareNotice { id: number; receivedAt: number; read: boolean; pending: boolean; }
export interface CareNoticeState { version: number; seen: number[]; entries: LocalCareNotice[]; }
export interface CareNoticeStore {
  read(ownerId: string): Promise<CareNoticeState>;
  save(ownerId: string, state: CareNoticeState, assertCurrent: () => void): Promise<void>;
}
export interface CarePollPort {
  readInvitations(): Promise<CareInvitation[]>;
  store: CareNoticeStore;
  now(): number;
  schedule(action: () => void, delayMs: number): number;
  cancel(timer: number): void;
  changed(): void;
  arrived(count: number): void;
  notify(ownerId: string, notice: LocalCareNotice, assertCurrent: () => void): Promise<void>;
  failed(): void;
}

export function emptyCareNoticeState(): CareNoticeState { return { version: 1, seen: [], entries: [] }; }

// Persist only event IDs, read state and receipt time; never inviter identity or health values.
export function parseCareNoticeState(raw: string): CareNoticeState {
  if (!raw) return emptyCareNoticeState();
  const value = JSON.parse(raw) as CareNoticeState;
  if (!value || value.version !== 1 || !Array.isArray(value.seen) || !Array.isArray(value.entries)) {
    throw new Error('邀请消息暂时无法读取');
  }
  const seen: number[] = [];
  value.seen.forEach((id: number) => {
    if (!Number.isSafeInteger(id) || id <= 0) throw new Error('邀请消息暂时无法读取');
    if (!seen.includes(id)) seen.push(id);
  });
  const entries: LocalCareNotice[] = [];
  value.entries.forEach((item: LocalCareNotice) => {
    if (!item || !seen.includes(item.id) || !Number.isSafeInteger(item.receivedAt) || item.receivedAt <= 0 ||
      typeof item.read !== 'boolean' || typeof item.pending !== 'boolean' || entries.some((entry) => entry.id === item.id)) {
      throw new Error('邀请消息暂时无法读取');
    }
    entries.push({ id: item.id, receivedAt: item.receivedAt, read: item.read, pending: item.pending });
  });
  return { version: 1, seen: seen, entries: entries.slice(-200) };
}

export function localCareInbox(state: CareNoticeState): InboxMessage[] {
  return state.entries.slice().reverse().map((item: LocalCareNotice): InboxMessage => ({
    id: -item.id, entityId: String(item.id), source: 'local', kind: 'care_invitation',
    title: item.pending ? '新的关爱邀请' : '关爱邀请已更新',
    content: item.pending ? '点击查看邀请并选择是否接受' : '点击查看邀请的最新状态',
    createdAt: new Date(item.receivedAt + 8 * 3600000).toISOString().slice(0, 16).replace('T', ' '), read: item.read
  }));
}

export function mergeCareInbox(server: InboxMessage[], local: InboxMessage[]): InboxMessage[] {
  const serverEntities = new Set(server.filter((row) => row.kind === 'care_invitation' && row.entityId)
    .map((row) => row.entityId ?? ''));
  return [...local.filter((row) => !serverEntities.has(row.entityId ?? '')), ...server];
}

export function careInboxUnread(serverCount: number | undefined, server: InboxMessage[], local: InboxMessage[]): number {
  const knownServer = server.filter((row) => !row.read).length;
  const localOnly = mergeCareInbox(server, local).filter((row) => row.source === 'local' && !row.read).length;
  return Math.max(serverCount ?? 0, knownServer) + localOnly;
}

export class ForegroundCareNotifications {
  private port: CarePollPort;
  private session: HealthOwnerSession = { ownerId: '', generation: 0 };
  private foreground: boolean = false;
  private epoch: number = 0;
  private timer: number = -1;
  private running: number = -1;
  private again: boolean = false;
  private failures: number = 0;
  private state: CareNoticeState | undefined = undefined;
  private mutations: Promise<void> = Promise.resolve();
  private remoteEntities: Set<number> = new Set();

  constructor(port: CarePollPort) { this.port = port; }

  setSession(session: HealthOwnerSession): void {
    if (session.ownerId === this.session.ownerId && session.generation === this.session.generation) return;
    this.stopTimer(); ++this.epoch;
    this.session = { ownerId: session.ownerId, generation: session.generation };
    this.state = undefined; this.failures = 0; this.again = false; this.remoteEntities.clear();
    this.port.changed();
    this.refresh();
  }

  setForeground(value: boolean): void {
    if (this.foreground === value) return;
    this.foreground = value; this.stopTimer(); ++this.epoch; this.failures = 0; this.again = false;
    if (value) this.refresh();
  }

  currentInbox(): InboxMessage[] { return localCareInbox(this.state ?? emptyCareNoticeState()); }

  remoteArrived(entityId: string): void {
    if (!this.session.ownerId || !/^[1-9]\d*$/.test(entityId)) return;
    const id = Number(entityId);
    if (!Number.isSafeInteger(id)) return;
    // A remote arrival is only a refresh hint, not an invitation or its authority.
    this.remoteEntities.add(id);
    this.refresh();
  }

  async markRead(entityId: number): Promise<void> {
    const epoch = this.epoch;
    const operation = this.mutations.catch(() => {}).then(async () => {
      this.assertCurrent(epoch);
      await this.load(epoch);
      const state = parseCareNoticeState(JSON.stringify(this.state));
      const item = state.entries.find((entry) => entry.id === entityId);
      if (!item || item.read) return;
      item.read = true;
      await this.port.store.save(this.session.ownerId, state, () => this.assertCurrent(epoch));
      this.assertCurrent(epoch); this.state = state; this.port.changed();
    });
    this.mutations = operation;
    await operation;
  }

  refresh(): void {
    if (!this.foreground || !this.session.ownerId) return;
    this.stopTimer();
    if (this.running === this.epoch) { this.again = true; return; }
    this.poll(this.epoch);
  }

  private stopTimer(): void { if (this.timer >= 0) this.port.cancel(this.timer); this.timer = -1; }
  private assertCurrent(epoch: number): void {
    if (epoch !== this.epoch || !this.foreground || !this.session.ownerId) throw new Error('已停止旧账号邀请检查');
  }
  private async load(epoch: number): Promise<void> {
    if (this.state) return;
    const state = await this.port.store.read(this.session.ownerId);
    this.assertCurrent(epoch); this.state = state; this.port.changed();
  }

  private async poll(epoch: number): Promise<void> {
    this.running = epoch;
    try {
      const loading = this.mutations.catch(() => {}).then(() => this.load(epoch));
      this.mutations = loading;
      await loading;
      this.assertCurrent(epoch);
      const invitations = await this.port.readInvitations();
      this.assertCurrent(epoch);
      const operation = this.mutations.catch(() => {}).then(() => this.reconcile(epoch, invitations));
      this.mutations = operation;
      await operation;
      this.assertCurrent(epoch); this.failures = 0; this.port.changed();
    } catch {
      if (epoch === this.epoch && this.foreground && this.session.ownerId) {
        ++this.failures; this.port.failed();
      }
    } finally {
      if (this.running === epoch) this.running = -1;
      if (epoch === this.epoch && this.foreground && this.session.ownerId) {
        const delay = this.failures ? [30000, 60000, 120000, 300000][Math.min(3, this.failures - 1)] : this.again ? 0 : 30000;
        this.again = false;
        this.timer = this.port.schedule(() => { this.timer = -1; this.refresh(); }, delay);
      }
    }
  }

  private async reconcile(epoch: number, invitations: CareInvitation[]): Promise<void> {
    this.assertCurrent(epoch); await this.load(epoch); this.assertCurrent(epoch);
    const state = parseCareNoticeState(JSON.stringify(this.state));
    const pending = new Set(invitations.filter((item) => item.state === 'pending').map((item) => item.id));
    const handled = new Set(invitations.filter((item) => item.state === 'accepted' || item.state === 'rejected').map((item) => item.id));
    // This endpoint does not guarantee a full unpaginated snapshot. Absence is not revocation or a read receipt.
    state.entries.forEach((item) => {
      if (handled.has(item.id)) { item.pending = false; item.read = true; }
      else if (pending.has(item.id)) item.pending = true;
    });
    const added: LocalCareNotice[] = [];
    pending.forEach((id: number) => {
      if (state.seen.includes(id)) return;
      const notice: LocalCareNotice = { id: id, receivedAt: this.port.now(), read: false, pending: true };
      state.seen.push(id); state.entries.push(notice);
      if (!this.remoteEntities.has(id)) added.push(notice);
    });
    state.entries = state.entries.slice(-200);
    if (JSON.stringify(state) !== JSON.stringify(this.state)) {
      await this.port.store.save(this.session.ownerId, state, () => this.assertCurrent(epoch));
      this.assertCurrent(epoch); this.state = state; this.port.changed();
    }
    // Permission failure never discards the saved inbox. Persisted IDs stop later retries duplicating alerts.
    if (added.length > 0) {
      this.assertCurrent(epoch); this.port.arrived(added.length);
      for (const notice of added) {
        this.assertCurrent(epoch);
        if (this.remoteEntities.has(notice.id)) continue;
        try { await this.port.notify(this.session.ownerId, notice, () => this.assertCurrent(epoch)); } catch {}
      }
    }
  }
}
