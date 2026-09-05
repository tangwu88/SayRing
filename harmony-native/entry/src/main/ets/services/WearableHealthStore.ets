import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import {
  HealthRecord, HealthValue, WearableMetricKey, WearableProvider, WearableRecordSource,
  healthValue
} from '../model/WearableContracts';

const STORE_NAME: string = 'saydian_wearable_health.db';
const RECORD_TABLE: string = 'wearable_health_record';
const BINDING_TABLE: string = 'wearable_binding';
const MAX_LOADED_RECORDS: number = 2000;

const METRICS: WearableMetricKey[] = [
  'activity', 'sleep', 'heart', 'pressure', 'oxygen', 'temperature', 'glucose', 'hrv',
  'ecg', 'bodyComposition', 'bloodComponents', 'sport'
];

export interface StoredWearableBinding {
  provider: WearableProvider;
  name: string;
  mac: string;
  updatedAt: number;
}

interface StoredHealthValue {
  name: string;
  value: number;
  unit: string;
}

export class WearableHealthStore {
  private context: common.Context | null = null;
  private store: relationalStore.RdbStore | null = null;
  private opening: Promise<relationalStore.RdbStore> | null = null;

  async open(context: common.Context): Promise<void> {
    this.context = context;
    await this.getStore();
  }

  async saveRecords(records: HealthRecord[]): Promise<void> {
    if (records.length === 0) return;
    const store = await this.getStore();
    // Loading is intentionally bounded for UI memory, but persistence must never
    // drop older records. Chunking also avoids oversized single DB transactions.
    const batchSize = 250;
    for (let offset = 0; offset < records.length; offset += batchSize) {
      const rows: relationalStore.ValuesBucket[] = records.slice(offset, offset + batchSize)
        .map((record: HealthRecord) => this.recordBucket(record));
      await store.batchInsertWithConflictResolution(RECORD_TABLE, rows,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    }
  }

  async loadRecent(deviceKey: string = '', limit: number = MAX_LOADED_RECORDS): Promise<HealthRecord[]> {
    const store = await this.getStore();
    const predicates = new relationalStore.RdbPredicates(RECORD_TABLE);
    if (deviceKey) predicates.equalTo('device_key', deviceKey);
    predicates.orderByDesc('recorded_at').limitAs(Math.max(1, Math.min(MAX_LOADED_RECORDS, Math.round(limit))));
    const result = await store.query(predicates,
      ['record_id', 'device_key', 'metric', 'recorded_at', 'source', 'values_json', 'samples_json', 'sample_frequency']);
    const records: HealthRecord[] = [];
    try {
      while (result.goToNextRow()) {
        const record = this.readRecord(result);
        if (record) records.push(record);
      }
    } finally { result.close(); }
    return records;
  }

  async loadRange(deviceKey: string, metric: WearableMetricKey,
    startTime: number, endTime: number): Promise<HealthRecord[]> {
    const store = await this.getStore();
    const predicates = new relationalStore.RdbPredicates(RECORD_TABLE)
      .equalTo('device_key', deviceKey)
      .and().equalTo('metric', metric)
      .and().between('recorded_at', Math.round(startTime), Math.round(endTime))
      .orderByDesc('recorded_at');
    const result = await store.query(predicates,
      ['record_id', 'device_key', 'metric', 'recorded_at', 'source', 'values_json', 'samples_json', 'sample_frequency']);
    const records: HealthRecord[] = [];
    try {
      while (result.goToNextRow()) {
        const record = this.readRecord(result);
        if (record) records.push(record);
      }
    } finally { result.close(); }
    return records;
  }

  async saveBinding(binding: StoredWearableBinding): Promise<void> {
    const store = await this.getStore();
    const values: relationalStore.ValuesBucket = {
      binding_id: 1,
      provider: binding.provider,
      device_name: binding.name.slice(0, 80),
      mac: binding.mac,
      updated_at: Math.round(binding.updatedAt)
    };
    await store.insert(BINDING_TABLE, values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async loadBinding(): Promise<StoredWearableBinding | undefined> {
    const store = await this.getStore();
    const result = await store.query(new relationalStore.RdbPredicates(BINDING_TABLE).equalTo('binding_id', 1),
      ['provider', 'device_name', 'mac', 'updated_at']);
    try {
      if (!result.goToNextRow()) return undefined;
      const provider = result.getString(0);
      const name = result.getString(1);
      const mac = result.getString(2);
      const updatedAt = result.getLong(3);
      if ((provider !== 'Vep' && provider !== 'Yuc') || !name || !mac || !Number.isFinite(updatedAt)) return undefined;
      return { provider: provider as WearableProvider, name: name, mac: mac, updatedAt: updatedAt };
    } finally { result.close(); }
  }

  private async getStore(): Promise<relationalStore.RdbStore> {
    if (this.store) return this.store;
    if (this.opening) return this.opening;
    if (!this.context) throw new Error('健康数据库尚未初始化');
    const config: relationalStore.StoreConfig = {
      name: STORE_NAME,
      securityLevel: relationalStore.SecurityLevel.S3,
      encrypt: true
    };
    this.opening = relationalStore.getRdbStore(this.context, config).then(async (store: relationalStore.RdbStore) => {
      await store.executeSql(`CREATE TABLE IF NOT EXISTS ${RECORD_TABLE} (` +
        'record_id TEXT PRIMARY KEY, device_key TEXT NOT NULL, metric TEXT NOT NULL, ' +
        'recorded_at INTEGER NOT NULL, source TEXT NOT NULL, values_json TEXT NOT NULL, ' +
        'samples_json TEXT NOT NULL, sample_frequency INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL)');
      await store.executeSql(`CREATE INDEX IF NOT EXISTS idx_wearable_metric_time ON ${RECORD_TABLE} ` +
        '(device_key, metric, recorded_at DESC)');
      await store.executeSql(`CREATE TABLE IF NOT EXISTS ${BINDING_TABLE} (` +
        'binding_id INTEGER PRIMARY KEY, provider TEXT NOT NULL, device_name TEXT NOT NULL, ' +
        'mac TEXT NOT NULL, updated_at INTEGER NOT NULL)');
      this.store = store;
      return store;
    });
    try { return await this.opening; }
    finally { this.opening = null; }
  }

  private recordBucket(record: HealthRecord): relationalStore.ValuesBucket {
    return {
      record_id: record.id,
      device_key: record.deviceKey,
      metric: record.metric,
      recorded_at: Math.round(record.timestamp),
      source: record.source,
      values_json: JSON.stringify(record.values),
      samples_json: JSON.stringify(record.samples.slice(0, 60000)),
      sample_frequency: Math.max(0, Math.round(record.sampleFrequency)),
      updated_at: Date.now()
    };
  }

  private readRecord(result: relationalStore.ResultSet): HealthRecord | undefined {
    const id = result.getString(0);
    const deviceKey = result.getString(1);
    const metricText = result.getString(2);
    const timestamp = result.getLong(3);
    const sourceText = result.getString(4);
    if (!id || !deviceKey || !METRICS.includes(metricText as WearableMetricKey) ||
      !Number.isFinite(timestamp) || timestamp <= 0 ||
      (sourceText !== 'watch_history' && sourceText !== 'app_measurement')) return undefined;
    const values = this.parseValues(result.getString(5));
    const samples = this.parseSamples(result.getString(6));
    if (values.length === 0 && samples.length === 0) return undefined;
    return {
      id: id,
      deviceKey: deviceKey,
      metric: metricText as WearableMetricKey,
      timestamp: timestamp,
      source: sourceText as WearableRecordSource,
      values: values,
      samples: samples,
      sampleFrequency: Math.max(0, Math.round(result.getLong(7)))
    };
  }

  private parseValues(text: string): HealthValue[] {
    try {
      const items = JSON.parse(text) as StoredHealthValue[];
      if (!Array.isArray(items)) return [];
      const values: HealthValue[] = [];
      items.slice(0, 32).forEach((item: StoredHealthValue) => {
        if (!item || typeof item.name !== 'string' || typeof item.value !== 'number' || typeof item.unit !== 'string') return;
        const value = healthValue(item.name, item.value, item.unit);
        if (value) values.push(value);
      });
      return values;
    } catch { return []; }
  }

  private parseSamples(text: string): number[] {
    try {
      const items = JSON.parse(text) as number[];
      if (!Array.isArray(items)) return [];
      const samples: number[] = [];
      items.slice(0, 60000).forEach((value: number) => {
        if (typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= 1000000) samples.push(value);
      });
      return samples;
    } catch { return []; }
  }
}

export const wearableHealthStore: WearableHealthStore = new WearableHealthStore();
