import type { HealthRecord } from '../model/WearableContracts';
import type { HealthOwnerSession, HealthSyncResult, HealthUploadRequest } from '../model/HealthUpload';
import { healthUploadRequests, sameHealthSession, validHealthOwner } from '../model/HealthUpload';

export interface HealthUploadStore {
  pending(ownerId: string): Promise<HealthRecord[]>;
  markUploaded(ownerId: string, records: HealthRecord[], isCurrent: () => boolean): Promise<void>;
  pendingCount(ownerId: string): Promise<number>;
}
export interface HealthUploadApi {
  healthSession(): HealthOwnerSession;
  uploadHealthRequest(request: HealthUploadRequest, session: HealthOwnerSession): Promise<void>;
}
export class HealthUploadService {
  private running: Promise<HealthSyncResult> | undefined = undefined;
  private store: HealthUploadStore;
  private api: HealthUploadApi;
  constructor(store: HealthUploadStore, api: HealthUploadApi) { this.store = store; this.api = api; }

  synchronize(isCurrent: () => boolean = () => true): Promise<HealthSyncResult> {
    if (this.running) return this.running;
    this.running = this.run(isCurrent).finally(() => { this.running = undefined; });
    return this.running;
  }
  private async run(isCurrent: () => boolean): Promise<HealthSyncResult> {
    const session = this.api.healthSession();
    const current = (): boolean => isCurrent() && sameHealthSession(session, this.api.healthSession());
    let uploaded = 0;
    if (!validHealthOwner(session.ownerId)) return { state: 'signed_out', uploaded: 0, pending: 0, message: '' };
    try {
      while (current()) {
        const records = await this.store.pending(session.ownerId);
        if (!current()) break;
        if (records.length === 0) return { state: 'complete', uploaded: uploaded, pending: 0, message: '' };
        const requests = healthUploadRequests(records);
        if (!requests.length) throw new Error('部分记录暂不支持上传');
        for (const request of requests) {
          if (!current()) break;
          await this.api.uploadHealthRequest(request, session);
          if (!current()) break;
          await this.store.markUploaded(session.ownerId, records.filter((record: HealthRecord) => request.recordIds.includes(record.id)), current);
          if (!current()) break;
          uploaded += request.recordIds.length;
        }
      }
      return { state: 'cancelled', uploaded: uploaded, pending: 0, message: '' };
    } catch {
      if (!current()) return { state: 'cancelled', uploaded: uploaded, pending: 0, message: '' };
      return { state: 'retry', uploaded: uploaded, pending: await this.store.pendingCount(session.ownerId).catch(() => -1),
        message: '部分数据暂未上传，已保存在本机，请稍后重试' };
    }
  }
}
