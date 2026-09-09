import type { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import * as wxopensdk from '@tencent/wechat_open_sdk';
import { ApiError } from '../model/Contracts';
import { WECHAT_APP_ID } from '../model/WechatAuthContracts';
import type { WechatSignedPayment } from '../model/WechatPaymentContracts';
import { matchesWechatPayment } from '../model/WechatPaymentContracts';
import { withPaymentTimeout } from '../model/PaymentWatchdog';

interface PendingWechatPayment {
  prepayId: string;
  transaction: string;
  resolve: () => void;
  reject: (reason: ApiError) => void;
}

class WechatPaymentService {
  private api?: wxopensdk.WXApi;
  private pending?: PendingWechatPayment;

  isAvailable(): boolean {
    if (!WECHAT_APP_ID) return false;
    try {
      if (!this.api) this.api = wxopensdk.WXAPIFactory.createWXAPI(WECHAT_APP_ID);
      return this.api.isWXAppInstalled();
    } catch { return false; }
  }

  async start(context: common.UIAbilityContext, fields: WechatSignedPayment): Promise<void> {
    if (this.pending) throw new ApiError('支付请求正在处理，请勿重复提交');
    if (!this.isAvailable() || !this.api) throw new ApiError('请先安装微信后再支付');
    const transaction = `sdpay_${util.generateRandomUUID(false)}`;
    const request = new wxopensdk.PayReq();
    request.appId = fields.appId;
    request.partnerId = fields.partnerId;
    request.prepayId = fields.prepayId;
    request.nonceStr = fields.nonceStr;
    request.timeStamp = fields.timeStamp;
    request.packageValue = fields.packageValue;
    request.sign = fields.sign;
    if (fields.signType) request.signType = fields.signType;
    request.transaction = transaction;
    request.callbackAbility = 'EntryAbility';
    if (!request.checkArgs()) throw new ApiError('支付信息暂时不可用，请刷新订单后重试');
    const api = this.api;
    try {
      await withPaymentTimeout(new Promise<void>((resolve: () => void, reject: (reason: ApiError) => void) => {
        this.pending = { prepayId: fields.prepayId, transaction: transaction, resolve: resolve, reject: reject };
        try {
          Promise.resolve(api.sendReq(context, request)).then((sent: boolean) => {
            if (!sent) reject(new ApiError('未能打开微信，请稍后重试'));
          }).catch(() => reject(new ApiError('暂时无法打开微信，请稍后重试')));
        } catch { reject(new ApiError('暂时无法打开微信，请稍后重试')); }
      }));
    } finally {
      this.clearPending(transaction);
    }
  }

  private clearPending(transaction: string): void {
    if (this.pending?.transaction === transaction) this.pending = undefined;
  }

  handleResponse(response: wxopensdk.PayResp): void {
    const pending = this.pending;
    if (!pending || !matchesWechatPayment(pending.prepayId, pending.transaction,
      response.prepayId?.trim() ?? '', response.transaction?.trim() ?? '')) return;
    this.pending = undefined;
    if (response.errCode === wxopensdk.ErrCode.ERR_OK) pending.resolve();
    else if (response.errCode === wxopensdk.ErrCode.ERR_USER_CANCEL) pending.reject(new ApiError('已取消支付'));
    else pending.reject(new ApiError('支付未完成，请确认订单状态后重试'));
  }
}

export const wechatPayment: WechatPaymentService = new WechatPaymentService();
