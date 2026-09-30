import { ApiError, MemberProfile, Article, ArticleBlock, Session,
  canSubmitLogin, profileName, profileField, articleBlocks } from '../model/Contracts';
import { saydianApi } from '../services/SaydianApi';
import { appDisplayService } from '../services/AppDisplayService';
import { ArticleImage } from '../components/ArticleImage';
import { CareMember, CareInvitation, CareShareSettings, CareMetric, CareRecord, CareField, CareOption,
  chinaDay, chinaDaySeconds, shiftChinaDay, careMetricLatest, careRecordText, careInvitationFallback, careInvitationNeedsConfirmation,
  careGroupOptions, toggleCareGroup } from '../model/CareContracts';
import { common, Configuration } from '@kit.AbilityKit';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { pushErrorMessage, paymentErrorMessage } from '../model/PushPaymentContracts';
import type { PaymentProvider, ShopOrder } from '../model/PushPaymentContracts';
import { isPaymentTimeout } from '../model/PaymentWatchdog';
import { harmonyPush } from '../services/HarmonyPushService';
import { CARE_ARRIVAL_REVISION, NOTIFICATION_REVISION, PENDING_NOTIFICATION_ROUTE, notificationMatchesOwner } from '../services/NotificationNavigation';
import { careNotifications } from '../services/CareNotificationService';
import { careInboxUnread, mergeCareInbox } from '../model/ForegroundCareNotifications';
import {
  HealthRecord, HealthValue, MeasurementState, SportSessionState, WearableConnectionPhase, WearableDevice, WearableDial,
  WearableMetricKey, WearableSnapshot, WearableSportMode, batteryText, emptyMeasurement, emptySportSession,
  emptyWearableSnapshot, healthRecordText, latestMetricRecord, sportModeLabel, sportRoutePolyline,
  wearableIdentifierText, wearableModelText, WEARABLE_SCAN_TIMEOUT_MS
} from '../model/WearableContracts';
import { vepWearable, WearableServiceListener } from '../services/VepWearableService';
import { sameHealthSession } from '../model/HealthUpload';
import { AI_USER_MESSAGE_MAX_LENGTH, AiChatMessage, AppUpdateInfo, ShopCategory, ShopHome,
  ShopProduct } from '../model/ExperienceContracts';
import { appUpdateService, HARMONY_VERSION_CODE, HARMONY_VERSION_NAME } from '../services/AppUpdateService';
import { WECHAT_AUTH_RESULT_KEY, parseWechatAuthResult } from '../model/WechatAuthContracts';
import { wechatAuth } from '../services/WechatAuthService';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { DisplayUnits, ProfileDraft, FEEDBACK_TYPES, defaultDisplayUnits, displayHealthValue,
  displayNumber, feedbackError, profileDraftError } from '../model/DisplayPreferences';
import { displayPreferenceStore } from '../services/DisplayPreferenceStore';
import { APP_LOCALES, APP_LANGUAGE_NAMES, appText, formatAppText } from '../model/GlobalLocale';
import { appLocaleStore } from '../services/AppLocaleStore';
import { AuthChannel, GlobalAuthCapabilities, PHONE_COUNTRIES, PhoneCountry,
  emptyAuthCapabilities, globalRegistrationValidation, globalUnverifiedRegistrationValidation,
  normalizeIdentifier, validGlobalPassword } from '../model/GlobalAuth';
import { GLOBAL_WECHAT_ENABLED, GLOBAL_PUSH_ENABLED } from '../model/GlobalConfiguration';
import { GlobalHealthReport, GlobalReportProfile, GlobalReportEligibility, GlobalAnalysisDocument,
  reportGenerationBlock } from '../model/GlobalHealthReports';
import { saveReportPdf } from '../services/ReportPdfExport';
import { ShippingAddress, InboxMessage, ArticleCategory, orderStatusLabel, orderMatchesFilter } from '../model/AccountPageContracts';
import { ProductDetail, ShopSku, ShopLine, ShopSelection, CheckoutPreview, OrderDetail, Shipment, ShipmentTrace,
  commerceMoney, commerceCents, purchaseError, checkoutError, orderHeading, orderExplanation } from '../model/CommerceContracts';
import { SupportConfig, emptySupportConfig } from '../model/SupportConfig';

import { AddressDraft, RegionCatalog, RegionChoice, emptyAddressDraft, copyAddressDraft, emptyRegions, parseRegions,
  addressRegionChoices, selectAddressRegion, addressValidation } from '../model/AddressForm';
import { PermissionRow, readPermissionRows, openPermissionSetting } from '../services/PermissionPresentation';
import { TrendPeriod, TrendPoint, TrendWindow, TrendSeries, TrendSummary, localDateKey, trendWindow, shiftTrendDay,
  trendRecords, trendFieldNames, trendSeries, trendSummary, spreadChartX, spreadChartPoints, spreadChartIndex,
  plotSeries, waveformPoints } from '../model/HealthTrend';
import { SummaryLabel, pageLayout, controlHeight, careDaySummary, waveformPageCount, waveformPageLabel } from '../model/PagePresentation';
import { dialRenderKey, deviceRenderKey } from '../model/DeviceRenderKeys';
import { vepDeviceSettings } from '../services/VepDeviceSettingsAdapter';
import { WatchAlarm, WatchUnitField, WatchUnits, alarmDraftError, alarmRepeatText, copyWatchAlarm,
  emptyWatchUnits, newWatchAlarm, refreshSummaryOnSettingsReturn, supportedWatchUnit, watchUnitChoiceLabel } from '../model/DeviceSettingsTransactions';
import { vepDeviceFeatures } from '../services/VepDeviceFeatureAdapter';
import { harmonyCamera } from '../services/HarmonyCameraController';
import { WatchAssessmentSetting, WatchAutoMeasureSetting, WatchContact, WatchDeviceFeatureKey,
  WatchDeviceFeatureSpec, WatchNotificationSetting, WatchPhoneState, WatchPhotoDialProfile, WatchReminder,
  WatchScreenSetting, WatchWeatherSetting, WatchWorldClock, emptyPhoneState, emptyPhotoDialProfile,
  emptyScreenSetting, visibleWatchDeviceFeatures, watchContactError, watchDeviceFeatureSupported } from '../model/DeviceFeatureContracts';

const RED: string = '#D20B27';
const RED_DARK: string = '#980018';
const INK: string = '#171B2B';
const MUTED: string = '#5F6675';
const BG: string = '#F5F7FA';
const SURFACE: string = '#FFFFFF';
const SURFACE_ALT: string = '#F8FAFC';
const LINE: string = '#DDE3EC';
const OUTLINE: string = '#98A2B3';
const RED_SOFT: string = '#FFE8EC';
const GOLD_SOFT: string = '#FFF6DE';
const BLUE_SOFT: string = '#EAF1FF';
const GREEN_SOFT: string = '#EAF6ED';
const BLUE: string = '#2467A6';
const TECH_BLUE: string = '#316EF5';
const GREEN: string = '#287A3B';
const GOLD: string = '#705300';
const CARD_SHADOW: string = '#17151B2B';

interface CommerceLineProps { line: ShopLine; }
interface CommerceAmountProps { label: string; amount: number; emphasis?: boolean; }
interface NoticeOptions { message: string; color?: string; }
interface WearableMetricSpec { key: WearableMetricKey; title: string; }
interface PageRowOptions { title: string; subtitle?: string; icon: Resource; action: () => void; id?: string; }
interface StateCardOptions { title: string; detail?: string; icon?: Resource; green?: boolean; }
interface CareGroupView { daily: boolean; }
interface DeviceActionOptions { title: string; icon: Resource; color: string; background: string; action: () => void; id: string; }
interface WatchUnitOptions { title: string; field: WatchUnitField; value: number; }
interface DialRowProps { dial: WearableDial; index: number; }
interface WorldClockPreset { city: string; utcOffsetMinutes: number; }

@Entry
@Component
struct Index {
  @StorageLink(PENDING_NOTIFICATION_ROUTE)
  @Watch('pendingNotificationChanged')
  private pendingNotificationRoute: string = '';
  @StorageLink(NOTIFICATION_REVISION)
  @Watch('notificationArrived')
  private notificationRevision: number = 0;
  @StorageLink(CARE_ARRIVAL_REVISION)
  @Watch('careInvitationArrived')
  private careArrivalRevision: number = 0;
  @StorageLink(WECHAT_AUTH_RESULT_KEY)
  @Watch('wechatAuthChanged')
  private wechatAuthResult: string = '';
  @State private screen: string = 'login';
  @State private pageWidth: number = 390;
  @State private systemFontScale: number = 1;
  @State private tab: number = 0;
  @State private account: string = '';
  @State private appLocale: string = 'en';
  @State private authChannel: AuthChannel = 'email';
  @State private authCountry: string = 'US';
  @State private capabilities: GlobalAuthCapabilities = emptyAuthCapabilities();
  @State private authCapabilitiesBusy: boolean = true;
  @State private globalReports: GlobalHealthReport[] = [];
  @State private globalReportParagraphs: string[] = [];
  @State private globalReportsBusy: boolean = false;
  @State private globalReportsError: string = '';
  private globalReportsGeneration: number = 0;
  @State private hideAiContent: boolean = true;
  private stopDisplayObserver: (() => void) | undefined = undefined;
  private aiChatGeneration: number = 0;
  @State private globalReportProfile: GlobalReportProfile | undefined = undefined;
  @State private globalReportEligibility: GlobalReportEligibility | undefined = undefined;
  @State private globalAnalysisParagraphs: string[] = [];
  @State private globalAnalysisDocument: GlobalAnalysisDocument | undefined = undefined;
  @State private globalAnalysisAccepted: boolean = false;
  @State private password: string = '';
  @State private accepted: boolean = false;
  @State private registerMobile: string = '';
  @State private registerCode: string = '';
  @State private registerChallengeId: string = '';
  @State private registerPassword: string = '';
  @State private registerConfirmation: string = '';
  @State private registerAccepted: boolean = false;
  @State private registerError: string = '';
  @State private smsBusy: boolean = false;
  @State private smsCountdown: number = 0;
  @State private busy: boolean = false;
  @State private restoring: boolean = true;
  @State private error: string = '';
  @State private profileError: string = '';
  @State private profileLoading: boolean = false;
  @State private profileUpdatedAt: string = '';
  @State private logoutFailed: boolean = false;
  @State private profile: MemberProfile = {};
  @State private displayUnits: DisplayUnits = defaultDisplayUnits();
  @State private preferenceError: string = '';
  @State private formMessage: string = '';
  @State private formBusy: boolean = false;
  @State private editNickname: string = '';
  @State private editGender: number = 0;
  @State private editBirthday: string = '';
  @State private editHeight: string = '';
  @State private editWeight: string = '';
  @State private editAvatarUri: string = '';
  @State private avatarPicking: boolean = false;
  @State private feedbackType: number = 0;
  @State private feedbackContent: string = '';
  @State private feedbackContact: string = '';
  @State private expandedFaq: number = -1;
  @State private contactMessage: string = '';
  @State private supportConfig: SupportConfig = emptySupportConfig();
  @State private supportLoading: boolean = false;
  @State private supportError: string = '';
  private supportGeneration: number = 0;
  @State private addresses: ShippingAddress[] = [];
  @State private addressDraft: AddressDraft = emptyAddressDraft();
  @State private addressRegions: RegionCatalog = emptyRegions();
  @State private regionsLoading: boolean = false;
  @State private accountPageLoading: boolean = false;
  @State private accountPageError: string = '';
  @State private inbox: InboxMessage[] = [];
  private serverInbox: InboxMessage[] = [];
  private serverUnread: number | undefined = undefined;
  private inboxGeneration: number = 0;
  private unreadGeneration: number = 0;
  @State private inboxLoading: boolean = false;
  @State private inboxError: string = '';
  @State private permissionRows: PermissionRow[] = [];
  @State private permissionError: string = '';
  @State private resetMobile: string = '';
  @State private resetCode: string = '';
  @State private resetChallengeId: string = '';
  @State private resetPassword: string = '';
  @State private resetConfirmation: string = '';
  @State private displayName: string = '';
  @State private guest: boolean = true;
  @State private articleTitle: string = '';
  @State private articleContent: ArticleBlock[] = [];
  @State private articleLoading: boolean = false;
  @State private articleError: string = '';
  @State private articles: Article[] = [];
  @State private articleCategories: ArticleCategory[] = [];
  @State private articleCategoryId: number = 0;
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
  @State private selectedCareRecord: CareRecord | undefined = undefined;
  @State private careWaveformSegment: number = 0;
  @State private recordChartWidth: number = 280;
  @State private dialBusy: boolean = false;
  @State private dialMessage: string = '';
  @State private settingsBusy: boolean = false;
  @State private settingsMessage: string = '';
  @State private watchUnits: WatchUnits = emptyWatchUnits();
  @State private watchAlarms: WatchAlarm[] = [];
  @State private deviceEditorBusy: boolean = false;
  @State private deviceSettingsWriting: boolean = false;
  @State private deviceEditorLoaded: boolean = false;
  @State private deviceEditorMessage: string = '';
  @State private watchAlarmDraft: WatchAlarm = newWatchAlarm();
  private watchAlarmOriginal: WatchAlarm | undefined = undefined;
  private deviceEditorGeneration: number = 0;
  @State private selectedDeviceFeature: WatchDeviceFeatureKey = 'notifications';
  @State private deviceFeatureBusy: boolean = false;
  @State private deviceFeatureWriting: boolean = false;
  @State private deviceFeatureLoaded: boolean = false;
  @State private deviceFeatureMessage: string = '';
  @State private watchPhoneState: WatchPhoneState = emptyPhoneState();
  @State private watchContacts: WatchContact[] = [];
  @State private watchContactDraft: WatchContact = { id: 0, name: '', phone: '', sos: false };
  @State private watchNotifications: WatchNotificationSetting[] = [];
  @State private watchWeather: WatchWeatherSetting = { enabled: false, celsius: true };
  @State private watchWorldClocks: WatchWorldClock[] = [];
  @State private watchReminders: WatchReminder[] = [];
  @State private watchAutoMeasures: WatchAutoMeasureSetting[] = [];
  @State private watchAssessments: WatchAssessmentSetting[] = [];
  @State private watchScreen: WatchScreenSetting = emptyScreenSetting();
  @State private watchPhotoDial: WatchPhotoDialProfile = emptyPhotoDialProfile();
  @State private photoDialUri: string = '';
  @State private photoDialProgress: number = 0;
  @State private cameraRemoteEnabled: boolean = false;
  @State private cameraRemoteMessage: string = '';
  @State private cameraReady: boolean = false;
  @State private cameraCapturing: boolean = false;
  @State private cameraLastPhotoUri: string = '';
  private cameraSurfaceId: string = '';
  private cameraController: XComponentController = new XComponentController();
  private deviceFeatureGeneration: number = 0;
  @State private careOverview: CareMetric[] = [];
  @State private careUpdatedAt: string = '';
  @State private notificationCount: number = -1;
  @State private pushBusy: boolean = false;
  @State private pushStatus: string = '尚未检查通知状态';
  @State private orders: ShopOrder[] = [];
  @State private orderFilter: number = 99;
  @State private orderLoading: boolean = false;
  private orderGeneration: number = 0;
  @State private paymentBusy: boolean = false;
  @State private paymentMessage: string = '';
  @State private selectedOrder: ShopOrder = { id: 0, number: '', amountCents: 0, status: 0, summary: '' };
  @State private selectedProvider: PaymentProvider = 'wechat';
  @State private wearableDevices: WearableDevice[] = [];
  @State private wearablePhase: WearableConnectionPhase = 'idle';
  @State private wearableMessage: string = '尚未连接戒指';
  @State private wearableSnapshot: WearableSnapshot = emptyWearableSnapshot();
  @State private wearableMeasurement: MeasurementState = emptyMeasurement();
  @State private localSportRecords: HealthRecord[] = [];
  @State private sportLoading: boolean = false;
  @State private sportError: string = '';
  @State private sportSession: SportSessionState = emptySportSession();
  @State private selectedSportMode: WearableSportMode = 'running';
  @State private sportActionBusy: boolean = false;
  @State private sportClock: number = 0;
  @State private sportRouteWidth: number = 280;
  private sportGeneration: number = 0;
  private sportTimer: number = -1;
  @State private selectedWearableMetric: WearableMetricKey = 'heart';
  @State private trendPeriod: TrendPeriod = 'day';
  @State private trendDay: string = localDateKey();
  @State private trendField: string = '';
  @State private trendData: HealthRecord[] = [];
  @State private trendLoading: boolean = false;
  @State private trendError: string = '';
  @State private trendReadout: string = '';
  @State private trendChartWidth: number = 280;
  @State private allTrendRecords: boolean = false;
  @State private trendRecordPage: number = 0;
  @State private selectedHealthRecord: HealthRecord | undefined = undefined;
  @State private waveformSegment: number = 0;
  private trendGeneration: number = 0;
  private trendReturnScreen: string = 'home';
  @State private aiMessages: AiChatMessage[] = [];
  @State private aiInput: string = '';
  @State private aiSessionId: string = '';
  @State private aiBusy: boolean = false;
  @State private aiError: string = '';
  @State private shopHome: ShopHome = { bannerUrl: '', categories: [] };
  @State private shopCategoryIndex: number = 0;
  @State private shopKeyword: string = '';
  @State private shopLoading: boolean = false;
  @State private shopError: string = '';
  @State private selectedProduct: ShopProduct = { id: 0, name: '', picture: '', price: '0.00', stock: 0 };
  @State private productDetail: ProductDetail | undefined = undefined;
  @State private selectedSkuIndex: number = 0;
  @State private purchaseQuantity: number = 1;
  @State private purchaseSheet: boolean = false;
  @State private purchaseToCart: boolean = false;
  @State private commerceLoading: boolean = false;
  @State private commerceBusy: boolean = false;
  @State private commerceError: string = '';
  @State private cartLines: ShopLine[] = [];
  @State private cartSelection: number[] = [];
  @State private checkoutItems: ShopSelection[] = [];
  @State private checkoutPreview: CheckoutPreview | undefined = undefined;
  @State private checkoutAddress: ShippingAddress | undefined = undefined;
  @State private checkoutPoints: string = '0';
  @State private checkoutMessage: string = '';
  @State private checkoutAttempted: boolean = false;
  private checkoutFromCart: boolean = false;
  @State private selectingCheckoutAddress: boolean = false;
  @State private orderDetail: OrderDetail | undefined = undefined;
  @State private shipments: Shipment[] = [];
  @State private refundLine: ShopLine | undefined = undefined;
  @State private refundType: number = 0;
  @State private refundAmount: string = '';
  @State private refundReason: string = '';
  @State private refundAttempted: boolean = false;
  private commerceOrderId: number = 0;
  @State private updateBusy: boolean = false;
  @State private updateStatus: string = '点击检查是否有新版本';
  @State private updateInfo: AppUpdateInfo = { latestVersion: '', latestBuild: 0,
    minimumSupportedBuild: 0, releaseNotes: '', destinationUrl: '', hasUpdate: false, required: false };
  private careGeneration: number = 0;
  private environmentCallbackId: number = -1;
  private previousTab: number = 0;
  private pageGeneration: number = 0;
  private contentGeneration: number = 0;
  private careSummaryGeneration: number = 0;
  private careSummaryUpdatedAt: number = 0;
  private selectedArticleId: string = '';
  private selectedAgreement: boolean = false;
  private smsTimer: number = -1;
  private innerParents: Map<string, string> = new Map();
  private scanCountdownController: TextTimerController = new TextTimerController();
  private homeScroller: Scroller = new Scroller();
  private contentScroller: Scroller = new Scroller();
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
  private readonly worldClockPresets: WorldClockPreset[] = [
    { city: '北京', utcOffsetMinutes: 480 }, { city: '东京', utcOffsetMinutes: 540 },
    { city: '伦敦', utcOffsetMinutes: 0 }, { city: '巴黎', utcOffsetMinutes: 60 },
    { city: '纽约', utcOffsetMinutes: -300 }, { city: '洛杉矶', utcOffsetMinutes: -480 }
  ];

  aboutToAppear(): void {
    appDisplayService.attachContext(this.uiContext());
    this.stopDisplayObserver = appDisplayService.state.observe((hidden: boolean) => this.applyAiDisplay(hidden));
    appDisplayService.refresh();
    this.refreshLayoutScale();
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.environmentCallbackId = this.uiContext().getApplicationContext().on('environment', {
      onConfigurationUpdated: (configuration: Configuration) => {
        this.systemFontScale = pageLayout(this.pageWidth, configuration.fontSizeScale ?? 1).fontScale;
      },
      onMemoryLevel: () => {}
    });
    this.bindWearable();
    wechatAuth.attachContext(this.uiContext());
    this.restoreLogin();
    this.consumeWechatAuthResult();
    this.loadDisplayPreferences();
    this.loadAppLocale();
  }
  onPageShow(): void {
    appDisplayService.refresh();
    this.refreshLayoutScale();
    if (this.sportActive()) this.startSportClock();
    this.consumeNotificationRoute(); this.consumeWechatAuthResult();
    if (!this.guest) vepWearable.synchronizeCloud();
    if (this.screen === 'permissions') this.refreshPermissions();
    if (this.screen === 'sport-records') this.loadSportRecords();
  }
  aboutToDisappear(): void {
    this.stopDisplayObserver?.(); this.stopDisplayObserver = undefined;
    ++this.aiChatGeneration;
    ++this.pageGeneration; ++this.contentGeneration; ++this.careGeneration;
    this.clearSmsCountdown();
    this.stopSportClock();
    this.clearDeviceFeature();
    vepWearable.clearListener();
    if (this.environmentCallbackId >= 0) {
      this.uiContext().getApplicationContext().off('environment', this.environmentCallbackId).catch(() => {});
      this.environmentCallbackId = -1;
    }
  }

  private applyAiDisplay(hidden: boolean): void {
    this.hideAiContent = hidden;
    if (!hidden) return;
    ++this.aiChatGeneration; ++this.globalReportsGeneration;
    this.aiMessages = []; this.aiInput = ''; this.aiSessionId = ''; this.aiError = ''; this.aiBusy = false;
    this.globalReports = []; this.globalReportParagraphs = []; this.globalReportsBusy = false; this.globalReportsError = '';
    if (this.screen === 'ai-chat' || this.screen === 'health-reports') {
      const previous = this.innerParents.get(this.screen) ?? 'home';
      this.innerParents.delete(this.screen);
      this.screen = previous === 'ai-chat' || previous === 'health-reports' ? 'home' : previous;
    }
  }

  private pendingNotificationChanged(): void { this.consumeNotificationRoute(); }
  private careInvitationArrived(): void {
    if (this.guest || this.restoring || !careNotifications.isForeground()) return;
    this.getUIContext().getPromptAction().showToast({ message: '收到新的关爱邀请，可在消息中查看' });
  }
  private notificationArrived(): void {
    if (this.guest || this.restoring || !careNotifications.isForeground()) return;
    this.updateLocalInbox();
    this.refreshInbox();
    if (['care', 'care-invitations', 'care-sharing'].includes(this.screen) && !this.careLoading) {
      this.refreshCare();
    } else {
      this.refreshCareSummary(true);
    }
  }
  private wechatAuthChanged(): void { this.consumeWechatAuthResult(); }

  private clearCareState(): void {
    ++this.careGeneration;
    ++this.careSummaryGeneration;
    this.careSummaryUpdatedAt = 0;
    this.careMembers = []; this.careInvitations = []; this.careMobile = '';
    this.careSettings = { enabled: [], unknown: [] }; this.careSettingsReady = false;
    this.careMetricData = { key: 'heart', title: '心率', unit: '', state: 'empty', message: '', records: [] };
    this.careMessage = ''; this.careMemberError = ''; this.careInvitationError = '';
    this.careSelectedMember = { relationId: 0, memberId: 0, name: '', mobile: '' };
    this.careSelectedInviter = { id: 0, inviterId: 0, name: '', mobile: '', state: '' };
    this.careLoading = false; this.careBusy = false;
    this.careOverview = []; this.careUpdatedAt = '';
    this.selectedCareRecord = undefined; this.careWaveformSegment = 0;
  }

  private refreshLayoutScale(): void {
    this.systemFontScale = pageLayout(this.pageWidth, this.uiContext().config.fontSizeScale ?? 1).fontScale;
  }

  private singleColumn(): boolean { return pageLayout(this.pageWidth, this.systemFontScale).singleColumn; }
  private controlHeight(minimum: number = 48): number { return controlHeight(minimum, this.systemFontScale); }

  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private tr(message: string): string { return appText(message, this.appLocale); }

  private async loadAppLocale(): Promise<void> {
    try { this.appLocale = await appLocaleStore.read(this.uiContext()); }
    catch { this.appLocale = 'en'; }
    await this.loadAuthCapabilities();
  }

  private async changeAppLocale(index: number): Promise<void> {
    const next = APP_LOCALES[index];
    if (!next || next === this.appLocale) return;
    try {
      await appLocaleStore.save(next); this.appLocale = next;
      this.accepted = false; this.registerAccepted = false;
      await this.loadAuthCapabilities();
    }
    catch { this.error = 'Settings could not be saved. Please retry.'; }
  }

  private async loadAuthCapabilities(): Promise<void> {
    this.authCapabilitiesBusy = true;
    try {
      const previousVersion = this.capabilities.consentVersion;
      this.capabilities = await saydianApi.authCapabilities(this.appLocale);
      if (previousVersion && previousVersion !== this.capabilities.consentVersion) {
        this.accepted = false; this.registerAccepted = false;
      }
      if (!this.capabilities.registration.verificationRequired) {
        this.registerChallengeId = ''; this.registerCode = ''; this.clearSmsCountdown();
      }
      if (!this.capabilities.smsCountries.includes(this.authCountry) && this.phoneChoices().length) {
        this.authCountry = this.phoneChoices()[0].code;
      }
    }
    catch { this.capabilities = emptyAuthCapabilities(); }
    finally { this.authCapabilitiesBusy = false; }
  }

  private phoneChoices(): PhoneCountry[] {
    if (this.screen !== 'reset-password' &&
      (this.screen !== 'register' || !this.capabilities.registration.verificationRequired)) return PHONE_COUNTRIES;
    return PHONE_COUNTRIES.filter(country => this.capabilities.smsCountries.includes(country.code));
  }

  private async openGlobalReports(): Promise<void> {
    if (this.hideAiContent) return;
    if (this.guest) { this.screen = 'login'; return; }
    if (this.screen !== 'health-reports') this.openInnerPage('health-reports');
    const epoch = this.pageGeneration, owner = saydianApi.current()?.memberId, request = ++this.globalReportsGeneration;
    this.globalReportsBusy = true; this.globalReportsError = ''; this.globalReports = []; this.globalReportParagraphs = [];
    this.globalReportProfile = undefined; this.globalReportEligibility = undefined;
    this.globalAnalysisParagraphs = []; this.globalAnalysisDocument = undefined; this.globalAnalysisAccepted = false;
    try {
      const reports = await saydianApi.healthReports();
      if (this.hideAiContent || request !== this.globalReportsGeneration || epoch !== this.pageGeneration) return;
      if (request === this.globalReportsGeneration && epoch === this.pageGeneration && owner === saydianApi.current()?.memberId && this.screen === 'health-reports') this.globalReports = reports;
      const profile = await saydianApi.reportProfile(), eligibility = await saydianApi.reportEligibility();
      if (request === this.globalReportsGeneration && epoch === this.pageGeneration && owner === saydianApi.current()?.memberId && this.screen === 'health-reports') {
        this.globalReportProfile = profile; this.globalReportEligibility = eligibility;
      }
    } catch (error) {
      if (request === this.globalReportsGeneration && epoch === this.pageGeneration && this.screen === 'health-reports') this.globalReportsError = this.accountFormFailure(error as Error);
    } finally { if (request === this.globalReportsGeneration && epoch === this.pageGeneration) this.globalReportsBusy = false; }
  }

  private async openGlobalReport(report: GlobalHealthReport): Promise<void> {
    if (this.hideAiContent) return;
    if (this.globalReportsBusy || report.status !== 'ready') return;
    const epoch = this.pageGeneration, owner = saydianApi.current()?.memberId, request = ++this.globalReportsGeneration;
    this.globalReportsBusy = true; this.globalReportsError = ''; this.globalReportParagraphs = [];
    try {
      const paragraphs = await saydianApi.healthReportContent(report.id);
      if (request === this.globalReportsGeneration && epoch === this.pageGeneration && owner === saydianApi.current()?.memberId && this.screen === 'health-reports') this.globalReportParagraphs = paragraphs;
    } catch (error) {
      if (request === this.globalReportsGeneration && epoch === this.pageGeneration && this.screen === 'health-reports') this.globalReportsError = this.accountFormFailure(error as Error);
    } finally { if (request === this.globalReportsGeneration && epoch === this.pageGeneration) this.globalReportsBusy = false; }
  }

  private async globalReportAction(action: 'read' | 'grant' | 'revoke' | 'generate' | 'export', id: string = ''): Promise<void> {
    if (this.hideAiContent && action !== 'read' && action !== 'revoke') return;
    if (this.globalReportsBusy) return;
    const epoch = this.pageGeneration, session = saydianApi.healthSession(), request = ++this.globalReportsGeneration;
    const active = (): boolean => request === this.globalReportsGeneration && epoch === this.pageGeneration &&
      sameHealthSession(session, saydianApi.healthSession()) && this.screen === 'health-reports';
    this.globalReportsBusy = true; this.globalReportsError = '';
    try {
      if (action === 'read') {
        this.globalAnalysisDocument = undefined; this.globalAnalysisAccepted = false; this.globalAnalysisParagraphs = [];
        const document = this.globalReportProfile?.document;
        if (!document) throw new ApiError('legal_unavailable');
        const article = await saydianApi.analysisNotice(document);
        const paragraphs = articleBlocks(article.content).filter((block: ArticleBlock) => block.kind === 'text').map((block: ArticleBlock) => block.text);
        if (!paragraphs.length) throw new ApiError('legal_unavailable');
        if (active()) { this.globalAnalysisDocument = document; this.globalAnalysisParagraphs = paragraphs; }
      } else if (action === 'export') {
        const bytes = await saydianApi.exportHealthReport(id);
        if (!active()) return;
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const saved = await saveReportPdf(context, id, bytes, active);
        if (active() && saved) this.getUIContext().getPromptAction().showToast({ message: this.tr('reports_saved') });
      } else {
        if (action === 'grant') {
          if (!this.globalAnalysisAccepted || !this.globalAnalysisDocument || !this.globalAnalysisParagraphs.length) throw new ApiError('reports_consent_required');
          await saydianApi.setReportConsent(true, this.globalAnalysisDocument);
        } else if (action === 'revoke') {
          const choice = await this.getUIContext().getPromptAction().showDialog({ title: this.tr('reports_withdraw'),
            message: this.tr('reports_withdraw_notice'), buttons: [{ text: this.tr('cancel'), color: MUTED },
              { text: this.tr('reports_withdraw'), color: RED }] });
          if (choice.index !== 1 || !active()) return;
          await saydianApi.setReportConsent(false);
        } else { await saydianApi.generateHealthReport(id); }
        if (active()) await this.openGlobalReports();
      }
    } catch (error) {
      if (active()) this.globalReportsError = this.accountFormFailure(error as Error);
    } finally { if (request === this.globalReportsGeneration && epoch === this.pageGeneration) this.globalReportsBusy = false; }
  }

  private accountIdentifier(value: string): string {
    if (this.authChannel === 'email' || value.trim().startsWith('+')) return value.trim();
    const country = PHONE_COUNTRIES.find(country => country.code === this.authCountry);
    return `${country?.dialCode ?? ''}${value.trim()}`;
  }

  private async loadDisplayPreferences(): Promise<void> {
    try { this.displayUnits = await displayPreferenceStore.read(this.uiContext()); }
    catch { this.preferenceError = '单位设置暂未读取，请稍后重试'; }
  }

  private async setDisplayUnits(distance: 'km' | 'mi', temperature: 'c' | 'f'): Promise<void> {
    const next: DisplayUnits = { distance, temperature };
    try { await displayPreferenceStore.save(next); this.displayUnits = next; this.preferenceError = ''; }
    catch { this.preferenceError = '单位设置未能保存，请重试'; }
  }

  private displayRecord(record?: HealthRecord): string {
    if (!record || record.values.length === 0) return healthRecordText(record);
    return record.values.map(value => {
      const converted = displayHealthValue(value, this.displayUnits);
      return `${converted.name} ${displayNumber(converted.value)}${converted.unit}`;
    }).join(' · ');
  }

  private openInnerPage(next: string): void {
    if (next === this.screen) return;
    ++this.contentGeneration;
    this.innerParents.set(next, this.screen);
    this.formMessage = '';
    this.screen = next;
  }

  private openContact(): void {
    this.openInnerPage('contact');
    this.loadSupportConfig();
  }

  private async loadSupportConfig(): Promise<void> {
    const generation = ++this.supportGeneration;
    this.supportLoading = true; this.supportError = ''; this.contactMessage = '';
    try {
      const config = await saydianApi.supportConfig();
      if (generation !== this.supportGeneration || this.screen !== 'contact') return;
      this.supportConfig = config;
      if (!config.configured) this.supportError = config.message || '客服渠道暂时无法使用，请稍后再试';
    } catch (error) {
      if (generation === this.supportGeneration && this.screen === 'contact') {
        this.supportConfig = emptySupportConfig();
        this.supportError = (error as Error).message || '客服信息加载失败，请稍后重试';
      }
    } finally {
      if (generation === this.supportGeneration && this.screen === 'contact') this.supportLoading = false;
    }
  }

  private async callSupport(): Promise<void> {
    const phone = this.supportConfig.phone;
    if (!phone) return;
    try {
      await this.uiContext().startAbility({ action: 'ohos.want.action.dial', uri: `tel:${phone.replace(/[^+0-9]/g, '')}` });
    } catch {
      this.contactMessage = `无法打开拨号界面，请手动拨打 ${phone}`;
    }
  }

  private async copySupportAccount(): Promise<void> {
    const account = this.supportConfig.officialAccount;
    if (!account) return;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, account);
      await pasteboard.getSystemPasteboard().setData(data);
      this.contactMessage = `公众号“${account}”已复制，可前往微信搜索添加`;
    } catch {
      this.contactMessage = `复制失败，请手动搜索公众号“${account}”`;
    }
  }

  private openPasswordReset(): void {
    this.clearSmsCountdown();
    this.resetMobile = this.guest ? this.account.trim() : this.profile.mobile ?? '';
    this.resetChallengeId = ''; this.resetCode = ''; this.resetPassword = ''; this.resetConfirmation = '';
    this.openInnerPage('reset-password');
  }

  private openCareRecord(record: CareRecord): void {
    this.selectedCareRecord = record;
    this.careWaveformSegment = 0;
    this.openInnerPage('care-record');
  }

  private async openDials(): Promise<void> {
    if (!this.wearableSnapshot.connected || !this.wearableSnapshot.capabilities.dial) return;
    this.openInnerPage('device-dials');
    await this.refreshDials();
  }

  private async refreshDials(): Promise<void> {
    if (this.dialBusy || this.wearableBusy() || this.wearableMeasurement.running || this.sportActive()) return;
    const deviceKey = this.wearableSnapshot.deviceKey;
    this.dialBusy = true; this.dialMessage = '';
    try {
      const success = await vepWearable.readDials();
      if (this.wearableSnapshot.deviceKey === deviceKey && !success) this.dialMessage = this.wearableMessage || '暂时无法读取表盘，请重试';
    } finally { this.dialBusy = false; }
  }

  private async selectExistingDial(dial: WearableDial): Promise<void> {
    if (this.dialBusy || dial.selected || this.wearableBusy() || this.wearableMeasurement.running || this.sportActive()) return;
    const deviceKey = this.wearableSnapshot.deviceKey;
    if (!await this.confirmCommerce('使用此表盘？', '切换后，手表将显示所选表盘。', '使用') || deviceKey !== this.wearableSnapshot.deviceKey) return;
    this.dialBusy = true; this.dialMessage = '';
    try {
      const success = await vepWearable.setExistingDial(dial.key);
      if (deviceKey === this.wearableSnapshot.deviceKey) this.dialMessage = success ? '已切换表盘' : this.wearableMessage;
    } finally { this.dialBusy = false; }
  }

  private async openDeviceSettings(): Promise<void> {
    this.openInnerPage('device-settings');
    await this.refreshDeviceSettings();
  }

  private async refreshDeviceSettings(): Promise<boolean> {
    if (this.settingsBusy || this.wearableBusy() || this.wearableMeasurement.running || this.sportActive()) return false;
    const deviceKey = this.wearableSnapshot.deviceKey;
    this.settingsBusy = true; this.settingsMessage = '';
    try {
      const success = await vepWearable.readDeviceConfiguration();
      if (deviceKey === this.wearableSnapshot.deviceKey && !success) this.settingsMessage = this.wearableMessage || '暂时无法读取，请重试';
      return success && deviceKey === this.wearableSnapshot.deviceKey;
    } catch (error) {
      if (deviceKey === this.wearableSnapshot.deviceKey) this.settingsMessage = (error as Error).message || '暂时无法读取，请重试';
      return false;
    } finally { this.settingsBusy = false; }
  }

  private deviceFeatureSpec(): WatchDeviceFeatureSpec {
    return visibleWatchDeviceFeatures(this.wearableSnapshot.capabilities)
      .find((item: WatchDeviceFeatureSpec) => item.key === this.selectedDeviceFeature) ??
      { key: this.selectedDeviceFeature, title: '设备功能', subtitle: 'deviceSettingsSubtitle' };
  }

  private deviceFeatureIcon(feature: WatchDeviceFeatureKey): Resource {
    if (feature === 'photoDial') return $r('sys.symbol.camera_fill');
    if (feature === 'camera') return $r('sys.symbol.camera_fill');
    if (feature === 'phoneCalls') return $r('sys.symbol.phone_fill');
    if (feature === 'contacts') return $r('sys.symbol.person_2_fill');
    if (feature === 'notifications') return $r('sys.symbol.bell_fill');
    if (feature === 'weather') return $r('sys.symbol.cloud_sun_fill');
    if (feature === 'worldClock') return $r('sys.symbol.clock');
    if (feature === 'healthReminders') return $r('sys.symbol.heart_fill');
    if (feature === 'healthMonitoring') return $r('sys.symbol.waveform');
    if (feature === 'healthAssessment') return $r('sys.symbol.checkmark_shield_fill');
    return $r('sys.symbol.brightness');
  }

  private clearDeviceFeature(): void {
    ++this.deviceFeatureGeneration;
    if (this.cameraRemoteEnabled) vepDeviceFeatures.setCameraRemote(false).catch(() => {});
    vepDeviceFeatures.setCameraListener(undefined);
    harmonyCamera.stop().catch(() => {});
    this.deviceFeatureBusy = false; this.deviceFeatureWriting = false; this.deviceFeatureLoaded = false;
    this.deviceFeatureMessage = ''; this.watchPhoneState = emptyPhoneState(); this.watchContacts = [];
    this.watchContactDraft = { id: 0, name: '', phone: '', sos: false }; this.watchNotifications = [];
    this.watchWeather = { enabled: false, celsius: true }; this.watchWorldClocks = []; this.watchReminders = [];
    this.watchAutoMeasures = []; this.watchAssessments = []; this.watchScreen = emptyScreenSetting();
    this.watchPhotoDial = emptyPhotoDialProfile(); this.photoDialUri = ''; this.photoDialProgress = 0;
    this.cameraRemoteEnabled = false; this.cameraRemoteMessage = ''; this.cameraReady = false;
    this.cameraCapturing = false; this.cameraLastPhotoUri = ''; this.cameraSurfaceId = '';
  }

  private async openDeviceFeature(feature: WatchDeviceFeatureKey): Promise<void> {
    if (!this.wearableSnapshot.connected || !watchDeviceFeatureSupported(this.wearableSnapshot.capabilities, feature)) return;
    this.clearDeviceFeature(); this.selectedDeviceFeature = feature; this.openInnerPage('device-feature');
    await this.refreshDeviceFeature();
  }

  private async refreshDeviceFeature(): Promise<void> {
    if (this.deviceFeatureBusy || !this.wearableSnapshot.connected) return;
    const generation = ++this.deviceFeatureGeneration, deviceKey = this.wearableSnapshot.deviceKey;
    const feature = this.selectedDeviceFeature;
    this.deviceFeatureBusy = true; this.deviceFeatureLoaded = false; this.deviceFeatureMessage = '';
    try {
      if (feature === 'photoDial') this.watchPhotoDial = await vepDeviceFeatures.readPhotoDialProfile();
      else if (feature === 'camera') {
        vepDeviceFeatures.setCameraListener((captureRequested: boolean, message: string) => {
          if (generation !== this.deviceFeatureGeneration || this.screen !== 'device-feature') return;
          if (captureRequested) this.captureCameraPhoto(true); else this.cameraRemoteMessage = message;
        });
        this.cameraRemoteMessage = '点击开启后显示实时画面，可在手表相机页面遥控拍照';
      } else if (feature === 'phoneCalls') this.watchPhoneState = await vepDeviceFeatures.readPhoneState();
      else if (feature === 'contacts') this.watchContacts = await vepDeviceFeatures.readContacts();
      else if (feature === 'notifications') this.watchNotifications = await vepDeviceFeatures.readNotifications();
      else if (feature === 'weather') this.watchWeather = await vepDeviceFeatures.readWeather();
      else if (feature === 'worldClock') this.watchWorldClocks = await vepDeviceFeatures.readWorldClocks();
      else if (feature === 'healthReminders') this.watchReminders = await vepDeviceFeatures.readReminders();
      else if (feature === 'healthMonitoring') this.watchAutoMeasures = await vepDeviceFeatures.readAutoMeasure();
      else if (feature === 'healthAssessment') this.watchAssessments = await vepDeviceFeatures.readAssessments();
      else this.watchScreen = await vepDeviceFeatures.readScreen();
      if (generation === this.deviceFeatureGeneration && deviceKey === this.wearableSnapshot.deviceKey) {
        this.deviceFeatureLoaded = true;
        if (feature === 'photoDial' && this.watchPhotoDial.message) this.deviceFeatureMessage = this.watchPhotoDial.message;
      }
    } catch (error) {
      if (generation === this.deviceFeatureGeneration && deviceKey === this.wearableSnapshot.deviceKey) {
        this.deviceFeatureMessage = (error as Error).message || '暂时无法读取此功能，请重试';
      }
    } finally {
      if (generation === this.deviceFeatureGeneration && deviceKey === this.wearableSnapshot.deviceKey) this.deviceFeatureBusy = false;
    }
  }

  private async writeDeviceFeature(action: () => Promise<void>, successMessage: string): Promise<void> {
    if (this.deviceFeatureBusy || !this.deviceFeatureLoaded || !this.wearableSnapshot.connected) return;
    const generation = this.deviceFeatureGeneration, deviceKey = this.wearableSnapshot.deviceKey;
    this.deviceFeatureBusy = true; this.deviceFeatureWriting = true; this.deviceFeatureMessage = '';
    try {
      await action();
      if (generation === this.deviceFeatureGeneration && deviceKey === this.wearableSnapshot.deviceKey) {
        this.deviceFeatureMessage = successMessage;
      }
    } catch (error) {
      if (generation === this.deviceFeatureGeneration && deviceKey === this.wearableSnapshot.deviceKey) {
        this.deviceFeatureLoaded = false;
        this.deviceFeatureMessage = (error as Error).message || '保存结果未确认，请重新读取';
      }
    } finally {
      if (generation === this.deviceFeatureGeneration && deviceKey === this.wearableSnapshot.deviceKey) {
        this.deviceFeatureBusy = false; this.deviceFeatureWriting = false;
      }
    }
  }

  private connectWatchPhone(): void {
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchPhoneState = await vepDeviceFeatures.connectPhoneAudio();
    }, '蓝牙通话连接状态已更新');
  }

  private changeContactDraft(field: string, value: string): void {
    const draft: WatchContact = { id: this.watchContactDraft.id, name: this.watchContactDraft.name,
      phone: this.watchContactDraft.phone, sos: this.watchContactDraft.sos };
    if (field === 'name') draft.name = value; else draft.phone = value;
    this.watchContactDraft = draft;
  }

  private editWatchContact(contact?: WatchContact): void {
    this.watchContactDraft = contact ? { id: contact.id, name: contact.name, phone: contact.phone, sos: contact.sos } :
      { id: 0, name: '', phone: '', sos: false };
    this.deviceFeatureMessage = '';
  }

  private saveWatchContact(): void {
    const error = watchContactError(this.watchContactDraft);
    if (error) { this.deviceFeatureMessage = error; return; }
    const draft: WatchContact = { id: this.watchContactDraft.id, name: this.watchContactDraft.name,
      phone: this.watchContactDraft.phone, sos: this.watchContactDraft.sos };
    const expected = draft.id > 0 ? this.watchContacts.find((item: WatchContact) => item.id === draft.id) : undefined;
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchContacts = await vepDeviceFeatures.saveContact(draft, expected);
      this.watchContactDraft = { id: 0, name: '', phone: '', sos: false };
    }, '联系人已保存到手表');
  }

  private async deleteWatchContact(contact: WatchContact): Promise<void> {
    if (!await this.confirmCommerce('删除联系人？', `将从手表中删除“${contact.name}”。`, '删除')) return;
    await this.writeDeviceFeature(async (): Promise<void> => {
      this.watchContacts = await vepDeviceFeatures.deleteContact(contact);
      if (this.watchContactDraft.id === contact.id) this.watchContactDraft = { id: 0, name: '', phone: '', sos: false };
    }, '联系人已从手表删除');
  }

  private setWatchSos(contact: WatchContact): void {
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchContacts = await vepDeviceFeatures.setSosContact(contact);
    }, `${contact.name} 已设为 SOS 紧急联系人`);
  }

  private setWatchNotification(item: WatchNotificationSetting, enabled: boolean): void {
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchNotifications = await vepDeviceFeatures.setNotification(item.key, enabled);
    }, `${item.label}已${enabled ? '开启' : '关闭'}`);
  }

  private saveWatchWeather(enabled: boolean, celsius: boolean): void {
    const value: WatchWeatherSetting = { enabled: enabled, celsius: celsius };
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchWeather = await vepDeviceFeatures.saveWeather(value);
    }, '天气设置已保存到手表');
  }

  private addWatchWorldClock(preset: WorldClockPreset): void {
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchWorldClocks = await vepDeviceFeatures.addWorldClock(preset.city, preset.utcOffsetMinutes);
    }, `${preset.city}已添加到手表`);
  }

  private async deleteWatchWorldClock(clock: WatchWorldClock): Promise<void> {
    if (!await this.confirmCommerce('删除世界时钟？', `将从手表中删除“${clock.city}”。`, '删除')) return;
    await this.writeDeviceFeature(async (): Promise<void> => {
      this.watchWorldClocks = await vepDeviceFeatures.deleteWorldClock(clock);
    }, `${clock.city}已删除`);
  }

  private setWatchReminder(item: WatchReminder, enabled: boolean, deltaMinutes: number = 0): void {
    const value: WatchReminder = { id: item.id, type: item.type, label: item.label, startTime: item.startTime,
      endTime: item.endTime, enabled: enabled, sedentary: item.sedentary,
      intervalMinutes: Math.max(15, Math.min(240, item.intervalMinutes + deltaMinutes)) };
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchReminders = await vepDeviceFeatures.saveReminder(value);
    }, `${item.label}已保存`);
  }

  private setWatchAutoMeasure(item: WatchAutoMeasureSetting, enabled: boolean, deltaSteps: number = 0): void {
    const step = Math.max(1, item.minimumIntervalMinutes);
    const value: WatchAutoMeasureSetting = { feature: item.feature, label: item.label, enabled: enabled,
      minimumIntervalMinutes: item.minimumIntervalMinutes, intervalModifiable: item.intervalModifiable,
      timeSlotModifiable: item.timeSlotModifiable, startTime: item.startTime, endTime: item.endTime,
      intervalMinutes: Math.max(step, Math.min(1440, item.intervalMinutes + deltaSteps * step)) };
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchAutoMeasures = await vepDeviceFeatures.saveAutoMeasure(value);
    }, `${item.label}已保存`);
  }

  private setWatchAssessment(item: WatchAssessmentSetting, enabled: boolean): void {
    const value: WatchAssessmentSetting = { dataType: item.dataType, label: item.label, enabled: enabled };
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchAssessments = await vepDeviceFeatures.saveAssessment(value);
    }, `${item.label}已${enabled ? '开启' : '关闭'}`);
  }

  private saveWatchScreen(next: WatchScreenSetting): void {
    this.writeDeviceFeature(async (): Promise<void> => {
      this.watchScreen = await vepDeviceFeatures.saveScreen(next);
    }, '屏幕显示设置已保存到手表');
  }

  private nextWatchScreen(durationSeconds?: number, raiseToWakeEnabled?: boolean,
    raiseToWakeLevel?: number): WatchScreenSetting {
    return { durationSupported: this.watchScreen.durationSupported,
      durationSeconds: durationSeconds ?? this.watchScreen.durationSeconds,
      raiseToWakeSupported: this.watchScreen.raiseToWakeSupported,
      raiseToWakeEnabled: raiseToWakeEnabled ?? this.watchScreen.raiseToWakeEnabled,
      raiseToWakeStartTime: this.watchScreen.raiseToWakeStartTime,
      raiseToWakeEndTime: this.watchScreen.raiseToWakeEndTime,
      raiseToWakeLevel: raiseToWakeLevel ?? this.watchScreen.raiseToWakeLevel };
  }

  private setCameraRemote(enabled: boolean): void {
    const generation = this.deviceFeatureGeneration, deviceKey = this.wearableSnapshot.deviceKey;
    this.writeDeviceFeature(async (): Promise<void> => {
      if (enabled) {
        await harmonyCamera.start(this.uiContext(), this.cameraSurfaceId);
        if (generation !== this.deviceFeatureGeneration || deviceKey !== this.wearableSnapshot.deviceKey ||
          this.screen !== 'device-feature' || this.selectedDeviceFeature !== 'camera') {
          await harmonyCamera.stop();
          throw new Error('相机操作已取消');
        }
        try { await vepDeviceFeatures.setCameraRemote(true); }
        catch (error) { await harmonyCamera.stop(); throw error as Error; }
        this.cameraReady = true; this.cameraRemoteEnabled = true;
        this.cameraRemoteMessage = '相机遥控已开启，请在手表上点击拍照';
      } else {
        await vepDeviceFeatures.setCameraRemote(false);
        await harmonyCamera.stop();
        this.cameraReady = false; this.cameraRemoteEnabled = false; this.cameraCapturing = false;
        this.cameraRemoteMessage = '相机遥控已关闭';
      }
    }, enabled ? '相机遥控已开启' : '相机遥控已关闭');
  }

  private cameraSurfaceLoaded(): void {
    this.cameraSurfaceId = this.cameraController.getXComponentSurfaceId();
    try { this.cameraController.setXComponentSurfaceRotation({ lock: true }); } catch {}
  }

  private cameraSurfaceDestroyed(): void {
    this.cameraSurfaceId = ''; this.cameraReady = false; this.cameraCapturing = false;
    harmonyCamera.stop().catch(() => {});
  }

  private async captureCameraPhoto(fromWatch: boolean): Promise<void> {
    if (!this.cameraRemoteEnabled || !this.cameraReady || this.cameraCapturing) {
      if (fromWatch && !this.cameraCapturing) this.cameraRemoteMessage = '手机相机尚未准备好，请重新开启相机遥控';
      return;
    }
    const generation = this.deviceFeatureGeneration;
    this.cameraCapturing = true;
    this.cameraRemoteMessage = fromWatch ? '已收到手表指令，正在拍照并保存…' : '正在拍照并保存…';
    try {
      const uri = await harmonyCamera.capture();
      if (generation !== this.deviceFeatureGeneration || this.screen !== 'device-feature') return;
      this.cameraLastPhotoUri = uri; this.cameraRemoteMessage = '照片已保存到手机图库';
    } catch (error) {
      if (generation === this.deviceFeatureGeneration && this.screen === 'device-feature') {
        this.cameraRemoteMessage = (error as Error).message || '拍照保存失败，请重试';
      }
    } finally {
      if (generation === this.deviceFeatureGeneration) this.cameraCapturing = false;
    }
  }

  private async pickPhotoDial(): Promise<void> {
    if (this.deviceFeatureBusy || !this.deviceFeatureLoaded) return;
    this.deviceFeatureBusy = true; this.deviceFeatureMessage = '';
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1; options.isEditSupported = true;
      const selected = await new photoAccessHelper.PhotoViewPicker().select(options);
      const uri = selected.photoUris.length ? selected.photoUris[0].trim() : '';
      if (uri) { this.photoDialUri = uri; this.photoDialProgress = 0; this.deviceFeatureMessage = '照片已选择，请确认后安装到手表'; }
    } catch (error) {
      const code = Number((error as BusinessError).code ?? 0);
      if (code !== 201) this.deviceFeatureMessage = '无法读取照片，请重新选择';
    } finally { this.deviceFeatureBusy = false; }
  }

  private installPhotoDial(): void {
    if (!this.photoDialUri) { this.deviceFeatureMessage = '请先选择一张照片'; return; }
    const generation = this.deviceFeatureGeneration;
    this.photoDialProgress = 0;
    this.writeDeviceFeature(async (): Promise<void> => {
      await vepDeviceFeatures.installPhotoDial(this.photoDialUri, (progress: number, message: string) => {
        if (generation !== this.deviceFeatureGeneration) return;
        this.photoDialProgress = progress;
        if (message) this.deviceFeatureMessage = message;
      });
      this.photoDialProgress = 100;
      await vepWearable.readDials();
    }, '照片表盘已安装到手表');
  }

  private watchWorldClockOffset(minutes: number): string {
    const sign = minutes >= 0 ? '+' : '-'; const absolute = Math.abs(minutes);
    return `UTC${sign}${String(Math.floor(absolute / 60)).padStart(2, '0')}:${String(absolute % 60).padStart(2, '0')}`;
  }

  private clearDeviceEditor(): void {
    ++this.deviceEditorGeneration;
    this.watchUnits = emptyWatchUnits(); this.watchAlarms = [];
    this.deviceEditorLoaded = false; this.deviceEditorBusy = false; this.deviceSettingsWriting = false;
    this.deviceEditorMessage = ''; this.watchAlarmDraft = newWatchAlarm(); this.watchAlarmOriginal = undefined;
  }

  private async openWatchSettings(page: string): Promise<void> {
    if (this.deviceEditorBusy || !this.wearableSnapshot.connected) return;
    this.clearDeviceEditor(); this.openInnerPage(page);
    await this.refreshWatchSettings();
  }

  private async refreshWatchSettings(): Promise<void> {
    if (this.deviceEditorBusy || !this.wearableSnapshot.connected) return;
    const generation = ++this.deviceEditorGeneration;
    this.deviceEditorBusy = true; this.deviceEditorLoaded = false; this.deviceEditorMessage = '';
    try {
      if (this.screen === 'device-units') {
        const units = await vepDeviceSettings.readUnits();
        if (generation === this.deviceEditorGeneration) this.watchUnits = units;
      } else {
        const alarms = await vepDeviceSettings.readAlarms();
        if (generation === this.deviceEditorGeneration) this.watchAlarms = alarms;
      }
      if (generation === this.deviceEditorGeneration) this.deviceEditorLoaded = true;
    } catch (error) {
      if (generation === this.deviceEditorGeneration) this.deviceEditorMessage = (error as Error).message || '暂时无法读取，请重试';
    } finally { if (generation === this.deviceEditorGeneration) this.deviceEditorBusy = false; }
  }

  private async setWatchUnit(field: WatchUnitField, value: number): Promise<void> {
    if (this.deviceEditorBusy || !this.deviceEditorLoaded) return;
    const expected = this.watchUnits[field];
    if (!supportedWatchUnit(expected) || expected === value) return;
    const generation = this.deviceEditorGeneration;
    this.deviceEditorBusy = true; this.deviceSettingsWriting = true; this.deviceEditorMessage = '';
    try {
      const units = await vepDeviceSettings.setUnit(field, value, expected);
      if (generation === this.deviceEditorGeneration) {
        this.watchUnits = units; this.deviceEditorMessage = '已保存到手表';
      }
    } catch (error) {
      if (generation === this.deviceEditorGeneration) {
        this.deviceEditorLoaded = false; this.deviceEditorMessage = (error as Error).message || '保存结果未确认，请重新读取';
      }
    } finally {
      if (generation === this.deviceEditorGeneration) { this.deviceEditorBusy = false; this.deviceSettingsWriting = false; }
    }
  }

  private editWatchAlarm(alarm?: WatchAlarm): void {
    if (this.deviceEditorBusy || !this.deviceEditorLoaded) return;
    this.watchAlarmOriginal = alarm ? copyWatchAlarm(alarm) : undefined;
    this.watchAlarmDraft = alarm ? copyWatchAlarm(alarm) : newWatchAlarm();
    this.deviceEditorMessage = ''; this.openInnerPage('device-alarm-edit');
  }

  private pickWatchAlarmTime(): void {
    if (this.deviceEditorBusy) return;
    const generation = this.deviceEditorGeneration;
    const parts = this.watchAlarmDraft.time.split(':');
    const selected = new Date(); selected.setHours(Number(parts[0]), Number(parts[1]), 0, 0);
    TimePickerDialog.show({ selected: selected, useMilitaryTime: true,
      onAccept: (result: TimePickerResult) => {
        if (generation !== this.deviceEditorGeneration || this.screen !== 'device-alarm-edit' || this.deviceEditorBusy) return;
        const draft = copyWatchAlarm(this.watchAlarmDraft);
        draft.time = `${String(result.hour ?? 0).padStart(2, '0')}:${String(result.minute ?? 0).padStart(2, '0')}`;
        this.watchAlarmDraft = draft;
      } });
  }

  private changeAlarmDraft(field: string, value: string): void {
    const draft = copyWatchAlarm(this.watchAlarmDraft);
    if (field === 'label') draft.label = value;
    else if (field === 'enabled') draft.enabled = value === 'true';
    else { const index = Number(field); if (index >= 0 && index < 7) draft.days[index] = !draft.days[index]; }
    this.watchAlarmDraft = draft;
  }

  private async saveAlarmDraft(): Promise<void> {
    if (this.deviceEditorBusy || !this.deviceEditorLoaded) return;
    const draft = copyWatchAlarm(this.watchAlarmDraft); draft.label = draft.label.trim();
    this.deviceEditorMessage = alarmDraftError(draft);
    if (this.deviceEditorMessage) return;
    await this.writeWatchAlarm(draft, this.watchAlarmOriginal, false, true);
  }

  private async toggleWatchAlarm(alarm: WatchAlarm, enabled: boolean): Promise<void> {
    const updated = copyWatchAlarm(alarm); updated.enabled = enabled;
    await this.writeWatchAlarm(updated, alarm);
  }

  private async removeWatchAlarm(alarm: WatchAlarm): Promise<void> {
    if (this.deviceEditorBusy || !this.deviceEditorLoaded) return;
    const generation = this.deviceEditorGeneration;
    if (!await this.confirmCommerce('删除闹钟', '确定删除这个闹钟吗？', '删除') || generation !== this.deviceEditorGeneration) return;
    await this.writeWatchAlarm(alarm, alarm, true);
  }

  private async writeWatchAlarm(draft: WatchAlarm, expected?: WatchAlarm, remove: boolean = false, closeEditor: boolean = false): Promise<void> {
    if (this.deviceEditorBusy || !this.deviceEditorLoaded) return;
    const generation = this.deviceEditorGeneration;
    this.deviceEditorBusy = true; this.deviceSettingsWriting = true; this.deviceEditorMessage = '';
    try {
      const alarms = remove ? await vepDeviceSettings.deleteAlarm(draft) : await vepDeviceSettings.setAlarm(draft, expected);
      if (generation === this.deviceEditorGeneration) {
        this.watchAlarms = alarms;
        if (closeEditor) { this.innerParents.delete('device-alarm-edit'); this.screen = 'device-alarms'; }
        this.deviceEditorMessage = remove ? '闹钟已删除' : '闹钟已保存';
      }
    } catch (error) {
      if (generation === this.deviceEditorGeneration) {
        this.deviceEditorLoaded = false; this.deviceEditorMessage = (error as Error).message || '保存结果未确认，请重新读取';
      }
    } finally {
      if (generation === this.deviceEditorGeneration) { this.deviceEditorBusy = false; this.deviceSettingsWriting = false; }
    }
  }

  private openProfileEditor(): void {
    this.editNickname = profileName(this.profile) || this.displayName || this.tr('defaultUser');
    this.editGender = [1, 2].includes(Number(this.profile.gender)) ? Number(this.profile.gender) : 0;
    this.editBirthday = this.profile.birthday ?? '';
    this.editHeight = this.profile.height === undefined ? '' : String(this.profile.height);
    this.editWeight = this.profile.weight === undefined ? '' : String(this.profile.weight);
    this.editAvatarUri = '';
    this.openInnerPage('profile-edit');
  }

  private async pickProfileAvatar(): Promise<void> {
    if (this.avatarPicking || this.formBusy) return;
    this.avatarPicking = true;
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      options.isEditSupported = true;
      const selected = await new photoAccessHelper.PhotoViewPicker().select(options);
      const uri = selected.photoUris.length ? selected.photoUris[0].trim() : '';
      if (uri) { this.editAvatarUri = uri; this.formMessage = ''; }
    } catch (error) {
      const code = Number((error as BusinessError).code ?? 0);
      if (code !== 201) this.formMessage = '无法读取照片，请重新选择';
    } finally { this.avatarPicking = false; }
  }

  private chooseBirthday(): void {
    DatePickerDialog.show({ start: new Date(1900, 0, 1), end: new Date(),
      selected: this.editBirthday ? new Date(`${this.editBirthday}T12:00:00`) : new Date(1990, 0, 1),
      onDateAccept: (date: Date) => {
        this.editBirthday = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
      } });
  }

  private async saveProfileDraft(): Promise<void> {
    if (this.formBusy) return;
    const draft: ProfileDraft = { nickname: this.editNickname, gender: this.editGender,
      birthday: this.editBirthday, height: this.editHeight, weight: this.editWeight };
    this.formMessage = profileDraftError(draft);
    if (this.formMessage) return;
    const session = saydianApi.healthSession(), generation = this.contentGeneration;
    const current = (): boolean => generation === this.contentGeneration && sameHealthSession(session, saydianApi.healthSession());
    this.formBusy = true;
    try {
      const avatar = this.editAvatarUri ? await saydianApi.uploadProfileImage({ uri: this.editAvatarUri,
        fileName: 'avatar', maxBytes: 6 * 1024 * 1024 }) : '';
      if (!current()) return;
      const profile = await saydianApi.saveProfile(draft, avatar);
      if (!current()) return;
      this.profile = profile;
      this.displayName = profileName(this.profile);
      this.editAvatarUri = '';
      this.formMessage = '个人资料已保存';
    } catch (error) { if (current()) this.formMessage = this.accountFormFailure(error as Error); }
    finally {
      if (current()) this.formBusy = false;
      else if (generation === this.contentGeneration && !saydianApi.healthSession().ownerId) {
        this.formMessage = this.accountFormFailure(new ApiError('登录已失效，请重新登录', 401) as Error);
      }
    }
  }

  private async submitFeedback(): Promise<void> {
    if (this.formBusy) return;
    this.formMessage = feedbackError(FEEDBACK_TYPES[this.feedbackType], this.feedbackContent, this.feedbackContact);
    if (this.formMessage) return;
    this.formBusy = true;
    try {
      await saydianApi.submitFeedback(FEEDBACK_TYPES[this.feedbackType], this.feedbackContent, this.feedbackContact);
      this.feedbackContent = ''; this.formMessage = '反馈已提交，感谢你的建议';
    } catch (error) { this.formMessage = this.accountFormFailure(error as Error); }
    finally { this.formBusy = false; }
  }

  private clearAccountForms(): void {
    ++this.contentGeneration;
    ++this.globalReportsGeneration;
    this.globalReports = []; this.globalReportParagraphs = []; this.globalReportsError = ''; this.globalReportsBusy = false;
    this.globalReportProfile = undefined; this.globalReportEligibility = undefined;
    this.globalAnalysisParagraphs = []; this.globalAnalysisDocument = undefined; this.globalAnalysisAccepted = false;
    this.cartLines = []; this.cartSelection = []; this.checkoutItems = []; this.checkoutPreview = undefined;
    this.checkoutAddress = undefined; this.checkoutMessage = ''; this.checkoutPoints = '0';
    this.orderDetail = undefined; this.shipments = []; this.refundLine = undefined; this.refundReason = '';
    this.commerceError = ''; this.selectingCheckoutAddress = false; this.purchaseSheet = false;
    this.clearInboxState(); this.addresses = []; this.accountPageError = '';
    this.addressDraft = emptyAddressDraft();
    ++this.orderGeneration; this.orders = []; this.orderLoading = false; this.paymentMessage = '';
    this.resetMobile = ''; this.resetChallengeId = ''; this.resetCode = ''; this.resetPassword = ''; this.resetConfirmation = '';
    this.editNickname = ''; this.editBirthday = ''; this.editHeight = ''; this.editWeight = ''; this.editAvatarUri = '';
    this.avatarPicking = false;
    this.formBusy = false; this.clearSportRecords(); this.selectedHealthRecord = undefined;
    this.feedbackContent = ''; this.feedbackContact = ''; this.innerParents.clear();
    ++this.supportGeneration; this.supportConfig = emptySupportConfig(); this.supportLoading = false;
    this.supportError = ''; this.contactMessage = '';
  }

  private accountFormFailure(error: Error): string {
    if (error instanceof ApiError && error.status === 401) {
      this.clearAccountForms();
      return this.careFailure(error as Error);
    }
    return error.message || '操作未完成，请稍后重试';
  }


  private async openAddresses(): Promise<void> {
    if (this.screen !== 'addresses') this.openInnerPage('addresses');
    const epoch = ++this.contentGeneration;
    this.accountPageLoading = true; this.accountPageError = ''; this.addresses = [];
    try { const rows = await saydianApi.addresses(); if (epoch === this.contentGeneration) this.addresses = rows; }
    catch (error) { if (epoch === this.contentGeneration) this.accountPageError = this.accountFormFailure(error as Error); }
    finally { if (epoch === this.contentGeneration) this.accountPageLoading = false; }
  }

  private async editAddress(address?: ShippingAddress): Promise<void> {
    this.openInnerPage('address-edit'); this.formMessage = '';
    this.addressDraft = address ? copyAddressDraft(address.draft) : emptyAddressDraft();
    const epoch = this.contentGeneration;
    this.regionsLoading = true;
    try {
      const bytes = await this.uiContext().resourceManager.getRawFileContent('china_regions.json');
      const regions = parseRegions(new util.TextDecoder().decodeToString(bytes));
      if (epoch !== this.contentGeneration) return;
      this.addressRegions = regions;
      for (let level = 0; level < 3; level++) {
        const code = level === 0 ? this.addressDraft.province : level === 1 ? this.addressDraft.city : this.addressDraft.area;
        if (!this.addressChoices(level).some((item: RegionChoice) => item.code === code)) {
          this.addressDraft = selectAddressRegion(this.addressDraft, level, '');
        }
      }
    } catch { if (epoch === this.contentGeneration) this.formMessage = '地区暂时无法读取，请重新进入此页面'; }
    finally { if (epoch === this.contentGeneration) this.regionsLoading = false; }
  }

  private addressChoices(level: number): RegionChoice[] {
    return addressRegionChoices(this.addressRegions, this.addressDraft, level);
  }

  private editAddressText(field: string, value: string): void {
    const draft = copyAddressDraft(this.addressDraft);
    if (field === 'name') draft.name = value;
    else if (field === 'mobile') draft.mobile = value;
    else if (field === 'details') draft.details = value;
    this.addressDraft = draft;
  }

  private addressRegionIndex(level: number): number {
    const code = level === 0 ? this.addressDraft.province : level === 1 ? this.addressDraft.city : this.addressDraft.area;
    return this.addressChoices(level).findIndex((item: RegionChoice) => item.code === code);
  }

  private async saveAddress(): Promise<void> {
    if (this.formBusy || this.regionsLoading) return;
    this.formMessage = addressValidation(this.addressDraft, this.addressRegions);
    if (this.formMessage) return;
    this.formBusy = true;
    let saved = false;
    try { await saydianApi.saveAddress(this.addressDraft, this.addressRegions); saved = true; }
    catch (error) { this.formMessage = this.accountFormFailure(error as Error); }
    finally { this.formBusy = false; }
    if (saved) { this.back(); await this.openAddresses(); }
  }

  private async refreshInbox(): Promise<void> {
    if (this.inboxLoading || this.guest) return;
    const session = saydianApi.healthSession();
    const epoch = ++this.inboxGeneration;
    this.inboxLoading = true; this.inboxError = '';
    this.updateLocalInbox();
    try {
      const values = await saydianApi.inbox();
      if (epoch === this.inboxGeneration && session.generation === saydianApi.healthSession().generation) {
        this.serverInbox = values; this.updateLocalInbox();
      }
    } catch (error) {
      if (epoch === this.inboxGeneration && session.generation === saydianApi.healthSession().generation) {
        this.inboxError = '部分消息暂未更新，请稍后重试';
        if (error instanceof ApiError && error.status === 401) this.accountFormFailure(error as Error);
      }
    } finally { if (epoch === this.inboxGeneration) this.inboxLoading = false; }
    if (epoch === this.inboxGeneration) this.refreshNotificationCount();
  }

  private clearInboxState(): void {
    ++this.inboxGeneration; ++this.unreadGeneration;
    this.inbox = []; this.serverInbox = []; this.serverUnread = undefined; this.inboxError = ''; this.inboxLoading = false;
    this.notificationCount = -1;
  }

  private updateLocalInbox(): void {
    if (this.guest) return;
    const local = careNotifications.currentInbox();
    this.inbox = mergeCareInbox(this.serverInbox, local);
    this.notificationCount = careInboxUnread(this.serverUnread, this.serverInbox, local);
  }

  private async openInboxMessage(message: InboxMessage): Promise<void> {
    if (message.kind === 'care_invitation') {
      if (message.source === 'local') {
        try { await careNotifications.markRead(-message.id); this.updateLocalInbox(); }
        catch { this.inboxError = '消息已读状态暂未保存，请稍后重试'; }
      } else { this.readInvitationMessage(message.id); }
      await this.openCare(); if (!this.guest) this.screen = 'care-invitations'; return;
    }
    this.showFeature(message.title, message.content || '暂无消息内容');
    const epoch = this.contentGeneration;
    try {
      const current = await saydianApi.readInboxMessage(message.id);
      if (epoch !== this.contentGeneration || this.screen !== 'feature') return;
      this.detailTitle = current.title; this.detailBody = current.content || '暂无消息内容';
      this.refreshInbox();
    } catch { /* Keep the supplied preview; do not pretend it was marked read. */ }
  }

  private async readInvitationMessage(id: number): Promise<void> {
    const accountId = saydianApi.current()?.memberId;
    try {
      await saydianApi.readInboxMessage(id);
      if (accountId === saydianApi.current()?.memberId) await this.refreshInbox();
    } catch { /* A failed read does not decrement the server unread count. */ }
  }

  private async refreshPermissions(): Promise<void> {
    this.permissionError = '';
    try { this.permissionRows = await readPermissionRows(); }
    catch { this.permissionError = '暂时无法读取权限状态，请重试'; }
  }

  private async setPermission(key: string): Promise<void> {
    try { await openPermissionSetting(this.uiContext(), key); await this.refreshPermissions(); }
    catch { this.permissionError = 'viewAppPermissions'; }
  }

  private async sendResetCode(): Promise<void> {
    if (this.smsBusy || this.smsCountdown > 0) return;
    this.smsBusy = true; this.formMessage = '';
    try {
      const challenge = await saydianApi.sendVerificationCode(this.authChannel,
        this.accountIdentifier(this.resetMobile), 'reset_password', this.appLocale, this.authCountry);
      this.resetChallengeId = challenge.challengeId;
      this.beginSmsCountdown(challenge.retryAfter); this.formMessage = 'code_sent';
    }
    catch (error) { this.formMessage = (error as Error).message; }
    finally { this.smsBusy = false; }
  }

  private async submitResetPassword(): Promise<void> {
    if (this.formBusy) return;
    this.formMessage = globalRegistrationValidation(this.accountIdentifier(this.resetMobile), this.authChannel,
      this.resetCode, this.resetPassword, this.resetConfirmation, true);
    if (this.formMessage) return;
    this.formBusy = true;
    try {
      const session = await saydianApi.resetGlobalPassword(this.authChannel, this.accountIdentifier(this.resetMobile),
        this.resetChallengeId, this.resetCode, this.resetPassword, this.resetConfirmation);
      this.resetChallengeId = ''; this.resetCode = ''; this.resetPassword = ''; this.resetConfirmation = ''; this.clearSmsCountdown();
      this.innerParents.clear(); this.acceptAuthenticatedSession(session); this.startAuthenticatedServices();
    } catch (error) {
      this.formMessage = (error as Error).message;
      if (!saydianApi.current()) { this.guest = true; this.profile = {}; this.displayName = ''; this.inbox = []; this.clearCareState(); }
    } finally { this.formBusy = false; }
  }

  private bindWearable(): void {
    vepWearable.attachContext(this.uiContext());
    const listener: WearableServiceListener = {
      onDevices: (devices: WearableDevice[]) => this.wearableDevices = devices,
      onPhase: (phase: WearableConnectionPhase, message: string) => {
        this.wearablePhase = phase;
        this.wearableMessage = message;
      },
      onSnapshot: (snapshot: WearableSnapshot) => {
        if (snapshot.deviceKey !== this.wearableSnapshot.deviceKey || (!snapshot.connected && this.wearableSnapshot.connected)) {
          this.clearDeviceEditor(); this.clearDeviceFeature();
        }
        this.wearableSnapshot = snapshot;
        if (this.screen === 'wearable-metric') this.loadTrendData();
        if (snapshot.connected && this.screen === 'device-search') {
          this.screen = 'home';
          this.tab = 1;
        }
      },
      onMeasurement: (measurement: MeasurementState) => this.wearableMeasurement = measurement,
      onSportSession: (session: SportSessionState) => {
        const wasActive = this.sportActive();
        this.sportSession = session;
        if (this.sportActive()) this.startSportClock(); else this.stopSportClock();
        if (wasActive && session.phase === 'completed' && this.screen === 'sport-records') this.loadSportRecords();
      }
    };
    vepWearable.setListener(listener);
  }

  private wearableBusy(): boolean {
    return this.wearablePhase === 'connecting' || this.wearablePhase === 'authenticating' ||
      this.wearablePhase === 'syncing' || this.wearablePhase === 'disconnecting';
  }

  private clearSportRecords(): void {
    ++this.sportGeneration;
    this.localSportRecords = []; this.sportLoading = false; this.sportError = '';
  }

  private openSportRecords(): void {
    this.screen = 'sport-records';
    this.loadSportRecords();
  }

  private async loadSportRecords(): Promise<void> {
    if (this.guest) { this.clearSportRecords(); return; }
    const generation = ++this.sportGeneration, page = this.pageGeneration;
    const session = saydianApi.healthSession();
    const current = (): boolean => generation === this.sportGeneration && page === this.pageGeneration &&
      sameHealthSession(session, saydianApi.healthSession());
    this.sportLoading = true; this.sportError = '';
    try {
      const records = await vepWearable.savedSportRecords();
      if (current()) this.localSportRecords = records;
    } catch { if (current()) this.sportError = '运动记录读取失败，请重试'; }
    finally { if (current()) this.sportLoading = false; }
  }

  private async syncSportRecords(): Promise<void> {
    if (!this.wearableSnapshot.connected || !this.wearableCapability('sport') || this.wearableBusy() ||
      this.wearableMeasurement.running || this.sportActive()) return;
    const session = saydianApi.healthSession(), page = this.pageGeneration;
    const current = (): boolean => page === this.pageGeneration && sameHealthSession(session, saydianApi.healthSession());
    const synced = await vepWearable.syncHistory();
    if (!current()) return;
    await this.loadSportRecords();
    if (current() && !synced) this.sportError = '同步未完成，已保存的记录仍可查看';
  }

  private sportActive(): boolean {
    return ['starting', 'running', 'paused', 'stopping'].includes(this.sportSession.phase);
  }

  private startSportClock(): void {
    if (this.sportTimer !== -1) return;
    this.sportClock = Date.now();
    this.sportTimer = setInterval(() => this.sportClock = Date.now(), 1000);
  }

  private stopSportClock(): void {
    if (this.sportTimer !== -1) clearInterval(this.sportTimer);
    this.sportTimer = -1;
  }

  private sportElapsedSeconds(): number {
    let seconds = this.sportSession.durationSeconds;
    if (this.sportSession.phase === 'running' && this.sportSession.observedAt > 0) {
      seconds += Math.max(0, Math.floor((this.sportClock - this.sportSession.observedAt) / 1000));
    }
    return Math.max(0, seconds);
  }

  private sportDurationText(seconds: number): string {
    const value = Math.max(0, Math.round(seconds));
    const hours = Math.floor(value / 3600).toString().padStart(2, '0');
    const minutes = Math.floor(value % 3600 / 60).toString().padStart(2, '0');
    const remainder = (value % 60).toString().padStart(2, '0');
    return `${hours}:${minutes}:${remainder}`;
  }

  private sportModeIcon(mode: WearableSportMode): Resource {
    if (mode === 'cycling') return $r('sys.symbol.bicycle');
    if (mode === 'walking') return $r('sys.symbol.figure_walk');
    if (mode === 'hiking') return $r('sys.symbol.shoe');
    return $r('sys.symbol.figure_run');
  }

  private async startSport(mode: WearableSportMode): Promise<void> {
    if (this.sportActionBusy || this.sportActive()) return;
    this.sportActionBusy = true; this.sportError = '';
    try {
      const success = await vepWearable.startSport(mode);
      if (!success) this.sportError = vepWearable.currentSportSession().status || '当前手表未能开始运动';
    } finally { this.sportActionBusy = false; }
  }

  private async toggleSportPause(): Promise<void> {
    if (this.sportActionBusy || !['running', 'paused'].includes(this.sportSession.phase)) return;
    this.sportActionBusy = true; this.sportError = '';
    try {
      const success = this.sportSession.phase === 'paused' ? await vepWearable.resumeSport() : await vepWearable.pauseSport();
      if (!success) this.sportError = '手表未确认运动状态，请稍后重试';
    } finally { this.sportActionBusy = false; }
  }

  private async confirmStopSport(exitAfter: boolean = false): Promise<void> {
    if (this.sportActionBusy || !this.sportActive()) return;
    const confirmed = await this.confirmCommerce('结束本次运动？', '结束后将保存手表返回的数据和已记录的前台轨迹。', '结束运动');
    if (!confirmed || !this.sportActive()) return;
    this.sportActionBusy = true; this.sportError = '';
    try {
      const success = await vepWearable.stopSport();
      if (!success) this.sportError = vepWearable.currentSportSession().status || '手表未确认结束运动';
      else {
        await this.loadSportRecords();
        if (exitAfter) this.screen = 'home';
      }
    } finally { this.sportActionBusy = false; }
  }

  private sportRecordMode(record: HealthRecord): string {
    return sportModeLabel(record.sport?.mode ?? '');
  }

  private sportRecordIconMode(record: HealthRecord): WearableSportMode {
    return record.sport?.mode || 'running';
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
    return this.displayRecord(latestMetricRecord(this.wearableSnapshot.records, metric));
  }

  private wearableMetricTitle(metric: WearableMetricKey): string {
    const found = this.wearableMetrics.find((item: WearableMetricSpec) => item.key === metric);
    return found?.title ?? '健康数据';
  }

  private visibleWearableMetrics(): WearableMetricSpec[] {
    if (!this.wearableSnapshot.connected) return [];
    return this.wearableMetrics.filter((metric: WearableMetricSpec) =>
      metric.key !== 'sport' && this.wearableCapability(metric.key));
  }

  private metricMiniChartPoints(metric: WearableMetricKey): number[][] {
    const records = this.wearableMetricRecords(metric).filter((record: HealthRecord) =>
      record.values.length > 0 && Number.isFinite(record.values[0].value)).slice(0, 12).reverse();
    if (records.length < 2) return [];
    const values = records.map((record: HealthRecord) => record.values[0].value);
    let minimum = values[0];
    let maximum = values[0];
    values.forEach((value: number) => { minimum = Math.min(minimum, value); maximum = Math.max(maximum, value); });
    const range = Math.max(1, maximum - minimum);
    return values.map((value: number, index: number) =>
      [Math.round(index * 132 / Math.max(1, values.length - 1)), Math.round(30 - ((value - minimum) / range) * 25)]);
  }

  private todayText(): string {
    const today = new Date();
    return `${today.getMonth() + 1}月${today.getDate()}日`;
  }

  private openDeviceSearch(): void {
    this.previousTab = this.tab;
    this.screen = 'device-search';
    if (!this.wearableBusy() && !vepWearable.isScanning()) this.startWearableScan();
  }

  private async startWearableScan(): Promise<void> {
    const started = await vepWearable.startScan();
    if (!started || this.screen !== 'device-search') return;
    try {
      this.scanCountdownController.reset();
      this.scanCountdownController.start();
    } catch {}
  }

  private openWearableMetric(metric: WearableMetricKey): void {
    this.trendReturnScreen = this.screen;
    this.selectedWearableMetric = metric;
    this.trendDay = localDateKey(); this.trendPeriod = 'day'; this.trendField = '';
    this.trendData = []; this.trendReadout = ''; this.allTrendRecords = false;
    this.screen = 'wearable-metric';
    this.loadTrendData();
  }

  private async loadTrendData(): Promise<void> {
    const epoch = ++this.trendGeneration;
    this.trendReadout = ''; this.trendError = ''; this.allTrendRecords = false; this.trendRecordPage = 0;
    this.trendData = [];
    const key = this.wearableSnapshot.deviceKey;
    if (!key) { this.trendLoading = false; return; }
    const current = this.currentTrendWindow();
    const prior = trendWindow(shiftTrendDay(this.trendDay, this.trendPeriod, -1), this.trendPeriod);
    this.trendLoading = true;
    try {
      const data = await vepWearable.healthRange(key, this.selectedWearableMetric, prior.start, current.end);
      if (epoch === this.trendGeneration && key === this.wearableSnapshot.deviceKey) this.trendData = data;
    } catch (error) { if (epoch === this.trendGeneration) this.trendError = (error as Error).message; }
    finally { if (epoch === this.trendGeneration) this.trendLoading = false; }
  }

  private currentTrendWindow(): TrendWindow { return trendWindow(this.trendDay, this.trendPeriod); }
  private currentTrendRecords(): HealthRecord[] {
    return trendRecords(this.trendData, this.selectedWearableMetric, this.wearableSnapshot.deviceKey, this.currentTrendWindow());
  }
  private currentTrendNames(): string[] { return trendFieldNames(this.currentTrendRecords()); }
  private primaryTrendName(): string {
    const names = this.currentTrendNames();
    return names.includes(this.trendField) ? this.trendField : names[0] ?? '';
  }
  private displayedTrendNames(): string[] {
    return this.selectedWearableMetric === 'pressure' ? this.currentTrendNames().filter((name: string) =>
      ['收缩压', '舒张压', '脉搏', '心率'].includes(name)) : [this.primaryTrendName()].filter((name: string) => !!name);
  }
  private currentSeries(name: string): TrendSeries { return trendSeries(this.currentTrendRecords(), name, this.trendPeriod, this.displayUnits); }
  private seriesSummary(name: string): TrendSummary {
    const prior = trendWindow(shiftTrendDay(this.trendDay, this.trendPeriod, -1), this.trendPeriod);
    return trendSummary(this.currentTrendRecords(), trendRecords(this.trendData, this.selectedWearableMetric,
      this.wearableSnapshot.deviceKey, prior), name, this.displayUnits) ??
      { name, unit: '', min: NaN, max: NaN, average: NaN, count: 0 };
  }
  private chartNames(): string[] {
    return this.selectedWearableMetric === 'pressure' ? this.currentTrendNames().filter((name: string) =>
      ['收缩压', '舒张压'].includes(name)) : this.displayedTrendNames();
  }
  private chartMinimum(): number {
    const values = this.chartNames().map((name: string) => this.seriesSummary(name).min).filter((value: number) => Number.isFinite(value));
    return values.length ? Math.min(...values) : 0;
  }
  private chartMaximum(): number {
    const values = this.chartNames().map((name: string) => this.seriesSummary(name).max).filter((value: number) => Number.isFinite(value));
    return values.length ? Math.max(...values) : 1;
  }
  private plottedSeries(name: string): TrendSeries { return plotSeries(this.currentSeries(name)); }
  private seriesPoints(name: string): number[][] {
    return spreadChartPoints(this.plottedSeries(name), this.chartMinimum(), this.chartMaximum(), this.trendChartWidth);
  }
  private chartTimeline(): TrendPoint[] {
    const name = this.chartNames()[0] ?? '';
    return name ? this.plottedSeries(name).points : [];
  }
  private trendPointLabel(point: TrendPoint): string {
    const date = new Date(point.time);
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return this.trendPeriod === 'day' ? `${pad(date.getHours())}:${pad(date.getMinutes())}` : `${date.getMonth() + 1}/${date.getDate()}`;
  }
  private chartStartLabel(): string {
    const points = this.chartTimeline();
    return points.length ? this.trendPointLabel(points[0]) : '--';
  }
  private chartEndLabel(): string {
    const points = this.chartTimeline();
    return points.length > 1 ? this.trendPointLabel(points[points.length - 1]) : '';
  }
  private selectTrendPeriod(period: TrendPeriod): void { this.trendPeriod = period; this.loadTrendData(); }
  private moveTrend(direction: number): void {
    const next = shiftTrendDay(this.trendDay, this.trendPeriod, direction);
    if (trendWindow(next, this.trendPeriod).start > Date.now()) return;
    this.trendDay = next; this.loadTrendData();
  }
  private pickTrendDate(): void {
    DatePickerDialog.show({ start: new Date(2000, 0, 1), end: new Date(), selected: new Date(`${this.trendDay}T12:00:00`),
      onDateAccept: (date: Date) => { this.trendDay = localDateKey(date.getTime()); this.loadTrendData(); } });
  }
  private inspectTrend(x: number): void {
    const points = this.chartTimeline();
    if (!points.length) return;
    const point = points[spreadChartIndex(x, this.trendChartWidth, points.length)];
    const records = this.currentTrendRecords();
    if (!records.length) return;
    const exact = records.find((record: HealthRecord) => record.id === point.recordId);
    const nearest = exact ?? records.reduce((a: HealthRecord, b: HealthRecord) =>
      Math.abs(a.timestamp - point.time) < Math.abs(b.timestamp - point.time) ? a : b);
    this.trendReadout = `${this.wearableRecordTime(nearest.timestamp)} · ${this.displayRecord(nearest)}`;
  }
  private openRecord(record: HealthRecord): void {
    this.selectedHealthRecord = record; this.waveformSegment = 0; this.openInnerPage('health-record');
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

  private selectHomeTab(index: number): void {
    if (index < 0 || index > 2) return;
    try { this.homeScroller.scrollEdge(Edge.Top); } catch {}
    this.tab = index;
    if (index === 2) this.refreshCareSummary();
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
    const session = saydianApi.healthSession();
    const epoch = ++this.unreadGeneration;
    try {
      const count = await saydianApi.notificationUnread();
      if (epoch !== this.unreadGeneration || session.generation !== saydianApi.healthSession().generation) return;
      this.serverUnread = count; this.updateLocalInbox();
    } catch (error) {
      if (epoch !== this.unreadGeneration || session.generation !== saydianApi.healthSession().generation) return;
      if (error instanceof ApiError && error.status === 401) this.careFailure(error as Error);
      this.updateLocalInbox();
    }
  }

  private async connectPush(requestPermission: boolean): Promise<void> {
    if (this.pushBusy) return;
    if (!GLOBAL_PUSH_ENABLED) { this.pushStatus = 'serviceUnavailable'; return; }
    if (this.guest) { this.pushStatus = 'signInToContinue'; return; }
    this.pushBusy = true;
    this.pushStatus = '正在检查系统通知与推送身份…';
    try {
      let enabled = await harmonyPush.notificationEnabled();
      if (!enabled && requestPermission) {
        await harmonyPush.requestNotificationPermission(this.uiContext());
        enabled = await harmonyPush.notificationEnabled();
      }
      if (!enabled) { this.pushStatus = '系统通知未开启；打开 App 时仍可收到邀请提醒'; return; }
      const identity = await harmonyPush.getIdentity(this.uiContext());
      const registered = await saydianApi.registerPushDevice(identity,
        `${HARMONY_VERSION_NAME}+${HARMONY_VERSION_CODE}`);
      this.pushStatus = registered ? '通知服务已开启' : '通知服务暂时不可用，请稍后重试';
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
    if (this.guest) { this.showFeature('消息', 'signInToContinue'); return; }
    this.screen = 'messages';
    careNotifications.refresh();
    await this.refreshInbox();
    await this.connectPush(false);
  }

  private async consumeNotificationRoute(): Promise<void> {
    const route = this.pendingNotificationRoute;
    if (!route || this.guest || this.restoring) return;
    this.pendingNotificationRoute = '';
    if (!notificationMatchesOwner(saydianApi.current()?.memberId ?? '')) return;
    if (route === 'care-invitations') {
      await this.openCare();
      if (!this.guest) {
        this.screen = 'care-invitations';
        for (const invitation of this.careInvitations) {
          try { await careNotifications.markRead(invitation.id); } catch {}
        }
        this.updateLocalInbox();
      }
    } else if (route === 'health-alerts') {
      this.openHealthAlerts();
    } else if (route === 'messages') {
      await this.openMessages();
    }
  }

  private async openOrders(filter?: number): Promise<void> {
    if (this.guest) { this.showFeature('商城订单', 'signInToContinue'); return; }
    if (filter !== undefined) this.orderFilter = filter;
    else if (this.screen !== 'shop-orders' && this.screen !== 'shop-payment') this.orderFilter = 99;
    if (this.screen !== 'shop-orders' && this.screen !== 'shop-payment') this.openInnerPage('shop-orders');
    this.screen = 'shop-orders'; this.orderLoading = true; this.paymentMessage = ''; this.orders = [];
    const epoch = ++this.orderGeneration;
    try { const values = await saydianApi.shopOrders(this.orderFilter); if (epoch === this.orderGeneration) this.orders = values; }
    catch (error) { if (epoch === this.orderGeneration) this.paymentMessage = this.accountFormFailure(error as Error); }
    finally { if (epoch === this.orderGeneration) this.orderLoading = false; }
  }

  private openHealthAlerts(): void {
    this.screen = 'health-alerts';
    this.refreshInbox();
  }

  private async openShop(): Promise<void> {
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

  private async openShopProduct(product: ShopProduct): Promise<void> {
    this.selectedProduct = product;
    if (this.screen !== 'shop-product') this.openInnerPage('shop-product');
    this.productDetail = undefined; this.commerceError = ''; this.commerceLoading = true;
    const epoch = ++this.contentGeneration;
    try {
      const detail = await saydianApi.shopProductDetail(product.id);
      if (epoch !== this.contentGeneration) return;
      this.productDetail = detail; this.selectedSkuIndex = 0; this.purchaseQuantity = detail.minBuy;
    } catch (error) { if (epoch === this.contentGeneration) this.commerceError = this.accountFormFailure(error as Error); }
    finally { if (epoch === this.contentGeneration) this.commerceLoading = false; }
  }

  private purchaseSku(): ShopSku | undefined { return this.productDetail?.skus[this.selectedSkuIndex]; }
  private showPurchase(toCart: boolean): void {
    this.commerceError = '';
    if (!this.productDetail?.skus.length) { this.commerceError = '该商品暂无可购买规格'; return; }
    this.purchaseToCart = toCart; this.purchaseSheet = true;
  }
  private async purchaseSelected(): Promise<void> {
    if (this.commerceBusy) return;
    const sku = this.purchaseSku();
    this.commerceError = purchaseError(this.productDetail, sku, this.purchaseQuantity);
    if (this.commerceError || !sku) return;
    if (this.guest) { this.commerceError = '请先登录后购买'; return; }
    if (!this.purchaseToCart) {
      this.purchaseSheet = false; this.openCheckout([{ skuId: sku.id, quantity: this.purchaseQuantity }]); return;
    }
    this.commerceBusy = true;
    try {
      this.cartLines = await saydianApi.changeShopCart(sku.id, this.purchaseQuantity, 'add');
      this.purchaseSheet = false;
      this.getUIContext().getPromptAction().showToast({ message: '已加入购物车' });
    } catch (error) { this.commerceError = this.accountFormFailure(error as Error); }
    finally { this.commerceBusy = false; }
  }
  private async openCart(): Promise<void> {
    if (this.guest) { this.showFeature('购物车', '请先登录后查看购物车'); return; }
    if (this.screen !== 'shop-cart') this.openInnerPage('shop-cart');
    this.commerceLoading = true; this.commerceError = ''; this.cartLines = []; const epoch = ++this.contentGeneration;
    try {
      const lines = await saydianApi.shopCart();
      if (epoch !== this.contentGeneration) return;
      this.cartLines = lines; this.cartSelection = lines.map((line: ShopLine) => line.skuId);
    } catch (error) { if (epoch === this.contentGeneration) this.commerceError = this.accountFormFailure(error as Error); }
    finally { if (epoch === this.contentGeneration) this.commerceLoading = false; }
  }
  private cartChosen(): ShopLine[] { return this.cartLines.filter((line: ShopLine) => this.cartSelection.includes(line.skuId)); }
  private cartTotal(): number {
    const selected = this.cartChosen();
    return selected.some((line: ShopLine) => line.priceCents < 0) ? -1 : selected.reduce((sum: number, line: ShopLine) => sum + line.priceCents * line.quantity, 0);
  }
  private toggleCart(id: number, selected: boolean): void {
    this.cartSelection = selected ? Array.from(new Set([...this.cartSelection, id])) : this.cartSelection.filter((value: number) => value !== id);
  }
  private async changeCart(line: ShopLine, quantity: number, remove: boolean = false): Promise<void> {
    if (this.commerceBusy) return;
    if (remove) {
      if (!await this.confirmCommerce('移出购物车？', line.name, '移出') || this.screen !== 'shop-cart') return;
    }
    this.commerceBusy = true; this.commerceError = '';
    try {
      this.cartLines = await saydianApi.changeShopCart(line.skuId, quantity, remove ? 'delete' : 'quantity');
      this.cartSelection = this.cartSelection.filter((id: number) => this.cartLines.some((value: ShopLine) => value.skuId === id));
    } catch (error) { this.commerceError = this.accountFormFailure(error as Error); }
    finally { this.commerceBusy = false; }
  }
  private async confirmCommerce(title: string, message: string, confirm: string): Promise<boolean> {
    try {
      const result = await this.getUIContext().getPromptAction().showDialog({ title, message,
        buttons: [{ text: '取消', color: MUTED }, { text: confirm, color: RED }] });
      return result.index === 1;
    } catch { return false; }
  }
  private openCheckout(items: ShopSelection[], fromCart: boolean = false): void {
    if (this.guest || !items.length) return;
    this.checkoutItems = items; this.checkoutFromCart = fromCart; this.checkoutPreview = undefined; this.checkoutAddress = undefined;
    this.checkoutAttempted = false; this.checkoutPoints = '0'; this.checkoutMessage = '';
    this.openInnerPage('shop-checkout'); this.loadCheckout();
  }
  private async loadCheckout(): Promise<void> {
    this.commerceLoading = true; this.commerceError = ''; const epoch = ++this.contentGeneration;
    try {
      const preview = await saydianApi.shopCheckout(this.checkoutItems);
      if (epoch !== this.contentGeneration) return;
      this.checkoutPreview = preview; this.checkoutAddress = preview.address;
    } catch (error) { if (epoch === this.contentGeneration) this.commerceError = this.accountFormFailure(error as Error); }
    finally { if (epoch === this.contentGeneration) this.commerceLoading = false; }
  }
  private async submitCommerceOrder(): Promise<void> {
    if (this.commerceBusy || this.checkoutAttempted) return;
    this.commerceError = checkoutError(this.checkoutPreview, this.checkoutAddress?.id ?? '', this.checkoutPoints, this.checkoutMessage);
    if (this.commerceError || !this.checkoutPreview || !this.checkoutAddress) return;
    this.commerceBusy = true; this.checkoutAttempted = true;
    try {
      const id = await saydianApi.createCommerceOrder(this.checkoutItems, this.checkoutPreview, this.checkoutAddress.id, this.checkoutPoints, this.checkoutMessage);
      // An order exists now. A subsequent read failure must never offer duplicate creation.
      if (this.checkoutFromCart) {
        let cleaned = false;
        try { cleaned = await saydianApi.removeCreatedCartItems(id, this.checkoutItems); } catch { cleaned = false; }
        if (!cleaned) this.getUIContext().getPromptAction().showToast({ message: '订单已生成，购物车请稍后刷新确认' });
      }
      this.commerceBusy = false; this.innerParents.delete('shop-checkout');
      this.screen = 'shop-orders'; await this.openCommerceOrder(id);
    } catch (error) { this.commerceError = this.accountFormFailure(error as Error); }
    finally { this.commerceBusy = false; }
  }
  private async openCommerceOrder(id: number): Promise<void> {
    if (this.screen !== 'shop-order-detail') this.openInnerPage('shop-order-detail');
    this.commerceOrderId = id; this.orderDetail = undefined; this.commerceLoading = true; this.commerceError = '';
    const epoch = ++this.contentGeneration;
    try {
      const detail = await saydianApi.commerceOrder(id);
      if (epoch === this.contentGeneration) { this.orderDetail = detail; this.selectedOrder = detail.order; }
    } catch (error) { if (epoch === this.contentGeneration) this.commerceError = this.accountFormFailure(error as Error); }
    finally { if (epoch === this.contentGeneration) this.commerceLoading = false; }
  }
  private async openShipments(): Promise<void> {
    if (this.screen !== 'shop-express') this.openInnerPage('shop-express');
    this.commerceLoading = true; this.commerceError = ''; this.shipments = []; const epoch = ++this.contentGeneration;
    try { const shipments = await saydianApi.shopShipments(this.commerceOrderId); if (epoch === this.contentGeneration) this.shipments = shipments; }
    catch (error) { if (epoch === this.contentGeneration) this.commerceError = this.accountFormFailure(error as Error); }
    finally { if (epoch === this.contentGeneration) this.commerceLoading = false; }
  }
  private async confirmReceipt(): Promise<void> {
    if (this.commerceBusy || this.orderDetail?.order.status !== 2) return;
    const id = this.commerceOrderId;
    if (!await this.confirmCommerce('确认已经收到商品？', '确认收货后订单将完成。如尚未收到商品，请不要确认。', '确认收货') ||
      this.commerceOrderId !== id || this.screen !== 'shop-order-detail') return;
    this.commerceBusy = true; this.commerceError = '';
    try { this.orderDetail = await saydianApi.confirmShopReceipt(id); }
    catch (error) { this.commerceError = this.accountFormFailure(error as Error); }
    finally { this.commerceBusy = false; }
  }
  private openRefund(line: ShopLine): void {
    this.refundLine = line; this.refundType = 0; this.refundAmount = line.priceCents >= 0 ? (line.priceCents / 100).toFixed(2) : '';
    this.refundReason = ''; this.refundAttempted = false; this.commerceError = ''; this.openInnerPage('shop-refund');
  }
  private async submitRefund(): Promise<void> {
    if (this.commerceBusy || this.refundAttempted || !this.refundLine || this.refundLine.applied) return;
    if (commerceCents(this.refundAmount) <= 0 || !this.refundReason.trim()) { this.commerceError = '请检查申请金额和售后原因'; return; }
    this.commerceBusy = true; this.refundAttempted = true; this.commerceError = '';
    try {
      const detail = await saydianApi.applyShopRefund(this.commerceOrderId, this.refundLine.id, this.refundType + 1, this.refundAmount, this.refundReason);
      this.orderDetail = detail; this.refundLine = detail.products.find((line: ShopLine) => line.id === this.refundLine?.id);
      this.commerceError = '申请结果请以最新订单状态为准';
    } catch (error) { this.commerceError = this.accountFormFailure(error as Error); }
    finally { this.commerceBusy = false; }
  }

  private async openAiChat(): Promise<void> {
    if (this.hideAiContent) return;
    if (this.guest) { this.showFeature('AI 健康管家', 'signInToContinue'); return; }
    this.openInnerPage('ai-chat'); this.aiBusy = true; this.aiError = '';
    const request = ++this.aiChatGeneration, session = saydianApi.healthSession();
    const active = (): boolean => !this.hideAiContent && request === this.aiChatGeneration &&
      sameHealthSession(session, saydianApi.healthSession()) && this.screen === 'ai-chat';
    try {
      const messages = await saydianApi.aiMessages();
      if (!active()) return;
      this.aiMessages = messages;
      const withSession = this.aiMessages.find((item: AiChatMessage) => item.sessionId.length > 0);
      this.aiSessionId = withSession?.sessionId ?? '';
      this.scrollAiToLatest();
    } catch (error) { if (active()) this.aiError = this.careFailure(error as Error); }
    finally { if (active()) this.aiBusy = false; }
  }

  private async sendAiChat(): Promise<void> {
    if (this.hideAiContent || this.screen !== 'ai-chat') return;
    const message = this.aiInput.trim();
    if (this.aiBusy || !message) return;
    this.aiBusy = true; this.aiError = '';
    const request = ++this.aiChatGeneration, session = saydianApi.healthSession();
    const active = (): boolean => !this.hideAiContent && request === this.aiChatGeneration &&
      sameHealthSession(session, saydianApi.healthSession()) && this.screen === 'ai-chat';
    const pending: AiChatMessage = { id: `local-${Date.now()}`, text: message, mine: true,
      sessionId: this.aiSessionId, failed: false };
    this.aiMessages = [...this.aiMessages, pending];
    this.aiInput = '';
    this.scrollAiToLatest();
    try {
      const reply = await saydianApi.sendAiMessage(message, this.aiSessionId);
      if (!active()) return;
      if (reply.sessionId) this.aiSessionId = reply.sessionId;
      this.aiMessages = [...this.aiMessages, reply];
      this.scrollAiToLatest();
    } catch (error) {
      if (!active()) return;
      pending.failed = true;
      this.aiMessages = this.aiMessages.map((item: AiChatMessage) => item.id === pending.id ? pending : item);
      this.aiInput = message;
      this.aiError = this.careFailure(error as Error);
    } finally { if (active()) this.aiBusy = false; }
  }

  private scrollAiToLatest(): void {
    setTimeout(() => {
      if (this.screen !== 'ai-chat') return;
      try { this.contentScroller.scrollEdge(Edge.Bottom); } catch {}
    }, 60);
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
    } catch { this.updateStatus = '无法打开 APP 下载页面，请稍后重试'; }
  }

  private openPayment(order: ShopOrder): void {
    if (order.status !== 0) { this.paymentMessage = '订单状态已更新，无需重复支付'; return; }
    this.selectedOrder = order; this.selectedProvider = 'wechat'; this.paymentMessage = '';
    this.screen = 'shop-payment';
  }

  private selectPaymentProvider(provider: PaymentProvider): void {
    if (this.paymentBusy) return;
    this.selectedProvider = provider;
    this.paymentMessage = '';
  }

  private async refreshSelectedOrder(): Promise<void> {
    if (this.paymentBusy || this.selectedOrder.id <= 0) return;
    this.paymentBusy = true;
    try {
      this.selectedOrder = await saydianApi.shopOrder(this.selectedOrder.id);
      this.paymentMessage = `订单状态已更新：${this.orderStatus(this.selectedOrder.status)}`;
    } catch (error) {
      this.paymentMessage = (error as Error).message || '订单状态暂时无法刷新';
    } finally {
      this.paymentBusy = false;
    }
  }

  private async startPayment(): Promise<void> {
    if (this.paymentBusy || this.selectedOrder.id <= 0) return;
    const orderId = this.selectedOrder.id;
    let outcomeMessage: string = '';
    let clientReturned: boolean = false;
    let clientTimedOut: boolean = false;
    this.paymentBusy = true; this.paymentMessage = '正在核对订单…';
    try {
      const paymentModule = await import('../services/HarmonyPaymentService');
      if (!paymentModule.canStartHarmonyPayment(this.selectedProvider)) {
        this.paymentMessage = this.selectedProvider === 'wechat' ? '请先安装微信后再支付' : '当前手机暂时无法使用支付宝支付';
        this.paymentBusy = false;
        return;
      }
      const request = await saydianApi.harmonyPayment(this.selectedProvider, this.selectedOrder);
      await paymentModule.harmonyPayment.start(this.uiContext(), request);
      clientReturned = true;
      outcomeMessage = '支付流程已返回';
    } catch (error) {
      clientTimedOut = isPaymentTimeout(error as Error);
      if (clientTimedOut) outcomeMessage = '支付客户端响应超时，已停止等待';
      else if (error instanceof ApiError) outcomeMessage = error.message;
      else outcomeMessage = paymentErrorMessage(this.businessErrorCode(error as Error));
    }
    try {
      const latest = await saydianApi.shopOrder(orderId);
      if (this.selectedOrder.id === orderId) this.selectedOrder = latest;
      if (latest.status !== 0) {
        this.paymentMessage = `订单状态已更新：${this.orderStatus(latest.status)}`;
      } else if (clientTimedOut) {
        this.paymentMessage = `${outcomeMessage}；订单仍待支付，请确认未扣款后再重试`;
      } else if (clientReturned) {
        this.paymentMessage = '订单仍待支付，请确认支付结果或稍后刷新';
      } else {
        this.paymentMessage = `${outcomeMessage}；订单仍待支付`;
      }
    } catch {
      this.paymentMessage = `${outcomeMessage || '支付流程已结束'}；订单状态暂未核实，请返回订单列表刷新`;
    } finally {
      this.paymentBusy = false;
    }
  }

  private money(cents: number): string {
    return `¥${(cents / 100).toFixed(2)}`;
  }

  private orderStatus(status: number): string {
    return orderStatusLabel(status);
  }

  private visibleOrders(): ShopOrder[] {
    return this.orders.filter((order: ShopOrder) => orderMatchesFilter(order.status, this.orderFilter));
  }

  private filteredShopProducts(): ShopProduct[] {
    const keyword = this.shopKeyword.trim().toLowerCase();
    return this.shopCategory().products.filter((product: ShopProduct) => !keyword || product.name.toLowerCase().includes(keyword));
  }

  private healthWarnings(): InboxMessage[] { return this.inbox.filter((message: InboxMessage) => message.kind === 'health_warning'); }

  private careFailure(error: Error): string {
    if (error instanceof ApiError && error.status === 401) {
      ++this.pageGeneration;
      this.clearAccountForms();
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
    if (this.guest) { this.showFeature('远程关爱', 'signInToContinue'); return; }
    this.screen = 'care';
    await this.refreshCare();
  }

  private async refreshCare(): Promise<void> {
    if (this.careBusy) return;
    const epoch = ++this.careGeneration;
    this.careLoading = true;
    this.careMemberError = ''; this.careInvitationError = '';
    await Promise.all([this.readCareMembers(epoch), this.readCareInvitations(epoch)]);
    if (epoch === this.careGeneration) {
      this.careLoading = false;
    }
  }

  private async refreshCareSummary(force: boolean = false): Promise<void> {
    if (this.guest || (!force && Date.now() - this.careSummaryUpdatedAt < 60000)) return;
    await this.readCareMembers(this.careGeneration);
  }

  private async readCareMembers(epoch: number): Promise<void> {
    const generation = ++this.careSummaryGeneration;
    const memberId = saydianApi.current()?.memberId ?? '';
    try {
      const members = await saydianApi.careMembers();
      if (epoch !== this.careGeneration || generation !== this.careSummaryGeneration ||
        memberId !== (saydianApi.current()?.memberId ?? '')) return;
      this.careMembers = members;
      this.careMemberError = '';
      this.careSummaryUpdatedAt = Date.now();
    } catch (error) {
      if (epoch !== this.careGeneration || generation !== this.careSummaryGeneration ||
        memberId !== (saydianApi.current()?.memberId ?? '')) return;
      if (error instanceof ApiError && error.status === 401) this.careFailure(error as Error);
      else this.careMemberError = this.careFailure(error as Error);
    }
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
    this.screen = 'care-member'; await this.loadCareOverview();
  }

  private async loadCareOverview(): Promise<void> {
    const epoch = ++this.careGeneration;
    this.careLoading = true; this.careMessage = ''; this.careOverview = []; this.careUpdatedAt = '';
    try {
      chinaDaySeconds(this.careDateInput);
      if (this.careDateInput > chinaDay()) throw new ApiError('不能查看未来日期');
      this.careDay = this.careDateInput;
      const member = this.careSelectedMember, day = this.careDay;
      const data = await saydianApi.careMetrics(member.relationId, member.memberId, day);
      if (epoch !== this.careGeneration) return;
      this.careOverview = data;
      const now = new Date();
      this.careUpdatedAt = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
    } catch (error) { if (epoch === this.careGeneration) this.careMessage = this.careFailure(error as Error); }
    finally { if (epoch === this.careGeneration) this.careLoading = false; }
  }

  private pickCareDate(): void {
    DatePickerDialog.show({ start: new Date(2000, 0, 1), end: new Date(), selected: new Date(`${this.careDay}T12:00:00`),
      onDateAccept: (date: Date) => {
        this.careDateInput = localDateKey(date.getTime()); this.refreshCareDate();
      } });
  }

  private refreshCareDate(): void {
    if (this.screen === 'care-metric') this.loadCareMetric();
    else this.loadCareOverview();
  }

  private openCareMetric(metric: CareMetric): void {
    this.careMetricKey = metric.key; this.careMetricData = metric; this.careRecordLimit = 30;
    this.careMessage = ''; this.screen = 'care-metric';
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
          this.updateLocalInbox();
          this.refreshCareSummary(true);
          this.connectPush(false);
          this.consumeNotificationRoute();
        }
      }
    }
  }

  private acceptAuthenticatedSession(session: Session): void {
    this.password = '';
    this.registerPassword = '';
    this.registerConfirmation = '';
    this.registerChallengeId = '';
    this.registerCode = '';
    this.clearCareState();
    this.clearInboxState(); this.addresses = []; this.innerParents.clear();
    this.clearSportRecords(); this.selectedHealthRecord = undefined;
    this.profile = {};
    this.profileError = '';
    this.logoutFailed = false;
    this.displayName = session.displayName;
    this.guest = false;
    this.tab = 0;
    this.screen = 'home';
    this.refreshProfile();
  }

  private startAuthenticatedServices(): void {
    this.updateLocalInbox();
    this.refreshNotificationCount();
    this.refreshCareSummary(true);
    this.connectPush(false);
    this.consumeNotificationRoute();
  }

  private async startWechatLogin(): Promise<void> {
    if (this.busy || this.restoring) return;
    if (!this.accepted) {
      this.error = '请先阅读并同意用户协议与隐私政策';
      return;
    }
    this.error = '';
    this.busy = true;
    try {
      const result = await wechatAuth.start();
      if (!result.sent) this.error = result.message;
    } finally { this.busy = false; }
  }

  private async consumeWechatAuthResult(): Promise<void> {
    if (!this.wechatAuthResult) return;
    const raw = this.wechatAuthResult;
    AppStorage.setOrCreate<string>(WECHAT_AUTH_RESULT_KEY, '');
    const result = parseWechatAuthResult(raw);
    if (!result) {
      this.error = '微信登录失败，请重试';
      this.screen = 'login';
      return;
    }
    if (result.status === 'error') {
      this.error = result.message || '微信登录失败，请重试';
      this.screen = 'login';
      return;
    }
    if (this.busy) return;
    this.busy = true;
    this.error = '';
    const epoch = ++this.pageGeneration;
    try {
      const session = await saydianApi.loginWithWechat(result.code, result.state, result.openId);
      if (epoch !== this.pageGeneration) return;
      this.acceptAuthenticatedSession(session);
    } catch (error) {
      if (epoch === this.pageGeneration) {
        const failure = error as Error;
        this.error = failure instanceof ApiError && (failure.status === 404 || failure.status === 405) ?
          '微信登录暂时不可用，请使用手机号登录' : failure.message;
        this.screen = 'login';
      }
    } finally {
      if (epoch === this.pageGeneration) {
        this.busy = false;
        if (!this.guest) this.startAuthenticatedServices();
      }
    }
  }

  private async submitLogin(): Promise<void> {
    if (!canSubmitLogin(this.busy, this.restoring)) return;
    this.error = !this.accepted ? 'accept_terms' : !validGlobalPassword(this.password) ? 'password_length' : '';
    try { normalizeIdentifier(this.authChannel, this.accountIdentifier(this.account)); }
    catch (error) { this.error = (error as Error).message; }
    if (this.error) return;
    this.busy = true;
    const epoch = ++this.pageGeneration;
    try {
      const session = await saydianApi.login(this.accountIdentifier(this.account), this.password);
      if (epoch !== this.pageGeneration) return;
      this.acceptAuthenticatedSession(session);
    } catch (error) {
      if (epoch === this.pageGeneration) this.error = (error as Error).message;
    } finally {
      if (epoch === this.pageGeneration) {
        this.busy = false;
        if (!this.guest) this.startAuthenticatedServices();
      }
    }
  }

  private openRegistration(): void {
    this.error = '';
    this.registerError = '';
    this.registerMobile = '';
    this.registerCode = '';
    this.registerChallengeId = '';
    this.registerPassword = '';
    this.registerConfirmation = '';
    this.registerAccepted = false;
    this.clearSmsCountdown();
    this.screen = 'register';
  }

  private clearSmsCountdown(): void {
    if (this.smsTimer >= 0) clearInterval(this.smsTimer);
    this.smsTimer = -1;
    this.smsCountdown = 0;
  }

  private beginSmsCountdown(seconds: number = 60): void {
    this.clearSmsCountdown();
    this.smsCountdown = seconds;
    this.smsTimer = setInterval(() => {
      if (this.smsCountdown <= 1) this.clearSmsCountdown();
      else this.smsCountdown--;
    }, 1000);
  }

  private async sendRegistrationCode(): Promise<void> {
    if (this.smsBusy || this.busy || this.smsCountdown > 0) return;
    this.smsBusy = true;
    this.registerError = '';
    try {
      const challenge = await saydianApi.sendVerificationCode(this.authChannel,
        this.accountIdentifier(this.registerMobile), 'register', this.appLocale, this.authCountry);
      this.registerChallengeId = challenge.challengeId;
      this.beginSmsCountdown(challenge.retryAfter);
      this.registerError = 'code_sent';
    } catch (error) { this.registerError = (error as Error).message; }
    finally { this.smsBusy = false; }
  }

  private async submitRegistration(): Promise<void> {
    if (this.busy || this.restoring) return;
    this.registerError = this.capabilities.registration.verificationRequired ?
      globalRegistrationValidation(this.accountIdentifier(this.registerMobile), this.authChannel, this.registerCode,
        this.registerPassword, this.registerConfirmation, this.registerAccepted) :
      globalUnverifiedRegistrationValidation(this.accountIdentifier(this.registerMobile), this.authChannel,
        this.registerPassword, this.registerConfirmation, this.registerAccepted);
    if (this.registerError) return;
    this.busy = true;
    const epoch = ++this.pageGeneration;
    try {
      const session = this.capabilities.registration.verificationRequired ?
        await saydianApi.registerGlobal(this.authChannel, this.accountIdentifier(this.registerMobile), this.registerChallengeId,
          this.registerCode, this.registerPassword, this.registerConfirmation, this.registerAccepted,
          this.appLocale, this.capabilities.consentVersion) :
        await saydianApi.registerGlobalWithoutVerification(this.authChannel, this.accountIdentifier(this.registerMobile),
          this.registerPassword, this.registerConfirmation, this.registerAccepted,
          this.appLocale, this.capabilities.consentVersion);
      if (epoch !== this.pageGeneration) return;
      this.clearSmsCountdown();
      this.account = this.registerMobile.trim();
      this.accepted = true;
      this.acceptAuthenticatedSession(session);
    } catch (error) {
      if (epoch === this.pageGeneration) this.registerError = (error as Error).message;
    } finally {
      if (epoch === this.pageGeneration) {
        this.busy = false;
        if (!this.guest) this.startAuthenticatedServices();
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
        this.clearAccountForms();
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
    careNotifications.beginSignOut();
    ++this.pageGeneration;
    this.clearCareState();
    this.clearAccountForms();
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
    this.detailTitle = title;
    this.detailBody = message;
    this.openInnerPage('feature');
  }

  private async openArticle(id: string, title: string, agreement: boolean): Promise<void> {
    this.openInnerPage('article');
    this.selectedArticleId = id;
    this.selectedAgreement = agreement;
    this.articleTitle = title;
    this.articleContent = [];
    this.articleError = '';
    this.articleLoading = true;
    const epoch = ++this.contentGeneration;
    try {
      if (agreement) await this.loadAuthCapabilities();
      const article = agreement ? await saydianApi.globalLegal(id === '3', this.appLocale) : await saydianApi.article(id, false);
      if (epoch !== this.contentGeneration) return;
      this.articleTitle = article.title || title;
      this.articleContent = articleBlocks(article.content || article.description);
      if (this.articleContent.length === 0) this.articleError = '内容暂不可用，请稍后重试';
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
      const categories = await saydianApi.articleCategories();
      if (epoch !== this.contentGeneration) return;
      this.articleCategories = [{ id: 0, title: '全部' }, ...categories];
      const items = await saydianApi.articlesByCategory(this.articleCategoryId);
      if (epoch === this.contentGeneration) this.articles = items;
    } catch (error) {
      if (epoch === this.contentGeneration) this.listError = (error as Error).message;
    } finally { if (epoch === this.contentGeneration) this.listLoading = false; }
  }

  private back(): void {
    if (this.careBusy || this.paymentBusy || this.formBusy || this.commerceBusy || this.deviceSettingsWriting ||
      this.deviceFeatureWriting) return;
    if (this.screen === 'sport-records' && this.sportActive()) { this.confirmStopSport(true); return; }
    if (this.screen === 'device-units' || this.screen === 'device-alarms') this.clearDeviceEditor();
    if (this.screen === 'device-feature') this.clearDeviceFeature();
    if (this.purchaseSheet) { this.purchaseSheet = false; return; }
    if (this.screen === 'addresses') this.selectingCheckoutAddress = false;
    this.commerceError = ''; this.commerceLoading = false;
    ++this.contentGeneration;
    if (this.screen === 'contact') { ++this.supportGeneration; this.supportLoading = false; }
    if (this.screen === 'address-edit') { this.addressDraft = emptyAddressDraft(); this.regionsLoading = false; }
    if (this.screen === 'care-record') { this.selectedCareRecord = undefined; this.careWaveformSegment = 0; }
    if (this.screen === 'reset-password') {
      this.clearSmsCountdown(); this.resetCode = ''; this.resetPassword = ''; this.resetConfirmation = '';
    }
    const parent = this.innerParents.get(this.screen);
    if (this.screen === 'shop-payment' && parent === 'shop-order-detail') {
      this.innerParents.delete(this.screen); this.screen = parent; this.openCommerceOrder(this.commerceOrderId); return;
    }
    if (parent) {
      const from = this.screen;
      this.innerParents.delete(this.screen); this.screen = parent; this.formMessage = '';
      refreshSummaryOnSettingsReturn(from, parent, async (): Promise<boolean> => {
        // Hide the former snapshot even if another SDK operation currently blocks a read.
        this.settingsMessage = '请重新读取最新设备设置';
        return this.refreshDeviceSettings();
      });
      return;
    }
    if (this.screen === 'register') {
      this.clearSmsCountdown();
      this.registerError = '';
      this.screen = 'login';
      return;
    }
    if (this.screen === 'shop-product') { this.screen = 'shop-home'; return; }
    if (this.screen === 'shop-payment') { this.screen = 'shop-orders'; this.paymentMessage = ''; return; }
    if (this.screen === 'device-search') {
      if (vepWearable.isScanning()) vepWearable.stopScan('已停止扫描');
      this.screen = 'home'; this.tab = this.previousTab;
      return;
    }
    if (this.screen === 'shop-orders' || this.screen === 'messages' || this.screen === 'health-alerts' ||
      this.screen === 'health-all' || this.screen === 'sport-records' || this.screen === 'ai-chat' ||
      this.screen === 'shop-home' || this.screen === 'about' || this.screen === 'contact' ||
      this.screen === 'help' || this.screen === 'permissions' || this.screen === 'account' ||
      this.screen === 'unit-settings') { this.screen = 'home'; return; }
    if (this.screen === 'wearable-metric') { ++this.trendGeneration; this.screen = this.trendReturnScreen; return; }
    if (this.screen.startsWith('care')) {
      ++this.careGeneration; this.careLoading = false; this.careMessage = '';
      if (this.screen === 'care') { this.screen = 'home'; this.clearCareState(); }
      else if (this.screen === 'care-metric') { this.screen = 'care-member'; this.loadCareOverview(); }
      else if (this.screen === 'care-settings') { this.screen = 'care-sharing'; this.careSettingsReady = false; this.careSettings = { enabled: [], unknown: [] }; }
      else this.screen = 'care';
      return;
    }
    if (this.screen === 'article' || this.screen === 'feature') this.screen = this.guest ? 'login' : 'home';
    else if (this.screen === 'articles') this.screen = 'home';
  }

  onBackPress(): boolean {
    if (this.innerParents.has(this.screen)) { this.back(); return true; }
    if (this.screen === 'register' || this.screen === 'article' || this.screen === 'feature' || this.screen === 'articles' ||
      this.screen === 'messages' || this.screen === 'health-alerts' || this.screen === 'health-all' ||
      this.screen === 'sport-records' || this.screen === 'ai-chat' || this.screen === 'wearable-metric' ||
      this.screen === 'device-search' || this.screen === 'about' || this.screen === 'contact' ||
      this.screen === 'help' || this.screen === 'permissions' || this.screen === 'account' ||
      this.screen === 'unit-settings' || this.screen.startsWith('device-') ||
      this.screen.startsWith('shop-') || this.screen.startsWith('care')) {
      this.back();
      return true;
    }
    return false;
  }

  @Builder
  PageRow($$: PageRowOptions) {
    Row({ space: 16 }) {
      SymbolGlyph($$.icon).fontSize(24).fontColor([RED]).width(24)
      Column({ space: 4 }) {
        Text(this.tr($$.title)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        if ($$.subtitle) { Text(this.tr($$.subtitle)).fontSize(14).fontColor(INK).lineHeight(21).width('100%') }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([RED])
    }.width('100%').constraintSize({ minHeight: $$.subtitle ? 80 : 64 })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 }).onClick(() => $$.action())
      .id($$.id ?? '').accessibilityText(this.tr(`${$$.title}${$$.subtitle ? '，' + $$.subtitle : ''}`))
  }

  @Builder
  StateCard($$: StateCardOptions) {
    Column({ space: 16 }) {
      Column() { SymbolGlyph($$.icon ?? $r('sys.symbol.info_circle')).fontSize(28).fontColor([$$.green ? GREEN : BLUE]) }
        .width(54).height(54).justifyContent(FlexAlign.Center).backgroundColor($$.green ? GREEN_SOFT : BLUE_SOFT).borderRadius(16)
      Text(this.tr($$.title)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').textAlign(TextAlign.Center)
      if ($$.detail) { Text(this.tr($$.detail)).fontSize(16).lineHeight(24).fontColor(MUTED).width('100%').textAlign(TextAlign.Center) }
    }.width('100%').padding(20).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
  }

  @Builder
  Notice($$: NoticeOptions) {
    Row({ space: 7 }) {
      if ($$.color === '#FFF0E9') {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle')).fontSize(22).fontColor([RED_DARK])
      } else {
        SymbolGlyph($r('sys.symbol.info_circle')).fontSize(22)
          .fontColor([$$.color === GREEN_SOFT ? GREEN : $$.color === GOLD_SOFT ? GOLD : BLUE])
      }
      Text(this.tr($$.message)).fontSize(16).fontColor($$.color === GREEN_SOFT ? GREEN :
        $$.color === GOLD_SOFT ? GOLD : $$.color === '#FFF0E9' ? RED_DARK : BLUE)
        .lineHeight(24).layoutWeight(1)
    }.width('100%').padding(12)
      .backgroundColor($$.color ?? BLUE_SOFT).borderRadius(14)
      .border({ width: 1, color: $$.color === GREEN_SOFT ? '#3D287A3B' :
        $$.color === GOLD_SOFT ? '#3D705300' : $$.color === '#FFF0E9' ? '#3DB3261E' : '#3D2467A6' })
  }

  @Builder
  Heading() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([INK])
      }.backgroundColor(Color.Transparent).type(ButtonType.Normal).borderRadius(12).width(48).height(this.controlHeight(48))
        .enabled(!this.careBusy && !this.paymentBusy && !this.formBusy && !this.commerceBusy && !this.deviceSettingsWriting &&
          !this.deviceFeatureWriting && !this.sportActionBusy).onClick(() => this.back()).accessibilityText(this.tr('返回上一页'))
      Text(this.tr(this.screen === 'health-reports' ? 'reports' : this.screen === 'health-record' ? '记录详情' : this.screen === 'device-dials' ? '表盘中心' :
        this.screen === 'device-feature' ? this.deviceFeatureSpec().title : this.screen === 'device-settings' ? '设备设置' :
        this.screen === 'device-units' ? '手表单位' : this.screen === 'device-alarms' ? '闹钟' : this.screen === 'device-alarm-edit' ?
          (this.watchAlarmDraft.id < 0 ? '添加闹钟' : '编辑闹钟') : this.screen === 'profile-edit' ? '个人资料' : this.screen === 'addresses' ? '收货地址' :
        this.screen === 'address-edit' ? (this.addressDraft.id ? '编辑地址' : '新增地址') : this.screen === 'reset-password' ? '找回密码' :
        this.screen.startsWith('care') ? this.careHeading() : this.screen === 'messages' ? '消息' :
        this.screen === 'health-alerts' ? '健康预警' : this.screen === 'health-all' ? '全部健康数据' :
          this.screen === 'sport-records' ? '运动与记录' : this.screen === 'ai-chat' ? 'AI 健康管家' :
            this.screen === 'device-search' ? '添加设备' :
            this.screen === 'shop-cart' ? '购物车' : this.screen === 'shop-checkout' ? '确认订单' :
            this.screen === 'shop-order-detail' ? '订单详情' : this.screen === 'shop-express' ? '物流信息' :
            this.screen === 'shop-after-sales' ? '售后服务' : this.screen === 'shop-refund' ? '申请售后' :
            this.screen === 'shop-home' ? 'shop' : this.screen === 'shop-product' ? '商品详情' :
              this.screen === 'shop-orders' ? '我的订单' : this.screen === 'shop-payment' ? '支付收银台' :
                this.screen === 'about' ? '关于我们' : this.screen === 'contact' ? '联系客服' :
                  this.screen === 'help' ? '帮助与反馈' : this.screen === 'permissions' ? '权限管理' :
                    this.screen === 'account' ? '账号设置' : this.screen === 'unit-settings' ? '单位设置' :
          this.screen === 'wearable-metric' ? `${this.wearableMetricTitle(this.selectedWearableMetric)}分析` :
            this.screen === 'articles' ? '健康百科' : this.screen === 'article' ? this.articleTitle : this.detailTitle))
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1).maxLines(2)
        .textAlign(TextAlign.Center)
      if (this.screen === 'device-search') {
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(23).fontColor([INK])
        }.backgroundColor(Color.Transparent).type(ButtonType.Normal).borderRadius(12).width(48).height(this.controlHeight(48))
          .enabled(!this.wearableBusy()).onClick(() => this.startWearableScan())
          .accessibilityText(this.tr('重新查找附近设备')).id('device_search_refresh')
      } else if (this.screen === 'shop-home') {
        Button() { SymbolGlyph($r('sys.symbol.bag')).fontSize(24).fontColor([INK]) }
          .width(48).height(this.controlHeight(48)).backgroundColor(Color.Transparent).onClick(() => this.openCart())
          .accessibilityText(this.tr('购物车')).id('shop_cart')
      } else if (this.screen === 'addresses') {
        Button() { SymbolGlyph($r('sys.symbol.plus')).fontSize(24).fontColor([INK]) }
          .width(48).height(this.controlHeight(48)).backgroundColor(Color.Transparent).onClick(() => this.editAddress())
          .accessibilityText(this.tr('新增地址')).id('add_address_header')
      } else {
        Blank().width(48)
      }
    }.width('100%').constraintSize({ minHeight: 56 })
  }

  private careHeading(): string {
    if (this.screen === 'care-invitations') return '关爱邀请';
    if (this.screen === 'care-sharing') return '共享管理';
    if (this.screen === 'care-settings') return '共享数据管理';
    if (this.screen === 'care-add') return '添加关爱成员';
    if (this.screen === 'care-member') return this.careSelectedMember.name || '成员健康数据';
    if (this.screen === 'care-metric') return this.careMetricData.title;
    if (this.screen === 'care-record') return this.careMetricData.key === 'ecg' ? '心电详情' : '记录详情';
    return '远程关爱';
  }

  @Builder
  WearableMetricIcon(metric: WearableMetricKey) {
    if (metric === 'activity') {
      SymbolGlyph($r('sys.symbol.figure_walk')).fontSize(22).fontColor([RED])
    } else if (metric === 'sleep') {
      SymbolGlyph($r('sys.symbol.sleep')).fontSize(22).fontColor([RED])
    } else if (metric === 'heart') {
      SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(22).fontColor([RED])
    } else if (metric === 'pressure') {
      SymbolGlyph($r('sys.symbol.blood_pressure')).fontSize(22).fontColor([RED])
    } else if (metric === 'oxygen') {
      SymbolGlyph($r('sys.symbol.blood_oxygen_saturation')).fontSize(22).fontColor([RED])
    } else if (metric === 'glucose') {
      SymbolGlyph($r('sys.symbol.blood_glucose')).fontSize(22).fontColor([RED])
    } else if (metric === 'temperature') {
      SymbolGlyph($r('sys.symbol.thermometer')).fontSize(22).fontColor([RED])
    } else if (metric === 'hrv') {
      SymbolGlyph($r('sys.symbol.waveform')).fontSize(22).fontColor([RED])
    } else if (metric === 'ecg') {
      SymbolGlyph($r('sys.symbol.waveform_path_ecg_heart')).fontSize(22).fontColor([RED])
    } else if (metric === 'bodyComposition') {
      SymbolGlyph($r('sys.symbol.person_badge_data')).fontSize(22).fontColor([RED])
    } else if (metric === 'bloodComponents') {
      SymbolGlyph($r('sys.symbol.drop_fill')).fontSize(22).fontColor([RED])
    } else {
      SymbolGlyph($r('sys.symbol.dumbbell')).fontSize(22).fontColor([RED])
    }
  }

  @Builder
  BrandLockup() {
    Row({ space: 12 }) {
      Image($r('app.media.app_icon')).width(62).height(62).borderRadius(31)
      Text(this.tr('appName')).fontSize(27).fontWeight(FontWeight.Bold).fontColor(RED).maxLines(1)
    }.width(190).height(92).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
      .margin({ top: 16, bottom: 18 }).accessibilityText(this.tr('appName'))
  }

  @Builder
  LanguagePicker() {
    Row({ space: 10 }) {
      Text(this.tr('language')).fontSize(14).fontColor(MUTED)
      Select(APP_LANGUAGE_NAMES.map((name: string): SelectOption => { return { value: name }; }))
        .selected(APP_LOCALES.indexOf(this.appLocale)).value(APP_LANGUAGE_NAMES[APP_LOCALES.indexOf(this.appLocale)])
        .font({ size: 15 }).layoutWeight(1).onSelect((index: number) => this.changeAppLocale(index))
        .id('global_language')
    }.width('100%').constraintSize({ minHeight: 48 })
  }

  @Builder
  AuthMethodSelector() {
    Row({ space: 8 }) {
      Button(this.tr('email')).layoutWeight(1).height(this.controlHeight(48))
        .fontColor(this.authChannel === 'email' ? Color.White : INK)
        .backgroundColor(this.authChannel === 'email' ? RED : SURFACE)
        .enabled(!this.busy && !this.smsBusy && !this.formBusy)
        .onClick(() => { this.authChannel = 'email'; this.clearSmsCountdown(); this.registerChallengeId = '';
          this.resetChallengeId = ''; this.registerCode = ''; this.resetCode = ''; })
        .id('auth_email')
      Button(this.tr('phone')).layoutWeight(1).height(this.controlHeight(48))
        .fontColor(this.authChannel === 'sms' ? Color.White : INK)
        .backgroundColor(this.authChannel === 'sms' ? RED : SURFACE)
        .enabled(!this.busy && !this.smsBusy && !this.formBusy)
        .onClick(() => { this.authChannel = 'sms'; this.clearSmsCountdown(); this.registerChallengeId = '';
          this.resetChallengeId = ''; this.registerCode = ''; this.resetCode = ''; })
        .id('auth_phone')
    }.width('100%')
    if (this.authChannel === 'sms') {
      Select(this.phoneChoices().map((country: PhoneCountry): SelectOption => { return { value: `${country.name} ${country.dialCode}` }; }))
        .selected(this.phoneChoices().findIndex((country: PhoneCountry) => country.code === this.authCountry))
        .value(this.phoneChoices().find((country: PhoneCountry) => country.code === this.authCountry)?.name ?? this.tr('country'))
        .font({ size: 15 }).width('100%').enabled(!this.busy && !this.smsBusy && !this.formBusy)
        .onSelect((index: number) => { this.authCountry = this.phoneChoices()[index].code; this.clearSmsCountdown();
          this.registerChallengeId = ''; this.resetChallengeId = ''; this.registerCode = ''; this.resetCode = ''; })
        .id('auth_country')
    }
  }

  @Builder
  Login() {
    Scroll() {
      Column({ space: 14 }) {
        this.LanguagePicker()
        this.BrandLockup()
        this.AuthMethodSelector()
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.phone')).fontSize(22).fontColor([MUTED]).margin({ left: 15 })
          TextInput({ placeholder: this.tr(this.authChannel === 'email' ? 'email' : 'phone'), text: this.account }).type(InputType.Normal)
            .layoutWeight(1).height(this.controlHeight(54)).fontSize(17).backgroundColor(Color.Transparent)
            .maxLength(128).enabled(canSubmitLogin(this.busy, this.restoring))
            .onChange((value: string) => this.account = value).id('login_account').accessibilityText(this.tr('手机号或账号'))
        }.width('100%').height(this.controlHeight(56)).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.lock')).fontSize(22).fontColor([MUTED]).margin({ left: 15 })
          TextInput({ placeholder: this.tr('密码'), text: this.password }).type(InputType.Password)
            .layoutWeight(1).height(this.controlHeight(54)).fontSize(17).backgroundColor(Color.Transparent)
            .maxLength(256).enabled(canSubmitLogin(this.busy, this.restoring))
            .onChange((value: string) => this.password = value)
            .onSubmit(() => this.submitLogin()).id('login_password').accessibilityText(this.tr('密码'))
        }.width('100%').height(this.controlHeight(56)).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
        Row() {
          Blank()
          Button(this.tr('忘记密码？')).height(this.controlHeight(48)).fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK)
            .backgroundColor(Color.Transparent).enabled(!this.busy && !this.restoring)
            .onClick(() => this.openPasswordReset()).id('forgot_password')
        }.width('100%')
        if (this.error) { this.Notice({ message: this.error, color: '#FFF0E9' }) }
        Row() {
          Checkbox({ name: 'agreement' }).select(this.accepted).enabled(canSubmitLogin(this.busy, this.restoring))
            .selectedColor(RED).onChange((value: boolean) => this.accepted = value)
            .id('login_agreement').accessibilityText(this.tr('同意用户协议与隐私政策'))
          Column({ space: 0 }) {
            Text(this.tr('我已阅读并同意')).fontSize(13).fontColor(MUTED).width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              Button(this.tr('用户协议')).height(this.controlHeight(48)).fontSize(14).fontColor(BLUE).backgroundColor(Color.Transparent)
                .enabled(canSubmitLogin(this.busy, this.restoring)).onClick(() => this.openArticle('2', '用户协议', true))
              Button(this.tr('隐私政策')).height(this.controlHeight(48)).fontSize(14).fontColor(BLUE).backgroundColor(Color.Transparent)
                .enabled(canSubmitLogin(this.busy, this.restoring)).onClick(() => this.openArticle('3', '隐私政策', true))
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(VerticalAlign.Top)
        if (this.logoutFailed) {
          Button(this.tr('重试清除本机登录状态')).width('100%').constraintSize({ minHeight: 50 })
            .fontColor(RED).backgroundColor(Color.White).enabled(!this.busy)
            .onClick(() => this.signOut()).id('retry_logout')
        }
        Button(this.tr(this.busy ? '正在登录…' : '登录')).width('100%').height(this.controlHeight(50)).fontSize(17)
          .fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(10)
          .enabled(!this.busy && !this.restoring)
          .onClick(() => this.submitLogin()).id('login_submit')
        Button(this.tr('注册账户')).width('100%').height(this.controlHeight(48)).fontSize(16).fontColor(INK)
          .fontWeight(FontWeight.Medium).backgroundColor(Color.Transparent).enabled(!this.busy && !this.restoring)
          .onClick(() => this.openRegistration()).id('open_registration')
        if (GLOBAL_WECHAT_ENABLED) { Row() {
          Button(this.tr(this.busy ? '正在打开微信…' : '微信授权登录')).width(this.singleColumn() ? '100%' : '60%').height(this.controlHeight(48)).fontSize(16)
            .fontWeight(FontWeight.Medium).fontColor('#07883E').backgroundColor(Color.Transparent)
            .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: '#07883E' })
            .enabled(!this.busy && !this.restoring)
            .onClick(() => this.startWechatLogin()).id('wechat_login').accessibilityText(this.tr('使用微信授权登录'))
        }.width('100%').justifyContent(FlexAlign.Center) }
      }.width('100%').constraintSize({ maxWidth: 427 }).padding({ left: 26, right: 26, bottom: 32 })
    }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .linearGradient({ angle: 180, colors: [['#FFF1F3', 0.0], ['#F5F7FA', 0.5], ['#EAF1FF', 1.0]] })
  }

  @Builder
  Registration() {
    Scroll() {
      Column({ space: 12 }) {
        this.LanguagePicker()
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([INK])
          }.width(48).height(this.controlHeight(48)).backgroundColor(Color.Transparent).type(ButtonType.Normal).borderRadius(12)
            .onClick(() => this.back()).accessibilityText(this.tr('返回登录'))
          Text(this.tr('注册')).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1).textAlign(TextAlign.Center)
          Blank().width(48)
        }.width('100%').height(this.controlHeight(56))
        this.BrandLockup()
        this.AuthMethodSelector()
        TextInput({ placeholder: this.tr(this.authChannel === 'email' ? 'email' : 'phone'), text: this.registerMobile }).type(InputType.Normal)
          .height(this.controlHeight(56)).fontSize(17).backgroundColor(SURFACE).borderRadius(12)
          .border({ width: 1, color: OUTLINE }).maxLength(254).enabled(!this.busy && !this.smsBusy)
          .onChange((value: string) => { this.registerMobile = value; this.registerChallengeId = ''; this.registerCode = ''; }).id('register_mobile')
          .accessibilityText(this.tr('注册手机号'))
        if (this.capabilities.registration.verificationRequired) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          TextInput({ placeholder: this.tr('短信验证码'), text: this.registerCode }).type(InputType.Number)
            .width(this.singleColumn() ? '100%' : '58%').height(this.controlHeight(56)).fontSize(17).backgroundColor(SURFACE).borderRadius(12)
            .border({ width: 1, color: OUTLINE }).maxLength(6).enabled(!this.busy)
            .onChange((value: string) => this.registerCode = value).id('register_code')
            .accessibilityText(this.tr('短信验证码'))
          Button(this.tr(this.smsBusy ? '发送中…' : this.smsCountdown > 0 ? `${this.smsCountdown}s` : '获取验证码'))
            .width(this.singleColumn() ? '100%' : '38%').height(this.controlHeight(56)).fontSize(14).fontColor(INK).backgroundColor(SURFACE)
            .margin({ top: this.singleColumn() ? 8 : 0 })
            .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE })
            .enabled(!this.busy && !this.smsBusy && this.smsCountdown === 0 && !this.authCapabilitiesBusy && this.capabilities.registration[this.authChannel])
            .onClick(() => this.sendRegistrationCode()).id('register_send_code')
          }.width('100%')
        }
        if (!this.authCapabilitiesBusy && !this.capabilities.registration[this.authChannel]) {
          this.Notice({ message: 'channel_unavailable', color: GOLD_SOFT })
          Button(this.tr('retry')).onClick(() => this.loadAuthCapabilities()).id('retry_auth_capabilities')
        }
        TextInput({ placeholder: this.tr('new_password'), text: this.registerPassword }).type(InputType.Password)
          .height(this.controlHeight(56)).fontSize(17).backgroundColor(SURFACE).borderRadius(12)
          .border({ width: 1, color: OUTLINE }).maxLength(256).enabled(!this.busy)
          .onChange((value: string) => this.registerPassword = value).id('register_password')
          .accessibilityText(this.tr('设置密码'))
        TextInput({ placeholder: this.tr('再次输入密码'), text: this.registerConfirmation }).type(InputType.Password)
          .height(this.controlHeight(56)).fontSize(17).backgroundColor(SURFACE).borderRadius(12)
          .border({ width: 1, color: OUTLINE }).maxLength(256).enabled(!this.busy)
          .onChange((value: string) => this.registerConfirmation = value).id('register_confirmation')
          .onSubmit(() => this.submitRegistration()).accessibilityText(this.tr('确认密码'))
        Row() {
          Checkbox({ name: 'register-agreement' }).select(this.registerAccepted).enabled(!this.busy)
            .selectedColor(RED).onChange((value: boolean) => this.registerAccepted = value)
            .id('register_agreement').accessibilityText(this.tr('同意用户协议与隐私政策'))
          Column({ space: 0 }) {
            Text(this.tr('我已阅读并同意')).fontSize(13).fontColor(MUTED).width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              Button(this.tr('用户协议')).height(this.controlHeight(48)).fontSize(14).fontColor(BLUE).backgroundColor(Color.Transparent)
                .enabled(!this.busy).onClick(() => this.openArticle('2', '用户协议', true))
              Button(this.tr('隐私政策')).height(this.controlHeight(48)).fontSize(14).fontColor(BLUE).backgroundColor(Color.Transparent)
                .enabled(!this.busy).onClick(() => this.openArticle('3', '隐私政策', true))
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(VerticalAlign.Top)
        if (this.registerError) { this.Notice({ message: this.registerError, color: '#FFF0E9' }) }
        Button(this.tr(this.busy ? '正在注册…' : '注册')).width('100%').height(this.controlHeight(56)).fontSize(17)
          .fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
          .enabled(!this.busy && !this.restoring && !this.authCapabilitiesBusy &&
            this.capabilities.registration[this.authChannel]).onClick(() => this.submitRegistration()).id('register_submit')
        Button(this.tr('已有账号，返回登录')).width('100%').height(this.controlHeight(48)).fontSize(16).fontColor(INK)
          .backgroundColor(Color.Transparent).enabled(!this.busy)
          .onClick(() => { this.clearSmsCountdown(); this.registerError = ''; this.screen = 'login'; })
          .id('register_back_login')
      }.width('100%').constraintSize({ maxWidth: 440 }).padding({ left: 24, right: 24, bottom: 32 })
    }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .linearGradient({ angle: 180, colors: [['#FFF1F3', 0.0], ['#F5F7FA', 0.5], ['#EAF1FF', 1.0]] })
  }

  @Builder
  HealthHome() {
    Column({ space: 12 }) {
      Row({ space: 11 }) {
        Column() {
          Image($r('app.media.app_icon')).width(46).height(46).borderRadius(23).accessibilityText(this.tr('appName'))
        }.width(50).height(50).justifyContent(FlexAlign.Center).backgroundColor(SURFACE).borderRadius(25)
        Column({ space: 2 }) {
          Text(formatAppText('welcome', { name: this.guest ? this.tr('defaultUser') : this.displayName }, this.appLocale))
            .fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          Text(this.tr('今天也要保持好状态')).fontSize(13).fontColor(MUTED).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Stack({ alignContent: Alignment.TopEnd }) {
          Button() {
            SymbolGlyph($r('sys.symbol.bell')).fontSize(27).fontColor([INK])
          }.width(48).height(this.controlHeight(48)).backgroundColor(Color.Transparent).type(ButtonType.Normal).borderRadius(12)
            .onClick(() => this.openMessages()).id('open_messages')
            .accessibilityText(this.tr(this.notificationCount > 0 ? `消息，${this.notificationCount} 条未读` : '消息'))
          if (this.notificationCount > 0) {
            Text(this.tr(this.notificationCount > 99 ? '99+' : `${this.notificationCount}`))
              .fontSize(10).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 }).backgroundColor(RED).borderRadius(8)
          }
        }.width(50).height(50)
      }.width('100%').alignItems(VerticalAlign.Center)

      if (!this.hideAiContent) {
      Row() {
        Image($r('app.media.health_doctor')).width('36%').height(140).objectFit(ImageFit.Cover)
          .accessibilityText(this.tr('appName'))
        Column({ space: 4 }) {
          Text(this.tr('AI健康管家')).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#9E1025').width('100%')
          Text(this.tr('我是您的健康管家，\n有任何健康问题都可以向我提问。'))
            .fontSize(12).lineHeight(15).fontColor(INK).width('100%')
          Button(this.tr('马上提问')).fontSize(14.5).fontWeight(FontWeight.Bold).height(this.controlHeight(44)).backgroundColor(RED)
            .type(ButtonType.Capsule).width('100%').onClick(() => this.openAiChat()).id('open_ai_chat')
        }.width('64%').padding({ left: 4, right: 13, top: 7, bottom: 7 }).alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ minHeight: 140 }).borderRadius(20).backgroundColor('#FDF7F3')
        .border({ width: 1.2, color: '#66D20B27' }).clip(true)
      }

      Flex({ wrap: FlexWrap.Wrap }) {
        Column({ space: 6 }) {
          Column() { SymbolGlyph($r('sys.symbol.person_badge_heart')).fontSize(26).fontColor([Color.White]) }
            .width(47).height(47).justifyContent(FlexAlign.Center).backgroundColor('#E84358').borderRadius(14)
          Text(this.tr('远程关爱')).fontSize(13.5).fontWeight(FontWeight.Bold).fontColor(INK).textAlign(TextAlign.Center)
        }.width(this.singleColumn() ? '100%' : '25%').padding({ top: 8, bottom: 8 }).onClick(() => this.openCare()).id('family_care')
        Column({ space: 6 }) {
          Column() { SymbolGlyph($r('sys.symbol.book')).fontSize(26).fontColor([Color.White]) }
            .width(47).height(47).justifyContent(FlexAlign.Center).backgroundColor('#D5A03D').borderRadius(14)
          Text(this.tr('健康百科')).fontSize(13.5).fontWeight(FontWeight.Bold).fontColor(INK).textAlign(TextAlign.Center)
        }.width(this.singleColumn() ? '100%' : '25%').padding({ top: 8, bottom: 8 }).onClick(() => this.openArticles()).id('health_articles')
        Column({ space: 6 }) {
          Column() { SymbolGlyph($r('sys.symbol.exclamationmark_shield_fill')).fontSize(26).fontColor([Color.White]) }
            .width(47).height(47).justifyContent(FlexAlign.Center).backgroundColor('#EF6E78').borderRadius(14)
          Text(this.tr('健康预警')).fontSize(13.5).fontWeight(FontWeight.Bold).fontColor(INK).textAlign(TextAlign.Center)
        }.width(this.singleColumn() ? '100%' : '25%').padding({ top: 8, bottom: 8 }).onClick(() => this.openHealthAlerts()).id('health_alerts')
        Column({ space: 6 }) {
          Column() { SymbolGlyph($r('sys.symbol.bag_fill')).fontSize(26).fontColor([Color.White]) }
            .width(47).height(47).justifyContent(FlexAlign.Center).backgroundColor('#D99C2B').borderRadius(14)
          Text(this.tr('shop')).fontSize(13.5).fontWeight(FontWeight.Bold).fontColor(INK).textAlign(TextAlign.Center)
        }.width(this.singleColumn() ? '100%' : '25%').padding({ top: 8, bottom: 8 }).onClick(() => this.openShop()).id('health_shop')
      }.width('100%').padding({ left: 6, right: 6, top: 10, bottom: 10 }).backgroundColor(SURFACE).borderRadius(18)
        .shadow({ radius: 9, color: CARD_SHADOW, offsetY: 3 })

      if (this.profileError) { this.Notice({ message: this.profileError, color: '#FFF0E9' }) }
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        Row({ space: 7 }) {
          Text(this.tr('健康数据')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK)
          SymbolGlyph($r('sys.symbol.calendar')).fontSize(19).fontColor([MUTED])
          Text(this.todayText()).fontSize(14).fontColor(MUTED)
        }.width(this.singleColumn() ? '100%' : '68%')
        Button() {
          Row({ space: 2 }) {
            Text(this.tr('全部数据')).fontSize(14).fontWeight(FontWeight.Bold).fontColor(RED)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(20).fontColor([RED])
          }
        }.width(this.singleColumn() ? '100%' : '32%').height(this.controlHeight(48)).backgroundColor(Color.Transparent).type(ButtonType.Normal).borderRadius(10)
          .onClick(() => this.screen = 'health-all').id('health_all')
      }.width('100%')

      if (this.visibleWearableMetrics().length === 0) {
        Row({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.circle')).fontSize(17).fontColor([BLUE])
          Text(this.tr(this.wearableSnapshot.connected ? '暂无可显示的健康数据' : 'connectWatchForData'))
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(BLUE).textAlign(TextAlign.Center).layoutWeight(1)
        }.width('100%').padding({ left: 10, right: 10, top: 12, bottom: 12 }).backgroundColor(BLUE_SOFT)
          .borderRadius(10).border({ width: 1, color: '#3D2467A6' })
          .onClick(() => { if (!this.wearableSnapshot.connected) this.openDeviceSearch(); }).id('connect_watch_notice')
      } else {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.visibleWearableMetrics(), (metric: WearableMetricSpec) => {
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Column() { this.WearableMetricIcon(metric.key) }
                  .width(30).height(30).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(15)
                Text(this.tr(metric.title)).fontSize(15).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1).maxLines(2)
                if (this.wearableMetricRecords(metric.key).length > 0) {
                  Text(this.tr('已记录')).fontSize(11).fontWeight(FontWeight.Bold).fontColor(GREEN)
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 }).backgroundColor('#E7F7E6').borderRadius(9)
                }
              }.width('100%')
              Text(this.wearableLatest(metric.key)).fontSize(17).lineHeight(23).fontWeight(FontWeight.Bold)
                .fontColor(INK).width('100%').maxLines(2)
              Blank().layoutWeight(1)
              if (this.metricMiniChartPoints(metric.key).length > 1) {
                Polyline({ width: 132, height: 34 }).points(this.metricMiniChartPoints(metric.key))
                  .fillOpacity(0).stroke(TECH_BLUE).strokeWidth(2).width('100%').height(34)
              }
            }.width(this.singleColumn() ? '100%' : '48%').constraintSize({ minHeight: 142 }).padding({ left: 10, right: 10, top: 9, bottom: 8 })
              .margin({ bottom: 12 }).backgroundColor(SURFACE).borderRadius(18)
              .shadow({ radius: 9, color: CARD_SHADOW, offsetY: 3 })
              .onClick(() => this.openWearableMetric(metric.key))
              .accessibilityText(`${metric.title}，${this.wearableLatest(metric.key)}`)
          }, (metric: WearableMetricSpec) => metric.key)
        }.width('100%')
      }

      Text(this.tr('运动与记录')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').margin({ top: 6 })
      Column() {
        Row({ space: 10 }) {
          Column() { SymbolGlyph($r('sys.symbol.clock_arrow_2_circlepath')).fontSize(20).fontColor([RED]) }
            .width(34).height(34).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(11)
          Column({ space: 3 }) {
            Text(this.tr('运动记录')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(this.wearableSnapshot.connected ? this.wearableLatest('sport') : '查看已保存的运动记录')
              .fontSize(13).fontColor(MUTED).width('100%').maxLines(2)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(20).fontColor([RED])
        }.width('100%').constraintSize({ minHeight: 72 }).padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(RED_SOFT).borderRadius(17).onClick(() => this.openSportRecords())
          .accessibilityText(this.tr('查看运动记录'))
      }.width('100%').padding({ left: 14, right: 14, top: 14, bottom: 12 }).backgroundColor(SURFACE)
        .borderRadius(22).border({ width: 1, color: '#18D20B27' }).shadow({ radius: 12, color: CARD_SHADOW, offsetY: 4 })
      this.Notice({ message: '测量结果仅供健康管理参考，如有不适请咨询专业医务人员。', color: GREEN_SOFT })
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 24 })
  }

  @Builder
  DeviceAction($$: DeviceActionOptions) {
    Row({ space: 10 }) {
      Column() { SymbolGlyph($$.icon).fontSize(23).fontColor([$$.color]) }
        .width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor($$.background).borderRadius(13)
      Text(this.tr($$.title)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
    }.width(this.singleColumn() ? '100%' : '48%').constraintSize({ minHeight: 78 }).padding(12).margin({ bottom: 12 })
      .backgroundColor(SURFACE).borderRadius(16).border({ width: 1, color: LINE })
      .enabled(!this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive()).onClick(() => $$.action())
      .id($$.id).accessibilityText(this.tr($$.title))
  }

  @Builder
  DeviceHome() {
    Column({ space: 12 }) {
      if (this.wearableSnapshot.connected) {
        Column({ space: 13 }) {
          Row({ space: 12 }) {
            Column() {
              SymbolGlyph($r('sys.symbol.circle')).fontSize(31).fontColor([Color.White])
            }.width(56).height(56).justifyContent(FlexAlign.Center).backgroundColor('#171B2B').borderRadius(28)
              .accessibilityText(this.tr('connectedRing'))
            Column({ space: 5 }) {
              Text(this.tr(this.wearableSnapshot.deviceName)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK)
                .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.tr(this.wearableSnapshot.mac ? `MAC · ${this.wearableSnapshot.mac}` : '设备标识暂不可用'))
                .fontSize(13).fontColor(MUTED).width('100%').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.tr('connected')).fontSize(13).fontColor(GREEN).width('100%').maxLines(1)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 3 }) {
              Text(batteryText(this.wearableSnapshot.battery)).fontSize(15).fontWeight(FontWeight.Bold)
                .fontColor(this.wearableSnapshot.battery.lowBattery ? RED : GREEN)
              Text(this.tr('电量')).fontSize(11).fontColor(MUTED)
            }.alignItems(HorizontalAlign.End)
          }.width('100%').alignItems(VerticalAlign.Center)
          Text(this.wearableSyncTime()).fontSize(13).fontColor(GREEN).width('100%').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`型号 ${wearableModelText(this.wearableSnapshot.model, this.wearableSnapshot.deviceName)} · 固件 ${this.wearableSnapshot.firmware || '未知'}`)
            .fontSize(13).fontColor(MUTED).width('100%').maxLines(2)
          Row({ space: 10 }) {
            Button(this.tr(this.wearablePhase === 'syncing' ? '正在同步…' : '同步数据')).layoutWeight(1)
              .constraintSize({ minHeight: 48 }).backgroundColor(RED)
              .type(ButtonType.Normal).borderRadius(14)
              .enabled(!this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive())
              .onClick(() => vepWearable.syncHistory()).id('wearable_sync')
            Button(this.tr('断开连接')).layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(INK)
              .backgroundColor(SURFACE).type(ButtonType.Normal).borderRadius(14).border({ width: 1, color: LINE })
              .enabled(!this.wearableBusy() && !this.sportActive()).onClick(() => vepWearable.disconnect()).id('wearable_disconnect')
          }.width('100%')
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)
          .border({ width: 1, color: LINE }).shadow({ radius: 12, color: CARD_SHADOW, offsetY: 4 })
          .id('device-current-card')

        this.Notice({ message: this.wearableMessage,
          color: this.wearablePhase === 'error' || this.wearablePhase === 'permission' ? '#FFF0E9' : GREEN_SOFT })

        if (this.wearableSnapshot.capabilities.dial || this.wearableSnapshot.capabilities.photoDial) {
          Text(this.tr('表盘与个性化')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Column({ space: 0 }) {
            if (this.wearableSnapshot.capabilities.dial) {
              Row({ space: 12 }) {
                Column() {
                  SymbolGlyph($r('sys.symbol.watch_badge_card')).fontSize(25).fontColor([RED])
                }.width(46).height(46).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(14)
                Column({ space: 3 }) {
                  Text(this.tr('表盘中心')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                  Text(this.tr('查看并切换手表内表盘')).fontSize(13).fontColor(MUTED).width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
              }.width('100%').constraintSize({ minHeight: 76 }).padding({ left: 13, right: 13, top: 11, bottom: 11 })
                .enabled(!this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive())
                .onClick(() => this.openDials()).id('wearable_read_dials').accessibilityText(this.tr('表盘中心'))
            }
            if (this.wearableSnapshot.capabilities.dial && this.wearableSnapshot.capabilities.photoDial) {
              Divider().color(LINE).margin({ left: 58 })
            }
            if (this.wearableSnapshot.capabilities.photoDial) {
              Row({ space: 12 }) {
                Column() { SymbolGlyph($r('sys.symbol.camera_fill')).fontSize(25).fontColor([BLUE]) }
                  .width(46).height(46).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(14)
                Column({ space: 3 }) {
                  Text(this.tr('照片表盘')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                  Text(this.tr('选择照片并按手表尺寸制作')).fontSize(13).fontColor(MUTED).width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
              }.width('100%').constraintSize({ minHeight: 76 }).padding({ left: 13, right: 13, top: 11, bottom: 11 })
                .enabled(!this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive())
                .onClick(() => this.openDeviceFeature('photoDial')).id('wearable_photo_dial').accessibilityText(this.tr('照片表盘'))
            }
          }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        }

        if (visibleWatchDeviceFeatures(this.wearableSnapshot.capabilities)
          .filter((item: WatchDeviceFeatureSpec) => item.key !== 'photoDial').length > 0) {
          Text(this.tr('常用功能')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(visibleWatchDeviceFeatures(this.wearableSnapshot.capabilities)
              .filter((item: WatchDeviceFeatureSpec) => item.key !== 'photoDial'), (feature: WatchDeviceFeatureSpec) => {
              this.DeviceAction({ title: feature.title, icon: this.deviceFeatureIcon(feature.key), color: BLUE,
                background: BLUE_SOFT, action: () => this.openDeviceFeature(feature.key), id: `device_feature_${feature.key}` })
            }, (feature: WatchDeviceFeatureSpec) => feature.key)
          }.width('100%')
        }

        Text(this.tr('设备功能')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          this.DeviceAction({ title: '同步时间', icon: $r('sys.symbol.clock_arrow_2_circlepath'), color: RED, background: RED_SOFT,
            action: () => vepWearable.syncTime(), id: 'wearable_sync_time' })
          if (this.wearableSnapshot.capabilities.findDevice) {
            this.DeviceAction({ title: '查找手表', icon: $r('sys.symbol.bell_badge_local'), color: BLUE, background: BLUE_SOFT,
              action: () => vepWearable.findDevice(), id: 'wearable_find' })
          }
          this.DeviceAction({ title: '设备信息', icon: $r('sys.symbol.info_circle'), color: GREEN, background: GREEN_SOFT,
            action: () => vepWearable.refresh(), id: 'wearable_refresh' })
          this.DeviceAction({ title: '设备设置', icon: $r('sys.symbol.gearshape'), color: '#C98716', background: GOLD_SOFT,
            action: () => this.openDeviceSettings(), id: 'wearable_read_settings' })
        }.width('100%')

        Column({ space: 0 }) {
          Row({ space: 12 }) {
            Column() {
              SymbolGlyph($r('sys.symbol.info_circle')).fontSize(22).fontColor([BLUE])
            }.width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(13)
            Column({ space: 3 }) {
              Text(this.tr('关于设备')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
          }.width('100%').constraintSize({ minHeight: 66 }).padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .onClick(() => this.showFeature('关于设备',
              `设备：${this.wearableSnapshot.deviceName}\nMAC：${this.wearableSnapshot.mac || '未提供'}\n型号：${wearableModelText(this.wearableSnapshot.model, this.wearableSnapshot.deviceName)}\n固件：${this.wearableSnapshot.firmware || '未知'}`))
          Divider().color(LINE).margin({ left: 54 })
          Row({ space: 12 }) {
            Column() {
              SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(22).fontColor(['#C98716'])
            }.width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor(GOLD_SOFT).borderRadius(13)
            Column({ space: 3 }) {
              Text(this.tr('连接说明')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
          }.width('100%').constraintSize({ minHeight: 66 }).padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .onClick(() => this.showFeature('连接说明',
              '1. 打开手机蓝牙并允许查找附近设备。\n2. 让手表保持亮屏并靠近手机。\n3. 如果手表弹出确认，请及时确认。'))
        }.width('100%').padding(4).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      } else {
        Column({ space: 14 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.watch')).fontSize(62).fontColor([TECH_BLUE])
          }.width(118).height(118).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(59)
          Text(this.tr('添加智能设备')).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK)
          Text(this.tr('请开启手机蓝牙并将手表靠近手机')).fontSize(13).fontColor(MUTED)
            .textAlign(TextAlign.Center).lineHeight(20)
          Button(this.tr('开始查找')).width('100%').constraintSize({ minHeight: 50 }).backgroundColor(RED)
            .type(ButtonType.Normal).borderRadius(14).enabled(!this.wearableBusy())
            .onClick(() => this.openDeviceSearch()).id('wearable_scan')
        }.width('100%').padding({ left: 24, right: 24, top: 28, bottom: 24 }).backgroundColor(SURFACE)
          .borderRadius(20).border({ width: 1, color: LINE }).shadow({ radius: 12, color: CARD_SHADOW, offsetY: 4 })
          .id('device-add-card')
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(22).fontColor([BLUE])
          }.width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(13)
          Column({ space: 3 }) {
            Text(this.tr('连接说明')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(this.tr('手表保持亮屏、靠近手机，并确认未被其他手机占用')).fontSize(13).fontColor(MUTED)
              .width('100%').maxLines(2)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
        }.width('100%').constraintSize({ minHeight: 72 }).padding(13).backgroundColor(SURFACE).borderRadius(18)
          .border({ width: 1, color: LINE }).onClick(() => this.showFeature('连接说明',
            '1. 打开手机蓝牙并允许查找附近设备。\n2. 将手表充电激活并靠近手机。\n3. 点击“开始查找”选择自己的手表。'))
      }
      this.Notice({ message: '连接或同步时，请让手表保持电量充足并靠近手机。', color: BLUE_SOFT })
    }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 24 })
  }

  @Builder
  InstalledDialAction($$: DialRowProps) {
    if ($$.dial.selected) {
      Row() { SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(24).fontColor([GREEN]) }
        .width(48).height(this.controlHeight()).justifyContent(FlexAlign.Center).accessibilityText(this.tr('当前使用'))
    } else {
      Button(this.tr('使用')).constraintSize({ minWidth: 48 }).height(this.controlHeight()).fontSize(16).fontColor(RED)
        .backgroundColor(Color.Transparent).type(ButtonType.Normal).borderRadius(12)
        .enabled(!this.dialBusy && !this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive())
        .onClick(() => this.selectExistingDial($$.dial)).id(`dial_select_${$$.index}`)
        .accessibilityText(this.tr(`使用表盘 ${$$.index + 1}`))
    }
  }

  @Builder
  InstalledDialRow($$: DialRowProps) {
    Column({ space: 4 }) {
      Row({ space: 14 }) {
        Column() {
          Text(this.tr('预览\n暂不可用')).fontSize(11).fontWeight(FontWeight.Medium).fontColor(MUTED).textAlign(TextAlign.Center)
        }.width(Math.max(62, 44 * this.systemFontScale)).height(Math.max(62, 44 * this.systemFontScale))
          .justifyContent(FlexAlign.Center).backgroundColor('#F0F2F5').borderRadius(17)
          .accessibilityText(this.tr(`表盘 ${$$.index + 1} 预览暂不可用`))
        Column({ space: 4 }) {
          Text(this.tr(`表盘 ${$$.index + 1}`)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Text(this.tr($$.dial.selected ? '当前使用' : '已安装')).fontSize(14).fontColor($$.dial.selected ? GREEN : MUTED).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (!this.singleColumn()) { this.InstalledDialAction({ dial: $$.dial, index: $$.index }) }
      }.width('100%').constraintSize({ minHeight: 72 })
      if (this.singleColumn()) {
        Row() { this.InstalledDialAction({ dial: $$.dial, index: $$.index }) }
          .width('100%').justifyContent(FlexAlign.End)
      }
    }.width('100%').padding({ left: 16, right: 12, top: 8, bottom: 8 }).id(`installed_dial_row_${$$.index}`)
  }

  @Builder
  InstalledDialsContent() {
    if (!this.wearableSnapshot.connected) {
      this.StateCard({ title: '手表已断开', detail: '连接手表后可查看和切换表盘。', icon: $r('sys.symbol.watch') })
      Button(this.tr('添加设备')).width('100%').height(this.controlHeight()).backgroundColor(RED)
        .onClick(() => this.openDeviceSearch()).id('dials_connect')
    } else if (!this.wearableSnapshot.capabilities.dial) {
      this.StateCard({ title: '当前手表不支持此功能', icon: $r('sys.symbol.watch') })
    } else {
      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.info_circle')).fontSize(26).fontColor([RED])
        Column({ space: 4 }) {
          Text(this.tr('已安装表盘')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Text(this.tr(this.wearableSnapshot.deviceName)).fontSize(14).fontColor(MUTED).width('100%')
          Text(this.tr('可切换手表内已有表盘')).fontSize(14).fontColor(MUTED).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Text(this.tr('手表中的表盘')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      if (this.dialBusy) { LoadingProgress().width(32).height(32).color(RED) }
      if (this.dialMessage) { this.Notice({ message: this.dialMessage }) }
      if (!this.dialBusy && this.wearableSnapshot.dials.length === 0) {
        this.StateCard({ title: '暂无可用表盘', detail: '请让手表靠近手机后重新读取。', icon: $r('sys.symbol.watch') })
      }
      if (this.wearableSnapshot.dials.length > 0) {
        Column() {
          ForEach(this.wearableSnapshot.dials, (dial: WearableDial, index: number) => {
            this.InstalledDialRow({ dial: dial, index: index })
            if (index < this.wearableSnapshot.dials.length - 1) {
              Row() { Blank().width(92); Divider().color(LINE).layoutWeight(1) }.width('100%')
            }
          }, (dial: WearableDial, index: number) => dialRenderKey(dial, index))
        }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      }
      Button(this.tr(this.dialBusy ? '读取中…' : '刷新手表表盘')).width('100%').height(this.controlHeight()).fontSize(16).fontColor(RED)
        .backgroundColor(Color.Transparent).enabled(!this.dialBusy && !this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive())
        .onClick(() => this.refreshDials()).id('dials_refresh')
      if (this.wearableSnapshot.originalDialKey && this.wearableSnapshot.currentDialKey !== this.wearableSnapshot.originalDialKey) {
        Button(this.tr('恢复原表盘')).width('100%').height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(RED_SOFT)
          .enabled(!this.dialBusy && !this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive())
          .onClick(() => vepWearable.restoreOriginalDial()).id('wearable_restore_dial')
      }
    }
  }

  @Builder
  DeviceFeatureContent() {
    if (!this.wearableSnapshot.connected) {
      this.StateCard({ title: '手表已断开', detail: '重新连接后再查看或调整此功能。', icon: $r('sys.symbol.watch') })
    } else if (!watchDeviceFeatureSupported(this.wearableSnapshot.capabilities, this.selectedDeviceFeature)) {
      this.StateCard({ title: '当前手表不支持此功能', detail: '设备页只会展示手表能力表中已支持的功能。',
        icon: this.deviceFeatureIcon(this.selectedDeviceFeature) })
    } else {
      this.StateCard({ title: this.deviceFeatureSpec().title, detail: this.deviceFeatureSpec().subtitle,
        icon: this.deviceFeatureIcon(this.selectedDeviceFeature), green: this.deviceFeatureLoaded })
      if (this.deviceFeatureBusy) { LoadingProgress().width(34).height(34).color(RED) }
      if (this.deviceFeatureMessage) {
        this.Notice({ message: this.deviceFeatureMessage,
          color: this.deviceFeatureLoaded && !this.deviceFeatureMessage.includes('失败') &&
            !this.deviceFeatureMessage.includes('无法') ? GREEN_SOFT : GOLD_SOFT })
      }
      if (this.deviceFeatureLoaded) {
        if (this.selectedDeviceFeature === 'photoDial') {
          if (this.watchPhotoDial.supported) {
            this.Notice({ message: `将按手表实际分辨率 ${this.watchPhotoDial.width} × ${this.watchPhotoDial.height} 制作，传输时请保持设备靠近。` })
            if (this.photoDialUri) {
              Image(this.photoDialUri).width('100%').height(260).objectFit(ImageFit.Contain).backgroundColor('#111318')
                .borderRadius(18).accessibilityText(this.tr('已选择的照片表盘预览'))
            }
            Button(this.tr(this.photoDialUri ? '重新选择照片' : '选择照片')).width('100%').height(this.controlHeight(56))
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).backgroundColor(SURFACE)
              .type(ButtonType.Normal).borderRadius(14).border({ width: 1, color: OUTLINE })
              .enabled(!this.deviceFeatureBusy).onClick(() => this.pickPhotoDial()).id('photo_dial_pick')
            if (this.photoDialProgress > 0) {
              Progress({ value: this.photoDialProgress, total: 100, type: ProgressType.Linear }).width('100%').color(RED)
              Text(this.tr(`安装进度 ${this.photoDialProgress}%`)).fontSize(15).fontColor(MUTED).width('100%').textAlign(TextAlign.Center)
            }
            Button(this.tr(this.deviceFeatureWriting ? '正在安装…' : '安装到手表')).width('100%').height(this.controlHeight(56))
              .fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(14)
              .enabled(!this.deviceFeatureBusy && this.photoDialUri.length > 0).onClick(() => this.installPhotoDial())
              .id('photo_dial_install')
          } else {
            this.StateCard({ title: '暂未读取到照片表盘规格', detail: this.watchPhotoDial.message || '请重新读取后再试。',
              icon: $r('sys.symbol.camera_fill') })
          }
        } else if (this.selectedDeviceFeature === 'camera') {
          this.Notice({ message: '仅在点击开启后申请相机权限。本页面保持打开时，手表拍照键会直接拍摄并保存到手机图库。' })
          Stack() {
            XComponent({ id: 'saydian_camera_preview', type: XComponentType.SURFACE, controller: this.cameraController })
              .width('100%').height('100%').backgroundColor('#111318')
              .onLoad(() => this.cameraSurfaceLoaded()).onDestroy(() => this.cameraSurfaceDestroyed())
            if (!this.cameraRemoteEnabled) {
              Column({ space: 12 }) {
                SymbolGlyph($r('sys.symbol.camera_fill')).fontSize(62).fontColor([Color.White])
                Text(this.tr('开启后显示实时取景')).fontSize(17).fontColor(Color.White)
              }.width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('#99111318')
            }
            if (this.cameraCapturing) {
              Column({ space: 10 }) {
                LoadingProgress().width(38).height(38).color(Color.White)
                Text(this.tr('正在保存照片…')).fontSize(15).fontColor(Color.White)
              }.width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('#77111318')
            }
          }.width('100%').aspectRatio(0.75).backgroundColor('#111318').borderRadius(18).clip(true)
          Text(this.tr(this.cameraRemoteMessage || '相机遥控尚未开启')).fontSize(16).fontColor(INK).width('100%').textAlign(TextAlign.Center)
          if (this.cameraLastPhotoUri) {
            Row({ space: 12 }) {
              Image(this.cameraLastPhotoUri).width(82).height(82).objectFit(ImageFit.Cover).borderRadius(12)
                .accessibilityText(this.tr('最近拍摄并保存的照片'))
              Column({ space: 5 }) {
                Text(this.tr('最近拍摄')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                Text(this.tr('已保存到手机图库')).fontSize(14).fontColor(GREEN).width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%').padding(12).backgroundColor(SURFACE).borderRadius(16).border({ width: 1, color: LINE })
          }
          if (this.cameraRemoteEnabled) {
            Row({ space: 10 }) {
              Button(this.tr(this.cameraCapturing ? '正在拍照…' : '手机拍照')).layoutWeight(1).height(this.controlHeight(56))
                .fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(14)
                .enabled(!this.deviceFeatureBusy && !this.cameraCapturing).onClick(() => this.captureCameraPhoto(false))
                .id('camera_local_capture')
              Button(this.tr('关闭遥控')).layoutWeight(1).height(this.controlHeight(56)).fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(RED).backgroundColor(RED_SOFT).type(ButtonType.Normal).borderRadius(14)
                .enabled(!this.deviceFeatureBusy && !this.cameraCapturing).onClick(() => this.setCameraRemote(false))
                .id('camera_remote_close')
            }.width('100%')
          } else {
            Button(this.tr('开启相机遥控')).width('100%').height(this.controlHeight(56)).fontSize(16).fontWeight(FontWeight.Bold)
              .backgroundColor(RED).type(ButtonType.Normal).borderRadius(14).enabled(!this.deviceFeatureBusy)
              .onClick(() => this.setCameraRemote(true)).id('camera_remote_toggle')
          }
        } else if (this.selectedDeviceFeature === 'phoneCalls') {
          Column({ space: 12 }) {
            Text(this.tr(this.watchPhoneState.connected ? '蓝牙通话已连接' : '蓝牙通话未连接')).fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(this.watchPhoneState.connected ? GREEN : INK).width('100%')
            Text(this.tr(`手表通话开关：${this.watchPhoneState.enabled ? '开启' : '关闭'}`)).fontSize(16).fontColor(INK).width('100%')
            Text(this.tr(`设备配对状态：${this.watchPhoneState.paired ? '已配对' : '未配对'}`)).fontSize(16).fontColor(INK).width('100%')
            Text(this.tr(`媒体音频：${this.watchPhoneState.multimediaEnabled ? '开启' : '关闭'}`)).fontSize(16).fontColor(INK).width('100%')
          }.width('100%').padding(18).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          Button(this.tr(this.watchPhoneState.connected ? '重新读取连接状态' : '连接手表通话蓝牙')).width('100%').height(this.controlHeight(56))
            .fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(14)
            .enabled(!this.deviceFeatureBusy).onClick(() => this.watchPhoneState.connected ? this.refreshDeviceFeature() : this.connectWatchPhone())
            .id('watch_phone_connect')
        } else if (this.selectedDeviceFeature === 'contacts') {
          Column({ space: 12 }) {
            Text(this.tr(this.watchContactDraft.id > 0 ? '编辑联系人' : '添加联系人')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            TextInput({ text: this.watchContactDraft.name, placeholder: this.tr('姓名') }).height(this.controlHeight(52)).fontSize(17).maxLength(20)
              .backgroundColor(SURFACE_ALT).borderRadius(12).enabled(!this.deviceFeatureBusy)
              .onChange((value: string) => this.changeContactDraft('name', value)).id('watch_contact_name')
            TextInput({ text: this.watchContactDraft.phone, placeholder: this.tr('电话号码') }).height(this.controlHeight(52)).fontSize(17)
              .type(InputType.PhoneNumber).maxLength(20).backgroundColor(SURFACE_ALT).borderRadius(12).enabled(!this.deviceFeatureBusy)
              .onChange((value: string) => this.changeContactDraft('phone', value)).id('watch_contact_phone')
            if (watchContactError(this.watchContactDraft) && (this.watchContactDraft.name || this.watchContactDraft.phone)) {
              Text(watchContactError(this.watchContactDraft)).fontSize(14).fontColor(RED_DARK).width('100%')
            }
            Row({ space: 10 }) {
              if (this.watchContactDraft.id > 0) {
                Button(this.tr('取消编辑')).layoutWeight(1).height(this.controlHeight()).fontSize(16).fontColor(INK).backgroundColor(SURFACE_ALT)
                  .enabled(!this.deviceFeatureBusy).onClick(() => this.editWatchContact()).id('watch_contact_cancel')
              }
              Button(this.tr(this.watchContactDraft.id > 0 ? '保存修改' : '添加到手表')).layoutWeight(1).height(this.controlHeight())
                .fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED).enabled(!this.deviceFeatureBusy && !watchContactError(this.watchContactDraft))
                .onClick(() => this.saveWatchContact()).id('watch_contact_save')
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          if (this.watchContacts.length === 0) {
            this.StateCard({ title: '手表中还没有联系人', icon: $r('sys.symbol.person_2_fill') })
          }
          ForEach(this.watchContacts, (contact: WatchContact) => {
            Column({ space: 10 }) {
              Row({ space: 12 }) {
                Column() { SymbolGlyph($r('sys.symbol.person_fill')).fontSize(24).fontColor([contact.sos ? RED : BLUE]) }
                  .width(46).height(46).justifyContent(FlexAlign.Center).backgroundColor(contact.sos ? RED_SOFT : BLUE_SOFT).borderRadius(23)
                Column({ space: 4 }) {
                  Row({ space: 7 }) {
                    Text(this.tr(contact.name)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(1)
                    if (contact.sos) {
                      Text(this.tr('当前 SOS')).fontSize(12).fontWeight(FontWeight.Bold).fontColor(RED)
                        .padding({ left: 7, right: 7, top: 3, bottom: 3 }).backgroundColor(RED_SOFT).borderRadius(10)
                    }
                  }.width('100%')
                  Text(this.tr(contact.phone)).fontSize(15).fontColor(MUTED).width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%')
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                Button(this.tr('编辑')).width(this.singleColumn() ? '100%' : '31%').height(this.controlHeight()).fontColor(INK).backgroundColor(SURFACE_ALT)
                  .enabled(!this.deviceFeatureBusy).onClick(() => this.editWatchContact(contact)).id(`watch_contact_edit_${contact.id}`)
                Button(this.tr(contact.sos ? '已是 SOS' : '设为 SOS')).width(this.singleColumn() ? '100%' : '36%').height(this.controlHeight())
                  .fontColor(contact.sos ? GREEN : RED).backgroundColor(contact.sos ? GREEN_SOFT : RED_SOFT)
                  .enabled(!this.deviceFeatureBusy && !contact.sos).onClick(() => this.setWatchSos(contact)).id(`watch_contact_sos_${contact.id}`)
                Button(this.tr('删除')).width(this.singleColumn() ? '100%' : '27%').height(this.controlHeight()).fontColor(RED)
                  .backgroundColor(Color.Transparent).enabled(!this.deviceFeatureBusy).onClick(() => this.deleteWatchContact(contact))
                  .id(`watch_contact_delete_${contact.id}`)
              }.width('100%')
            }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          }, (contact: WatchContact) => `${contact.id}-${contact.name}-${contact.phone}-${contact.sos}`)
        } else if (this.selectedDeviceFeature === 'notifications') {
          if (this.watchNotifications.length === 0) {
            this.StateCard({ title: '手表没有返回可配置的消息类型', icon: $r('sys.symbol.bell_fill') })
          }
          Column() {
            ForEach(this.watchNotifications, (item: WatchNotificationSetting, index: number) => {
              Row({ space: 12 }) {
                Text(this.tr(item.label)).fontSize(17).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: item.enabled }).selectedColor(RED).enabled(!this.deviceFeatureBusy)
                  .onChange((enabled: boolean) => this.setWatchNotification(item, enabled))
                  .accessibilityText(this.tr(`${item.label}${item.enabled ? '已开启' : '已关闭'}`)).id(`watch_notification_${item.key}`)
              }.width('100%').constraintSize({ minHeight: 62 }).padding({ left: 16, right: 12 })
              if (index < this.watchNotifications.length - 1) { Divider().color(LINE).margin({ left: 16 }) }
            }, (item: WatchNotificationSetting) => `${item.key}-${item.enabled}`)
          }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        } else if (this.selectedDeviceFeature === 'weather') {
          Column({ space: 8 }) {
            Row() {
              Column({ space: 4 }) {
                Text(this.tr('手表天气')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                Text(this.tr('开启后同步天气信息到手表')).fontSize(14).fontColor(MUTED).width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.watchWeather.enabled }).selectedColor(RED)
                .enabled(!this.deviceFeatureBusy).onChange((enabled: boolean) => this.saveWatchWeather(enabled, this.watchWeather.celsius))
                .id('watch_weather_enabled')
            }.width('100%').constraintSize({ minHeight: 68 }).padding(16)
            Divider().color(LINE)
            Text(this.tr('温度单位')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').padding({ left: 16, right: 16, top: 8 })
            Row({ space: 10 }) {
              Button(this.tr('摄氏度 ℃')).layoutWeight(1).height(this.controlHeight()).fontColor(this.watchWeather.celsius ? RED : INK)
                .backgroundColor(this.watchWeather.celsius ? RED_SOFT : SURFACE_ALT).enabled(!this.deviceFeatureBusy)
                .onClick(() => this.saveWatchWeather(this.watchWeather.enabled, true)).id('watch_weather_celsius')
              Button(this.tr('华氏度 ℉')).layoutWeight(1).height(this.controlHeight()).fontColor(!this.watchWeather.celsius ? RED : INK)
                .backgroundColor(!this.watchWeather.celsius ? RED_SOFT : SURFACE_ALT).enabled(!this.deviceFeatureBusy)
                .onClick(() => this.saveWatchWeather(this.watchWeather.enabled, false)).id('watch_weather_fahrenheit')
            }.width('100%').padding({ left: 16, right: 16, bottom: 16 })
          }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        } else if (this.selectedDeviceFeature === 'worldClock') {
          if (this.watchWorldClocks.length === 0) {
            this.StateCard({ title: '手表中还没有世界时钟', icon: $r('sys.symbol.clock') })
          }
          ForEach(this.watchWorldClocks, (clock: WatchWorldClock) => {
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text(this.tr(clock.city)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                Text(this.watchWorldClockOffset(clock.utcOffsetMinutes)).fontSize(14).fontColor(MUTED).width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Button(this.tr('删除')).height(this.controlHeight()).fontColor(RED).backgroundColor(RED_SOFT).enabled(!this.deviceFeatureBusy)
                .onClick(() => this.deleteWatchWorldClock(clock)).id(`watch_clock_delete_${clock.id}`)
            }.width('100%').constraintSize({ minHeight: 74 }).padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          }, (clock: WatchWorldClock) => `${clock.id}-${clock.city}-${clock.utcOffsetMinutes}`)
          Text(this.tr('添加城市')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.worldClockPresets, (preset: WorldClockPreset) => {
              Button(`${preset.city}\n${this.watchWorldClockOffset(preset.utcOffsetMinutes)}`).width(this.singleColumn() ? '100%' : '48%')
                .constraintSize({ minHeight: 64 }).fontSize(15).fontColor(INK).backgroundColor(SURFACE)
                .type(ButtonType.Normal).borderRadius(14).border({ width: 1, color: LINE }).margin({ bottom: 10 })
                .enabled(!this.deviceFeatureBusy && !this.watchWorldClocks.some((clock: WatchWorldClock) => clock.city === preset.city))
                .onClick(() => this.addWatchWorldClock(preset)).id(`watch_clock_add_${preset.city}`)
            }, (preset: WorldClockPreset) => preset.city)
          }.width('100%')
        } else if (this.selectedDeviceFeature === 'healthReminders') {
          if (this.watchReminders.length === 0) {
            this.StateCard({ title: '手表没有返回可配置的健康提醒', icon: $r('sys.symbol.heart_fill') })
          }
          ForEach(this.watchReminders, (item: WatchReminder) => {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 4 }) {
                  Text(this.tr(item.label)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                  Text(this.tr(`${item.startTime} - ${item.endTime}`)).fontSize(14).fontColor(MUTED).width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: item.enabled }).selectedColor(RED).enabled(!this.deviceFeatureBusy)
                  .onChange((enabled: boolean) => this.setWatchReminder(item, enabled)).id(`watch_reminder_toggle_${item.id}`)
              }.width('100%')
              Row({ space: 10 }) {
                Button(this.tr('−')).width(52).height(this.controlHeight()).fontSize(22).fontColor(RED).backgroundColor(RED_SOFT)
                  .enabled(!this.deviceFeatureBusy && item.intervalMinutes > 15)
                  .onClick(() => this.setWatchReminder(item, item.enabled, -15)).id(`watch_reminder_less_${item.id}`)
                Text(this.tr(`每 ${item.intervalMinutes} 分钟`)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1).textAlign(TextAlign.Center)
                Button(this.tr('+')).width(52).height(this.controlHeight()).fontSize(22).fontColor(RED).backgroundColor(RED_SOFT)
                  .enabled(!this.deviceFeatureBusy && item.intervalMinutes < 240)
                  .onClick(() => this.setWatchReminder(item, item.enabled, 15)).id(`watch_reminder_more_${item.id}`)
              }.width('100%')
            }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          }, (item: WatchReminder) => `${item.id}-${item.enabled}-${item.intervalMinutes}`)
        } else if (this.selectedDeviceFeature === 'healthMonitoring') {
          this.Notice({ message: '监测间隔按手表支持的最小步长调整，保存后会重新读取确认。' })
          if (this.watchAutoMeasures.length === 0) {
            this.StateCard({ title: '手表没有返回可配置的自动监测项目', icon: $r('sys.symbol.waveform') })
          }
          ForEach(this.watchAutoMeasures, (item: WatchAutoMeasureSetting) => {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 4 }) {
                  Text(this.tr(item.label)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                  Text(this.tr(item.timeSlotModifiable ? `${item.startTime} - ${item.endTime}` : '全天按手表规则监测'))
                    .fontSize(14).fontColor(MUTED).width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: item.enabled }).selectedColor(RED).enabled(!this.deviceFeatureBusy)
                  .onChange((enabled: boolean) => this.setWatchAutoMeasure(item, enabled)).id(`watch_auto_toggle_${item.feature}`)
              }.width('100%')
              if (item.intervalModifiable) {
                Row({ space: 10 }) {
                  Button(this.tr('−')).width(52).height(this.controlHeight()).fontSize(22).fontColor(RED).backgroundColor(RED_SOFT)
                    .enabled(!this.deviceFeatureBusy && item.intervalMinutes > item.minimumIntervalMinutes)
                    .onClick(() => this.setWatchAutoMeasure(item, item.enabled, -1)).id(`watch_auto_less_${item.feature}`)
                  Text(this.tr(`每 ${item.intervalMinutes} 分钟`)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1).textAlign(TextAlign.Center)
                  Button(this.tr('+')).width(52).height(this.controlHeight()).fontSize(22).fontColor(RED).backgroundColor(RED_SOFT)
                    .enabled(!this.deviceFeatureBusy && item.intervalMinutes < 1440)
                    .onClick(() => this.setWatchAutoMeasure(item, item.enabled, 1)).id(`watch_auto_more_${item.feature}`)
                }.width('100%')
              } else {
                Text(this.tr(`监测间隔由手表固定为 ${item.intervalMinutes} 分钟`)).fontSize(14).fontColor(MUTED).width('100%')
              }
            }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          }, (item: WatchAutoMeasureSetting) => `${item.feature}-${item.enabled}-${item.intervalMinutes}`)
        } else if (this.selectedDeviceFeature === 'healthAssessment') {
          if (this.watchAssessments.length === 0) {
            this.StateCard({ title: '手表没有返回可配置的辅助评估', icon: $r('sys.symbol.checkmark_shield_fill') })
          }
          Column() {
            ForEach(this.watchAssessments, (item: WatchAssessmentSetting, index: number) => {
              Row({ space: 12 }) {
                Text(this.tr(item.label)).fontSize(17).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: item.enabled }).selectedColor(RED).enabled(!this.deviceFeatureBusy)
                  .onChange((enabled: boolean) => this.setWatchAssessment(item, enabled)).id(`watch_assessment_${item.dataType}`)
              }.width('100%').constraintSize({ minHeight: 62 }).padding({ left: 16, right: 12 })
              if (index < this.watchAssessments.length - 1) { Divider().color(LINE).margin({ left: 16 }) }
            }, (item: WatchAssessmentSetting) => `${item.dataType}-${item.enabled}`)
          }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        } else if (this.selectedDeviceFeature === 'screenDisplay') {
          if (this.watchScreen.durationSupported) {
            Column({ space: 12 }) {
              Text(this.tr('亮屏时长')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
              Row({ space: 10 }) {
                Button(this.tr('−')).width(52).height(this.controlHeight()).fontSize(22).fontColor(RED).backgroundColor(RED_SOFT)
                  .enabled(!this.deviceFeatureBusy && this.watchScreen.durationSeconds > 1)
                  .onClick(() => this.saveWatchScreen(this.nextWatchScreen(
                    Math.max(1, this.watchScreen.durationSeconds - 1)))).id('watch_screen_duration_less')
                Text(this.tr(`${this.watchScreen.durationSeconds} 秒`)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK)
                  .layoutWeight(1).textAlign(TextAlign.Center)
                Button(this.tr('+')).width(52).height(this.controlHeight()).fontSize(22).fontColor(RED).backgroundColor(RED_SOFT)
                  .enabled(!this.deviceFeatureBusy && this.watchScreen.durationSeconds < 120)
                  .onClick(() => this.saveWatchScreen(this.nextWatchScreen(
                    Math.min(120, this.watchScreen.durationSeconds + 1)))).id('watch_screen_duration_more')
              }.width('100%')
            }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          }
          if (this.watchScreen.raiseToWakeSupported) {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 4 }) {
                  Text(this.tr('抬腕亮屏')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                  Text(this.tr(`${this.watchScreen.raiseToWakeStartTime} - ${this.watchScreen.raiseToWakeEndTime}`))
                    .fontSize(14).fontColor(MUTED).width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: this.watchScreen.raiseToWakeEnabled }).selectedColor(RED)
                  .enabled(!this.deviceFeatureBusy).onChange((enabled: boolean) =>
                    this.saveWatchScreen(this.nextWatchScreen(undefined, enabled))).id('watch_raise_to_wake')
              }.width('100%')
              Row({ space: 10 }) {
                Button(this.tr('−')).width(52).height(this.controlHeight()).fontSize(22).fontColor(RED).backgroundColor(RED_SOFT)
                  .enabled(!this.deviceFeatureBusy && this.watchScreen.raiseToWakeLevel > 1)
                  .onClick(() => this.saveWatchScreen(this.nextWatchScreen(undefined, undefined,
                    Math.max(1, this.watchScreen.raiseToWakeLevel - 1)))).id('watch_raise_level_less')
                Text(this.tr(`灵敏度 ${this.watchScreen.raiseToWakeLevel}`)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK)
                  .layoutWeight(1).textAlign(TextAlign.Center)
                Button(this.tr('+')).width(52).height(this.controlHeight()).fontSize(22).fontColor(RED).backgroundColor(RED_SOFT)
                  .enabled(!this.deviceFeatureBusy && this.watchScreen.raiseToWakeLevel < 10)
                  .onClick(() => this.saveWatchScreen(this.nextWatchScreen(undefined, undefined,
                    Math.min(10, this.watchScreen.raiseToWakeLevel + 1)))).id('watch_raise_level_more')
              }.width('100%')
            }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          }
          if (!this.watchScreen.durationSupported && !this.watchScreen.raiseToWakeSupported) {
            this.StateCard({ title: '当前手表没有可调整的屏幕项目', icon: $r('sys.symbol.brightness') })
          }
        }
      }
      Button(this.tr(this.deviceFeatureBusy ? '读取中…' : '重新读取手表设置')).width('100%').height(this.controlHeight())
        .fontSize(16).fontColor(RED).backgroundColor(Color.Transparent).enabled(!this.deviceFeatureBusy)
        .onClick(() => this.refreshDeviceFeature()).id('device_feature_refresh')
    }
  }

  @Builder
  DeviceSettingsContent() {
    if (!this.wearableSnapshot.connected) {
      this.StateCard({ title: '手表已断开', detail: '重新连接后查看设备设置。', icon: $r('sys.symbol.watch') })
    } else {
      Text(this.tr(this.wearableSnapshot.deviceName)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      this.PageRow({ title: '手表单位', subtitle: '公英制、温度单位', icon: $r('sys.symbol.gearshape'),
        action: () => this.openWatchSettings('device-units'), id: 'settings_units' })
      if (this.wearableSnapshot.capabilities.alarm) {
        this.PageRow({ title: '闹钟', subtitle: '时间、重复与提醒名称', icon: $r('sys.symbol.clock'),
          action: () => this.openWatchSettings('device-alarms'), id: 'settings_alarms' })
      }
      if (this.wearableSnapshot.settings.loadedAt > 0 && !this.settingsBusy && !this.settingsMessage) {
        Column({ space: 14 }) {
          Text(this.tr(`单位：${this.wearableSnapshot.settings.unitSystem}`)).fontSize(16).fontColor(INK).width('100%')
          Divider().color(LINE)
          Text(this.tr(`时制：${this.wearableSnapshot.settings.timeFormat}`)).fontSize(16).fontColor(INK).width('100%')
          Divider().color(LINE)
          Text(this.tr(`自动健康：${this.wearableSnapshot.settings.automaticHealth}`)).fontSize(16).fontColor(INK).width('100%')
          if (this.wearableSnapshot.capabilities.sedentaryReminder) {
            Divider().color(LINE)
            Text(this.tr(`久坐提醒：${this.wearableSnapshot.settings.sedentaryReminder}`)).fontSize(16).fontColor(INK).width('100%')
          }
          if (this.wearableSnapshot.capabilities.notification) {
            Divider().color(LINE)
            Text(this.tr(`消息提醒：${this.wearableSnapshot.settings.messageReminder}`)).fontSize(16).fontColor(INK).width('100%')
          }
          if (this.wearableSnapshot.capabilities.alarm) {
            Divider().color(LINE)
            Text(this.wearableSnapshot.settings.alarms.length > 0 ? `闹钟：${this.wearableSnapshot.settings.alarms.join('\n')}` : '暂无闹钟')
              .fontSize(16).fontColor(INK).width('100%')
          }
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        Text(this.tr('其他设置可在手表上查看和调整。')).fontSize(14).fontColor(MUTED).width('100%')
      } else { this.StateCard({ title: this.settingsBusy ? '正在读取设备设置' : '暂未读取到设备设置', icon: $r('sys.symbol.gearshape') }) }
      if (this.settingsMessage) { this.Notice({ message: this.settingsMessage }) }
      Button(this.tr(this.settingsBusy ? '读取中…' : '重新读取')).width('100%').height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(Color.Transparent)
        .enabled(!this.settingsBusy && !this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive()).onClick(() => this.refreshDeviceSettings())
        .id('settings_refresh')
      Button(this.tr('同步时间')).width('100%').height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(RED_SOFT)
        .enabled(!this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive()).onClick(() => vepWearable.syncTime()).id('settings_sync_time')
    }
  }

  @Builder
  WatchUnitCard($$: WatchUnitOptions) {
    if (supportedWatchUnit($$.value)) {
      Column({ space: 12 }) {
        Text(this.tr($$.title)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Button(watchUnitChoiceLabel($$.field, 1)).width('100%').height(this.controlHeight())
          .fontSize(16).fontColor($$.value === 1 ? RED : INK).backgroundColor($$.value === 1 ? RED_SOFT : SURFACE_ALT)
          .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: $$.value === 1 ? RED : LINE })
          .enabled(!this.deviceEditorBusy && this.deviceEditorLoaded).onClick(() => this.setWatchUnit($$.field, 1))
          .accessibilityText(`${watchUnitChoiceLabel($$.field, 1)}${$$.value === 1 ? '，当前使用' : ''}`).id(`watch_unit_${$$.field}_1`)
        Button(watchUnitChoiceLabel($$.field, 2)).width('100%').height(this.controlHeight())
          .fontSize(16).fontColor($$.value === 2 ? RED : INK).backgroundColor($$.value === 2 ? RED_SOFT : SURFACE_ALT)
          .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: $$.value === 2 ? RED : LINE })
          .enabled(!this.deviceEditorBusy && this.deviceEditorLoaded).onClick(() => this.setWatchUnit($$.field, 2))
          .accessibilityText(`${watchUnitChoiceLabel($$.field, 2)}${$$.value === 2 ? '，当前使用' : ''}`).id(`watch_unit_${$$.field}_2`)
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    }
  }

  @Builder
  WatchSettingsContent() {
    if (!this.wearableSnapshot.connected) {
      this.StateCard({ title: '手表已断开', detail: '重新连接后再查看或调整。', icon: $r('sys.symbol.watch') })
    } else if (this.screen !== 'device-units' && !this.wearableSnapshot.capabilities.alarm) {
      this.StateCard({ title: '当前手表不支持闹钟管理', icon: $r('sys.symbol.clock') })
    } else {
      if (this.deviceEditorBusy) { LoadingProgress().width(32).height(32).color(RED) }
      if (this.deviceEditorMessage) { this.Notice({ message: this.deviceEditorMessage }) }
      if (this.screen === 'device-units') {
        this.WatchUnitCard({ title: '距离单位', field: 'unitSystem', value: this.watchUnits.unitSystem })
        this.WatchUnitCard({ title: '温度单位', field: 'tempUnit', value: this.watchUnits.tempUnit })
        this.WatchUnitCard({ title: '时间格式', field: 'timeFormat', value: this.watchUnits.timeFormat })
        if (this.deviceEditorLoaded && !supportedWatchUnit(this.watchUnits.unitSystem) &&
          !supportedWatchUnit(this.watchUnits.tempUnit) && !supportedWatchUnit(this.watchUnits.timeFormat)) {
          this.StateCard({ title: '当前手表没有可调整的单位', icon: $r('sys.symbol.gearshape') })
        }
        Text(this.tr('此处修改手表显示单位，不改变已有健康记录。')).fontSize(14).fontColor(MUTED).width('100%')
      } else if (this.screen === 'device-alarm-edit') {
        this.WatchAlarmEditor()
      } else {
        if (this.deviceEditorLoaded && this.watchAlarms.length === 0) {
          this.StateCard({ title: '手表中还没有闹钟', icon: $r('sys.symbol.clock') })
        }
        ForEach(this.watchAlarms, (alarm: WatchAlarm) => {
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              Column({ space: 5 }) {
                Text(this.tr(alarm.time)).fontSize(28).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
                if (alarm.label) { Text(this.tr(alarm.label)).fontSize(16).fontColor(INK).width('100%') }
                Text(alarmRepeatText(alarm.days)).fontSize(14).fontColor(MUTED).width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: alarm.enabled }).selectedColor(RED)
                .enabled(!this.deviceEditorBusy && this.deviceEditorLoaded).onChange((enabled: boolean) => this.toggleWatchAlarm(alarm, enabled))
                .accessibilityText(this.tr(`${alarm.time}闹钟${alarm.enabled ? '已开启' : '已关闭'}`)).id(`alarm_toggle_${alarm.id}`)
            }.width('100%')
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              Button(this.tr('编辑')).width(this.singleColumn() ? '100%' : '48%').height(this.controlHeight()).fontSize(16)
                .fontColor(RED).backgroundColor(RED_SOFT).enabled(!this.deviceEditorBusy && this.deviceEditorLoaded)
                .onClick(() => this.editWatchAlarm(alarm)).id(`alarm_edit_${alarm.id}`)
              Button(this.tr('删除')).width(this.singleColumn() ? '100%' : '48%').height(this.controlHeight()).fontSize(16)
                .fontColor(RED).backgroundColor(Color.Transparent).enabled(!this.deviceEditorBusy && this.deviceEditorLoaded)
                .onClick(() => this.removeWatchAlarm(alarm)).id(`alarm_delete_${alarm.id}`)
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        }, (alarm: WatchAlarm) => JSON.stringify(alarm))
        Button(this.tr('添加闹钟')).width('100%').height(this.controlHeight()).fontSize(16).backgroundColor(RED)
          .enabled(!this.deviceEditorBusy && this.deviceEditorLoaded).onClick(() => this.editWatchAlarm()).id('alarm_add')
      }
      if (this.screen !== 'device-alarm-edit') {
        Button(this.tr(this.deviceEditorBusy ? '读取中…' : '重新读取')).width('100%').height(this.controlHeight()).fontSize(16)
          .fontColor(RED).backgroundColor(Color.Transparent).enabled(!this.deviceEditorBusy)
          .onClick(() => this.refreshWatchSettings()).id('watch_settings_refresh')
      } else if (!this.deviceEditorLoaded) {
        Button(this.tr('返回闹钟列表重新读取')).width('100%').height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(RED_SOFT)
          .enabled(!this.deviceEditorBusy).onClick(() => {
            this.innerParents.delete('device-alarm-edit'); this.screen = 'device-alarms'; this.refreshWatchSettings();
          }).id('alarm_retry_list')
      }
    }
  }

  @Builder
  WatchAlarmEditor() {
    Column({ space: 16 }) {
      Button(this.tr(this.watchAlarmDraft.time)).width('100%').height(this.controlHeight(60)).fontSize(28).fontWeight(FontWeight.Bold)
        .fontColor(INK).backgroundColor(SURFACE_ALT).type(ButtonType.Normal).borderRadius(12)
        .enabled(!this.deviceEditorBusy).onClick(() => this.pickWatchAlarmTime()).id('alarm_time')
      Row() {
        Text(this.tr('启用闹钟')).fontSize(16).fontColor(INK).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.watchAlarmDraft.enabled }).selectedColor(RED)
          .enabled(!this.deviceEditorBusy).onChange((enabled: boolean) => this.changeAlarmDraft('enabled', String(enabled)))
          .accessibilityText(this.tr('启用闹钟')).id('alarm_enabled')
      }.width('100%').constraintSize({ minHeight: 48 })
      TextInput({ text: this.watchAlarmDraft.label, placeholder: this.tr('提醒名称，例如起床') }).fontSize(16)
        .height(this.controlHeight(56)).width('100%').maxLength(21).backgroundColor(SURFACE_ALT).borderRadius(12)
        .enabled(!this.deviceEditorBusy).onChange((value: string) => this.changeAlarmDraft('label', value)).id('alarm_label')
      if (alarmDraftError(this.watchAlarmDraft)) {
        Text(alarmDraftError(this.watchAlarmDraft)).fontSize(14).fontColor(RED_DARK).width('100%')
      }
      Text(this.tr('重复')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(['周一', '周二', '周三', '周四', '周五', '周六', '周日'], (day: string, index: number) => {
          Button(this.tr(day)).width(this.singleColumn() ? '100%' : '30%').height(this.controlHeight()).fontSize(16)
            .fontColor(this.watchAlarmDraft.days[index] ? RED : INK)
            .backgroundColor(this.watchAlarmDraft.days[index] ? RED_SOFT : SURFACE_ALT).margin({ bottom: 8 })
            .enabled(!this.deviceEditorBusy).onClick(() => this.changeAlarmDraft(String(index), ''))
            .accessibilityText(this.tr(`${day}${this.watchAlarmDraft.days[index] ? '，已选择' : '，未选择'}`)).id(`alarm_day_${index}`)
        })
      }.width('100%')
      Text(alarmRepeatText(this.watchAlarmDraft.days)).fontSize(14).fontColor(MUTED).width('100%')
      Button(this.tr(this.deviceSettingsWriting ? '保存中…' : '保存')).width('100%').height(this.controlHeight(56)).fontSize(16).backgroundColor(RED)
        .enabled(!this.deviceEditorBusy && this.deviceEditorLoaded && !alarmDraftError(this.watchAlarmDraft))
        .onClick(() => this.saveAlarmDraft()).id('alarm_save')
    }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
  }

  @Builder
  DeviceSearchContent() {
    Column({ space: 5 }) {
      Text(this.tr('已发现设备')).fontSize(26).fontWeight(FontWeight.Bold).fontColor(INK)
      Text(this.tr('searchNearbyWatch')).fontSize(15).fontColor(MUTED)
    }.width('100%').padding({ top: 8, bottom: 10 })

    if (this.wearablePhase === 'error' || this.wearablePhase === 'permission') {
      this.Notice({ message: this.wearableMessage, color: '#FFF0E9' })
    }
    if (this.wearablePhase === 'scanning') {
      Row({ space: 8 }) {
        LoadingProgress().width(18).height(18).color(TECH_BLUE)
        Text(this.tr('正在搜索附近设备')).fontSize(13).fontColor(MUTED)
        TextTimer({ isCountDown: true, count: WEARABLE_SCAN_TIMEOUT_MS,
          controller: this.scanCountdownController }).format('ss').fontSize(13).fontColor(MUTED)
          .onAppear(() => {
            try {
              this.scanCountdownController.reset();
              this.scanCountdownController.start();
            } catch {}
          })
          .onTimer((_utc: number, elapsedTime: number) => {
            // With format('ss'), Harmony reports elapsed whole seconds.
            if (elapsedTime * 1000 < WEARABLE_SCAN_TIMEOUT_MS) return;
            vepWearable.stopScan('扫描已完成');
          })
          .onDisAppear(() => {
            try { this.scanCountdownController.pause(); } catch {}
          })
        Text(this.tr('秒')).fontSize(13).fontColor(MUTED)
      }.width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 4 })
    }
    if (this.wearableDevices.length === 0) {
      Column({ space: 14 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.dot_radiowaves_left_and_right')).fontSize(48).fontColor([TECH_BLUE])
        }.width(104).height(104).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(52)
        Text(this.tr(this.wearablePhase === 'scanning' ? 'searchRingTitle' : 'noRingFound'))
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK)
        Text(this.tr(this.wearablePhase === 'scanning' ? 'watchNearbyHint' : 'ringSearchHint'))
          .fontSize(13).fontColor(MUTED).lineHeight(20).textAlign(TextAlign.Center).width('100%')
      }.width('100%').padding({ top: 42, bottom: 42 })
    }
    ForEach(this.wearableDevices, (device: WearableDevice) => {
      Row({ space: 12 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.circle')).fontSize(29).fontColor([Color.White])
        }.width(52).height(52).justifyContent(FlexAlign.Center).backgroundColor(INK).borderRadius(15)
        Column({ space: 6 }) {
          Text(this.tr(device.name)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(wearableIdentifierText(device)).fontSize(13).fontColor(MUTED).maxLines(1).width('100%')
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 6 }) {
          Text(this.signalText(device.rssi)).fontSize(12).fontColor(MUTED)
          Text(this.tr('连接')).fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(device.provider === 'Vep' ? TECH_BLUE : GREEN)
        }.alignItems(HorizontalAlign.End)
      }.width('100%').constraintSize({ minHeight: 86 }).padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        .shadow({ radius: 9, color: CARD_SHADOW, offsetY: 3 })
        .enabled(device.connectable && !this.wearableBusy())
        .onClick(() => vepWearable.connect(device.key))
        .accessibilityText(`${device.name}，${this.signalText(device.rssi)}`)
    }, (device: WearableDevice) => deviceRenderKey(device))

    Row({ space: 7 }) {
      SymbolGlyph($r('sys.symbol.bag')).fontSize(18).fontColor([RED])
      Text(this.tr('noWatchShopHint')).fontSize(15).fontWeight(FontWeight.Bold).fontColor(RED)
    }.width('100%').height(52).justifyContent(FlexAlign.Center).onClick(() => this.openShop())
      .id('device_search_shop').accessibilityText(this.tr('shop'))
  }

  @Builder
  MineHome() {
    Column({ space: 12 }) {
      Row({ space: 14 }) {
        if (!this.guest && this.profile.head_portrait) {
          Image(this.profile.head_portrait).width(66).height(66).objectFit(ImageFit.Cover).borderRadius(33)
            .accessibilityText(this.tr('个人头像'))
        } else {
          Image($r('app.media.app_icon')).width(66).height(66).borderRadius(33).accessibilityText(this.tr('appName'))
        }
        Column({ space: 5 }) {
          Text(this.guest ? this.tr('暂未登录') : this.displayName).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK)
            .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (!this.guest) {
            Text(formatAppText('memberId', { id: profileField(this.profile.id) }, this.appLocale)).fontSize(14).fontColor(MUTED).width('100%')
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column() {
          SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(19).fontColor([RED])
        }.width(36).height(36).justifyContent(FlexAlign.Center).backgroundColor(SURFACE).borderRadius(18)
      }.width('100%').padding(20).linearGradient({ angle: 135,
        colors: [['#FFF8F3', 0.0], ['#FFECEE', 1.0]] }).borderRadius(24)
        .border({ width: 1, color: '#F6C9D2' }).shadow({ radius: 12, color: CARD_SHADOW, offsetY: 4 })
        .onClick(() => {
          if (this.guest) { this.error = ''; this.screen = 'login'; return; }
          this.openProfileEditor();
        }).id('mine-profile-card').accessibilityText(this.tr(this.guest ? 'signIn' : '编辑个人资料'))
      if (this.guest) {
        Button(this.tr('signIn')).width('100%').height(this.controlHeight(50)).backgroundColor(RED)
          .type(ButtonType.Normal).borderRadius(14)
          .onClick(() => { this.error = ''; this.screen = 'login'; }).id('go_login')
      } else {
        Row({ space: 9 }) {
          Column({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.watch')).fontSize(23)
              .fontColor([this.wearableSnapshot.connected ? GREEN : MUTED])
            Text(this.tr(this.wearableSnapshot.connected ? '在线' : '未连接')).fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor(this.wearableSnapshot.connected ? GREEN : MUTED).maxLines(1)
            Text(this.tr('设备')).fontSize(12).fontColor(MUTED)
          }.layoutWeight(1).constraintSize({ minHeight: 86 }).justifyContent(FlexAlign.Center)
            .backgroundColor(SURFACE).borderRadius(17).border({ width: 1, color: LINE })
            .shadow({ radius: 8, color: CARD_SHADOW, offsetY: 3 }).onClick(() => this.selectHomeTab(1))
            .id('profile_stat_device').accessibilityText(this.tr(`设备，${this.wearableSnapshot.connected ? '在线' : '未连接'}`))
          Column({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(23).fontColor([RED])
            Text(formatAppText('recordCount', { count: String(this.wearableSnapshot.records.length) }, this.appLocale)).fontSize(14).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(1)
            Text(this.tr('健康记录')).fontSize(12).fontColor(MUTED).maxLines(1)
          }.layoutWeight(1).constraintSize({ minHeight: 86 }).justifyContent(FlexAlign.Center)
            .backgroundColor(SURFACE).borderRadius(17).border({ width: 1, color: LINE })
            .shadow({ radius: 8, color: CARD_SHADOW, offsetY: 3 }).onClick(() => this.screen = 'health-all')
            .id('profile_stat_health').accessibilityText(this.tr(`健康记录，${this.wearableSnapshot.records.length} 条`))
          Column({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.person_badge_heart')).fontSize(23).fontColor([BLUE])
            Text(formatAppText('memberCount', { count: String(this.careMembers.length) }, this.appLocale)).fontSize(14).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(1)
            Text(this.tr('关爱成员')).fontSize(12).fontColor(MUTED).maxLines(1)
          }.layoutWeight(1).constraintSize({ minHeight: 86 }).justifyContent(FlexAlign.Center)
            .backgroundColor(SURFACE).borderRadius(17).border({ width: 1, color: LINE })
            .shadow({ radius: 8, color: CARD_SHADOW, offsetY: 3 }).onClick(() => this.openCare())
            .id('profile_stat_care').accessibilityText(this.tr(`关爱成员，${this.careMembers.length} 人`))
        }.width('100%')
      }

      Column({ space: 4 }) {
        Row() {
          Text(this.tr('我的订单')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
          Row({ space: 2 }) {
            Text(this.tr('全部')).fontSize(14).fontColor(RED)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([RED])
          }.constraintSize({ minHeight: 48 }).padding({ left: 10 }).onClick(() => this.openOrders())
        }.width('100%')
        Divider().color(LINE)
        Row({ space: 2 }) {
          Column({ space: 7 }) {
            SymbolGlyph($r('sys.symbol.wallet')).fontSize(26).fontColor([INK])
            Text(this.tr('待支付')).fontSize(13).fontColor(INK)
          }.layoutWeight(1).constraintSize({ minHeight: 68 }).justifyContent(FlexAlign.Center)
            .borderRadius(13).onClick(() => this.openOrders(0)).accessibilityText(this.tr('查看待支付订单')).id('mine_orders_unpaid')
          Column({ space: 7 }) {
            SymbolGlyph($r('sys.symbol.archivebox')).fontSize(26).fontColor([INK])
            Text(this.tr('待发货')).fontSize(13).fontColor(INK)
          }.layoutWeight(1).constraintSize({ minHeight: 68 }).justifyContent(FlexAlign.Center)
            .borderRadius(13).onClick(() => this.openOrders(1)).accessibilityText(this.tr('查看待发货订单')).id('mine_orders_delivery')
          Column({ space: 7 }) {
            SymbolGlyph($r('sys.symbol.truck_box_fill')).fontSize(26).fontColor([INK])
            Text(this.tr('待收货')).fontSize(13).fontColor(INK)
          }.layoutWeight(1).constraintSize({ minHeight: 68 }).justifyContent(FlexAlign.Center)
            .borderRadius(13).onClick(() => this.openOrders(2)).accessibilityText(this.tr('查看待收货订单')).id('mine_orders_receipt')
          Column({ space: 7 }) {
            SymbolGlyph($r('sys.symbol.headphones')).fontSize(26).fontColor([INK])
            Text(this.tr('售后')).fontSize(13).fontColor(INK)
          }.layoutWeight(1).constraintSize({ minHeight: 68 }).justifyContent(FlexAlign.Center)
            .borderRadius(13).onClick(() => this.openOrders(-1)).accessibilityText(this.tr('查看售后订单')).id('mine_orders_refund')
        }.width('100%')
      }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 10 }).backgroundColor(SURFACE)
        .borderRadius(20).border({ width: 1, color: LINE }).id('mine-orders-card')

      Column({ space: 0 }) {
        if (!this.wearableSnapshot.connected) {
          Row({ space: 12 }) {
            Column() {
              SymbolGlyph($r('sys.symbol.watch')).fontSize(23).fontColor([RED])
            }.width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(14)
            Column({ space: 3 }) {
              Text(this.tr('添加设备')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
          }.width('100%').constraintSize({ minHeight: 70 }).padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .onClick(() => this.openDeviceSearch()).id('mine_add_device').accessibilityText(this.tr('添加设备'))
          Divider().color(LINE).margin({ left: 58 })
        }
        if (!this.hideAiContent) {
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.message')).fontSize(23).fontColor([GOLD])
          }.width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(GOLD_SOFT).borderRadius(14)
          Column({ space: 3 }) {
            Text(this.tr('AI提问')).fontSize(17).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
            Text(this.tr('向 AI 健康管家咨询健康问题')).fontSize(13).fontColor(MUTED).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
        }.width('100%').constraintSize({ minHeight: 70 }).padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onClick(() => this.openAiChat()).id('mine_ai')
        Divider().color(LINE).margin({ left: 58 })
        }
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.ruler')).fontSize(23).fontColor([BLUE])
          }.width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(14)
          Column({ space: 3 }) {
            Text(this.tr('单位设置')).fontSize(17).fontWeight(FontWeight.Medium).fontColor(INK).width('100%')
            Text(this.tr('选择距离和温度的显示单位')).fontSize(13).fontColor(MUTED).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
        }.width('100%').constraintSize({ minHeight: 70 }).padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onClick(() => this.screen = 'unit-settings').id('mine_units')
      }.width('100%').padding(6).backgroundColor(SURFACE).borderRadius(20).border({ width: 1, color: LINE })
        .id('mine-quick-card')

      Column({ space: 6 }) {
        Text(this.tr('我的服务')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          .padding({ left: 8, bottom: 6 })
        Row({ space: 2 }) {
          Column({ space: 7 }) {
            Column() { SymbolGlyph($r('sys.symbol.person_badge_gearshape')).fontSize(23).fontColor([RED]) }
              .width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(14)
            Text(this.tr('账号设置')).fontSize(13).fontColor(INK).maxLines(2).textAlign(TextAlign.Center)
          }.layoutWeight(1).constraintSize({ minHeight: 82 }).justifyContent(FlexAlign.Center)
            .onClick(() => this.screen = 'account').id('mine_account').accessibilityText(this.tr('账号设置'))
          Column({ space: 7 }) {
            Column() { SymbolGlyph($r('sys.symbol.lock_shield')).fontSize(23).fontColor([BLUE]) }
              .width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(14)
            Text(this.tr('权限管理')).fontSize(13).fontColor(INK).maxLines(2).textAlign(TextAlign.Center)
          }.layoutWeight(1).constraintSize({ minHeight: 82 }).justifyContent(FlexAlign.Center)
            .onClick(() => { this.screen = 'permissions'; this.refreshPermissions(); this.connectPush(false); })
            .id('mine_permissions').accessibilityText(this.tr('权限管理'))
          Column({ space: 7 }) {
            Column() { SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(23).fontColor(['#C98716']) }
              .width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(GOLD_SOFT).borderRadius(14)
            Text(this.tr('帮助反馈')).fontSize(13).fontColor(INK).maxLines(2).textAlign(TextAlign.Center)
          }.layoutWeight(1).constraintSize({ minHeight: 82 }).justifyContent(FlexAlign.Center)
            .onClick(() => this.screen = 'help').id('mine_help').accessibilityText(this.tr('帮助反馈'))
          Column({ space: 7 }) {
            Column() { SymbolGlyph($r('sys.symbol.headphones')).fontSize(23).fontColor([GREEN]) }
              .width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(GREEN_SOFT).borderRadius(14)
            Text(this.tr('联系客服')).fontSize(13).fontColor(INK).maxLines(2).textAlign(TextAlign.Center)
          }.layoutWeight(1).constraintSize({ minHeight: 82 }).justifyContent(FlexAlign.Center)
            .onClick(() => this.openContact()).id('mine_contact').accessibilityText(this.tr('联系客服'))
          Column({ space: 7 }) {
            Column() { SymbolGlyph($r('sys.symbol.info_circle')).fontSize(23).fontColor([RED]) }
              .width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(14)
            Text(this.tr('关于我们')).fontSize(13).fontColor(INK).maxLines(2).textAlign(TextAlign.Center)
          }.layoutWeight(1).constraintSize({ minHeight: 82 }).justifyContent(FlexAlign.Center)
            .onClick(() => this.screen = 'about').id('mine_about').accessibilityText(this.tr('关于我们'))
        }.width('100%')
      }.width('100%').padding({ left: 8, right: 8, top: 14, bottom: 8 }).backgroundColor(SURFACE)
        .borderRadius(20).border({ width: 1, color: LINE }).id('mine-services-card')

    }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 24 })
  }

  @Builder
  Home() {
    Column() {
      if (this.tab !== 0) {
        Row() {
          Blank().width(52)
          Text(this.tr(this.tab === 1 ? '设备' : '我的')).fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Blank().width(52)
        }.width('100%').height(this.controlHeight(54)).padding({ left: 12, right: 12 }).backgroundColor(SURFACE)
          .border({ width: { bottom: 1 }, color: LINE }).id('section-titlebar')
      }
      Scroll(this.homeScroller) {
        Column() {
          if (this.tab === 0) { this.HealthHome() }
          else if (this.tab === 1) { this.DeviceHome() }
          else { this.MineHome() }
        }.width('100%').constraintSize({ maxWidth: 720 })
      }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
      Row() {
        ForEach(['健康', '设备', '我的'], (title: string, index: number) => {
          Column({ space: 3 }) {
            if (index === 0) {
              SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(23).fontColor([this.tab === index ? RED : MUTED])
            } else if (index === 1) {
              SymbolGlyph($r('sys.symbol.watch')).fontSize(23).fontColor([this.tab === index ? RED : MUTED])
            } else {
              SymbolGlyph($r('sys.symbol.person')).fontSize(23).fontColor([this.tab === index ? RED : MUTED])
            }
            Text(this.tr(title)).fontSize(14).fontWeight(this.tab === index ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.tab === index ? RED : MUTED)
          }.layoutWeight(1).constraintSize({ minHeight: 62 }).justifyContent(FlexAlign.Center)
            .backgroundColor(SURFACE)
            .onClick(() => {
              this.selectHomeTab(index);
            }).id(`tab_${index}`)
            .accessibilityText(this.tr(title)).accessibilityDescription(this.tab === index ? '当前页' : '切换页面')
        })
      }.width('100%').padding({ left: 12, right: 12, top: 6, bottom: 8 })
        .backgroundColor(SURFACE).border({ width: { top: 1 }, color: LINE })
    }.height('100%').width('100%')
  }

  @Builder
  HealthAllContent() {
    Row({ space: 14 }) {
      Column({ space: 6 }) {
        Text(this.tr('健康数据总览')).fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
        Text(this.tr('点击指标查看详情与历史趋势')).fontSize(12).fontColor('#99FFFFFF').width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column() {
        SymbolGlyph($r('sys.symbol.waveform_path_ecg_heart')).fontSize(30).fontColor([GREEN])
      }.width(54).height(54).justifyContent(FlexAlign.Center).backgroundColor('#1FFFFFFF').borderRadius(27)
    }.width('100%').padding(20).backgroundColor(INK).borderRadius(22)

    if (this.visibleWearableMetrics().length === 0) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.watch')).fontSize(17).fontColor([BLUE])
        Text(this.tr(this.wearableSnapshot.connected ? '暂无可显示的健康数据' : 'connectWatchForData'))
          .fontSize(14).fontColor(BLUE).layoutWeight(1)
      }.width('100%').padding(12).backgroundColor(BLUE_SOFT).borderRadius(10)
        .border({ width: 1, color: '#3D2467A6' })
        .onClick(() => { if (!this.wearableSnapshot.connected) this.openDeviceSearch(); })
    }
    ForEach(this.visibleWearableMetrics(), (metric: WearableMetricSpec) => {
      Row({ space: 12 }) {
        Column() { this.WearableMetricIcon(metric.key) }
          .width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(13)
        Column({ space: 4 }) {
          Text(this.tr(metric.title)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Text(this.wearableLatest(metric.key)).fontSize(13).fontColor(MUTED).lineHeight(20).maxLines(2).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(19).fontColor([MUTED])
      }.width('100%').constraintSize({ minHeight: 76 }).padding({ left: 13, right: 13, top: 10, bottom: 10 })
        .backgroundColor(SURFACE).borderRadius(16).border({ width: 1, color: LINE })
        .onClick(() => this.openWearableMetric(metric.key))
        .accessibilityText(`${metric.title}，${this.wearableLatest(metric.key)}`)
    }, (metric: WearableMetricSpec) => metric.key)
    this.Notice({ message: '数值仅供健康管理参考，不自动判断疾病或异常。', color: GREEN_SOFT })
  }

  @Builder
  SportRecordContent() {
    Text(this.tr('开始今日运动')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    if (!this.wearableSnapshot.connected) {
      this.Notice({ message: 'connectRingForSport' })
    } else if (!this.wearableCapability('sport')) {
      this.Notice({ message: 'ringSportSyncUnsupported' })
    } else if (this.wearableSnapshot.sportCapability.modes.length === 0) {
      this.Notice({ message: 'ringSportStartOnDevice' })
    }
    if (this.sportActive()) {
      Column({ space: 14 }) {
        Row({ space: 12 }) {
          Column() { SymbolGlyph(this.sportModeIcon(this.sportSession.mode as WearableSportMode)).fontSize(30).fontColor([RED]) }
            .width(52).height(52).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(16)
          Column({ space: 4 }) {
            Text(sportModeLabel(this.sportSession.mode)).fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(this.tr(this.sportSession.status)).fontSize(14).fontColor(this.sportSession.phase === 'paused' ? GOLD : GREEN).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
        Text(this.sportDurationText(this.sportElapsedSeconds())).fontSize(38).fontWeight(FontWeight.Bold).fontColor(INK)
          .fontFamily('HarmonyOS Sans').width('100%').textAlign(TextAlign.Center)
        Row() {
          this.SportLiveValue('ringDistance', this.sportSession.distanceKm > 0 ? `${this.sportSession.distanceKm.toFixed(2)} km` : '--')
          this.SportLiveValue('热量', this.sportSession.calories > 0 ? `${Math.round(this.sportSession.calories)} kcal` : '--')
          this.SportLiveValue('心率', this.sportSession.heartRate > 0 ? `${Math.round(this.sportSession.heartRate)} BPM` : '--')
        }.width('100%')
        if (this.sportSession.route.length > 1) {
          Column({ space: 8 }) {
            Text(this.tr('手机前台轨迹')).fontSize(15).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Polyline({ width: this.sportRouteWidth, height: 150 })
              .points(sportRoutePolyline(this.sportSession.route, this.sportRouteWidth, 150))
              .fillOpacity(0).stroke(RED).strokeWidth(3).width('100%').height(150)
              .onAreaChange((oldArea: Area, area: Area) => this.sportRouteWidth = Number(area.width))
            Text(`轨迹距离 ${this.sportSession.routeDistanceKm.toFixed(2)} km · ${this.sportSession.route.length} 个定位点`)
              .fontSize(13).fontColor(MUTED).width('100%')
          }.width('100%').padding(12).backgroundColor(SURFACE_ALT).borderRadius(14)
        }
        if (this.sportSession.locationStatus) {
          Text(this.tr(this.sportSession.locationStatus)).fontSize(13).fontColor(MUTED).width('100%')
        }
        Row({ space: 10 }) {
          if (this.wearableSnapshot.sportCapability.supportsPause) {
            Button(this.tr(this.sportSession.phase === 'paused' ? '继续' : '暂停')).layoutWeight(1)
              .constraintSize({ minHeight: 52 }).backgroundColor(SURFACE).fontColor(INK).type(ButtonType.Normal)
              .borderRadius(14).border({ width: 1, color: OUTLINE }).enabled(!this.sportActionBusy &&
                ['running', 'paused'].includes(this.sportSession.phase)).onClick(() => this.toggleSportPause())
          }
          Button(this.tr('结束运动')).layoutWeight(1).constraintSize({ minHeight: 52 }).backgroundColor(RED)
            .type(ButtonType.Normal).borderRadius(14).enabled(!this.sportActionBusy && this.sportActive())
            .onClick(() => this.confirmStopSport())
        }.width('100%')
      }.width('100%').padding(18).backgroundColor(SURFACE).borderRadius(20).border({ width: 1, color: '#33D20B27' })
    } else if (this.wearableSnapshot.connected && this.wearableSnapshot.sportCapability.modes.length > 0) {
      if (this.sportSession.phase === 'completed') {
        this.Notice({ message: this.sportSession.status, color: GREEN_SOFT })
      } else if (this.sportSession.phase === 'error' && this.sportSession.status) {
        this.Notice({ message: this.sportSession.status, color: '#FFF0E9' })
      }
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.wearableSnapshot.sportCapability.modes, (mode: WearableSportMode) => {
          this.SportModeCard(mode)
        }, (mode: WearableSportMode) => mode)
      }.width('100%')
      Button(`开始${sportModeLabel(this.selectedSportMode)}`).width('100%').constraintSize({ minHeight: 54 })
        .backgroundColor(RED).type(ButtonType.Normal).borderRadius(15).enabled(!this.sportActionBusy &&
          !this.wearableBusy() && !this.wearableMeasurement.running).onClick(() => this.startSport(this.selectedSportMode))
    }
    Text(this.tr('运动记录')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').margin({ top: 8 })
    Row({ space: 10 }) {
      Button(this.tr('同步近三天')).layoutWeight(1).constraintSize({ minHeight: 50 }).backgroundColor(RED)
        .type(ButtonType.Normal).borderRadius(14).enabled(this.wearableSnapshot.connected && this.wearableCapability('sport') &&
          !this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive())
        .onClick(() => this.syncSportRecords())
      if (this.wearableSnapshot.connected) {
        Button(this.tr('查看设备')).layoutWeight(1).constraintSize({ minHeight: 50 }).fontColor(RED).backgroundColor(SURFACE)
          .type(ButtonType.Normal).borderRadius(14).border({ width: 1, color: LINE })
          .enabled(!this.sportActive())
          .onClick(() => { this.screen = 'home'; this.selectHomeTab(1); })
      } else {
        Button(this.tr('添加设备')).layoutWeight(1).constraintSize({ minHeight: 50 }).fontColor(RED).backgroundColor(SURFACE)
          .type(ButtonType.Normal).borderRadius(14).border({ width: 1, color: LINE })
          .onClick(() => this.openDeviceSearch()).id('sport_go_device')
      }
    }.width('100%')
    if (this.sportLoading) { LoadingProgress().width(36).height(36).color(RED) }
    if (this.sportError) { this.Notice({ message: this.sportError }) }
    else if (!this.sportLoading && this.localSportRecords.length === 0) {
      this.StateCard({ title: '暂无运动记录', detail: 'noSportRecordsHint',
        icon: $r('sys.symbol.clock_arrow_2_circlepath'), green: true })
    }
    Button(this.tr('刷新本机记录')).fontColor(RED).backgroundColor(Color.Transparent).constraintSize({ minHeight: 48 })
      .enabled(!this.sportLoading).onClick(() => this.loadSportRecords())
    ForEach(this.localSportRecords, (record: HealthRecord) => {
      Row({ space: 12 }) {
        Column() { SymbolGlyph(this.sportModeIcon(this.sportRecordIconMode(record))).fontSize(25).fontColor([RED]) }
          .width(48).height(48).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(14)
        Column({ space: 6 }) {
          Row() {
            Text(this.sportRecordMode(record)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
            Text(this.wearableRecordTime(record.timestamp)).fontSize(12).fontColor(MUTED)
          }.width('100%')
          Text(this.displayRecord(record)).fontSize(14).fontColor(MUTED).lineHeight(22).maxLines(2).width('100%')
          Text(this.tr(record.source === 'watch_history' ? 'ringHistory' : 'App 运动'))
            .fontSize(12).fontColor(GREEN).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(16).border({ width: 1, color: LINE })
        .onClick(() => this.openRecord(record))
    }, (record: HealthRecord) => record.id)
  }

  @Builder
  SportModeCard(mode: WearableSportMode) {
    Column({ space: 8 }) {
      Row() {
        SymbolGlyph(this.sportModeIcon(mode)).fontSize(25).fontColor([this.selectedSportMode === mode ? RED : MUTED])
        Blank()
        if (this.selectedSportMode === mode) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(20).fontColor([RED])
        }
      }.width('100%')
      Text(sportModeLabel(mode)).fontSize(15).fontWeight(FontWeight.Medium).maxLines(1).width('100%')
        .fontColor(this.selectedSportMode === mode ? RED_DARK : INK)
    }.width(this.singleColumn() ? '100%' : '48%').constraintSize({ minHeight: 78 })
      .padding({ left: 14, right: 12, top: 11, bottom: 10 })
      .backgroundColor(this.selectedSportMode === mode ? RED_SOFT : SURFACE).borderRadius(15)
      .border({ width: 1, color: this.selectedSportMode === mode ? '#66D20B27' : LINE })
      .margin({ bottom: 10 }).onClick(() => this.selectedSportMode = mode)
      .accessibilityText(`${sportModeLabel(mode)}${this.selectedSportMode === mode ? '，已选择' : ''}`)
  }

  @Builder
  SportLiveValue(label: string, value: string) {
    Column({ space: 5 }) {
      Text(this.tr(value)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(1)
      Text(this.tr(label)).fontSize(12).fontColor(MUTED)
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  @Builder
  HealthAlertContent() {
    Text(this.tr('预警记录')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
    if (this.inboxLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.inboxError) { this.Notice({ message: this.inboxError, color: '#FFF0E9' }) }
    else if (!this.inboxLoading && this.healthWarnings().length === 0) {
      this.StateCard({ title: '暂无健康预警', icon: $r('sys.symbol.lock_shield'), green: true })
    }
    ForEach(this.healthWarnings(), (message: InboxMessage) => {
      Column({ space: 8 }) {
        Text(message.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Text(message.content).fontSize(14).lineHeight(22).fontColor(MUTED).width('100%')
        Text(message.createdAt).fontSize(12).fontColor(MUTED).width('100%')
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        .onClick(() => this.openInboxMessage(message))
    }, (message: InboxMessage) => String(message.id))
    this.StateCard({ title: '健康预警仅作健康管理提醒', detail: '如有不适，请及时咨询专业医务人员。这里只展示已收到的健康预警。', green: true,
      icon: $r('sys.symbol.lock_shield') })
    Button(this.tr('刷新预警记录')).width('100%').constraintSize({ minHeight: 56 }).fontColor(INK).backgroundColor(Color.Transparent)
      .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE })
      .enabled(!this.inboxLoading).onClick(() => this.refreshInbox())
  }

  @Builder
  ShopHomeContent() {
    Column() {
      this.Heading()
      if (this.shopLoading) {
        LoadingProgress().width(40).height(40).color(RED).margin({ top: 120 })
        Blank().layoutWeight(1)
      } else if (this.shopError || !this.shopHome.categories.length) {
        Column({ space: 20 }) {
          SymbolGlyph($r('sys.symbol.bag')).fontSize(44).fontColor([INK])
          Text(this.tr(this.shopError || '当前暂无商品')).fontSize(16).fontColor(INK).lineHeight(24).textAlign(TextAlign.Center).width('100%')
          Button(this.tr('重新加载')).constraintSize({ minHeight: 56 }).fontSize(16).fontWeight(FontWeight.Bold)
            .backgroundColor(RED).type(ButtonType.Normal).borderRadius(12).onClick(() => this.openShop()).id('shop_refresh')
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding(20)
      } else {
        TextInput({ text: this.shopKeyword, placeholder: this.tr('搜索商品') }).fontSize(16).height(this.controlHeight(60))
          .padding({ left: 20, right: 20 }).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
          .maxLength(80).onChange((value: string) => this.shopKeyword = value).margin({ left: 14, right: 14, top: 8, bottom: 10 })
          .id('shop_search')
        if (this.shopHome.bannerUrl) {
          Image(this.shopHome.bannerUrl).height(102).width('92%').objectFit(ImageFit.Cover).borderRadius(16)
            .margin({ bottom: 10 }).accessibilityText(this.tr('shop'))
        }
        Row({ space: 0 }) {
          Scroll() {
            Column({ space: 0 }) {
              ForEach(this.shopHome.categories, (category: ShopCategory, index: number) => {
                Text(this.tr(category.name)).fontSize(16).fontWeight(this.shopCategoryIndex === index ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.shopCategoryIndex === index ? RED : INK).width('100%').constraintSize({ minHeight: 64 })
                  .textAlign(TextAlign.Center).padding({ left: 10, right: 10, top: 12, bottom: 12 })
                  .backgroundColor(this.shopCategoryIndex === index ? SURFACE : Color.Transparent)
                  .border({ width: { left: 4 }, color: this.shopCategoryIndex === index ? RED : Color.Transparent })
                  .onClick(() => this.shopCategoryIndex = index).id(`shop_category_${index}`)
              }, (category: ShopCategory) => category.id)
            }.width('100%')
          }.width(106).height('100%').align(Alignment.Top).scrollBar(BarState.Off).backgroundColor('#F5F2F0')
          Scroll() {
            Column({ space: 10 }) {
              if (!this.filteredShopProducts().length) {
                SymbolGlyph($r('sys.symbol.bag')).fontSize(40).fontColor([OUTLINE]).margin({ top: 90 })
                Text(this.shopKeyword.trim() ? '未找到相关商品' : '当前分类暂无商品').fontSize(16).fontColor(INK).width('100%').textAlign(TextAlign.Center)
              }
              ForEach(this.filteredShopProducts(), (product: ShopProduct) => {
                Row({ space: 0 }) {
                  if (product.picture) {
                    Image(product.picture).width(96).height(104).objectFit(ImageFit.Contain).backgroundColor(SURFACE_ALT).accessibilityText(this.tr(product.name))
                  } else {
                    Column() { SymbolGlyph($r('sys.symbol.bag')).fontSize(24).fontColor([OUTLINE]) }
                      .width(96).height(104).backgroundColor('#F0F1F5').justifyContent(FlexAlign.Center).accessibilityText(this.tr('暂无商品图片'))
                  }
                  Column({ space: 8 }) {
                    Text(this.tr(product.name)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').maxLines(2)
                    Text(this.tr(product.stock > 0 ? `库存 ${product.stock}` : '暂时缺货')).fontSize(13).fontColor(MUTED).width('100%')
                    Text(this.tr(`¥${product.price}`)).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#914D00').width('100%')
                  }.layoutWeight(1).padding(12).alignItems(HorizontalAlign.Start)
                }.width('100%').constraintSize({ minHeight: 104 }).backgroundColor(SURFACE).borderRadius(18)
                  .border({ width: 1, color: LINE }).clip(true).onClick(() => this.openShopProduct(product))
                  .accessibilityText(this.tr(`${product.name}，${product.price} 元`))
              }, (product: ShopProduct) => String(product.id))
            }.width('100%').padding({ left: 12, right: 14, top: 4, bottom: 24 })
          }.layoutWeight(1).height('100%').align(Alignment.Top).scrollBar(BarState.Off)
        }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Top)
      }
      Row({ space: 12 }) {
        Button(this.tr('我的订单')).layoutWeight(1).constraintSize({ minHeight: 48 }).fontSize(16).fontColor(RED).backgroundColor(SURFACE)
          .onClick(() => this.openOrders()).id('shop_orders')
        Button(this.tr('刷新商城')).layoutWeight(1).constraintSize({ minHeight: 48 }).fontSize(16).fontColor(INK).backgroundColor(SURFACE)
          .enabled(!this.shopLoading).onClick(() => this.openShop())
      }.width('100%').padding(8).backgroundColor(SURFACE)
    }.width('100%').height('100%')
  }

  @Builder
  ShopProductContent() {
    if (this.commerceLoading) { LoadingProgress().width(40).height(40).color(RED).margin({ top: 100 }) }
    if (this.commerceError && !this.purchaseSheet) { this.Notice({ message: this.commerceError, color: GOLD_SOFT }) }
    if (!this.commerceLoading && !this.productDetail) {
      Button(this.tr('重新加载')).height(this.controlHeight(56)).backgroundColor(RED).onClick(() => this.openShopProduct(this.selectedProduct))
    }
    if (this.productDetail) {
      if (this.productDetail.covers.length) {
        Swiper() {
          ForEach(this.productDetail.covers, (url: string) => {
            Image(url).width('100%').height(350).objectFit(ImageFit.Cover).accessibilityText(this.tr(this.productDetail?.name ?? '商品图片'))
          }, (url: string) => url)
        }.width('100%').height(350).autoPlay(false).loop(false).indicator(this.productDetail.covers.length > 1)
      } else {
        Column() { SymbolGlyph($r('sys.symbol.bag')).fontSize(32).fontColor([OUTLINE]) }
          .width('100%').height(350).justifyContent(FlexAlign.Center).backgroundColor('#F0F2F5')
          .accessibilityText(this.tr('暂无商品图片'))
      }
      Column({ space: 14 }) {
        Text(this.tr(this.productDetail.name)).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Row() {
          Text(commerceMoney(this.purchaseSku()?.priceCents ?? this.productDetail.priceCents)).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#914E00').layoutWeight(1)
          if (this.productDetail.sales) { Text(this.tr(`销量 ${this.productDetail.sales}`)).fontSize(15).fontColor(MUTED) }
        }.width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(['品质保障', '配送到家', '售后服务'], (label: string) => {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.checkmark_shield')).fontSize(16).fontColor([RED])
              Text(this.tr(label)).fontSize(13).fontColor(INK)
            }.padding({ left: 9, right: 9, top: 6, bottom: 6 }).margin({ right: 6, bottom: 6 }).backgroundColor(RED_SOFT).borderRadius(99)
          })
        }.width('100%')
        if (this.productDetail.skus.length) {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text(this.tr('规格')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
              Text(this.purchaseSku()?.name ?? '请选择规格').fontSize(15).fontColor(INK).width('100%')
            }.layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(20).fontColor([RED])
          }.width('100%').constraintSize({ minHeight: 80 }).padding(16).backgroundColor(SURFACE)
            .border({ width: 1, color: LINE, radius: 18 }).onClick(() => this.showPurchase(false)).id('product_sku')
        }
      }.width('92%').padding(18).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Column({ space: 12 }) {
        Text(this.tr('商品详情')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        if (!this.productDetail.blocks.length) { Text(this.tr('暂无详细介绍')).fontSize(16).fontColor(MUTED).width('100%') }
        ForEach(this.productDetail.blocks, (block: ArticleBlock) => {
          if (block.kind === 'image') { ArticleImage({ source: block.url, description: block.text }) }
          else if (block.kind === 'text') { Text(block.text).fontSize(16).fontColor(INK).lineHeight(25).width('100%') }
          else { Text(this.tr('图片暂不可用')).fontSize(14).fontColor(MUTED) }
        }, (block: ArticleBlock) => block.id)
      }.width('92%').padding(18).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    }
  }

  @Builder
  PurchaseSheetContent() {
    Column({ space: 18 }) {
      Text(this.tr('请选择规格')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.productDetail?.skus ?? [], (sku: ShopSku, index: number) => {
          Button(this.tr(sku.name)).fontSize(15).fontColor(INK).constraintSize({ minHeight: 48 }).type(ButtonType.Normal).borderRadius(10)
            .backgroundColor(this.selectedSkuIndex === index ? GOLD_SOFT : SURFACE).border({ width: 1, color: OUTLINE, radius: 10 })
            .margin({ right: 8, bottom: 8 }).enabled(!this.commerceBusy).onClick(() => {
              this.selectedSkuIndex = index; this.purchaseQuantity = this.productDetail?.minBuy ?? 1; this.commerceError = '';
            }).id(`sku_${sku.id}`)
        }, (sku: ShopSku) => String(sku.id))
      }.width('100%')
      Row({ space: 10 }) {
        Text((this.purchaseSku()?.stock ?? -1) < 0 ? '库存待确认' : `库存 ${this.purchaseSku()?.stock}`)
          .fontSize(15).fontColor(INK).layoutWeight(1)
        Button(this.tr('−')).width(48).height(this.controlHeight(44)).fontSize(22).fontColor(INK).backgroundColor(SURFACE).border({ width: 1, color: OUTLINE })
          .enabled(!this.commerceBusy && this.purchaseQuantity > (this.productDetail?.minBuy ?? 1)).onClick(() => this.purchaseQuantity--).id('quantity_minus')
        Text(String(this.purchaseQuantity)).fontSize(16).fontWeight(FontWeight.Bold).width(28).textAlign(TextAlign.Center)
        Button(this.tr('+')).width(48).height(this.controlHeight(44)).fontSize(22).fontColor(INK).backgroundColor(SURFACE).border({ width: 1, color: OUTLINE })
          .enabled(!this.commerceBusy && this.purchaseQuantity < Math.min(this.purchaseSku()?.stock ?? 0, 999)).onClick(() => this.purchaseQuantity++).id('quantity_plus')
      }.width('100%')
      if (this.commerceError) { this.Notice({ message: this.commerceError, color: GOLD_SOFT }) }
      Button(this.tr(this.commerceBusy ? '处理中…' : this.purchaseToCart ? '加入购物车' : '立即购买')).width('100%').height(this.controlHeight(56))
        .fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
        .enabled(!this.commerceBusy && !purchaseError(this.productDetail, this.purchaseSku(), this.purchaseQuantity))
        .onClick(() => this.purchaseSelected()).id('purchase_confirm')
    }.width('100%').padding({ left: 20, right: 20, top: 20, bottom: 24 })
  }

  @Builder
  CommerceLine($$: CommerceLineProps) {
    Row({ space: 12 }) {
      if ($$.line.picture) { Image($$.line.picture).width(78).height(78).objectFit(ImageFit.Cover).borderRadius(10) }
      else { Column() { SymbolGlyph($r('sys.symbol.bag')).fontSize(24).fontColor([INK]) }
        .width(78).height(78).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(10) }
      Column({ space: 6 }) {
        Text(this.tr($$.line.name)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').maxLines(2)
        Text(this.tr($$.line.sku)).fontSize(13).fontColor(MUTED).width('100%')
        Row() {
          Text(`${$$.line.totalPrice ? '小计 ' : ''}${commerceMoney($$.line.priceCents)}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(RED).layoutWeight(1)
          Text(this.tr($$.line.quantity > 0 ? `×${$$.line.quantity}` : '')).fontSize(14).fontColor(MUTED)
        }.width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  CommerceStatus() {
    if (this.commerceLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.commerceError) { this.Notice({ message: this.commerceError, color: GOLD_SOFT }) }
  }

  @Builder
  CartContent() {
    this.CommerceStatus()
    if (!this.commerceLoading && !this.commerceError && !this.cartLines.length) {
      Column({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.bag')).fontSize(72).fontColor([OUTLINE])
        Text(this.tr('购物车还是空的')).fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK)
        Text(this.tr('去商城挑选适合您的健康设备吧')).fontSize(16).fontColor(INK).textAlign(TextAlign.Center)
        Button(this.tr('返回商城')).height(this.controlHeight(56)).fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED)
          .type(ButtonType.Normal).borderRadius(12).onClick(() => this.back())
      }.width('100%').constraintSize({ minHeight: 620 }).justifyContent(FlexAlign.Center)
    }
    ForEach(this.cartLines, (line: ShopLine) => {
      Column({ space: 12 }) {
        Row({ space: 4 }) {
          Checkbox().select(this.cartSelection.includes(line.skuId)).selectedColor(RED).enabled(!this.commerceBusy)
            .onChange((selected: boolean) => this.toggleCart(line.skuId, selected)).accessibilityText(this.tr(`选择${line.name}`))
          Column() { this.CommerceLine({ line }) }.layoutWeight(1)
        }.width('100%')
        Row({ space: 8 }) {
          Button(this.tr('移出')).fontSize(14).fontColor(MUTED).backgroundColor(Color.Transparent).height(this.controlHeight(44))
            .enabled(!this.commerceBusy).onClick(() => this.changeCart(line, line.quantity, true))
          Blank().layoutWeight(1)
          Button(this.tr('−')).width(48).height(this.controlHeight(44)).fontSize(20).fontColor(INK).backgroundColor(BG).enabled(!this.commerceBusy && line.quantity > 1)
            .onClick(() => this.changeCart(line, line.quantity - 1))
          Text(String(line.quantity)).fontSize(16).fontColor(INK).width(28).textAlign(TextAlign.Center)
          Button(this.tr('+')).width(48).height(this.controlHeight(44)).fontSize(20).fontColor(INK).backgroundColor(BG)
            .enabled(!this.commerceBusy && line.quantity < 999 && (line.stock < 0 || line.quantity < line.stock))
            .onClick(() => this.changeCart(line, line.quantity + 1))
        }.width('100%')
      }.width('100%').padding(14).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    }, (line: ShopLine) => String(line.id))
    if (this.cartLines.length || this.commerceError) {
      Button(this.tr('刷新购物车')).height(this.controlHeight(48)).fontColor(RED).backgroundColor(Color.Transparent)
        .enabled(!this.commerceBusy).onClick(() => this.openCart())
    }
  }

  @Builder
  CheckoutContent() {
    this.CommerceStatus()
    if (this.checkoutPreview) {
      Column() {
        this.PageRow({ title: this.checkoutAddress ? `${this.checkoutAddress.name}  ${this.checkoutAddress.mobile}` : '请选择收货地址',
          subtitle: this.checkoutAddress?.address ?? '', icon: $r('sys.symbol.map'),
          action: () => { if (!this.commerceBusy && !this.checkoutAttempted) { this.selectingCheckoutAddress = true; this.openAddresses(); } }, id: 'checkout_address' })
      }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Column({ space: 12 }) {
        Text(this.tr('商品信息')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        ForEach(this.checkoutPreview.products, (line: ShopLine) => { this.CommerceLine({ line }) })
        TextInput({ text: this.checkoutMessage, placeholder: this.tr('留言') }).fontSize(16).height(this.controlHeight(56)).maxLength(100)
          .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
          .enabled(!this.commerceBusy && !this.checkoutAttempted).onChange((value: string) => this.checkoutMessage = value).id('checkout_message')
        Text(this.tr(`${this.checkoutMessage.length}/100`)).fontSize(13).fontColor(MUTED).textAlign(TextAlign.End).width('100%')
      }.width('100%').padding(14).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Column({ space: 8 }) {
        Text(this.tr('积分抵扣')).fontSize(14).fontColor(MUTED).width('100%')
        TextInput({ text: this.checkoutPoints, placeholder: this.tr('0') }).fontSize(16).height(this.controlHeight(56)).maxLength(12).type(InputType.NUMBER_DECIMAL)
          .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
          .enabled(!this.commerceBusy && !this.checkoutAttempted && this.checkoutPreview.pointsCents >= 0)
          .onChange((value: string) => this.checkoutPoints = value).id('checkout_points')
        Text(`可用积分：${this.checkoutPreview.pointsCents >= 0 ? (this.checkoutPreview.pointsCents / 100).toFixed(2) : '暂未读取'}`)
          .fontSize(14).fontColor(MUTED).width('100%')
      }.width('100%').padding(14).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Column({ space: 12 }) {
        this.CommerceAmount({ label: '商品总额', amount: this.checkoutPreview.productCents })
        this.CommerceAmount({ label: '快递费用', amount: this.checkoutPreview.shippingCents })
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      if (this.checkoutAttempted && !this.commerceBusy) {
        this.Notice({ message: '请先核对我的订单，避免重复提交。' })
        Button(this.tr('查看我的订单')).height(this.controlHeight(56)).backgroundColor(RED).onClick(() => this.openOrders())
      }
    } else if (!this.commerceLoading) {
      Button(this.tr('重新加载')).height(this.controlHeight(56)).backgroundColor(RED).onClick(() => this.loadCheckout())
    }
  }

  @Builder
  CommerceAmount($$: CommerceAmountProps) {
    Row({ space: 12 }) {
      Text(this.tr($$.label)).fontSize(16).fontColor(INK).layoutWeight(1)
      Text(commerceMoney($$.amount)).fontSize($$.emphasis ? 19 : 16).fontWeight(FontWeight.Bold).fontColor($$.emphasis ? RED : INK)
    }.width('100%')
  }

  @Builder
  OrderDetailContent() {
    this.CommerceStatus()
    if (this.orderDetail) {
      Row({ space: 14 }) {
        Column() { SymbolGlyph($r('sys.symbol.bag')).fontSize(26).fontColor([Color.White]) }
          .width(50).height(50).justifyContent(FlexAlign.Center).backgroundColor('#2AFFFFFF').borderRadius(25)
        Column({ space: 6 }) {
          Text(orderHeading(this.orderDetail.order.status)).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
          Text(orderExplanation(this.orderDetail.order.status)).fontSize(15).fontColor('#E6FFFFFF').lineHeight(22).width('100%')
        }.layoutWeight(1)
      }.width('100%').padding(20).linearGradient({ angle: 90, colors: [['#9E1025', 0], [RED, 1]] }).borderRadius(22)
      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.map')).fontSize(24).fontColor([RED])
        Column({ space: 8 }) {
          Text(this.tr(this.orderDetail.receiver)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Text(this.tr(this.orderDetail.address)).fontSize(15).fontColor(MUTED).lineHeight(22).width('100%')
        }.layoutWeight(1)
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Column({ space: 14 }) {
        ForEach(this.orderDetail.products, (line: ShopLine) => { this.CommerceLine({ line }) })
      }.width('100%').padding(14).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Column({ space: 12 }) {
        this.CommerceAmount({ label: '商品金额', amount: this.orderDetail.orderCents })
        Divider().color(LINE)
        this.CommerceAmount({ label: '实付款', amount: this.orderDetail.order.amountCents, emphasis: true })
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Column({ space: 10 }) {
        Text(this.tr(`订单编号  ${this.orderDetail.order.number}`)).fontSize(15).fontColor(INK).width('100%').copyOption(CopyOptions.InApp)
        Text(this.tr(`下单时间  ${this.orderDetail.createdAt}`)).fontSize(15).fontColor(MUTED).width('100%')
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
        if (this.orderDetail.order.status > 0) {
          Button(this.tr('申请售后')).height(this.controlHeight(48)).fontSize(16).fontColor(INK).backgroundColor(SURFACE).border({ width: 1, color: OUTLINE, radius: 12 })
            .margin({ left: 8, bottom: 8 }).enabled(!this.commerceBusy).onClick(() => this.openInnerPage('shop-after-sales')).id('order_after_sales')
        }
        if (this.orderDetail.order.status >= 2) {
          Button(this.tr('查看物流')).height(this.controlHeight(48)).fontSize(16).fontColor(INK).backgroundColor(SURFACE).border({ width: 1, color: OUTLINE, radius: 12 })
            .margin({ left: 8, bottom: 8 }).enabled(!this.commerceBusy).onClick(() => this.openShipments()).id('order_express')
        }
        if (this.orderDetail.order.status === 2) {
          Button(this.tr('确认收货')).height(this.controlHeight(48)).fontSize(16).backgroundColor(RED).margin({ left: 8, bottom: 8 })
            .enabled(!this.commerceBusy).onClick(() => this.confirmReceipt()).id('order_receipt')
        }
        if (this.orderDetail.order.status === 0 && this.orderDetail.order.amountCents > 0) {
          Button(this.tr('查看支付状态')).height(this.controlHeight(56)).fontSize(16).backgroundColor(RED).margin({ left: 8, bottom: 8 })
            .onClick(() => { this.innerParents.set('shop-payment', 'shop-order-detail'); this.openPayment(this.orderDetail!.order); }).id('order_payment')
        }
      }.width('100%')
    }
    Button(this.tr('刷新订单详情')).height(this.controlHeight(48)).fontColor(RED).backgroundColor(Color.Transparent)
      .enabled(!this.commerceBusy && !this.commerceLoading).onClick(() => this.openCommerceOrder(this.commerceOrderId)).id('refresh_order_detail')
  }

  @Builder
  ExpressContent() {
    this.CommerceStatus()
    if (!this.commerceLoading && !this.commerceError && !this.shipments.length) {
      Column({ space: 20 }) {
        SymbolGlyph($r('sys.symbol.bag')).fontSize(44).fontColor([INK])
        Text(this.tr('暂无物流信息')).fontSize(16).fontColor(INK)
        Button(this.tr('重新加载')).height(this.controlHeight(56)).fontSize(16).backgroundColor(RED).onClick(() => this.openShipments())
      }.width('100%').constraintSize({ minHeight: 620 }).justifyContent(FlexAlign.Center)
    }
    ForEach(this.shipments, (shipment: Shipment) => {
      Column({ space: 14 }) {
        Text(this.tr(shipment.company)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Text(this.tr(`快递单号：${shipment.number}`)).fontSize(15).fontColor(INK).width('100%').copyOption(CopyOptions.InApp)
        Divider().color(LINE)
        ForEach(shipment.traces, (trace: ShipmentTrace) => {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.circle_fill')).fontSize(10).fontColor([RED])
            Column({ space: 6 }) { Text(this.tr(trace.remark)).fontSize(16).fontColor(INK).width('100%'); Text(this.tr(trace.time)).fontSize(14).fontColor(MUTED).width('100%') }.layoutWeight(1)
          }.width('100%')
        })
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    })
    if (this.commerceError || this.shipments.length) {
      Button(this.tr('刷新物流')).height(this.controlHeight(48)).fontColor(RED).backgroundColor(Color.Transparent).enabled(!this.commerceLoading).onClick(() => this.openShipments())
    }
  }

  @Builder
  AfterSalesContent() {
    this.Notice({ message: '请选择需要售后的商品，并填写原因和申请金额。提交后可在订单列表查看处理状态。' })
    if (this.orderDetail) {
      Column({ space: 14 }) {
        Text(this.tr(`订单号 ${this.orderDetail.order.number}`)).fontSize(14).fontColor(MUTED).width('100%')
        Divider().color(LINE)
        ForEach(this.orderDetail.products, (line: ShopLine) => {
          this.CommerceLine({ line })
          Row() { Blank().layoutWeight(1)
            Button(this.tr(line.applied ? '查看售后状态' : '申请售后')).height(this.controlHeight(48)).fontSize(16).fontColor(INK).backgroundColor(SURFACE)
            .border({ width: 1, color: OUTLINE, radius: 12 }).onClick(() => this.openRefund(line)).id(`refund_line_${line.id}`)
          }.width('100%')
        })
      }.width('100%').padding(14).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    }
  }

  @Builder
  RefundContent() {
    if (this.refundLine) {
      Column() { this.CommerceLine({ line: this.refundLine }) }.width('100%').padding(14).backgroundColor(SURFACE).borderRadius(18)
      if (this.refundLine.applied) { this.Notice({ message: '该商品已经提交售后申请，请等待商城工作人员处理。', color: GOLD_SOFT }) }
      else {
        Column({ space: 6 }) {
          Text(this.tr('售后类型')).fontSize(14).fontColor(MUTED).width('100%')
          Select([{ value: '仅退款' }, { value: '退货退款' }]).selected(this.refundType).value(this.refundType === 0 ? '仅退款' : '退货退款')
            .width('100%').font({ size: 16 }).backgroundColor(SURFACE).enabled(!this.commerceBusy).onSelect((index: number) => this.refundType = index)
        }.width('100%').padding(12).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
        TextInput({ text: this.refundAmount, placeholder: this.tr('申请金额') }).type(InputType.NUMBER_DECIMAL).fontSize(16).height(this.controlHeight(56)).maxLength(12)
          .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.commerceBusy)
          .onChange((value: string) => this.refundAmount = value).id('refund_amount')
        TextArea({ text: this.refundReason, placeholder: this.tr('售后原因，请说明遇到的问题') }).fontSize(16).height(140).maxLength(200)
          .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.commerceBusy)
          .onChange((value: string) => this.refundReason = value).id('refund_reason')
        Text(this.tr(`${this.refundReason.length}/200`)).fontSize(13).fontColor(MUTED).textAlign(TextAlign.End).width('100%')
        Button(this.tr(this.commerceBusy ? '提交中…' : '提交申请')).width('100%').height(this.controlHeight(56)).fontSize(16).backgroundColor(RED)
          .enabled(!this.commerceBusy && !this.refundAttempted).onClick(() => this.submitRefund()).id('refund_submit')
        if (this.refundAttempted && !this.commerceBusy) {
          Button(this.tr('刷新订单确认结果')).height(this.controlHeight(48)).fontColor(RED).backgroundColor(Color.Transparent)
            .onClick(() => { this.screen = 'shop-order-detail'; this.openCommerceOrder(this.commerceOrderId); })
        }
      }
      if (this.commerceError) { this.Notice({ message: this.commerceError, color: GOLD_SOFT }) }
    }
  }

  @Builder
  AiChatContent() {
    if (this.aiMessages.length === 0 && !this.aiBusy) {
      Column({ space: 16 }) {
        Column() { SymbolGlyph($r('sys.symbol.lock_shield')).fontSize(28).fontColor([RED]) }
          .width(54).height(54).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(16)
        Text(this.tr('您好，我是 AI 健康管家')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').textAlign(TextAlign.Center)
        Text(this.tr('可以向我咨询日常健康管理问题，回答仅供参考，不能替代医生诊断。'))
          .fontSize(16).lineHeight(24).fontColor(MUTED).width('100%').textAlign(TextAlign.Center)
      }.width('100%').constraintSize({ minHeight: 440 }).padding(20).margin({ top: 16 })
        .backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    }
    if (this.aiBusy && this.aiMessages.length === 0) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.aiError) { this.Notice({ message: this.aiError, color: '#FFF0E9' }) }
    ForEach(this.aiMessages, (message: AiChatMessage) => {
      Row() {
        if (message.mine) { Blank().layoutWeight(1) }
        Column({ space: 5 }) {
          Text(message.text).fontSize(16).lineHeight(24).fontColor(message.mine ? Color.White : INK)
            .copyOption(CopyOptions.InApp).width('100%')
          if (message.failed) { Text(this.tr('发送失败，请检查网络后重试')).fontSize(12).fontColor('#FFD7D7').width('100%') }
        }.width('78%').padding(14).backgroundColor(message.mine ? RED : SURFACE).borderRadius(18)
          .border({ width: 1, color: message.mine ? RED : LINE })
        if (!message.mine) { Blank().layoutWeight(1) }
      }.width('100%')
    }, (message: AiChatMessage) => message.id)
    if (this.aiBusy && this.aiMessages.length > 0) {
      Row() {
        Row({ space: 10 }) {
          LoadingProgress().width(22).height(22).color(RED)
          Text(this.tr('AI 正在思考，请耐心等待…')).fontSize(15).fontColor(MUTED)
        }.padding(14).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        Blank().layoutWeight(1)
      }.width('100%')
    }
  }

  @Builder
  GlobalReportsContent() {
    this.Notice({ message: 'healthDisclaimer' })
    if (this.globalReportsBusy) { LoadingProgress().width(36).height(36).color(RED) }
    if (this.globalReportsError) { this.Notice({ message: this.globalReportsError }) }
    Button(this.tr('reports_refresh')).width('100%').constraintSize({ minHeight: 48 }).enabled(!this.globalReportsBusy)
      .onClick(() => this.openGlobalReports()).id('reports_refresh')
    if (this.globalReportEligibility) {
      Text(formatAppText('reports_data_days', { days: String(this.globalReportEligibility.distinctDays),
        minimum: String(this.globalReportEligibility.minimumDistinctDays) }, this.appLocale)).fontSize(15).fontColor(INK).width('100%')
    }
    if (this.globalReportProfile?.consentVersion) {
      Button(this.tr('reports_withdraw')).width('100%').constraintSize({ minHeight: 48 }).enabled(!this.globalReportsBusy)
        .onClick(() => this.globalReportAction('revoke')).id('reports_withdraw')
    } else if (this.globalReportProfile?.document) {
      Button(this.tr('reports_read_notice')).width('100%').constraintSize({ minHeight: 48 }).enabled(!this.globalReportsBusy)
        .onClick(() => this.globalReportAction('read')).id('reports_read_notice')
    }
    ForEach(this.globalAnalysisParagraphs, (paragraph: string, index: number) => {
      Text(paragraph).fontSize(16).lineHeight(25).fontColor(INK).width('100%')
    }, (paragraph: string, index: number) => String(index))
    if (this.globalAnalysisDocument && this.globalAnalysisParagraphs.length > 0) {
      Row({ space: 8 }) {
        Checkbox().select(this.globalAnalysisAccepted).enabled(!this.globalReportsBusy)
          .onChange((checked: boolean) => this.globalAnalysisAccepted = checked).id('reports_analysis_agreement')
        Text(this.tr('reports_agree_notice')).fontSize(15).fontColor(INK).layoutWeight(1)
      }.width('100%')
      Button(this.tr('reports_agree')).width('100%').constraintSize({ minHeight: 48 })
        .enabled(this.globalAnalysisAccepted && !this.globalReportsBusy).onClick(() => this.globalReportAction('grant')).id('reports_agree')
    }
    if (this.globalReportProfile && this.globalReportEligibility) {
      if (reportGenerationBlock(this.globalReportProfile, this.globalReportEligibility)) {
        this.Notice({ message: reportGenerationBlock(this.globalReportProfile, this.globalReportEligibility) })
      }
      Button(this.tr('reports_generate')).width('100%').constraintSize({ minHeight: 48 })
        .enabled(!this.globalReportsBusy && !reportGenerationBlock(this.globalReportProfile, this.globalReportEligibility))
        .onClick(() => this.globalReportAction('generate')).id('reports_generate')
    }
    if (!this.globalReportsBusy && !this.globalReportsError && !this.globalReports.length) {
      this.StateCard({ title: 'reports_no_data' })
    }
    ForEach(this.globalReports, (report: GlobalHealthReport) => {
      Column({ space: 8 }) {
        Text(report.title || this.tr('reports')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Text(report.from.slice(0, 10) + ' – ' + report.to.slice(0, 10)).fontSize(14).fontColor(MUTED).width('100%')
        if (report.summary) { Text(report.summary).fontSize(15).fontColor(INK).lineHeight(23).width('100%') }
        if (report.aiGenerated) { Text(this.tr('reports_ai')).fontSize(13).fontColor(MUTED).width('100%') }
        if (report.status === 'ready') {
          Button(this.tr('reports_open')).width('100%').constraintSize({ minHeight: 48 }).enabled(!this.globalReportsBusy)
            .onClick(() => this.openGlobalReport(report)).id('report_' + report.id)
          Button(this.tr('reports_export')).width('100%').constraintSize({ minHeight: 48 }).enabled(!this.globalReportsBusy)
            .onClick(() => this.globalReportAction('export', report.id)).id('report_export_' + report.id)
        } else if (report.status === 'failed') {
          Text(this.tr('reports_failed')).fontSize(14).fontColor(MUTED).width('100%')
          Button(this.tr('retry')).width('100%').constraintSize({ minHeight: 48 })
            .enabled(!this.globalReportsBusy && !reportGenerationBlock(this.globalReportProfile, this.globalReportEligibility, true))
            .onClick(() => this.globalReportAction('generate', report.id)).id('report_retry_' + report.id)
        } else if (report.status === 'awaiting_payment') {
          Text(this.tr('reports_payment_unavailable')).fontSize(14).fontColor(MUTED).width('100%')
        } else if (report.status === 'revoked') {
          Text(this.tr('reports_revoked')).fontSize(14).fontColor(MUTED).width('100%')
        } else { Text(this.tr('reports_pending')).fontSize(14).fontColor(MUTED).width('100%') }
      }.padding(16).width('100%').backgroundColor(SURFACE).borderRadius(18)
    }, (report: GlobalHealthReport) => report.id)
    ForEach(this.globalReportParagraphs, (paragraph: string, index: number) => {
      Text(paragraph).fontSize(16).lineHeight(25).fontColor(INK).width('100%').copyOption(CopyOptions.InApp)
    }, (paragraph: string, index: number) => String(index))
  }


  @Builder
  AccountContent() {
    this.LanguagePicker()
    this.Notice({ message: 'language_note' })
    if (!this.hideAiContent) {
      this.PageRow({ title: 'reports', icon: $r('sys.symbol.doc'), action: () => this.openGlobalReports(), id: 'global_health_reports' })
    }
    if (this.guest) {
      this.Notice({ message: '登录后可管理账号信息。' })
      Button(this.tr('前往登录')).width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
        .type(ButtonType.Normal).borderRadius(12).onClick(() => this.screen = 'login')
    } else {
      Column({ space: 0 }) {
        this.PageRow({ title: '个人资料', subtitle: '注册手机号和基础资料', icon: $r('sys.symbol.person'),
          action: () => this.openProfileEditor(), id: 'edit_profile' })
        Divider().color(LINE).margin({ left: 56 })
        this.PageRow({ title: '收货地址', subtitle: '查看账号中的收货地址', icon: $r('sys.symbol.map'),
          action: () => this.openAddresses(), id: 'account_addresses' })
        Divider().color(LINE).margin({ left: 56 })
        this.PageRow({ title: '重置密码', subtitle: '验证手机号后重新设置登录密码', icon: $r('sys.symbol.lock'),
          action: () => this.openPasswordReset() })
        Divider().color(LINE).margin({ left: 56 })
        this.PageRow({ title: '隐私协议', icon: $r('sys.symbol.lock_shield'),
          action: () => this.openArticle('3', '隐私协议', true) })
      }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE }).clip(true)
      if (this.profileError) { this.Notice({ message: this.profileError, color: '#FFF0E9' }) }
      Button(this.tr(this.busy ? '正在退出…' : '退出登录')).width('100%').constraintSize({ minHeight: 56 }).margin({ top: 6 })
        .fontSize(16).fontWeight(FontWeight.Bold)
        .backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
        .enabled(!this.busy).onClick(() => this.signOut()).id('logout')
    }
  }

  @Builder
  AddressContent() {
    if (this.accountPageLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.accountPageError) { this.Notice({ message: this.accountPageError, color: '#FFF0E9' }) }
    if (!this.accountPageLoading && !this.accountPageError && this.addresses.length === 0) {
      Column({ space: 20 }) {
        SymbolGlyph($r('sys.symbol.bag')).fontSize(44).fontColor([INK])
        Text(this.tr('暂无收货地址')).fontSize(16).fontColor(INK)
        Button(this.tr('新增地址')).constraintSize({ minHeight: 56 }).fontSize(16).fontWeight(FontWeight.Bold)
          .backgroundColor(RED).type(ButtonType.Normal).borderRadius(12).onClick(() => this.editAddress()).id('add_address_empty')
      }.width('100%').constraintSize({ minHeight: 530 }).justifyContent(FlexAlign.Center)
    }
    ForEach(this.addresses, (address: ShippingAddress) => {
      Row({ space: 12 }) {
        Column() { SymbolGlyph($r('sys.symbol.map')).fontSize(22).fontColor([RED]) }
          .width(40).height(40).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(20)
        Column({ space: 6 }) {
          Text(this.tr(`${address.name}  ${address.mobile}`)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Text(this.tr(address.address)).fontSize(14).fontColor(MUTED).lineHeight(22).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button() { SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(22).fontColor([RED]) }
          .width(48).height(this.controlHeight(48)).backgroundColor(Color.Transparent).onClick(() => this.editAddress(address)).accessibilityText(this.tr('编辑地址'))
      }.width('100%').padding(15).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        .onClick(() => {
          if (this.selectingCheckoutAddress) { this.checkoutAddress = address; this.back(); }
          else this.editAddress(address);
        }).id(`edit_address_${address.id}`)
    }, (address: ShippingAddress) => address.id)
    Button(this.tr('刷新地址')).constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.Transparent)
      .enabled(!this.accountPageLoading).onClick(() => this.openAddresses())
  }

  @Builder
  AddressEditContent() {
    if (this.regionsLoading) { LoadingProgress().width(40).height(40).color(RED) }
    TextInput({ text: this.addressDraft.name, placeholder: this.tr('收货人') }).height(this.controlHeight(56)).fontSize(16).maxLength(60)
      .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.formBusy)
      .onChange((value: string) => this.editAddressText('name', value)).id('address_name')
    TextInput({ text: this.addressDraft.mobile, placeholder: this.tr('手机号') }).height(this.controlHeight(56)).fontSize(16).type(InputType.PhoneNumber).maxLength(11)
      .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.formBusy)
      .onChange((value: string) => this.editAddressText('mobile', value)).id('address_mobile')
    ForEach([0, 1, 2], (level: number) => {
      Stack({ alignContent: Alignment.TopStart }) {
        Select(this.addressChoices(level).map((item: RegionChoice): SelectOption => { return { value: item.name }; }))
          .selected(this.addressRegionIndex(level)).value(this.addressChoices(level)[this.addressRegionIndex(level)]?.name ?? '')
          .font({ size: 16 }).height(this.controlHeight(56)).width('100%').backgroundColor(SURFACE).borderRadius(12)
          .border({ width: 1, color: OUTLINE }).enabled(!this.formBusy && !this.regionsLoading && this.addressChoices(level).length > 0)
          .onSelect((index: number) => {
            const item = this.addressChoices(level)[index];
            if (item) this.addressDraft = selectAddressRegion(this.addressDraft, level, item.code);
          }).id(`address_region_${level}`).accessibilityText(this.tr(level === 0 ? '省或自治区' : level === 1 ? '市' : '区或县'))
        Text(this.tr(level === 0 ? '省/自治区' : level === 1 ? '城市' : '区/县'))
          .fontSize(this.addressRegionIndex(level) < 0 ? 16 : 12).fontColor(MUTED)
          .backgroundColor(this.addressRegionIndex(level) < 0 ? Color.Transparent : SURFACE).padding({ left: 4, right: 4 })
          .position({ x: 12, y: this.addressRegionIndex(level) < 0 ? 17 : -7 }).hitTestBehavior(HitTestMode.None)
      }.width('100%').height(this.controlHeight(56)).margin({ top: 4 })
    })
    TextArea({ text: this.addressDraft.details, placeholder: this.tr('详细地址') }).height(108).fontSize(16).maxLength(300)
      .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.formBusy)
      .onChange((value: string) => this.editAddressText('details', value)).id('address_details')
    Row() {
      Text(this.tr('设为默认地址')).fontSize(16).fontColor(INK).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.addressDraft.isDefault }).selectedColor(RED).enabled(!this.formBusy)
        .onChange((value: boolean) => {
          const draft = copyAddressDraft(this.addressDraft); draft.isDefault = value; this.addressDraft = draft;
        }).id('address_default')
    }.width('100%').constraintSize({ minHeight: 48 })
    if (this.formMessage) { this.Notice({ message: this.formMessage, color: GOLD_SOFT }) }
    Button(this.tr(this.formBusy ? '保存中…' : '保存地址')).width('100%').constraintSize({ minHeight: 56 }).fontSize(16)
      .fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
      .enabled(!this.formBusy && !this.regionsLoading).onClick(() => this.saveAddress()).id('save_address')
  }

  @Builder
  PasswordResetContent() {
    this.AuthMethodSelector()
    Column({ space: 24 }) {
      SymbolGlyph($r('sys.symbol.lock')).fontSize(54).fontColor([BLUE]).margin({ top: 26, bottom: 8 })
      Text(this.tr('reset_password')).fontSize(24).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').textAlign(TextAlign.Center)
    }.width('100%')
    TextInput({ text: this.resetMobile, placeholder: this.tr(this.authChannel === 'email' ? 'email' : 'phone') }).type(InputType.Normal).height(this.controlHeight(56)).fontSize(16)
      .maxLength(254).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.formBusy)
      .onChange((value: string) => { this.resetMobile = value; this.resetChallengeId = ''; this.resetCode = ''; }).id('reset_mobile')
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
      TextInput({ text: this.resetCode, placeholder: this.tr('短信验证码') }).type(InputType.Number).height(this.controlHeight(56)).fontSize(16)
        .width(this.singleColumn() ? '100%' : '58%').maxLength(8).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
        .enabled(!this.formBusy).onChange((value: string) => this.resetCode = value).id('reset_code')
      Button(this.tr(this.smsBusy ? '发送中…' : this.smsCountdown > 0 ? `${this.smsCountdown}s` : '获取验证码'))
        .width(this.singleColumn() ? '100%' : '38%').height(this.controlHeight(56)).fontSize(14).fontColor(INK).backgroundColor(SURFACE)
        .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE }).margin({ top: this.singleColumn() ? 8 : 0 })
        .enabled(!this.smsBusy && !this.formBusy && this.smsCountdown === 0 && !this.authCapabilitiesBusy && this.capabilities.recovery[this.authChannel]).onClick(() => this.sendResetCode())
    }.width('100%')
    TextInput({ text: this.resetPassword, placeholder: this.tr('新密码') }).type(InputType.Password).height(this.controlHeight(56)).fontSize(16)
      .maxLength(72).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.formBusy)
      .onChange((value: string) => this.resetPassword = value).id('reset_password')
    Text(this.tr('password_length')).fontSize(13).fontColor(MUTED).width('100%').padding({ left: 16 })
    TextInput({ text: this.resetConfirmation, placeholder: this.tr('确认新密码') }).type(InputType.Password).height(this.controlHeight(56)).fontSize(16)
      .maxLength(72).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.formBusy)
      .onChange((value: string) => this.resetConfirmation = value).id('reset_confirmation')
    if (this.formMessage) { this.Notice({ message: this.formMessage, color: GOLD_SOFT }) }
    Button(this.tr(this.formBusy ? '正在提交…' : '重置密码')).width('100%').constraintSize({ minHeight: 56 }).fontSize(16)
      .fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
      .enabled(!this.formBusy).onClick(() => this.submitResetPassword()).id('submit_reset')
  }

  @Builder
  ProfileInput(label: string, value: string, fieldId: string, numeric: boolean, change: (value: string) => void) {
    Column({ space: 4 }) {
      Text(this.tr(label)).fontSize(13).fontColor(MUTED).width('100%')
      TextInput({ text: value, placeholder: `请输入${label}` }).fontSize(16).height(this.controlHeight(48))
        .type(numeric ? InputType.NUMBER_DECIMAL : InputType.Normal).maxLength(numeric ? 6 : 30)
        .padding(0).backgroundColor(Color.Transparent).borderRadius(0)
        .enabled(!this.formBusy).onChange(change).id(fieldId).accessibilityText(this.tr(label))
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
  }

  @Builder
  ProfileEditorContent() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.editAvatarUri || this.profile.head_portrait) {
          Image(this.editAvatarUri || this.profile.head_portrait).width(94).height(94).objectFit(ImageFit.Cover).borderRadius(47)
            .border({ width: 1, color: LINE })
        } else {
          Column() { SymbolGlyph($r('sys.symbol.person_fill')).fontSize(42).fontColor([Color.White]) }
            .width(94).height(94).justifyContent(FlexAlign.Center).backgroundColor(RED).borderRadius(47)
        }
        Column() {
          if (this.avatarPicking) { LoadingProgress().width(18).height(18).color(Color.White) }
          else { SymbolGlyph($r('sys.symbol.camera_fill')).fontSize(17).fontColor([Color.White]) }
        }.width(32).height(32).justifyContent(FlexAlign.Center).backgroundColor(RED).borderRadius(16)
          .border({ width: 2, color: SURFACE })
      }.width(100).height(100).onClick(() => this.pickProfileAvatar()).id('profile_avatar_picker')
        .accessibilityText(this.tr('更换头像'))
      Text(this.tr(this.editAvatarUri ? '已选择新头像，保存后生效' : '点击头像更换照片'))
        .fontSize(14).fontColor(MUTED).textAlign(TextAlign.Center)
    }.width('100%').margin({ top: 8, bottom: 8 })

    if (this.profileError) {
      this.Notice({ message: this.profileError, color: GOLD_SOFT })
      Button(this.tr('重新读取')).width('100%').height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(Color.Transparent)
        .enabled(!this.profileLoading && !this.formBusy).onClick(async () => { await this.refreshProfile(); if (!this.profileError) this.openProfileEditor(); })
        .id('profile_retry')
    }
    Column({ space: 6 }) {
      Text(this.tr('注册手机号')).fontSize(13).fontColor(MUTED).width('100%')
      Row({ space: 12 }) {
        Text(profileField(this.profile.mobile || this.profile.username)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.lock')).fontSize(22).fontColor([INK])
      }.width('100%')
    }.width('100%').constraintSize({ minHeight: this.controlHeight(60) }).padding(16)
      .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
      .id('profile_registered_mobile').accessibilityText(this.tr('emailOrPhone') + ': ' + profileField(this.profile.mobile || this.profile.username))

    this.ProfileInput('昵称', this.editNickname, 'profile_nickname', false, (value: string) => this.editNickname = value)
    Column({ space: 4 }) {
      Text(this.tr('性别')).fontSize(13).fontColor(MUTED).width('100%')
      Select([{ value: '未设置' }, { value: '男' }, { value: '女' }]).selected(this.editGender)
        .value(['未设置', '男', '女'][this.editGender]).font({ size: 17 }).width('100%').backgroundColor(Color.Transparent)
        .enabled(!this.formBusy).onSelect((index: number) => this.editGender = index).id('profile_gender')
    }.width('100%').constraintSize({ minHeight: this.controlHeight(60) }).padding({ left: 16, right: 12, top: 10, bottom: 10 })
      .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
    Column({ space: 6 }) {
      Text(this.tr('出生日期')).fontSize(13).fontColor(MUTED).width('100%')
      Row({ space: 12 }) {
        Text(this.tr(this.editBirthday || '请选择出生日期')).fontSize(16).fontColor(this.editBirthday ? INK : MUTED).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.calendar')).fontSize(23).fontColor([INK])
      }.width('100%')
    }.width('100%').constraintSize({ minHeight: this.controlHeight(60) }).padding(16)
      .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
      .enabled(!this.formBusy).onClick(() => this.chooseBirthday()).id('profile_birthday')
      .accessibilityText(this.tr(`出生日期：${this.editBirthday || '未设置'}`))
    this.ProfileInput('身高（cm）', this.editHeight, 'profile_height', true, (value: string) => this.editHeight = value)
    this.ProfileInput('体重（kg）', this.editWeight, 'profile_weight', true, (value: string) => this.editWeight = value)

    this.Notice({ message: '保存后，资料会同步到当前账号。' })
    if (this.formMessage) {
      this.Notice({ message: this.formMessage, color: this.formMessage.includes('已保存') ? GREEN_SOFT : '#FFF0E9' })
    }
    Button(this.tr(this.formBusy ? '正在保存…' : '保存资料')).width('100%').constraintSize({ minHeight: 56 }).fontSize(16)
      .fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(14)
      .enabled(!this.formBusy && !this.avatarPicking).onClick(() => this.saveProfileDraft()).id('save_profile')
  }

  @Builder
  UnitSettingsContent() {
    Column() {
      ForEach(['km', 'mi'], (unit: string) => {
        Row({ space: 12 }) {
          Radio({ value: unit, group: 'distance', indicatorType: RadioIndicatorType.DOT }).checked(this.displayUnits.distance === unit)
            .radioStyle({ checkedBackgroundColor: RED, indicatorColor: RED, uncheckedBorderColor: INK }).onChange((checked: boolean) => {
              if (checked) this.setDisplayUnits(unit === 'mi' ? 'mi' : 'km', this.displayUnits.temperature);
            }).accessibilityText(this.tr(unit === 'km' ? '公里' : '英里')).id(`distance_${unit}`)
          Column({ space: 3 }) {
            Text(this.tr(unit === 'km' ? '公里' : '英里')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(this.tr(unit === 'km' ? '距离使用 km' : '距离使用 mi')).fontSize(14).fontColor(INK).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').constraintSize({ minHeight: 80 }).padding({ left: 8, right: 16, top: 8, bottom: 8 })
          .onClick(() => this.setDisplayUnits(unit === 'mi' ? 'mi' : 'km', this.displayUnits.temperature))
      })
    }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    Column() {
      ForEach(['c', 'f'], (unit: string) => {
        Row({ space: 12 }) {
          Radio({ value: unit, group: 'temperature', indicatorType: RadioIndicatorType.DOT }).checked(this.displayUnits.temperature === unit)
            .radioStyle({ checkedBackgroundColor: RED, indicatorColor: RED, uncheckedBorderColor: INK }).onChange((checked: boolean) => {
              if (checked) this.setDisplayUnits(this.displayUnits.distance, unit === 'f' ? 'f' : 'c');
            }).accessibilityText(this.tr(unit === 'c' ? '摄氏度' : '华氏度')).id(`temperature_${unit}`)
          Text(this.tr(unit === 'c' ? '摄氏度（℃）' : '华氏度（℉）')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
        }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 8, right: 16, top: 8, bottom: 8 })
          .onClick(() => this.setDisplayUnits(this.displayUnits.distance, unit === 'f' ? 'f' : 'c'))
      })
    }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    this.Notice({ message: '单位设置会影响 App 内的数据显示，不会更改原始记录。' })
    if (this.preferenceError) { this.Notice({ message: this.preferenceError, color: '#FFF0E9' }) }
  }

  @Builder
  AboutContent() {
    this.BrandLockup()
    Text(this.tr('brandHealthTitle')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').textAlign(TextAlign.Center)
    Text(this.tr('让健康数据更直观，让日常管理更轻松。')).fontSize(16).lineHeight(24).fontColor(MUTED)
      .width('100%').textAlign(TextAlign.Center)
    Text(`V${HARMONY_VERSION_NAME} (${HARMONY_VERSION_CODE})`).fontSize(16).fontColor(MUTED).width('100%').textAlign(TextAlign.Center)
    Column({ space: 0 }) {
      this.PageRow({ title: '隐私政策', icon: $r('sys.symbol.lock_shield'), action: () => this.openArticle('3', '隐私政策', true) })
      Divider().color(LINE).margin({ left: 56 })
      this.PageRow({ title: '用户协议', icon: $r('sys.symbol.doc'), action: () => this.openArticle('2', '用户协议', true) })
      Divider().color(LINE).margin({ left: 56 })
      this.PageRow({ title: this.updateBusy ? '正在检查更新…' : '检查更新', icon: $r('sys.symbol.arrow_down'),
        action: () => { if (!this.updateBusy) this.checkOnlineUpdate(); }, id: 'check_update' })
    }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE }).clip(true).margin({ top: 10 })
    if (this.updateStatus && this.updateStatus !== '点击检查是否有新版本') {
      this.Notice({ message: this.updateStatus, color: this.updateInfo.hasUpdate ? GOLD_SOFT : BLUE_SOFT })
    }
    if (this.updateInfo.hasUpdate) {
      if (this.updateInfo.releaseNotes) { Text(this.updateInfo.releaseNotes).fontSize(15).fontColor(INK).lineHeight(24).width('100%') }
      Button(this.tr('download_update')).width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
        .onClick(() => this.openUpdateDestination()).id('open_update')
    }
    this.StateCard({ title: '健康数据说明', detail: '测量结果仅供健康管理参考，不用于诊断或治疗。' })
  }

  @Builder
  ContactContent() {
    if (this.supportLoading) {
      LoadingProgress().width(40).height(40).color(RED).margin({ top: 28, bottom: 28 })
    } else if (this.supportError || !this.supportConfig.configured) {
      this.StateCard({ title: 'customerService', detail: this.supportError || '客服渠道暂时无法使用，请稍后再试',
        icon: $r('sys.symbol.message') })
      Button(this.tr('重新加载')).width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
        .onClick(() => this.loadSupportConfig()).id('contact_retry')
    } else {
      Column({ space: 0 }) {
        if (this.supportConfig.phone) {
          Row({ space: 14 }) {
            Column() { SymbolGlyph($r('sys.symbol.phone')).fontSize(24).fontColor([RED]) }
              .width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(21)
            Column({ space: 4 }) {
              Text(this.tr('联系电话')).fontSize(15).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
              Text(this.supportConfig.phone).fontSize(14).fontColor(MUTED).width('100%').copyOption(CopyOptions.InApp)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Button(this.tr('拨打电话')).constraintSize({ minHeight: 42 }).fontSize(14).fontColor(RED)
              .backgroundColor(RED_SOFT).type(ButtonType.Normal).borderRadius(12)
              .onClick(() => this.callSupport()).id('contact_call')
          }.width('100%').constraintSize({ minHeight: 76 }).padding({ left: 16, right: 12, top: 10, bottom: 10 })
        }
        if (this.supportConfig.phone && this.supportConfig.officialAccount) { Divider().color(LINE).margin({ left: 72 }) }
        if (this.supportConfig.officialAccount) {
          Row({ space: 14 }) {
            Column() { SymbolGlyph($r('sys.symbol.message')).fontSize(24).fontColor([GREEN]) }
              .width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor(GREEN_SOFT).borderRadius(21)
            Column({ space: 4 }) {
              Text(this.tr('公众号')).fontSize(15).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
              Text(this.supportConfig.officialAccount).fontSize(14).fontColor(MUTED).width('100%').copyOption(CopyOptions.InApp)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Button(this.tr('添加客服')).constraintSize({ minHeight: 42 }).fontSize(14).fontColor(GREEN)
              .backgroundColor(GREEN_SOFT).type(ButtonType.Normal).borderRadius(12)
              .onClick(() => this.copySupportAccount()).id('contact_copy')
          }.width('100%').constraintSize({ minHeight: 76 }).padding({ left: 16, right: 12, top: 10, bottom: 10 })
        }
      }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE }).clip(true)
      if (this.supportConfig.serviceHours) { this.Notice({ message: this.supportConfig.serviceHours, color: BLUE_SOFT }) }
      if (this.contactMessage) { this.Notice({ message: this.contactMessage, color: GREEN_SOFT }) }
    }
    this.StateCard({ title: 'support_prepare', detail: 'support_privacy',
      icon: $r('sys.symbol.lock_shield') })
  }

  @Builder
  HelpContent() {
    Text(this.tr('问题反馈')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').margin({ bottom: 2 })
    Stack({ alignContent: Alignment.TopStart }) {
      Select(FEEDBACK_TYPES.map((value: string): SelectOption => { return { value }; }))
        .selected(this.feedbackType).value(FEEDBACK_TYPES[this.feedbackType]).font({ size: 16 })
        .width('100%').height(this.controlHeight(60)).padding({ left: 8, right: 8 }).backgroundColor(SURFACE)
        .borderRadius(12).border({ width: 1, color: OUTLINE }).onSelect((index: number) => this.feedbackType = index)
        .enabled(!this.formBusy).id('feedback_type')
      Text(this.tr('问题类型')).fontSize(12).fontColor(MUTED).padding({ left: 4, right: 4 }).backgroundColor(BG)
        .position({ x: 16, y: -8 })
    }.width('100%').height(this.controlHeight(60))
    TextArea({ text: this.feedbackContent, placeholder: this.tr('问题说明') }).fontSize(16).height(164)
      .padding(20).maxLength(500).backgroundColor(SURFACE).borderRadius(12)
      .border({ width: 1, color: OUTLINE }).enabled(!this.formBusy)
      .onChange((value: string) => this.feedbackContent = value).id('feedback_content')
    Text(this.tr(`${this.feedbackContent.length}/500`)).fontSize(14).fontColor(MUTED).width('100%').textAlign(TextAlign.End)
      .padding({ right: 20 }).margin({ top: -10 })
    TextInput({ text: this.feedbackContact, placeholder: this.tr('联系方式（选填）') }).fontSize(16).height(this.controlHeight(60)).maxLength(100).padding(20)
      .backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE }).enabled(!this.formBusy)
      .onChange((value: string) => this.feedbackContact = value).id('feedback_contact')
    if (this.formMessage) { this.Notice({ message: this.formMessage, color: this.formMessage.includes('已提交') ? GREEN_SOFT : '#FFF0E9' }) }
    Button(this.tr(this.formBusy ? '正在提交…' : '提交反馈')).width('100%').constraintSize({ minHeight: 56 })
      .fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
      .enabled(!this.formBusy).onClick(() => this.submitFeedback()).id('submit_feedback')
    Text(this.tr('常见问题')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').margin({ top: 14 })
    Column({ space: 0 }) {
      ForEach(['ringHelpQuestion', '为什么健康数据暂时为空？'], (question: string, index: number) => {
        Row({ space: 12 }) {
          Text(this.tr(question)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(18).fontColor([MUTED])
            .rotate({ angle: this.expandedFaq === index ? 180 : 0 })
        }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16 })
          .onClick(() => this.expandedFaq = this.expandedFaq === index ? -1 : index).id(`faq_${index}`)
        if (this.expandedFaq === index) {
          Text(this.tr(index === 0 ? 'ringHelpAnswer' : 'ringDataHelpAnswer'))
            .fontSize(14).lineHeight(22).fontColor(MUTED).width('100%').padding({ left: 16, right: 16, bottom: 16 })
        }
        if (index === 0) { Divider().color(LINE) }
      })
    }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
  }

  @Builder
  PermissionContent() {
    Text(this.tr('App 系统权限')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').margin({ top: 16 })
    if (this.permissionError) { this.Notice({ message: this.permissionError, color: '#FFF0E9' }) }
    Column() {
      ForEach(this.permissionRows, (item: PermissionRow, index: number) => {
        Row({ space: 16 }) {
          SymbolGlyph(item.enabled ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.info_circle'))
            .fontSize(24).fontColor([item.enabled ? GREEN : GOLD])
          Column({ space: 4 }) {
            Text(this.tr(item.title)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(this.tr(item.status)).fontSize(14).fontColor(INK).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button(this.tr('设置')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(RED).backgroundColor(Color.Transparent)
            .constraintSize({ minHeight: 48, minWidth: 48 }).onClick(() => this.setPermission(item.key)).id(`permission_${item.key}`)
        }.width('100%').constraintSize({ minHeight: 80 }).padding({ left: 16, right: 16, top: 12, bottom: 12 })
        if (index < this.permissionRows.length - 1) { Divider().color(LINE).margin({ left: 56 }) }
      }, (item: PermissionRow) => item.key)
    }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.bell')).fontSize(23).fontColor([BLUE])
        }.width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(13)
        Column({ space: 3 }) {
          Text(this.tr('消息通知')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Text(this.tr(this.pushStatus)).fontSize(14).fontColor(MUTED).lineHeight(21).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.pushBusy) { LoadingProgress().width(24).height(24).color(RED) }
      }.width('100%')
      Button(this.tr(this.pushBusy ? '检查中…' : '检查通知服务')).width('100%').constraintSize({ minHeight: 48 })
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(RED).backgroundColor(Color.Transparent)
        .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: LINE }).enabled(!this.pushBusy)
        .onClick(() => this.connectPush(true)).id('check_push_service')
    }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    Button(this.tr('刷新权限状态')).width('100%').constraintSize({ minHeight: 56 }).fontSize(16).fontWeight(FontWeight.Bold)
      .fontColor(INK).backgroundColor(Color.Transparent).type(ButtonType.Normal).borderRadius(12)
      .border({ width: 1, color: OUTLINE }).onClick(() => this.refreshPermissions())
    this.Notice({ message: '仅在使用对应功能时申请权限。锁屏通知不显示具体健康数值。', color: GREEN_SOFT })
  }

  @Builder
  MessageContent() {
    if (this.inboxLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.inboxError) { this.Notice({ message: this.inboxError, color: '#FFF0E9' }) }
    if (careNotifications.failureMessage()) { this.Notice({ message: careNotifications.failureMessage(), color: '#FFF0E9' }) }
    if (!this.inboxLoading && !this.inboxError && this.inbox.length === 0) {
      Text(this.tr('暂无消息')).fontSize(16).fontColor(MUTED).width('100%').textAlign(TextAlign.Center).margin({ top: 180, bottom: 100 })
    }
    ForEach(this.inbox, (message: InboxMessage) => {
      Row({ space: 12 }) {
        Column() { SymbolGlyph($r('sys.symbol.bell')).fontSize(24).fontColor([message.kind === 'health_warning' ? RED : BLUE]) }
          .width(40).height(40).justifyContent(FlexAlign.Center)
          .backgroundColor(message.kind === 'health_warning' ? RED_SOFT : BLUE_SOFT).borderRadius(20)
        Column({ space: 5 }) {
          Row() {
            Text(message.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1).maxLines(2)
            if (!message.read) { Column().width(8).height(8).borderRadius(4).backgroundColor(RED).accessibilityText(this.tr('未读')) }
          }.width('100%')
          if (message.content) { Text(message.content).fontSize(14).fontColor(MUTED).lineHeight(21).maxLines(2).width('100%') }
          if (message.createdAt) { Text(message.createdAt).fontSize(12).fontColor(MUTED).width('100%') }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([RED])
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        .onClick(() => this.openInboxMessage(message)).id(`inbox_${message.id}`)
    }, (message: InboxMessage) => JSON.stringify(message))
    Button(this.tr('刷新消息')).width('100%').constraintSize({ minHeight: 48 }).fontColor(INK).backgroundColor(SURFACE)
      .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE })
      .enabled(!this.inboxLoading).onClick(() => { careNotifications.refresh(); this.refreshInbox(); }).id('refresh_unread')
    Row({ space: 8 }) {
      Button(this.tr('通知设置')).layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.Transparent)
        .onClick(() => { this.openInnerPage('permissions'); this.refreshPermissions(); this.connectPush(false); }).id('enable_push')
      Button(this.tr('关爱邀请')).layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.Transparent)
        .onClick(async () => { await this.openCare(); if (!this.guest) this.screen = 'care-invitations'; }).id('message_care_invitations')
    }.width('100%')
  }

  @Builder
  OrderContent() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach([99, 0, 1, 2, 3, -1], (filter: number) => {
          Button(filter === 99 ? '全部' : filter === -1 ? '售后' : this.orderStatus(filter))
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).constraintSize({ minHeight: 48 })
            .backgroundColor(this.orderFilter === filter ? GOLD_SOFT : SURFACE).type(ButtonType.Normal).borderRadius(10)
            .border({ width: 1, color: this.orderFilter === filter ? GOLD_SOFT : LINE })
            .onClick(() => this.openOrders(filter)).id(`order_filter_${filter}`)
        })
      }
    }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).align(Alignment.Top)
    if (this.orderLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.paymentMessage) { this.Notice({ message: this.paymentMessage, color: '#FFF0E9' }) }
    if (!this.orderLoading && !this.paymentMessage && this.visibleOrders().length === 0) {
      Column({ space: 20 }) {
        SymbolGlyph($r('sys.symbol.doc')).fontSize(60).fontColor([OUTLINE])
        Text(this.tr('暂无订单')).fontSize(16).fontColor(MUTED)
      }.width('100%').margin({ top: 100, bottom: 64 })
    }
    ForEach(this.visibleOrders(), (order: ShopOrder) => {
      Column({ space: 10 }) {
        Text(order.summary).fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').maxLines(2)
        Text(this.tr(`订单号：${order.number}`)).fontSize(14).fontColor(MUTED).width('100%').maxLines(2)
        Row() {
          Text(this.orderStatus(order.status)).fontSize(15).fontColor(order.status === 0 ? RED : MUTED).layoutWeight(1)
          Text(this.money(order.amountCents)).fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK)
        }.width('100%')
        Button(this.tr('订单详情')).width('100%').constraintSize({ minHeight: 48 }).fontColor(INK).backgroundColor(SURFACE)
          .border({ width: 1, color: OUTLINE, radius: 12 }).onClick(() => this.openCommerceOrder(order.id)).id(`detail_order_${order.id}`)
        if (order.status === 0) {
          Button(this.tr('去支付')).width('100%').constraintSize({ minHeight: 48 }).backgroundColor(RED)
            .onClick(() => this.openPayment(order)).id(`pay_order_${order.id}`)
        }
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    }, (order: ShopOrder) => String(order.id))
    Button(this.tr(this.orderLoading ? '正在刷新…' : '刷新订单')).width('100%').constraintSize({ minHeight: 48 })
      .fontColor(RED).backgroundColor(Color.White).enabled(!this.orderLoading)
      .onClick(() => this.openOrders()).id('refresh_orders')
  }

  @Builder
  PaymentContent() {
    Column({ space: 12 }) {
      if (this.selectedOrder.summary) {
        Text(this.selectedOrder.summary).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').maxLines(2)
      }
      Column({ space: 5 }) {
        Text(this.tr('订单号')).fontSize(15).fontColor(MUTED).width('100%')
        Text(this.selectedOrder.number).fontSize(15).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).copyOption(CopyOptions.InApp)
      }.width('100%').alignItems(HorizontalAlign.Start)
      Divider().color(LINE).margin({ top: 2, bottom: 2 })
      Row() {
        Text(this.tr('订单总额')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
        Text(this.money(this.selectedOrder.amountCents)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(RED)
      }.width('100%')
    }.width('100%').padding(18).backgroundColor(SURFACE).borderRadius(20)
      .border({ width: 1, color: LINE }).shadow({ radius: 9, color: CARD_SHADOW, offsetY: 3 })
    Text(this.tr('选择支付方式')).fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK).width('100%').margin({ top: 8 })
    Row({ space: 13 }) {
      Column() { SymbolGlyph($r('sys.symbol.wechat')).fontSize(25).fontColor(['#07C160']) }
        .width(46).height(46).justifyContent(FlexAlign.Center).backgroundColor('#EAF9F0').borderRadius(14)
      Column({ space: 3 }) {
        Text(this.tr('微信支付')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Text(this.tr('使用微信安全支付')).fontSize(13).fontColor(MUTED).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column() {
        if (this.selectedProvider === 'wechat') {
          SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([Color.White])
        }
      }.width(28).height(28).justifyContent(FlexAlign.Center)
        .backgroundColor(this.selectedProvider === 'wechat' ? RED : SURFACE).borderRadius(14)
        .border({ width: 1, color: this.selectedProvider === 'wechat' ? RED : OUTLINE })
    }.width('100%').constraintSize({ minHeight: 82 }).padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(SURFACE).borderRadius(18)
      .border({ width: this.selectedProvider === 'wechat' ? 2 : 1, color: this.selectedProvider === 'wechat' ? RED : LINE })
      .enabled(!this.paymentBusy).onClick(() => this.selectPaymentProvider('wechat')).id('select_wechat')
    Row({ space: 13 }) {
      Column() { SymbolGlyph($r('sys.symbol.wallet')).fontSize(25).fontColor(['#1677FF']) }
        .width(46).height(46).justifyContent(FlexAlign.Center).backgroundColor(BLUE_SOFT).borderRadius(14)
      Column({ space: 3 }) {
        Text(this.tr('支付宝支付')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Text(this.tr('使用支付宝安全支付')).fontSize(13).fontColor(MUTED).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column() {
        if (this.selectedProvider === 'alipay') {
          SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([Color.White])
        }
      }.width(28).height(28).justifyContent(FlexAlign.Center)
        .backgroundColor(this.selectedProvider === 'alipay' ? RED : SURFACE).borderRadius(14)
        .border({ width: 1, color: this.selectedProvider === 'alipay' ? RED : OUTLINE })
    }.width('100%').constraintSize({ minHeight: 82 }).padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(SURFACE).borderRadius(18)
      .border({ width: this.selectedProvider === 'alipay' ? 2 : 1, color: this.selectedProvider === 'alipay' ? RED : LINE })
      .enabled(!this.paymentBusy).onClick(() => this.selectPaymentProvider('alipay')).id('select_alipay')
    if (this.paymentMessage) {
      this.Notice({ message: this.paymentMessage, color: this.paymentMessage.includes('已更新') ? GREEN_SOFT : GOLD_SOFT })
    }
    Button(this.tr('刷新订单状态')).width('100%').constraintSize({ minHeight: 50 }).fontColor(INK)
      .backgroundColor(SURFACE).type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE })
      .enabled(!this.paymentBusy).onClick(() => this.refreshSelectedOrder()).id('payment_refresh')
    Button(this.tr('查看我的订单')).width('100%').constraintSize({ minHeight: 50 }).fontColor(INK)
      .backgroundColor(SURFACE).type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE })
      .enabled(!this.paymentBusy).onClick(() => this.openOrders()).id('payment_return_orders')
  }

  @Builder
  WearableMetricContent() {
    Row() {
      ForEach(['day', 'week', 'month'], (period: string) => {
        Button(this.tr(period === 'day' ? '日' : period === 'week' ? '周' : '月')).layoutWeight(1)
          .constraintSize({ minHeight: 48 }).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK)
          .backgroundColor(this.trendPeriod === period ? GOLD_SOFT : Color.Transparent).type(ButtonType.Normal)
          .border({ width: 0.5, color: OUTLINE }).borderRadius(0)
          .onClick(() => this.selectTrendPeriod(period === 'month' ? 'month' : period === 'week' ? 'week' : 'day')).id(`trend_period_${period}`)
      })
    }.width('100%').borderRadius(24).border({ width: 1, color: OUTLINE }).clip(true)
    Row({ space: 4 }) {
      Button() { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor([INK]) }
        .width(48).height(this.controlHeight(48)).backgroundColor(Color.Transparent).onClick(() => this.moveTrend(-1)).accessibilityText(this.tr('上一周期')).id('trend_previous')
      Button() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.calendar')).fontSize(20).fontColor([INK])
          Text(this.currentTrendWindow().label).fontSize(this.trendPeriod === 'week' ? 13 : 16).fontWeight(FontWeight.Bold)
            .fontColor(INK).layoutWeight(1).textAlign(TextAlign.Center)
        }.width('100%')
      }.layoutWeight(1).constraintSize({ minHeight: 56 }).padding({ left: 12, right: 12 }).backgroundColor(Color.Transparent)
        .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE }).onClick(() => this.pickTrendDate()).id('trend_calendar')
      Button() { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(20).fontColor([INK]) }
        .width(48).height(this.controlHeight(48)).backgroundColor(Color.Transparent).onClick(() => this.moveTrend(1))
        .enabled(this.currentTrendWindow().end <= Date.now()).accessibilityText(this.tr('下一周期')).id('trend_next')
    }.width('100%')
    if (this.wearableSnapshot.connected && this.wearableCapability(this.selectedWearableMetric)) {
      if (this.wearableMetricMeasurable(this.selectedWearableMetric)) {
        Button(this.tr(this.wearableMeasurement.running && this.wearableMeasurement.metric === this.selectedWearableMetric ? '结束测量' : '手动测量'))
          .width('100%').constraintSize({ minHeight: 56 }).fontSize(16).fontWeight(FontWeight.Bold)
          .backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
          .enabled(!this.sportActive() && !this.wearableBusy() && (!this.wearableMeasurement.running || this.wearableMeasurement.metric === this.selectedWearableMetric))
          .onClick(() => this.wearableMeasurement.running ? vepWearable.stopMeasurement() : vepWearable.startMeasurement(this.selectedWearableMetric))
          .id('trend_measure')
      }
      if (this.wearableMeasurement.metric === this.selectedWearableMetric && this.wearableMeasurement.status) {
        Column({ space: 10 }) {
          Text(this.measurementText()).fontSize(17).fontColor(INK).lineHeight(25).width('100%')
          if (this.selectedWearableMetric === 'ecg' && this.wearableMeasurement.samples.length > 1) {
            Polyline({ width: 320, height: 120 }).points(this.ecgWaveformPoints())
              .fillOpacity(0).stroke(RED).strokeWidth(2).width('100%').height(120)
            Text(this.tr(`真实心电波形 ${this.wearableMeasurement.samples.length} 点`)).fontSize(13).fontColor(MUTED).width('100%')
          }
        }.width('100%').padding(16).backgroundColor(RED_SOFT).borderRadius(18)
      }
    }
    if (this.trendLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.trendError) { this.Notice({ message: this.trendError, color: '#FFF0E9' }) }
    if (!this.trendLoading && !this.trendError && this.currentTrendRecords().length === 0) {
      this.StateCard({ title: '该时间段暂无数据', icon: $r('sys.symbol.waveform') })
    }
    if (this.currentTrendRecords().length > 0) {
      if (this.selectedWearableMetric !== 'ecg') {
        if (this.selectedWearableMetric !== 'pressure' && this.currentTrendNames().length > 1) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.currentTrendNames(), (name: string) => {
                Button(this.tr(name)).fontSize(14).constraintSize({ minHeight: 48 }).fontColor(this.primaryTrendName() === name ? Color.White : INK)
                  .backgroundColor(this.primaryTrendName() === name ? RED : SURFACE).type(ButtonType.Normal).borderRadius(10)
                  .onClick(() => { this.trendField = name; this.trendReadout = ''; }).id(`trend_field_${name}`)
              }, (name: string) => name)
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).align(Alignment.Top)
        }
        ForEach(this.displayedTrendNames(), (name: string) => {
          Column({ space: 10 }) {
            Row() {
              Text(this.tr(name)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
              Text(this.seriesSummary(name).unit).fontSize(14).fontColor(MUTED)
            }.width('100%')
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              Column({ space: 4 }) {
                Text(displayNumber(this.seriesSummary(name).max)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK)
                Text(this.tr('最大')).fontSize(12).fontColor(MUTED)
              }.width(this.singleColumn() ? '100%' : '24%').padding({ top: 4, bottom: 4 })
              Column({ space: 4 }) {
                Text(displayNumber(this.seriesSummary(name).min)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK)
                Text(this.tr('最小')).fontSize(12).fontColor(MUTED)
              }.width(this.singleColumn() ? '100%' : '24%').padding({ top: 4, bottom: 4 })
              Column({ space: 4 }) {
                Text(displayNumber(this.seriesSummary(name).average)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK)
                Text(this.tr('平均')).fontSize(12).fontColor(MUTED)
              }.width(this.singleColumn() ? '100%' : '24%').padding({ top: 4, bottom: 4 })
              Column({ space: 4 }) {
                Text(String(this.seriesSummary(name).count)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK)
                Text(this.tr(this.selectedWearableMetric === 'activity' ? '有记录天数' : '记录')).fontSize(12).fontColor(MUTED)
              }.width(this.singleColumn() ? '100%' : '24%').padding({ top: 4, bottom: 4 })
            }.width('100%')
            if (this.seriesSummary(name).change !== undefined) {
              Text(`较上一周期平均值变化 ${displayNumber(this.seriesSummary(name).change ?? NaN)}${this.seriesSummary(name).unit}`)
                .fontSize(13).fontColor(MUTED).width('100%')
            }
          }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
        }, (name: string) => name)
        if (this.selectedWearableMetric === 'sleep') {
          ForEach(this.currentTrendRecords(), (record: HealthRecord) => {
            Column({ space: 8 }) {
              Text(this.wearableRecordTime(record.timestamp)).fontSize(13).fontColor(MUTED).width('100%')
              Row({ space: 2 }) {
                ForEach(record.values.filter(value => ['深睡', '浅睡', '清醒'].includes(value.name)), (value: HealthValue) => {
                  Column().height(24).backgroundColor(value.name === '深睡' ? '#6451A4' : value.name === '浅睡' ? '#AB9CD1' : '#E2C68A')
                    .layoutWeight(Math.max(0.1, value.value)).accessibilityText(this.tr(`${value.name} ${value.value} 分钟`))
                })
              }.width('100%').borderRadius(6).clip(true)
              Text(this.displayRecord(record)).fontSize(14).fontColor(INK).lineHeight(22).width('100%')
            }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
          }, (record: HealthRecord) => record.id)
        } else {
          Column({ space: 8 }) {
            Row() {
              Text(this.tr('趋势图')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
              Text(`${this.chartTimeline().length} 个数据点`).fontSize(13).fontColor(MUTED)
            }.width('100%')
            Row() {
              Text(displayNumber(this.chartMaximum())).fontSize(12).fontColor(MUTED).layoutWeight(1)
              Text(this.trendPeriod === 'day' ? '触摸图表查看记录' : '按日汇总 · 触摸查看记录').fontSize(12).fontColor(MUTED)
            }.width('100%')
            Stack({ alignContent: Alignment.TopStart }) {
              ForEach(this.chartNames(), (name: string, seriesIndex: number) => {
                if (this.selectedWearableMetric === 'activity') {
                  ForEach(this.plottedSeries(name).points, (point: TrendPoint, pointIndex: number) => {
                    Column().width(8).height(Math.max(1, point.value / Math.max(1, this.chartMaximum()) * 128))
                      .backgroundColor(RED).position({ x: Math.min(this.trendChartWidth - 8,
                        spreadChartX(pointIndex, this.plottedSeries(name).points.length, this.trendChartWidth)),
                        y: 144 - Math.max(1, point.value / Math.max(1, this.chartMaximum()) * 128) })
                  })
                } else {
                  if (this.seriesPoints(name).length > 1) {
                    Polyline({ width: this.trendChartWidth, height: 160 }).points(this.seriesPoints(name))
                      .fillOpacity(0).stroke(seriesIndex === 0 ? RED : BLUE).strokeWidth(2)
                  }
                  ForEach(this.seriesPoints(name), (point: number[]) => {
                    Column().width(6).height(6).borderRadius(3).backgroundColor(seriesIndex === 0 ? RED : BLUE).position({ x: point[0] - 3, y: point[1] - 3 })
                  })
                }
              }, (name: string) => name)
            }.width('100%').height(160).onAreaChange((oldArea: Area, area: Area) => this.trendChartWidth = Number(area.width))
              .onTouch((event: TouchEvent) => {
                if ((event.type === TouchType.Down || event.type === TouchType.Move) && event.touches.length) {
                  this.inspectTrend(event.touches[0].x);
                }
              }).id('health_trend_chart')
            Row() {
              Text(this.chartStartLabel()).fontSize(12).fontColor(MUTED).layoutWeight(1)
              Text(this.chartEndLabel()).fontSize(12).fontColor(MUTED)
            }.width('100%')
            if (this.selectedWearableMetric === 'pressure') {
              Row({ space: 16 }) { Text(this.tr('收缩压')).fontSize(13).fontColor(RED); Text(this.tr('舒张压')).fontSize(13).fontColor(BLUE) }.width('100%')
            }
            if (this.trendReadout) { Text(this.trendReadout).fontSize(14).lineHeight(22).fontColor(INK).width('100%') }
          }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
            .accessibilityText(this.displayedTrendNames().map((name: string) =>
              `${name}，最大 ${displayNumber(this.seriesSummary(name).max)}，最小 ${displayNumber(this.seriesSummary(name).min)}，平均 ${displayNumber(this.seriesSummary(name).average)}`).join('；'))
        }
      }
      Row() {
        Text(this.tr(this.allTrendRecords ? '全部记录' : '近期数据')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
        Text(`${this.currentTrendRecords().length} 条`).fontSize(14).fontColor(MUTED)
      }.width('100%')
      ForEach(this.currentTrendRecords().slice().reverse().slice(this.allTrendRecords ? this.trendRecordPage * 50 : 0,
        this.allTrendRecords ? (this.trendRecordPage + 1) * 50 : 6), (record: HealthRecord) => {
        Row({ space: 10 }) {
          Column({ space: 6 }) {
            Text(this.displayRecord(record)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).lineHeight(24).width('100%')
            Text(this.wearableRecordTime(record.timestamp)).fontSize(14).fontColor(MUTED).width('100%')
            Text(this.tr(record.source === 'watch_history' ? 'ringHistory' : 'App 测量')).fontSize(12).fontColor(MUTED).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([RED])
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE }).onClick(() => this.openRecord(record))
      }, (record: HealthRecord) => record.id)
      if (!this.allTrendRecords && this.currentTrendRecords().length > 6) {
        Button(this.tr('查看全部记录')).width('100%').constraintSize({ minHeight: 48 }).backgroundColor(SURFACE).fontColor(RED)
          .type(ButtonType.Normal).borderRadius(12).onClick(() => this.allTrendRecords = true).id('all_trend_records')
      }
      if (this.allTrendRecords && this.currentTrendRecords().length > 50) {
        Row({ space: 8 }) {
          Button(this.tr('上一页')).layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(SURFACE)
            .enabled(this.trendRecordPage > 0).onClick(() => this.trendRecordPage--).id('records_previous')
          Text(`${this.trendRecordPage + 1}/${Math.ceil(this.currentTrendRecords().length / 50)}`).fontSize(14).fontColor(MUTED)
          Button(this.tr('下一页')).layoutWeight(1).constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(SURFACE)
            .enabled((this.trendRecordPage + 1) * 50 < this.currentTrendRecords().length).onClick(() => this.trendRecordPage++).id('records_next')
        }.width('100%')
      }
    }
    if (this.wearableSnapshot.connected && this.wearableCapability(this.selectedWearableMetric)) {
      Button(this.tr('syncRingData')).width('100%').constraintSize({ minHeight: 48 }).fontColor(INK).backgroundColor(Color.Transparent)
        .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE })
        .enabled(!this.wearableBusy() && !this.wearableMeasurement.running && !this.sportActive()).onClick(() => vepWearable.syncHistory())
    }
    this.StateCard({ title: '趋势仅作日常健康参考', detail: '单次和阶段变化可能受佩戴、运动及环境影响，不替代医疗诊断。', green: true,
      icon: $r('sys.symbol.lock_shield') })
  }

  @Builder
  HealthRecordContent() {
    if (this.selectedHealthRecord) {
      Column({ space: 14 }) {
        if (this.selectedHealthRecord.metric === 'sport') {
          Row({ space: 12 }) {
            Column() { SymbolGlyph(this.sportModeIcon(this.sportRecordIconMode(this.selectedHealthRecord))).fontSize(28).fontColor([RED]) }
              .width(52).height(52).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(16)
            Column({ space: 4 }) {
              Text(this.sportRecordMode(this.selectedHealthRecord)).fontSize(21).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
              if (this.selectedHealthRecord.sport && this.selectedHealthRecord.sport.durationSeconds > 0) {
                Text(this.sportDurationText(this.selectedHealthRecord.sport.durationSeconds)).fontSize(15).fontColor(MUTED).width('100%')
              }
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
        }
        Text(this.wearableRecordTime(this.selectedHealthRecord.timestamp)).fontSize(16).fontColor(MUTED).width('100%')
        Text(this.displayRecord(this.selectedHealthRecord)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK).lineHeight(30).width('100%')
        Text(this.selectedHealthRecord.source === 'watch_history' ? this.tr('sourceRingHistory') :
          this.selectedHealthRecord.metric === 'sport' ? '来源：App 运动' : '来源：App 测量').fontSize(14).fontColor(MUTED).width('100%')
        if (this.selectedHealthRecord.metric === 'sport' && this.selectedHealthRecord.sport &&
          this.selectedHealthRecord.sport.route.length > 1) {
          Column({ space: 8 }) {
            Text(this.tr('运动轨迹')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Polyline({ width: this.sportRouteWidth, height: 180 })
              .points(sportRoutePolyline(this.selectedHealthRecord.sport.route, this.sportRouteWidth, 180))
              .fillOpacity(0).stroke(RED).strokeWidth(3).width('100%').height(180)
              .onAreaChange((oldArea: Area, area: Area) => this.sportRouteWidth = Number(area.width))
            Text(this.tr(`真实轨迹形状 · ${this.selectedHealthRecord.sport.route.length} 个定位点`))
              .fontSize(13).fontColor(MUTED).width('100%')
          }.width('100%').padding(12).backgroundColor(SURFACE_ALT).borderRadius(14)
        } else if (this.selectedHealthRecord.metric === 'sport') {
          this.Notice({ message: 'ringRouteUnavailable', color: GOLD_SOFT })
        }
        if (this.selectedHealthRecord.samples.length > 1) {
          Polyline({ width: this.recordChartWidth, height: 160 }).points(waveformPoints(this.selectedHealthRecord.samples.slice(this.waveformSegment * 1000, (this.waveformSegment + 1) * 1000), this.recordChartWidth))
            .fillOpacity(0).stroke(RED).strokeWidth(1.5).width('100%').height(160)
            .onAreaChange((oldArea: Area, area: Area) => this.recordChartWidth = Number(area.width))
          Text(waveformPageLabel(this.selectedHealthRecord.samples.length, this.waveformSegment, this.selectedHealthRecord.sampleFrequency))
            .fontSize(14).fontColor(MUTED).width('100%').textAlign(TextAlign.Center)
          if (this.selectedHealthRecord.samples.length > 1000) {
            Row({ space: 8 }) {
              Button(this.tr('上一段')).layoutWeight(1).height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(Color.Transparent)
                .enabled(this.waveformSegment > 0).onClick(() => this.waveformSegment--)
              Text(`${this.waveformSegment + 1}/${Math.ceil(this.selectedHealthRecord.samples.length / 1000)}`).fontSize(14).fontColor(MUTED)
              Button(this.tr('下一段')).layoutWeight(1).height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(Color.Transparent)
                .enabled((this.waveformSegment + 1) * 1000 < this.selectedHealthRecord.samples.length).onClick(() => this.waveformSegment++)
            }.width('100%').accessibilityText(this.tr('逐段查看完整心电波形'))
          }
        }
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    } else { this.StateCard({ title: '记录暂不可用' }) }
  }

  @Builder
  CareDateControls() {
    Row({ space: 4 }) {
      Button() { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor([INK]) }
        .width(48).height(this.controlHeight(52)).backgroundColor(Color.Transparent).enabled(!this.careLoading)
        .onClick(() => { this.careDateInput = shiftChinaDay(this.careDay, -1); this.refreshCareDate(); })
        .accessibilityText(this.tr('前一天')).id('care_previous_day')
      Button() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.calendar')).fontSize(19).fontColor([RED])
          Text(this.careDay.replace('-', '年').replace('-', '月') + '日').fontSize(16).fontWeight(FontWeight.Bold).fontColor(RED)
        }
      }.layoutWeight(1).height(this.controlHeight(52)).backgroundColor(Color.Transparent).enabled(!this.careLoading)
        .onClick(() => this.pickCareDate()).id('care_calendar')
      Button() { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(20).fontColor([INK]) }
        .width(48).height(this.controlHeight(52)).backgroundColor(Color.Transparent).enabled(!this.careLoading && this.careDay < chinaDay())
        .onClick(() => { this.careDateInput = shiftChinaDay(this.careDay, 1); this.refreshCareDate(); })
        .accessibilityText(this.tr('后一天')).id('care_next_day')
    }.width('100%').padding(4).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
  }

  @Builder
  CareSharingGroup($$: CareGroupView) {
    Column({ space: 0 }) {
      Row() {
        Text(this.tr($$.daily ? '每日数据' : '健康数据')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
        Button(careGroupOptions($$.daily).every((option: CareOption) => this.careSettings.enabled.includes(option.key)) ? '取消全选' : '全选')
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(RED).backgroundColor(Color.Transparent).constraintSize({ minHeight: 48 })
          .enabled(this.careSettingsReady && !this.careBusy && !this.careLoading)
          .onClick(() => this.careSettings = toggleCareGroup(this.careSettings, $$.daily)).id($$.daily ? 'share_daily_all' : 'share_health_all')
      }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16 })
      ForEach(careGroupOptions($$.daily), (option: CareOption) => {
        Divider().color(LINE).margin({ left: 16 })
        Row({ space: 12 }) {
          Text(this.tr(option.label)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.careSettings.enabled.includes(option.key) })
            .selectedColor(RED).enabled(this.careSettingsReady && !this.careBusy && !this.careLoading)
            .onChange((enabled: boolean) => this.toggleCareSetting(option.key, enabled)).accessibilityText(this.tr(`共享${option.label}`))
        }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16 })
      }, (option: CareOption) => option.key)
    }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE }).clip(true)
  }

  @Builder
  CareSummaryContent() {
    if (careDaySummary(this.careMetricData).length > 0) {
      Column({ space: 12 }) {
        Text(this.tr('当日摘要')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        Text(this.tr('仅汇总所选日期的有效记录')).fontSize(13).fontColor(MUTED).width('100%')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(careDaySummary(this.careMetricData), (item: SummaryLabel) => {
            Column({ space: 5 }) {
              Text(this.tr(item.label)).fontSize(13).fontColor(MUTED).width('100%')
              Text(this.tr(item.value)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            }.width(this.singleColumn() ? '100%' : '48%').padding(12).margin({ bottom: 8 }).backgroundColor(BLUE_SOFT).borderRadius(12)
          }, (item: SummaryLabel) => item.label)
        }.width('100%')
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE }).id('care_day_summary')
    }
  }

  @Builder
  CareRecordContent() {
    if (this.selectedCareRecord) {
      Column({ space: 14 }) {
        Text(this.selectedCareRecord.time).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
        ForEach(this.selectedCareRecord.fields, (field: CareField) => {
          Flex({ direction: this.singleColumn() ? FlexDirection.Column : FlexDirection.Row }) {
            Text(this.tr(field.label)).fontSize(16).fontColor(MUTED).width(this.singleColumn() ? '100%' : '36%')
            Text(`${displayNumber(field.value)} ${field.unit}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK)
              .width(this.singleColumn() ? '100%' : '64%')
          }.width('100%').padding({ top: 4, bottom: 4 })
        }, (field: CareField) => field.label)
        if (this.selectedCareRecord.samples.length > 1) {
          Text(this.tr('心电波形')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
          Polyline({ width: this.recordChartWidth, height: 160 })
            .points(waveformPoints(this.selectedCareRecord.samples.slice(this.careWaveformSegment * 1000, (this.careWaveformSegment + 1) * 1000), this.recordChartWidth))
            .fillOpacity(0).stroke(RED).strokeWidth(1.5).width('100%').height(160)
            .onAreaChange((oldArea: Area, area: Area) => this.recordChartWidth = Number(area.width)).id('care_record_waveform')
          Text(waveformPageLabel(this.selectedCareRecord.samples.length, this.careWaveformSegment, this.selectedCareRecord.frequency))
            .fontSize(14).fontColor(MUTED).width('100%').textAlign(TextAlign.Center)
          if (this.selectedCareRecord.samples.length > 1000) {
            Row({ space: 8 }) {
              Button(this.tr('上一段')).layoutWeight(1).height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(RED_SOFT)
                .enabled(this.careWaveformSegment > 0).onClick(() => this.careWaveformSegment--).id('care_waveform_previous')
              Text(`${this.careWaveformSegment + 1}/${waveformPageCount(this.selectedCareRecord.samples.length)}`)
                .fontSize(14).fontColor(MUTED)
              Button(this.tr('下一段')).layoutWeight(1).height(this.controlHeight()).fontSize(16).fontColor(RED).backgroundColor(RED_SOFT)
                .enabled((this.careWaveformSegment + 1) * 1000 < this.selectedCareRecord.samples.length)
                .onClick(() => this.careWaveformSegment++).id('care_waveform_next')
            }.width('100%').accessibilityText(this.tr('逐段查看完整心电波形'))
          }
        } else if (this.careMetricData.key === 'ecg') {
          this.Notice({ message: '本条记录未包含可用心电波形' })
        }
        Text(this.tr('来源：关爱成员授权共享')).fontSize(13).fontColor(MUTED).width('100%')
      }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
    } else { this.StateCard({ title: '记录暂不可用' }) }
  }

  @Builder
  CareContent() {
    if (this.careLoading) { LoadingProgress().width(40).height(40).color(RED) }
    if (this.careMessage) { this.Notice({ message: this.careMessage, color: '#FFF0E9' }) }
    if (this.screen === 'care') {
      Row({ space: 14 }) {
        Column() { SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(30).fontColor([Color.White]) }
          .width(58).height(58).justifyContent(FlexAlign.Center).backgroundColor('#38FFFFFF').borderRadius(29)
        Column({ space: 5 }) {
          Text(this.tr('守护家人健康')).fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
          Text(this.tr(this.careMembers.length ? `已关爱 ${this.careMembers.length} 位家人` : '添加关爱成员后查看授权数据'))
            .fontSize(14).lineHeight(21).fontColor('#FFE4E9').width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button() { SymbolGlyph($r('sys.symbol.person_badge_plus')).fontSize(25).fontColor([RED]) }
          .width(48).height(this.controlHeight(48)).backgroundColor(SURFACE).borderRadius(24).enabled(!this.careLoading)
          .onClick(() => { this.careMessage = ''; this.screen = 'care-add'; }).accessibilityText(this.tr('添加关爱成员')).id('care_add')
      }.width('100%').padding(20).linearGradient({ angle: 135,
        colors: [['#A51125', 0.0], ['#D72D42', 1.0]] }).borderRadius(22)
      Row({ space: 0 }) {
        Row({ space: 10 }) {
          Column() { SymbolGlyph($r('sys.symbol.person_badge_gearshape')).fontSize(22).fontColor([RED]) }
            .width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(13)
          Column({ space: 3 }) {
            Text(this.tr('共享管理')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(this.tr('授权与隐私')).fontSize(14).fontColor(MUTED).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.layoutWeight(1).constraintSize({ minHeight: 76 }).padding(14).enabled(!this.careLoading)
          .onClick(() => { this.careMessage = ''; this.screen = 'care-sharing'; }).id('care_sharing')
        Divider().vertical(true).height(76).color(LINE)
        Row({ space: 10 }) {
          Column() { SymbolGlyph($r('sys.symbol.envelope')).fontSize(22).fontColor([RED]) }
            .width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(13)
          Column({ space: 3 }) {
            Text(this.tr('关爱邀请')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(this.careInvitationError ? '暂时无法读取' : this.pendingInvitations().length > 0 ?
              `${this.pendingInvitations().length} 条待处理` : '暂无新邀请').fontSize(14).fontColor(MUTED).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.layoutWeight(1).constraintSize({ minHeight: 76 }).padding(14).enabled(!this.careLoading)
          .onClick(() => { this.careMessage = ''; this.screen = 'care-invitations'; }).id('care_invitations')
      }.width('100%').backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      Text(this.tr('关爱成员')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      if (this.careMemberError) { this.Notice({ message: this.careMemberError, color: '#FFF0E9' }) }
      else if (!this.careLoading && this.careMembers.length === 0) {
        Column({ space: 16 }) {
          Column() { SymbolGlyph($r('sys.symbol.person_2_fill')).fontSize(36).fontColor([RED]) }
            .width(78).height(78).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(39)
          Text(this.tr('暂无关爱成员')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(INK)
          Text(this.tr('通过手机号邀请家人，对方接受并授权后才会共享健康数据。')).fontSize(14).lineHeight(22)
            .fontColor(MUTED).textAlign(TextAlign.Center).width('100%')
          Button(this.tr('添加关爱')).fontSize(16).fontWeight(FontWeight.Bold).constraintSize({ minHeight: 56 }).padding({ left: 24, right: 24 })
            .backgroundColor(RED).type(ButtonType.Normal).borderRadius(12).onClick(() => this.screen = 'care-add')
        }.width('100%').padding(26).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
      }
      ForEach(this.careMembers, (member: CareMember) => {
        Row({ space: 12 }) {
          Column() { SymbolGlyph($r('sys.symbol.person')).fontSize(24).fontColor([RED]) }
            .width(48).height(48).justifyContent(FlexAlign.Center).backgroundColor(RED_SOFT).borderRadius(24)
          Column({ space: 4 }) {
            Text(member.name).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(this.tr(member.mobile || '查看已授权的健康记录')).fontSize(13).fontColor(MUTED).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
        }.width('100%').constraintSize({ minHeight: 78 }).padding(14).backgroundColor(SURFACE).borderRadius(18)
          .border({ width: 1, color: LINE }).onClick(() => this.openCareMember(member))
          .id(`care_member_${member.relationId}`)
      }, (member: CareMember) => String(member.relationId))
      this.Notice({ message: '默认不共享任何数据；成员可按指标授权并随时撤销。', color: GREEN_SOFT })
      Button(this.tr('刷新关爱列表')).width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White)
        .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: LINE })
        .enabled(!this.careLoading).onClick(() => this.refreshCare())
    } else if (this.screen === 'care-add') {
      this.Notice({ message: '邀请只向您填写的账号发送。对方接受后，还需要主动选择共享项目。' })
      TextInput({ placeholder: this.tr('请输入家人手机号'), text: this.careMobile }).type(InputType.PhoneNumber)
        .fontSize(18).height(this.controlHeight(56)).maxLength(20).enabled(!this.careBusy).backgroundColor(Color.White)
        .onChange((value: string) => this.careMobile = value).id('care_mobile')
      Button(this.tr(this.careBusy ? '正在提交…' : '发送关爱邀请')).width('100%').constraintSize({ minHeight: 52 })
        .backgroundColor(RED).enabled(!this.careBusy && this.careMobile.trim().length > 0).onClick(() => this.sendCareInvitation())
    } else if (this.screen === 'care-invitations') {
      if (this.careInvitationError) { this.Notice({ message: this.careInvitationError, color: '#FFF0E9' }) }
      else if (!this.careLoading && this.pendingInvitations().length === 0) {
        this.StateCard({ title: '暂无新的关爱邀请', detail: '收到家人的关爱请求后，会显示在这里。', icon: $r('sys.symbol.envelope') })
      }
      ForEach(this.pendingInvitations(), (invite: CareInvitation) => {
        Column({ space: 12 }) {
          Flex({ direction: this.singleColumn() ? FlexDirection.Column : FlexDirection.Row, alignItems: ItemAlign.Start }) {
            Column() { SymbolGlyph($r('sys.symbol.person_fill')).fontSize(28).fontColor([RED]) }
              .width(50).height(50).backgroundColor(RED_SOFT).borderRadius(25).justifyContent(FlexAlign.Center)
              .margin({ right: this.singleColumn() ? 0 : 12, bottom: this.singleColumn() ? 8 : 0 }).accessibilityLevel('no')
            Column({ space: 5 }) {
              Text(invite.name).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
              if (invite.mobile) { Text(invite.mobile).fontSize(14).fontColor(MUTED).width('100%') }
              else if (invite.name !== careInvitationFallback(invite.inviterId)) {
                Text(careInvitationFallback(invite.inviterId)).fontSize(14).fontColor(MUTED).width('100%')
              }
              if (careInvitationNeedsConfirmation(invite)) {
                Text(this.tr('请确认邀请人后再接受')).fontSize(14).fontColor(MUTED).width('100%')
              }
            }.width(this.singleColumn() ? '100%' : undefined).layoutWeight(this.singleColumn() ? 0 : 1)
          }.width('100%')
          Text(this.tr('同意邀请不会自动开启健康数据共享。')).fontSize(14).fontColor(MUTED).width('100%')
          Flex({ direction: this.singleColumn() ? FlexDirection.Column : FlexDirection.Row, justifyContent: FlexAlign.SpaceBetween }) {
            Button(this.tr('拒绝')).width(this.singleColumn() ? '100%' : '48%').constraintSize({ minHeight: this.controlHeight(48) })
              .fontSize(16).fontColor(INK).backgroundColor(SURFACE).margin({ bottom: this.singleColumn() ? 10 : 0 })
              .type(ButtonType.Normal).borderRadius(12).border({ width: 1, color: OUTLINE })
              .enabled(!this.careBusy).onClick(() => this.respondInvitation(invite.id, false))
              .accessibilityText(this.tr(`拒绝${invite.name}的关爱邀请`)).id(`care_invitation_reject_${invite.id}`)
            Button(this.tr('同意')).width(this.singleColumn() ? '100%' : '48%').constraintSize({ minHeight: this.controlHeight(48) })
              .fontSize(16).backgroundColor(RED)
              .type(ButtonType.Normal).borderRadius(12).enabled(!this.careBusy).onClick(() => this.respondInvitation(invite.id, true))
              .accessibilityText(this.tr(`同意${invite.name}的关爱邀请`)).id(`care_invitation_accept_${invite.id}`)
          }.width('100%')
        }.width('100%').padding(18).borderRadius(18).backgroundColor(Color.White).id(`care_invitation_${invite.id}`)
      }, (invite: CareInvitation) => JSON.stringify(invite))
      Button(this.tr('刷新邀请状态')).width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.White)
        .enabled(!this.careLoading && !this.careBusy).onClick(() => this.refreshCare())
    } else if (this.screen === 'care-sharing') {
      this.Notice({ message: '这里管理哪些关爱人可以查看您的数据。只显示您已经同意的邀请。', color: GREEN_SOFT })
      if (this.careInvitationError) { this.Notice({ message: this.careInvitationError, color: '#FFF0E9' }) }
      else if (this.sharingTargets().length === 0) {
        this.StateCard({ title: '暂无共享对象', detail: '同意关爱邀请后，可在这里管理共享项目。', icon: $r('sys.symbol.lock_shield') })
      }
      ForEach(this.sharingTargets(), (invite: CareInvitation) => {
        Button(this.tr(`${invite.name}\n设置允许对方查看的项目`)).width('100%').constraintSize({ minHeight: 76 })
          .type(ButtonType.Normal).borderRadius(18).labelStyle({ maxLines: 8 })
          .padding(16).fontSize(17).fontColor(INK).backgroundColor(Color.White).onClick(() => this.openCareSettings(invite))
      }, (invite: CareInvitation) => String(invite.inviterId))
    } else if (this.screen === 'care-settings') {
      this.StateCard({ title: this.careSelectedInviter.name, detail: '只有已开启的项目会共享；关闭后保存即可撤销。',
        icon: $r('sys.symbol.lock_shield'), green: true })
      if (!this.careLoading && !this.careSettingsReady) {
        this.StateCard({ title: '共享设置暂时不可用', detail: '当前不会更改任何授权项目。', icon: $r('sys.symbol.cloud') })
      }
      if (this.careSettings.unknown.length) { this.Notice({ message: '其他已有共享设置将保持不变。' }) }
      this.CareSharingGroup({ daily: true })
      this.CareSharingGroup({ daily: false })
      Button(this.tr(this.careBusy ? '正在保存…' : '保存共享设置')).width('100%').constraintSize({ minHeight: 56 })
        .fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
        .enabled(this.careSettingsReady && !this.careBusy && !this.careLoading).onClick(() => this.saveCareSettings())
      Button(this.tr('重新读取共享设置')).width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.Transparent)
        .enabled(!this.careBusy && !this.careLoading).onClick(() => this.openCareSettings(this.careSelectedInviter))
    } else if (this.screen === 'care-member') {
      this.CareDateControls()
      Row() {
        Blank().layoutWeight(1)
        Button(this.tr(this.careLoading ? '正在读取…' : this.careUpdatedAt ? `更新于 ${this.careUpdatedAt}` : '刷新数据'))
          .constraintSize({ minHeight: 48 }).fontSize(14).fontColor(MUTED).backgroundColor(Color.Transparent)
          .enabled(!this.careLoading).onClick(() => this.loadCareOverview()).id('care_member_refresh')
      }.width('100%')
      if (!this.careLoading && this.careOverview.length > 0) {
        Text(`可查看 ${this.careOverview.filter((metric: CareMetric) => metric.state === 'ready').length} 项 · ` +
          `暂无记录 ${this.careOverview.filter((metric: CareMetric) => metric.state === 'empty').length} 项 · ` +
          `未授权 ${this.careOverview.filter((metric: CareMetric) => metric.state === 'unauthorized').length} 项`)
          .fontSize(14).fontColor(MUTED).width('100%').textAlign(TextAlign.Center)
      }
      ForEach(this.careOverview, (metric: CareMetric) => {
        Row({ space: 14 }) {
          Column() {
            SymbolGlyph(metric.state === 'ready' ? $r('sys.symbol.heart_fill') :
              metric.state === 'unauthorized' ? $r('sys.symbol.lock_shield') : $r('sys.symbol.info_circle'))
              .fontSize(23).fontColor([metric.state === 'ready' ? RED : metric.state === 'unauthorized' ? MUTED : BLUE])
          }.width(46).height(46).justifyContent(FlexAlign.Center)
            .backgroundColor(metric.state === 'ready' ? RED_SOFT : metric.state === 'unauthorized' ? SURFACE_ALT : BLUE_SOFT)
            .borderRadius(14)
          Column({ space: 5 }) {
            Text(this.tr(metric.title)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
            Text(metric.state === 'ready' ? careMetricLatest(metric) : metric.state === 'unauthorized' ? '对方未授权此项目' :
              metric.state === 'empty' ? '当日暂无记录' : '服务暂不可用，可刷新重试')
              .fontSize(14).fontColor(metric.state === 'ready' ? INK : MUTED).lineHeight(21).width('100%').maxLines(2)
            if (metric.state === 'ready') {
              Text(this.tr(`${metric.records.length} 条共享记录`)).fontSize(13).fontColor(MUTED).width('100%')
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
        }.width('100%').constraintSize({ minHeight: 88 }).padding(14).backgroundColor(SURFACE).borderRadius(18)
          .border({ width: 1, color: LINE }).onClick(() => this.openCareMetric(metric)).id(`care_metric_${metric.key}`)
          .accessibilityText(this.tr(`${metric.title}，${metric.state === 'ready' ? metric.records.length + ' 条记录' : metric.message}`))
      }, (metric: CareMetric) => metric.key)
    } else if (this.screen === 'care-metric') {
      this.CareDateControls()
      if (!this.careLoading && !this.careMessage) {
        this.CareSummaryContent()
        if (this.careMetricData.records.length === 0) {
          this.Notice({ message: this.careMetricData.message || '当日暂无记录', color: GOLD_SOFT })
        }
        ForEach(this.careMetricData.records.slice(0, this.careRecordLimit), (record: CareRecord) => {
          Column({ space: 12 }) {
            Text(record.time).fontSize(14).fontColor(MUTED).width('100%')
            Text(careRecordText(record)).fontSize(18).fontColor(INK).lineHeight(27).width('100%')
            if (record.samples.length > 1) {
              Polyline({ width: 280, height: 160 }).points(waveformPoints(record.samples.slice(0, 1000), 280))
                .fillOpacity(0).stroke(RED).strokeWidth(1.5).width('100%').height(160)
              Text(this.tr('查看完整心电波形')).fontSize(14).fontColor(RED).width('100%')
            }
            Text(this.tr('来源：关爱成员授权共享')).fontSize(13).fontColor(MUTED).width('100%')
          }.width('100%').padding(18).backgroundColor(SURFACE).borderRadius(18).border({ width: 1, color: LINE })
            .onClick(() => this.openCareRecord(record)).id(`care_record_${record.id}`)
        }, (record: CareRecord) => record.id)
        if (this.careRecordLimit < this.careMetricData.records.length) {
          Button(this.tr('显示更多记录')).width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.Transparent)
            .onClick(() => this.careRecordLimit += 30)
        }
      }
      Button(this.tr('刷新记录')).width('100%').constraintSize({ minHeight: 48 }).fontColor(RED).backgroundColor(Color.Transparent)
        .enabled(!this.careLoading).onClick(() => this.loadCareMetric())
    } else if (this.screen === 'care-record') {
      this.CareRecordContent()
    }
  }

  @Builder
  ArticleListContent() {
    Column({ space: 10 }) {
      Text(this.tr('健康分类')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK).width('100%')
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.articleCategories.length ? this.articleCategories : [{ id: 0, title: '全部' }], (category: ArticleCategory) => {
            Button(this.tr(category.title)).constraintSize({ minHeight: 48 }).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK)
              .type(ButtonType.Normal).borderRadius(10).backgroundColor(this.articleCategoryId === category.id ? GOLD_SOFT : SURFACE)
              .border({ width: this.articleCategoryId === category.id ? 0 : 1, color: OUTLINE }).padding({ left: 16, right: 16 })
              .enabled(!this.listLoading).onClick(() => { this.articleCategoryId = category.id; this.openArticles(); })
              .id(`article_category_${category.id}`)
          }, (category: ArticleCategory) => String(category.id))
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).align(Alignment.Top).scrollBar(BarState.Off)
    }.width('100%').padding(16).backgroundColor(SURFACE)
    if (this.listLoading) { LoadingProgress().width(40).height(40).color(RED) }
    else if (this.listError) {
      this.StateCard({ title: '健康百科加载失败', icon: $r('sys.symbol.cloud') })
      Button(this.tr('重新加载')).constraintSize({ minHeight: 48 }).fontSize(16).fontColor(RED).backgroundColor(Color.Transparent)
        .onClick(() => this.openArticles())
    } else if (!this.articles.length) {
      Text(this.tr('该分类暂无百科内容')).fontSize(16).fontColor(INK).textAlign(TextAlign.Center).width('100%').margin({ top: 160 })
    }
    ForEach(this.articles, (item: Article) => {
      Row({ space: 16 }) {
        Column() { SymbolGlyph($r('sys.symbol.book')).fontSize(22).fontColor([GREEN]) }
          .width(40).height(40).justifyContent(FlexAlign.Center).backgroundColor(GREEN_SOFT).borderRadius(20)
        Text(this.tr(item.title || '健康百科')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(INK).layoutWeight(1).maxLines(2)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([MUTED])
      }.width('100%').constraintSize({ minHeight: 72 }).padding(16).backgroundColor(SURFACE).borderRadius(18)
        .border({ width: 1, color: LINE }).onClick(() => this.openArticle(String(item.id ?? ''), item.title || '健康百科', false))
    }, (item: Article) => String(item.id))
  }

  @Builder
  ContentPage() {
    Column() {
      Column() { this.Heading() }
        .width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 4, right: 4 })
        .backgroundColor(BG)
    Scroll(this.contentScroller) {
      Column({ space: 14 }) {
        if (this.screen === 'feature') {
          this.Notice({ message: this.detailBody })
          if (this.detailTitle === '远程关爱' && this.guest) {
            Button(this.tr('前往登录')).width('100%').constraintSize({ minHeight: 52 }).backgroundColor(RED)
              .onClick(() => { this.error = ''; this.screen = 'login'; })
          }
        } else if (this.screen === 'device-search') {
          this.DeviceSearchContent()
        } else if (this.screen === 'device-dials') {
          this.InstalledDialsContent()
        } else if (this.screen === 'device-feature') {
          this.DeviceFeatureContent()
        } else if (this.screen === 'device-settings') {
          this.DeviceSettingsContent()
        } else if (this.screen === 'device-units' || this.screen === 'device-alarms' || this.screen === 'device-alarm-edit') {
          this.WatchSettingsContent()
        } else if (this.screen === 'wearable-metric') {
          this.WearableMetricContent()
        } else if (this.screen === 'health-record') {
          this.HealthRecordContent()
        } else if (this.screen === 'health-reports') {
          if (!this.hideAiContent) { this.GlobalReportsContent() }
        } else if (this.screen === 'health-all') {
          this.HealthAllContent()
        } else if (this.screen === 'sport-records') {
          this.SportRecordContent()
        } else if (this.screen === 'health-alerts') {
          this.HealthAlertContent()
        } else if (this.screen === 'ai-chat') {
          if (!this.hideAiContent) { this.AiChatContent() }
        } else if (this.screen === 'shop-home') {
          this.ShopHomeContent()
        } else if (this.screen === 'shop-product') {
          this.ShopProductContent()
        } else if (this.screen === 'shop-cart') {
          this.CartContent()
        } else if (this.screen === 'shop-checkout') {
          this.CheckoutContent()
        } else if (this.screen === 'shop-order-detail') {
          this.OrderDetailContent()
        } else if (this.screen === 'shop-express') {
          this.ExpressContent()
        } else if (this.screen === 'shop-after-sales') {
          this.AfterSalesContent()
        } else if (this.screen === 'shop-refund') {
          this.RefundContent()
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
        } else if (this.screen === 'account') {
          this.AccountContent()
        } else if (this.screen === 'profile-edit') {
          this.ProfileEditorContent()
        } else if (this.screen === 'addresses') {
          this.AddressContent()
        } else if (this.screen === 'address-edit') {
          this.AddressEditContent()
        } else if (this.screen === 'reset-password') {
          this.PasswordResetContent()
        } else if (this.screen === 'unit-settings') {
          this.UnitSettingsContent()
        } else if (this.screen === 'articles') {
          this.ArticleListContent()
        } else {
          if (this.articleLoading) { LoadingProgress().width(40).height(40).color(RED) }
          if (this.articleError) {
            this.Notice({ message: this.articleError, color: '#FFF0E9' })
            Button(this.tr('重新加载内容')).constraintSize({ minHeight: 48 }).backgroundColor(RED)
              .onClick(() => this.openArticle(this.selectedArticleId, this.articleTitle, this.selectedAgreement))
              .id('retry_article')
          }
          ForEach(this.articleContent, (block: ArticleBlock) => {
            if (block.kind === 'text') {
              Text(block.text).fontSize(16).lineHeight(26).fontColor(INK).width('100%').copyOption(CopyOptions.InApp)
            } else if (block.kind === 'image') {
              ArticleImage({ source: block.url, description: block.text })
            } else {
              this.Notice({ message: '配图暂不可用。' })
            }
          }, (block: ArticleBlock) => `${this.selectedArticleId}-${block.id}-${block.url}`)
        }
      }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: this.screen === 'shop-product' ? 0 : this.screen === 'about' || this.screen === 'reset-password' ? 24 : 16,
        right: this.screen === 'shop-product' ? 0 : this.screen === 'about' || this.screen === 'reset-password' ? 24 : 16, top: this.screen === 'shop-product' ? 0 : 8, bottom: 24 })
    }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
      if (this.screen === 'ai-chat' && !this.hideAiContent) {
        Row({ space: 10 }) {
          TextInput({ placeholder: this.tr('请输入消息…'), text: this.aiInput }).fontSize(16).height(this.controlHeight(56))
            .maxLength(AI_USER_MESSAGE_MAX_LENGTH)
            .layoutWeight(1).backgroundColor(SURFACE).borderRadius(12).border({ width: 1, color: OUTLINE })
            .enabled(!this.aiBusy).onChange((value: string) => this.aiInput = value).onSubmit(() => this.sendAiChat()).id('ai_input')
          Button() {
            if (this.aiBusy) { LoadingProgress().width(24).height(24).color(Color.White) }
            else { SymbolGlyph($r('sys.symbol.paperplane')).fontSize(24).fontColor([Color.White]) }
          }.width(48).height(this.controlHeight(48)).borderRadius(24).backgroundColor(RED)
            .enabled(!this.aiBusy && this.aiInput.trim().length > 0).onClick(() => this.sendAiChat()).id('ai_send').accessibilityText(this.tr('发送消息'))
        }.width('100%').padding(12).backgroundColor(SURFACE)
      } else if (this.screen === 'shop-product' && this.productDetail) {
        Row({ space: 8 }) {
          Button() { Column({ space: 2 }) {
            SymbolGlyph($r('sys.symbol.house')).fontSize(23).fontColor([INK]); Text(this.tr('首页')).fontSize(11).fontColor(INK)
          } }.width(48).height(this.controlHeight(52)).backgroundColor(Color.Transparent).onClick(() => { this.screen = 'shop-home'; })
          Button() { Column({ space: 2 }) {
            SymbolGlyph($r('sys.symbol.phone')).fontSize(23).fontColor([INK]); Text(this.tr('客服')).fontSize(11).fontColor(INK)
          } }.width(48).height(this.controlHeight(52)).backgroundColor(Color.Transparent).onClick(() => this.openContact())
          Button(this.tr('加入购物车')).layoutWeight(1).height(this.controlHeight(48)).fontSize(14).fontWeight(FontWeight.Bold).fontColor(INK).backgroundColor(SURFACE)
            .type(ButtonType.Normal).border({ width: 1, color: OUTLINE, radius: 12 }).enabled(!this.commerceBusy)
            .onClick(() => this.showPurchase(true)).id('product_add_cart')
          Button(this.tr('立即购买')).layoutWeight(1).height(this.controlHeight(48)).fontSize(14).fontWeight(FontWeight.Bold).backgroundColor(RED)
            .type(ButtonType.Normal).borderRadius(12).enabled(!this.commerceBusy).onClick(() => this.showPurchase(false)).id('product_buy')
        }.width('100%').padding({ left: 12, right: 12, top: 8, bottom: 10 }).backgroundColor(BG)
          .bindSheet($$this.purchaseSheet, this.PurchaseSheetContent(), { height: SheetSize.FIT_CONTENT })
      } else if (this.screen === 'shop-cart' && this.cartLines.length > 0 && !this.commerceLoading) {
        Row({ space: 6 }) {
          Checkbox().select(this.cartSelection.length === this.cartLines.length).selectedColor(RED).enabled(!this.commerceBusy)
            .onChange((selected: boolean) => this.cartSelection = selected ? this.cartLines.map((line: ShopLine) => line.skuId) : []).id('cart_select_all')
          Text(this.tr('全选')).fontSize(14).fontColor(INK)
          Text(`合计 ${commerceMoney(this.cartTotal())}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(RED).layoutWeight(1)
          Button(`结算（${this.cartChosen().length}）`).height(this.controlHeight(48)).fontSize(14).backgroundColor(RED)
            .enabled(!this.commerceBusy && this.cartChosen().length > 0 && this.cartTotal() >= 0)
            .onClick(() => this.openCheckout(this.cartChosen().map((line: ShopLine): ShopSelection => { return { skuId: line.skuId, quantity: line.quantity }; }), true)).id('cart_checkout')
        }.width('100%').padding(12).backgroundColor(SURFACE)
      } else if (this.screen === 'shop-checkout' && this.checkoutPreview) {
        Row({ space: 12 }) {
          Text(`合计 ${commerceMoney(this.checkoutPreview.productCents + this.checkoutPreview.shippingCents)}`)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#914E00').layoutWeight(1)
          Button(this.tr(this.commerceBusy ? '提交中…' : '提交订单')).height(this.controlHeight(56)).fontSize(16).fontWeight(FontWeight.Bold).backgroundColor(RED)
            .enabled(!this.commerceBusy && !this.checkoutAttempted).onClick(() => this.submitCommerceOrder()).id('checkout_submit')
        }.width('100%').padding({ left: 18, right: 12, top: 9, bottom: 10 }).backgroundColor(BG)
      } else if (this.screen === 'shop-payment') {
        Column() {
          Button(this.paymentBusy ? '正在处理…' : `去支付  ${this.money(this.selectedOrder.amountCents)}`)
            .width('100%').constraintSize({ minHeight: 56 }).fontSize(18).fontWeight(FontWeight.Bold)
            .backgroundColor(RED).type(ButtonType.Normal).borderRadius(12)
            .enabled(!this.paymentBusy && this.selectedOrder.status === 0)
            .onClick(() => this.startPayment()).id('confirm_payment')
        }.width('100%').padding(16).backgroundColor(SURFACE)
      } else if (this.screen === 'addresses') {
        Row() {
          Blank().layoutWeight(1)
          Button() {
            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.plus')).fontSize(22).fontColor([RED_DARK])
              Text(this.tr('新增地址')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(RED_DARK)
            }.padding({ left: 20, right: 20 })
          }.height(this.controlHeight(56)).type(ButtonType.Normal).borderRadius(16).backgroundColor(RED_SOFT)
            .onClick(() => this.editAddress()).id('add_address')
        }.width('100%').padding(16)
      }
    }.width('100%').height('100%').backgroundColor(this.screen === 'shop-product' ? '#F6F4F2' : this.screen === 'shop-order-detail' ? '#F7F4F1' : BG)
  }

  build() {
    Column() {
      if (this.screen === 'login') { this.Login() }
      else if (this.screen === 'register') { this.Registration() }
      else if (this.screen === 'home') { this.Home() }
      else if (this.screen === 'shop-home') { this.ShopHomeContent() }
      else { this.ContentPage() }
    }.width('100%').height('100%').backgroundColor(BG)
      .onAreaChange((oldArea: Area, area: Area) => {
        this.pageWidth = Number(area.width);
        this.refreshLayoutScale();
      })
  }
}
