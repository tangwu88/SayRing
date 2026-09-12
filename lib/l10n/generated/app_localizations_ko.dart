// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get scanLocationTitle => '위치 서비스를 켜 주세요';

  @override
  String get scanLocationHint =>
      '설정에서 휴대전화의 위치 서비스를 켠 후 이 화면으로 돌아와 주변 워치를 검색해 주세요.';

  @override
  String get scanPermissionTitle => '기기 접근을 허용해 주세요';

  @override
  String get scanPermissionHint => '설정에서 필요한 권한을 허용한 후 이 화면으로 돌아와 워치를 검색해 주세요.';

  @override
  String get loginProtectionTitle => '로그인 보호';

  @override
  String get verifyContactToReset => '이메일 또는 전화번호를 인증한 후 비밀번호를 재설정하세요.';

  @override
  String get workoutStartOnWatch =>
      '현재 워치는 앱에서 운동을 시작할 수 없습니다. 워치에서 직접 운동을 시작하세요.';

  @override
  String get finishWorkoutConfirm => '현재 운동을 종료할까요?';

  @override
  String get finishLeaveWorkoutHint =>
      '나가기 전에 워치 운동이 중지되고 기록된 운동 시간과 경로가 저장됩니다.';

  @override
  String get finishAndLeave => '종료하고 나가기';

  @override
  String get workoutRouteMissing =>
      '이 기록에는 휴대폰에서 기록한 경로가 없습니다. 워치 운동 데이터는 보관되어 있습니다.';

  @override
  String get workoutDuration => '운동 시간';

  @override
  String get workoutWatchHeartRate => '워치 심박수';

  @override
  String get messageSendFailed => '전송하지 못했습니다. 네트워크를 확인한 후 다시 시도하세요.';

  @override
  String get noWatchShopHint => '기기가 필요하신가요? Saydian 스토어를 둘러보세요.';

  @override
  String get notificationInAppHint =>
      '앱 내 메시지와 읽지 않음 표시는 계속 사용할 수 있습니다. 알림을 켜면 돌봄 초대와 건강 알림을 신속히 받을 수 있습니다.';

  @override
  String get healthAlertSafetyHint =>
      '건강 알림은 신속한 안내를 위한 것이며 의학적 진단이 아닙니다. 뚜렷한 불편함이 느껴지면 신속히 진료를 받으세요.';

  @override
  String get afterSalesService => '구매 후 서비스';

  @override
  String get afterSalesApplyHint =>
      '대상 상품을 선택하고 사유와 신청 금액을 입력하세요. 제출 후 주문 목록에서 처리 상태를 확인할 수 있습니다.';

  @override
  String get afterSalesAlreadySubmitted =>
      '이 상품은 이미 구매 후 서비스가 신청되었습니다. 스토어 담당자의 처리를 기다려 주세요.';

  @override
  String get afterSalesType => '신청 유형';

  @override
  String get requestedAmount => '신청 금액';

  @override
  String get afterSalesReason => '신청 사유';

  @override
  String get describeProblem => '발생한 문제를 설명해 주세요';

  @override
  String get amountPaid => '실제 결제 금액';

  @override
  String get orderDetailsLoadFailed => '주문 상세 정보를 불러오지 못했습니다. 잠시 후 다시 시도하세요.';

  @override
  String get confirmItemReceived => '상품을 받으셨나요?';

  @override
  String get confirmReceiptHint =>
      '수령을 확인하면 주문이 완료됩니다. 아직 상품을 받지 않았다면 확인하지 마세요.';

  @override
  String get notConfirmYet => '아직 아니요';

  @override
  String get unitChangesHint => '단위 변경은 즉시 적용됩니다. 앱을 다시 설치하면 재설정이 필요할 수 있습니다.';

  @override
  String get goalSettingsTitle => '목표 설정';

  @override
  String get dailyStepGoalField => '일일 걸음 수 목표(걸음)';

  @override
  String get dailyDistanceGoalField => '일일 거리 목표(km)';

  @override
  String get dailyCalorieGoalField => '일일 칼로리 목표(kcal)';

  @override
  String get saveGoals => '목표 저장';

  @override
  String get viewAccountAddresses => '계정에 등록된 배송지 확인';

  @override
  String get loadingProfile => '프로필 불러오는 중…';

  @override
  String get profileSaveExplanation =>
      '저장을 누르면 사진과 프로필이 계정에 저장되어 내 프로필과 돌봄 멤버 식별에 사용됩니다.';

  @override
  String get contactPhoneLabel => '연락처 전화번호';

  @override
  String get wechatOfficialAccount => 'WeChat 공식 계정';

  @override
  String get addSupportContact => '고객 지원 연락처 추가';

  @override
  String get contactPreparationHint => '문의 전에 기기 모델과 문제가 발생한 시간을 준비해 주세요.';

  @override
  String get supportPrivacyWarning =>
      '공식 계정이 아닌 곳에 인증 코드, 비밀번호 또는 전체 건강 기록을 보내지 마세요.';

  @override
  String get brandHealthTitle => 'Saydian 건강';

  @override
  String get accountAndSecurity => '계정 및 보안';

  @override
  String get cityNameLabel => '도시 이름';

  @override
  String get cityNameExample => '예: 서울';

  @override
  String get visitStoreHint => '스토어에서 나에게 맞는 건강 기기를 찾아보세요.';

  @override
  String get selectReportPlan => '보고서 요금제 선택';

  @override
  String get reportPaidContentHint =>
      '뚜렷한 이상에 대한 알림은 무료입니다. 유료 콘텐츠에는 더 자세한 추세 요약과 일상적인 건강 관리 제안이 포함됩니다.';

  @override
  String get wechatPayLabel => 'WeChat Pay';

  @override
  String get alipayLabel => 'Alipay';

  @override
  String get reportPurchaseTerms =>
      '구매 전에 요금제와 가격을 확인하세요. 건강 멤버십은 자동 갱신되지 않으며 만료 후 미사용 횟수는 이월되지 않습니다.';

  @override
  String get detailedHealthReport => '상세 건강 보고서';

  @override
  String get reportInsufficientDataHint =>
      '데이터가 부족하면 결제 주문이 생성되지 않습니다. 워치를 평소대로 착용하고 데이터를 동기화한 후 다시 시도하세요.';

  @override
  String get waitingPaymentConfirmation => '결제 확인 대기 중';

  @override
  String get paymentReturnRefreshHint =>
      '결제 후 이 화면으로 돌아와 새로고침하세요. 결제가 확인되면 사용 가능한 횟수가 업데이트됩니다.';

  @override
  String get reportPurchaseDataMissing => '아직 데이터가 부족하여 구매할 수 없습니다.';

  @override
  String get heartRateUpperLimit => '심박수 상한';

  @override
  String get systolicUpperLimit => '수축기 혈압 상한';

  @override
  String get diastolicUpperLimit => '이완기 혈압 상한';

  @override
  String get temperatureUpperLimit => '체온 상한';

  @override
  String get calibrateOnWatchHint => '워치의 안내에 따라 보정을 완료하세요.';

  @override
  String get spotCheckCuffHint =>
      '이번 측정은 안정 상태의 단회 측정이며 참고용입니다. 더 정확한 수치가 필요한 경우 워치의 펌프·커프 측정 기능을 이용하세요.';

  @override
  String get setHealthUpperLimits => '건강 수치 상한 알림 설정';

  @override
  String get healthUpperLimitHint => '수치가 설정한 상한을 넘으면 알려드립니다.';

  @override
  String get heartRateAlertLabel => '심박수 알림';

  @override
  String get heartRateAlertHint => '심박수가 설정한 상한을 넘으면 알림';

  @override
  String get bloodPressureAlertLabel => '혈압 알림';

  @override
  String get bloodPressureAlertHint => '수축기 또는 이완기 혈압이 설정한 상한을 넘으면 알림';

  @override
  String get temperatureAlertLabel => '체온 알림';

  @override
  String get temperatureAlertHint => '체온이 설정한 상한을 넘으면 알림';

  @override
  String get saveHealthAlerts => '알림 설정 저장';

  @override
  String get healthAlertHistory => '알림 내역';

  @override
  String get seekProfessionalCare => '뚜렷한 불편함이 느껴지면 신속히 의료 전문가와 상담하세요.';

  @override
  String get watchHealthReference => '워치 측정 결과는 일상적인 건강 관리 참고용입니다.';

  @override
  String get calibrationReferenceHint => '전문 측정 기기로 방금 측정한 수치를 사용하세요.';

  @override
  String get calibrationWearerHint =>
      '보정값은 현재 착용자에게만 적용됩니다. 착용자가 바뀌면 보정을 끄거나 다시 보정하세요.';

  @override
  String get enableCalibration => '보정 사용';

  @override
  String get calibrationDisabledHint => '끄면 워치의 일반 측정 모드로 돌아갑니다.';

  @override
  String get diastolicLowerLabel => '이완기 혈압(낮은 수치)';

  @override
  String get longTermTrendHint => '장기적인 추세를 보면 더 유용한 참고가 됩니다.';

  @override
  String get measurementVariationHint =>
      '단회 측정은 착용 상태, 운동 및 환경의 영향을 받을 수 있습니다. 몸이 불편하면 의료 전문가와 상담하세요.';

  @override
  String get ecgDetailTitle => '심전도 상세';

  @override
  String get viewFullReport => '전체 보고서 보기';

  @override
  String get ecgReferenceHint => '심전도 결과는 건강 관리 참고용입니다.';

  @override
  String get ecgVariationSafety =>
      '단회 측정은 착용 상태, 운동 및 환경의 영향을 받으며 의학적 진단을 대신할 수 없습니다. 몸이 불편하면 신속히 진료를 받으세요.';

  @override
  String get ecgBasicOnly => '이번 측정에서는 기본 심전도 데이터만 반환되었습니다.';

  @override
  String get measurementIndicators => '측정 지표';

  @override
  String get riskIndicatorsMissing => '이번 측정에서는 워치가 위험 지표를 반환하지 않았습니다.';

  @override
  String get riskAnalysisTitle => '위험 분석';

  @override
  String get watchAlgorithmReference => '아래 수치는 워치 알고리즘에서 산출되었으며 건강 추세 참고용입니다.';

  @override
  String get ecgHealthReport => '심전도 건강 보고서';

  @override
  String get brandedEcgReport => 'Saydian · 심전도 건강 보고서';

  @override
  String get ecgReportSafety =>
      '안내: 이 보고서는 워치 측정 데이터를 바탕으로 작성되었습니다. 건강 관리 참고용이며 의사의 진단을 대신할 수 없습니다.';

  @override
  String get installedWatchFaces => '설치된 워치 페이스';

  @override
  String get switchInstalledWatchFace => '워치에 이미 설치된 페이스로 변경할 수 있습니다.';

  @override
  String get useSelectedWatchFace => '사용';

  @override
  String get downloadUseWatchFace => '눌러서 다운로드 및 사용';

  @override
  String get photoWatchFaceHint => '선명한 사진을 선택하고 미리보기를 확인한 후 워치로 전송하세요.';

  @override
  String get timeDisplayPosition => '시간 표시 위치';

  @override
  String get transferSetWatchFace => '전송하고 워치 페이스로 설정';

  @override
  String get watchTransferKeepNear => '전송 중에는 워치를 휴대폰 가까이에 두고 이 화면을 유지하세요.';

  @override
  String get callMediaAudio => '통화 및 미디어 소리';

  @override
  String get useCelsius => '섭씨 사용';

  @override
  String get sosContactHint =>
      '워치에서 SOS가 작동하면 여기서 선택한 사람에게 우선 연락합니다. 평소 자주 연락하는 가족을 선택하세요.';

  @override
  String get noHealthAssessments => '현재 워치에는 설정 가능한 보조 평가가 없습니다.';

  @override
  String get modelFeaturesVary => '지원 기능은 모델에 따라 다릅니다. 워치에 실제 표시되는 기능을 확인하세요.';

  @override
  String get assessmentEnabledHint => '켜면 워치가 일상적인 추세 정보를 제공합니다.';

  @override
  String get assessmentSafety => '보조 평가는 일상적인 건강 관리 참고용이며 진단이나 치료용이 아닙니다.';

  @override
  String get autoMonitorIntervalHint => '켜면 워치가 설정된 주기에 따라 자동으로 측정합니다.';

  @override
  String get watchHeartRateAlert => '워치 심박수 알림';

  @override
  String get sustainedLimitWatchAlert => '수치가 상한을 계속 넘으면 워치가 알려드립니다.';

  @override
  String get ecgWaveformTitle => '심전도 파형';

  @override
  String get ecgWaveformMissing => '이번 측정에서는 유효한 심전도 파형이 반환되지 않았습니다.';

  @override
  String get ecgElectrodeHint =>
      '심박수 및 HRV 결과는 계속 확인할 수 있습니다. 다음 측정 시에는 워치 전극에 계속 접촉해 주세요.';

  @override
  String get screenAutoTimeHint => '워치가 시간에 따라 자동으로 조절합니다.';

  @override
  String get raiseWristScreenHint => '손목을 들면 화면이 켜집니다.';

  @override
  String get watchHighHeartRate => '높은 심박수 알림';

  @override
  String get watchThresholdHint => '상한에 도달하면 워치가 알려드립니다.';

  @override
  String get watchMeasurementSafety => '측정 결과는 건강 관리 참고용이며 진단이나 치료용이 아닙니다.';

  @override
  String get healthDataExplanation => '건강 데이터 안내';

  @override
  String get trendUnavailable => '현재 추세를 표시할 수 없습니다.';

  @override
  String get recentData => '최근 데이터';

  @override
  String get trendReferenceOnly => '추세는 일상적인 건강 관리 참고용입니다.';

  @override
  String get trendVariationSafety =>
      '단회 및 기간별 변화는 착용 상태, 운동, 환경의 영향을 받을 수 있으며 의학적 진단을 대신하지 않습니다.';

  @override
  String get watchFaceDownloadHint =>
      '다운로드 후 워치 페이스가 워치로 전송됩니다. 전송 중에는 워치를 휴대폰 가까이에 두고 이 화면을 유지하세요.';

  @override
  String get refreshWatchFaces => '워치 페이스 새로고침';

  @override
  String get openTestFlight => 'TestFlight 열기';

  @override
  String get articlesEmpty => '이 카테고리에는 아직 글이 없습니다.';

  @override
  String get articlesUnavailable => '건강 백과를 불러올 수 없습니다.';

  @override
  String get articleContentUnavailable => '아직 글 내용을 표시할 수 없습니다.';

  @override
  String get imageUnavailable => '이미지를 불러올 수 없습니다.';

  @override
  String get allowNotifications => '알림 허용';

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get analysisConsentUnavailable =>
      '건강 분석은 아직 사용할 수 없습니다. 기존 보고서는 계속 확인할 수 있습니다.';

  @override
  String get analysisReadAgree => '위 건강 분석 안내를 읽었으며 동의합니다.';

  @override
  String get agreeContinue => '동의하고 계속';

  @override
  String get notGrantNow => '나중에';

  @override
  String get analysisConsentSaved => '건강 분석 동의가 저장되었습니다.';

  @override
  String get withdrawAnalysisConsent => '건강 분석 동의를 철회할까요?';

  @override
  String get withdrawAnalysisExplanation =>
      '새 상세 보고서가 생성되지 않습니다. 이미 생성되었고 환불되지 않은 보고서는 계속 확인할 수 있습니다.';

  @override
  String get confirmWithdraw => '철회 확인';

  @override
  String get analysisConsentWithdrawn => '건강 분석 동의를 철회했습니다.';

  @override
  String get consentGrantedHint => '동의했습니다. 언제든지 철회할 수 있습니다.';

  @override
  String get consentNeededHint => '상세 보고서를 생성하기 전에 별도 동의가 필요합니다.';

  @override
  String get withdraw => '철회';

  @override
  String get reportHistory => '보고서 내역';

  @override
  String get saving => '저장 중…';

  @override
  String get pauseWorkout => '운동 일시 정지';

  @override
  String get resumeWorkout => '운동 계속';

  @override
  String get finishWorkout => '운동 종료';

  @override
  String get watchDistance => '워치 거리';

  @override
  String get watchSteps => '워치 걸음 수';

  @override
  String get liveHeartRate => '실시간 심박수';

  @override
  String get watchCalories => '워치 칼로리';

  @override
  String get connectForWorkout => '먼저 기기 화면에서 워치를 연결하세요. 워치가 운동을 기록합니다.';

  @override
  String latestVersion(String version) {
    return '최신 버전 V$version을 사용하고 있습니다';
  }

  @override
  String workoutPaused(String mode) {
    return '$mode 일시 정지됨';
  }

  @override
  String workoutInProgress(String mode) {
    return '$mode 진행 중';
  }

  @override
  String workoutReady(String mode) {
    return '$mode 시작 준비';
  }

  @override
  String startWorkout(String mode) {
    return '$mode 시작';
  }

  @override
  String finishOtherWorkout(String mode) {
    return '먼저 $mode을(를) 종료하세요';
  }

  @override
  String workoutDetails(String mode) {
    return '$mode 상세';
  }

  @override
  String stepCount(int count) {
    return '$count 걸음';
  }

  @override
  String get globalShopPricePending => '가격 확인 중';

  @override
  String get globalShopLoadMore => '더 보기';

  @override
  String get globalShopReadOnly => '상품을 둘러볼 수 있습니다. 이 지역에서는 아직 주문할 수 없습니다.';

  @override
  String get appName => 'Saydian';

  @override
  String get searchingNearby => '주변 워치 검색 중';

  @override
  String get noDevices => '기기를 찾지 못했습니다';

  @override
  String get selectWatch => '이름과 신호 세기를 확인한 후 워치를 선택하세요';

  @override
  String get searchingHint => '검색 중입니다. 목록 위치는 그대로이고 신호 세기만 갱신됩니다.';

  @override
  String get activateWatch => '워치를 충전해 활성화한 후 휴대전화 가까이에 두세요';

  @override
  String get checkWatchConnection =>
      '이 휴대전화의 블루투스 설정이나 다른 휴대전화에 연결되어 있으면 먼저 연결을 해제한 후 다시 검색하세요';

  @override
  String get running => '달리기';

  @override
  String get walking => '걷기';

  @override
  String get cycling => '자전거';

  @override
  String get hiking => '하이킹';

  @override
  String get mountaineering => '등산';

  @override
  String metricAnalysis(String metric) {
    return '$metric 분석';
  }

  @override
  String metricAllData(String metric) {
    return '전체 $metric 데이터';
  }

  @override
  String metricMeasurement(String metric) {
    return '$metric 측정';
  }

  @override
  String metricCalibration(String metric) {
    return '$metric 보정';
  }

  @override
  String metricDetails(String metric) {
    return '$metric 상세';
  }

  @override
  String get add => '추가';

  @override
  String get endTime => '종료 시간';

  @override
  String get reminderInterval => '알림 간격';

  @override
  String get reminderName => '알림 이름';

  @override
  String get repeat => '반복';

  @override
  String get addAlarm => '알람 추가';

  @override
  String get alarmTime => '알림 시간';

  @override
  String get enableAlarm => '알람 켜기';

  @override
  String get emergencyContact => 'SOS 긴급 연락처';

  @override
  String get selectEmergencyContact => 'SOS 연락처 선택';

  @override
  String get confirmEmergencyContact => 'SOS 연락처로 설정';

  @override
  String get addWorldClock => '세계 시계 추가';

  @override
  String get autoBrightness => '자동 밝기';

  @override
  String get raiseToWake => '손목을 들어 화면 켜기';

  @override
  String get activeTime => '적용 시간';

  @override
  String get saveSettings => '설정 저장';

  @override
  String get helpFeedback => '도움말 및 의견';

  @override
  String get issueType => '문제 유형';

  @override
  String get issueDescription => '문제 설명';

  @override
  String get describeIssue => '문제와 재현 단계를 설명해 주세요';

  @override
  String get contactOptional => '연락처(선택)';

  @override
  String get phoneOrEmail => '전화번호 또는 이메일';

  @override
  String get call => '전화 걸기';

  @override
  String get addContact => '연락처 추가';

  @override
  String get contactName => '이름';

  @override
  String get contactPhone => '전화번호';

  @override
  String get cart => '장바구니';

  @override
  String get searchProducts => '상품 검색';

  @override
  String get selectVariant => '옵션을 선택하세요';

  @override
  String get variant => '옵션';

  @override
  String get buyNow => '바로 구매';

  @override
  String get cartEmpty => '장바구니가 비어 있습니다';

  @override
  String get returnShop => '스토어로 돌아가기';

  @override
  String get selectAll => '전체 선택';

  @override
  String get checkout => '결제하기';

  @override
  String get clearCart => '장바구니를 비우시겠습니까?';

  @override
  String get clearCartHint => '장바구니의 모든 상품이 삭제됩니다.';

  @override
  String get viewOrder => '주문 보기';

  @override
  String get confirmOrder => '주문 확인';

  @override
  String get productInfo => '상품 정보';

  @override
  String get orderNote => '메모';

  @override
  String get noteToSeller => '판매자에게 메모 남기기';

  @override
  String get paymentCheckout => '결제';

  @override
  String get orderTotal => '주문 합계';

  @override
  String get selectPayment => '결제 수단 선택';

  @override
  String get refreshOrder => '주문 상태 새로고침';

  @override
  String get viewMyOrders => '내 주문 보기';

  @override
  String get backToProduct => '상품 상세로 돌아가기';

  @override
  String get newAddress => '주소 추가';

  @override
  String get recipient => '수령인';

  @override
  String get province => '주/도';

  @override
  String get district => '구/군';

  @override
  String get streetAddress => '상세 주소';

  @override
  String get defaultAddress => '기본 배송지로 설정';

  @override
  String get shippingInfo => '배송 정보';

  @override
  String get restorePurchases => '구매 복원';

  @override
  String get paymentMethod => '결제 수단';

  @override
  String get refresh => '새로고침';

  @override
  String get useWatchFace => '이 워치 페이스를 사용하시겠습니까?';

  @override
  String get downloadAndUse => '다운로드하여 사용';

  @override
  String get watchFaceFailed => '워치 페이스를 설정하지 못했습니다';

  @override
  String get statusNormal => '정상';

  @override
  String get statusRecorded => '기록됨';

  @override
  String get statusAttention => '측정값 확인';

  @override
  String get statusOutOfRange => '참고 범위 밖';

  @override
  String get statusLow => '낮음';

  @override
  String get statusHigh => '높음';

  @override
  String get careInviteHint => '이메일 또는 국제 전화번호로 Saydian 국제판 계정을 초대하세요.';

  @override
  String get careSharingHint => '선택한 측정 항목만 공유됩니다. 언제든지 공유를 중지할 수 있습니다.';

  @override
  String get carePending => '대기 중';

  @override
  String get careActive => '활성';

  @override
  String get careClosed => '종료됨';

  @override
  String get accept => '수락';

  @override
  String get decline => '거절';

  @override
  String get stopSharing => '공유 중지';

  @override
  String get sharedMeasurements => '공유 측정 항목';

  @override
  String get invitationSent => '초대를 보냈습니다';

  @override
  String get invalidCareContact => '이메일 또는 국가 코드가 포함된 전화번호를 입력하세요.';

  @override
  String get carePermissionDenied => '이 측정 항목은 나에게 공유되지 않았습니다.';

  @override
  String get reload => '다시 불러오기';

  @override
  String get applyAfterSales => '판매 후 지원 신청';

  @override
  String get analysisConsent => '건강 분석 동의';

  @override
  String get workoutRecords => '운동 기록';

  @override
  String get startTime => '시작 시간';

  @override
  String get addCare => '돌봄 구성원 추가';

  @override
  String get confirmReceipt => '수령 확인';

  @override
  String get personalInfo => '개인 정보';

  @override
  String get deliveryAddresses => '배송지';

  @override
  String get readAgain => '다시 읽기';

  @override
  String get smsCode => '문자 인증 코드';

  @override
  String get watchFaceShop => '워치 페이스 스토어';

  @override
  String get selectCity => '도시 선택';

  @override
  String get city => '도시';

  @override
  String get confirm => '확인';

  @override
  String get productDetails => '상품 상세';

  @override
  String get clear => '비우기';

  @override
  String get settings => '설정';

  @override
  String get goals => '목표';

  @override
  String get send => '보내기';

  @override
  String get typeMessage => '메시지를 입력하세요…';

  @override
  String get devicesFound => '발견된 기기';

  @override
  String get connect => '연결';

  @override
  String get searchAgain => '다시 검색';

  @override
  String get searchRecovery =>
      '워치를 가까이 두세요. 시스템 블루투스나 다른 휴대전화에 연결되어 있다면 먼저 해제한 후 다시 시도하세요.';

  @override
  String get deviceName => '기기 이름';

  @override
  String get deviceModel => '기기 모델';

  @override
  String get connectionStatus => '연결 상태';

  @override
  String get firmwareVersion => '펌웨어 버전';

  @override
  String get watchBattery => '워치 배터리';

  @override
  String get chargingStatus => '충전 상태';

  @override
  String get messageDetails => '메시지 상세';

  @override
  String get dailySummary => '일일 요약';

  @override
  String get remoteMemberData => '돌봄 구성원 데이터';

  @override
  String get ecgWaveformUnavailable => '표시할 심전도 파형이 없습니다';

  @override
  String get orderDetails => '주문 상세';

  @override
  String get viewShipping => '배송 조회';

  @override
  String get measureAgain => '다시 측정';

  @override
  String get checkPaymentStatus => '결제 상태 확인';

  @override
  String get deleteAccount => '계정 삭제';

  @override
  String get confirmDeleteAccountTitle => '계정을 삭제하시겠습니까?';

  @override
  String get deleteAccountHint => '계정과 관련 데이터가 삭제되면 이 기기에서 로그아웃됩니다.';

  @override
  String get confirmDelete => '삭제 확인';

  @override
  String get exit => '나가기';

  @override
  String get nickname => '닉네임';

  @override
  String get gender => '성별';

  @override
  String get birthDate => '생년월일';

  @override
  String get heightCm => '키(cm)';

  @override
  String get weightKg => '몸무게(kg)';

  @override
  String get choose => '선택하세요';

  @override
  String get connectWatchToUse => '워치를 연결한 후 이용하세요';

  @override
  String get selectPhoto => '사진 선택';

  @override
  String get saved => '저장됨';

  @override
  String get saveChanges => '변경 사항 저장';

  @override
  String get notificationsOff => '시스템 알림이 꺼져 있습니다';

  @override
  String get privacyAgreement => '개인정보 처리방침';

  @override
  String get appPermissions => '앱 권한';

  @override
  String get openSystemSettings => '시스템 앱 설정 열기';

  @override
  String get monitoringHint => '워치를 연결하면 설정 가능한 건강 모니터링 항목이 표시됩니다.';

  @override
  String get previewUnavailable => '미리보기를 사용할 수 없습니다';

  @override
  String get distance => '거리';

  @override
  String get calories => '칼로리';

  @override
  String get healthProfile => '건강 프로필';

  @override
  String get photoWatchFace => '사진 워치 페이스';

  @override
  String get cameraRemote => '카메라 리모컨';

  @override
  String get phoneCalls => '통화';

  @override
  String get contacts => '연락처';

  @override
  String get notifications => '알림';

  @override
  String get alarms => '알람';

  @override
  String get weather => '날씨';

  @override
  String get worldClock => '세계 시계';

  @override
  String get healthReminders => '건강 리마인더';

  @override
  String get healthMonitoring => '건강 모니터링';

  @override
  String get healthAssessment => '건강 평가';

  @override
  String get screenDisplay => '화면 표시';

  @override
  String get scanning => '검색 중…';

  @override
  String get connecting => '연결 중…';

  @override
  String get waitingConfirmation => '확인 대기';

  @override
  String get syncing => '동기화 중…';

  @override
  String get measuring => '측정 중…';

  @override
  String get needsAttention => '확인 필요';

  @override
  String get tapToOpen => '눌러서 열기';

  @override
  String get deviceInfoHint => '기기 정보 보기';

  @override
  String get connectionInstructions =>
      '1. 블루투스를 켜고 주변 기기 접근을 허용하세요.\n2. 워치를 충전하고 휴대전화 가까이에 두세요.\n3. 기기 검색을 눌러 본인의 워치를 선택하세요.\n4. 워치에 확인 요청이 표시되면 승인하세요.';

  @override
  String get syncNearbyHint => '연결하거나 동기화할 때 워치를 충분히 충전하고 휴대전화 가까이에 두세요.';

  @override
  String get invalidCode => '코드를 확인하고 다시 시도하세요';

  @override
  String get codeExpired => '코드가 만료되었습니다. 새 코드를 요청하세요.';

  @override
  String get tooManyAttempts => '시도 횟수가 너무 많습니다. 잠시 후 다시 시도하세요.';

  @override
  String get readTerms => '계속하려면 이용약관과 개인정보 처리방침을 읽어 주세요';

  @override
  String verificationSentTo(String contact) {
    return '$contact(으)로 코드를 보냈습니다';
  }

  @override
  String get addSmartDevice => '스마트 기기 추가';

  @override
  String get watchNearbyHint => '블루투스를 켜고 워치를 휴대전화 가까이에 두세요';

  @override
  String get startSearch => '기기 검색';

  @override
  String get readingData => '데이터 읽는 중…';

  @override
  String get readingCapabilities => '워치 기능 확인 중…';

  @override
  String get capabilitiesHint => '이 워치에서 사용할 수 있는 기능만 표시됩니다';

  @override
  String get capabilitiesFailed => '워치 기능을 읽지 못했습니다';

  @override
  String get keepWatchNear => '워치를 휴대전화 가까이에 두고 다시 시도하세요';

  @override
  String get personalizeWatch => '워치 페이스 및 꾸미기';

  @override
  String get signInCloudHint => '로그인하고 클라우드 건강 서비스를 이용하세요';

  @override
  String get aiQuestion => 'AI에 질문';

  @override
  String get aiQuestionHint => 'AI 도우미에게 건강 관리에 관해 물어보세요';

  @override
  String get language => '언어';

  @override
  String get signIn => '로그인';

  @override
  String get signUp => '회원가입';

  @override
  String get signOut => '로그아웃';

  @override
  String get email => '이메일';

  @override
  String get phoneNumber => '전화번호';

  @override
  String get countryRegion => '국가 또는 지역';

  @override
  String get password => '비밀번호';

  @override
  String get confirmPassword => '비밀번호 확인';

  @override
  String get verificationCode => '인증 코드';

  @override
  String get sendCode => '코드 받기';

  @override
  String get forgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get resetPassword => '비밀번호 재설정';

  @override
  String get createAccount => '계정 만들기';

  @override
  String get continueAction => '계속';

  @override
  String get back => '뒤로';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get retry => '다시 시도';

  @override
  String get loading => '불러오는 중…';

  @override
  String get pleaseWait => '잠시 기다려 주세요…';

  @override
  String get emailOrPhone => '이메일 또는 전화번호';

  @override
  String get enterEmail => '이메일 주소를 입력하세요';

  @override
  String get enterPhone => '전화번호를 입력하세요';

  @override
  String get enterPassword => '비밀번호를 입력하세요';

  @override
  String get passwordRequirement =>
      '8자 이상 입력하세요. 영문과 숫자는 최대 72자이며, 다른 문자는 허용 길이가 더 짧습니다.';

  @override
  String get passwordMismatch => '비밀번호가 일치하지 않습니다';

  @override
  String get invalidEmail => '올바른 이메일 주소를 입력하세요';

  @override
  String get invalidPhone => '국가 코드와 전화번호를 확인하세요';

  @override
  String get codeSent => '코드를 보냈습니다. 메시지를 확인하세요.';

  @override
  String get codeRequired => '인증 코드를 입력하세요';

  @override
  String get consentRequired => '이용약관과 개인정보 처리방침을 읽고 동의해 주세요';

  @override
  String get agreeToTerms => '다음을 읽고 동의합니다:';

  @override
  String get termsOfService => '이용약관';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get registrationUnavailable => '현재 회원가입을 이용할 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String get loginFailed => '로그인하지 못했습니다. 입력 정보를 확인하고 다시 시도하세요.';

  @override
  String get accountAlreadyExists => '이미 등록된 계정입니다. 로그인해 주세요.';

  @override
  String get networkUnavailable => '인터넷 연결을 확인하고 다시 시도하세요';

  @override
  String get serviceUnavailable => '현재 이 기능을 이용할 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String get accountCreated => '계정이 생성되었습니다';

  @override
  String get passwordReset => '비밀번호가 변경되었습니다';

  @override
  String get haveAccount => '이미 계정이 있으신가요?';

  @override
  String get noAccount => 'Saydian이 처음이신가요?';

  @override
  String get showPassword => '비밀번호 표시';

  @override
  String get hidePassword => '비밀번호 숨기기';

  @override
  String get selectCountry => '국가 또는 지역 선택';

  @override
  String get registrationMethod => '가입 방법';

  @override
  String get changeLanguageFailed => '언어를 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get health => '건강';

  @override
  String get device => '기기';

  @override
  String get profile => '내 정보';

  @override
  String get healthData => '건강 데이터';

  @override
  String get allData => '전체 데이터';

  @override
  String get healthRecords => '건강 기록';

  @override
  String get workoutsAndRecords => '운동 및 기록';

  @override
  String get healthDisclaimer => '측정 결과는 건강 관리 참고용입니다. 몸이 불편하면 의료 전문가와 상담하세요.';

  @override
  String get healthSafetyAdvice => '휴식 후 다시 측정하세요. 몸이 불편하면 의료진과 상담하세요.';

  @override
  String get defaultUser => 'Saydian 사용자';

  @override
  String get dailyGreeting => '오늘도 건강한 하루 보내세요';

  @override
  String get messages => '메시지';

  @override
  String get aiAssistant => 'AI 건강 도우미';

  @override
  String get aiAssistantIntro => '건강 관리에 관해 궁금한 점을 물어보세요.';

  @override
  String get askNow => '지금 질문하기';

  @override
  String get remoteCare => '가족 돌봄';

  @override
  String get healthLibrary => '건강 정보';

  @override
  String get healthAlerts => '건강 알림';

  @override
  String get shop => '스토어';

  @override
  String get connectWatch => '워치 연결';

  @override
  String get addDevice => '기기 추가';

  @override
  String get connectWatchForData => '워치를 연결하면 지원되는 건강 데이터를 확인할 수 있습니다';

  @override
  String get noHealthData => '아직 표시할 건강 데이터가 없습니다';

  @override
  String get noData => '아직 데이터가 없습니다';

  @override
  String get connected => '연결됨';

  @override
  String get notConnected => '연결되지 않음';

  @override
  String get online => '온라인';

  @override
  String get syncData => '데이터 동기화';

  @override
  String get syncComplete => '데이터를 동기화했습니다';

  @override
  String get syncFailedTryAgain => '동기화하지 못했습니다. 워치를 휴대전화 가까이에 두고 다시 시도하세요.';

  @override
  String get disconnect => '연결 해제';

  @override
  String get findWatch => '워치 찾기';

  @override
  String get watchFaces => '워치 페이스';

  @override
  String get deviceFeatures => '기기 기능';

  @override
  String get aboutDevice => '기기 정보';

  @override
  String get connectionHelp => '연결 도움말';

  @override
  String get searchNearbyWatch => '주변 Saydian 워치를 찾아 연결하세요';

  @override
  String get useWatch => '워치에서 조작해 주세요';

  @override
  String get myOrders => '내 주문';

  @override
  String get all => '전체';

  @override
  String get awaitingPayment => '결제 대기';

  @override
  String get awaitingShipment => '배송 준비';

  @override
  String get awaitingDelivery => '수령 대기';

  @override
  String get afterSales => '반품 및 지원';

  @override
  String get careMembers => '돌봄 구성원';

  @override
  String get unitSettings => '단위 설정';

  @override
  String get unitSettingsHint => '거리, 온도 등의 단위를 설정하세요';

  @override
  String get myServices => '내 서비스';

  @override
  String get accountSettings => '계정 설정';

  @override
  String get editProfile => '프로필 편집';

  @override
  String get permissions => '권한 관리';

  @override
  String get feedback => '의견 보내기';

  @override
  String get customerService => '고객 지원';

  @override
  String get aboutApp => 'Saydian 정보';

  @override
  String get security => '계정 보안';

  @override
  String get goToSettings => '설정 열기';

  @override
  String get close => '닫기';

  @override
  String get view => '보기';

  @override
  String get checkUpdates => '업데이트 확인';

  @override
  String get onlineUpdate => '앱 업데이트';

  @override
  String get updateRequired => '계속하려면 업데이트하세요';

  @override
  String get updateReady => '새 버전을 사용할 수 있습니다';

  @override
  String get preparingUpdate => '안전한 업데이트 준비 중…';

  @override
  String get openingUpdate => '시스템 업데이트 화면을 여는 중…';

  @override
  String get updateAppStore => 'App Store에서 업데이트';

  @override
  String get updateStore => '앱 스토어에서 업데이트';

  @override
  String get downloadAndInstall => '안전하게 다운로드 및 설치';

  @override
  String get gettingReady => '준비 중입니다…';

  @override
  String get enableNotifications => 'Saydian 알림 켜기';

  @override
  String get notificationExplanation =>
      '건강 알림과 돌봄 초대를 받습니다. 잠금 화면에는 건강 수치가 표시되지 않으며 시스템 설정에서 알림을 끌 수 있습니다.';

  @override
  String get notNow => '나중에';

  @override
  String get enable => '켜기';

  @override
  String get newCareRequest => '새 돌봄 요청';

  @override
  String get dismissHealthAlert => '건강 알림 닫기';

  @override
  String get dismissCareAlert => '돌봄 알림 닫기';

  @override
  String get bloodPressure => '혈압';

  @override
  String get heartRate => '심박수';

  @override
  String get bloodOxygen => '혈중 산소';

  @override
  String get bloodGlucose => '혈당';

  @override
  String get bodyTemperature => '체온';

  @override
  String get ecg => '심전도';

  @override
  String get hrv => 'HRV';

  @override
  String get bodyComposition => '체성분';

  @override
  String get bloodComposition => '혈액 성분';

  @override
  String get sleep => '수면';

  @override
  String get steps => '걸음 수';

  @override
  String get workouts => '운동';

  @override
  String welcome(String name) {
    return '안녕하세요, $name';
  }

  @override
  String resendCode(int seconds) {
    return '$seconds초 후 다시 보내기';
  }

  @override
  String memberId(String id) {
    return '회원 ID: $id';
  }

  @override
  String unreadMessages(int count) {
    return '메시지, 읽지 않음 $count개';
  }

  @override
  String recordCount(int count) {
    return '$count개 기록';
  }

  @override
  String memberCount(int count) {
    return '$count명';
  }

  @override
  String versionBuild(String version, int build) {
    return 'V$version · 빌드 $build';
  }

  @override
  String get globalShopBrowseNotice =>
      '상품은 계속 둘러볼 수 있습니다. 배송 지역에서 배송과 결제를 이용할 수 있을 때 주문이 열립니다.';

  @override
  String get shopAccount => '쇼핑 계정';

  @override
  String get addToCart => '장바구니에 담기';

  @override
  String get addedToCart => '장바구니에 담았습니다';

  @override
  String get quantity => '수량';

  @override
  String get inStock => '재고 있음';

  @override
  String get outOfStock => '품절 또는 이용 불가';

  @override
  String get favorites => '찜한 상품';

  @override
  String get coupons => '쿠폰';

  @override
  String get points => '포인트';

  @override
  String get helpCenter => '도움말';

  @override
  String get chooseDeliveryAddress => '배송지 선택';

  @override
  String get editAddress => '주소 수정';

  @override
  String get delete => '삭제';

  @override
  String get deleteAddressPrompt => '이 주소를 삭제할까요?';

  @override
  String get postalCode => '우편번호';

  @override
  String get itemsSubtotal => '상품 소계';

  @override
  String get discount => '할인';

  @override
  String get shippingFee => '배송비';

  @override
  String get amountDue => '결제 금액';

  @override
  String get placeOrder => '주문하기';

  @override
  String get orderPlaced => '주문이 접수되었습니다';

  @override
  String get orderSubmissionUncertain =>
      '주문 결과를 확인할 수 없습니다. 다시 시도하기 전에 내 주문을 확인해 주세요.';

  @override
  String get availableCoupons => '사용 가능한 쿠폰';

  @override
  String get ownedCoupons => '내 쿠폰';

  @override
  String get couponCode => '쿠폰 코드';

  @override
  String get redeem => '사용';

  @override
  String get claim => '받기';

  @override
  String get claimed => '받음';

  @override
  String get pointsBalance => '포인트 잔액';

  @override
  String get pointsUnavailable => '잔액을 아직 확인할 수 없습니다';

  @override
  String get marketUnavailable => '선택한 배송 지역에서는 아직 주문할 수 없습니다.';

  @override
  String get paymentUnavailable =>
      '현재 앱에서 결제할 수 없습니다. 장바구니와 기존 주문은 계속 이용할 수 있습니다.';

  @override
  String get orderNumber => '주문';

  @override
  String get orderDate => '주문일';

  @override
  String get cancelOrder => '주문 취소';

  @override
  String get cancelOrderPrompt => '이 미결제 주문을 취소할까요?';

  @override
  String get refundOnly => '환불만';

  @override
  String get returnRefund => '반품 및 환불';

  @override
  String get exchange => '교환';

  @override
  String get submitRequest => '요청 제출';

  @override
  String get requestSubmitted => '요청을 제출했습니다';

  @override
  String get writeReview => '리뷰 작성';

  @override
  String get submitReview => '리뷰 등록';

  @override
  String get defaultVariant => '기본 옵션';

  @override
  String selectedItems(int count) {
    return '$count개 선택';
  }

  @override
  String get signInToShopHint => '로그인하여 장바구니, 주소와 주문을 관리하세요.';

  @override
  String get checkoutPriceChanged => '주문 금액이 변경되었습니다. 계속하기 전에 갱신된 금액을 확인해 주세요.';

  @override
  String get shopHelpIntro => '주문, 배송 및 판매 후 지원은 해당 지역에서 이용할 수 있는 서비스를 따릅니다.';

  @override
  String get shopHelpOrdering => '왜 주문할 수 없나요?';

  @override
  String get shopHelpOrderingAnswer =>
      '배송 및 지역 서비스가 제공될 때 주문이 활성화됩니다. 상품은 장바구니에 보관하고 나중에 다시 시도할 수 있습니다.';

  @override
  String get shopHelpPayment => '결제는 어떻게 확인되나요?';

  @override
  String get shopHelpPaymentAnswer =>
      '결제 업체가 확인한 후에만 주문이 결제 완료로 표시됩니다. 확인 중에는 같은 주문을 다시 제출하지 마세요.';

  @override
  String get shopHelpAfterSales => '판매 후 지원은 어떻게 요청하나요?';

  @override
  String get shopHelpAfterSalesAnswer =>
      '지원 가능한 주문을 열고 지원 요청을 선택한 뒤, 환불 금액과 사유를 확인하여 제출하세요.';

  @override
  String get noOrders => '아직 주문이 없습니다';

  @override
  String get noFavorites => '아직 찜한 상품이 없습니다';

  @override
  String get noCoupons => '사용 가능한 쿠폰이 없습니다';

  @override
  String get selectItemsToContinue => '계속하려면 이용 가능한 상품을 하나 이상 선택하세요.';

  @override
  String get noCoupon => '쿠폰 사용 안 함';

  @override
  String get pointsToUse => '사용할 포인트 금액';

  @override
  String get refreshOrderTotal => '주문 금액 갱신';

  @override
  String get chooseAddressForTotal => '배송지를 선택하면 최신 주문 금액을 확인할 수 있습니다.';

  @override
  String get requiredField => '필수 항목입니다.';

  @override
  String get invalidInternationalPhone => '국가 번호를 포함한 올바른 전화번호를 입력하세요.';

  @override
  String get invalidCouponCode => '영문, 숫자, 하이픈 또는 밑줄로 된 4~32자 코드를 입력하세요.';

  @override
  String get unavailable => '이용 불가';

  @override
  String get orderItemsUnavailable => '이전 주문의 상품 정보는 제공되지 않습니다.';

  @override
  String get orderCompleted => '완료';

  @override
  String get orderCancelled => '취소됨';

  @override
  String get orderRefunded => '환불됨';

  @override
  String get orderStatusPending => '처리 중';

  @override
  String get legacyOrderReadOnly =>
      '이전 주문은 여기에서 조회만 할 수 있습니다. 변경이 필요하면 고객 지원에 문의하세요.';

  @override
  String get returnLogistics => '반품 배송';

  @override
  String get carrier => '배송 업체';

  @override
  String get trackingNumber => '운송장 번호';

  @override
  String get noShippingUpdates => '아직 배송 정보가 없습니다';

  @override
  String get waitingForReturn => '반품 대기 중';

  @override
  String get requestRejected => '요청이 거절되었습니다';

  @override
  String get requestProcessing => '요청 처리 중';

  @override
  String get afterSalesUnavailable => '이 주문에는 판매 후 지원이 가능한 상품이 없습니다.';

  @override
  String get previewRequest => '요청 금액 확인';

  @override
  String get problemPhotos => '문제 사진';

  @override
  String get afterSalePhotoHint =>
      '선택 사항입니다. JPG, PNG 또는 WebP 이미지를 최대 9장, 장당 10MB까지 추가할 수 있습니다.';

  @override
  String get addProblemPhotos => '사진 추가';

  @override
  String get chooseFromGallery => '갤러리에서 선택';

  @override
  String get takePhoto => '사진 촬영';

  @override
  String get photoUploading => '업로드 중…';

  @override
  String get photoUploaded => '업로드됨';

  @override
  String get photoUploadFailed => '업로드에 실패했습니다. 다시 시도하거나 사진을 삭제하세요.';

  @override
  String get photoServiceUnavailable =>
      '지금은 사진을 추가할 수 없습니다. 설명만으로도 요청할 수 있습니다.';

  @override
  String get removePhoto => '사진 삭제';

  @override
  String get photoTooLarge => '사진 한 장은 10MB 이하여야 합니다.';

  @override
  String get photoFormatUnsupported => 'JPG, PNG 또는 WebP 이미지를 선택하세요.';

  @override
  String get photoReadFailed => '사진을 불러오지 못했습니다. 다시 시도하세요.';

  @override
  String get afterSaleSubmissionUncertain =>
      '요청 결과가 확인되지 않았습니다. 주문 상태를 확인하거나 같은 요청을 다시 시도하세요.';

  @override
  String get requestDetails => '신청 상세';

  @override
  String get afterSaleItems => '이번 신청 상품';

  @override
  String get afterSaleItemsUnavailable => '이 신청의 상품 상세 정보를 불러올 수 없습니다.';

  @override
  String get refundProgress => '환불 진행 상태';

  @override
  String get refundResultPending => '환불 결과를 확인하고 있습니다.';

  @override
  String get afterSaleItem => '판매 후 지원 상품';

  @override
  String get shareProduct => '상품 공유';

  @override
  String get customerReviews => '고객 리뷰';

  @override
  String stockCount(int count) {
    return '재고 $count개';
  }
}
