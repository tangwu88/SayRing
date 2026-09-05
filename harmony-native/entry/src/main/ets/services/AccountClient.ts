import {
  ApiError, parseSession,
  validateStoredSession, parseProfile, parseArticles, parseArticle, loginValidation
} from '../model/Contracts';
import type { Envelope, Session, FormField, MemberProfile, Article } from '../model/Contracts';
import { CARE_METRICS, careId, careMobileValidation, parseCareMembers, parseCareInvitations,
  parseCareSettings, careSettingsBody, chinaDaySeconds, parseCareMetric, careMetricState } from '../model/CareContracts';
import type { CareMember, CareInvitation, CareShareSettings, CareMetric, CareMetricSpec } from '../model/CareContracts';
import { notificationUnreadCount, parseHarmonyPayment, parseShopOrder, parseShopOrders,
  paymentFields, pushRegistrationFields } from '../model/PushPaymentContracts';
import type { HarmonyPaymentRequest, PaymentProvider, PushIdentity, ShopOrder } from '../model/PushPaymentContracts';
import { parseAiMessages, parseAiReply, parseShopHome } from '../model/ExperienceContracts';
import type { AiChatMessage, ShopHome } from '../model/ExperienceContracts';

export interface SessionStore {
  read(): Promise<Session | undefined>;
  write(session: Session): Promise<void>;
  clear(): Promise<void>;
}
export interface ApiTransport {
  request(path: string, fields?: FormField[], session?: Session, jsonBody?: string,
    method?: 'GET' | 'POST' | 'DELETE'): Promise<Envelope>;
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
  private shareSnapshots: Map<number, CareShareSettings> = new Map();

  private clearCare(): void { this.careTargets.clear(); this.shareSnapshots.clear(); }

  constructor(transport: ApiTransport, vault: SessionStore, now: () => number = () => Date.now()) {
    this.transport = transport;
    this.vault = vault;
    this.now = now;
  }

  current(): Session | undefined { return this.session ? validateStoredSession(this.session) : undefined; }
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
  }

  async login(account: string, password: string): Promise<Session> {
    const validation = loginValidation(account, password, true);
    if (validation) throw new ApiError(validation);
    const epoch = ++this.generation;
    this.session = undefined;
    this.blockRestore = true;
    this.refreshing = undefined;
    this.clearCare();
    // A failed account switch must not revive the previous account on a later restore.
    await this.clearVault();
    this.assertEpoch(epoch);
    const payload = await this.transport.request('/api/v1/site/login', [
      { name: 'username', value: account.trim() }, { name: 'password', value: password },
      { name: 'group', value: 'app' }
    ]);
    const session = parseSession(payload, this.now());
    await this.persist(session, epoch);
    this.blockRestore = false;
    return validateStoredSession(session);
  }

  async logout(): Promise<void> {
    ++this.generation;
    this.session = undefined;
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
    method?: 'GET' | 'POST' | 'DELETE'): Promise<Envelope> {
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

  async shopOrders(): Promise<ShopOrder[]> {
    const response = await this.authorized('/api/inv-shop/v1/member/order/index?page=1');
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
    const response = await this.authorized('/api/v1/member/care/my');
    this.assertEpoch(epoch);
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
    let typedError: ApiError | undefined = undefined;
    try {
      const response = await this.authorized(`${spec.endpoint}?${query}${spec.type ? `&type=${spec.type}` : ''}`);
      this.assertEpoch(epoch);
      const result = parseCareMetric(spec, response.data, day);
      if (result.state === 'ready' || !spec.type) return result;
    } catch (error) {
      this.assertEpoch(epoch);
      if (error instanceof ApiError && error.status === 401) throw error;
      typedError = error instanceof ApiError ? error : new ApiError('成员数据读取失败');
      if (typedError.status === 403) return careMetricState(spec, 'unauthorized', '对方尚未授权此项目');
      if (!spec.type || typedError.status === 0) return careMetricState(spec, 'unavailable', typedError.message);
    }
    // Confirmed legacy fallback: same member/date and only the selected metric's whitelisted fields.
    // A 403 is never bypassed using another endpoint.
    try {
      const response = await this.authorized(`${spec.endpoint}?${query}`);
      this.assertEpoch(epoch);
      return parseCareMetric(spec, response.data, day, false);
    } catch (error) {
      this.assertEpoch(epoch);
      if (error instanceof ApiError && error.status === 401) throw error;
      if (error instanceof ApiError && error.status === 403) return careMetricState(spec, 'unauthorized', '对方尚未授权此项目');
      return careMetricState(spec, 'unavailable', '该项服务暂不可用，请稍后重试');
    }
  }

  async articles(): Promise<Article[]> {
    return parseArticles((await this.transport.request('/api/rf-article/article/index')).data);
  }

  async article(id: string, agreement: boolean): Promise<Article> {
    if (!/^\d+$/.test(id)) throw new ApiError('内容编号不正确');
    const path = agreement ? '/api/rf-article/article-single/view' : '/api/rf-article/article/view';
    return parseArticle((await this.transport.request(`${path}?id=${encodeURIComponent(id)}`)).data);
  }
}
