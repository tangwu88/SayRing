import { asset } from '@kit.AssetStoreKit';
import { common, Want } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import * as wxopensdk from '@tencent/wechat_open_sdk';
import { wechatPayment } from './WechatPaymentService';
import {
  WECHAT_APP_ID, WECHAT_AUTH_RESULT_KEY, WechatAuthResult, buildWechatState,
  isFreshWechatState, wechatAuthErrorMessage
} from '../model/WechatAuthContracts';

interface PendingWechatState { value: string; expiresAt: number; }
export interface WechatAuthStartResult { sent: boolean; message: string; }

export function initializeWechatAuthState(): void {
  AppStorage.setOrCreate<string>(WECHAT_AUTH_RESULT_KEY, '');
}

class WechatAuthService implements wxopensdk.WXApiEventHandler {
  private context?: common.UIAbilityContext;
  private api?: wxopensdk.WXApi;
  private readonly alias: Uint8Array = new util.TextEncoder().encodeInto('saydian.harmony.wechat-state.v1');

  attachContext(context: common.UIAbilityContext): void {
    this.context = context;
    if (!this.api) this.api = wxopensdk.WXAPIFactory.createWXAPI(WECHAT_APP_ID, context);
  }

  async start(): Promise<WechatAuthStartResult> {
    if (!this.context || !this.api) return { sent: false, message: '暂时无法打开微信，请重试' };
    if (!this.api.isWXAppInstalled()) return { sent: false, message: '请先安装微信后再登录' };
    const state = buildWechatState(Date.now(), util.generateRandomUUID(false));
    if (!state) return { sent: false, message: '暂时无法打开微信，请重试' };
    try {
      await this.saveState({ value: state, expiresAt: Date.now() + 10 * 60 * 1000 });
      const request = new wxopensdk.SendAuthReq();
      request.isOption1 = false;
      request.nonAutomatic = true;
      request.scope = 'snsapi_userinfo';
      request.state = state;
      request.transaction = state;
      request.callbackAbility = 'EntryAbility';
      const sent = await this.api.sendReq(this.context, request);
      if (!sent) await this.clearState();
      return sent ? { sent: true, message: '' } : { sent: false, message: '未能打开微信，请重试' };
    } catch {
      await this.clearState();
      return { sent: false, message: '暂时无法打开微信，请重试' };
    }
  }

  handleWant(want: Want): boolean {
    if (!this.api) return false;
    try { return this.api.handleWant(want, this); }
    catch { return false; }
  }

  onReq(_request: wxopensdk.BaseReq): void {}

  onResp(response: wxopensdk.BaseResp): void {
    if (response instanceof wxopensdk.PayResp) { wechatPayment.handleResponse(response); return; }
    if (!(response instanceof wxopensdk.SendAuthResp)) return;
    this.consumeResponse(response);
  }

  private async consumeResponse(response: wxopensdk.SendAuthResp): Promise<void> {
    const pending = await this.readState();
    await this.clearState();
    if (response.errCode !== wxopensdk.ErrCode.ERR_OK) {
      this.publish({ status: 'error', code: '', state: '', openId: '', message: wechatAuthErrorMessage(response.errCode) });
      return;
    }
    const state = response.state?.trim() ?? '';
    const code = response.code?.trim() ?? '';
    const openId = response.openId?.trim() ?? '';
    if (!pending || pending.expiresAt < Date.now() || !isFreshWechatState(state, pending.value, Date.now()) || !code) {
      this.publish({ status: 'error', code: '', state: '', openId: '', message: '微信授权已失效，请重新登录' });
      return;
    }
    if (!openId) {
      this.publish({ status: 'error', code: '', state: '', openId: '', message: '微信未返回登录信息，请更新微信后重试' });
      return;
    }
    this.publish({ status: 'success', code: code, state: state, openId: openId, message: '' });
  }

  private publish(result: WechatAuthResult): void {
    AppStorage.setOrCreate<string>(WECHAT_AUTH_RESULT_KEY, JSON.stringify(result));
  }

  private async saveState(state: PendingWechatState): Promise<void> {
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.alias);
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(JSON.stringify(state)));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    await asset.add(attributes);
  }

  private async readState(): Promise<PendingWechatState | undefined> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results = await asset.query(query);
      if (results.length === 0) return undefined;
      const secret = results[0].get(asset.Tag.SECRET) as Uint8Array;
      const state = JSON.parse(new util.TextDecoder().decodeToString(secret)) as PendingWechatState;
      if (!state || typeof state.value !== 'string' || typeof state.expiresAt !== 'number') return undefined;
      return state;
    } catch { return undefined; }
  }

  private async clearState(): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias);
    try { await asset.remove(query); } catch {}
  }
}

export const wechatAuth: WechatAuthService = new WechatAuthService();
