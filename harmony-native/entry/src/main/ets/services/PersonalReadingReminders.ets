import { common } from '@kit.AbilityKit';
import { ReadingSettings, ReadingNotice, defaultReadingSettings, readingSettingsError, evaluatePersonalReading, supportedReadingRules, readingRuleEnabled } from '../model/ReadingReminders';
import { WearableSnapshot, MeasurementState, WearableMetricKey, emptyWearableSnapshot, emptyMeasurement } from '../model/WearableContracts';
import { readingReminderStore } from './ReadingReminderStore';
import { readingReminderSound } from './ReadingReminderSound';

interface PendingReading { token: number; owner: string; device: string; firmware: string; metric: WearableMetricKey; started: number; confirmed: boolean; }
export class PersonalReadingReminders {
  private owner: string = '';
  private context: common.UIAbilityContext | undefined = undefined;
  private snapshot: WearableSnapshot = emptyWearableSnapshot();
  private completed: MeasurementState = emptyMeasurement();
  private pending: PendingReading | undefined = undefined;
  private revision: number = 0;
  private ready: boolean = false;
  private loading: boolean = false;
  private foreground: boolean = true;
  private seen: Set<string> = new Set();
  private notice: ((value: ReadingNotice | undefined) => void) | undefined = undefined;
  private settingsListener: ((value: ReadingSettings) => void) | undefined = undefined;
  private activeNotice: ReadingNotice | undefined = undefined;
  private noticeOwner: string = '';
  private sequence: number = 0;
  private played: number = -1;
  private feedbackRevision: number = 0;
  settings: ReadingSettings = defaultReadingSettings();
  listen(listener: ((value: ReadingNotice | undefined) => void) | undefined): void { this.notice = listener; }
  listenSettings(listener: ((value: ReadingSettings) => void) | undefined): void { this.settingsListener = listener; }
  configure(owner: string, context: common.UIAbilityContext, snapshot: WearableSnapshot): void {
    this.context = context; readingReminderStore.attach(context);
    if (owner !== this.owner || (!this.ready && !this.loading)) {
      const revision = ++this.revision; this.owner = owner; this.ready = false; this.loading = true; this.settings = defaultReadingSettings();
      this.settingsListener?.(this.settings);
      this.seen.clear(); this.cancel();
      readingReminderStore.read(owner).then((settings: ReadingSettings) => {
        if (revision !== this.revision || owner !== this.owner) return;
        this.settings = settings; this.ready = true; this.loading = false; this.settingsListener?.(this.settings);
      }).catch(() => { if (revision === this.revision) this.loading = false; });
    }
    this.updateSnapshot(snapshot);
  }
  clear(): void { ++this.revision; this.owner = ''; this.ready = false; this.loading = false; this.settings = defaultReadingSettings(); this.settingsListener?.(this.settings); this.seen.clear(); this.cancel(); }
  setForeground(value: boolean): void { this.foreground = value; if (!value) this.cancel(); }
  updateSnapshot(snapshot: WearableSnapshot): void {
    if (this.snapshot.deviceKey !== snapshot.deviceKey || this.snapshot.firmware !== snapshot.firmware ||
      (this.snapshot.connected && !snapshot.connected)) this.cancel();
    if (this.activeNotice?.event && !supportedReadingRules(snapshot).includes(this.activeNotice.event.rule)) this.cancel();
    this.snapshot = snapshot; this.evaluate();
  }
  measurement(state: MeasurementState): void { this.completed = state; this.evaluate(); }
  begin(metric: WearableMetricKey): number {
    this.cancel();
    if (!this.ready || !this.owner || !this.foreground || !this.snapshot.connected) return -1;
    const token = ++this.sequence;
    this.pending = { token, owner: this.owner, device: this.snapshot.deviceKey, firmware: this.snapshot.firmware,
      metric, started: Date.now(), confirmed: false };
    this.completed = emptyMeasurement();
    return token;
  }
  confirmStart(accepted: boolean, token: number): void {
    if (this.pending?.token !== token) return;
    if (!accepted) { this.pending = undefined; return; }
    if (this.pending) { this.pending.confirmed = true; this.evaluate(); }
  }
  cancel(): void { ++this.feedbackRevision; this.pending = undefined; this.activeNotice = undefined; readingReminderSound.stop(); this.notice?.(undefined); }
  dismiss(token: number): void { if (this.activeNotice?.token === token) this.cancel(); }
  mute(token?: number): void {
    if (token !== undefined && this.activeNotice?.token !== token) return;
    if (this.activeNotice) this.played = this.activeNotice.token;
    readingReminderSound.stop();
  }
  preview(sound: boolean, reduceMotion: boolean): void {
    this.cancel();
    if (!this.foreground) return;
    this.noticeOwner = this.owner;
    this.activeNotice = { token: ++this.sequence, preview: true, reduceMotion, phoneSound: sound };
    this.notice?.(this.activeNotice);
  }
  noticeVisible(token: number): void {
    const notice = this.activeNotice;
    if (!notice || notice.token !== token || token === this.played || !this.foreground || this.noticeOwner !== this.owner) return;
    if (notice.event && (!this.snapshot.connected || notice.event.deviceKey !== this.snapshot.deviceKey || notice.event.firmware !== this.snapshot.firmware ||
      !supportedReadingRules(this.snapshot).includes(notice.event.rule) || !readingRuleEnabled(this.settings, notice.event.rule))) return;
    this.played = token;
    if (notice.phoneSound && this.context) readingReminderSound.play(this.context);
  }
  async save(owner: string, settings: ReadingSettings, device: string, firmware: string): Promise<void> {
    const revision = this.revision;
    const error = readingSettingsError(settings);
    if (error) throw new Error(error);
    if (owner !== this.owner || device !== this.snapshot.deviceKey || firmware !== this.snapshot.firmware) throw new Error('账号或戒指已变化，请重新进入设置');
    this.cancel();
    await readingReminderStore.save(owner, settings);
    if (owner !== this.owner || revision !== this.revision || device !== this.snapshot.deviceKey || firmware !== this.snapshot.firmware) throw new Error('账号或戒指已变化，请重新进入设置');
    this.settings = settings; this.ready = true; this.settingsListener?.(this.settings); this.cancel();
  }
  private evaluate(): void {
    const pending = this.pending;
    if (!pending || !pending.confirmed || !this.ready || !this.foreground || pending.owner !== this.owner) return;
    if (Date.now() - pending.started > 90000) { this.pending = undefined; return; }
    if (this.completed.running || this.completed.progress !== 100 || this.completed.metric !== pending.metric) return;
    for (const record of this.snapshot.records) {
      const event = evaluatePersonalReading(this.settings, this.snapshot, record, this.completed, pending.started, Date.now());
      if (!event || this.seen.has(event.id)) continue;
      this.pending = undefined; this.seen.add(event.id);
      const revision = this.revision, feedbackRevision = this.feedbackRevision, owner = this.owner;
      const current = (): boolean => revision === this.revision && feedbackRevision === this.feedbackRevision && owner === this.owner && this.foreground &&
        this.snapshot.connected && this.snapshot.deviceKey === pending.device && this.snapshot.firmware === pending.firmware;
      readingReminderStore.append(owner, event, current).then(() => {
        if (!current()) return;
        this.noticeOwner = owner;
        this.activeNotice = { token: ++this.sequence, preview: false, event, reduceMotion: this.settings.reduceMotion, phoneSound: this.settings.phoneSound };
        this.notice?.(this.activeNotice);
      }).catch(() => { /* No false persisted-success message. */ });
      return;
    }
  }
}
export const personalReadingReminders: PersonalReadingReminders = new PersonalReadingReminders();
