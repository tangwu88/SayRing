import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { HealthRecord, WearableProvider } from '../model/WearableContracts';
import { HEALTH_OWNER_SCHEMA, OWNED_HEALTH_TABLE, OWNED_BINDING_TABLE, DEVICE_CLAIM_TABLE,
  validHealthOwner, healthUploadSupported, isDailyUpload, ownershipStart, UPSERT_OWNED_HEALTH_SQL, MARK_HEALTH_UPLOADED_SQL } from '../model/HealthUpload';

const STORE_NAME: string = 'saydian_wearable_health.db';
const MAX_LOADED_RECORDS: number = 2000;
export interface StoredWearableBinding { provider: WearableProvider; name: string; mac: string; updatedAt: number; }

export class WearableHealthStore {
  private context: common.Context | null = null;
  private store: relationalStore.RdbStore | null = null;
  private opening: Promise<relationalStore.RdbStore> | null = null;
  private writing: Promise<void> = Promise.resolve();

  async open(context: common.Context): Promise<void> { this.context = context; await this.getStore(); }
  async saveRecords(owner: string, records: HealthRecord[], isCurrent: () => boolean = () => true): Promise<void> {
    if (!validHealthOwner(owner) || !records.length) return;
    await this.write(async (store: relationalStore.RdbStore) => {
      if (!isCurrent()) return;
      for (const record of records) {
        if (!isCurrent()) throw new Error('账号或设备已变化');
        const payload = JSON.stringify(record);
        const state = healthUploadSupported(record) ? 'pending' : 'local_only';
        // API 12 compatible SQL transaction; no since-18 batch API and no REPLACE resetting synced rows.
        await store.executeSql(UPSERT_OWNED_HEALTH_SQL,
          [owner, record.id, record.deviceKey, record.metric, Math.round(record.timestamp), record.source, payload, state, Date.now()]);
      }
      if (!isCurrent()) throw new Error('账号或设备已变化');
    });
  }
  async loadRecent(owner: string, deviceKey: string = '', limit: number = MAX_LOADED_RECORDS): Promise<HealthRecord[]> {
    if (!validHealthOwner(owner)) return [];
    const predicates = new relationalStore.RdbPredicates(OWNED_HEALTH_TABLE).equalTo('owner_id', owner);
    if (deviceKey) predicates.and().equalTo('device_key', deviceKey);
    predicates.orderByDesc('recorded_at').limitAs(Math.max(1, Math.min(MAX_LOADED_RECORDS, Math.round(limit))));
    return this.records(predicates);
  }
  async loadRange(owner: string, deviceKey: string, metric: string, start: number, end: number): Promise<HealthRecord[]> {
    if (!validHealthOwner(owner)) return [];
    return this.records(new relationalStore.RdbPredicates(OWNED_HEALTH_TABLE).equalTo('owner_id', owner)
      .and().equalTo('device_key', deviceKey).and().equalTo('metric', metric)
      .and().between('recorded_at', Math.round(start), Math.round(end)).orderByDesc('recorded_at'));
  }
  async pending(owner: string): Promise<HealthRecord[]> {
    if (!validHealthOwner(owner)) return [];
    const records = await this.records(new relationalStore.RdbPredicates(OWNED_HEALTH_TABLE).equalTo('owner_id', owner)
      .and().equalTo('sync_state', 'pending').orderByAsc('recorded_at').limitAs(20));
    // Include previously uploaded fields of the same legacy minute row when a new measurement arrives.
    const expanded: Map<string, HealthRecord> = new Map();
    records.forEach((record: HealthRecord) => expanded.set(record.id, record));
    const minutes: Set<number> = new Set();
    for (const record of records) {
      if (!isDailyUpload(record)) continue;
      const minute = Math.floor(record.timestamp / 60000) * 60000;
      if (minutes.has(minute)) continue;
      minutes.add(minute);
      const related = await this.records(new relationalStore.RdbPredicates(OWNED_HEALTH_TABLE).equalTo('owner_id', owner)
        .and().between('recorded_at', minute, minute + 59999).orderByAsc('recorded_at'));
      related.filter(isDailyUpload).forEach((item: HealthRecord) => expanded.set(item.id, item));
    }
    return Array.from(expanded.values()).sort((a: HealthRecord, b: HealthRecord) => a.timestamp - b.timestamp);
  }
  async markUploaded(owner: string, records: HealthRecord[], isCurrent: () => boolean): Promise<void> {
    if (!validHealthOwner(owner)) return;
    await this.write(async (store: relationalStore.RdbStore) => {
      for (const record of records) {
        if (!isCurrent()) throw new Error('账号或设备已变化');
        // CAS preserves a fuller record which arrived while its previous version was uploading.
        await store.executeSql(MARK_HEALTH_UPLOADED_SQL,
          [owner, record.id, JSON.stringify(record)]);
      }
      if (!isCurrent()) throw new Error('账号或设备已变化');
    });
  }
  async pendingCount(owner: string): Promise<number> {
    if (!validHealthOwner(owner)) return 0;
    await this.writing;
    const store = await this.getStore();
    const result = await store.querySql(`SELECT COUNT(*) FROM ${OWNED_HEALTH_TABLE} WHERE owner_id=? AND sync_state='pending'`, [owner]);
    try { return result.goToNextRow() ? result.getLong(0) : 0; } finally { result.close(); }
  }
  async claimDevice(owner: string, deviceKey: string, now: number, resume: boolean, isCurrent: () => boolean): Promise<number> {
    if (!validHealthOwner(owner) || !deviceKey) return Number.MAX_SAFE_INTEGER;
    let since = now;
    await this.write(async (store: relationalStore.RdbStore) => {
      if (!isCurrent()) throw new Error('账号或设备已变化');
      const current = await store.querySql(`SELECT owner_id,owned_since FROM ${DEVICE_CLAIM_TABLE} WHERE device_key=?`, [deviceKey]);
      try { if (current.goToNextRow()) since = ownershipStart(current.getString(0), current.getLong(1), owner, now, resume); }
      finally { current.close(); }
      await store.executeSql(`INSERT OR REPLACE INTO ${DEVICE_CLAIM_TABLE} (device_key,owner_id,owned_since) VALUES (?,?,?)`,
        [deviceKey, owner, since]);
      if (!isCurrent()) throw new Error('账号或设备已变化');
    });
    return since;
  }
  async saveBinding(owner: string, binding: StoredWearableBinding, isCurrent: () => boolean): Promise<void> {
    if (!validHealthOwner(owner)) return;
    await this.write(async (store: relationalStore.RdbStore) => {
      if (!isCurrent()) throw new Error('账号或设备已变化');
      await store.executeSql(`INSERT OR REPLACE INTO ${OWNED_BINDING_TABLE} ` +
        '(owner_id,provider,device_name,mac,updated_at) VALUES (?,?,?,?,?)',
        [owner, binding.provider, binding.name.slice(0, 80), binding.mac, binding.updatedAt]);
      if (!isCurrent()) throw new Error('账号或设备已变化');
    });
  }
  async loadBinding(owner: string): Promise<StoredWearableBinding | undefined> {
    if (!validHealthOwner(owner)) return undefined;
    await this.writing;
    const store = await this.getStore();
    const result = await store.querySql(`SELECT provider,device_name,mac,updated_at FROM ${OWNED_BINDING_TABLE} WHERE owner_id=?`, [owner]);
    try {
      if (!result.goToNextRow()) return undefined;
      const provider = result.getString(0), name = result.getString(1), mac = result.getString(2);
      if ((provider !== 'Vep' && provider !== 'Yuc') || !name || !mac) return undefined;
      return { provider: provider as WearableProvider, name: name, mac: mac, updatedAt: result.getLong(3) };
    } finally { result.close(); }
  }
  private async records(predicates: relationalStore.RdbPredicates): Promise<HealthRecord[]> {
    await this.writing;
    const store = await this.getStore();
    const result = await store.query(predicates, ['payload']);
    const records: HealthRecord[] = [];
    try {
      while (result.goToNextRow()) {
        try {
          const record = JSON.parse(result.getString(0)) as HealthRecord;
          if (record.id && record.deviceKey && Number.isFinite(record.timestamp) &&
            Array.isArray(record.values) && Array.isArray(record.samples)) records.push(record);
        } catch { /* Corrupt rows remain on disk and are never presented as valid measurements. */ }
      }
    } finally { result.close(); }
    return records;
  }
  private write(operation: (store: relationalStore.RdbStore) => Promise<void>): Promise<void> {
    const writing = this.writing.then(async () => {
      const store = await this.getStore();
      store.beginTransaction();
      try { await operation(store); store.commit(); }
      catch (error) { store.rollBack(); throw error as Error; }
    });
    this.writing = writing.catch(() => {});
    return writing;
  }
  private async getStore(): Promise<relationalStore.RdbStore> {
    if (this.store) return this.store;
    if (this.opening) return this.opening;
    if (!this.context) throw new Error('健康数据库尚未初始化');
    const config: relationalStore.StoreConfig = { name: STORE_NAME, securityLevel: relationalStore.SecurityLevel.S3, encrypt: true };
    this.opening = relationalStore.getRdbStore(this.context, config).then(async (store: relationalStore.RdbStore) => {
      store.beginTransaction();
      try { for (const sql of HEALTH_OWNER_SCHEMA) await store.executeSql(sql); store.commit(); }
      catch (error) { store.rollBack(); throw error as Error; }
      this.store = store; return store;
    });
    try { return await this.opening; } finally { this.opening = null; }
  }
}
export const wearableHealthStore: WearableHealthStore = new WearableHealthStore();
