// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get scanLocationTitle => '位置情報をオンにしてください';

  @override
  String get scanLocationHint =>
      '設定でスマートフォンの位置情報をオンにしてから、この画面に戻って近くのリングを検索してください。';

  @override
  String get scanPermissionTitle => '必要な権限を許可してください';

  @override
  String get scanPermissionHint => '設定で必要な権限を許可してから、この画面に戻ってリングを検索してください。';

  @override
  String get loginProtectionTitle => 'ログイン保護';

  @override
  String get verifyContactToReset => 'メールアドレスまたは電話番号を確認して、パスワードを再設定します。';

  @override
  String get workoutStartOnWatch => 'このリングではアプリから運動を開始できません。リングで直接開始してください。';

  @override
  String get finishWorkoutConfirm => 'この運動を終了しますか？';

  @override
  String get finishLeaveWorkoutHint => '画面を離れる前に腕時計の運動を停止し、記録済みの時間とルートを保存します。';

  @override
  String get finishAndLeave => '終了して戻る';

  @override
  String get workoutRouteMissing =>
      'この記録にはスマートフォンで記録したルートがありません。腕時計の運動データは保存されています。';

  @override
  String get workoutDuration => '運動時間';

  @override
  String get workoutWatchHeartRate => 'リングの心拍数';

  @override
  String get messageSendFailed => '送信できませんでした。ネットワークを確認して、もう一度お試しください。';

  @override
  String get noWatchShopHint => 'ほかのデバイスをお探しですか？Say Ringストアをご覧ください。';

  @override
  String get notificationInAppHint =>
      'アプリ内のメッセージと未読表示は引き続き利用できます。通知を有効にすると、見守りの招待や健康アラートを速やかに受け取れます。';

  @override
  String get healthAlertSafetyHint =>
      '健康アラートは速やかな注意喚起のためのもので、医療診断ではありません。強い体調不良を感じる場合は、速やかに受診してください。';

  @override
  String get afterSalesService => 'アフターサービス';

  @override
  String get afterSalesApplyHint =>
      '対象の商品を選び、理由と申請金額を入力してください。送信後は注文一覧で対応状況を確認できます。';

  @override
  String get afterSalesAlreadySubmitted =>
      'この商品のアフターサービス申請は送信済みです。ストア担当者の対応をお待ちください。';

  @override
  String get afterSalesType => '申請の種類';

  @override
  String get requestedAmount => '申請金額';

  @override
  String get afterSalesReason => '申請理由';

  @override
  String get describeProblem => '問題を説明してください';

  @override
  String get amountPaid => '支払額';

  @override
  String get orderDetailsLoadFailed => '注文詳細を読み込めませんでした。しばらくしてからお試しください。';

  @override
  String get confirmItemReceived => '商品を受け取りましたか？';

  @override
  String get confirmReceiptHint => '受取を確認すると注文が完了します。商品が届いていない場合は確認しないでください。';

  @override
  String get notConfirmYet => 'まだ受け取っていない';

  @override
  String get unitChangesHint => '単位の変更はすぐに反映されます。アプリの再インストール後は再設定が必要な場合があります。';

  @override
  String get goalSettingsTitle => '目標設定';

  @override
  String get dailyStepGoalField => '1日の歩数目標（歩）';

  @override
  String get dailyDistanceGoalField => '1日の距離目標（km）';

  @override
  String get dailyCalorieGoalField => '1日の消費カロリー目標（kcal）';

  @override
  String get saveGoals => '目標を保存';

  @override
  String get viewAccountAddresses => 'アカウントの配送先住所を確認';

  @override
  String get loadingProfile => 'プロフィールを読み込み中…';

  @override
  String get profileSaveExplanation =>
      '「保存」をタップすると写真とプロフィールがアカウントに保存され、プロフィールや見守りメンバーの識別に使用されます。';

  @override
  String get contactPhoneLabel => '連絡先電話番号';

  @override
  String get wechatOfficialAccount => 'WeChat公式アカウント';

  @override
  String get addSupportContact => 'サポート連絡先を追加';

  @override
  String get contactPreparationHint => '問い合わせ前に、デバイスのモデルと問題が起きた時刻を確認してください。';

  @override
  String get supportPrivacyWarning => '非公式のアカウントに認証コード、パスワード、健康記録全体を送らないでください。';

  @override
  String get brandHealthTitle => 'Say Ring ヘルス';

  @override
  String get accountAndSecurity => 'アカウントとセキュリティ';

  @override
  String get cityNameLabel => '都市名';

  @override
  String get cityNameExample => '例：東京';

  @override
  String get visitStoreHint => 'ストアで自分に合う健康デバイスを探しましょう。';

  @override
  String get selectReportPlan => 'レポートプランを選択';

  @override
  String get reportPaidContentHint =>
      '明らかな異常のアラートは無料です。有料コンテンツには、より詳しい傾向の整理や日常の健康管理の提案が含まれます。';

  @override
  String get wechatPayLabel => 'WeChat Pay';

  @override
  String get alipayLabel => 'Alipay';

  @override
  String get reportPurchaseTerms =>
      '購入前にプランと価格を確認してください。健康メンバーシップは自動更新されず、期限切れの未使用回数は繰り越されません。';

  @override
  String get detailedHealthReport => '詳細な健康レポート';

  @override
  String get reportInsufficientDataHint =>
      'データが不足している場合、支払い注文は作成されません。普段どおりリングを装着し、データを同期してから再度お試しください。';

  @override
  String get waitingPaymentConfirmation => '支払いの確認待ち';

  @override
  String get paymentReturnRefreshHint =>
      '支払い後にこの画面へ戻って更新してください。支払いを確認できると、利用可能な回数が更新されます。';

  @override
  String get reportPurchaseDataMissing => 'まだデータが不足しているため、購入できません。';

  @override
  String get heartRateUpperLimit => '心拍数の上限';

  @override
  String get systolicUpperLimit => '収縮期血圧の上限';

  @override
  String get diastolicUpperLimit => '拡張期血圧の上限';

  @override
  String get temperatureUpperLimit => '体温の上限';

  @override
  String get calibrateOnWatchHint => 'リングの案内に従って校正を完了してください。';

  @override
  String get spotCheckCuffHint =>
      '今回は安静時の単発測定で、結果は参考用です。より正確な値が必要な場合は、腕時計のポンプ・カフ式測定を使用してください。';

  @override
  String get setHealthUpperLimits => '健康データの上限アラートを設定';

  @override
  String get healthUpperLimitHint => '設定した上限を超えると通知します。';

  @override
  String get heartRateAlertLabel => '心拍数アラート';

  @override
  String get heartRateAlertHint => '心拍数が設定値を超えると通知';

  @override
  String get bloodPressureAlertLabel => '血圧アラート';

  @override
  String get bloodPressureAlertHint => '収縮期または拡張期血圧が設定値を超えると通知';

  @override
  String get temperatureAlertLabel => '体温アラート';

  @override
  String get temperatureAlertHint => '体温が設定値を超えると通知';

  @override
  String get saveHealthAlerts => 'アラート設定を保存';

  @override
  String get healthAlertHistory => 'アラート履歴';

  @override
  String get seekProfessionalCare => '強い体調不良を感じる場合は、速やかに医療従事者に相談してください。';

  @override
  String get watchHealthReference => 'リングの測定結果は、日常の健康管理の参考用です。';

  @override
  String get calibrationReferenceHint => '専門の測定機器で直前に測った値を使用してください。';

  @override
  String get calibrationWearerHint =>
      '校正値は現在の装着者専用です。装着者が変わった場合は、校正を無効にするか、やり直してください。';

  @override
  String get enableCalibration => '校正を有効にする';

  @override
  String get calibrationDisabledHint => '無効にすると腕時計の通常の測定モードに戻ります。';

  @override
  String get diastolicLowerLabel => '拡張期血圧（下の値）';

  @override
  String get longTermTrendHint => '長期的な傾向を見ると、より参考になります。';

  @override
  String get measurementVariationHint =>
      '単発の測定は、装着状態、運動、環境の影響を受ける場合があります。体調が悪い場合は、医療従事者に相談してください。';

  @override
  String get ecgDetailTitle => '心電図の詳細';

  @override
  String get viewFullReport => 'レポート全体を表示';

  @override
  String get ecgReferenceHint => '心電図の結果は健康管理の参考用です。';

  @override
  String get ecgVariationSafety =>
      '単発の測定は装着状態、運動、環境の影響を受け、医療診断の代わりにはなりません。体調が悪い場合は速やかに受診してください。';

  @override
  String get ecgBasicOnly => '今回は基本的な心電図データのみが取得されました。';

  @override
  String get measurementIndicators => '測定指標';

  @override
  String get riskIndicatorsMissing => '今回は腕時計からリスク指標が取得されませんでした。';

  @override
  String get riskAnalysisTitle => 'リスク分析';

  @override
  String get watchAlgorithmReference =>
      '以下の値はリングのアルゴリズムによるもので、健康の傾向を確認する参考用です。';

  @override
  String get ecgHealthReport => '心電図健康レポート';

  @override
  String get brandedEcgReport => 'Say Ring · 心電図健康レポート';

  @override
  String get ecgReportSafety =>
      '注：このレポートはリングの測定データに基づく健康管理の参考用であり、医師の診断の代わりにはなりません。';

  @override
  String get installedWatchFaces => 'インストール済みの文字盤';

  @override
  String get switchInstalledWatchFace => '腕時計に保存済みの文字盤を切り替えられます。';

  @override
  String get useSelectedWatchFace => '使用する';

  @override
  String get downloadUseWatchFace => 'タップしてダウンロード・適用';

  @override
  String get photoWatchFaceHint => '鮮明な写真を選び、プレビューを確認してから腕時計に転送してください。';

  @override
  String get timeDisplayPosition => '時刻の表示位置';

  @override
  String get transferSetWatchFace => '転送して文字盤に設定';

  @override
  String get watchTransferKeepNear => '転送中は腕時計をスマートフォンの近くに置き、この画面から移動しないでください。';

  @override
  String get callMediaAudio => '通話・メディアの音声';

  @override
  String get useCelsius => '摂氏を使用';

  @override
  String get sosContactHint =>
      '腕時計でSOSを作動させると、ここで選んだ人に優先して連絡します。普段よく連絡するご家族を選ぶことをおすすめします。';

  @override
  String get noHealthAssessments => 'この腕時計には設定可能な補助評価がありません。';

  @override
  String get modelFeaturesVary => '対応機能はモデルにより異なります。腕時計に表示される機能を確認してください。';

  @override
  String get assessmentEnabledHint => '有効にすると、腕時計が日々の傾向を参考情報として提供します。';

  @override
  String get assessmentSafety => '補助評価は日常の健康管理の参考用で、診断や治療には使用できません。';

  @override
  String get autoMonitorIntervalHint => '有効にすると、腕時計が設定された間隔で自動測定します。';

  @override
  String get watchHeartRateAlert => '腕時計の心拍数アラート';

  @override
  String get sustainedLimitWatchAlert => '値が上限を超えた状態が続くと、腕時計が通知します。';

  @override
  String get ecgWaveformTitle => '心電図波形';

  @override
  String get ecgWaveformMissing => '今回は有効な心電図波形が取得されませんでした。';

  @override
  String get ecgElectrodeHint =>
      '心拍数やHRVなどの結果は引き続き確認できます。次回は測定中ずっと腕時計の電極に触れてください。';

  @override
  String get screenAutoTimeHint => '腕時計が時刻に応じて自動調整します。';

  @override
  String get raiseWristScreenHint => '手首を上げると画面が点灯します。';

  @override
  String get watchHighHeartRate => '高心拍数アラート';

  @override
  String get watchThresholdHint => '設定値に達すると腕時計が通知します。';

  @override
  String get watchMeasurementSafety => '測定結果は健康管理の参考用で、診断や治療には使用できません。';

  @override
  String get healthDataExplanation => '健康データについて';

  @override
  String get trendUnavailable => '現在、傾向を表示できません。';

  @override
  String get recentData => '最近のデータ';

  @override
  String get trendReferenceOnly => '傾向は日々の健康管理の参考用です。';

  @override
  String get trendVariationSafety =>
      '単発または期間ごとの変化は、装着状態、運動、環境の影響を受ける場合があり、医療診断の代わりにはなりません。';

  @override
  String get watchFaceDownloadHint =>
      'ダウンロード後、文字盤を腕時計に転送します。転送中は腕時計をスマートフォンの近くに置き、この画面を開いたままにしてください。';

  @override
  String get refreshWatchFaces => '文字盤を更新';

  @override
  String get openTestFlight => 'TestFlight を開く';

  @override
  String get articlesEmpty => 'このカテゴリーの記事はまだありません。';

  @override
  String get articlesUnavailable => '健康ライブラリを読み込めませんでした。';

  @override
  String get articleContentUnavailable => '記事の本文はまだ表示できません。';

  @override
  String get imageUnavailable => '画像を読み込めませんでした。';

  @override
  String get allowNotifications => '通知を許可';

  @override
  String get updateNow => '今すぐ更新';

  @override
  String get analysisConsentUnavailable =>
      '健康分析は現在利用できません。作成済みのレポートは引き続き確認できます。';

  @override
  String get analysisReadAgree => '上記の健康分析に関する説明を読み、同意します。';

  @override
  String get agreeContinue => '同意して続ける';

  @override
  String get notGrantNow => '今は同意しない';

  @override
  String get analysisConsentSaved => '健康分析への同意を保存しました。';

  @override
  String get withdrawAnalysisConsent => '健康分析への同意を撤回しますか？';

  @override
  String get withdrawAnalysisExplanation =>
      '新しい詳細レポートは作成されなくなります。作成済みで返金されていないレポートは引き続き確認できます。';

  @override
  String get confirmWithdraw => '撤回を確定';

  @override
  String get analysisConsentWithdrawn => '健康分析への同意を撤回しました。';

  @override
  String get consentGrantedHint => '同意済みです。いつでも撤回できます。';

  @override
  String get consentNeededHint => '詳細レポートの作成前に、個別の同意が必要です。';

  @override
  String get withdraw => '撤回';

  @override
  String get reportHistory => 'レポート履歴';

  @override
  String get saving => '保存中…';

  @override
  String get pauseWorkout => '運動を一時停止';

  @override
  String get resumeWorkout => '運動を再開';

  @override
  String get finishWorkout => '運動を終了';

  @override
  String get watchDistance => '腕時計の距離';

  @override
  String get watchSteps => '腕時計の歩数';

  @override
  String get liveHeartRate => '現在の心拍数';

  @override
  String get watchCalories => '腕時計の消費カロリー';

  @override
  String get connectForWorkout => 'まずデバイス画面でリングを接続してください。運動はリングが記録します。';

  @override
  String latestVersion(String version) {
    return '最新バージョン V$version を使用しています';
  }

  @override
  String workoutPaused(String mode) {
    return '$modeを一時停止中';
  }

  @override
  String workoutInProgress(String mode) {
    return '$mode中';
  }

  @override
  String workoutReady(String mode) {
    return '$modeを開始できます';
  }

  @override
  String startWorkout(String mode) {
    return '$modeを開始';
  }

  @override
  String finishOtherWorkout(String mode) {
    return '先に$modeを終了してください';
  }

  @override
  String workoutDetails(String mode) {
    return '$modeの詳細';
  }

  @override
  String stepCount(int count) {
    return '$count 歩';
  }

  @override
  String get globalShopPricePending => '価格は確認待ちです';

  @override
  String get globalShopLoadMore => 'さらに読み込む';

  @override
  String get globalShopReadOnly => '商品をご覧いただけます。この地域ではまだ注文できません。';

  @override
  String get appName => 'Say Ring';

  @override
  String get searchingNearby => '近くのリングを検索中';

  @override
  String get noDevices => 'デバイスが見つかりません';

  @override
  String get selectWatch => '名前と電波強度を確認してリングを選択してください';

  @override
  String get searchingHint => '検索中です。リストの位置は変わらず、電波強度だけが更新されます。';

  @override
  String get activateWatch => 'リングを充電して起動し、スマートフォンに近づけてください';

  @override
  String get checkWatchConnection =>
      'リングがこのスマートフォンのBluetooth設定または別の端末に接続中なら、接続を解除して再検索してください';

  @override
  String get running => 'ランニング';

  @override
  String get walking => 'ウォーキング';

  @override
  String get cycling => 'サイクリング';

  @override
  String get hiking => 'ハイキング';

  @override
  String get mountaineering => '登山';

  @override
  String metricAnalysis(String metric) {
    return '$metricの分析';
  }

  @override
  String metricAllData(String metric) {
    return '$metricのすべてのデータ';
  }

  @override
  String metricMeasurement(String metric) {
    return '$metricを測定';
  }

  @override
  String metricCalibration(String metric) {
    return '$metricを校正';
  }

  @override
  String metricDetails(String metric) {
    return '$metricの詳細';
  }

  @override
  String get add => '追加';

  @override
  String get endTime => '終了時間';

  @override
  String get reminderInterval => '通知間隔';

  @override
  String get reminderName => 'リマインダー名';

  @override
  String get repeat => '繰り返し';

  @override
  String get addAlarm => 'アラームを追加';

  @override
  String get alarmTime => '通知時刻';

  @override
  String get enableAlarm => 'アラームを有効化';

  @override
  String get emergencyContact => 'SOS緊急連絡先';

  @override
  String get selectEmergencyContact => 'SOS連絡先を選択';

  @override
  String get confirmEmergencyContact => 'SOS連絡先に設定';

  @override
  String get addWorldClock => '世界時計を追加';

  @override
  String get autoBrightness => '明るさの自動調整';

  @override
  String get raiseToWake => '手首を上げて点灯';

  @override
  String get activeTime => '有効時間';

  @override
  String get saveSettings => '設定を保存';

  @override
  String get helpFeedback => 'ヘルプとフィードバック';

  @override
  String get issueType => '問題の種類';

  @override
  String get issueDescription => '問題の説明';

  @override
  String get describeIssue => '問題の内容と発生する手順を説明してください';

  @override
  String get contactOptional => '連絡先（任意）';

  @override
  String get phoneOrEmail => '電話番号またはメールアドレス';

  @override
  String get call => '電話する';

  @override
  String get addContact => '連絡先を追加';

  @override
  String get contactName => '名前';

  @override
  String get contactPhone => '電話番号';

  @override
  String get cart => 'カート';

  @override
  String get searchProducts => '商品を検索';

  @override
  String get selectVariant => '仕様を選択してください';

  @override
  String get variant => '仕様';

  @override
  String get buyNow => '今すぐ購入';

  @override
  String get cartEmpty => 'カートは空です';

  @override
  String get returnShop => 'ショップに戻る';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get checkout => '購入手続きへ';

  @override
  String get clearCart => 'カートを空にしますか？';

  @override
  String get clearCartHint => 'カート内のすべての商品を削除します。';

  @override
  String get viewOrder => '注文を確認';

  @override
  String get confirmOrder => '注文を確認';

  @override
  String get productInfo => '商品情報';

  @override
  String get orderNote => '備考';

  @override
  String get noteToSeller => '販売者へのメッセージ';

  @override
  String get paymentCheckout => 'お支払い';

  @override
  String get orderTotal => '注文合計';

  @override
  String get selectPayment => '支払い方法を選択';

  @override
  String get refreshOrder => '注文状況を更新';

  @override
  String get viewMyOrders => '自分の注文を確認';

  @override
  String get backToProduct => '商品詳細に戻る';

  @override
  String get newAddress => '住所を追加';

  @override
  String get recipient => '受取人';

  @override
  String get province => '州・省';

  @override
  String get district => '区・郡';

  @override
  String get streetAddress => '詳細住所';

  @override
  String get defaultAddress => '既定の住所に設定';

  @override
  String get shippingInfo => '配送情報';

  @override
  String get restorePurchases => '購入を復元';

  @override
  String get paymentMethod => '支払い方法';

  @override
  String get refresh => '更新';

  @override
  String get useWatchFace => 'この文字盤を使用しますか？';

  @override
  String get downloadAndUse => 'ダウンロードして使用';

  @override
  String get watchFaceFailed => '文字盤を設定できませんでした';

  @override
  String get statusNormal => '正常';

  @override
  String get statusRecorded => '記録済み';

  @override
  String get statusAttention => '数値を確認';

  @override
  String get statusOutOfRange => '参考範囲外';

  @override
  String get statusLow => '低め';

  @override
  String get statusHigh => '高め';

  @override
  String get careInviteHint => 'メールアドレスまたは国番号付き電話番号でSay Ringアカウントを招待できます。';

  @override
  String get careSharingHint => '選択した測定項目のみ共有します。共有はいつでも停止できます。';

  @override
  String get carePending => '保留中';

  @override
  String get careActive => '有効';

  @override
  String get careClosed => '終了';

  @override
  String get accept => '承認';

  @override
  String get decline => '拒否';

  @override
  String get stopSharing => '共有を停止';

  @override
  String get sharedMeasurements => '共有する測定項目';

  @override
  String get invitationSent => '招待を送信しました';

  @override
  String get invalidCareContact => 'メールアドレスまたは国番号付きの電話番号を入力してください。';

  @override
  String get carePermissionDenied => 'この測定項目は共有されていません。';

  @override
  String get reload => '再読み込み';

  @override
  String get applyAfterSales => 'サポートを依頼';

  @override
  String get analysisConsent => '健康分析への同意';

  @override
  String get workoutRecords => '運動記録';

  @override
  String get startTime => '開始時間';

  @override
  String get addCare => '見守りメンバーを追加';

  @override
  String get confirmReceipt => '受け取りを確認';

  @override
  String get personalInfo => '個人情報';

  @override
  String get deliveryAddresses => '配送先住所';

  @override
  String get readAgain => '再取得';

  @override
  String get smsCode => 'SMS確認コード';

  @override
  String get watchFaceShop => '文字盤ストア';

  @override
  String get selectCity => '都市を選択';

  @override
  String get city => '都市';

  @override
  String get confirm => '確認';

  @override
  String get productDetails => '商品詳細';

  @override
  String get clear => 'クリア';

  @override
  String get settings => '設定';

  @override
  String get goals => '目標';

  @override
  String get send => '送信';

  @override
  String get typeMessage => 'メッセージを入力…';

  @override
  String get devicesFound => 'デバイスが見つかりました';

  @override
  String get connect => '接続';

  @override
  String get searchAgain => '再検索';

  @override
  String get searchRecovery =>
      'リングを近づけ、システムBluetoothまたは別の端末に接続中なら先に解除してから再試行してください。';

  @override
  String get deviceName => 'デバイス名';

  @override
  String get deviceModel => 'デバイスモデル';

  @override
  String get connectionStatus => '接続状態';

  @override
  String get firmwareVersion => 'ファームウェアバージョン';

  @override
  String get watchBattery => 'リングのバッテリー';

  @override
  String get chargingStatus => '充電状態';

  @override
  String get messageDetails => 'メッセージ詳細';

  @override
  String get dailySummary => '当日の概要';

  @override
  String get remoteMemberData => '見守りメンバーのデータ';

  @override
  String get ecgWaveformUnavailable => '表示できる心電図波形がありません';

  @override
  String get orderDetails => '注文詳細';

  @override
  String get viewShipping => '配送状況を確認';

  @override
  String get measureAgain => '再測定';

  @override
  String get checkPaymentStatus => '支払い状況を確認';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get confirmDeleteAccountTitle => 'アカウントを削除しますか？';

  @override
  String get deleteAccountHint => 'アカウントと関連データの削除後、この端末からログアウトします。';

  @override
  String get confirmDelete => '削除を確認';

  @override
  String get exit => '終了';

  @override
  String get nickname => 'ニックネーム';

  @override
  String get gender => '性別';

  @override
  String get birthDate => '生年月日';

  @override
  String get heightCm => '身長（cm）';

  @override
  String get weightKg => '体重（kg）';

  @override
  String get choose => '選択してください';

  @override
  String get connectWatchToUse => 'リングを接続して利用';

  @override
  String get selectPhoto => '写真を選択';

  @override
  String get saved => '保存しました';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get notificationsOff => 'システム通知が無効です';

  @override
  String get privacyAgreement => 'プライバシーポリシー';

  @override
  String get appPermissions => 'アプリの権限';

  @override
  String get openSystemSettings => 'アプリのシステム設定を開く';

  @override
  String get monitoringHint => '接続後、このリングで設定可能な健康モニタリング項目を表示します。';

  @override
  String get previewUnavailable => 'プレビューを利用できません';

  @override
  String get distance => '距離';

  @override
  String get calories => '消費カロリー';

  @override
  String get healthProfile => '健康プロフィール';

  @override
  String get photoWatchFace => '写真の文字盤';

  @override
  String get cameraRemote => 'カメラリモコン';

  @override
  String get phoneCalls => '通話';

  @override
  String get contacts => '連絡先';

  @override
  String get notifications => '通知';

  @override
  String get alarms => 'アラーム';

  @override
  String get weather => '天気';

  @override
  String get worldClock => '世界時計';

  @override
  String get healthReminders => '健康リマインダー';

  @override
  String get healthMonitoring => '健康モニタリング';

  @override
  String get healthAssessment => '健康評価';

  @override
  String get screenDisplay => '画面表示';

  @override
  String get scanning => '検索中…';

  @override
  String get connecting => '接続中…';

  @override
  String get waitingConfirmation => '確認待ち';

  @override
  String get syncing => '同期中…';

  @override
  String get measuring => '測定中…';

  @override
  String get needsAttention => '確認が必要';

  @override
  String get tapToOpen => 'タップして開く';

  @override
  String get deviceInfoHint => 'デバイス情報を表示';

  @override
  String get connectionInstructions =>
      '1. Bluetoothと付近のデバイスへのアクセスを有効にします。\n2. リングを充電し、スマートフォンの近くに置きます。\n3. デバイスを検索し、自分のリングを選びます。\n4. リングに確認が表示されたら承認します。';

  @override
  String get syncNearbyHint => '接続・同期中はリングを十分に充電し、スマートフォンの近くに置いてください。';

  @override
  String get invalidCode => 'コードを確認して再試行してください';

  @override
  String get codeExpired => 'コードの有効期限が切れました。新しいコードを取得してください。';

  @override
  String get tooManyAttempts => '操作回数が多すぎます。しばらくしてから再試行してください。';

  @override
  String get readTerms => '利用規約とプライバシーポリシーをご確認ください';

  @override
  String verificationSentTo(String contact) {
    return '$contactにコードを送信しました';
  }

  @override
  String get addSmartDevice => 'スマートデバイスを追加';

  @override
  String get watchNearbyHint => 'Bluetoothを有効にしてリングをスマートフォンに近づけてください';

  @override
  String get startSearch => 'デバイスを検索';

  @override
  String get readingData => 'データを読み取り中…';

  @override
  String get readingCapabilities => 'リングの機能を確認中…';

  @override
  String get capabilitiesHint => 'このリングで利用できる機能のみ表示します';

  @override
  String get capabilitiesFailed => 'リングの機能を読み取れませんでした';

  @override
  String get keepWatchNear => 'リングを近づけて再試行してください';

  @override
  String get personalizeWatch => '文字盤とカスタマイズ';

  @override
  String get signInCloudHint => 'ログインしてクラウド健康サービスを利用';

  @override
  String get aiQuestion => 'AIに質問';

  @override
  String get aiQuestionHint => 'AIアシスタントに健康管理について質問';

  @override
  String get language => '言語';

  @override
  String get signIn => 'ログイン';

  @override
  String get signUp => '新規登録';

  @override
  String get signOut => 'ログアウト';

  @override
  String get email => 'メールアドレス';

  @override
  String get phoneNumber => '電話番号';

  @override
  String get countryRegion => '国または地域';

  @override
  String get password => 'パスワード';

  @override
  String get confirmPassword => 'パスワードの確認';

  @override
  String get verificationCode => '確認コード';

  @override
  String get sendCode => 'コードを送信';

  @override
  String get forgotPassword => 'パスワードをお忘れですか？';

  @override
  String get resetPassword => 'パスワードをリセット';

  @override
  String get createAccount => 'アカウントを作成';

  @override
  String get continueAction => '続ける';

  @override
  String get back => '戻る';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get retry => '再試行';

  @override
  String get loading => '読み込み中…';

  @override
  String get pleaseWait => 'しばらくお待ちください…';

  @override
  String get emailOrPhone => 'メールアドレスまたは電話番号';

  @override
  String get enterEmail => 'メールアドレスを入力';

  @override
  String get enterPhone => '電話番号を入力';

  @override
  String get enterPassword => 'パスワードを入力';

  @override
  String get passwordRequirement => '8文字以上。英字・数字は最大72文字、その他の文字では上限が短くなります。';

  @override
  String get passwordMismatch => 'パスワードが一致しません';

  @override
  String get invalidEmail => '有効なメールアドレスを入力してください';

  @override
  String get invalidPhone => '国番号と電話番号を確認してください';

  @override
  String get codeSent => 'コードを送信しました。受信内容をご確認ください。';

  @override
  String get codeRequired => '確認コードを入力してください';

  @override
  String get consentRequired => '利用規約とプライバシーポリシーを読み、同意してください';

  @override
  String get agreeToTerms => '確認し、同意します：';

  @override
  String get termsOfService => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get registrationUnavailable => '現在、新規登録をご利用いただけません。後でもう一度お試しください。';

  @override
  String get loginFailed => 'ログインできませんでした。入力内容を確認して再試行してください。';

  @override
  String get accountAlreadyExists => 'このアカウントは登録済みです。ログインしてください。';

  @override
  String get networkUnavailable => 'インターネット接続を確認して再試行してください';

  @override
  String get serviceUnavailable => '現在、この機能をご利用いただけません。後でもう一度お試しください。';

  @override
  String get accountCreated => 'アカウントを作成しました';

  @override
  String get passwordReset => 'パスワードを更新しました';

  @override
  String get haveAccount => 'すでにアカウントをお持ちですか？';

  @override
  String get noAccount => 'Say Ringは初めてですか？';

  @override
  String get showPassword => 'パスワードを表示';

  @override
  String get hidePassword => 'パスワードを隠す';

  @override
  String get selectCountry => '国または地域を選択';

  @override
  String get registrationMethod => '登録方法';

  @override
  String get changeLanguageFailed => '言語を保存できませんでした。再試行してください。';

  @override
  String get health => '健康';

  @override
  String get device => 'デバイス';

  @override
  String get profile => 'マイページ';

  @override
  String get healthData => '健康データ';

  @override
  String get allData => 'すべてのデータ';

  @override
  String get healthRecords => '健康記録';

  @override
  String get workoutsAndRecords => '運動と記録';

  @override
  String get healthDisclaimer => '測定結果は健康管理の参考です。体調がすぐれない場合は医療専門家にご相談ください。';

  @override
  String get healthSafetyAdvice => '休憩してから再測定してください。体調がすぐれない場合は医療機関にご相談ください。';

  @override
  String get defaultUser => 'Say Ringユーザー';

  @override
  String get dailyGreeting => '今日も自分を大切に';

  @override
  String get messages => 'メッセージ';

  @override
  String get aiAssistant => 'AIヘルスアシスタント';

  @override
  String get aiAssistantIntro => '健康管理についてお気軽にご質問ください。';

  @override
  String get askNow => '質問する';

  @override
  String get remoteCare => '家族の見守り';

  @override
  String get healthLibrary => '健康ライブラリ';

  @override
  String get healthAlerts => '健康アラート';

  @override
  String get shop => 'ショップ';

  @override
  String get connectWatch => 'リングを接続';

  @override
  String get addDevice => 'デバイスを追加';

  @override
  String get connectWatchForData => 'リングを接続すると対応する健康データを確認できます';

  @override
  String get noHealthData => '表示できる健康データはまだありません';

  @override
  String get noData => 'データはまだありません';

  @override
  String get connected => '接続済み';

  @override
  String get notConnected => '未接続';

  @override
  String get online => 'オンライン';

  @override
  String get syncData => 'データを同期';

  @override
  String get syncComplete => 'データを同期しました';

  @override
  String get syncFailedTryAgain => '同期できませんでした。リングをスマートフォンに近づけて再試行してください。';

  @override
  String get disconnect => '接続を解除';

  @override
  String get findWatch => 'リングを探す';

  @override
  String get watchFaces => '文字盤';

  @override
  String get deviceFeatures => 'デバイス機能';

  @override
  String get aboutDevice => 'デバイスについて';

  @override
  String get connectionHelp => '接続ガイド';

  @override
  String get searchNearbyWatch => '近くのSay Ringを検索して接続';

  @override
  String get useWatch => 'リングで操作してください';

  @override
  String get myOrders => '注文履歴';

  @override
  String get all => 'すべて';

  @override
  String get awaitingPayment => '支払い待ち';

  @override
  String get awaitingShipment => '発送待ち';

  @override
  String get awaitingDelivery => '受け取り待ち';

  @override
  String get afterSales => '返品・サポート';

  @override
  String get careMembers => '見守りメンバー';

  @override
  String get unitSettings => '単位設定';

  @override
  String get unitSettingsHint => '距離や温度などの単位を設定';

  @override
  String get myServices => 'サービス';

  @override
  String get accountSettings => 'アカウント設定';

  @override
  String get editProfile => 'プロフィール編集';

  @override
  String get permissions => '権限管理';

  @override
  String get feedback => 'フィードバック';

  @override
  String get customerService => 'サポートに連絡';

  @override
  String get aboutApp => 'Say Ringについて';

  @override
  String get security => 'アカウントの安全';

  @override
  String get goToSettings => '設定を開く';

  @override
  String get close => '閉じる';

  @override
  String get view => '表示';

  @override
  String get checkUpdates => '更新を確認';

  @override
  String get onlineUpdate => 'アプリの更新';

  @override
  String get updateRequired => '更新して続行';

  @override
  String get updateReady => '新しいバージョンがあります';

  @override
  String get preparingUpdate => '安全な更新を準備中…';

  @override
  String get openingUpdate => 'システムの更新画面を開いています…';

  @override
  String get updateAppStore => 'App Storeで更新';

  @override
  String get updateStore => 'アプリストアで更新';

  @override
  String get downloadAndInstall => '安全にダウンロードしてインストール';

  @override
  String get gettingReady => '準備しています…';

  @override
  String get enableNotifications => 'Say Ringの通知を有効にする';

  @override
  String get notificationExplanation =>
      '健康アラートや見守りの招待を受け取れます。ロック画面に健康数値は表示されません。通知はシステム設定で無効にできます。';

  @override
  String get notNow => '後で';

  @override
  String get enable => '有効にする';

  @override
  String get newCareRequest => '新しい見守りリクエスト';

  @override
  String get dismissHealthAlert => '健康アラートを閉じる';

  @override
  String get dismissCareAlert => '見守り通知を閉じる';

  @override
  String get bloodPressure => '血圧';

  @override
  String get heartRate => '心拍数';

  @override
  String get bloodOxygen => '血中酸素';

  @override
  String get bloodGlucose => '血糖';

  @override
  String get bodyTemperature => '体温';

  @override
  String get ecg => '心電図';

  @override
  String get hrv => 'HRV';

  @override
  String get bodyComposition => '体組成';

  @override
  String get bloodComposition => '血液成分';

  @override
  String get sleep => '睡眠';

  @override
  String get steps => '歩数';

  @override
  String get workouts => '運動';

  @override
  String welcome(String name) {
    return 'こんにちは、$name';
  }

  @override
  String resendCode(int seconds) {
    return '$seconds秒後に再送';
  }

  @override
  String memberId(String id) {
    return '会員ID：$id';
  }

  @override
  String unreadMessages(int count) {
    return 'メッセージ、未読$count件';
  }

  @override
  String recordCount(int count) {
    return '$count件';
  }

  @override
  String memberCount(int count) {
    return '$count人';
  }

  @override
  String versionBuild(String version, int build) {
    return 'V$version · ビルド $build';
  }

  @override
  String get globalShopBrowseNotice =>
      '商品は引き続きご覧いただけます。お届け先の地域で配送と支払いが利用可能になると注文できます。';

  @override
  String get shopAccount => 'ショップアカウント';

  @override
  String get addToCart => 'カートに追加';

  @override
  String get addedToCart => 'カートに追加しました';

  @override
  String get quantity => '数量';

  @override
  String get inStock => '在庫あり';

  @override
  String get outOfStock => '在庫切れまたは利用不可';

  @override
  String get favorites => 'お気に入り';

  @override
  String get coupons => 'クーポン';

  @override
  String get points => 'ポイント';

  @override
  String get helpCenter => 'ヘルプセンター';

  @override
  String get chooseDeliveryAddress => '配送先を選択';

  @override
  String get editAddress => '住所を編集';

  @override
  String get delete => '削除';

  @override
  String get deleteAddressPrompt => 'この住所を削除しますか？';

  @override
  String get postalCode => '郵便番号';

  @override
  String get itemsSubtotal => '商品小計';

  @override
  String get discount => '割引';

  @override
  String get shippingFee => '送料';

  @override
  String get amountDue => 'お支払い金額';

  @override
  String get placeOrder => '注文を確定';

  @override
  String get orderPlaced => '注文を受け付けました';

  @override
  String get orderSubmissionUncertain => '注文結果を確認できません。再度操作する前に注文履歴をご確認ください。';

  @override
  String get availableCoupons => '利用可能なクーポン';

  @override
  String get ownedCoupons => 'マイクーポン';

  @override
  String get couponCode => 'クーポンコード';

  @override
  String get redeem => '利用する';

  @override
  String get claim => '受け取る';

  @override
  String get claimed => '受取済み';

  @override
  String get pointsBalance => 'ポイント残高';

  @override
  String get pointsUnavailable => '残高はまだ利用できません';

  @override
  String get marketUnavailable => '選択した配送地域では、まだ注文をご利用いただけません。';

  @override
  String get paymentUnavailable =>
      '現在、アプリではお支払いをご利用いただけません。カートと既存の注文は引き続き確認できます。';

  @override
  String get orderNumber => '注文';

  @override
  String get orderDate => '作成日時';

  @override
  String get cancelOrder => '注文をキャンセル';

  @override
  String get cancelOrderPrompt => 'この未払い注文をキャンセルしますか？';

  @override
  String get refundOnly => '返金のみ';

  @override
  String get returnRefund => '返品・返金';

  @override
  String get exchange => '交換';

  @override
  String get submitRequest => '申請を送信';

  @override
  String get requestSubmitted => '申請を送信しました';

  @override
  String get writeReview => 'レビューを書く';

  @override
  String get submitReview => 'レビューを投稿';

  @override
  String get defaultVariant => '標準オプション';

  @override
  String selectedItems(int count) {
    return '$count件選択';
  }

  @override
  String get signInToShopHint => 'ログインすると、カート、住所、注文を管理できます。';

  @override
  String get checkoutPriceChanged => '注文金額が変更されました。更新後の金額をご確認ください。';

  @override
  String get shopHelpIntro => '注文、配送、アフターサービスは、お住まいの地域で利用できるサービスに準じます。';

  @override
  String get shopHelpOrdering => 'なぜ注文できないのですか？';

  @override
  String get shopHelpOrderingAnswer =>
      '配送および販売サービスが利用可能になると注文できます。商品はカートに残したまま、後でもう一度お試しいただけます。';

  @override
  String get shopHelpPayment => '支払いはどのように確認されますか？';

  @override
  String get shopHelpPaymentAnswer =>
      '決済事業者による確認後にのみ、注文は支払い済みになります。確認中は同じ注文を再度行わないでください。';

  @override
  String get shopHelpAfterSales => '購入後のサポートはどう申請しますか？';

  @override
  String get shopHelpAfterSalesAnswer =>
      '対象の注文を開き、サポート申請を選択して、返金額と理由を確認して送信してください。';

  @override
  String get noOrders => '注文はまだありません';

  @override
  String get noFavorites => 'お気に入りはまだありません';

  @override
  String get noCoupons => '利用できるクーポンはありません';

  @override
  String get selectItemsToContinue => '利用可能な商品を1点以上選択してください。';

  @override
  String get noCoupon => 'クーポンを使用しない';

  @override
  String get pointsToUse => '使用するポイント相当額';

  @override
  String get refreshOrderTotal => '注文金額を更新';

  @override
  String get chooseAddressForTotal => '配送先を選択すると、最新の注文金額を確認できます。';

  @override
  String get requiredField => 'この項目は必須です。';

  @override
  String get invalidInternationalPhone => '国番号を含む有効な電話番号を入力してください。';

  @override
  String get invalidCouponCode => '4～32文字の英数字、ハイフンまたはアンダースコアで入力してください。';

  @override
  String get unavailable => '利用不可';

  @override
  String get orderItemsUnavailable => 'この過去の注文では商品情報を確認できません。';

  @override
  String get orderCompleted => '完了';

  @override
  String get orderCancelled => 'キャンセル済み';

  @override
  String get orderRefunded => '返金済み';

  @override
  String get orderStatusPending => '処理中';

  @override
  String get legacyOrderReadOnly =>
      'この過去の注文は閲覧のみ可能です。変更が必要な場合はサポートへお問い合わせください。';

  @override
  String get returnLogistics => '返品配送';

  @override
  String get carrier => '配送業者';

  @override
  String get trackingNumber => '追跡番号';

  @override
  String get noShippingUpdates => '配送状況の更新はまだありません';

  @override
  String get waitingForReturn => '返品待ち';

  @override
  String get requestRejected => '申請は承認されませんでした';

  @override
  String get requestProcessing => '申請処理中';

  @override
  String get afterSalesUnavailable => 'この注文には購入後サポートの対象商品がありません。';

  @override
  String get previewRequest => '申請金額を確認';

  @override
  String get problemPhotos => '問題の写真';

  @override
  String get afterSalePhotoHint => '任意。JPG、PNG、WebP を最大9枚、1枚10MBまで追加できます。';

  @override
  String get addProblemPhotos => '写真を追加';

  @override
  String get chooseFromGallery => 'ギャラリーから選択';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String get photoUploading => 'アップロード中…';

  @override
  String get photoUploaded => 'アップロード済み';

  @override
  String get photoUploadFailed => 'アップロードできませんでした。再試行するか写真を削除してください。';

  @override
  String get photoServiceUnavailable => '現在写真を追加できません。説明文だけでも申請できます。';

  @override
  String get removePhoto => '写真を削除';

  @override
  String get photoTooLarge => '写真は1枚10MB以下にしてください。';

  @override
  String get photoFormatUnsupported => 'JPG、PNG、WebP の画像を選択してください。';

  @override
  String get photoReadFailed => '写真を読み込めませんでした。もう一度お試しください。';

  @override
  String get afterSaleSubmissionUncertain =>
      '申請結果を確認できません。注文状況を確認するか、同じ申請を再試行してください。';

  @override
  String get requestDetails => '申請内容';

  @override
  String get afterSaleItems => '今回の申請商品';

  @override
  String get afterSaleItemsUnavailable => 'この申請の商品明細は取得できません。';

  @override
  String get refundProgress => '返金状況';

  @override
  String get refundResultPending => '返金結果を確認しています。';

  @override
  String get afterSaleItem => 'アフターサービス商品';

  @override
  String get shareProduct => '商品を共有';

  @override
  String get customerReviews => '購入者レビュー';

  @override
  String stockCount(int count) {
    return '在庫 $count 点';
  }
}
