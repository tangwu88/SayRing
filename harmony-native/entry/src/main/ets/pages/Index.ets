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

const RED: string = '#D7082E';
const INK: string = '#1C1D29';
const MUTED: string = '#747783';
const BG: string = '#F6F7FB';

interface NoticeOptions { message: string; color?: string; }

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
  private careGeneration: number = 0;
  private previousScreen: string = 'login';
  private pageGeneration: number = 0;
  private contentGeneration: number = 0;
  private selectedArticleId: string = '';
  private selectedAgreement: boolean = false;
  private readonly metrics: string[] = ['心率', '血压', '血氧', '血糖', '体温', '睡眠', 'HRV', '心电', '身体成分', '血液成分'];

  aboutToAppear(): void { this.restoreLogin(); }
  onPageShow(): void { this.consumeNotificationRoute(); }
  aboutToDisappear(): void { ++this.pageGeneration; ++this.contentGeneration; ++this.careGeneration; }

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
      this.previousScreen = 'home';
      this.detailTitle = '健康预警';
      this.detailBody = '已收到健康预警通知。原生鸿蒙端仍需服务端开放预警列表接口后，才能读取并展示对应事件；不会根据普通测量值自行诊断。';
      this.screen = 'feature';
    }
  }

  private async openOrders(): Promise<void> {
    if (this.guest) { this.showFeature('商城订单', '请先登录赛电账号，再查看订单与支付状态。'); return; }
    this.screen = 'shop-orders'; this.orderLoading = true; this.paymentMessage = ''; this.orders = [];
    try { this.orders = await saydianApi.shopOrders(); }
    catch (error) { this.paymentMessage = (error as Error).message || '订单暂时无法加载'; }
    finally { this.orderLoading = false; }
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
    if (this.screen === 'shop-payment') { this.screen = 'shop-orders'; this.paymentMessage = ''; return; }
    if (this.screen === 'shop-orders' || this.screen === 'messages') { this.screen = 'home'; return; }
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
      this.screen === 'messages' || this.screen.startsWith('shop-') || this.screen.startsWith('care')) {
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
        this.screen === 'shop-orders' ? '我的订单' : this.screen === 'shop-payment' ? '支付收银台' :
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
        this.Notice({ message: '原生鸿蒙开发验证版\n已开放登录、首页、健康百科、远程关爱、消息推送和订单支付客户端链路。正式推送、支付仍需服务端和鸿蒙正式应用身份配合。' })
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
          Text('让健康信息更直观\n让日常管理更轻松').fontSize(15).fontColor(INK).lineHeight(23)
          Button('查看适配进度').fontSize(15).height(46).backgroundColor(RED).width('100%')
            .onClick(() => this.showFeature('原生适配进度', '已接入：账号登录、个人资料只读、健康百科、远程关爱、消息推送客户端、商城订单与鸿蒙系统支付客户端。\n\n待平台或服务端配置：极光鸿蒙包名与 Server key、harmony 推送设备登记、未读数、鸿蒙微信/支付宝签名参数。\n\n待适配：AI 对话、手表蓝牙、健康同步、测量和在线升级。'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').padding(14).borderRadius(24).backgroundColor('#FFF1F2')
      Row({ space: 10 }) {
        Button('远程关爱').layoutWeight(1).height(52).fontColor(INK).backgroundColor('#FFE8ED')
          .onClick(() => this.openCare()).id('family_care')
        Button('健康百科').layoutWeight(1).height(52).fontColor(INK).backgroundColor('#FFF0CC')
          .onClick(() => this.openArticles()).id('health_articles')
      }.width('100%')
      Row({ space: 10 }) {
        Button('商城订单').layoutWeight(1).height(52).fontColor(INK).backgroundColor('#EAF1F8')
          .onClick(() => this.openOrders()).id('health_orders')
        Button('消息通知').layoutWeight(1).height(52).fontColor(INK).backgroundColor('#EAF2EA')
          .onClick(() => this.openMessages()).id('health_notifications')
      }.width('100%')
      if (this.profileError) { this.Notice({ message: this.profileError, color: '#FFF0E9' }) }
      Row() {
        Text('健康数据').fontSize(25).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
        Text(`${new Date().getMonth() + 1}月${new Date().getDate()}日`).fontSize(15).fontColor(MUTED)
      }.width('100%')
      Button('手表连接功能适配中').height(54).width('100%').fontSize(17).fontColor('#32648B')
        .backgroundColor('#E5EFF9').onClick(() => this.tab = 1).id('connect_watch_notice')
      Text('尚未接入手表，以下项目暂无本机记录。').fontSize(14).fontColor(MUTED).width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.metrics, (metric: string) => {
          Column({ space: 9 }) {
            Text(metric).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
            Text('—').fontSize(28).fontColor(MUTED).width('100%')
            Text('暂无记录').fontSize(13).fontColor(MUTED).width('100%')
          }.width('48%').padding(18).margin({ bottom: 12 }).backgroundColor(Color.White).borderRadius(20)
            .onClick(() => this.showFeature(`${metric}记录`, `当前鸿蒙版本尚未接入手表健康同步，因此没有${metric}记录。\n\n没有真实数据时不绘制趋势，不生成测量结果，不将其他账号或设备的数据用作本机数据。`))
            .accessibilityText(`${metric}，暂无记录，手表同步功能尚未适配`)
        }, (metric: string) => metric)
      }.width('100%')
      this.Notice({ message: '测量结果仅供健康管理参考，如有不适请咨询专业医务人员。', color: '#EAF2EA' })
    }.width('100%').padding(20)
  }

  @Builder
  DeviceHome() {
    Column({ space: 20 }) {
      Text('我的设备').fontSize(28).fontWeight(FontWeight.Bold).width('100%').fontColor(INK)
      Text('原生鸿蒙蓝牙正在适配').fontSize(22).fontWeight(FontWeight.Medium).fontColor(INK)
      this.Notice({ message: '本轮没有连接附近手表，也不会抢占安卓或苹果手机的蓝牙连接。' })
      this.Notice({ message: 'Vep：Veepoo\nYuc：Yucheng（名称包含 W8 的系列）\n\n厂商鸿蒙 SDK 及原生桥接验收前，不开放扫描、测量、同步、表盘写入和固件升级。' })
      Button('返回健康首页').width('100%').height(50).backgroundColor(RED).onClick(() => this.tab = 0)
    }.width('100%').padding(24)
  }

  @Builder
  MineHome() {
    Column({ space: 18 }) {
      Text('我的').fontSize(28).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      Image($r('app.media.app_icon')).width(72).height(72).borderRadius(36)
      Text(this.guest ? '暂未登录' : this.displayName).fontSize(23).fontWeight(FontWeight.Bold).fontColor(INK)
        .width('100%').textAlign(TextAlign.Center).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.guest) {
        Button('登录赛电账号').width('100%').height(52).backgroundColor(RED)
          .onClick(() => { this.error = ''; this.screen = 'login'; }).id('go_login')
      } else {
        this.Notice({ message: `昵称：${profileName(this.profile) || this.displayName}\n生日：${profileField(this.profile.birthday)}\n身高：${profileField(this.profile.height, ' cm')}\n体重：${profileField(this.profile.weight, ' kg')}` })
        Text('以上资料来自当前账号服务端，仅查看，不修改。').fontSize(13).fontColor(MUTED)
        if (this.profileUpdatedAt) {
          Text(`最近读取 ${this.profileUpdatedAt}`).fontSize(13).fontColor(MUTED)
        }
        if (this.profileError) { this.Notice({ message: this.profileError, color: '#FFF0E9' }) }
        Button(this.profileLoading ? '正在读取资料…' : '刷新个人资料').width('100%').height(50)
          .fontColor(RED).backgroundColor(Color.White).enabled(!this.profileLoading && !this.busy)
          .onClick(() => this.refreshProfile()).id('refresh_profile')
        Button('消息与推送').width('100%').height(50).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.openMessages()).id('mine_messages')
        Button('我的订单与支付').width('100%').height(50).fontColor(INK).backgroundColor(Color.White)
          .onClick(() => this.openOrders()).id('mine_orders')
        Button(this.busy ? '正在退出…' : '退出本机登录').width('100%').height(50).backgroundColor(RED)
          .enabled(!this.busy).onClick(() => this.signOut()).id('logout')
      }
      Button('用户协议').width('100%').height(48).fontColor(INK).backgroundColor(Color.White)
        .onClick(() => this.openArticle('2', '用户协议', true))
      Button('隐私政策').width('100%').height(48).fontColor(INK).backgroundColor(Color.White)
        .onClick(() => this.openArticle('3', '隐私政策', true))
      this.Notice({ message: '赛电鸿蒙 0.1.3 · 原生开发验证版\n推送与支付的正式能力以服务端和鸿蒙平台配置状态为准。' })
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
            .fontColor(this.tab === index ? RED : MUTED).backgroundColor(Color.Transparent)
            .onClick(() => this.tab = index).id(`tab_${index}`)
        })
      }.width('100%').backgroundColor(Color.White)
    }.height('100%').width('100%')
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
        } else if (this.screen === 'messages') {
          this.MessageContent()
        } else if (this.screen === 'shop-orders') {
          this.OrderContent()
        } else if (this.screen === 'shop-payment') {
          this.PaymentContent()
        } else if (this.screen.startsWith('care')) {
          this.CareContent()
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
