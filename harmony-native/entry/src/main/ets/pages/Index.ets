import { ApiError, MemberProfile, Article, ArticleBlock, loginValidation, canSubmitLogin, profileName, profileField, articleBlocks } from '../model/Contracts';
import { saydianApi } from '../services/SaydianApi';
import { ArticleImage } from '../components/ArticleImage';
import { CareMember, CareInvitation, CareShareSettings, CareMetric, CareMetricSpec, CareRecord, CareOption,
  CARE_OPTIONS, CARE_METRICS, chinaDay, chinaDaySeconds, shiftChinaDay, careMetricLatest, careRecordText } from '../model/CareContracts';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { pushErrorMessage, paymentErrorMessage } from '../model/PushPaymentContracts';
import type { PaymentProvider, ShopOrder } from '../model/PushPaymentContracts';
import { harmonyPush } from '../services/HarmonyPushService';
import { PENDING_NOTIFICATION_ROUTE } from '../services/NotificationNavigation';
import {
  HealthRecord, MeasurementState, WearableConnectionPhase, WearableDevice, WearableDial, WearableMetricKey,
  WearableSnapshot, batteryText, emptyMeasurement, emptyWearableSnapshot, healthRecordText,
  latestMetricRecord, wearableIdentifierText
} from '../model/WearableContracts';
import { vepWearable, WearableServiceListener } from '../services/VepWearableService';
import { AiChatMessage, AppUpdateInfo, ShopCategory, ShopHome, ShopProduct } from '../model/ExperienceContracts';
import { appUpdateService, HARMONY_VERSION_CODE, HARMONY_VERSION_NAME } from '../services/AppUpdateService';

const RED: string = '#D7082E';
const INK: string = '#1C1D29';
const MUTED: string = '#747783';
const BG: string = '#F6F7FB';

interface NoticeOptions { message: string; color?: string; }
interface WearableMetricSpec { key: WearableMetricKey; title: string; }

@Entry
@Component
struct Index {
  @StorageLink(PENDING_NOTIFICATION_ROUTE)
  @Watch('pendingNotificationChanged')
  private pendingNotificationRoute: string = '';
  @State private screen: string = 'login';
  @State private tab: number = 0;
  @State private account: string = '';
  @State private password: string = '';
  @State private accepted: boolean = false;
  @State private busy: boolean = false;
  @State private restoring: boolean = true;
  @State private error: string = '';
  @State private profileError: string = '';
  @State private profileLoading: boolean = false;
  @State private profileUpdatedAt: string = '';
  @State private logoutFailed: boolean = false;
  @State private profile: MemberProfile = {};
  @State private displayName: string = '';
  @State private guest: boolean = true;
  @State private articleTitle: string = '';
  @State private articleContent: ArticleBlock[] = [];
  @State private articleLoading: boolean = false;
  @State private articleError: string = '';
  @State private articles: Article[] = [];
  @State private listLoading: boolean = false;
  @State private listError: string = '';
  @State private detailTitle: string = '';
  @State private detailBody: string = '';
  @State private careMembers: CareMember[] = [];
  @State private careInvitations: CareInvitation[] = [];
  @State private careLoading: boolean = false;
  @State private careBusy: boolean = false;
  @State private careMemberError: string = '';
  @State private careInvitationError: string = '';
  @State private careMessage: string = '';
  @State private careMobile: string = '';
  @State private careSelectedMember: CareMember = { relationId: 0, memberId: 0, name: '', mobile: '' };
  @State private careSelectedInviter: CareInvitation = { id: 0, inviterId: 0, name: '', mobile: '', state: '' };
  @State private careSettings: CareShareSettings = { enabled: [], unknown: [] };
  @State private careSettingsReady: boolean = false;
  @State private careDay: string = chinaDay();
  @State private careDateInput: string = chinaDay();
  @State private careMetricKey: string = 'heart';
  @State private careMetricData: CareMetric = { key: 'heart', title: '心率', unit: '', state: 'empty', message: '', records: [] };
  @State private careRecordLimit: number = 30;
  @State private notificationCount: number = -1;
  @State private pushBusy: boolean = false;
  @State private pushStatus: string = '尚未检查鸿蒙推送';
  @State private orders: ShopOrder[] = [];
  @State private orderLoading: boolean = false;
  @State private paymentBusy: boolean = false;
  @State private paymentMessage: string = '';
  @State private selectedOrder: ShopOrder = { id: 0, number: '', amountCents: 0, status: 0, summary: '' };
  @State private selectedProvider: PaymentProvider = 'wechat';
  @State private wearableDevices: WearableDevice[] = [];
  @State private wearablePhase: WearableConnectionPhase = 'idle';
  @State private wearableMessage: string = '尚未连接手表';
  @State private wearableSnapshot: WearableSnapshot = emptyWearableSnapshot();
  @State private wearableMeasurement: MeasurementState = emptyMeasurement();
  @State private selectedWearableMetric: WearableMetricKey = 'heart';
  @State private aiMessages: AiChatMessage[] = [];
  @State private aiInput: string = '';
  @State private aiSessionId: string = '';
  @State private aiBusy: boolean = false;
  @State private aiError: string = '';
  @State private shopHome: ShopHome = { bannerUrl: '', categories: [] };
  @State private shopCategoryIndex: number = 0;
  @State private shopLoading: boolean = false;
  @State private shopError: string = '';
  @State private selectedProduct: ShopProduct = { id: 0, name: '', picture: '', price: '0.00', stock: 0 };
  @State private updateBusy: boolean = false;
  @State private updateStatus: string = '点击检查是否有新版本';
  @State private updateInfo: AppUpdateInfo = { latestVersion: '', latestBuild: 0,
    minimumSupportedBuild: 0, releaseNotes: '', destinationUrl: '', hasUpdate: false, required: false };
  private careGeneration: number = 0;
  private previousScreen: string = 'login';
  private pageGeneration: number = 0;
  private contentGeneration: number = 0;
  private selectedArticleId: string = '';
  private selectedAgreement: boolean = false;
  private readonly wearableMetrics: WearableMetricSpec[] = [
    { key: 'activity', title: '活动' }, { key: 'sleep', title: '睡眠' },
    { key: 'heart', title: '心率' }, { key: 'pressure', title: '血压' },
    { key: 'oxygen', title: '血氧' }, { key: 'glucose', title: '血糖' },
    { key: 'temperature', title: '体温' }, { key: 'hrv', title: 'HRV' },
    { key: 'ecg', title: '心电' }, { key: 'bodyComposition', title: '身体成分' },
    { key: 'bloodComponents', title: '血液成分' }, { key: 'sport', title: '运动记录' }
  ];
  private readonly measurementMetrics: WearableMetricSpec[] = [
    { key: 'heart', title: '心率' }, { key: 'pressure', title: '血压' },
    { key: 'oxygen', title: '血氧' }, { key: 'glucose', title: '血糖' },
    { key: 'temperature', title: '体温' }, { key: 'ecg', title: '心电' },
    { key: 'bodyComposition', title: '身体成分' }, { key: 'bloodComponents', title: '血液成分' }
  ];

  aboutToAppear(): void {
    this.bindWearable();
    this.restoreLogin();
  }
  onPageShow(): void { this.consumeNotificationRoute(); }
  aboutToDisappear(): void {
    ++this.pageGeneration; ++this.contentGeneration; ++this.careGeneration;
    vepWearable.clearListener();
  }

  private pendingNotificationChanged(): void { this.consumeNotificationRoute(); }

  private clearCareState(): void {
    ++this.careGeneration;
    this.careMembers = []; this.careInvitations = []; this.careMobile = '';
    this.careSettings = { enabled: [], unknown: [] }; this.careSettingsReady = false;
    this.careMetricData = { key: 'heart', title: '心率', unit: '', state: 'empty', message: '', records: [] };
    this.careMessage = ''; this.careMemberError = ''; this.careInvitationError = '';
    this.careSelectedMember = { relationId: 0, memberId: 0, name: '', mobile: '' };
    this.careSelectedInviter = { id: 0, inviterId: 0, name: '', mobile: '', state: '' };
    this.careLoading = false; this.careBusy = false;
  }

  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private bindWearable(): void {
    vepWearable.attachContext(this.uiContext());
    const listener: WearableServiceListener = {
      onDevices: (devices: WearableDevice[]) => this.wearableDevices = devices,
      onPhase: (phase: WearableConnectionPhase, message: string) => {
        this.wearablePhase = phase;
        this.wearableMessage = message;
      },
      onSnapshot: (snapshot: WearableSnapshot) => this.wearableSnapshot = snapshot,
      onMeasurement: (measurement: MeasurementState) => this.wearableMeasurement = measurement
    };
    vepWearable.setListener(listener);
  }

  private wearableBusy(): boolean {
    return this.wearablePhase === 'connecting' || this.wearablePhase === 'authenticating' ||
      this.wearablePhase === 'syncing' || this.wearablePhase === 'disconnecting';
  }

  private wearableCapability(metric: WearableMetricKey): boolean {
    const capabilities = this.wearableSnapshot.capabilities;
    if (metric === 'activity') return capabilities.activity;
    if (metric === 'sleep') return capabilities.sleep;
    if (metric === 'heart') return capabilities.heart;
    if (metric === 'pressure') return capabilities.pressure;
    if (metric === 'oxygen') return capabilities.oxygen;
    if (metric === 'temperature') return capabilities.temperature;
    if (metric === 'glucose') return capabilities.glucose;
    if (metric === 'hrv') return capabilities.hrv;
    if (metric === 'ecg') return capabilities.ecg;
    if (metric === 'bodyComposition') return capabilities.bodyComposition;
    if (metric === 'bloodComponents') return capabilities.bloodComponents;
    return capabilities.sport;
  }

  private wearableMetricMeasurable(metric: WearableMetricKey): boolean {
    return this.measurementMetrics.some((item: WearableMetricSpec) => item.key === metric);
  }

  private wearableMetricRecords(metric: WearableMetricKey): HealthRecord[] {
    return this.wearableSnapshot.records.filter((record: HealthRecord) => record.metric === metric)
      .sort((a: HealthRecord, b: HealthRecord) => b.timestamp - a.timestamp);
  }

  private wearableLatest(metric: WearableMetricKey): string {
    if (!this.wearableSnapshot.connected) return '暂无记录';
    if (!this.wearableCapability(metric)) return '设备不支持';
    return healthRecordText(latestMetricRecord(this.wearableSnapshot.records, metric));
  }

  private wearableMetricTitle(metric: WearableMetricKey): string {
    const found = this.wearableMetrics.find((item: WearableMetricSpec) => item.key === metric);
    return found?.title ?? '健康数据';
  }

  private openWearableMetric(metric: WearableMetricKey): void {
    this.selectedWearableMetric = metric;
    this.previousScreen = 'home';
    this.screen = 'wearable-metric';
  }

  private wearableRecordTime(timestamp: number): string {
    if (!Number.isFinite(timestamp) || timestamp <= 0) return '时间未知';
    const date = new Date(timestamp);
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private wearableSyncTime(): string {
    return this.wearableSnapshot.syncedAt > 0 ? `最近同步 ${this.wearableRecordTime(this.wearableSnapshot.syncedAt)}` : '尚未同步健康数据';
  }

  private signalText(rssi: number): string {
    if (rssi === 0) return '已连接';
    if (rssi >= -60) return `强 ${rssi}`;
    if (rssi >= -80) return `中 ${rssi}`;
    return `弱 ${rssi}`;
  }

  private measurementText(): string {
    if (this.wearableMeasurement.values.length === 0) return this.wearableMeasurement.status || '等待手表读数';
    return this.wearableMeasurement.values.map((value) =>
      `${value.name} ${value.value}${value.unit}`).join(' · ');
  }

  private ecgWaveformPoints(): number[][] {
    const samples = this.wearableMeasurement.samples.slice(-240);
    if (samples.length < 2) return [];
    let min = samples[0];
    let max = samples[0];
    samples.forEach((value: number) => { min = Math.min(min, value); max = Math.max(max, value); });
    const range = Math.max(1, max - min);
    return samples.map((value: number, index: number) =>
      [Math.round(index * 320 / Math.max(1, samples.length - 1)), Math.round(112 - ((value - min) / range) * 104)]);
  }

  private businessErrorCode(error: Error): number {
    const code = (error as BusinessError).code;
    if (typeof code === 'number') return code;
    const match = error.message.match(/\b(?:code\D*)?(\d{3,10})\b/i);
    return match ? Number(match[1]) : 0;
  }

  private async refreshNotificationCount(): Promise<void> {
    if (this.guest) { this.notificationCount = -1; return; }
    try {
      const count = await saydianApi.notificationUnread();
      this.notificationCount = count === undefined ? -1 : count;
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) this.careFailure(error as Error);
      this.notificationCount = -1;
    }
  }

  private async connectPush(requestPermission: boolean): Promise<void> {
    if (this.pushBusy) return;
    if (this.guest) { this.pushStatus = '请先登录赛电账号，再开启消息推送'; return; }
    this.pushBusy = true;
    this.pushStatus = '正在检查系统通知与推送身份…';
    try {
      let enabled = await harmonyPush.notificationEnabled();
      if (!enabled && requestPermission) {
        await harmonyPush.requestNotificationPermission(this.uiContext());
        enabled = await harmonyPush.notificationEnabled();
      }
      if (!enabled) { this.pushStatus = '系统通知未开启；应用内消息仍可手动刷新'; return; }
      const identity = await harmonyPush.getIdentity(this.uiContext());
      const registered = await saydianApi.registerPushDevice(identity, '0.1.3+4');
      this.pushStatus = registered ? '鸿蒙推送标识已登记，可接收服务端通知' :
        '客户端已取得推送标识，但服务端尚未接受 harmony 平台登记';
    } catch (error) {
      this.pushStatus = error instanceof ApiError ? error.message : pushErrorMessage(this.businessErrorCode(error as Error));
    } finally { this.pushBusy = false; }
  }

  private async releasePushBeforeLogout(): Promise<void> {
    const identity = harmonyPush.currentIdentity();
    if (identity) {
      try { await saydianApi.unregisterPushDevice(identity.installationId); } catch {}
    }
    try { await harmonyPush.clearToken(); } catch {}
    this.notificationCount = -1;
    this.pushStatus = '已退出账号，推送标识已从本机清除';
  }

  private async openMessages(): Promise<void> {
    if (this.guest) { this.showFeature('消息', '请先登录赛电账号，再查看关爱邀请和健康预警。'); return; }
    this.screen = 'messages';
    await this.refreshNotificationCount();
    await this.connectPush(false);
  }

  private async consumeNotificationRoute(): Promise<void> {
    const route = this.pendingNotificationRoute;
    if (!route || this.guest || this.restoring) return;
    this.pendingNotificationRoute = '';
    if (route === 'care-invitations') {
      await this.openCare();
      if (!this.guest) this.screen = 'care-invitations';
    } else if (route === 'health-alerts') {
      this.openHealthAlerts();
    }
  }

  private async openOrders(): Promise<void> {
    if (this.guest) { this.showFeature('商城订单', '请先登录赛电账号，再查看订单与支付状态。'); return; }
    this.screen = 'shop-orders'; this.orderLoading = true; this.paymentMessage = ''; this.orders = [];
    try { this.orders = await saydianApi.shopOrders(); }
    catch (error) { this.paymentMessage = (error as Error).message || '订单暂时无法加载'; }
    finally { this.orderLoading = false; }
  }

  private openHealthAlerts(): void {
    this.previousScreen = 'home';
    this.screen = 'health-alerts';
    this.refreshNotificationCount();
  }

  private async openShop(): Promise<void> {
    this.previousScreen = 'home';
    this.screen = 'shop-home';
    this.shopLoading = true; this.shopError = ''; this.shopHome = { bannerUrl: '', categories: [] };
    try {
      this.shopHome = await saydianApi.shopHome();
      this.shopCategoryIndex = 0;
    } catch (error) { this.shopError = (error as Error).message || '商城暂时无法加载'; }
    finally { this.shopLoading = false; }
  }

  private shopCategory(): ShopCategory {
    if (this.shopHome.categories.length === 0) return { id: '', name: '', products: [] };
    const index = Math.max(0, Math.min(this.shopCategoryIndex, this.shopHome.categories.length - 1));
    return this.shopHome.categories[index];
  }

  private openShopProduct(product: ShopProduct): void {
    this.selectedProduct = product;
    this.screen = 'shop-product';
  }

  private async openAiChat(): Promise<void> {
    if (this.guest) { this.showFeature('AI 健康管家', '请先登录赛电账号，再向 AI 健康管家提问。'); return; }
    this.previousScreen = 'home'; this.screen = 'ai-chat'; this.aiBusy = true; this.aiError = '';
    try {
      this.aiMessages = await saydianApi.aiMessages();
      const withSession = this.aiMessages.find((item: AiChatMessage) => item.sessionId.length > 0);
      this.aiSessionId = withSession?.sessionId ?? '';
    } catch (error) { this.aiError = this.careFailure(error as Error); }
    finally { this.aiBusy = false; }
  }

  private async sendAiChat(): Promise<void> {
    const message = this.aiInput.trim();
    if (this.aiBusy || !message) return;
    this.aiBusy = true; this.aiError = '';
    const pending: AiChatMessage = { id: `local-${Date.now()}`, text: message, mine: true,
      sessionId: this.aiSessionId, failed: false };
    this.aiMessages = [...this.aiMessages, pending];
    try {
      const reply = await saydianApi.sendAiMessage(message, this.aiSessionId);
      if (reply.sessionId) this.aiSessionId = reply.sessionId;
      this.aiMessages = [...this.aiMessages, reply];
      this.aiInput = '';
    } catch (error) {
      pending.failed = true;
      this.aiMessages = this.aiMessages.map((item: AiChatMessage) => item.id === pending.id ? pending : item);
      this.aiError = this.careFailure(error as Error);
    } finally { this.aiBusy = false; }
  }

  private async checkOnlineUpdate(): Promise<void> {
    if (this.updateBusy) return;
    this.updateBusy = true; this.updateStatus = '正在检查更新…';
    try {
      this.updateInfo = await appUpdateService.check();
      this.updateStatus = this.updateInfo.hasUpdate ?
        `发现新版本 V${this.updateInfo.latestVersion}${this.updateInfo.required ? '，需要更新后继续使用' : ''}` :
        `当前已是最新版本 V${HARMONY_VERSION_NAME}`;
    } catch (error) { this.updateStatus = (error as Error).message || '暂时无法检查更新'; }
    finally { this.updateBusy = false; }
  }

  private async openUpdateDestination(): Promise<void> {
    if (!this.updateInfo.hasUpdate || !this.updateInfo.destinationUrl) return;
    try {
      await this.uiContext().startAbility({ action: 'ohos.want.action.viewData', uri: this.updateInfo.destinationUrl });
    } catch { this.updateStatus = '无法打开华为应用市场，请稍后重试'; }
  }

  private openPayment(order: ShopOrder): void {
    if (order.status !== 0) { this.paymentMessage = '订单状态已更新，无需重复支付'; return; }
    this.selectedOrder = order; this.selectedProvider = 'wechat'; this.paymentMessage = '';
    this.screen = 'shop-payment';
  }

  private async startPayment(): Promise<void> {
    if (this.paymentBusy || this.selectedOrder.id <= 0) return;
    if (!canIUse('SystemCapability.Payment.ThirdPaymentService')) {
      this.paymentMessage = '当前设备未安装或不支持鸿蒙三方支付服务';
      return;
    }
    this.paymentBusy = true; this.paymentMessage = '正在向服务端核对订单并获取签名参数…';
    try {
      const request = await saydianApi.harmonyPayment(this.selectedProvider, this.selectedOrder);
      const paymentModule = await import('../services/HarmonyPaymentService');
      await paymentModule.harmonyPayment.start(this.uiContext(), request);
      const latest = await saydianApi.shopOrder(this.selectedOrder.id);
      this.selectedOrder = latest;
      this.paymentMessage = latest.status === 0 ? '支付客户端已返回，订单仍待支付；请稍后刷新核对' :
        '服务端订单状态已更新';
    } catch (error) {
      if (error instanceof ApiError) this.paymentMessage = error.message;
      else this.paymentMessage = paymentErrorMessage(this.businessErrorCode(error as Error));
    } finally { this.paymentBusy = false; }
  }

  private money(cents: number): string {
    return `¥${(cents / 100).toFixed(2)}`;
  }

  private orderStatus(status: number): string {
    if (status === 0) return '待支付';
    if (status === 1) return '已支付';
    if (status === 2) return '已发货';
    if (status === 3) return '已完成';
    if (status === -1 || status === 4) return '已取消';
    return `状态 ${status}`;
  }

  private careFailure(error: Error): string {
    if (error instanceof ApiError && error.status === 401) {
      ++this.pageGeneration;
      this.clearCareState(); this.profile = {}; this.displayName = ''; this.profileUpdatedAt = '';
      this.profileLoading = false; this.profileError = ''; this.busy = false; this.restoring = false;
      this.guest = true; this.password = ''; this.accepted = false;
      this.error = '登录已失效，请重新登录'; this.screen = 'login';
      return this.error;
    }
    return error instanceof ApiError && (error.status === 404 || error.status === 405) ?
      '关爱服务暂不可用，请稍后重试' : error.message || '读取失败，请稍后重试';
  }

  private async openCare(): Promise<void> {
    if (this.guest) { this.showFeature('远程关爱', '请先登录赛电账号，再查看成员与共享授权。'); return; }
    this.screen = 'care';
    await this.refreshCare();
  }

  private async refreshCare(): Promise<void> {
    if (this.careBusy) return;
    const epoch = ++this.careGeneration;
    this.careLoading = true; this.careMembers = []; this.careInvitations = [];
    this.careMemberError = ''; this.careInvitationError = '';
    await Promise.all([this.readCareMembers(epoch), this.readCareInvitations(epoch)]);
    if (epoch === this.careGeneration) this.careLoading = false;
  }

  private async readCareMembers(epoch: number): Promise<void> {
    try {
      const members = await saydianApi.careMembers();
      if (epoch === this.careGeneration) this.careMembers = members;
    } catch (error) { if (epoch === this.careGeneration) this.careMemberError = this.careFailure(error as Error); }
  }

  private async readCareInvitations(epoch: number): Promise<void> {
    try {
      const invitations = await saydianApi.careInvitations();
      if (epoch === this.careGeneration) this.careInvitations = invitations;
    } catch (error) { if (epoch === this.careGeneration) this.careInvitationError = this.careFailure(error as Error); }
  }

  private pendingInvitations(): CareInvitation[] { return this.careInvitations.filter((item: CareInvitation) => item.state === 'pending'); }
  private sharingTargets(): CareInvitation[] {
    const seen: Set<number> = new Set();
    return this.careInvitations.filter((item: CareInvitation) => {
      if (item.state !== 'accepted' || seen.has(item.inviterId)) return false;
      seen.add(item.inviterId); return true;
    });
  }

  private async sendCareInvitation(): Promise<void> {
    if (this.careBusy) return;
    const epoch = this.careGeneration;
    this.careBusy = true; this.careMessage = '';
    try {
      await saydianApi.addCare(this.careMobile);
      if (epoch !== this.careGeneration) return;
      this.careMobile = ''; this.careMessage = '邀请已提交，请等待对方同意并选择共享项目。';
    } catch (error) { if (epoch === this.careGeneration) this.careMessage = this.careFailure(error as Error); }
    finally { if (epoch === this.careGeneration) this.careBusy = false; }
  }

  private async respondInvitation(id: number, accepted: boolean): Promise<void> {
    if (this.careBusy) return;
    const epoch = this.careGeneration;
    this.careBusy = true; this.careMessage = '';
    try {
      await saydianApi.respondCareInvitation(id, accepted);
      if (epoch !== this.careGeneration) return;
      this.careMessage = accepted ? '已同意邀请。请到共享管理选择允许对方查看的项目。' : '已拒绝邀请。';
      this.careInvitations = [];
      await this.readCareInvitations(epoch);
    } catch (error) {
      if (epoch === this.careGeneration) {
        this.careMessage = this.careFailure(error as Error);
        if (epoch === this.careGeneration) {
          this.careInvitations = [];
          await this.readCareInvitations(epoch);
        }
      }
    }
    finally { if (epoch === this.careGeneration) this.careBusy = false; }
  }

  private async openCareSettings(inviter: CareInvitation): Promise<void> {
    this.careSelectedInviter = inviter; this.screen = 'care-settings';
    this.careSettings = { enabled: [], unknown: [] }; this.careSettingsReady = false;
    this.careLoading = true; this.careMessage = '';
    const epoch = ++this.careGeneration;
    try {
      const settings = await saydianApi.careShareSettings(inviter.inviterId);
      if (epoch !== this.careGeneration) return;
      this.careSettings = settings; this.careSettingsReady = true;
    } catch (error) { if (epoch === this.careGeneration) this.careMessage = this.careFailure(error as Error); }
    finally { if (epoch === this.careGeneration) this.careLoading = false; }
  }

  private toggleCareSetting(key: string, enabled: boolean): void {
    if (!this.careSettingsReady || this.careBusy) return;
    const keys = this.careSettings.enabled.filter((item: string) => item !== key);
    if (enabled) keys.push(key);
    this.careSettings = { enabled: keys, unknown: this.careSettings.unknown };
  }

  private async saveCareSettings(): Promise<void> {
    if (this.careBusy || !this.careSettingsReady) return;
    const epoch = this.careGeneration;
    let submitted: boolean = false;
    this.careBusy = true; this.careMessage = '';
    try {
      await saydianApi.saveCareShareSettings(this.careSelectedInviter.inviterId, this.careSettings.enabled);
      if (epoch !== this.careGeneration) return;
      submitted = true;
      this.careSettingsReady = false;
      const verifiedSettings = await saydianApi.careShareSettings(this.careSelectedInviter.inviterId);
      if (epoch !== this.careGeneration) return;
      this.careSettings = verifiedSettings;
      this.careSettingsReady = true; this.careMessage = '已保存并重新读取共享设置。';
    } catch (error) {
      if (epoch === this.careGeneration) {
        this.careSettingsReady = false;
        const message = this.careFailure(error as Error);
        this.careMessage = submitted ? `保存请求已完成，但重新读取失败。请重新读取后确认。${message}` : message;
      }
    }
    finally { if (epoch === this.careGeneration) this.careBusy = false; }
  }

  private async openCareMember(member: CareMember): Promise<void> {
    this.careSelectedMember = member; this.careMetricKey = 'heart';
    this.careDay = chinaDay(); this.careDateInput = this.careDay;
    this.screen = 'care-member'; await this.loadCareMetric();
  }

  private async loadCareMetric(): Promise<void> {
    const epoch = ++this.careGeneration;
    this.careLoading = true; this.careMessage = ''; this.careRecordLimit = 30;
    this.careMetricData = { key: this.careMetricKey, title: '', unit: '', state: 'empty', message: '', records: [] };
    try {
      chinaDaySeconds(this.careDateInput);
      if (this.careDateInput > chinaDay()) throw new ApiError('不能查看未来日期');
      this.careDay = this.careDateInput;
      const result = await saydianApi.careMetric(this.careSelectedMember.relationId,
        this.careSelectedMember.memberId, this.careMetricKey, this.careDay);
      if (epoch === this.careGeneration) this.careMetricData = result;
    } catch (error) { if (epoch === this.careGeneration) this.careMessage = this.careFailure(error as Error); }
    finally { if (epoch === this.careGeneration) this.careLoading = false; }
  }

  private async restoreLogin(): Promise<void> {
    const epoch = this.pageGeneration;
    try {
      const session = await saydianApi.restore();
      if (epoch !== this.pageGeneration) return;
      if (session) {
        this.guest = false;
        this.displayName = session.displayName;
        this.screen = 'home';
        this.refreshProfile();
      }
    } catch (error) {
      if (epoch === this.pageGeneration) this.error = (error as Error).message;
    } finally {
      if (epoch === this.pageGeneration) {
        this.restoring = false;
        if (!this.guest) {
          this.refreshNotificationCount();
          this.connectPush(false);
          this.consumeNotificationRoute();
        }
      }
    }
  }

  private async submitLogin(): Promise<void> {
    if (!canSubmitLogin(this.busy, this.restoring)) return;
    this.error = loginValidation(this.account, this.password, this.accepted);
    if (this.error) return;
    this.busy = true;
    const epoch = ++this.pageGeneration;
    try {
      const session = await saydianApi.login(this.account, this.password);
      if (epoch !== this.pageGeneration) return;
      this.password = '';
      this.clearCareState();
      this.profile = {};
      this.profileError = '';
      this.logoutFailed = false;
      this.displayName = session.displayName;
      this.guest = false;
      this.tab = 0;
      this.screen = 'home';
      this.refreshProfile();
    } catch (error) {
      if (epoch === this.pageGeneration) this.error = (error as Error).message;
    } finally {
      if (epoch === this.pageGeneration) {
        this.busy = false;
        if (!this.guest) {
          this.refreshNotificationCount();
          this.connectPush(false);
          this.consumeNotificationRoute();
        }
      }
    }
  }

  private async refreshProfile(): Promise<void> {
    if (this.guest || this.profileLoading) return;
    const epoch = this.pageGeneration;
    this.profileLoading = true;
    this.profileError = '';
    try {
      const member = await saydianApi.profile();
      if (epoch !== this.pageGeneration) return;
      this.profile = member;
      this.displayName = profileName(member) || this.displayName;
      const updated = new Date();
      this.profileUpdatedAt = `${updated.getHours().toString().padStart(2, '0')}:${updated.getMinutes().toString().padStart(2, '0')}`;
    } catch (error) {
      if (epoch !== this.pageGeneration) return;
      this.profileError = (error as Error).message;
      if (error instanceof ApiError && error.status === 401) {
        this.clearCareState();
        this.error = '登录已失效，请重新登录';
        this.displayName = '';
        this.profile = {};
        this.profileUpdatedAt = '';
        this.guest = true;
        this.password = '';
        this.screen = 'login';
        this.accepted = false;
      }
    } finally { if (epoch === this.pageGeneration) this.profileLoading = false; }
  }

  private async signOut(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    ++this.pageGeneration;
    this.clearCareState();
    try {
      await this.releasePushBeforeLogout();
      await saydianApi.logout();
      this.logoutFailed = false;
      this.error = '';
      this.account = '';
    } catch (error) {
      this.logoutFailed = true;
      this.error = `本机登录信息未能清除，请点下方按钮重试。${(error as Error).message}`;
    } finally {
      this.profile = {};
      this.profileError = '';
      this.profileUpdatedAt = '';
      this.profileLoading = false;
      this.displayName = '';
      this.password = '';
      this.accepted = false;
      this.guest = true;
      this.screen = 'login';
      this.busy = false;
    }
  }

  private showFeature(title: string, message: string): void {
    this.previousScreen = this.screen;
    this.detailTitle = title;
    this.detailBody = message;
    this.screen = 'feature';
  }

  private async openArticle(id: string, title: string, agreement: boolean): Promise<void> {
    if (this.screen !== 'article') this.previousScreen = this.screen;
    this.selectedArticleId = id;
    this.selectedAgreement = agreement;
    this.articleTitle = title;
    this.articleContent = [];
    this.articleError = '';
    this.articleLoading = true;
    this.screen = 'article';
    const epoch = ++this.contentGeneration;
    try {
      const article = await saydianApi.article(id, agreement);
      if (epoch !== this.contentGeneration) return;
      this.articleTitle = article.title || title;
      this.articleContent = articleBlocks(article.content || article.description);
      if (this.articleContent.length === 0) this.articleError = '服务器暂未提供正文，请稍后重试';
    } catch (error) {
      if (epoch === this.contentGeneration) this.articleError = (error as Error).message;
    } finally { if (epoch === this.contentGeneration) this.articleLoading = false; }
  }

  private async openArticles(): Promise<void> {
    this.screen = 'articles';
    this.articles = [];
    this.listError = '';
    this.listLoading = true;
    const epoch = ++this.contentGeneration;
    try {
      const items = await saydianApi.articles();
      if (epoch === this.contentGeneration) this.articles = items;
    } catch (error) {
      if (epoch === this.contentGeneration) this.listError = (error as Error).message;
    } finally { if (epoch === this.contentGeneration) this.listLoading = false; }
  }

  private back(): void {
    if (this.careBusy) return;
    ++this.contentGeneration;
    if (this.screen === 'shop-product') { this.screen = 'shop-home'; return; }
    if (this.screen === 'shop-payment') { this.screen = 'shop-orders'; this.paymentMessage = ''; return; }
    if (this.screen === 'shop-orders' || this.screen === 'messages' || this.screen === 'health-alerts' ||
      this.screen === 'health-all' || this.screen === 'sport-records' || this.screen === 'ai-chat' ||
      this.screen === 'shop-home' || this.screen === 'about' || this.screen === 'contact' ||
      this.screen === 'help' || this.screen === 'permissions') { this.screen = 'home'; return; }
    if (this.screen === 'wearable-metric') { this.screen = 'home'; return; }
    if (this.screen.startsWith('care')) {
      ++this.careGeneration; this.careLoading = false; this.careMessage = '';
      if (this.screen === 'care') { this.screen = 'home'; this.clearCareState(); }
      else if (this.screen === 'care-settings') { this.screen = 'care-sharing'; this.careSettingsReady = false; this.careSettings = { enabled: [], unknown: [] }; }
      else this.screen = 'care';
      return;
    }
    if (this.screen === 'article' || this.screen === 'feature') this.screen = this.previousScreen;
    else if (this.screen === 'articles') this.screen = 'home';
  }

  onBackPress(): boolean {
    if (this.screen === 'article' || this.screen === 'feature' || this.screen === 'articles' ||
      this.screen === 'messages' || this.screen === 'health-alerts' || this.screen === 'health-all' ||
      this.screen === 'sport-records' || this.screen === 'ai-chat' || this.screen === 'wearable-metric' ||
      this.screen === 'about' || this.screen === 'contact' || this.screen === 'help' || this.screen === 'permissions' ||
      this.screen.startsWith('shop-') || this.screen.startsWith('care')) {
      this.back();
      return true;
    }
    return false;
  }

  @Builder
  Notice($$: NoticeOptions) {
    Text($$.message).fontSize(14).fontColor(INK).lineHeight(22).width('100%')
      .padding(14).backgroundColor($$.color ?? '#EAF1F8').borderRadius(14)
  }

  @Builder
  Heading() {
    Row() {
      Button('‹ 返回').fontSize(16).fontColor(RED).backgroundColor(Color.Transparent)
        .height(48).enabled(!this.careBusy).onClick(() => this.back()).accessibilityText('返回上一页')
      Text(this.screen.startsWith('care') ? this.careHeading() : this.screen === 'messages' ? '消息与推送' :
        this.screen === 'health-alerts' ? '健康预警' : this.screen === 'health-all' ? '全部健康数据' :
          this.screen === 'sport-records' ? '运动与记录' : this.screen === 'ai-chat' ? 'AI 健康管家' :
            this.screen === 'shop-home' ? '赛电商城' : this.screen === 'shop-product' ? '商品详情' :
              this.screen === 'shop-orders' ? '我的订单' : this.screen === 'shop-payment' ? '支付收银台' :
                this.screen === 'about' ? '关于我们' : this.screen === 'contact' ? '联系客服' :
                  this.screen === 'help' ? '帮助与反馈' : this.screen === 'permissions' ? '权限管理' :
          this.screen === 'wearable-metric' ? this.wearableMetricTitle(this.selectedWearableMetric) :
            this.screen === 'articles' ? '健康百科' : this.screen === 'article' ? this.articleTitle : this.detailTitle)
        .fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
    }.width('100%').margin({ bottom: 16 })
  }

  private careHeading(): string {
    if (this.screen === 'care-invitations') return '关爱邀请';
    if (this.screen === 'care-sharing') return '共享管理';
    if (this.screen === 'care-settings') return '共享数据管理';
    if (this.screen === 'care-add') return '添加关爱成员';
    if (this.screen === 'care-member') return '成员健康数据';
    return '远程关爱';
  }

  @Builder
  Login() {
    Scroll() {
      Column({ space: 16 }) {
        Image($r('app.media.brand_lockup')).width(205).height(100).objectFit(ImageFit.Contain)
          .accessibilityText('赛电 SAYDIAN').margin({ top: 28, bottom: 12 })
        Text('欢迎回到赛电').fontSize(28).fontWeight(FontWeight.Bold).fontColor(INK)
        Text('登录后查看您的账号信息').fontSize(15).fontColor(MUTED).margin({ bottom: 16 })
        TextInput({ placeholder: '手机号 / 账号', text: this.account }).type(InputType.Normal)
          .height(54).fontSize(17).backgroundColor(Color.White).borderRadius(14)
          .maxLength(128).enabled(canSubmitLogin(this.busy, this.restoring)).onChange((value: string) => this.account = value)
          .id('login_account').accessibilityText('手机号或账号')
        TextInput({ placeholder: '密码', text: this.password }).type(InputType.Password)
          .height(54).fontSize(17).backgroundColor(Color.White).borderRadius(14)
          .maxLength(256).enabled(canSubmitLogin(this.busy, this.restoring)).onChange((value: string) => this.password = value)
          .onSubmit(() => this.submitLogin()).id('login_password').accessibilityText('密码')
        Row() {
          Checkbox({ name: 'agreement' }).select(this.accepted).enabled(canSubmitLogin(this.busy, this.restoring))
            .selectedColor(RED).onChange((value: boolean) => this.accepted = value)
            .id('login_agreement').accessibilityText('同意用户协议与隐私政策')
          Column({ space: 0 }) {
            Text('我已阅读并同意').fontSize(13).fontColor(MUTED).width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              Button('用户协议').height(44).fontSize(14).fontColor('#32648B').backgroundColor(Color.Transparent)
                .enabled(canSubmitLogin(this.busy, this.restoring)).onClick(() => this.openArticle('2', '用户协议', true))
              Button('隐私政策').height(44).fontSize(14).fontColor('#32648B').backgroundColor(Color.Transparent)
                .enabled(canSubmitLogin(this.busy, this.restoring)).onClick(() => this.openArticle('3', '隐私政策', true))
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(VerticalAlign.Top)
        if (this.error) { this.Notice({ message: this.error, color: '#FFF0E9' }) }
        if (this.logoutFailed) {
          Button('重试清除本机登录状态').width('100%').constraintSize({ minHeight: 50 })
            .fontColor(RED).backgroundColor(Color.White).enabled(!this.busy)
            .onClick(() => this.signOut()).id('retry_logout')
        }
        Button(this.busy ? '正在登录…' : '登录').width('100%').height(54).fontSize(18)
          .fontWeight(FontWeight.Bold).backgroundColor(RED).enabled(!this.busy && !this.restoring)
          .onClick(() => this.submitLogin()).id('login_submit')
        Button('先浏览首页（未登录）').width('100%').height(48).fontColor(RED)
          .backgroundColor(Color.Transparent).enabled(!this.busy && !this.restoring)
          .onClick(() => {
            ++this.pageGeneration;
            this.profile = {};
            this.displayName = '';
            this.guest = true;
            this.tab = 0;
            this.screen = 'home';
          }).id('browse_home')
        if (this.restoring) { Text('正在检查本机登录状态…').fontSize(14).fontColor(MUTED) }
        this.Notice({ message: '健康数据会保存在本机加密数据库；关爱、订单和推送功能需登录后使用。' })
        Text('账号密码仅用于登录；密码不会保存到本机。').fontSize(12).fontColor(MUTED).textAlign(TextAlign.Center)
      }.width('100%').constraintSize({ maxWidth: 460 }).padding({ left: 24, right: 24, bottom: 32 })
    }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
  }

  @Builder
  HealthHome() {
    Column({ space: 18 }) {
      Row({ space: 12 }) {
        Image($r('app.media.app_icon')).width(48).height(48).borderRadius(24).accessibilityText('赛电')
        Column({ space: 4 }) {
          Text(this.guest ? '您好，欢迎来到赛电' : `您好，${this.displayName}`)
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(2)
          Text(this.guest ? '当前未登录 · 可浏览首页' : '今天也要保持好状态').fontSize(14).fontColor(MUTED)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.notificationCount > 0 ? `消息 ${this.notificationCount > 99 ? '99+' : this.notificationCount}` : '消息')
          .height(48).fontSize(14).fontColor(this.notificationCount > 0 ? RED : INK).backgroundColor(Color.White)
          .onClick(() => this.openMessages()).id('open_messages')
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 12 }) {
        Image($r('app.media.health_doctor')).width(105).height(170).objectFit(ImageFit.Cover).borderRadius(18)
          .accessibilityText('赛电健康管家形象')
        Column({ space: 12 }) {
          Text('AI 健康管家').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#9F1230')
          Text('我是您的健康管家，\n有任何健康问题都可以向我提问。').fontSize(15).fontColor(INK).lineHeight(23)
          Button('马上提问').fontSize(16).height(46).backgroundColor(RED).width('100%')
            .onClick(() => this.openAiChat()).id('open_ai_chat')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').padding(14).borderRadius(24).backgroundColor('#FFF1F2')
      Row({ space: 10 }) {
        Button('远程关爱').layoutWeight(1).height(52).fontColor(INK).backgroundColor('#FFE8ED')
          .onClick(() => this.openCare()).id('family_care')
        Button('健康百科').layoutWeight(1).height(52).fontColor(INK).backgroundColor('#FFF0CC')
          .onClick(() => this.openArticles()).id('health_articles')
      }.width('100%')
      Row({ space: 10 }) {
        Button('健康预警').layoutWeight(1).height(52).fontColor(INK).backgroundColor('#FFE8ED')
          .onClick(() => this.openHealthAlerts()).id('health_alerts')
        Button('赛电商城').layoutWeight(1).height(52).fontColor(INK).backgroundColor('#FFF0CC')
          .onClick(() => this.openShop()).id('health_shop')
      }.width('100%')
      if (this.profileError) { this.Notice({ message: this.profileError, color: '#FFF0E9' }) }
      Row() {
        Text('健康数据').fontSize(25).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
        Button('全部数据  ›').height(44).fontSize(15).fontWeight(FontWeight.Bold).fontColor(RED)
          .backgroundColor(Color.Transparent).onClick(() => this.screen = 'health-all').id('health_all')
      }.width('100%')
      Button(this.wearableSnapshot.connected ? `已连接 ${this.wearableSnapshot.deviceName}` : '连接手表后查看健康数据')
        .constraintSize({ minHeight: 54 }).width('100%').fontSize(17).fontColor('#32648B')
        .backgroundColor('#E5EFF9').onClick(() => this.tab = 1).id('connect_watch_notice')
      Text(this.wearableSnapshot.connected ? this.wearableSyncTime() : '尚未连接手表，以下项目暂无本机记录。')
        .fontSize(14).fontColor(MUTED).width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.wearableMetrics.filter((metric: WearableMetricSpec) => metric.key !== 'sport'), (metric: WearableMetricSpec) => {
          Column({ space: 9 }) {
            Text(metric.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
            Text(this.wearableLatest(metric.key)).fontSize(15).lineHeight(22)
              .fontColor(this.wearableCapability(metric.key) ? INK : MUTED).width('100%').maxLines(4)
            Text(this.wearableSnapshot.connected && this.wearableCapability(metric.key) ? '查看全部记录 >' :
              this.wearableSnapshot.connected ? '当前手表不支持' : '暂无记录')
              .fontSize(13).fontColor(MUTED).width('100%')
          }.width('48%').padding(18).margin({ bottom: 12 }).backgroundColor(Color.White).borderRadius(20)
            .onClick(() => this.openWearableMetric(metric.key))
            .accessibilityText(`${metric.title}，${this.wearableLatest(metric.key)}`)
        }, (metric: WearableMetricSpec) => metric.key)
      }.width('100%')

      Text('运动与记录').fontSize(25).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      Row({ space: 14 }) {
        Text('◷').fontSize(30).fontColor(RED)
        Column({ space: 5 }) {
          Text('运动记录').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Text(this.wearableSnapshot.connected ? this.wearableLatest('sport') : '连接手表后读取运动记录')
            .fontSize(14).fontColor(MUTED).width('100%').maxLines(3)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('›').fontSize(30).fontColor(RED)
      }.width('100%').padding(18).backgroundColor('#FFF1F2').borderRadius(20)
        .onClick(() => this.screen = 'sport-records').accessibilityText('查看运动记录')
      this.Notice({ message: '测量结果仅供健康管理参考，如有不适请咨询专业医务人员。', color: '#EAF2EA' })
    }.width('100%').padding(20)
  }

  @Builder
  DeviceHome() {
    Column({ space: 16 }) {
      Text('我的设备').fontSize(28).fontWeight(FontWeight.Bold).width('100%').fontColor(INK)
      this.Notice({ message: this.wearableMessage,
        color: this.wearablePhase === 'error' || this.wearablePhase === 'permission' ? '#FFF0E9' :
          this.wearableSnapshot.connected ? '#EAF2EA' : '#EAF1F8' })

      if (this.wearableSnapshot.connected) {
        Column({ space: 12 }) {
          Row() {
            Column({ space: 4 }) {
              Text(this.wearableSnapshot.deviceName).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(2)
              Text('Vep · Veepoo').fontSize(13).fontColor('#32648B')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text(batteryText(this.wearableSnapshot.battery)).fontSize(17).fontWeight(FontWeight.Medium)
              .fontColor(this.wearableSnapshot.battery.lowBattery ? RED : INK)
          }.width('100%')
          Text(this.wearableSnapshot.mac ? `MAC · ${this.wearableSnapshot.mac}` : '真实 MAC 未提供')
            .fontSize(14).fontColor(MUTED).width('100%')
          if (this.wearableSnapshot.model || this.wearableSnapshot.firmware) {
            Text(`型号 ${this.wearableSnapshot.model || '未知'} · 固件 ${this.wearableSnapshot.firmware || '未知'}`)
              .fontSize(14).fontColor(MUTED).width('100%').maxLines(3)
          }
          Text(this.wearableSyncTime()).fontSize(13).fontColor(MUTED).width('100%')
          Row({ space: 10 }) {
            Button('刷新信息').layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor('#32648B')
              .backgroundColor('#E5EFF9').enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
              .onClick(() => vepWearable.refresh()).id('wearable_refresh')
            Button('同步近三天').layoutWeight(1).constraintSize({ minHeight: 48 }).backgroundColor(RED)
              .enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
              .onClick(() => vepWearable.syncHistory()).id('wearable_sync')
          }.width('100%')
          Row({ space: 10 }) {
            Button('同步时间').layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(INK)
              .backgroundColor(Color.White).enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
              .onClick(() => vepWearable.syncTime()).id('wearable_sync_time')
            if (this.wearableSnapshot.capabilities.findDevice) {
              Button('查找手表').layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(INK)
                .backgroundColor(Color.White).enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
                .onClick(() => vepWearable.findDevice()).id('wearable_find')
            }
          }.width('100%')
          Row({ space: 10 }) {
            Button('读取设备设置').layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(INK)
              .backgroundColor(Color.White).enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
              .onClick(() => vepWearable.readDeviceConfiguration()).id('wearable_read_settings')
            if (this.wearableSnapshot.capabilities.dial) {
              Button('读取表盘').layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(INK)
                .backgroundColor(Color.White).enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
                .onClick(() => vepWearable.readDials()).id('wearable_read_dials')
            }
          }.width('100%')
          Button('断开当前手表').width('100%').constraintSize({ minHeight: 48 }).fontColor(RED)
            .backgroundColor(Color.White).enabled(!this.wearableBusy())
            .onClick(() => vepWearable.disconnect()).id('wearable_disconnect')
        }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)

        if (this.wearableSnapshot.settings.loadedAt > 0) {
          Column({ space: 8 }) {
            Text('手表实际设置').fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(`单位 ${this.wearableSnapshot.settings.unitSystem} · 时制 ${this.wearableSnapshot.settings.timeFormat}`)
              .fontSize(15).fontColor(INK).width('100%')
            Text(`自动健康：${this.wearableSnapshot.settings.automaticHealth}`).fontSize(14).fontColor(MUTED).width('100%')
            Text(`久坐提醒：${this.wearableSnapshot.settings.sedentaryReminder}`).fontSize(14).fontColor(MUTED).width('100%')
            Text(`消息提醒：${this.wearableSnapshot.settings.messageReminder}`).fontSize(14).fontColor(MUTED).width('100%')
            Text(this.wearableSnapshot.settings.alarms.length > 0 ?
              `闹钟：${this.wearableSnapshot.settings.alarms.join('\n')}` : '闹钟：无已读取记录')
              .fontSize(14).fontColor(MUTED).lineHeight(22).width('100%')
          }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        }

        if (this.wearableSnapshot.dials.length > 0) {
          Column({ space: 10 }) {
            Row() {
              Text('手表内表盘').fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
              if (this.wearableSnapshot.originalDialKey &&
                this.wearableSnapshot.currentDialKey !== this.wearableSnapshot.originalDialKey) {
                Button('恢复原表盘').height(42).fontColor(RED).backgroundColor('#FFF1F2')
                  .enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
                  .onClick(() => vepWearable.restoreOriginalDial()).id('wearable_restore_dial')
              }
            }.width('100%')
            ForEach(this.wearableSnapshot.dials, (dial: WearableDial) => {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(dial.fileName || '未命名表盘').fontSize(16).fontWeight(FontWeight.Medium)
                    .fontColor(INK).maxLines(2).width('100%')
                  Text(dial.selected ? '当前使用' : '手表内已安装').fontSize(13)
                    .fontColor(dial.selected ? RED : MUTED).width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button(dial.selected ? '使用中' : '切换').height(42).fontColor(dial.selected ? MUTED : RED)
                  .backgroundColor(dial.selected ? '#F0F1F3' : '#FFF1F2')
                  .enabled(!dial.selected && !this.wearableBusy() && !this.wearableMeasurement.running)
                  .onClick(() => vepWearable.setExistingDial(dial.key))
              }.width('100%').padding(12).backgroundColor('#F8F9FB').borderRadius(14)
            }, (dial: WearableDial) => dial.key)
            Text('只读取和切换手表内已安装表盘；不猜测缩略图，不执行 OTA。')
              .fontSize(13).fontColor(MUTED).width('100%')
          }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        }

        Text('手动测量').fontSize(23).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.measurementMetrics, (metric: WearableMetricSpec) => {
            if (this.wearableCapability(metric.key)) {
              Button(`测${metric.title}`).width('48%').constraintSize({ minHeight: 50 }).margin({ bottom: 10 })
                .fontColor(this.wearableMeasurement.metric === metric.key ? Color.White : INK)
                .backgroundColor(this.wearableMeasurement.metric === metric.key ? RED : Color.White)
                .enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
                .onClick(() => vepWearable.startMeasurement(metric.key)).id(`measure_${metric.key}`)
            }
          }, (metric: WearableMetricSpec) => metric.key)
        }.width('100%')

        if (this.wearableMeasurement.metric) {
          Column({ space: 12 }) {
            Row() {
              Text(this.wearableMetricTitle(this.wearableMeasurement.metric)).fontSize(20).fontWeight(FontWeight.Bold)
                .fontColor(INK).layoutWeight(1)
              if (this.wearableMeasurement.running) {
                Text(`${this.wearableMeasurement.progress}%`).fontSize(16).fontColor(RED)
              }
            }.width('100%')
            Text(this.measurementText()).fontSize(16).fontColor(INK).lineHeight(24).width('100%')
            if (this.wearableMeasurement.metric === 'ecg') {
              if (this.wearableMeasurement.samples.length > 1) {
                Polyline({ width: 320, height: 120 }).points(this.ecgWaveformPoints())
                  .fillOpacity(0).stroke(RED).strokeWidth(2).width('100%').height(120)
                Text(`真实波形 ${this.wearableMeasurement.samples.length} 点${this.wearableMeasurement.sampleFrequency > 0 ?
                  ` · ${this.wearableMeasurement.sampleFrequency} Hz` : ''}`)
                  .fontSize(13).fontColor(MUTED).width('100%')
              } else {
                Text('等待真实心电采样点，不显示模拟波形。').fontSize(13).fontColor(MUTED).width('100%')
              }
            }
            if (this.wearableMeasurement.running) {
              Button('结束测量').width('100%').constraintSize({ minHeight: 50 }).backgroundColor(RED)
                .onClick(() => vepWearable.stopMeasurement()).id('measure_stop')
            }
          }.width('100%').padding(18).backgroundColor('#FFF1F2').borderRadius(20)
        }
      } else {
        Button(vepWearable.isScanning() ? '停止扫描' : '扫描附近手表').width('100%').constraintSize({ minHeight: 54 })
          .backgroundColor(vepWearable.isScanning() ? '#8A8D98' : RED).enabled(!this.wearableBusy())
          .onClick(() => vepWearable.isScanning() ? vepWearable.stopScan('已停止扫描') : vepWearable.startScan())
          .id('wearable_scan')
        if (this.wearableDevices.length === 0) {
          this.Notice({ message: vepWearable.isScanning() ? '正在搜索 ET488、W9、W9S 和 W8 系列…' :
            '点击扫描后，Vep 设备可连接；名称含 W8 的设备显示为 Yuc。' })
        }
        ForEach(this.wearableDevices, (device: WearableDevice) => {
          Row({ space: 12 }) {
            Column({ space: 6 }) {
              Text(device.name).fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(2).width('100%')
              Text(wearableIdentifierText(device)).fontSize(13).fontColor(MUTED).maxLines(2).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 6 }) {
              Text(device.provider).fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(device.provider === 'Vep' ? '#32648B' : '#26864A')
              Text(this.signalText(device.rssi)).fontSize(12).fontColor(MUTED)
              Text(device.provider === 'Vep' ? '连接' : '待 SDK').fontSize(15).fontWeight(FontWeight.Bold)
                .fontColor(device.provider === 'Vep' ? '#32648B' : MUTED)
            }
          }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18)
            .onClick(() => vepWearable.connect(device.key)).accessibilityText(`${device.name}，${device.provider}，${this.signalText(device.rssi)}`)
        }, (device: WearableDevice) => device.key)
      }
      this.Notice({ message: 'Vep：Veepoo，可连接 ET488、W9、W9S 等支持设备。\nYuc：Yucheng，名称只要包含 W8 就归入该类。\n\n本版本不开放 OTA、恢复出厂、删除联系人或清空健康数据。' })
    }.width('100%').padding(24)
  }

  @Builder
  MineHome() {
    Column({ space: 18 }) {
      Text('我的').fontSize(28).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      Row({ space: 15 }) {
        Image($r('app.media.app_icon')).width(72).height(72).borderRadius(36).accessibilityText('赛电头像')
        Column({ space: 6 }) {
          Text(this.guest ? '暂未登录' : this.displayName).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK)
            .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.guest ? '登录后开启云端健康服务' : `会员 ID：${profileField(this.profile.id)}`)
            .fontSize(14).fontColor(MUTED).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').padding(20).backgroundColor('#FFF1F2').borderRadius(24)
      if (this.guest) {
        Button('登录赛电账号').width('100%').height(52).backgroundColor(RED)
          .onClick(() => { this.error = ''; this.screen = 'login'; }).id('go_login')
      } else {
        Row({ space: 9 }) {
          Button(this.wearableSnapshot.connected ? '设备\n在线' : '设备\n未连接').layoutWeight(1).constraintSize({ minHeight: 72 })
            .padding(4).labelStyle({ maxLines: 2 }).fontColor(this.wearableSnapshot.connected ? '#26864A' : MUTED).backgroundColor(Color.White)
            .onClick(() => this.tab = 1).id('profile_stat_device')
          Button(`健康记录\n${this.wearableSnapshot.records.length} 条`).layoutWeight(1).constraintSize({ minHeight: 72 })
            .padding(4).labelStyle({ maxLines: 2 }).fontColor(RED).backgroundColor(Color.White)
            .onClick(() => this.screen = 'health-all').id('profile_stat_health')
          Button(`关爱成员\n${this.careMembers.length} 人`).layoutWeight(1).constraintSize({ minHeight: 72 })
            .padding(4).labelStyle({ maxLines: 2 }).fontColor('#32648B').backgroundColor(Color.White)
            .onClick(() => this.openCare()).id('profile_stat_care')
        }.width('100%')
      }

      Text('我的订单').fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      Row({ space: 8 }) {
        ForEach(['待支付', '待发货', '待收货', '售后'], (label: string) => {
          Button(label).layoutWeight(1).constraintSize({ minHeight: 54 }).padding(4).labelStyle({ maxLines: 2 })
            .fontSize(12).fontColor(INK)
            .backgroundColor(Color.White).onClick(() => this.openOrders())
        })
      }.width('100%')

      Column({ space: 10 }) {
        Button('查看个人资料  ›').width('100%').height(50).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.showFeature('个人资料', this.guest ? '请先登录赛电账号。' :
            `昵称：${profileName(this.profile) || this.displayName}\n生日：${profileField(this.profile.birthday)}\n身高：${profileField(this.profile.height, ' cm')}\n体重：${profileField(this.profile.weight, ' kg')}`))
        Button('AI 提问  ›').width('100%').height(50).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.openAiChat()).id('mine_ai')
        Button('消息与推送  ›').width('100%').height(50).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.openMessages()).id('mine_messages')
      }.width('100%').padding(10).backgroundColor(Color.White).borderRadius(20)

      Text('我的服务').fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      Row({ space: 8 }) {
        Button('账号设置').layoutWeight(1).height(52).fontSize(14).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.showFeature('账号设置', '可在个人资料中查看账号信息；收货地址、密码重置和注销账号的鸿蒙原生接口尚未开放。'))
        Button('权限管理').layoutWeight(1).height(52).fontSize(14).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.screen = 'permissions').id('mine_permissions')
        Button('帮助反馈').layoutWeight(1).height(52).fontSize(14).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.screen = 'help').id('mine_help')
      }.width('100%')
      Row({ space: 8 }) {
        Button('联系客服').layoutWeight(1).height(52).fontSize(14).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.screen = 'contact').id('mine_contact')
        Button('关于我们').layoutWeight(1).height(52).fontSize(14).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.screen = 'about').id('mine_about')
      }.width('100%')

      if (!this.guest) {
        if (this.profileError) { this.Notice({ message: this.profileError, color: '#FFF0E9' }) }
        Button(this.profileLoading ? '正在读取资料…' : '刷新个人资料').width('100%').height(50)
          .fontColor(RED).backgroundColor(Color.White).enabled(!this.profileLoading && !this.busy)
          .onClick(() => this.refreshProfile()).id('refresh_profile')
        Button(this.busy ? '正在退出…' : '退出登录').width('100%').height(50).backgroundColor(RED)
          .enabled(!this.busy).onClick(() => this.signOut()).id('logout')
      }
      Text(`赛电健康 V${HARMONY_VERSION_NAME} (${HARMONY_VERSION_CODE})`).fontSize(13).fontColor(MUTED)
        .width('100%').textAlign(TextAlign.Center)
    }.width('100%').padding(24)
  }

  @Builder
  Home() {
    Column() {
      Scroll() {
        Column() {
          if (this.tab === 0) { this.HealthHome() }
          else if (this.tab === 1) { this.DeviceHome() }
          else { this.MineHome() }
        }.width('100%').constraintSize({ maxWidth: 720 })
      }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
      Row() {
        ForEach(['健康', '设备', '我的'], (title: string, index: number) => {
          Button(title).layoutWeight(1).height(60).fontSize(17)
            .fontWeight(this.tab === index ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.tab === index ? RED : MUTED).backgroundColor(Color.White)
            .onClick(() => this.tab = index).id(`tab_${index}`)
        })
      }.width('100%').backgroundColor(Color.White)
    }.height('100%').width('100%')
  }

  @Builder
  HealthAllContent() {
    this.Notice({ message: this.wearableSnapshot.connected ?
      `${this.wearableSnapshot.deviceName} · ${this.wearableSyncTime()}` : '连接手表后可查看设备实际支持的健康数据。', color: '#EAF2EA' })
    ForEach(this.wearableMetrics, (metric: WearableMetricSpec) => {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text(metric.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Text(this.wearableLatest(metric.key)).fontSize(14).fontColor(MUTED).lineHeight(22).maxLines(3).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.wearableSnapshot.connected && this.wearableCapability(metric.key) ? '›' : '—')
          .fontSize(26).fontColor(this.wearableCapability(metric.key) ? RED : MUTED)
      }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18)
        .onClick(() => this.openWearableMetric(metric.key))
        .accessibilityText(`${metric.title}，${this.wearableLatest(metric.key)}`)
    }, (metric: WearableMetricSpec) => metric.key)
    Text('数值仅供健康管理参考，不自动判断疾病或异常。').fontSize(13).fontColor(MUTED).width('100%')
  }

  @Builder
  SportRecordContent() {
    if (!this.wearableSnapshot.connected) {
      this.Notice({ message: '连接手表后才能同步运动记录。' })
      Button('前往添加设备').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
        .onClick(() => { this.screen = 'home'; this.tab = 1; }).id('sport_go_device')
    } else if (!this.wearableCapability('sport')) {
      this.Notice({ message: `当前 ${this.wearableSnapshot.deviceName} 未报告可读取的运动记录能力。` })
    } else {
      Row({ space: 10 }) {
        Button('同步近三天').layoutWeight(1).constraintSize({ minHeight: 50 }).backgroundColor(RED)
          .enabled(!this.wearableBusy() && !this.wearableMeasurement.running).onClick(() => vepWearable.syncHistory())
        Button('查看设备').layoutWeight(1).constraintSize({ minHeight: 50 }).fontColor(RED).backgroundColor(Color.White)
          .onClick(() => { this.screen = 'home'; this.tab = 1; })
      }.width('100%')
      if (this.wearableMetricRecords('sport').length === 0) {
        this.Notice({ message: '手表暂未返回运动历史。不使用手机步数或模拟数据代替。' })
      }
      ForEach(this.wearableMetricRecords('sport'), (record: HealthRecord) => {
        Column({ space: 8 }) {
          Text(this.wearableRecordTime(record.timestamp)).fontSize(14).fontColor(MUTED).width('100%')
          Text(healthRecordText(record)).fontSize(18).fontColor(INK).lineHeight(26).width('100%')
          Text(record.source === 'watch_history' ? '来源：手表历史' : '来源：App 记录')
            .fontSize(13).fontColor(MUTED).width('100%')
        }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18)
      }, (record: HealthRecord) => record.id)
    }
  }

  @Builder
  HealthAlertContent() {
    this.Notice({ message: '健康预警只记录设备或服务端明确上报的事件，不根据普通测量值自行诊断。', color: '#EAF2EA' })
    Text(this.notificationCount > 0 ? `当前有 ${this.notificationCount} 条未读消息` : '暂无可展示的健康预警')
      .fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    this.Notice({ message: '服务端尚未开放鸿蒙健康预警列表接口。客户端已保留通知权限、点击路由和未读数链路，不伪造预警历史。' })
    Button('消息与推送设置').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
      .onClick(() => this.openMessages()).id('alerts_open_messages')
  }

  @Builder
  ShopHomeContent() {
    Row({ space: 10 }) {
      Button('我的订单').layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White)
        .onClick(() => this.openOrders()).id('shop_orders')
      Button(this.shopLoading ? '正在刷新…' : '刷新商城').layoutWeight(1).constraintSize({ minHeight: 48 })
        .backgroundColor(RED).enabled(!this.shopLoading).onClick(() => this.openShop()).id('shop_refresh')
    }.width('100%')
    if (this.shopLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.shopError) { this.Notice({ message: this.shopError, color: '#FFF0E9' }) }
    if (this.shopHome.bannerUrl) {
      ArticleImage({ source: this.shopHome.bannerUrl, description: '赛电商城横幅' })
    }
    if (!this.shopLoading && !this.shopError && this.shopHome.categories.length === 0) {
      this.Notice({ message: '商城暂无可展示分类。' })
    }
    if (this.shopHome.categories.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.shopHome.categories, (category: ShopCategory, index: number) => {
          Button(category.name).constraintSize({ minHeight: 46 }).margin({ right: 8, bottom: 8 })
            .fontColor(this.shopCategoryIndex === index ? Color.White : INK)
            .backgroundColor(this.shopCategoryIndex === index ? RED : Color.White)
            .onClick(() => this.shopCategoryIndex = index)
        }, (category: ShopCategory) => category.id)
      }.width('100%')
      if (this.shopCategory().products.length === 0) {
        this.Notice({ message: '当前分类暂无商品。' })
      }
      ForEach(this.shopCategory().products, (product: ShopProduct) => {
        Row({ space: 14 }) {
          if (product.picture) {
            Image(product.picture).width(104).height(104).objectFit(ImageFit.Cover).borderRadius(14)
              .accessibilityText(product.name)
          } else {
            Text('商品').width(104).height(104).fontSize(16).fontColor(MUTED).textAlign(TextAlign.Center)
              .backgroundColor('#F0F1F5').borderRadius(14)
          }
          Column({ space: 8 }) {
            Text(product.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').maxLines(2)
            Text(`¥${product.price}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor(RED).width('100%')
            Text(product.stock > 0 ? `库存 ${product.stock}` : '暂时缺货').fontSize(13).fontColor(MUTED).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('›').fontSize(28).fontColor(RED)
        }.width('100%').padding(14).backgroundColor(Color.White).borderRadius(18)
          .onClick(() => this.openShopProduct(product)).accessibilityText(`${product.name}，${product.price} 元`)
      }, (product: ShopProduct) => String(product.id))
    }
  }

  @Builder
  ShopProductContent() {
    if (this.selectedProduct.picture) {
      ArticleImage({ source: this.selectedProduct.picture, description: this.selectedProduct.name })
    }
    Text(this.selectedProduct.name).fontSize(24).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    Text(`¥${this.selectedProduct.price}`).fontSize(30).fontWeight(FontWeight.Bold).fontColor(RED).width('100%')
    Text(this.selectedProduct.stock > 0 ? `库存 ${this.selectedProduct.stock}` : '暂时缺货').fontSize(15).fontColor(MUTED).width('100%')
    this.Notice({ message: '鸿蒙端已使用服务端真实商品目录。商品规格、购物车和创建订单接口尚未完成原生适配，因此不展示无法完成的“立即购买”按钮。' })
    Button('查看我的订单').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
      .onClick(() => this.openOrders())
  }

  @Builder
  AiChatContent() {
    this.Notice({ message: '可以咨询日常健康管理问题。AI 回答仅供参考，不能替代医生诊断。', color: '#EAF2EA' })
    if (this.aiBusy && this.aiMessages.length === 0) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.aiError) { this.Notice({ message: this.aiError, color: '#FFF0E9' }) }
    if (!this.aiBusy && !this.aiError && this.aiMessages.length === 0) {
      this.Notice({ message: '您好，我是 AI 健康管家。请在下方输入您的问题。' })
    }
    ForEach(this.aiMessages, (message: AiChatMessage) => {
      Row() {
        if (message.mine) { Blank().layoutWeight(1) }
        Column({ space: 5 }) {
          Text(message.text).fontSize(16).lineHeight(24).fontColor(message.mine ? Color.White : INK)
            .copyOption(CopyOptions.InApp).width('100%')
          if (message.failed) { Text('发送失败，请检查网络后重试').fontSize(12).fontColor('#FFD7D7').width('100%') }
        }.width('78%').padding(14).backgroundColor(message.mine ? RED : Color.White).borderRadius(18)
        if (!message.mine) { Blank().layoutWeight(1) }
      }.width('100%')
    }, (message: AiChatMessage) => message.id)
    TextInput({ placeholder: '请输入消息…', text: this.aiInput }).fontSize(17).height(56).maxLength(2000)
      .backgroundColor(Color.White).enabled(!this.aiBusy).onChange((value: string) => this.aiInput = value)
      .onSubmit(() => this.sendAiChat()).id('ai_input')
    Button(this.aiBusy ? '正在等待回复…' : '发送').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
      .enabled(!this.aiBusy && this.aiInput.trim().length > 0).onClick(() => this.sendAiChat()).id('ai_send')
  }

  @Builder
  AboutContent() {
    Image($r('app.media.brand_lockup')).width(176).height(92).objectFit(ImageFit.Contain).accessibilityText('赛电 SAYDIAN')
    Text('赛电健康').fontSize(23).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').textAlign(TextAlign.Center)
    Text('记录日常健康趋势，连接家人与设备，让健康管理更简单。')
      .fontSize(15).fontColor(MUTED).lineHeight(24).width('100%').textAlign(TextAlign.Center)
    Text(`V${HARMONY_VERSION_NAME} (${HARMONY_VERSION_CODE})`).fontSize(14).fontColor(MUTED).width('100%').textAlign(TextAlign.Center)
    Button('隐私政策  ›').width('100%').height(52).fontColor(INK).backgroundColor(Color.White)
      .onClick(() => this.openArticle('3', '隐私政策', true))
    Button('用户协议  ›').width('100%').height(52).fontColor(INK).backgroundColor(Color.White)
      .onClick(() => this.openArticle('2', '用户协议', true))
    Button(this.updateBusy ? '正在检查更新…' : '检查更新  ›').width('100%').height(52).fontColor(INK)
      .backgroundColor(Color.White).enabled(!this.updateBusy).onClick(() => this.checkOnlineUpdate()).id('check_update')
    this.Notice({ message: this.updateStatus, color: this.updateInfo.hasUpdate ? '#FFF4D8' : '#EAF1F8' })
    if (this.updateInfo.hasUpdate) {
      if (this.updateInfo.releaseNotes) { Text(this.updateInfo.releaseNotes).fontSize(15).fontColor(INK).lineHeight(24).width('100%') }
      Button('前往华为应用市场更新').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
        .onClick(() => this.openUpdateDestination()).id('open_update')
    }
    this.Notice({ message: '健康测量结果仅供健康管理参考，不用于诊断或治疗。', color: '#EAF2EA' })
  }

  @Builder
  ContactContent() {
    Text('联系电话').fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    Text('4006386738').fontSize(24).fontColor(RED).width('100%').copyOption(CopyOptions.InApp)
    Text('微信公众号').fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    Text('赛电').fontSize(24).fontColor(RED).width('100%').copyOption(CopyOptions.InApp)
    this.Notice({ message: '联系前请准备设备型号和问题发生时间。请勿向非官方账号发送验证码、密码或完整健康记录。', color: '#EAF2EA' })
  }

  @Builder
  HelpContent() {
    Text('如何连接手表？').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    this.Notice({ message: '打开“设备”页后点击扫描。让手表保持亮屏、靠近手机，并确认未被其他手机占用。' })
    Text('为什么健康数据暂时为空？').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    this.Notice({ message: '请确认设备已连接并完成同步。设备不支持的项目不会生成模拟记录。' })
    this.Notice({ message: '鸿蒙原生反馈提交接口尚未开放。如需反馈，请通过“联系客服”提供设备型号、发生时间和复现步骤。', color: '#FFF4D8' })
    Button('联系客服').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
      .onClick(() => this.screen = 'contact')
  }

  @Builder
  PermissionContent() {
    Text('蓝牙与附近设备').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    this.Notice({ message: '用于扫描、连接手表并同步健康数据。仅在用户点击扫描时请求。', color: '#EAF2EA' })
    Text('位置').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    this.Notice({ message: '鸿蒙系统在扫描附近蓝牙设备时要求位置权限。本版不申请后台常驻定位。' })
    Text('通知').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    this.Notice({ message: '用于关爱邀请和健康预警。锁屏不显示具体健康数值。' })
    Button('去设备页检查蓝牙权限').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
      .onClick(() => { this.screen = 'home'; this.tab = 1; })
    Button('开启系统通知').width('100%').constraintSize({ minHeight: 52 }).fontColor(RED).backgroundColor(Color.White)
      .enabled(!this.pushBusy).onClick(() => this.connectPush(true))
  }

  @Builder
  MessageContent() {
    this.Notice({ message: '健康预警锁屏通知只显示“有新的健康预警”，不在系统通知中暴露健康数值。', color: '#EAF2EA' })
    Text(this.notificationCount < 0 ? '未读数：服务端暂未提供' : `未读数：${this.notificationCount}`)
      .fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    this.Notice({ message: this.pushStatus, color: this.pushStatus.includes('已登记') ? '#EAF2EA' : '#FFF4D8' })
    Button(this.pushBusy ? '正在连接…' : '开启系统通知并登记推送')
      .width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED).enabled(!this.pushBusy)
      .onClick(() => this.connectPush(true)).id('enable_push')
    Button('刷新未读数').width('100%').constraintSize({ minHeight: 48 })
      .fontColor(RED).backgroundColor(Color.White).enabled(!this.pushBusy)
      .onClick(() => this.refreshNotificationCount()).id('refresh_unread')
    Button('查看关爱邀请').width('100%').constraintSize({ minHeight: 52 })
      .fontColor(INK).backgroundColor(Color.White).onClick(async () => {
        await this.openCare();
        if (!this.guest) this.screen = 'care-invitations';
      }).id('message_care_invitations')
    this.Notice({ message: '客户端已实现极光点击路由和通知权限。只有服务端完成 harmony 设备登记、邀请事件及健康预警推送后，才会出现真实即时消息。' })
  }

  @Builder
  OrderContent() {
    this.Notice({ message: '订单金额和状态每次从服务端读取。App 不在本机生成支付签名，也不以微信或支付宝返回页作为成功依据。', color: '#EAF2EA' })
    if (this.orderLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.paymentMessage) { this.Notice({ message: this.paymentMessage, color: '#FFF0E9' }) }
    if (!this.orderLoading && !this.paymentMessage && this.orders.length === 0) {
      this.Notice({ message: '当前账号暂无可显示订单。' })
    }
    ForEach(this.orders, (order: ShopOrder) => {
      Column({ space: 10 }) {
        Text(order.summary).fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').maxLines(2)
        Text(`订单号：${order.number}`).fontSize(14).fontColor(MUTED).width('100%').maxLines(2)
        Row() {
          Text(this.orderStatus(order.status)).fontSize(15).fontColor(order.status === 0 ? RED : MUTED).layoutWeight(1)
          Text(this.money(order.amountCents)).fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK)
        }.width('100%')
        if (order.status === 0) {
          Button('去支付').width('100%').constraintSize({ minHeight: 48 }).backgroundColor(RED)
            .onClick(() => this.openPayment(order)).id(`pay_order_${order.id}`)
        }
      }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18)
    }, (order: ShopOrder) => String(order.id))
    Button(this.orderLoading ? '正在刷新…' : '刷新订单').width('100%').constraintSize({ minHeight: 48 })
      .fontColor(RED).backgroundColor(Color.White).enabled(!this.orderLoading)
      .onClick(() => this.openOrders()).id('refresh_orders')
  }

  @Builder
  PaymentContent() {
    Column({ space: 12 }) {
      Text(this.selectedOrder.summary).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').maxLines(2)
      Text(`订单号：${this.selectedOrder.number}`).fontSize(14).fontColor(MUTED).width('100%').maxLines(2)
      Row() {
        Text('订单总额').fontSize(17).fontColor(INK).layoutWeight(1)
        Text(this.money(this.selectedOrder.amountCents)).fontSize(27).fontWeight(FontWeight.Bold).fontColor(RED)
      }.width('100%')
    }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18)
    Text('选择支付方式').fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    Button(this.selectedProvider === 'wechat' ? '✓  微信支付' : '微信支付')
      .width('100%').constraintSize({ minHeight: 54 }).fontColor(this.selectedProvider === 'wechat' ? RED : INK)
      .backgroundColor(Color.White).enabled(!this.paymentBusy).onClick(() => this.selectedProvider = 'wechat')
      .id('select_wechat')
    Button(this.selectedProvider === 'alipay' ? '✓  支付宝支付' : '支付宝支付')
      .width('100%').constraintSize({ minHeight: 54 }).fontColor(this.selectedProvider === 'alipay' ? RED : INK)
      .backgroundColor(Color.White).enabled(!this.paymentBusy).onClick(() => this.selectedProvider = 'alipay')
      .id('select_alipay')
    this.Notice({ message: '点击支付后，App 会先向服务端重新核对订单金额与状态，再获取鸿蒙签名参数唤起对应支付 App。' })
    if (this.paymentMessage) {
      this.Notice({ message: this.paymentMessage, color: this.paymentMessage.includes('已更新') ? '#EAF2EA' : '#FFF4D8' })
    }
    Button(this.paymentBusy ? '正在处理…' : `支付 ${this.money(this.selectedOrder.amountCents)}`)
      .width('100%').constraintSize({ minHeight: 56 }).fontSize(18).fontWeight(FontWeight.Bold)
      .backgroundColor(RED).enabled(!this.paymentBusy && this.selectedOrder.status === 0)
      .onClick(() => this.startPayment()).id('confirm_payment')
    Button('返回并刷新订单').width('100%').constraintSize({ minHeight: 48 })
      .fontColor(RED).backgroundColor(Color.White).enabled(!this.paymentBusy)
      .onClick(() => this.openOrders()).id('payment_return_orders')
  }

  @Builder
  WearableMetricContent() {
    if (!this.wearableSnapshot.connected) {
      this.Notice({ message: '连接 Vep 手表后才能同步和查看本机健康记录。' })
      Button('前往添加设备').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
        .onClick(() => { this.screen = 'home'; this.tab = 1; }).id('metric_go_device')
    } else if (!this.wearableCapability(this.selectedWearableMetric)) {
      this.Notice({ message: `当前连接的 ${this.wearableSnapshot.deviceName} 未报告${this.wearableMetricTitle(this.selectedWearableMetric)}能力，因此不展示无效入口或模拟数据。` })
      Button('返回设备').width('100%').constraintSize({ minHeight: 50 }).backgroundColor(RED)
        .onClick(() => { this.screen = 'home'; this.tab = 1; })
    } else {
      this.Notice({ message: `${this.wearableSnapshot.deviceName} · ${this.wearableSyncTime()}`, color: '#EAF2EA' })
      Row({ space: 10 }) {
        Button('同步近三天').layoutWeight(1).constraintSize({ minHeight: 50 }).backgroundColor(RED)
          .enabled(!this.wearableBusy() && !this.wearableMeasurement.running)
          .onClick(() => vepWearable.syncHistory())
        if (this.wearableMetricMeasurable(this.selectedWearableMetric)) {
          Button(this.wearableMeasurement.running && this.wearableMeasurement.metric === this.selectedWearableMetric ?
            '结束测量' : '开始测量').layoutWeight(1).constraintSize({ minHeight: 50 })
            .fontColor(RED).backgroundColor(Color.White).enabled(!this.wearableBusy() &&
              (!this.wearableMeasurement.running || this.wearableMeasurement.metric === this.selectedWearableMetric))
            .onClick(() => this.wearableMeasurement.running ? vepWearable.stopMeasurement() :
              vepWearable.startMeasurement(this.selectedWearableMetric))
        }
      }.width('100%')
      if (this.wearableMeasurement.metric === this.selectedWearableMetric && this.wearableMeasurement.status) {
        Column({ space: 10 }) {
          Text(this.measurementText()).fontSize(17).fontColor(INK).lineHeight(25).width('100%')
          if (this.selectedWearableMetric === 'ecg' && this.wearableMeasurement.samples.length > 1) {
            Polyline({ width: 320, height: 120 }).points(this.ecgWaveformPoints())
              .fillOpacity(0).stroke(RED).strokeWidth(2).width('100%').height(120)
            Text(`真实心电波形 ${this.wearableMeasurement.samples.length} 点`)
              .fontSize(13).fontColor(MUTED).width('100%')
          }
        }.width('100%').padding(18).backgroundColor('#FFF1F2').borderRadius(18)
      }
      if (this.wearableMetricRecords(this.selectedWearableMetric).length === 0) {
        this.Notice({ message: '暂无真实记录。可点击同步，或在手表支持时开始手动测量。' })
      }
      ForEach(this.wearableMetricRecords(this.selectedWearableMetric), (record: HealthRecord) => {
        Column({ space: 8 }) {
          Row() {
            Text(this.wearableRecordTime(record.timestamp)).fontSize(14).fontColor(MUTED).layoutWeight(1)
            Text(record.source === 'watch_history' ? '手表历史' : 'App 测量')
              .fontSize(12).fontColor(record.source === 'watch_history' ? '#32648B' : RED)
          }.width('100%')
          Text(healthRecordText(record)).fontSize(17).fontColor(INK).lineHeight(25).width('100%')
          if (record.samples.length > 1) {
            Text(`已保留 ${record.samples.length} 个真实波形点${record.sampleFrequency > 0 ?
              ` · ${record.sampleFrequency} Hz` : ''}`).fontSize(13).fontColor(MUTED).width('100%')
          }
        }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18)
      }, (record: HealthRecord) => record.id)
      Text('数值仅供健康管理参考，不自动判断疾病或异常。').fontSize(13).fontColor(MUTED).width('100%')
    }
  }

  @Builder
  CareContent() {
    if (this.careLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.careMessage) { this.Notice({ message: this.careMessage, color: '#FFF0E9' }) }
    if (this.screen === 'care') {
      this.Notice({ message: '对方同意邀请并选择共享项目后，才能查看相应记录。默认不共享任何健康数据。', color: '#EAF2EA' })
      Button('添加关爱成员').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
        .enabled(!this.careLoading).onClick(() => { this.careMessage = ''; this.screen = 'care-add'; })
      Button(`关爱邀请${this.pendingInvitations().length ? ` · ${this.pendingInvitations().length} 条待处理` : ''}`)
        .width('100%').constraintSize({ minHeight: 52 }).fontColor(INK).backgroundColor(Color.White)
        .enabled(!this.careLoading).onClick(() => { this.careMessage = ''; this.screen = 'care-invitations'; })
      Button('共享管理').width('100%').constraintSize({ minHeight: 52 }).fontColor(INK).backgroundColor(Color.White)
        .enabled(!this.careLoading).onClick(() => { this.careMessage = ''; this.screen = 'care-sharing'; })
      if (this.careInvitationError) { this.Notice({ message: this.careInvitationError, color: '#FFF0E9' }) }
      Text('关爱成员').fontSize(21).fontWeight(FontWeight.Bold).width('100%')
      if (this.careMemberError) { this.Notice({ message: this.careMemberError, color: '#FFF0E9' }) }
      else if (!this.careLoading && this.careMembers.length === 0) { this.Notice({ message: '暂无关爱成员。可通过手机号邀请家人。' }) }
      ForEach(this.careMembers, (member: CareMember) => {
        Button(`${member.name}${member.mobile ? `\n${member.mobile}` : ''}\n查看已授权的健康记录 ›`)
          .width('100%').padding(18).constraintSize({ minHeight: 80 }).fontSize(17).fontColor(INK).backgroundColor(Color.White)
          .type(ButtonType.Normal).borderRadius(18).labelStyle({ maxLines: 8 })
          .onClick(() => this.openCareMember(member)).id(`care_member_${member.relationId}`)
      }, (member: CareMember) => String(member.relationId))
      Button('刷新关爱列表').width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White)
        .enabled(!this.careLoading).onClick(() => this.refreshCare())
    } else if (this.screen === 'care-add') {
      this.Notice({ message: '邀请只向您填写的账号发送。对方接受后，还需要主动选择共享项目。' })
      TextInput({ placeholder: '请输入家人手机号', text: this.careMobile }).type(InputType.PhoneNumber)
        .fontSize(18).height(56).maxLength(20).enabled(!this.careBusy).backgroundColor(Color.White)
        .onChange((value: string) => this.careMobile = value).id('care_mobile')
      Button(this.careBusy ? '正在提交…' : '发送关爱邀请').width('100%').constraintSize({ minHeight: 52 })
        .backgroundColor(RED).enabled(!this.careBusy && this.careMobile.trim().length > 0).onClick(() => this.sendCareInvitation())
      Text('推送客户端已接入；服务端推送事件上线前，接收方仍需进入关爱邀请页刷新查看。').fontSize(14).fontColor(MUTED).width('100%')
    } else if (this.screen === 'care-invitations') {
      if (this.careInvitationError) { this.Notice({ message: this.careInvitationError, color: '#FFF0E9' }) }
      else if (!this.careLoading && this.pendingInvitations().length === 0) { this.Notice({ message: '暂无新的关爱邀请。已处理或撤销的邀请不会再次显示操作按钮。' }) }
      ForEach(this.pendingInvitations(), (invite: CareInvitation) => {
        Column({ space: 14 }) {
          Text(invite.name).fontSize(20).fontWeight(FontWeight.Bold).width('100%')
          Text(invite.mobile || `邀请人账号 ID：${invite.inviterId}`).fontSize(15).fontColor(MUTED).width('100%')
          Text('同意邀请不会自动开启健康数据共享。').fontSize(14).fontColor(MUTED).width('100%')
          Button('同意邀请').width('100%').constraintSize({ minHeight: 48 }).backgroundColor(RED)
            .enabled(!this.careBusy).onClick(() => this.respondInvitation(invite.id, true))
          Button('拒绝邀请').width('100%').constraintSize({ minHeight: 48 }).fontColor(INK).backgroundColor('#F0F1F5')
            .enabled(!this.careBusy).onClick(() => this.respondInvitation(invite.id, false))
        }.width('100%').padding(18).borderRadius(18).backgroundColor(Color.White)
      }, (invite: CareInvitation) => String(invite.id))
      Button('刷新邀请状态').width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White)
        .enabled(!this.careLoading && !this.careBusy).onClick(() => this.refreshCare())
    } else if (this.screen === 'care-sharing') {
      this.Notice({ message: '这里管理哪些关爱人可以查看您的数据。只显示您已经同意的邀请。', color: '#EAF2EA' })
      if (this.careInvitationError) { this.Notice({ message: this.careInvitationError, color: '#FFF0E9' }) }
      else if (this.sharingTargets().length === 0) { this.Notice({ message: '暂无需要授权的关爱人。收到并同意邀请后，可在此按项目设置。' }) }
      ForEach(this.sharingTargets(), (invite: CareInvitation) => {
        Button(`${invite.name}\n设置允许对方查看的项目 ›`).width('100%').constraintSize({ minHeight: 76 })
          .type(ButtonType.Normal).borderRadius(18).labelStyle({ maxLines: 8 })
          .padding(16).fontSize(17).fontColor(INK).backgroundColor(Color.White).onClick(() => this.openCareSettings(invite))
      }, (invite: CareInvitation) => String(invite.inviterId))
    } else if (this.screen === 'care-settings') {
      Text(this.careSelectedInviter.name).fontSize(22).fontWeight(FontWeight.Bold).width('100%')
      this.Notice({ message: '仅勾选的项目会共享。修改后点击保存才会生效；关闭项目并保存即可撤销。', color: '#EAF2EA' })
      if (this.careSettings.unknown.length) { this.Notice({ message: `服务端另有 ${this.careSettings.unknown.length} 项历史设置，本版保存时保持原值。` }) }
      ForEach(CARE_OPTIONS, (option: CareOption) => {
        Row({ space: 12 }) {
          Text(option.label).fontSize(18).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.careSettings.enabled.includes(option.key) })
            .selectedColor(RED).enabled(this.careSettingsReady && !this.careBusy && !this.careLoading)
            .onChange((enabled: boolean) => this.toggleCareSetting(option.key, enabled)).accessibilityText(`共享${option.label}`)
        }.width('100%').padding(16).constraintSize({ minHeight: 60 }).backgroundColor(Color.White).borderRadius(14)
      }, (option: CareOption) => option.key)
      Button(this.careBusy ? '正在保存并核对…' : '保存共享设置').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
        .enabled(this.careSettingsReady && !this.careBusy && !this.careLoading).onClick(() => this.saveCareSettings())
      Button('重新读取共享设置').width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White)
        .enabled(!this.careBusy && !this.careLoading).onClick(() => this.openCareSettings(this.careSelectedInviter))
    } else if (this.screen === 'care-member') {
      Text(this.careSelectedMember.name).fontSize(22).fontWeight(FontWeight.Bold).width('100%')
      this.Notice({ message: '来源：远程成员授权共享。此处不会混入您的本机测量，也不会生成疾病判断。' })
      TextInput({ placeholder: '日期 YYYY-MM-DD', text: this.careDateInput }).fontSize(17).height(54)
        .maxLength(10).backgroundColor(Color.White).onChange((value: string) => this.careDateInput = value)
        .enabled(!this.careLoading).accessibilityText('成员记录日期，格式年-月-日')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        Button('前一天').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White).enabled(!this.careLoading)
          .onClick(() => { this.careDateInput = shiftChinaDay(this.careDay, -1); this.loadCareMetric(); })
        Button('读取日期').constraintSize({ minHeight: 48 }).backgroundColor(RED).enabled(!this.careLoading).onClick(() => this.loadCareMetric())
        Button('后一天').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White).enabled(!this.careLoading && this.careDay < chinaDay())
          .onClick(() => { this.careDateInput = shiftChinaDay(this.careDay, 1); this.loadCareMetric(); })
      }.width('100%')
      Text(`查询日期：${this.careDay}（中国时区）`).fontSize(14).fontColor(MUTED).width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(CARE_METRICS, (spec: CareMetricSpec) => {
          Button(spec.title).width('48%').constraintSize({ minHeight: 48 }).margin({ bottom: 10 }).fontSize(16)
            .fontColor(this.careMetricKey === spec.key ? Color.White : INK).backgroundColor(this.careMetricKey === spec.key ? RED : Color.White)
            .enabled(!this.careLoading).onClick(() => { this.careMetricKey = spec.key; this.loadCareMetric(); })
        }, (spec: CareMetricSpec) => spec.key)
      }.width('100%')
      if (!this.careLoading && !this.careMessage) {
        this.Notice({ message: `${this.careMetricData.title} · ${this.careMetricData.message}`, color: this.careMetricData.state === 'ready' ? '#EAF2EA' : '#EAF1F8' })
        if (this.careMetricData.records.length > 0) {
          Text(careMetricLatest(this.careMetricData)).fontSize(17).fontWeight(FontWeight.Medium).width('100%')
          ForEach(this.careMetricData.records.slice(0, this.careRecordLimit), (record: CareRecord) => {
            Column({ space: 10 }) {
              Text(record.time).fontSize(15).fontColor(MUTED).width('100%')
              Text(careRecordText(record)).fontSize(18).fontColor(INK).width('100%')
              if (record.samples.length > 1) {
                Text(`真实波形已收到 ${record.samples.length} 点${record.frequency ? `，采样率 ${record.frequency} Hz` : '，采样率未提供'}。原生波形图仍在适配，不展示模拟波形。`)
                  .fontSize(14).fontColor(MUTED).width('100%')
              }
            }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18)
          }, (record: CareRecord) => record.id)
          if (this.careRecordLimit < this.careMetricData.records.length) {
            Button('显示更多记录').width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White)
              .onClick(() => this.careRecordLimit += 30)
          }
        }
      }
      Button('刷新当前项目').width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White)
        .enabled(!this.careLoading).onClick(() => this.loadCareMetric())
      Text('数值仅供健康管理参考，如有不适请咨询专业医务人员。').fontSize(13).fontColor(MUTED).width('100%')
    }
  }

  @Builder
  ContentPage() {
    Column() {
      Column() { this.Heading() }
        .width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 20, right: 20, top: 8 })
    Scroll() {
      Column({ space: 16 }) {
        if (this.screen === 'feature') {
          this.Notice({ message: this.detailBody })
          if (this.detailTitle === '远程关爱' && this.guest) {
            Button('前往登录').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
              .onClick(() => { this.error = ''; this.screen = 'login'; })
          }
        } else if (this.screen === 'wearable-metric') {
          this.WearableMetricContent()
        } else if (this.screen === 'health-all') {
          this.HealthAllContent()
        } else if (this.screen === 'sport-records') {
          this.SportRecordContent()
        } else if (this.screen === 'health-alerts') {
          this.HealthAlertContent()
        } else if (this.screen === 'ai-chat') {
          this.AiChatContent()
        } else if (this.screen === 'shop-home') {
          this.ShopHomeContent()
        } else if (this.screen === 'shop-product') {
          this.ShopProductContent()
        } else if (this.screen === 'messages') {
          this.MessageContent()
        } else if (this.screen === 'shop-orders') {
          this.OrderContent()
        } else if (this.screen === 'shop-payment') {
          this.PaymentContent()
        } else if (this.screen.startsWith('care')) {
          this.CareContent()
        } else if (this.screen === 'about') {
          this.AboutContent()
        } else if (this.screen === 'contact') {
          this.ContactContent()
        } else if (this.screen === 'help') {
          this.HelpContent()
        } else if (this.screen === 'permissions') {
          this.PermissionContent()
        } else if (this.screen === 'articles') {
          if (this.listLoading) { LoadingProgress().width(40).height(40).color(RED) }
          if (this.listError) {
            this.Notice({ message: this.listError, color: '#FFF0E9' })
            Button('重新加载').height(48).backgroundColor(RED).onClick(() => this.openArticles())
          } else if (!this.listLoading && this.articles.length === 0) {
            this.Notice({ message: '暂无健康百科内容' })
          }
          ForEach(this.articles, (item: Article) => {
            Button(item.title || '健康百科').width('100%').constraintSize({ minHeight: 56 })
              .padding(16).fontSize(17).fontColor(INK).backgroundColor(Color.White)
              .onClick(() => this.openArticle(String(item.id ?? ''), item.title || '健康百科', false))
          }, (item: Article) => String(item.id))
        } else {
          if (this.articleLoading) { LoadingProgress().width(40).height(40).color(RED) }
          if (this.articleError) {
            this.Notice({ message: this.articleError, color: '#FFF0E9' })
            Button('重新加载内容').constraintSize({ minHeight: 48 }).backgroundColor(RED)
              .onClick(() => this.openArticle(this.selectedArticleId, this.articleTitle, this.selectedAgreement))
              .id('retry_article')
          }
          ForEach(this.articleContent, (block: ArticleBlock) => {
            if (block.kind === 'text') {
              Text(block.text).fontSize(16).lineHeight(26).fontColor(INK).width('100%').copyOption(CopyOptions.InApp)
            } else if (block.kind === 'image') {
              ArticleImage({ source: block.url, description: block.text })
            } else {
              this.Notice({ message: '此配图地址暂不支持安全加载，文字内容仍可阅读。' })
            }
          }, (block: ArticleBlock) => `${this.selectedArticleId}-${block.id}-${block.url}`)
        }
      }.width('100%').constraintSize({ maxWidth: 720 }).padding(20)
    }.width('100%').layoutWeight(1).align(Alignment.Top)
    }.width('100%').height('100%')
  }

  build() {
    Column() {
      if (this.screen === 'login') { this.Login() }
      else if (this.screen === 'home') { this.Home() }
      else { this.ContentPage() }
    }.width('100%').height('100%').backgroundColor(BG)
  }
}
