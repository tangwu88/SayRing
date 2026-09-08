import {
  ApiError, parseSession,
  validateStoredSession, parseProfile, parseArticles, parseArticle, loginValidation,
  registrationValidation, wechatAuthorizationValidation, wechatOpenIdValidation
} from '../model/Contracts';
import type { Envelope, Session, FormField, MemberProfile, Article, UploadFile } from '../model/Contracts';
import { profileImageUrl } from '../model/Contracts';
import { profileDraftError, profileSaveMismatches, feedbackError } from '../model/DisplayPreferences';
import type { ProfileDraft } from '../model/DisplayPreferences';
import { parseAddresses, parseInbox, parseArticleCategories } from '../model/AccountPageContracts';
import type { ShippingAddress, InboxMessage, ArticleCategory } from '../model/AccountPageContracts';
import { addressBody } from '../model/AddressForm';
import type { AddressDraft, RegionCatalog } from '../model/AddressForm';
import { CARE_METRICS, careId, careMobileValidation, parseCareMembers, parseCareInvitations,
  parseCareSettings, careSettingsBody, chinaDaySeconds, parseCareMetric, careMetricState } from '../model/CareContracts';
import type { CareMember, CareInvitation, CareShareSettings, CareMetric, CareMetricSpec } from '../model/CareContracts';
import { notificationUnreadCount, parseHarmonyPayment, parseShopOrder, parseShopOrders,
  paymentFields, pushRegistrationFields } from '../model/PushPaymentContracts';
import type { HarmonyPaymentRequest, PaymentProvider, PushIdentity, ShopOrder } from '../model/PushPaymentContracts';
import { parseAiMessages, parseAiReply, parseShopHome } from '../model/ExperienceContracts';
import type { AiChatMessage, ShopHome } from '../model/ExperienceContracts';
import { parseProductDetail, parseCart, selectionFields, parseCheckout, checkoutError, commerceCents,
  parseOrderDetail, parseShipments } from '../model/CommerceContracts';
import type { ProductDetail, ShopLine, ShopSelection, CheckoutPreview, OrderDetail, Shipment } from '../model/CommerceContracts';
import type { HealthOwnerSession, HealthUploadRequest } from '../model/HealthUpload';
import { assertHealthUploadAccepted, sameHealthSession } from '../model/HealthUpload';

export interface SessionStore {
  read(): Promise<Session | undefined>;
  write(session: Session): Promise<void>;
  clear(): Promise<void>;
}
export interface ApiTransport {
  request(path: string, fields?: FormField[], session?: Session, jsonBody?: string,
    method?: 'GET' | 'POST' | 'PUT' | 'DELETE'): Promise<Envelope>;
  upload?(path: string, file: UploadFile, session: Session): Promise<Envelope>;
}

// This is the production coordinator, also exercised by host tests with synthetic stores/transports.
export class AccountClient {
  private vault: SessionStore;
  private transport: ApiTransport;
  private now: () => number;
  private session: Session | undefined = undefined;
  private generation: number = 0;
  private blockRestore: boolean = false;
  private vaultQueue: Promise<void> = Promise.resolve();
  private refreshing: Promise<Session> | undefined = undefined;
  private careTargets: Map<number, number> = new Map();
  private careMemberReadGeneration: number = 0;
  private shareSnapshots: Map<number, CareShareSettings> = new Map();
  private shopWriteBusy: boolean = false;
  private healthSessionListener: ((session: HealthOwnerSession) => void) | undefined = undefined;
  private sessionListeners: Set<(session: HealthOwnerSession) => void> = new Set();

  private clearCare(): void { ++this.careMemberReadGeneration; this.careTargets.clear(); this.shareSnapshots.clear(); }

  constructor(transport: ApiTransport, vault: SessionStore, now: () => number = () => Date.now()) {
    this.transport = transport;
    this.vault = vault;
    this.now = now;
  }

  current(): Session | undefined { return this.session ? validateStoredSession(this.session) : undefined; }
  healthSession(): HealthOwnerSession { return { ownerId: this.session?.memberId ?? '', generation: this.generation }; }
  observeHealthSession(listener: (session: HealthOwnerSession) => void): void {
    this.healthSessionListener = listener; this.notifyHealthSession();
  }
  observeSession(listener: (session: HealthOwnerSession) => void): () => void {
    this.sessionListeners.add(listener);
    try { listener(this.healthSession()); } catch { /* An optional UI observer cannot invalidate a valid login. */ }
    return () => { this.sessionListeners.delete(listener); };
  }
  private notifyHealthSession(): void {
    this.healthSessionListener?.(this.healthSession());
    this.sessionListeners.forEach((listener) => { try { listener(this.healthSession()); } catch {} });
  }
  async uploadHealthRequest(request: HealthUploadRequest, session: HealthOwnerSession): Promise<void> {
    if (!sameHealthSession(session, this.healthSession())) throw new ApiError('账号已变化，已暂停上传');
    if (!['/api/v1/member/daily-date', '/api/v1/member/jrjk', '/api/v1/member/e-c-g',
      '/api/v1/member/bodycomposition', '/api/v1/member/bloodcomposition'].includes(request.path)) {
      throw new ApiError('不支持的健康上传项目');
    }
    const response = await this.authorized(request.path, request.body);
    if (!sameHealthSession(session, this.healthSession())) throw new ApiError('账号已变化，已暂停上传');
    assertHealthUploadAccepted(response.data, request.recordIds);
  }
  private assertEpoch(epoch: number): void {
    if (epoch !== this.generation) throw new ApiError('已忽略旧账号请求');
  }

  async restore(): Promise<Session | undefined> {
    if (this.blockRestore) return this.current();
    const epoch = this.generation;
    const reading = this.vaultQueue.catch(() => {}).then(() => this.vault.read());
    this.vaultQueue = reading.then(() => {}, () => {});
    const stored = await reading;
    if (epoch !== this.generation || this.blockRestore) return this.current();
    this.session = stored ? validateStoredSession(stored) : undefined;
    this.notifyHealthSession();
    if (!this.session) return undefined;
    try { return await this.ensureSession(); }
    catch (error) {
      if (error instanceof ApiError && error.status === 401) await this.invalidate(epoch);
      throw error as Error;
    }
  }

  private async clearVault(): Promise<void> {
    const clearing = this.vaultQueue.catch(() => {}).then(() => this.vault.clear());
    this.vaultQueue = clearing;
    await clearing;
  }

  private async invalidate(epoch: number): Promise<void> {
    if (epoch !== this.generation) return;
    ++this.generation;
    this.session = undefined;
    this.notifyHealthSession();
    this.blockRestore = true;
    this.refreshing = undefined;
    this.clearCare();
    try { await this.clearVault(); }
    catch { throw new ApiError('登录已失效，但本机凭证未能清除，请重试退出登录', 401); }
  }

  private async persist(session: Session, epoch: number): Promise<void> {
    const pending = this.vaultQueue.catch(() => {}).then(async () => {
      this.assertEpoch(epoch);
      await this.vault.write(session);
    });
    this.vaultQueue = pending;
    await pending;
    this.assertEpoch(epoch);
    this.session = session;
    this.notifyHealthSession();
  }

  private async authenticate(path: string, fields: FormField[]): Promise<Session> {
    const epoch = ++this.generation;
    this.session = undefined;
    this.notifyHealthSession();
    this.blockRestore = true;
    this.refreshing = undefined;
    this.clearCare();
    // An unsuccessful account change must never restore the previous account.
    await this.clearVault();
    this.assertEpoch(epoch);
    const payload = await this.transport.request(path, fields);
    const session = parseSession(payload, this.now());
    await this.persist(session, epoch);
    this.blockRestore = false;
    return validateStoredSession(session);
  }

  async login(account: string, password: string): Promise<Session> {
    const validation = loginValidation(account, password, true);
    if (validation) throw new ApiError(validation);
    return await this.authenticate('/api/v1/site/login', [
      { name: 'username', value: account.trim() }, { name: 'password', value: password },
      { name: 'group', value: 'app' }
    ]);
  }

  async sendSmsCode(mobile: string, usage: 'register' | 'reset' = 'register'): Promise<void> {
    const normalized = mobile.trim();
    if (!/^1\d{10}$/.test(normalized)) throw new ApiError('请输入正确的中国大陆手机号');
    await this.transport.request('/api/v1/site/sms-code', [
      { name: 'mobile', value: normalized }, { name: 'usage', value: usage }
    ]);
  }

  async registerWithSms(mobile: string, code: string, password: string,
    confirmation: string, accepted: boolean): Promise<Session> {
    const validation = registrationValidation(mobile, code, password, confirmation, accepted);
    if (validation) throw new ApiError(validation);
    const normalized = mobile.trim();
    return await this.authenticate('/api/v1/site/register', [
      { name: 'mobile', value: normalized }, { name: 'code', value: code.trim() },
      { name: 'password', value: password }, { name: 'password_repetition', value: confirmation },
      { name: 'nickname', value: `赛电用户${normalized.slice(-4)}` }, { name: 'group', value: 'app' }
    ]);
  }

  async loginWithWechat(code: string, state: string, openId: string = ''): Promise<Session> {
    const validation = wechatAuthorizationValidation(code, state) ||
      (openId.trim() ? wechatOpenIdValidation(openId) : '');
    if (validation) throw new ApiError(validation);
    // Harmony WeChat returns the one-time authorization code reliably, while openId and profile
    // fields can be empty. The service exchanges code with WeChat and obtains the trusted profile.
    return await this.authenticate('/api/v1/site/app-wechat-login', [
      { name: 'unionid', value: '' }, { name: 'openid', value: openId.trim() },
      { name: 'sex', value: '' }, { name: 'nickname', value: '' }, { name: 'headimgurl', value: '' },
      { name: 'code', value: code.trim() }
    ]);
  }

  async resetPassword(mobile: string, code: string, password: string, confirmation: string): Promise<Session> {
    const validation = registrationValidation(mobile, code, password, confirmation, true);
    if (validation) throw new ApiError(validation);
    return await this.authenticate('/api/v1/site/up-pwd', [
      { name: 'mobile', value: mobile.trim() }, { name: 'code', value: code.trim() },
      { name: 'password', value: password }, { name: 'password_repetition', value: confirmation },
      { name: 'group', value: 'app' }
    ]);
  }

  async addresses(): Promise<ShippingAddress[]> {
    return parseAddresses((await this.authorized('/api/v1/member/address?page=1')).data);
  }

  async saveAddress(draft: AddressDraft, regions: RegionCatalog): Promise<ShippingAddress> {
    const body = addressBody(draft, regions);
    const path = draft.id ? `/api/v1/member/address/${draft.id}` : '/api/v1/member/address';
    const response = await this.authorizedRequest(path, undefined, body, draft.id ? 'PUT' : 'POST');
    const saved = parseAddresses([response.data ?? {}])[0];
    if (draft.id && saved.id !== draft.id) throw new ApiError('地址保存结果不一致，请刷新列表确认');
    return saved;
  }

  async inbox(): Promise<InboxMessage[]> {
    return parseInbox((await this.authorized('/api/v1/member/notify?page=1&type=2')).data);
  }

  async readInboxMessage(id: number): Promise<InboxMessage> {
    if (!Number.isSafeInteger(id) || id <= 0) throw new ApiError('消息编号无效');
    const response = await this.authorized(`/api/v1/member/notify/${id}`);
    return parseInbox([response.data ?? {}])[0];
  }

  async logout(): Promise<void> {
    ++this.generation;
    this.session = undefined;
    this.notifyHealthSession();
    this.blockRestore = true;
    this.refreshing = undefined;
    this.clearCare();
    await this.clearVault();
  }

  private async ensureSession(rejectedToken: string = ''): Promise<Session> {
    const session = this.session;
    if (!session) throw new ApiError('请先登录', 401);
    if (rejectedToken && rejectedToken !== session.accessToken && session.expiresAt > this.now()) return session;
    if (!rejectedToken && session.expiresAt > this.now() + 300000) return session;
    if (!session.refreshToken) {
      if (!rejectedToken && session.expiresAt > this.now()) return session;
      throw new ApiError('登录已过期，请重新登录', 401);
    }
    const epoch = this.generation;
    const pending = this.refreshing || this.refresh(session, epoch);
    this.refreshing = pending;
    try { return await pending; }
    catch (error) {
      this.assertEpoch(epoch);
      // A transient refresh failure does not discard an access token that is still valid.
      if (!rejectedToken && session.expiresAt > this.now() && error instanceof ApiError &&
        (error.status === 0 || error.status >= 500)) return session;
      throw error as Error;
    } finally { if (this.refreshing === pending) this.refreshing = undefined; }
  }

  private async refresh(previous: Session, epoch: number): Promise<Session> {
    const payload = await this.transport.request('/api/v1/site/refresh', [
      { name: 'refresh_token', value: previous.refreshToken }, { name: 'group', value: 'app' }
    ]);
    this.assertEpoch(epoch);
    const next = parseSession(payload, this.now(), previous);
    await this.persist(next, epoch);
    return next;
  }

  private async authorizedRequest(path: string, fields?: FormField[], jsonBody?: string,
    method?: 'GET' | 'POST' | 'PUT' | 'DELETE'): Promise<Envelope> {
    const epoch = this.generation;
    try {
      let session = await this.ensureSession();
      this.assertEpoch(epoch);
      let response: Envelope;
      try { response = await this.transport.request(path, fields, session, jsonBody, method); }
      catch (error) {
        this.assertEpoch(epoch);
        if (error instanceof ApiError) {
          if (error.status !== 401) throw error;
        } else { throw new ApiError('请求失败，请稍后重试'); }
        session = await this.ensureSession(session.accessToken);
        this.assertEpoch(epoch);
        response = await this.transport.request(path, fields, session, jsonBody, method);
      }
      this.assertEpoch(epoch);
      return response;
    } catch (error) {
      this.assertEpoch(epoch);
      if (error instanceof ApiError && error.status === 401) await this.invalidate(epoch);
      throw error as Error;
    }
  }

  private async authorized(path: string, jsonBody?: string): Promise<Envelope> {
    return await this.authorizedRequest(path, undefined, jsonBody, jsonBody === undefined ? 'GET' : 'POST');
  }

  private async authorizedFields(path: string, fields: FormField[]): Promise<Envelope> {
    return await this.authorizedRequest(path, fields, undefined, 'POST');
  }

  private async authorizedUpload(path: string, file: UploadFile): Promise<Envelope> {
    const epoch = this.generation;
    if (!this.transport.upload) throw new ApiError('头像上传暂时不可用，请稍后重试');
    try {
      let session = await this.ensureSession();
      this.assertEpoch(epoch);
      let response: Envelope;
      try { response = await this.transport.upload(path, file, session); }
      catch (error) {
        this.assertEpoch(epoch);
        if (!(error instanceof ApiError) || error.status !== 401) throw error as Error;
        session = await this.ensureSession(session.accessToken);
        this.assertEpoch(epoch);
        response = await this.transport.upload(path, file, session);
      }
      this.assertEpoch(epoch);
      return response;
    } catch (error) {
      this.assertEpoch(epoch);
      if (error instanceof ApiError && error.status === 401) await this.invalidate(epoch);
      throw error as Error;
    }
  }

  async profile(): Promise<MemberProfile> {
    const epoch = this.generation;
    const response = await this.authorized('/api/v1/member/member/my');
    this.assertEpoch(epoch);
    try { return parseProfile(response.data, this.session?.memberId ?? ''); }
    catch (error) {
      if (error instanceof ApiError && error.status === 401) await this.invalidate(epoch);
      throw error as Error;
    }
  }

  async registerPushDevice(identity: PushIdentity, version: string): Promise<boolean> {
    try {
      await this.authorizedFields('/api/v1/member/push-devices', pushRegistrationFields(identity, version));
      return true;
    } catch (error) {
      if (error instanceof ApiError && (error.status === 404 || error.status === 405 || error.status === 422)) return false;
      throw error as Error;
    }
  }

  async uploadProfileImage(file: UploadFile): Promise<string> {
    if (!file.uri.trim() || file.maxBytes <= 0 || file.maxBytes > 6 * 1024 * 1024) throw new ApiError('请选择有效头像图片');
    return profileImageUrl((await this.authorizedUpload('/api/v1/file/images', file)).data);
  }

  async saveProfile(draft: ProfileDraft, headPortrait: string = ''): Promise<MemberProfile> {
    const error = profileDraftError(draft);
    if (error) throw new ApiError(error);
    const epoch = this.generation;
    const fields: FormField[] = [
      { name: 'nickname', value: draft.nickname.trim() }, { name: 'gender', value: String(draft.gender) },
      { name: 'birthday', value: draft.birthday }, { name: 'height', value: String(Number(draft.height)) },
      { name: 'weight', value: String(Number(draft.weight)) }
    ];
    if (headPortrait.trim()) fields.push({ name: 'head_portrait', value: headPortrait.trim() });
    await this.authorizedFields('/api/v1/member/member/save', fields);
    this.assertEpoch(epoch);
    const profile = await this.profile();
    this.assertEpoch(epoch);
    const mismatches = profileSaveMismatches(fields, profile);
    if (mismatches.length) throw new ApiError(`个人资料未全部保存，请核对${mismatches.join('、')}后重试`);
    return profile;
  }

  async submitFeedback(category: string, content: string, contact: string): Promise<string> {
    const error = feedbackError(category, content, contact);
    if (error) throw new ApiError(error);
    const response = await this.authorizedFields('/api/v1/member/feedback', [
      { name: 'type', value: category }, { name: 'content', value: content.trim() },
      { name: 'contact', value: contact.trim() }
    ]);
    const data = response.data as Record<string, Object>;
    const id = data && (typeof data['id'] === 'string' || typeof data['id'] === 'number') ? String(data['id']) : '';
    if (!id) throw new ApiError('反馈提交结果不完整，请稍后重试');
    return id;
  }

  async unregisterPushDevice(installationId: string): Promise<boolean> {
    const normalized = installationId.trim();
    if (!/^[A-Za-z0-9._:-]{8,160}$/.test(normalized)) throw new ApiError('推送设备标识无效');
    try {
      await this.authorizedRequest(`/api/v1/member/push-devices/${encodeURIComponent(normalized)}`,
        undefined, undefined, 'DELETE');
      return true;
    } catch (error) {
      if (error instanceof ApiError && (error.status === 404 || error.status === 405)) return false;
      throw error as Error;
    }
  }

  async notificationUnread(): Promise<number | undefined> {
    for (const path of ['/api/v1/member/notify/statistics', '/api/v1/member/notify/unread-count']) {
      try {
        const response = await this.authorized(path);
        return notificationUnreadCount(response.data);
      } catch (error) {
        if (!(error instanceof ApiError) || (error.status !== 404 && error.status !== 405)) throw error as Error;
      }
    }
    return undefined;
  }

  async shopOrders(status: number = 99): Promise<ShopOrder[]> {
    if (![99, 0, 1, 2, 3, -1].includes(status)) throw new ApiError('订单筛选无效');
    const query = status === 99 ? '' : `&synthesize_status=${status}`;
    const response = await this.authorized(`/api/inv-shop/v1/member/order/index?page=1${query}`);
    return parseShopOrders(response.data);
  }

  async shopOrder(id: number): Promise<ShopOrder> {
    if (!Number.isSafeInteger(id) || id <= 0) throw new ApiError('订单编号异常');
    const response = await this.authorized(`/api/inv-shop/v1/member/order/view?id=${id}`);
    return parseShopOrder(response.data);
  }

  async harmonyPayment(provider: PaymentProvider, order: ShopOrder): Promise<HarmonyPaymentRequest> {
    // Refresh amount and state before asking the server to sign; client display values never authorize payment.
    const current = await this.shopOrder(order.id);
    const response = await this.authorizedFields('/api/v1/pay', paymentFields(provider, current));
    return parseHarmonyPayment(provider, response.data);
  }

  async shopHome(): Promise<ShopHome> {
    const response = await this.transport.request('/api/v1/pages?code=SHOP_HOME');
    return parseShopHome(response.data);
  }

  async shopProductDetail(id: number): Promise<ProductDetail> {
    if (!Number.isSafeInteger(id) || id <= 0) throw new ApiError('商品编号无效');
    return parseProductDetail((await this.transport.request(`/api/inv-shop/v1/product/product/view?id=${id}`)).data, id);
  }

  async shopCart(): Promise<ShopLine[]> {
    return parseCart((await this.authorized('/api/inv-shop/v1/member/cart-item/index')).data);
  }

  async changeShopCart(skuId: number, quantity: number, action: 'add' | 'quantity' | 'delete'): Promise<ShopLine[]> {
    selectionFields([{ skuId, quantity }]);
    if (this.shopWriteBusy) throw new ApiError('正在更新，请稍候');
    this.shopWriteBusy = true; const epoch = this.generation;
    try {
      const suffix = action === 'add' ? 'create' : action === 'quantity' ? 'update-num' : 'delete-ids';
      const fields: FormField[] = action === 'delete' ? [{ name: 'sku_ids', value: String(skuId) }] :
        [{ name: 'sku_id', value: String(skuId) }, { name: 'num', value: String(quantity) }];
      await this.authorizedFields(`/api/inv-shop/v1/member/cart-item/${suffix}`, fields);
      this.assertEpoch(epoch);
      return await this.shopCart();
    } finally { this.shopWriteBusy = false; }
  }

  private async checkoutFields(items: ShopSelection[]): Promise<FormField[]> {
    const epoch = this.generation;
    const cart = items.length > 1 ? await this.shopCart() : [];
    this.assertEpoch(epoch); return selectionFields(items, cart);
  }

  async shopCheckout(items: ShopSelection[]): Promise<CheckoutPreview> {
    const epoch = this.generation, fields = await this.checkoutFields(items); this.assertEpoch(epoch);
    const query = fields.map((field: FormField) => `${field.name}=${encodeURIComponent(field.value)}`).join('&');
    return parseCheckout((await this.authorized(`/api/inv-shop/v1/order/order/preview?${query}`)).data);
  }

  async createCommerceOrder(items: ShopSelection[], preview: CheckoutPreview, addressId: string,
    points: string, message: string): Promise<number> {
    const validation = checkoutError(preview, addressId, points, message);
    if (validation) throw new ApiError(validation);
    if (this.shopWriteBusy) throw new ApiError('正在提交，请勿重复操作');
    this.shopWriteBusy = true; const epoch = this.generation;
    try {
      const latest = await this.shopCheckout(items); this.assertEpoch(epoch);
      if (latest.productCents !== preview.productCents || latest.shippingCents !== preview.shippingCents) {
        throw new ApiError('订单金额已变化，请返回重新确认');
      }
      const latestError = checkoutError(latest, addressId, points, message);
      if (latestError) throw new ApiError(latestError);
      const fields = await this.checkoutFields(items); this.assertEpoch(epoch);
      const body: Record<string, Object> = { merchant_id: 0, is_channel: 0, address_id: Number(addressId),
        buyer_message: message.trim(), shipping_type: 1, type: fields[0].value, data: fields[1].value,
        point: commerceCents(points) / 100 };
      const response = await this.authorized('/api/inv-shop/v1/order/order/create', JSON.stringify(body));
      const data = response.data as Record<string, Object>;
      const id = Number(data?.['id'] ?? data?.['order_id']);
      if (!Number.isSafeInteger(id) || id <= 0) throw new ApiError('提交结果待确认，请先查看我的订单，勿重复提交');
      return id;
    } finally { this.shopWriteBusy = false; }
  }

  async commerceOrder(id: number): Promise<OrderDetail> {
    if (!Number.isSafeInteger(id) || id <= 0) throw new ApiError('订单编号无效');
    return parseOrderDetail((await this.authorized(`/api/inv-shop/v1/member/order/view?id=${id}`)).data, id);
  }

  async removeCreatedCartItems(orderId: number, items: ShopSelection[]): Promise<boolean> {
    if (this.shopWriteBusy) return false;
    this.shopWriteBusy = true; const epoch = this.generation;
    try {
      const order = await this.commerceOrder(orderId); this.assertEpoch(epoch);
      // Never clear unrelated or changed cart rows, even after a successful create.
      if (!items.length || items.some((item: ShopSelection) => !order.products.some((line: ShopLine) =>
        line.skuId === item.skuId && line.quantity === item.quantity))) return false;
      const cart = await this.shopCart(); this.assertEpoch(epoch);
      let complete = true;
      for (const item of items) {
        const row = cart.find((line: ShopLine) => line.skuId === item.skuId);
        if (!row) continue;
        if (row.quantity !== item.quantity) { complete = false; continue; }
        this.assertEpoch(epoch);
        await this.authorizedFields('/api/inv-shop/v1/member/cart-item/delete-ids', [{ name: 'sku_ids', value: String(item.skuId) }]);
        this.assertEpoch(epoch);
      }
      return complete;
    } finally { this.shopWriteBusy = false; }
  }

  async shopShipments(id: number): Promise<Shipment[]> {
    if (!Number.isSafeInteger(id) || id <= 0) throw new ApiError('订单编号无效');
    return parseShipments((await this.authorized(`/api/inv-shop/v1/member/order-product-express/details?order_id=${id}`)).data);
  }

  async confirmShopReceipt(id: number): Promise<OrderDetail> {
    if (this.shopWriteBusy) throw new ApiError('正在处理，请稍候');
    this.shopWriteBusy = true; const epoch = this.generation;
    try {
      const latest = await this.commerceOrder(id); this.assertEpoch(epoch);
      if (latest.order.status !== 2) throw new ApiError('订单状态已更新，请刷新');
      await this.authorizedFields('/api/inv-shop/v1/member/order/take-delivery', [{ name: 'id', value: String(id) }]);
      this.assertEpoch(epoch); return await this.commerceOrder(id);
    } finally { this.shopWriteBusy = false; }
  }

  async applyShopRefund(orderId: number, lineId: number, type: number, amount: string, reason: string): Promise<OrderDetail> {
    const cents = commerceCents(amount);
    if (![1, 2].includes(type) || cents <= 0 || !reason.trim() || reason.trim().length > 200) throw new ApiError('请检查申请金额和售后原因');
    if (this.shopWriteBusy) throw new ApiError('正在处理，请稍候');
    this.shopWriteBusy = true; const epoch = this.generation;
    try {
      const latest = await this.commerceOrder(orderId); this.assertEpoch(epoch);
      const item = latest.products.find((value: ShopLine) => value.id === lineId);
      if (latest.order.status <= 0 || !item || item.applied || cents > latest.order.amountCents) throw new ApiError('该商品当前不可提交此售后申请，请刷新订单');
      await this.authorizedFields('/api/inv-shop/v1/member/order-product/refund-apply', [
        { name: 'id', value: String(lineId) }, { name: 'refund_type', value: String(type) },
        { name: 'refund_require_money', value: (cents / 100).toFixed(2) }, { name: 'refund_reason', value: reason.trim() }
      ]);
      this.assertEpoch(epoch); return await this.commerceOrder(orderId);
    } finally { this.shopWriteBusy = false; }
  }

  async aiMessages(): Promise<AiChatMessage[]> {
    const response = await this.authorized('/api/rf-article/chat/index?app=1&page=1');
    return parseAiMessages(response.data);
  }

  async sendAiMessage(message: string, sessionId: string = ''): Promise<AiChatMessage> {
    const normalized = message.trim();
    if (!normalized || normalized.length > 2000) throw new ApiError('请输入 1~2000 字的问题');
    const body: Record<string, Object> = { app: 1, message: normalized };
    if (sessionId) body['session_id'] = sessionId;
    const response = await this.authorized('/api/rf-article/chat/create', JSON.stringify(body));
    return parseAiReply(response.data);
  }

  async careMembers(): Promise<CareMember[]> {
    const epoch = this.generation;
    const readGeneration = ++this.careMemberReadGeneration;
    const response = await this.authorized('/api/v1/member/care/my');
    this.assertEpoch(epoch);
    if (readGeneration !== this.careMemberReadGeneration) throw new ApiError('关爱成员已刷新，请重新查看');
    const members = parseCareMembers(response.data, this.session?.memberId ?? '');
    this.careTargets.clear();
    members.forEach((member: CareMember) => this.careTargets.set(member.relationId, member.memberId));
    return members;
  }

  async careInvitations(): Promise<CareInvitation[]> {
    const epoch = this.generation;
    const response = await this.authorized('/api/v1/member/care');
    this.assertEpoch(epoch);
    return parseCareInvitations(response.data, this.session?.memberId ?? '');
  }

  async addCare(mobile: string): Promise<void> {
    const epoch = this.generation;
    const profile = await this.profile();
    this.assertEpoch(epoch);
    const validation = careMobileValidation(mobile, typeof profile.mobile === 'string' ? profile.mobile : '');
    if (validation) throw new ApiError(validation);
    await this.authorized('/api/v1/member/care', JSON.stringify({ mobile: mobile.trim() }));
    this.assertEpoch(epoch);
  }

  async respondCareInvitation(id: number, accepted: boolean): Promise<void> {
    if (!careId(id)) throw new ApiError('邀请编号无效');
    const epoch = this.generation;
    // Refresh immediately before an intentional action; stale/handled invitations are not actionable.
    const latest = await this.careInvitations();
    this.assertEpoch(epoch);
    if (!latest.some((item: CareInvitation) => item.id === id && item.state === 'pending')) {
      throw new ApiError('该邀请已处理或撤销，请刷新列表');
    }
    await this.authorized('/api/v1/member/care/save', JSON.stringify({ id: id, examine_status: accepted ? 1 : 2 }));
    this.assertEpoch(epoch);
  }

  async careShareSettings(memberId: number): Promise<CareShareSettings> {
    if (!careId(memberId)) throw new ApiError('成员身份无效');
    const epoch = this.generation;
    this.shareSnapshots.delete(memberId);
    const invites = await this.careInvitations();
    this.assertEpoch(epoch);
    if (!invites.some((item: CareInvitation) => item.inviterId === memberId && item.state === 'accepted')) {
      throw new ApiError('请先同意此成员的关爱邀请，再设置共享');
    }
    const response = await this.authorized(`/api/v1/member/care-setting/preview?type=0&to_member_id=${memberId}`);
    this.assertEpoch(epoch);
    const settings = parseCareSettings(response.data);
    this.shareSnapshots.set(memberId, { enabled: [...settings.enabled], unknown: [...settings.unknown] });
    return settings;
  }

  async saveCareShareSettings(memberId: number, enabled: string[]): Promise<void> {
    const snapshot = this.shareSnapshots.get(memberId);
    if (!snapshot) throw new ApiError('请先成功读取共享设置，再保存');
    const epoch = this.generation;
    const current = await this.careShareSettings(memberId);
    this.assertEpoch(epoch);
    if (JSON.stringify(current) !== JSON.stringify(snapshot)) {
      this.shareSnapshots.delete(memberId);
      throw new ApiError('共享设置已在其他设备更新，请重新读取后再修改');
    }
    const body = careSettingsBody(memberId, { enabled: enabled, unknown: snapshot.unknown });
    await this.authorized('/api/v1/member/care-setting', body);
    this.assertEpoch(epoch);
    this.shareSnapshots.delete(memberId);
  }

  async careMetric(relationId: number, memberId: number, key: string, day: string): Promise<CareMetric> {
    const epoch = this.generation;
    if (this.careTargets.get(relationId) !== memberId) throw new ApiError('成员关系已变化，请返回列表重新读取');
    const spec = CARE_METRICS.find((item: CareMetricSpec) => item.key === key);
    if (!spec) throw new ApiError('不支持此健康项目');
    const query = `selectmember=${memberId}&date=${chinaDaySeconds(day)}`;
    try {
      const response = await this.authorized(`${spec.endpoint}?${query}${spec.type ? `&type=${spec.type}` : ''}`);
      this.assertEpoch(epoch);
      // Only the selected metric endpoint is authoritative, including an empty response.
      return parseCareMetric(spec, response.data, day);
    } catch (error) {
      this.assertEpoch(epoch);
      if (error instanceof ApiError && error.status === 401) throw error;
      if (error instanceof ApiError && error.status === 403) return careMetricState(spec, 'unauthorized', '对方尚未授权此项目');
      if (error instanceof ApiError && error.status === 0) return careMetricState(spec, 'unavailable', error.message);
      return careMetricState(spec, 'unavailable', '该项服务暂不可用，请稍后重试');
    }
  }

  async careMetrics(relationId: number, memberId: number, day: string): Promise<CareMetric[]> {
    const epoch = this.generation;
    if (this.careTargets.get(relationId) !== memberId) throw new ApiError('成员关系已变化，请返回列表重新读取');
    const metrics: CareMetric[] = [];
    for (let index = 0; index < CARE_METRICS.length; index += 3) {
      const batch = await Promise.all(CARE_METRICS.slice(index, index + 3).map((spec: CareMetricSpec) =>
        this.careMetric(relationId, memberId, spec.key, day)));
      this.assertEpoch(epoch);
      metrics.push(...batch);
    }
    return metrics;
  }

  async articles(): Promise<Article[]> {
    return parseArticles((await this.transport.request('/api/rf-article/article/index')).data);
  }

  async articleCategories(): Promise<ArticleCategory[]> {
    return parseArticleCategories((await this.transport.request('/api/rf-article/article-cate/index?pid=3')).data);
  }

  async articlesByCategory(categoryId: number): Promise<Article[]> {
    if (!Number.isSafeInteger(categoryId) || categoryId < 0) throw new ApiError('健康分类无效');
    return parseArticles((await this.transport.request(`/api/rf-article/article/index?page=1${categoryId ? '&cate_id=' + categoryId : ''}`)).data);
  }

  async article(id: string, agreement: boolean): Promise<Article> {
    if (!/^\d+$/.test(id)) throw new ApiError('内容编号不正确');
    const path = agreement ? '/api/rf-article/article-single/view' : '/api/rf-article/article/view';
    return parseArticle((await this.transport.request(`${path}?id=${encodeURIComponent(id)}`)).data);
  }
}
