// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get scanLocationTitle => '请开启手机定位';

  @override
  String get scanLocationHint => '请在设置中开启手机定位，再返回此页面查找附近的手表。';

  @override
  String get scanPermissionTitle => '请允许相关权限';

  @override
  String get scanPermissionHint => '请在设置中允许相关权限，再返回此页面查找手表。';

  @override
  String get loginProtectionTitle => '登录保护';

  @override
  String get verifyContactToReset => '验证邮箱或手机号后重新设置密码';

  @override
  String get workoutStartOnWatch => '当前手表未开放由 APP 启动的运动模式，请直接在手表上开始运动。';

  @override
  String get finishWorkoutConfirm => '结束当前运动？';

  @override
  String get finishLeaveWorkoutHint => '离开前将先停止手表运动，并保存已记录的运动时长和轨迹。';

  @override
  String get finishAndLeave => '结束并离开';

  @override
  String get workoutRouteMissing => '该记录没有手机前台轨迹，仍保留手表运动数据。';

  @override
  String get workoutDuration => '运动时长';

  @override
  String get workoutWatchHeartRate => '手表心率';

  @override
  String get messageSendFailed => '发送失败，请检查网络后重试';

  @override
  String get noWatchShopHint => '没有设备？去赛电商城看看';

  @override
  String get notificationInAppHint => '应用内红点和消息仍可使用，开启后可及时收到关爱邀请与健康预警。';

  @override
  String get healthAlertSafetyHint => '健康预警用于及时提醒，不作为医疗诊断；如有明显不适，请及时就医。';

  @override
  String get afterSalesService => '售后服务';

  @override
  String get afterSalesApplyHint => '请选择需要售后的商品，并填写原因和申请金额。提交后可在订单列表查看处理状态。';

  @override
  String get afterSalesAlreadySubmitted => '该商品已经提交售后申请，请等待商城工作人员处理。';

  @override
  String get afterSalesType => '售后类型';

  @override
  String get requestedAmount => '申请金额';

  @override
  String get afterSalesReason => '售后原因';

  @override
  String get describeProblem => '请说明遇到的问题';

  @override
  String get amountPaid => '实付款';

  @override
  String get orderDetailsLoadFailed => '订单详情加载失败，请稍后重试。';

  @override
  String get confirmItemReceived => '确认已经收到商品？';

  @override
  String get confirmReceiptHint => '确认收货后订单将完成。如尚未收到商品，请不要确认。';

  @override
  String get notConfirmYet => '暂不确认';

  @override
  String get unitChangesHint => '单位选择会立即生效。重新安装应用后可能需要再次设置。';

  @override
  String get goalSettingsTitle => '目标设置';

  @override
  String get dailyStepGoalField => '每日步数目标（步）';

  @override
  String get dailyDistanceGoalField => '每日距离目标（公里）';

  @override
  String get dailyCalorieGoalField => '每日热量目标（千卡）';

  @override
  String get saveGoals => '保存目标';

  @override
  String get viewAccountAddresses => '查看账号中的收货地址';

  @override
  String get loadingProfile => '正在读取个人资料…';

  @override
  String get profileSaveExplanation => '头像和个人资料会在点击保存后同步到账号，用于个人中心和远程关爱成员识别。';

  @override
  String get contactPhoneLabel => '联系电话';

  @override
  String get wechatOfficialAccount => '公众号';

  @override
  String get addSupportContact => '添加客服';

  @override
  String get contactPreparationHint => '联系前请准备设备型号和问题发生时间';

  @override
  String get supportPrivacyWarning => '请勿向非官方账号发送验证码、密码或完整健康记录。';

  @override
  String get brandHealthTitle => '赛电健康';

  @override
  String get accountAndSecurity => '账号与安全';

  @override
  String get cityNameLabel => '城市名称';

  @override
  String get cityNameExample => '例如：深圳';

  @override
  String get visitStoreHint => '去商城挑选适合您的健康设备吧';

  @override
  String get selectReportPlan => '选择报告方案';

  @override
  String get reportPaidContentHint => '明显异常提醒始终免费；付费内容为更完整的趋势整理与日常健康建议。';

  @override
  String get wechatPayLabel => '微信支付';

  @override
  String get alipayLabel => '支付宝';

  @override
  String get reportPurchaseTerms => '购买前请确认方案和价格。健康会员不会自动续费，未使用次数到期不结转。';

  @override
  String get detailedHealthReport => '详细健康报告';

  @override
  String get reportInsufficientDataHint => '数据不足时不会创建支付订单。请正常佩戴并同步手表数据后再试。';

  @override
  String get waitingPaymentConfirmation => '等待支付结果确认';

  @override
  String get paymentReturnRefreshHint => '支付完成后返回本页刷新，我们核实结果后会更新可用权益。';

  @override
  String get reportPurchaseDataMissing => '当前数据还不足，暂不提供购买入口。';

  @override
  String get heartRateUpperLimit => '心率上限';

  @override
  String get systolicUpperLimit => '收缩压上限';

  @override
  String get diastolicUpperLimit => '舒张压上限';

  @override
  String get temperatureUpperLimit => '体温上限';

  @override
  String get calibrateOnWatchHint => '根据手表提示完成校准';

  @override
  String get spotCheckCuffHint => '本次仅为静态监测，结果仅供参考，如需更加准确的数据，请通过手表气泵气囊式检测';

  @override
  String get setHealthUpperLimits => '设置健康数据上限提醒';

  @override
  String get healthUpperLimitHint => '超过设定值时提醒。';

  @override
  String get heartRateAlertLabel => '心率报警';

  @override
  String get heartRateAlertHint => '超过设定心率时提示';

  @override
  String get bloodPressureAlertLabel => '血压报警';

  @override
  String get bloodPressureAlertHint => '收缩压或舒张压超过设定值时提示';

  @override
  String get temperatureAlertLabel => '体温报警';

  @override
  String get temperatureAlertHint => '超过设定体温时提示';

  @override
  String get saveHealthAlerts => '保存预警设置';

  @override
  String get healthAlertHistory => '预警记录';

  @override
  String get seekProfessionalCare => '如有明显不适，请及时咨询专业医务人员';

  @override
  String get watchHealthReference => '手表测量结果用于日常健康管理参考。';

  @override
  String get calibrationReferenceHint => '请使用刚刚由专业设备测得的数值';

  @override
  String get calibrationWearerHint => '校准值只适用于当前佩戴者。更换佩戴者后，请关闭或重新校准。';

  @override
  String get enableCalibration => '启用校准';

  @override
  String get calibrationDisabledHint => '关闭后恢复手表公共测量模式';

  @override
  String get diastolicLowerLabel => '舒张压（低压）';

  @override
  String get longTermTrendHint => '查看长期趋势更有参考价值';

  @override
  String get measurementVariationHint => '单次测量可能受佩戴方式、运动和环境影响；如有不适，请咨询专业医务人员。';

  @override
  String get ecgDetailTitle => '心电详情';

  @override
  String get viewFullReport => '查看完整报告';

  @override
  String get ecgReferenceHint => '心电结果仅供健康管理参考';

  @override
  String get ecgVariationSafety => '单次测量会受到佩戴、运动和环境影响，不能代替医疗诊断。如有不适，请及时就医。';

  @override
  String get ecgBasicOnly => '本次仅返回基础心电数据';

  @override
  String get measurementIndicators => '测量指标';

  @override
  String get riskIndicatorsMissing => '本次手表未返回风险指标';

  @override
  String get riskAnalysisTitle => '风险分析';

  @override
  String get watchAlgorithmReference => '以下数值来自手表算法，仅作健康趋势参考。';

  @override
  String get ecgHealthReport => '心电健康报告';

  @override
  String get brandedEcgReport => '赛电 · 心电健康报告';

  @override
  String get ecgReportSafety => '说明：本报告由手表测量数据生成，仅供健康管理参考，不能替代医生诊断。';

  @override
  String get installedWatchFaces => '已安装表盘';

  @override
  String get switchInstalledWatchFace => '可切换手表内已有表盘';

  @override
  String get useSelectedWatchFace => '使用';

  @override
  String get downloadUseWatchFace => '点击下载并使用';

  @override
  String get photoWatchFaceHint => '选择一张清晰照片，预览无误后再传送到手表。';

  @override
  String get timeDisplayPosition => '时间显示位置';

  @override
  String get transferSetWatchFace => '传送并设为表盘';

  @override
  String get watchTransferKeepNear => '传送时请保持手表靠近手机，并避免切换到其他页面。';

  @override
  String get callMediaAudio => '通话与媒体声音';

  @override
  String get useCelsius => '使用摄氏度';

  @override
  String get sosContactHint => '手表触发 SOS 后，会优先联系这里选择的人。建议选择最常联系的家人。';

  @override
  String get noHealthAssessments => '当前手表没有可设置的辅助评估';

  @override
  String get modelFeaturesVary => '不同型号支持的项目可能不同，请以手表实际显示为准。';

  @override
  String get assessmentEnabledHint => '开启后由手表提供日常趋势参考';

  @override
  String get assessmentSafety => '辅助评估仅供日常健康管理参考，不用于诊断或治疗。';

  @override
  String get autoMonitorIntervalHint => '开启后由手表按设备设定周期自动检测';

  @override
  String get watchHeartRateAlert => '手表心率预警';

  @override
  String get sustainedLimitWatchAlert => '持续超过阈值时由手表提醒';

  @override
  String get ecgWaveformTitle => '心电波形';

  @override
  String get ecgWaveformMissing => '本次未返回有效心电波形';

  @override
  String get ecgElectrodeHint => '心率和 HRV 等结果仍可查看；下次测量时请持续接触手表电极。';

  @override
  String get screenAutoTimeHint => '由手表根据时间自动调节';

  @override
  String get raiseWristScreenHint => '抬起手腕时自动点亮屏幕';

  @override
  String get watchHighHeartRate => '心率过高预警';

  @override
  String get watchThresholdHint => '达到阈值后由手表提醒';

  @override
  String get watchMeasurementSafety => '测量结果仅供健康管理参考，不用于诊断或治疗。';

  @override
  String get healthDataExplanation => '健康数据说明';

  @override
  String get trendUnavailable => '趋势暂不可用';

  @override
  String get recentData => '近期数据';

  @override
  String get trendReferenceOnly => '趋势仅作日常健康参考';

  @override
  String get trendVariationSafety => '单次和阶段变化可能受佩戴、运动及环境影响，不替代医疗诊断。';

  @override
  String get watchFaceDownloadHint => '下载后会传送到手表。传送期间请保持手表靠近手机，不要离开当前页面。';

  @override
  String get refreshWatchFaces => '刷新手表表盘';

  @override
  String get openTestFlight => '打开 TestFlight';

  @override
  String get articlesEmpty => '该分类暂无百科内容';

  @override
  String get articlesUnavailable => '健康百科加载失败';

  @override
  String get articleContentUnavailable => '文章详情暂未返回正文内容。';

  @override
  String get imageUnavailable => '图片暂时无法加载';

  @override
  String get allowNotifications => '允许通知';

  @override
  String get updateNow => '立即更新';

  @override
  String get analysisConsentUnavailable => '健康分析暂时无法使用，已有报告仍可查看。';

  @override
  String get analysisReadAgree => '我已阅读并同意上述健康分析说明';

  @override
  String get agreeContinue => '同意并继续';

  @override
  String get notGrantNow => '暂不授权';

  @override
  String get analysisConsentSaved => '健康分析授权已保存';

  @override
  String get withdrawAnalysisConsent => '撤回健康分析授权？';

  @override
  String get withdrawAnalysisExplanation => '撤回后不会再生成新的详细报告，已经生成且未退款的报告仍可查看。';

  @override
  String get confirmWithdraw => '确认撤回';

  @override
  String get analysisConsentWithdrawn => '健康分析授权已撤回';

  @override
  String get consentGrantedHint => '已授权，可随时撤回';

  @override
  String get consentNeededHint => '生成详细报告前需要单独授权';

  @override
  String get withdraw => '撤回';

  @override
  String get reportHistory => '历史报告';

  @override
  String get saving => '正在保存';

  @override
  String get pauseWorkout => '暂停运动';

  @override
  String get resumeWorkout => '继续运动';

  @override
  String get finishWorkout => '结束运动';

  @override
  String get watchDistance => '手表距离';

  @override
  String get watchSteps => '手表步数';

  @override
  String get liveHeartRate => '实时心率';

  @override
  String get watchCalories => '手表热量';

  @override
  String get connectForWorkout => '请先在设备页连接手表，运动模式将由手表记录。';

  @override
  String latestVersion(String version) {
    return '当前已是最新版本 V$version';
  }

  @override
  String workoutPaused(String mode) {
    return '$mode已暂停';
  }

  @override
  String workoutInProgress(String mode) {
    return '$mode进行中';
  }

  @override
  String workoutReady(String mode) {
    return '准备开始$mode';
  }

  @override
  String startWorkout(String mode) {
    return '开始$mode';
  }

  @override
  String finishOtherWorkout(String mode) {
    return '请先结束$mode';
  }

  @override
  String workoutDetails(String mode) {
    return '$mode详情';
  }

  @override
  String stepCount(int count) {
    return '$count 步';
  }

  @override
  String get globalShopPricePending => '价格待确认';

  @override
  String get globalShopLoadMore => '加载更多商品';

  @override
  String get globalShopReadOnly => '可浏览商品，当前地区暂未开放下单。';

  @override
  String get appName => 'Saydian';

  @override
  String get searchingNearby => '正在搜索附近手表';

  @override
  String get noDevices => '未发现设备';

  @override
  String get selectWatch => '请核对名称和信号强度，再选择手表';

  @override
  String get searchingHint => '正在搜索，信号会更新，列表位置不会变化';

  @override
  String get activateWatch => '请取出设备、充电激活，并将手表靠近手机';

  @override
  String get checkWatchConnection => '若手表已连到本机系统蓝牙或其他手机，请先断开后重新搜索';

  @override
  String get running => '跑步';

  @override
  String get walking => '步行';

  @override
  String get cycling => '骑行';

  @override
  String get hiking => '徒步';

  @override
  String get mountaineering => '登山';

  @override
  String metricAnalysis(String metric) {
    return '$metric分析';
  }

  @override
  String metricAllData(String metric) {
    return '$metric全部数据';
  }

  @override
  String metricMeasurement(String metric) {
    return '$metric测量';
  }

  @override
  String metricCalibration(String metric) {
    return '$metric校准';
  }

  @override
  String metricDetails(String metric) {
    return '$metric详情';
  }

  @override
  String get add => '添加';

  @override
  String get endTime => '结束时间';

  @override
  String get reminderInterval => '提醒间隔';

  @override
  String get reminderName => '提醒名称';

  @override
  String get repeat => '重复';

  @override
  String get addAlarm => '添加闹钟';

  @override
  String get alarmTime => '提醒时间';

  @override
  String get enableAlarm => '启用闹钟';

  @override
  String get emergencyContact => 'SOS 紧急联系人';

  @override
  String get selectEmergencyContact => '选择 SOS 紧急联系人';

  @override
  String get confirmEmergencyContact => '确认设为 SOS 联系人';

  @override
  String get addWorldClock => '添加世界时钟';

  @override
  String get autoBrightness => '自动调节亮度';

  @override
  String get raiseToWake => '抬腕亮屏';

  @override
  String get activeTime => '生效时间';

  @override
  String get saveSettings => '保存设置';

  @override
  String get helpFeedback => '帮助与反馈';

  @override
  String get issueType => '问题类型';

  @override
  String get issueDescription => '问题说明';

  @override
  String get describeIssue => '请描述遇到的问题和出现步骤';

  @override
  String get contactOptional => '联系方式（选填）';

  @override
  String get phoneOrEmail => '手机号或邮箱';

  @override
  String get call => '拨打电话';

  @override
  String get addContact => '添加联系人';

  @override
  String get contactName => '姓名';

  @override
  String get contactPhone => '电话号码';

  @override
  String get cart => '购物车';

  @override
  String get searchProducts => '搜索商品';

  @override
  String get selectVariant => '请选择规格';

  @override
  String get variant => '规格';

  @override
  String get buyNow => '立即购买';

  @override
  String get cartEmpty => '购物车还是空的';

  @override
  String get returnShop => '返回商城';

  @override
  String get selectAll => '全选';

  @override
  String get checkout => '去结算';

  @override
  String get clearCart => '清空购物车？';

  @override
  String get clearCartHint => '已加入的商品将全部移除。';

  @override
  String get viewOrder => '查看订单';

  @override
  String get confirmOrder => '确认订单';

  @override
  String get productInfo => '商品信息';

  @override
  String get orderNote => '留言';

  @override
  String get noteToSeller => '给商家留言';

  @override
  String get paymentCheckout => '支付收银台';

  @override
  String get orderTotal => '订单总额';

  @override
  String get selectPayment => '选择支付方式';

  @override
  String get refreshOrder => '刷新订单状态';

  @override
  String get viewMyOrders => '查看我的订单';

  @override
  String get backToProduct => '返回商品详情';

  @override
  String get newAddress => '新增地址';

  @override
  String get recipient => '收货人';

  @override
  String get province => '省/自治区';

  @override
  String get district => '区/县';

  @override
  String get streetAddress => '详细地址';

  @override
  String get defaultAddress => '设为默认地址';

  @override
  String get shippingInfo => '物流信息';

  @override
  String get restorePurchases => '恢复购买';

  @override
  String get paymentMethod => '支付方式';

  @override
  String get refresh => '刷新';

  @override
  String get useWatchFace => '使用这个表盘？';

  @override
  String get downloadAndUse => '下载并使用';

  @override
  String get watchFaceFailed => '表盘未设置成功';

  @override
  String get statusNormal => '正常';

  @override
  String get statusRecorded => '已记录';

  @override
  String get statusAttention => '请关注';

  @override
  String get statusOutOfRange => '超出参考范围';

  @override
  String get statusLow => '偏低';

  @override
  String get statusHigh => '偏高';

  @override
  String get careInviteHint => '通过邮箱或国际手机号邀请国际版Saydian账号。';

  @override
  String get careSharingHint => '仅共享您选择的测量项目，可随时停止共享。';

  @override
  String get carePending => '待处理';

  @override
  String get careActive => '已生效';

  @override
  String get careClosed => '已结束';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒绝';

  @override
  String get stopSharing => '停止共享';

  @override
  String get sharedMeasurements => '共享测量项目';

  @override
  String get invitationSent => '邀请已发送';

  @override
  String get invalidCareContact => '请输入邮箱或带国家区号的手机号。';

  @override
  String get carePermissionDenied => '对方尚未与您共享此测量项目。';

  @override
  String get reload => '重新加载';

  @override
  String get applyAfterSales => '申请售后';

  @override
  String get analysisConsent => '健康分析授权';

  @override
  String get workoutRecords => '运动记录';

  @override
  String get startTime => '开始时间';

  @override
  String get addCare => '添加关爱';

  @override
  String get confirmReceipt => '确认收货';

  @override
  String get personalInfo => '个人资料';

  @override
  String get deliveryAddresses => '收货地址';

  @override
  String get readAgain => '重新读取';

  @override
  String get smsCode => '短信验证码';

  @override
  String get watchFaceShop => '表盘商城';

  @override
  String get selectCity => '选择城市';

  @override
  String get city => '城市';

  @override
  String get confirm => '确定';

  @override
  String get productDetails => '商品详情';

  @override
  String get clear => '清空';

  @override
  String get settings => '设置';

  @override
  String get goals => '目标';

  @override
  String get send => '发送';

  @override
  String get typeMessage => '请输入消息…';

  @override
  String get devicesFound => '已发现设备';

  @override
  String get connect => '连接';

  @override
  String get searchAgain => '重新搜索';

  @override
  String get searchRecovery => '请让手表靠近手机；若已连接本机系统蓝牙或其他手机，请先断开再重试。';

  @override
  String get deviceName => '设备名称';

  @override
  String get deviceModel => '设备型号';

  @override
  String get connectionStatus => '连接状态';

  @override
  String get firmwareVersion => '固件版本';

  @override
  String get watchBattery => '手表电量';

  @override
  String get chargingStatus => '充电状态';

  @override
  String get messageDetails => '消息详情';

  @override
  String get dailySummary => '当日摘要';

  @override
  String get remoteMemberData => '远程成员数据';

  @override
  String get ecgWaveformUnavailable => '暂无可用心电波形';

  @override
  String get orderDetails => '订单详情';

  @override
  String get viewShipping => '查看物流';

  @override
  String get measureAgain => '重新测量';

  @override
  String get checkPaymentStatus => '查看支付状态';

  @override
  String get deleteAccount => '注销账号';

  @override
  String get confirmDeleteAccountTitle => '确认注销账号？';

  @override
  String get deleteAccountHint => '账号及相关数据删除成功后，本机会退出登录。';

  @override
  String get confirmDelete => '确认注销';

  @override
  String get exit => '退出';

  @override
  String get nickname => '昵称';

  @override
  String get gender => '性别';

  @override
  String get birthDate => '出生日期';

  @override
  String get heightCm => '身高（cm）';

  @override
  String get weightKg => '体重（kg）';

  @override
  String get choose => '请选择';

  @override
  String get connectWatchToUse => '连接手表后使用';

  @override
  String get selectPhoto => '选择照片';

  @override
  String get saved => '已保存';

  @override
  String get saveChanges => '保存修改';

  @override
  String get notificationsOff => '系统通知未开启';

  @override
  String get privacyAgreement => '隐私协议';

  @override
  String get appPermissions => 'App 系统权限';

  @override
  String get openSystemSettings => '打开系统应用设置';

  @override
  String get monitoringHint => '连接后会显示当前手表可设置的健康检测项目。';

  @override
  String get previewUnavailable => '预览暂不可用';

  @override
  String get distance => '距离';

  @override
  String get calories => '热量';

  @override
  String get healthProfile => '健康档案';

  @override
  String get photoWatchFace => '照片表盘';

  @override
  String get cameraRemote => '相机遥控';

  @override
  String get phoneCalls => '电话';

  @override
  String get contacts => '联系人';

  @override
  String get notifications => '消息通知';

  @override
  String get alarms => '闹钟';

  @override
  String get weather => '天气';

  @override
  String get worldClock => '世界时钟';

  @override
  String get healthReminders => '健康提醒';

  @override
  String get healthMonitoring => '健康监测';

  @override
  String get healthAssessment => '辅助评估';

  @override
  String get screenDisplay => '屏幕显示';

  @override
  String get scanning => '正在搜索';

  @override
  String get connecting => '连接中';

  @override
  String get waitingConfirmation => '等待确认';

  @override
  String get syncing => '正在同步';

  @override
  String get measuring => '测量中';

  @override
  String get needsAttention => '需要处理';

  @override
  String get tapToOpen => '点击进入';

  @override
  String get deviceInfoHint => '查看设备信息';

  @override
  String get connectionInstructions =>
      '1. 打开手机蓝牙并允许查找附近设备。\n2. 将手表充电激活，并放在手机旁边。\n3. 点击“开始查找”，选择自己的手表。\n4. 如果手表弹出确认，请及时确认。';

  @override
  String get syncNearbyHint => '连接或同步时，请让手表保持电量充足并靠近手机。';

  @override
  String get invalidCode => '请检查验证码后重试';

  @override
  String get codeExpired => '验证码已过期，请重新获取';

  @override
  String get tooManyAttempts => '操作过于频繁，请稍后重试';

  @override
  String get readTerms => '请阅读用户协议和隐私政策后继续';

  @override
  String verificationSentTo(String contact) {
    return '验证码已发送至 $contact';
  }

  @override
  String get addSmartDevice => '添加智能设备';

  @override
  String get watchNearbyHint => '请开启手机蓝牙并将手表靠近手机';

  @override
  String get startSearch => '开始查找';

  @override
  String get readingData => '正在读取数据';

  @override
  String get readingCapabilities => '正在识别手表功能…';

  @override
  String get capabilitiesHint => '识别完成后只显示当前手表可用的功能';

  @override
  String get capabilitiesFailed => '暂时无法读取此手表的功能';

  @override
  String get keepWatchNear => '请保持手表靠近手机后重试';

  @override
  String get personalizeWatch => '表盘与个性化';

  @override
  String get signInCloudHint => '登录后开启云端健康服务';

  @override
  String get aiQuestion => 'AI提问';

  @override
  String get aiQuestionHint => '向 AI 健康管家咨询健康问题';

  @override
  String get language => '语言';

  @override
  String get signIn => '登录';

  @override
  String get signUp => '注册';

  @override
  String get signOut => '退出登录';

  @override
  String get email => '邮箱';

  @override
  String get phoneNumber => '手机号';

  @override
  String get countryRegion => '国家或地区';

  @override
  String get password => '密码';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get verificationCode => '验证码';

  @override
  String get sendCode => '获取验证码';

  @override
  String get forgotPassword => '忘记密码？';

  @override
  String get resetPassword => '重置密码';

  @override
  String get createAccount => '创建账号';

  @override
  String get continueAction => '继续';

  @override
  String get back => '返回';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get retry => '重试';

  @override
  String get loading => '加载中…';

  @override
  String get pleaseWait => '请稍候…';

  @override
  String get emailOrPhone => '邮箱或手机号';

  @override
  String get enterEmail => '请输入邮箱地址';

  @override
  String get enterPhone => '请输入手机号';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get passwordRequirement => '至少8个字符；英文字母和数字最多72个，其他字符可用长度更短。';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get invalidEmail => '请输入有效的邮箱地址';

  @override
  String get invalidPhone => '请检查国家区号和手机号';

  @override
  String get codeSent => '验证码已发送，请查收';

  @override
  String get codeRequired => '请输入验证码';

  @override
  String get consentRequired => '请先阅读并同意用户协议和隐私政策';

  @override
  String get agreeToTerms => '我已阅读并同意';

  @override
  String get termsOfService => '用户协议';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get registrationUnavailable => '注册暂时无法使用，请稍后再试';

  @override
  String get loginFailed => '登录失败，请检查账号信息后重试';

  @override
  String get accountAlreadyExists => '此账号已注册，请直接登录';

  @override
  String get networkUnavailable => '网络不可用，请检查后重试';

  @override
  String get serviceUnavailable => '此功能暂时无法使用，请稍后再试';

  @override
  String get accountCreated => '账号已创建';

  @override
  String get passwordReset => '密码已更新';

  @override
  String get haveAccount => '已有账号？';

  @override
  String get noAccount => '还没有账号？';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get selectCountry => '选择国家或地区';

  @override
  String get registrationMethod => '注册方式';

  @override
  String get changeLanguageFailed => '语言保存失败，请重试';

  @override
  String get health => '健康';

  @override
  String get device => '设备';

  @override
  String get profile => '我的';

  @override
  String get healthData => '健康数据';

  @override
  String get allData => '全部数据';

  @override
  String get healthRecords => '健康记录';

  @override
  String get workoutsAndRecords => '运动与记录';

  @override
  String get healthDisclaimer => '测量结果仅供健康管理参考，如有不适请咨询专业医务人员。';

  @override
  String get healthSafetyAdvice => '请休息后复测；如有明显不适，请及时咨询医务人员。';

  @override
  String get defaultUser => '赛电用户';

  @override
  String get dailyGreeting => '今天也要保持好状态';

  @override
  String get messages => '消息';

  @override
  String get aiAssistant => 'AI健康管家';

  @override
  String get aiAssistantIntro => '我是您的健康管家，\n有任何健康问题都可以向我提问。';

  @override
  String get askNow => '马上提问';

  @override
  String get remoteCare => '远程关爱';

  @override
  String get healthLibrary => '健康百科';

  @override
  String get healthAlerts => '健康预警';

  @override
  String get shop => '赛电商城';

  @override
  String get connectWatch => '连接手表';

  @override
  String get addDevice => '添加设备';

  @override
  String get connectWatchForData => '连接手表后可查看支持的健康数据';

  @override
  String get noHealthData => '暂无可显示的健康数据';

  @override
  String get noData => '暂无数据';

  @override
  String get connected => '已连接';

  @override
  String get notConnected => '未连接';

  @override
  String get online => '在线';

  @override
  String get syncData => '同步数据';

  @override
  String get syncComplete => '数据同步完成';

  @override
  String get syncFailedTryAgain => '数据同步失败，请将手表靠近手机后重试';

  @override
  String get disconnect => '断开连接';

  @override
  String get findWatch => '查找手表';

  @override
  String get watchFaces => '表盘';

  @override
  String get deviceFeatures => '设备功能';

  @override
  String get aboutDevice => '关于设备';

  @override
  String get connectionHelp => '连接说明';

  @override
  String get searchNearbyWatch => '搜索并连接附近的赛电手表';

  @override
  String get useWatch => '请在手表上操作';

  @override
  String get myOrders => '我的订单';

  @override
  String get all => '全部';

  @override
  String get awaitingPayment => '待支付';

  @override
  String get awaitingShipment => '待发货';

  @override
  String get awaitingDelivery => '待收货';

  @override
  String get afterSales => '售后';

  @override
  String get careMembers => '关爱成员';

  @override
  String get unitSettings => '单位设置';

  @override
  String get unitSettingsHint => '设置距离、温度等数据单位';

  @override
  String get myServices => '我的服务';

  @override
  String get accountSettings => '账号设置';

  @override
  String get editProfile => '完善资料';

  @override
  String get permissions => '权限管理';

  @override
  String get feedback => '意见反馈';

  @override
  String get customerService => '联系客服';

  @override
  String get aboutApp => '关于我们';

  @override
  String get security => '账号安全';

  @override
  String get goToSettings => '去设置';

  @override
  String get close => '关闭';

  @override
  String get view => '查看';

  @override
  String get checkUpdates => '检查更新';

  @override
  String get onlineUpdate => '在线更新';

  @override
  String get updateRequired => '需要更新后继续使用';

  @override
  String get updateReady => '新版本已准备好';

  @override
  String get preparingUpdate => '正在准备安全更新…';

  @override
  String get openingUpdate => '正在打开系统更新页面…';

  @override
  String get updateAppStore => '前往 App Store 更新';

  @override
  String get updateStore => '前往应用商店更新';

  @override
  String get downloadAndInstall => '安全下载并安装';

  @override
  String get gettingReady => '正在为你准备…';

  @override
  String get enableNotifications => '开启赛电消息通知';

  @override
  String get notificationExplanation =>
      '用于提醒新的健康预警和关爱邀请。锁屏上不会显示具体健康数值，可随时在系统设置中关闭。';

  @override
  String get notNow => '暂不开启';

  @override
  String get enable => '开启';

  @override
  String get newCareRequest => '收到新的关爱请求';

  @override
  String get dismissHealthAlert => '关闭健康预警';

  @override
  String get dismissCareAlert => '关闭关爱提醒';

  @override
  String get bloodPressure => '血压';

  @override
  String get heartRate => '心率';

  @override
  String get bloodOxygen => '血氧';

  @override
  String get bloodGlucose => '血糖';

  @override
  String get bodyTemperature => '体温';

  @override
  String get ecg => '心电';

  @override
  String get hrv => 'HRV';

  @override
  String get bodyComposition => '身体成分';

  @override
  String get bloodComposition => '血液成分';

  @override
  String get sleep => '睡眠';

  @override
  String get steps => '步数';

  @override
  String get workouts => '运动';

  @override
  String welcome(String name) {
    return '你好，$name';
  }

  @override
  String resendCode(int seconds) {
    return '$seconds秒后重发';
  }

  @override
  String memberId(String id) {
    return '会员 ID：$id';
  }

  @override
  String unreadMessages(int count) {
    return '消息，$count 条未读';
  }

  @override
  String recordCount(int count) {
    return '$count 条';
  }

  @override
  String memberCount(int count) {
    return '$count 人';
  }

  @override
  String versionBuild(String version, int build) {
    return 'V$version · 构建 $build';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get scanLocationTitle => '请开启手机定位';

  @override
  String get scanLocationHint => '请在设置中开启手机定位，再返回此页面查找附近的手表。';

  @override
  String get scanPermissionTitle => '请允许相关权限';

  @override
  String get scanPermissionHint => '请在设置中允许相关权限，再返回此页面查找手表。';

  @override
  String get loginProtectionTitle => '登录保护';

  @override
  String get verifyContactToReset => '验证邮箱或手机号后重新设置密码';

  @override
  String get workoutStartOnWatch => '当前手表未开放由 APP 启动的运动模式，请直接在手表上开始运动。';

  @override
  String get finishWorkoutConfirm => '结束当前运动？';

  @override
  String get finishLeaveWorkoutHint => '离开前将先停止手表运动，并保存已记录的运动时长和轨迹。';

  @override
  String get finishAndLeave => '结束并离开';

  @override
  String get workoutRouteMissing => '该记录没有手机前台轨迹，仍保留手表运动数据。';

  @override
  String get workoutDuration => '运动时长';

  @override
  String get workoutWatchHeartRate => '手表心率';

  @override
  String get messageSendFailed => '发送失败，请检查网络后重试';

  @override
  String get noWatchShopHint => '没有设备？去赛电商城看看';

  @override
  String get notificationInAppHint => '应用内红点和消息仍可使用，开启后可及时收到关爱邀请与健康预警。';

  @override
  String get healthAlertSafetyHint => '健康预警用于及时提醒，不作为医疗诊断；如有明显不适，请及时就医。';

  @override
  String get afterSalesService => '售后服务';

  @override
  String get afterSalesApplyHint => '请选择需要售后的商品，并填写原因和申请金额。提交后可在订单列表查看处理状态。';

  @override
  String get afterSalesAlreadySubmitted => '该商品已经提交售后申请，请等待商城工作人员处理。';

  @override
  String get afterSalesType => '售后类型';

  @override
  String get requestedAmount => '申请金额';

  @override
  String get afterSalesReason => '售后原因';

  @override
  String get describeProblem => '请说明遇到的问题';

  @override
  String get amountPaid => '实付款';

  @override
  String get orderDetailsLoadFailed => '订单详情加载失败，请稍后重试。';

  @override
  String get confirmItemReceived => '确认已经收到商品？';

  @override
  String get confirmReceiptHint => '确认收货后订单将完成。如尚未收到商品，请不要确认。';

  @override
  String get notConfirmYet => '暂不确认';

  @override
  String get unitChangesHint => '单位选择会立即生效。重新安装应用后可能需要再次设置。';

  @override
  String get goalSettingsTitle => '目标设置';

  @override
  String get dailyStepGoalField => '每日步数目标（步）';

  @override
  String get dailyDistanceGoalField => '每日距离目标（公里）';

  @override
  String get dailyCalorieGoalField => '每日热量目标（千卡）';

  @override
  String get saveGoals => '保存目标';

  @override
  String get viewAccountAddresses => '查看账号中的收货地址';

  @override
  String get loadingProfile => '正在读取个人资料…';

  @override
  String get profileSaveExplanation => '头像和个人资料会在点击保存后同步到账号，用于个人中心和远程关爱成员识别。';

  @override
  String get contactPhoneLabel => '联系电话';

  @override
  String get wechatOfficialAccount => '公众号';

  @override
  String get addSupportContact => '添加客服';

  @override
  String get contactPreparationHint => '联系前请准备设备型号和问题发生时间';

  @override
  String get supportPrivacyWarning => '请勿向非官方账号发送验证码、密码或完整健康记录。';

  @override
  String get brandHealthTitle => '赛电健康';

  @override
  String get accountAndSecurity => '账号与安全';

  @override
  String get cityNameLabel => '城市名称';

  @override
  String get cityNameExample => '例如：深圳';

  @override
  String get visitStoreHint => '去商城挑选适合您的健康设备吧';

  @override
  String get selectReportPlan => '选择报告方案';

  @override
  String get reportPaidContentHint => '明显异常提醒始终免费；付费内容为更完整的趋势整理与日常健康建议。';

  @override
  String get wechatPayLabel => '微信支付';

  @override
  String get alipayLabel => '支付宝';

  @override
  String get reportPurchaseTerms => '购买前请确认方案和价格。健康会员不会自动续费，未使用次数到期不结转。';

  @override
  String get detailedHealthReport => '详细健康报告';

  @override
  String get reportInsufficientDataHint => '数据不足时不会创建支付订单。请正常佩戴并同步手表数据后再试。';

  @override
  String get waitingPaymentConfirmation => '等待支付结果确认';

  @override
  String get paymentReturnRefreshHint => '支付完成后返回本页刷新，我们核实结果后会更新可用权益。';

  @override
  String get reportPurchaseDataMissing => '当前数据还不足，暂不提供购买入口。';

  @override
  String get heartRateUpperLimit => '心率上限';

  @override
  String get systolicUpperLimit => '收缩压上限';

  @override
  String get diastolicUpperLimit => '舒张压上限';

  @override
  String get temperatureUpperLimit => '体温上限';

  @override
  String get calibrateOnWatchHint => '根据手表提示完成校准';

  @override
  String get spotCheckCuffHint => '本次仅为静态监测，结果仅供参考，如需更加准确的数据，请通过手表气泵气囊式检测';

  @override
  String get setHealthUpperLimits => '设置健康数据上限提醒';

  @override
  String get healthUpperLimitHint => '超过设定值时提醒。';

  @override
  String get heartRateAlertLabel => '心率报警';

  @override
  String get heartRateAlertHint => '超过设定心率时提示';

  @override
  String get bloodPressureAlertLabel => '血压报警';

  @override
  String get bloodPressureAlertHint => '收缩压或舒张压超过设定值时提示';

  @override
  String get temperatureAlertLabel => '体温报警';

  @override
  String get temperatureAlertHint => '超过设定体温时提示';

  @override
  String get saveHealthAlerts => '保存预警设置';

  @override
  String get healthAlertHistory => '预警记录';

  @override
  String get seekProfessionalCare => '如有明显不适，请及时咨询专业医务人员';

  @override
  String get watchHealthReference => '手表测量结果用于日常健康管理参考。';

  @override
  String get calibrationReferenceHint => '请使用刚刚由专业设备测得的数值';

  @override
  String get calibrationWearerHint => '校准值只适用于当前佩戴者。更换佩戴者后，请关闭或重新校准。';

  @override
  String get enableCalibration => '启用校准';

  @override
  String get calibrationDisabledHint => '关闭后恢复手表公共测量模式';

  @override
  String get diastolicLowerLabel => '舒张压（低压）';

  @override
  String get longTermTrendHint => '查看长期趋势更有参考价值';

  @override
  String get measurementVariationHint => '单次测量可能受佩戴方式、运动和环境影响；如有不适，请咨询专业医务人员。';

  @override
  String get ecgDetailTitle => '心电详情';

  @override
  String get viewFullReport => '查看完整报告';

  @override
  String get ecgReferenceHint => '心电结果仅供健康管理参考';

  @override
  String get ecgVariationSafety => '单次测量会受到佩戴、运动和环境影响，不能代替医疗诊断。如有不适，请及时就医。';

  @override
  String get ecgBasicOnly => '本次仅返回基础心电数据';

  @override
  String get measurementIndicators => '测量指标';

  @override
  String get riskIndicatorsMissing => '本次手表未返回风险指标';

  @override
  String get riskAnalysisTitle => '风险分析';

  @override
  String get watchAlgorithmReference => '以下数值来自手表算法，仅作健康趋势参考。';

  @override
  String get ecgHealthReport => '心电健康报告';

  @override
  String get brandedEcgReport => '赛电 · 心电健康报告';

  @override
  String get ecgReportSafety => '说明：本报告由手表测量数据生成，仅供健康管理参考，不能替代医生诊断。';

  @override
  String get installedWatchFaces => '已安装表盘';

  @override
  String get switchInstalledWatchFace => '可切换手表内已有表盘';

  @override
  String get useSelectedWatchFace => '使用';

  @override
  String get downloadUseWatchFace => '点击下载并使用';

  @override
  String get photoWatchFaceHint => '选择一张清晰照片，预览无误后再传送到手表。';

  @override
  String get timeDisplayPosition => '时间显示位置';

  @override
  String get transferSetWatchFace => '传送并设为表盘';

  @override
  String get watchTransferKeepNear => '传送时请保持手表靠近手机，并避免切换到其他页面。';

  @override
  String get callMediaAudio => '通话与媒体声音';

  @override
  String get useCelsius => '使用摄氏度';

  @override
  String get sosContactHint => '手表触发 SOS 后，会优先联系这里选择的人。建议选择最常联系的家人。';

  @override
  String get noHealthAssessments => '当前手表没有可设置的辅助评估';

  @override
  String get modelFeaturesVary => '不同型号支持的项目可能不同，请以手表实际显示为准。';

  @override
  String get assessmentEnabledHint => '开启后由手表提供日常趋势参考';

  @override
  String get assessmentSafety => '辅助评估仅供日常健康管理参考，不用于诊断或治疗。';

  @override
  String get autoMonitorIntervalHint => '开启后由手表按设备设定周期自动检测';

  @override
  String get watchHeartRateAlert => '手表心率预警';

  @override
  String get sustainedLimitWatchAlert => '持续超过阈值时由手表提醒';

  @override
  String get ecgWaveformTitle => '心电波形';

  @override
  String get ecgWaveformMissing => '本次未返回有效心电波形';

  @override
  String get ecgElectrodeHint => '心率和 HRV 等结果仍可查看；下次测量时请持续接触手表电极。';

  @override
  String get screenAutoTimeHint => '由手表根据时间自动调节';

  @override
  String get raiseWristScreenHint => '抬起手腕时自动点亮屏幕';

  @override
  String get watchHighHeartRate => '心率过高预警';

  @override
  String get watchThresholdHint => '达到阈值后由手表提醒';

  @override
  String get watchMeasurementSafety => '测量结果仅供健康管理参考，不用于诊断或治疗。';

  @override
  String get healthDataExplanation => '健康数据说明';

  @override
  String get trendUnavailable => '趋势暂不可用';

  @override
  String get recentData => '近期数据';

  @override
  String get trendReferenceOnly => '趋势仅作日常健康参考';

  @override
  String get trendVariationSafety => '单次和阶段变化可能受佩戴、运动及环境影响，不替代医疗诊断。';

  @override
  String get watchFaceDownloadHint => '下载后会传送到手表。传送期间请保持手表靠近手机，不要离开当前页面。';

  @override
  String get refreshWatchFaces => '刷新手表表盘';

  @override
  String get openTestFlight => '打开 TestFlight';

  @override
  String get articlesEmpty => '该分类暂无百科内容';

  @override
  String get articlesUnavailable => '健康百科加载失败';

  @override
  String get articleContentUnavailable => '文章详情暂未返回正文内容。';

  @override
  String get imageUnavailable => '图片暂时无法加载';

  @override
  String get allowNotifications => '允许通知';

  @override
  String get updateNow => '立即更新';

  @override
  String get analysisConsentUnavailable => '健康分析暂时无法使用，已有报告仍可查看。';

  @override
  String get analysisReadAgree => '我已阅读并同意上述健康分析说明';

  @override
  String get agreeContinue => '同意并继续';

  @override
  String get notGrantNow => '暂不授权';

  @override
  String get analysisConsentSaved => '健康分析授权已保存';

  @override
  String get withdrawAnalysisConsent => '撤回健康分析授权？';

  @override
  String get withdrawAnalysisExplanation => '撤回后不会再生成新的详细报告，已经生成且未退款的报告仍可查看。';

  @override
  String get confirmWithdraw => '确认撤回';

  @override
  String get analysisConsentWithdrawn => '健康分析授权已撤回';

  @override
  String get consentGrantedHint => '已授权，可随时撤回';

  @override
  String get consentNeededHint => '生成详细报告前需要单独授权';

  @override
  String get withdraw => '撤回';

  @override
  String get reportHistory => '历史报告';

  @override
  String get saving => '正在保存';

  @override
  String get pauseWorkout => '暂停运动';

  @override
  String get resumeWorkout => '继续运动';

  @override
  String get finishWorkout => '结束运动';

  @override
  String get watchDistance => '手表距离';

  @override
  String get watchSteps => '手表步数';

  @override
  String get liveHeartRate => '实时心率';

  @override
  String get watchCalories => '手表热量';

  @override
  String get connectForWorkout => '请先在设备页连接手表，运动模式将由手表记录。';

  @override
  String latestVersion(String version) {
    return '当前已是最新版本 V$version';
  }

  @override
  String workoutPaused(String mode) {
    return '$mode已暂停';
  }

  @override
  String workoutInProgress(String mode) {
    return '$mode进行中';
  }

  @override
  String workoutReady(String mode) {
    return '准备开始$mode';
  }

  @override
  String startWorkout(String mode) {
    return '开始$mode';
  }

  @override
  String finishOtherWorkout(String mode) {
    return '请先结束$mode';
  }

  @override
  String workoutDetails(String mode) {
    return '$mode详情';
  }

  @override
  String stepCount(int count) {
    return '$count 步';
  }

  @override
  String get globalShopPricePending => '价格待确认';

  @override
  String get globalShopLoadMore => '加载更多商品';

  @override
  String get globalShopReadOnly => '可浏览商品，当前地区暂未开放下单。';

  @override
  String get appName => 'Saydian';

  @override
  String get searchingNearby => '正在搜索附近手表';

  @override
  String get noDevices => '未发现设备';

  @override
  String get selectWatch => '请核对名称和信号强度，再选择手表';

  @override
  String get searchingHint => '正在搜索，信号会更新，列表位置不会变化';

  @override
  String get activateWatch => '请取出设备、充电激活，并将手表靠近手机';

  @override
  String get checkWatchConnection => '若手表已连到本机系统蓝牙或其他手机，请先断开后重新搜索';

  @override
  String get running => '跑步';

  @override
  String get walking => '步行';

  @override
  String get cycling => '骑行';

  @override
  String get hiking => '徒步';

  @override
  String get mountaineering => '登山';

  @override
  String metricAnalysis(String metric) {
    return '$metric分析';
  }

  @override
  String metricAllData(String metric) {
    return '$metric全部数据';
  }

  @override
  String metricMeasurement(String metric) {
    return '$metric测量';
  }

  @override
  String metricCalibration(String metric) {
    return '$metric校准';
  }

  @override
  String metricDetails(String metric) {
    return '$metric详情';
  }

  @override
  String get add => '添加';

  @override
  String get endTime => '结束时间';

  @override
  String get reminderInterval => '提醒间隔';

  @override
  String get reminderName => '提醒名称';

  @override
  String get repeat => '重复';

  @override
  String get addAlarm => '添加闹钟';

  @override
  String get alarmTime => '提醒时间';

  @override
  String get enableAlarm => '启用闹钟';

  @override
  String get emergencyContact => 'SOS 紧急联系人';

  @override
  String get selectEmergencyContact => '选择 SOS 紧急联系人';

  @override
  String get confirmEmergencyContact => '确认设为 SOS 联系人';

  @override
  String get addWorldClock => '添加世界时钟';

  @override
  String get autoBrightness => '自动调节亮度';

  @override
  String get raiseToWake => '抬腕亮屏';

  @override
  String get activeTime => '生效时间';

  @override
  String get saveSettings => '保存设置';

  @override
  String get helpFeedback => '帮助与反馈';

  @override
  String get issueType => '问题类型';

  @override
  String get issueDescription => '问题说明';

  @override
  String get describeIssue => '请描述遇到的问题和出现步骤';

  @override
  String get contactOptional => '联系方式（选填）';

  @override
  String get phoneOrEmail => '手机号或邮箱';

  @override
  String get call => '拨打电话';

  @override
  String get addContact => '添加联系人';

  @override
  String get contactName => '姓名';

  @override
  String get contactPhone => '电话号码';

  @override
  String get cart => '购物车';

  @override
  String get searchProducts => '搜索商品';

  @override
  String get selectVariant => '请选择规格';

  @override
  String get variant => '规格';

  @override
  String get buyNow => '立即购买';

  @override
  String get cartEmpty => '购物车还是空的';

  @override
  String get returnShop => '返回商城';

  @override
  String get selectAll => '全选';

  @override
  String get checkout => '去结算';

  @override
  String get clearCart => '清空购物车？';

  @override
  String get clearCartHint => '已加入的商品将全部移除。';

  @override
  String get viewOrder => '查看订单';

  @override
  String get confirmOrder => '确认订单';

  @override
  String get productInfo => '商品信息';

  @override
  String get orderNote => '留言';

  @override
  String get noteToSeller => '给商家留言';

  @override
  String get paymentCheckout => '支付收银台';

  @override
  String get orderTotal => '订单总额';

  @override
  String get selectPayment => '选择支付方式';

  @override
  String get refreshOrder => '刷新订单状态';

  @override
  String get viewMyOrders => '查看我的订单';

  @override
  String get backToProduct => '返回商品详情';

  @override
  String get newAddress => '新增地址';

  @override
  String get recipient => '收货人';

  @override
  String get province => '省/自治区';

  @override
  String get district => '区/县';

  @override
  String get streetAddress => '详细地址';

  @override
  String get defaultAddress => '设为默认地址';

  @override
  String get shippingInfo => '物流信息';

  @override
  String get restorePurchases => '恢复购买';

  @override
  String get paymentMethod => '支付方式';

  @override
  String get refresh => '刷新';

  @override
  String get useWatchFace => '使用这个表盘？';

  @override
  String get downloadAndUse => '下载并使用';

  @override
  String get watchFaceFailed => '表盘未设置成功';

  @override
  String get statusNormal => '正常';

  @override
  String get statusRecorded => '已记录';

  @override
  String get statusAttention => '请关注';

  @override
  String get statusOutOfRange => '超出参考范围';

  @override
  String get statusLow => '偏低';

  @override
  String get statusHigh => '偏高';

  @override
  String get careInviteHint => '通过邮箱或国际手机号邀请国际版Saydian账号。';

  @override
  String get careSharingHint => '仅共享您选择的测量项目，可随时停止共享。';

  @override
  String get carePending => '待处理';

  @override
  String get careActive => '已生效';

  @override
  String get careClosed => '已结束';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒绝';

  @override
  String get stopSharing => '停止共享';

  @override
  String get sharedMeasurements => '共享测量项目';

  @override
  String get invitationSent => '邀请已发送';

  @override
  String get invalidCareContact => '请输入邮箱或带国家区号的手机号。';

  @override
  String get carePermissionDenied => '对方尚未与您共享此测量项目。';

  @override
  String get reload => '重新加载';

  @override
  String get applyAfterSales => '申请售后';

  @override
  String get analysisConsent => '健康分析授权';

  @override
  String get workoutRecords => '运动记录';

  @override
  String get startTime => '开始时间';

  @override
  String get addCare => '添加关爱';

  @override
  String get confirmReceipt => '确认收货';

  @override
  String get personalInfo => '个人资料';

  @override
  String get deliveryAddresses => '收货地址';

  @override
  String get readAgain => '重新读取';

  @override
  String get smsCode => '短信验证码';

  @override
  String get watchFaceShop => '表盘商城';

  @override
  String get selectCity => '选择城市';

  @override
  String get city => '城市';

  @override
  String get confirm => '确定';

  @override
  String get productDetails => '商品详情';

  @override
  String get clear => '清空';

  @override
  String get settings => '设置';

  @override
  String get goals => '目标';

  @override
  String get send => '发送';

  @override
  String get typeMessage => '请输入消息…';

  @override
  String get devicesFound => '已发现设备';

  @override
  String get connect => '连接';

  @override
  String get searchAgain => '重新搜索';

  @override
  String get searchRecovery => '请让手表靠近手机；若已连接本机系统蓝牙或其他手机，请先断开再重试。';

  @override
  String get deviceName => '设备名称';

  @override
  String get deviceModel => '设备型号';

  @override
  String get connectionStatus => '连接状态';

  @override
  String get firmwareVersion => '固件版本';

  @override
  String get watchBattery => '手表电量';

  @override
  String get chargingStatus => '充电状态';

  @override
  String get messageDetails => '消息详情';

  @override
  String get dailySummary => '当日摘要';

  @override
  String get remoteMemberData => '远程成员数据';

  @override
  String get ecgWaveformUnavailable => '暂无可用心电波形';

  @override
  String get orderDetails => '订单详情';

  @override
  String get viewShipping => '查看物流';

  @override
  String get measureAgain => '重新测量';

  @override
  String get checkPaymentStatus => '查看支付状态';

  @override
  String get deleteAccount => '注销账号';

  @override
  String get confirmDeleteAccountTitle => '确认注销账号？';

  @override
  String get deleteAccountHint => '账号及相关数据删除成功后，本机会退出登录。';

  @override
  String get confirmDelete => '确认注销';

  @override
  String get exit => '退出';

  @override
  String get nickname => '昵称';

  @override
  String get gender => '性别';

  @override
  String get birthDate => '出生日期';

  @override
  String get heightCm => '身高（cm）';

  @override
  String get weightKg => '体重（kg）';

  @override
  String get choose => '请选择';

  @override
  String get connectWatchToUse => '连接手表后使用';

  @override
  String get selectPhoto => '选择照片';

  @override
  String get saved => '已保存';

  @override
  String get saveChanges => '保存修改';

  @override
  String get notificationsOff => '系统通知未开启';

  @override
  String get privacyAgreement => '隐私协议';

  @override
  String get appPermissions => 'App 系统权限';

  @override
  String get openSystemSettings => '打开系统应用设置';

  @override
  String get monitoringHint => '连接后会显示当前手表可设置的健康检测项目。';

  @override
  String get previewUnavailable => '预览暂不可用';

  @override
  String get distance => '距离';

  @override
  String get calories => '热量';

  @override
  String get healthProfile => '健康档案';

  @override
  String get photoWatchFace => '照片表盘';

  @override
  String get cameraRemote => '相机遥控';

  @override
  String get phoneCalls => '电话';

  @override
  String get contacts => '联系人';

  @override
  String get notifications => '消息通知';

  @override
  String get alarms => '闹钟';

  @override
  String get weather => '天气';

  @override
  String get worldClock => '世界时钟';

  @override
  String get healthReminders => '健康提醒';

  @override
  String get healthMonitoring => '健康监测';

  @override
  String get healthAssessment => '辅助评估';

  @override
  String get screenDisplay => '屏幕显示';

  @override
  String get scanning => '正在搜索';

  @override
  String get connecting => '连接中';

  @override
  String get waitingConfirmation => '等待确认';

  @override
  String get syncing => '正在同步';

  @override
  String get measuring => '测量中';

  @override
  String get needsAttention => '需要处理';

  @override
  String get tapToOpen => '点击进入';

  @override
  String get deviceInfoHint => '查看设备信息';

  @override
  String get connectionInstructions =>
      '1. 打开手机蓝牙并允许查找附近设备。\n2. 将手表充电激活，并放在手机旁边。\n3. 点击“开始查找”，选择自己的手表。\n4. 如果手表弹出确认，请及时确认。';

  @override
  String get syncNearbyHint => '连接或同步时，请让手表保持电量充足并靠近手机。';

  @override
  String get invalidCode => '请检查验证码后重试';

  @override
  String get codeExpired => '验证码已过期，请重新获取';

  @override
  String get tooManyAttempts => '操作过于频繁，请稍后重试';

  @override
  String get readTerms => '请阅读用户协议和隐私政策后继续';

  @override
  String verificationSentTo(String contact) {
    return '验证码已发送至 $contact';
  }

  @override
  String get addSmartDevice => '添加智能设备';

  @override
  String get watchNearbyHint => '请开启手机蓝牙并将手表靠近手机';

  @override
  String get startSearch => '开始查找';

  @override
  String get readingData => '正在读取数据';

  @override
  String get readingCapabilities => '正在识别手表功能…';

  @override
  String get capabilitiesHint => '识别完成后只显示当前手表可用的功能';

  @override
  String get capabilitiesFailed => '暂时无法读取此手表的功能';

  @override
  String get keepWatchNear => '请保持手表靠近手机后重试';

  @override
  String get personalizeWatch => '表盘与个性化';

  @override
  String get signInCloudHint => '登录后开启云端健康服务';

  @override
  String get aiQuestion => 'AI提问';

  @override
  String get aiQuestionHint => '向 AI 健康管家咨询健康问题';

  @override
  String get language => '语言';

  @override
  String get signIn => '登录';

  @override
  String get signUp => '注册';

  @override
  String get signOut => '退出登录';

  @override
  String get email => '邮箱';

  @override
  String get phoneNumber => '手机号';

  @override
  String get countryRegion => '国家或地区';

  @override
  String get password => '密码';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get verificationCode => '验证码';

  @override
  String get sendCode => '获取验证码';

  @override
  String get forgotPassword => '忘记密码？';

  @override
  String get resetPassword => '重置密码';

  @override
  String get createAccount => '创建账号';

  @override
  String get continueAction => '继续';

  @override
  String get back => '返回';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get retry => '重试';

  @override
  String get loading => '加载中…';

  @override
  String get pleaseWait => '请稍候…';

  @override
  String get emailOrPhone => '邮箱或手机号';

  @override
  String get enterEmail => '请输入邮箱地址';

  @override
  String get enterPhone => '请输入手机号';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get passwordRequirement => '至少8个字符；英文字母和数字最多72个，其他字符可用长度更短。';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get invalidEmail => '请输入有效的邮箱地址';

  @override
  String get invalidPhone => '请检查国家区号和手机号';

  @override
  String get codeSent => '验证码已发送，请查收';

  @override
  String get codeRequired => '请输入验证码';

  @override
  String get consentRequired => '请先阅读并同意用户协议和隐私政策';

  @override
  String get agreeToTerms => '我已阅读并同意';

  @override
  String get termsOfService => '用户协议';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get registrationUnavailable => '注册暂时无法使用，请稍后再试';

  @override
  String get loginFailed => '登录失败，请检查账号信息后重试';

  @override
  String get accountAlreadyExists => '此账号已注册，请直接登录';

  @override
  String get networkUnavailable => '网络不可用，请检查后重试';

  @override
  String get serviceUnavailable => '此功能暂时无法使用，请稍后再试';

  @override
  String get accountCreated => '账号已创建';

  @override
  String get passwordReset => '密码已更新';

  @override
  String get haveAccount => '已有账号？';

  @override
  String get noAccount => '还没有账号？';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get selectCountry => '选择国家或地区';

  @override
  String get registrationMethod => '注册方式';

  @override
  String get changeLanguageFailed => '语言保存失败，请重试';

  @override
  String get health => '健康';

  @override
  String get device => '设备';

  @override
  String get profile => '我的';

  @override
  String get healthData => '健康数据';

  @override
  String get allData => '全部数据';

  @override
  String get healthRecords => '健康记录';

  @override
  String get workoutsAndRecords => '运动与记录';

  @override
  String get healthDisclaimer => '测量结果仅供健康管理参考，如有不适请咨询专业医务人员。';

  @override
  String get healthSafetyAdvice => '请休息后复测；如有明显不适，请及时咨询医务人员。';

  @override
  String get defaultUser => '赛电用户';

  @override
  String get dailyGreeting => '今天也要保持好状态';

  @override
  String get messages => '消息';

  @override
  String get aiAssistant => 'AI健康管家';

  @override
  String get aiAssistantIntro => '我是您的健康管家，\n有任何健康问题都可以向我提问。';

  @override
  String get askNow => '马上提问';

  @override
  String get remoteCare => '远程关爱';

  @override
  String get healthLibrary => '健康百科';

  @override
  String get healthAlerts => '健康预警';

  @override
  String get shop => '赛电商城';

  @override
  String get connectWatch => '连接手表';

  @override
  String get addDevice => '添加设备';

  @override
  String get connectWatchForData => '连接手表后可查看支持的健康数据';

  @override
  String get noHealthData => '暂无可显示的健康数据';

  @override
  String get noData => '暂无数据';

  @override
  String get connected => '已连接';

  @override
  String get notConnected => '未连接';

  @override
  String get online => '在线';

  @override
  String get syncData => '同步数据';

  @override
  String get syncComplete => '数据同步完成';

  @override
  String get syncFailedTryAgain => '数据同步失败，请将手表靠近手机后重试';

  @override
  String get disconnect => '断开连接';

  @override
  String get findWatch => '查找手表';

  @override
  String get watchFaces => '表盘';

  @override
  String get deviceFeatures => '设备功能';

  @override
  String get aboutDevice => '关于设备';

  @override
  String get connectionHelp => '连接说明';

  @override
  String get searchNearbyWatch => '搜索并连接附近的赛电手表';

  @override
  String get useWatch => '请在手表上操作';

  @override
  String get myOrders => '我的订单';

  @override
  String get all => '全部';

  @override
  String get awaitingPayment => '待支付';

  @override
  String get awaitingShipment => '待发货';

  @override
  String get awaitingDelivery => '待收货';

  @override
  String get afterSales => '售后';

  @override
  String get careMembers => '关爱成员';

  @override
  String get unitSettings => '单位设置';

  @override
  String get unitSettingsHint => '设置距离、温度等数据单位';

  @override
  String get myServices => '我的服务';

  @override
  String get accountSettings => '账号设置';

  @override
  String get editProfile => '完善资料';

  @override
  String get permissions => '权限管理';

  @override
  String get feedback => '意见反馈';

  @override
  String get customerService => '联系客服';

  @override
  String get aboutApp => '关于我们';

  @override
  String get security => '账号安全';

  @override
  String get goToSettings => '去设置';

  @override
  String get close => '关闭';

  @override
  String get view => '查看';

  @override
  String get checkUpdates => '检查更新';

  @override
  String get onlineUpdate => '在线更新';

  @override
  String get updateRequired => '需要更新后继续使用';

  @override
  String get updateReady => '新版本已准备好';

  @override
  String get preparingUpdate => '正在准备安全更新…';

  @override
  String get openingUpdate => '正在打开系统更新页面…';

  @override
  String get updateAppStore => '前往 App Store 更新';

  @override
  String get updateStore => '前往应用商店更新';

  @override
  String get downloadAndInstall => '安全下载并安装';

  @override
  String get gettingReady => '正在为你准备…';

  @override
  String get enableNotifications => '开启赛电消息通知';

  @override
  String get notificationExplanation =>
      '用于提醒新的健康预警和关爱邀请。锁屏上不会显示具体健康数值，可随时在系统设置中关闭。';

  @override
  String get notNow => '暂不开启';

  @override
  String get enable => '开启';

  @override
  String get newCareRequest => '收到新的关爱请求';

  @override
  String get dismissHealthAlert => '关闭健康预警';

  @override
  String get dismissCareAlert => '关闭关爱提醒';

  @override
  String get bloodPressure => '血压';

  @override
  String get heartRate => '心率';

  @override
  String get bloodOxygen => '血氧';

  @override
  String get bloodGlucose => '血糖';

  @override
  String get bodyTemperature => '体温';

  @override
  String get ecg => '心电';

  @override
  String get hrv => 'HRV';

  @override
  String get bodyComposition => '身体成分';

  @override
  String get bloodComposition => '血液成分';

  @override
  String get sleep => '睡眠';

  @override
  String get steps => '步数';

  @override
  String get workouts => '运动';

  @override
  String welcome(String name) {
    return '你好，$name';
  }

  @override
  String resendCode(int seconds) {
    return '$seconds秒后重发';
  }

  @override
  String memberId(String id) {
    return '会员 ID：$id';
  }

  @override
  String unreadMessages(int count) {
    return '消息，$count 条未读';
  }

  @override
  String recordCount(int count) {
    return '$count 条';
  }

  @override
  String memberCount(int count) {
    return '$count 人';
  }

  @override
  String versionBuild(String version, int build) {
    return 'V$version · 构建 $build';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get scanLocationTitle => '請開啟手機定位';

  @override
  String get scanLocationHint => '請在設定中開啟手機定位，再返回此頁面尋找附近的手錶。';

  @override
  String get scanPermissionTitle => '請允許相關權限';

  @override
  String get scanPermissionHint => '請在設定中允許相關權限，再返回此頁面尋找手錶。';

  @override
  String get loginProtectionTitle => '登入保護';

  @override
  String get verifyContactToReset => '驗證電子郵件或手機號碼後重新設定密碼';

  @override
  String get workoutStartOnWatch => '目前手錶不支援從 App 啟動運動，請直接在手錶上開始運動。';

  @override
  String get finishWorkoutConfirm => '結束目前運動？';

  @override
  String get finishLeaveWorkoutHint => '離開前會先停止手錶運動，並儲存已記錄的運動時間和路線。';

  @override
  String get finishAndLeave => '結束並離開';

  @override
  String get workoutRouteMissing => '此記錄沒有手機前景路線，仍保留手錶運動資料。';

  @override
  String get workoutDuration => '運動時間';

  @override
  String get workoutWatchHeartRate => '手錶心率';

  @override
  String get messageSendFailed => '傳送失敗，請檢查網路後重試';

  @override
  String get noWatchShopHint => '沒有裝置？前往 Saydian 商城看看';

  @override
  String get notificationInAppHint => 'App 內未讀標示和訊息仍可使用，開啟通知後可及時收到關愛邀請與健康預警。';

  @override
  String get healthAlertSafetyHint => '健康預警用於及時提醒，不作為醫療診斷；如有明顯不適，請及時就醫。';

  @override
  String get afterSalesService => '售後服務';

  @override
  String get afterSalesApplyHint => '請選擇需要售後的商品，並填寫原因和申請金額。提交後可在訂單列表查看處理狀態。';

  @override
  String get afterSalesAlreadySubmitted => '此商品已提交售後申請，請等待商城工作人員處理。';

  @override
  String get afterSalesType => '售後類型';

  @override
  String get requestedAmount => '申請金額';

  @override
  String get afterSalesReason => '售後原因';

  @override
  String get describeProblem => '請說明遇到的問題';

  @override
  String get amountPaid => '實付款';

  @override
  String get orderDetailsLoadFailed => '訂單詳情載入失敗，請稍後重試。';

  @override
  String get confirmItemReceived => '確認已收到商品？';

  @override
  String get confirmReceiptHint => '確認收貨後訂單將完成。如尚未收到商品，請不要確認。';

  @override
  String get notConfirmYet => '暫不確認';

  @override
  String get unitChangesHint => '單位選擇會立即生效。重新安裝 App 後可能需要再次設定。';

  @override
  String get goalSettingsTitle => '目標設定';

  @override
  String get dailyStepGoalField => '每日步數目標（步）';

  @override
  String get dailyDistanceGoalField => '每日距離目標（公里）';

  @override
  String get dailyCalorieGoalField => '每日熱量目標（千卡）';

  @override
  String get saveGoals => '儲存目標';

  @override
  String get viewAccountAddresses => '查看帳號中的收貨地址';

  @override
  String get loadingProfile => '正在讀取個人資料…';

  @override
  String get profileSaveExplanation => '頭像和個人資料會在點選儲存後同步至帳號，用於個人中心和遠端關愛成員識別。';

  @override
  String get contactPhoneLabel => '聯絡電話';

  @override
  String get wechatOfficialAccount => '微信公眾號';

  @override
  String get addSupportContact => '新增客服聯絡方式';

  @override
  String get contactPreparationHint => '聯絡前請準備裝置型號和問題發生時間';

  @override
  String get supportPrivacyWarning => '請勿向非官方帳號傳送驗證碼、密碼或完整健康記錄。';

  @override
  String get brandHealthTitle => 'Saydian 健康';

  @override
  String get accountAndSecurity => '帳號與安全';

  @override
  String get cityNameLabel => '城市名稱';

  @override
  String get cityNameExample => '例如：倫敦';

  @override
  String get visitStoreHint => '前往商城挑選適合您的健康裝置';

  @override
  String get selectReportPlan => '選擇報告方案';

  @override
  String get reportPaidContentHint => '明顯異常提醒始終免費；付費內容為更完整的趨勢整理與日常健康建議。';

  @override
  String get wechatPayLabel => '微信支付';

  @override
  String get alipayLabel => '支付寶';

  @override
  String get reportPurchaseTerms => '購買前請確認方案和價格。健康會員不會自動續費，未使用次數到期不結轉。';

  @override
  String get detailedHealthReport => '詳細健康報告';

  @override
  String get reportInsufficientDataHint => '資料不足時不會建立付款訂單。請正常佩戴並同步手錶資料後再試。';

  @override
  String get waitingPaymentConfirmation => '等待付款結果確認';

  @override
  String get paymentReturnRefreshHint => '付款完成後返回此頁重新整理，確認結果後將更新可用權益。';

  @override
  String get reportPurchaseDataMissing => '目前資料仍不足，暫不提供購買入口。';

  @override
  String get heartRateUpperLimit => '心率上限';

  @override
  String get systolicUpperLimit => '收縮壓上限';

  @override
  String get diastolicUpperLimit => '舒張壓上限';

  @override
  String get temperatureUpperLimit => '體溫上限';

  @override
  String get calibrateOnWatchHint => '依照手錶提示完成校準';

  @override
  String get spotCheckCuffHint => '本次僅為靜態監測，結果僅供參考，如需更準確的資料，請使用手錶氣泵氣囊式檢測';

  @override
  String get setHealthUpperLimits => '設定健康資料上限提醒';

  @override
  String get healthUpperLimitHint => '超過設定值時提醒。';

  @override
  String get heartRateAlertLabel => '心率警報';

  @override
  String get heartRateAlertHint => '超過設定心率時提示';

  @override
  String get bloodPressureAlertLabel => '血壓警報';

  @override
  String get bloodPressureAlertHint => '收縮壓或舒張壓超過設定值時提示';

  @override
  String get temperatureAlertLabel => '體溫警報';

  @override
  String get temperatureAlertHint => '超過設定體溫時提示';

  @override
  String get saveHealthAlerts => '儲存預警設定';

  @override
  String get healthAlertHistory => '預警記錄';

  @override
  String get seekProfessionalCare => '如有明顯不適，請及時諮詢專業醫務人員';

  @override
  String get watchHealthReference => '手錶測量結果用於日常健康管理參考。';

  @override
  String get calibrationReferenceHint => '請使用剛剛由專業設備測得的數值';

  @override
  String get calibrationWearerHint => '校準值只適用於目前佩戴者。更換佩戴者後，請關閉或重新校準。';

  @override
  String get enableCalibration => '啟用校準';

  @override
  String get calibrationDisabledHint => '關閉後恢復手錶一般測量模式';

  @override
  String get diastolicLowerLabel => '舒張壓（低壓）';

  @override
  String get longTermTrendHint => '查看長期趨勢更有參考價值';

  @override
  String get measurementVariationHint => '單次測量可能受佩戴方式、運動和環境影響；如有不適，請諮詢專業醫務人員。';

  @override
  String get ecgDetailTitle => '心電詳情';

  @override
  String get viewFullReport => '查看完整報告';

  @override
  String get ecgReferenceHint => '心電結果僅供健康管理參考';

  @override
  String get ecgVariationSafety => '單次測量會受到佩戴、運動和環境影響，不能代替醫療診斷。如有不適，請及時就醫。';

  @override
  String get ecgBasicOnly => '本次僅傳回基本心電資料';

  @override
  String get measurementIndicators => '測量指標';

  @override
  String get riskIndicatorsMissing => '本次手錶未傳回風險指標';

  @override
  String get riskAnalysisTitle => '風險分析';

  @override
  String get watchAlgorithmReference => '以下數值來自手錶演算法，僅供健康趨勢參考。';

  @override
  String get ecgHealthReport => '心電健康報告';

  @override
  String get brandedEcgReport => 'Saydian · 心電健康報告';

  @override
  String get ecgReportSafety => '說明：本報告由手錶測量資料產生，僅供健康管理參考，不能替代醫師診斷。';

  @override
  String get installedWatchFaces => '已安裝錶面';

  @override
  String get switchInstalledWatchFace => '可切換手錶內已有錶面';

  @override
  String get useSelectedWatchFace => '使用';

  @override
  String get downloadUseWatchFace => '點選下載並使用';

  @override
  String get photoWatchFaceHint => '選擇一張清晰照片，確認預覽後再傳送至手錶。';

  @override
  String get timeDisplayPosition => '時間顯示位置';

  @override
  String get transferSetWatchFace => '傳送並設為錶面';

  @override
  String get watchTransferKeepNear => '傳送時請讓手錶靠近手機，並避免切換至其他頁面。';

  @override
  String get callMediaAudio => '通話與媒體聲音';

  @override
  String get useCelsius => '使用攝氏度';

  @override
  String get sosContactHint => '手錶觸發 SOS 後，會優先聯絡此處選擇的人。建議選擇最常聯絡的家人。';

  @override
  String get noHealthAssessments => '目前手錶沒有可設定的輔助評估';

  @override
  String get modelFeaturesVary => '不同型號支援的項目可能不同，請以手錶實際顯示為準。';

  @override
  String get assessmentEnabledHint => '開啟後由手錶提供日常趨勢參考';

  @override
  String get assessmentSafety => '輔助評估僅供日常健康管理參考，不用於診斷或治療。';

  @override
  String get autoMonitorIntervalHint => '開啟後由手錶依裝置設定週期自動檢測';

  @override
  String get watchHeartRateAlert => '手錶心率預警';

  @override
  String get sustainedLimitWatchAlert => '持續超過閾值時由手錶提醒';

  @override
  String get ecgWaveformTitle => '心電波形';

  @override
  String get ecgWaveformMissing => '本次未傳回有效心電波形';

  @override
  String get ecgElectrodeHint => '心率和 HRV 等結果仍可查看；下次測量時請持續接觸手錶電極。';

  @override
  String get screenAutoTimeHint => '由手錶依時間自動調節';

  @override
  String get raiseWristScreenHint => '抬起手腕時自動點亮螢幕';

  @override
  String get watchHighHeartRate => '心率過高預警';

  @override
  String get watchThresholdHint => '達到閾值後由手錶提醒';

  @override
  String get watchMeasurementSafety => '測量結果僅供健康管理參考，不用於診斷或治療。';

  @override
  String get healthDataExplanation => '健康資料說明';

  @override
  String get trendUnavailable => '趨勢暫時無法使用';

  @override
  String get recentData => '近期資料';

  @override
  String get trendReferenceOnly => '趨勢僅供日常健康參考';

  @override
  String get trendVariationSafety => '單次和階段變化可能受佩戴、運動及環境影響，不替代醫療診斷。';

  @override
  String get watchFaceDownloadHint => '下載後會傳送至手錶。傳送期間請讓手錶靠近手機，不要離開目前頁面。';

  @override
  String get refreshWatchFaces => '重新整理手錶錶面';

  @override
  String get openTestFlight => '開啟 TestFlight';

  @override
  String get articlesEmpty => '該分類暫無百科內容';

  @override
  String get articlesUnavailable => '健康百科載入失敗';

  @override
  String get articleContentUnavailable => '文章詳情暫未傳回正文內容。';

  @override
  String get imageUnavailable => '圖片暫時無法載入';

  @override
  String get allowNotifications => '允許通知';

  @override
  String get updateNow => '立即更新';

  @override
  String get analysisConsentUnavailable => '健康分析暫時無法使用，已有報告仍可查看。';

  @override
  String get analysisReadAgree => '我已閱讀並同意上述健康分析說明';

  @override
  String get agreeContinue => '同意並繼續';

  @override
  String get notGrantNow => '暫不授權';

  @override
  String get analysisConsentSaved => '健康分析授權已儲存';

  @override
  String get withdrawAnalysisConsent => '撤回健康分析授權？';

  @override
  String get withdrawAnalysisExplanation => '撤回後不會再產生新的詳細報告，已經產生且未退款的報告仍可查看。';

  @override
  String get confirmWithdraw => '確認撤回';

  @override
  String get analysisConsentWithdrawn => '健康分析授權已撤回';

  @override
  String get consentGrantedHint => '已授權，可隨時撤回';

  @override
  String get consentNeededHint => '產生詳細報告前需要單獨授權';

  @override
  String get withdraw => '撤回';

  @override
  String get reportHistory => '歷史報告';

  @override
  String get saving => '正在儲存';

  @override
  String get pauseWorkout => '暫停運動';

  @override
  String get resumeWorkout => '繼續運動';

  @override
  String get finishWorkout => '結束運動';

  @override
  String get watchDistance => '手錶距離';

  @override
  String get watchSteps => '手錶步數';

  @override
  String get liveHeartRate => '即時心率';

  @override
  String get watchCalories => '手錶熱量';

  @override
  String get connectForWorkout => '請先在裝置頁連接手錶，運動模式將由手錶記錄。';

  @override
  String latestVersion(String version) {
    return '目前已是最新版本 V$version';
  }

  @override
  String workoutPaused(String mode) {
    return '$mode已暫停';
  }

  @override
  String workoutInProgress(String mode) {
    return '$mode進行中';
  }

  @override
  String workoutReady(String mode) {
    return '準備開始$mode';
  }

  @override
  String startWorkout(String mode) {
    return '開始$mode';
  }

  @override
  String finishOtherWorkout(String mode) {
    return '請先結束$mode';
  }

  @override
  String workoutDetails(String mode) {
    return '$mode詳情';
  }

  @override
  String stepCount(int count) {
    return '$count 步';
  }

  @override
  String get globalShopPricePending => '價格待確認';

  @override
  String get globalShopLoadMore => '載入更多商品';

  @override
  String get globalShopReadOnly => '可瀏覽商品，目前地區暫未開放下單。';

  @override
  String get appName => 'Saydian';

  @override
  String get searchingNearby => '正在搜尋附近手錶';

  @override
  String get noDevices => '未發現裝置';

  @override
  String get selectWatch => '請核對名稱和訊號強度，再選擇手錶';

  @override
  String get searchingHint => '正在搜尋，訊號會更新，清單位置不會變化';

  @override
  String get activateWatch => '請取出裝置、充電啟動，並將手錶靠近手機';

  @override
  String get checkWatchConnection => '若手錶已連到本機系統藍牙或其他手機，請先中斷連線後重新搜尋';

  @override
  String get running => '跑步';

  @override
  String get walking => '步行';

  @override
  String get cycling => '騎行';

  @override
  String get hiking => '健行';

  @override
  String get mountaineering => '登山';

  @override
  String metricAnalysis(String metric) {
    return '$metric分析';
  }

  @override
  String metricAllData(String metric) {
    return '$metric全部資料';
  }

  @override
  String metricMeasurement(String metric) {
    return '$metric測量';
  }

  @override
  String metricCalibration(String metric) {
    return '$metric校準';
  }

  @override
  String metricDetails(String metric) {
    return '$metric詳情';
  }

  @override
  String get add => '新增';

  @override
  String get endTime => '結束時間';

  @override
  String get reminderInterval => '提醒間隔';

  @override
  String get reminderName => '提醒名稱';

  @override
  String get repeat => '重複';

  @override
  String get addAlarm => '新增鬧鐘';

  @override
  String get alarmTime => '提醒時間';

  @override
  String get enableAlarm => '啟用鬧鐘';

  @override
  String get emergencyContact => 'SOS 緊急聯絡人';

  @override
  String get selectEmergencyContact => '選擇 SOS 緊急聯絡人';

  @override
  String get confirmEmergencyContact => '確認設為 SOS 聯絡人';

  @override
  String get addWorldClock => '新增世界時鐘';

  @override
  String get autoBrightness => '自動調整亮度';

  @override
  String get raiseToWake => '抬腕亮屏';

  @override
  String get activeTime => '生效時間';

  @override
  String get saveSettings => '儲存設定';

  @override
  String get helpFeedback => '說明與回饋';

  @override
  String get issueType => '問題類型';

  @override
  String get issueDescription => '問題說明';

  @override
  String get describeIssue => '請描述遇到的問題和出現步驟';

  @override
  String get contactOptional => '聯絡方式（選填）';

  @override
  String get phoneOrEmail => '手機號碼或電子郵件';

  @override
  String get call => '撥打電話';

  @override
  String get addContact => '新增聯絡人';

  @override
  String get contactName => '姓名';

  @override
  String get contactPhone => '電話號碼';

  @override
  String get cart => '購物車';

  @override
  String get searchProducts => '搜尋商品';

  @override
  String get selectVariant => '請選擇規格';

  @override
  String get variant => '規格';

  @override
  String get buyNow => '立即購買';

  @override
  String get cartEmpty => '購物車還是空的';

  @override
  String get returnShop => '返回商城';

  @override
  String get selectAll => '全選';

  @override
  String get checkout => '前往結帳';

  @override
  String get clearCart => '清空購物車？';

  @override
  String get clearCartHint => '已加入的商品將全部移除。';

  @override
  String get viewOrder => '查看訂單';

  @override
  String get confirmOrder => '確認訂單';

  @override
  String get productInfo => '商品資訊';

  @override
  String get orderNote => '留言';

  @override
  String get noteToSeller => '給商家留言';

  @override
  String get paymentCheckout => '付款頁面';

  @override
  String get orderTotal => '訂單總額';

  @override
  String get selectPayment => '選擇付款方式';

  @override
  String get refreshOrder => '重新整理訂單狀態';

  @override
  String get viewMyOrders => '查看我的訂單';

  @override
  String get backToProduct => '返回商品詳情';

  @override
  String get newAddress => '新增地址';

  @override
  String get recipient => '收貨人';

  @override
  String get province => '省／自治區';

  @override
  String get district => '區／縣';

  @override
  String get streetAddress => '詳細地址';

  @override
  String get defaultAddress => '設為預設地址';

  @override
  String get shippingInfo => '物流資訊';

  @override
  String get restorePurchases => '恢復購買';

  @override
  String get paymentMethod => '付款方式';

  @override
  String get refresh => '重新整理';

  @override
  String get useWatchFace => '使用此錶盤？';

  @override
  String get downloadAndUse => '下載並使用';

  @override
  String get watchFaceFailed => '錶盤設定未成功';

  @override
  String get statusNormal => '正常';

  @override
  String get statusRecorded => '已記錄';

  @override
  String get statusAttention => '請留意';

  @override
  String get statusOutOfRange => '超出參考範圍';

  @override
  String get statusLow => '偏低';

  @override
  String get statusHigh => '偏高';

  @override
  String get careInviteHint => '透過電子郵件或國際手機號碼邀請國際版Saydian帳號。';

  @override
  String get careSharingHint => '僅分享您選擇的測量項目，可隨時停止分享。';

  @override
  String get carePending => '待處理';

  @override
  String get careActive => '已生效';

  @override
  String get careClosed => '已結束';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒絕';

  @override
  String get stopSharing => '停止分享';

  @override
  String get sharedMeasurements => '分享的測量項目';

  @override
  String get invitationSent => '邀請已傳送';

  @override
  String get invalidCareContact => '請輸入電子郵件或含國家區碼的手機號碼。';

  @override
  String get carePermissionDenied => '對方尚未與您分享此測量項目。';

  @override
  String get reload => '重新載入';

  @override
  String get applyAfterSales => '申請售後';

  @override
  String get analysisConsent => '健康分析授權';

  @override
  String get workoutRecords => '運動記錄';

  @override
  String get startTime => '開始時間';

  @override
  String get addCare => '新增關愛';

  @override
  String get confirmReceipt => '確認收貨';

  @override
  String get personalInfo => '個人資料';

  @override
  String get deliveryAddresses => '收貨地址';

  @override
  String get readAgain => '重新讀取';

  @override
  String get smsCode => '簡訊驗證碼';

  @override
  String get watchFaceShop => '錶盤商城';

  @override
  String get selectCity => '選擇城市';

  @override
  String get city => '城市';

  @override
  String get confirm => '確定';

  @override
  String get productDetails => '商品詳情';

  @override
  String get clear => '清空';

  @override
  String get settings => '設定';

  @override
  String get goals => '目標';

  @override
  String get send => '傳送';

  @override
  String get typeMessage => '請輸入訊息…';

  @override
  String get devicesFound => '已發現裝置';

  @override
  String get connect => '連接';

  @override
  String get searchAgain => '重新搜尋';

  @override
  String get searchRecovery => '請讓手錶靠近手機；若已連接本機系統藍牙或其他手機，請先中斷連線再重試。';

  @override
  String get deviceName => '裝置名稱';

  @override
  String get deviceModel => '裝置型號';

  @override
  String get connectionStatus => '連接狀態';

  @override
  String get firmwareVersion => '韌體版本';

  @override
  String get watchBattery => '手錶電量';

  @override
  String get chargingStatus => '充電狀態';

  @override
  String get messageDetails => '訊息詳情';

  @override
  String get dailySummary => '當日摘要';

  @override
  String get remoteMemberData => '遠端成員資料';

  @override
  String get ecgWaveformUnavailable => '暫無可用心電波形';

  @override
  String get orderDetails => '訂單詳情';

  @override
  String get viewShipping => '查看物流';

  @override
  String get measureAgain => '重新測量';

  @override
  String get checkPaymentStatus => '查看付款狀態';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get confirmDeleteAccountTitle => '確認刪除帳號？';

  @override
  String get deleteAccountHint => '帳號及相關資料刪除成功後，本機會登出。';

  @override
  String get confirmDelete => '確認刪除';

  @override
  String get exit => '退出';

  @override
  String get nickname => '暱稱';

  @override
  String get gender => '性別';

  @override
  String get birthDate => '出生日期';

  @override
  String get heightCm => '身高（cm）';

  @override
  String get weightKg => '體重（kg）';

  @override
  String get choose => '請選擇';

  @override
  String get connectWatchToUse => '連接手錶後使用';

  @override
  String get selectPhoto => '選擇照片';

  @override
  String get saved => '已儲存';

  @override
  String get saveChanges => '儲存變更';

  @override
  String get notificationsOff => '系統通知未開啟';

  @override
  String get privacyAgreement => '隱私協議';

  @override
  String get appPermissions => 'App 系統權限';

  @override
  String get openSystemSettings => '開啟系統應用程式設定';

  @override
  String get monitoringHint => '連接後會顯示目前手錶可設定的健康監測項目。';

  @override
  String get previewUnavailable => '預覽暫不可用';

  @override
  String get distance => '距離';

  @override
  String get calories => '熱量';

  @override
  String get healthProfile => '健康檔案';

  @override
  String get photoWatchFace => '照片錶盤';

  @override
  String get cameraRemote => '相機遙控';

  @override
  String get phoneCalls => '電話';

  @override
  String get contacts => '聯絡人';

  @override
  String get notifications => '訊息通知';

  @override
  String get alarms => '鬧鐘';

  @override
  String get weather => '天氣';

  @override
  String get worldClock => '世界時鐘';

  @override
  String get healthReminders => '健康提醒';

  @override
  String get healthMonitoring => '健康監測';

  @override
  String get healthAssessment => '輔助評估';

  @override
  String get screenDisplay => '螢幕顯示';

  @override
  String get scanning => '正在搜尋';

  @override
  String get connecting => '連接中';

  @override
  String get waitingConfirmation => '等待確認';

  @override
  String get syncing => '正在同步';

  @override
  String get measuring => '測量中';

  @override
  String get needsAttention => '需要處理';

  @override
  String get tapToOpen => '點選進入';

  @override
  String get deviceInfoHint => '查看裝置資訊';

  @override
  String get connectionInstructions =>
      '1. 開啟手機藍牙並允許尋找附近裝置。\n2. 為手錶充電並放在手機旁。\n3. 點選「開始搜尋」，選擇自己的手錶。\n4. 若手錶顯示確認提示，請確認。';

  @override
  String get syncNearbyHint => '連接或同步時，請讓手錶保持電量充足並靠近手機。';

  @override
  String get invalidCode => '請檢查驗證碼後重試';

  @override
  String get codeExpired => '驗證碼已過期，請重新取得';

  @override
  String get tooManyAttempts => '操作過於頻繁，請稍後重試';

  @override
  String get readTerms => '請閱讀使用者協議和隱私政策後繼續';

  @override
  String verificationSentTo(String contact) {
    return '驗證碼已傳送至 $contact';
  }

  @override
  String get addSmartDevice => '新增智慧裝置';

  @override
  String get watchNearbyHint => '請開啟手機藍牙並將手錶靠近手機';

  @override
  String get startSearch => '開始搜尋';

  @override
  String get readingData => '正在讀取資料';

  @override
  String get readingCapabilities => '正在辨識手錶功能…';

  @override
  String get capabilitiesHint => '辨識完成後僅顯示目前手錶可用的功能';

  @override
  String get capabilitiesFailed => '暫時無法讀取此手錶的功能';

  @override
  String get keepWatchNear => '請保持手錶靠近手機後重試';

  @override
  String get personalizeWatch => '錶盤與個人化';

  @override
  String get signInCloudHint => '登入後開啟雲端健康服務';

  @override
  String get aiQuestion => 'AI提問';

  @override
  String get aiQuestionHint => '向 AI 健康管家諮詢健康問題';

  @override
  String get language => '語言';

  @override
  String get signIn => '登入';

  @override
  String get signUp => '註冊';

  @override
  String get signOut => '登出';

  @override
  String get email => '電子郵件';

  @override
  String get phoneNumber => '手機號碼';

  @override
  String get countryRegion => '國家或地區';

  @override
  String get password => '密碼';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get verificationCode => '驗證碼';

  @override
  String get sendCode => '取得驗證碼';

  @override
  String get forgotPassword => '忘記密碼？';

  @override
  String get resetPassword => '重設密碼';

  @override
  String get createAccount => '建立帳號';

  @override
  String get continueAction => '繼續';

  @override
  String get back => '返回';

  @override
  String get cancel => '取消';

  @override
  String get save => '儲存';

  @override
  String get retry => '重試';

  @override
  String get loading => '載入中…';

  @override
  String get pleaseWait => '請稍候…';

  @override
  String get emailOrPhone => '電子郵件或手機號碼';

  @override
  String get enterEmail => '請輸入電子郵件地址';

  @override
  String get enterPhone => '請輸入手機號碼';

  @override
  String get enterPassword => '請輸入密碼';

  @override
  String get passwordRequirement => '至少8個字元；英文字母和數字最多72個，其他字元可用長度更短。';

  @override
  String get passwordMismatch => '兩次輸入的密碼不一致';

  @override
  String get invalidEmail => '請輸入有效的電子郵件地址';

  @override
  String get invalidPhone => '請檢查國家區碼和手機號碼';

  @override
  String get codeSent => '驗證碼已傳送，請查收';

  @override
  String get codeRequired => '請輸入驗證碼';

  @override
  String get consentRequired => '請先閱讀並同意使用者協議和隱私政策';

  @override
  String get agreeToTerms => '我已閱讀並同意';

  @override
  String get termsOfService => '使用者協議';

  @override
  String get privacyPolicy => '隱私政策';

  @override
  String get registrationUnavailable => '註冊暫時無法使用，請稍後再試';

  @override
  String get loginFailed => '登入失敗，請檢查帳號資訊後重試';

  @override
  String get accountAlreadyExists => '此帳號已註冊，請直接登入';

  @override
  String get networkUnavailable => '網路無法使用，請檢查後重試';

  @override
  String get serviceUnavailable => '此功能暫時無法使用，請稍後再試';

  @override
  String get accountCreated => '帳號已建立';

  @override
  String get passwordReset => '密碼已更新';

  @override
  String get haveAccount => '已有帳號？';

  @override
  String get noAccount => '還沒有帳號？';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get selectCountry => '選擇國家或地區';

  @override
  String get registrationMethod => '註冊方式';

  @override
  String get changeLanguageFailed => '語言儲存失敗，請重試';

  @override
  String get health => '健康';

  @override
  String get device => '裝置';

  @override
  String get profile => '我的';

  @override
  String get healthData => '健康資料';

  @override
  String get allData => '全部資料';

  @override
  String get healthRecords => '健康記錄';

  @override
  String get workoutsAndRecords => '運動與記錄';

  @override
  String get healthDisclaimer => '測量結果僅供健康管理參考，如有不適請諮詢專業醫護人員。';

  @override
  String get healthSafetyAdvice => '請休息後再測；如有明顯不適，請及時諮詢醫護人員。';

  @override
  String get defaultUser => 'Saydian使用者';

  @override
  String get dailyGreeting => '今天也要保持好狀態';

  @override
  String get messages => '訊息';

  @override
  String get aiAssistant => 'AI健康管家';

  @override
  String get aiAssistantIntro => '我是您的健康管家，\n有任何健康問題都可以向我提問。';

  @override
  String get askNow => '馬上提問';

  @override
  String get remoteCare => '遠端關愛';

  @override
  String get healthLibrary => '健康百科';

  @override
  String get healthAlerts => '健康預警';

  @override
  String get shop => 'Saydian商城';

  @override
  String get connectWatch => '連接手錶';

  @override
  String get addDevice => '新增裝置';

  @override
  String get connectWatchForData => '連接手錶後可查看支援的健康資料';

  @override
  String get noHealthData => '暫無可顯示的健康資料';

  @override
  String get noData => '暫無資料';

  @override
  String get connected => '已連接';

  @override
  String get notConnected => '未連接';

  @override
  String get online => '在線';

  @override
  String get syncData => '同步資料';

  @override
  String get syncComplete => '資料同步完成';

  @override
  String get syncFailedTryAgain => '資料同步失敗，請將手錶靠近手機後重試';

  @override
  String get disconnect => '中斷連接';

  @override
  String get findWatch => '尋找手錶';

  @override
  String get watchFaces => '錶盤';

  @override
  String get deviceFeatures => '裝置功能';

  @override
  String get aboutDevice => '關於裝置';

  @override
  String get connectionHelp => '連接說明';

  @override
  String get searchNearbyWatch => '搜尋並連接附近的Saydian手錶';

  @override
  String get useWatch => '請在手錶上操作';

  @override
  String get myOrders => '我的訂單';

  @override
  String get all => '全部';

  @override
  String get awaitingPayment => '待付款';

  @override
  String get awaitingShipment => '待出貨';

  @override
  String get awaitingDelivery => '待收貨';

  @override
  String get afterSales => '售後';

  @override
  String get careMembers => '關愛成員';

  @override
  String get unitSettings => '單位設定';

  @override
  String get unitSettingsHint => '設定距離、溫度等資料單位';

  @override
  String get myServices => '我的服務';

  @override
  String get accountSettings => '帳號設定';

  @override
  String get editProfile => '編輯資料';

  @override
  String get permissions => '權限管理';

  @override
  String get feedback => '意見回饋';

  @override
  String get customerService => '聯絡客服';

  @override
  String get aboutApp => '關於我們';

  @override
  String get security => '帳號安全';

  @override
  String get goToSettings => '前往設定';

  @override
  String get close => '關閉';

  @override
  String get view => '查看';

  @override
  String get checkUpdates => '檢查更新';

  @override
  String get onlineUpdate => '線上更新';

  @override
  String get updateRequired => '需要更新後繼續使用';

  @override
  String get updateReady => '新版本已準備好';

  @override
  String get preparingUpdate => '正在準備安全更新…';

  @override
  String get openingUpdate => '正在開啟系統更新頁面…';

  @override
  String get updateAppStore => '前往 App Store 更新';

  @override
  String get updateStore => '前往應用程式商店更新';

  @override
  String get downloadAndInstall => '安全下載並安裝';

  @override
  String get gettingReady => '正在為你準備…';

  @override
  String get enableNotifications => '開啟Saydian訊息通知';

  @override
  String get notificationExplanation =>
      '用於提醒新的健康預警和關愛邀請。鎖定畫面不顯示具體健康數值，可隨時在系統設定中關閉。';

  @override
  String get notNow => '暫不開啟';

  @override
  String get enable => '開啟';

  @override
  String get newCareRequest => '收到新的關愛請求';

  @override
  String get dismissHealthAlert => '關閉健康預警';

  @override
  String get dismissCareAlert => '關閉關愛提醒';

  @override
  String get bloodPressure => '血壓';

  @override
  String get heartRate => '心率';

  @override
  String get bloodOxygen => '血氧';

  @override
  String get bloodGlucose => '血糖';

  @override
  String get bodyTemperature => '體溫';

  @override
  String get ecg => '心電';

  @override
  String get hrv => 'HRV';

  @override
  String get bodyComposition => '身體成分';

  @override
  String get bloodComposition => '血液成分';

  @override
  String get sleep => '睡眠';

  @override
  String get steps => '步數';

  @override
  String get workouts => '運動';

  @override
  String welcome(String name) {
    return '你好，$name';
  }

  @override
  String resendCode(int seconds) {
    return '$seconds秒後重傳';
  }

  @override
  String memberId(String id) {
    return '會員 ID：$id';
  }

  @override
  String unreadMessages(int count) {
    return '訊息，$count 則未讀';
  }

  @override
  String recordCount(int count) {
    return '$count 筆';
  }

  @override
  String memberCount(int count) {
    return '$count 人';
  }

  @override
  String versionBuild(String version, int build) {
    return 'V$version · 組建 $build';
  }
}
