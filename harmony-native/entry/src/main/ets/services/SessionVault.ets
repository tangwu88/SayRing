import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Session, ApiError, validateStoredSession } from '../model/Contracts';

export class SessionVault {
  private alias: Uint8Array = new util.TextEncoder().encodeInto('saydian.global.harmony.session.v1');

  async read(): Promise<Session | undefined> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results = await asset.query(query);
      if (results.length === 0) return undefined;
      const secret = results[0].get(asset.Tag.SECRET) as Uint8Array;
      const data = new util.TextDecoder().decodeToString(secret);
      return validateStoredSession(JSON.parse(data) as Session);
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) return undefined;
      if (error instanceof ApiError) throw error;
      throw new ApiError('安全存储暂不可用，请解锁设备后重试');
    }
  }

  async write(session: Session): Promise<void> {
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.alias);
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(JSON.stringify(session)));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    try { await asset.add(attributes); }
    catch { throw new ApiError('安全存储暂不可用，请解锁设备后重试'); }
  }

  async clear(): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias);
    try { await asset.remove(query); }
    catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) {
        throw new ApiError('未能清除本机登录状态，请重试');
      }
    }
  }
}
