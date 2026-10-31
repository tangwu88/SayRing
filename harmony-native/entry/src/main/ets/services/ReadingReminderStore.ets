import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { ReadingSettings, PersonalReadingEvent, defaultReadingSettings, parseReadingSettings } from '../model/ReadingReminders';

export class ReadingReminderStore {
  private context: common.UIAbilityContext | undefined = undefined;
  private opening: Promise<relationalStore.RdbStore> | undefined = undefined;
  attach(context: common.UIAbilityContext): void { this.context = context; }
  private alias(owner: string): Uint8Array {
    return new util.TextEncoder().encodeInto(`say-ring.reading-settings.v1.${encodeURIComponent(owner || 'guest')}`);
  }
  async read(owner: string): Promise<ReadingSettings> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias(owner)); query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const rows = await asset.query(query);
      if (!rows.length) return defaultReadingSettings();
      const raw = new util.TextDecoder().decodeToString(rows[0].get(asset.Tag.SECRET) as Uint8Array);
      return parseReadingSettings(JSON.parse(raw) as Object);
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) return defaultReadingSettings();
      throw new Error('提醒设置暂未读取，请解锁后重试');
    }
  }
  async save(owner: string, settings: ReadingSettings): Promise<void> {
    const secret = new util.TextEncoder().encodeInto(JSON.stringify(settings));
    if (secret.length > 1024) throw new Error('提醒设置过长，请检查后重试');
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.alias(owner)); attributes.set(asset.Tag.SECRET, secret);
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    await asset.add(attributes);
  }
  private database(): Promise<relationalStore.RdbStore> {
    if (this.opening) return this.opening;
    const context = this.context;
    if (!context) return Promise.reject(new Error('提醒记录尚未就绪'));
    this.opening = relationalStore.getRdbStore(context, { name: 'say_ring_personal_readings_v1.db',
      securityLevel: relationalStore.SecurityLevel.S3, encrypt: true }).then(async (store: relationalStore.RdbStore) => {
      await store.executeSql('CREATE TABLE IF NOT EXISTS personal_readings (owner TEXT NOT NULL, id TEXT NOT NULL, measured_at REAL NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(owner,id))');
      return store;
    }).catch((error: Error) => { this.opening = undefined; throw error; });
    return this.opening;
  }
  async append(owner: string, event: PersonalReadingEvent, isCurrent: () => boolean): Promise<void> {
    if (!owner || !isCurrent()) return;
    const store = await this.database();
    if (!isCurrent()) return;
    await store.executeSql('INSERT OR IGNORE INTO personal_readings (owner,id,measured_at,payload) VALUES (?,?,?,?)',
      [owner, event.id, event.measuredAt, JSON.stringify(event)]);
  }
  async events(owner: string): Promise<PersonalReadingEvent[]> {
    if (!owner) return [];
    const store = await this.database();
    const rows = await store.query(new relationalStore.RdbPredicates('personal_readings').equalTo('owner', owner)
      .orderByDesc('measured_at').limitAs(50));
    const result: PersonalReadingEvent[] = [];
    try {
      while (rows.goToNextRow()) {
        try {
          const event = JSON.parse(rows.getString(rows.getColumnIndex('payload'))) as PersonalReadingEvent;
          if (event.id && Number.isFinite(event.value) && Number.isFinite(event.measuredAt)) result.push(event);
        } catch { /* Preserve a malformed row without presenting invented data. */ }
      }
    } finally { rows.close(); }
    return result;
  }
}
export const readingReminderStore: ReadingReminderStore = new ReadingReminderStore();
