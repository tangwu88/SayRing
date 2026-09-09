// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get scanLocationTitle => 'Turn on location';

  @override
  String get scanLocationHint =>
      'Turn on your phone’s location services to find nearby watches, then return to this page.';

  @override
  String get scanPermissionTitle => 'Allow device access';

  @override
  String get scanPermissionHint =>
      'Allow the required permissions in Settings, then return to find your watch.';

  @override
  String get loginProtectionTitle => 'Sign-in protection';

  @override
  String get verifyContactToReset =>
      'Verify your email or phone number to reset your password.';

  @override
  String get workoutStartOnWatch =>
      'This watch cannot start workouts from the app. Start the workout directly on your watch.';

  @override
  String get finishWorkoutConfirm => 'Finish this workout?';

  @override
  String get finishLeaveWorkoutHint =>
      'Before leaving, the watch workout will stop and the recorded duration and route will be saved.';

  @override
  String get finishAndLeave => 'Finish and leave';

  @override
  String get workoutRouteMissing =>
      'No phone-recorded route is available for this session. The watch workout data is still saved.';

  @override
  String get workoutDuration => 'Workout duration';

  @override
  String get workoutWatchHeartRate => 'Watch heart rate';

  @override
  String get messageSendFailed =>
      'Could not send. Check your connection and try again.';

  @override
  String get noWatchShopHint => 'Need a device? Visit the Saydian store.';

  @override
  String get notificationInAppHint =>
      'In-app messages and unread indicators remain available. Enable notifications to receive care invitations and health alerts promptly.';

  @override
  String get healthAlertSafetyHint =>
      'Health alerts provide timely reminders, not medical diagnoses. If you feel significantly unwell, seek medical care promptly.';

  @override
  String get afterSalesService => 'After-sales service';

  @override
  String get afterSalesApplyHint =>
      'Select the item and enter the reason and requested amount. After submitting, check the status in your orders.';

  @override
  String get afterSalesAlreadySubmitted =>
      'An after-sales request has already been submitted for this item. Please wait for the store team to review it.';

  @override
  String get afterSalesType => 'Request type';

  @override
  String get requestedAmount => 'Requested amount';

  @override
  String get afterSalesReason => 'Reason for request';

  @override
  String get describeProblem => 'Describe the problem';

  @override
  String get amountPaid => 'Amount paid';

  @override
  String get orderDetailsLoadFailed =>
      'Could not load order details. Please try again later.';

  @override
  String get confirmItemReceived => 'Have you received the items?';

  @override
  String get confirmReceiptHint =>
      'Confirming receipt will complete the order. Do not confirm if you have not received the items.';

  @override
  String get notConfirmYet => 'Not yet';

  @override
  String get unitChangesHint =>
      'Unit changes take effect immediately. You may need to set them again after reinstalling the app.';

  @override
  String get goalSettingsTitle => 'Goal settings';

  @override
  String get dailyStepGoalField => 'Daily step goal (steps)';

  @override
  String get dailyDistanceGoalField => 'Daily distance goal (km)';

  @override
  String get dailyCalorieGoalField => 'Daily calorie goal (kcal)';

  @override
  String get saveGoals => 'Save goals';

  @override
  String get viewAccountAddresses => 'View shipping addresses in your account';

  @override
  String get loadingProfile => 'Loading your profile…';

  @override
  String get profileSaveExplanation =>
      'Your photo and profile are saved to your account when you tap Save. They identify you in your profile and to care members.';

  @override
  String get contactPhoneLabel => 'Contact phone';

  @override
  String get wechatOfficialAccount => 'WeChat official account';

  @override
  String get addSupportContact => 'Add support contact';

  @override
  String get contactPreparationHint =>
      'Have your device model and the time of the issue ready before contacting support.';

  @override
  String get supportPrivacyWarning =>
      'Do not send verification codes, passwords or complete health records to unofficial accounts.';

  @override
  String get brandHealthTitle => 'Saydian Health';

  @override
  String get accountAndSecurity => 'Account and security';

  @override
  String get cityNameLabel => 'City name';

  @override
  String get cityNameExample => 'For example: London';

  @override
  String get visitStoreHint =>
      'Visit the store to choose a device that suits you.';

  @override
  String get selectReportPlan => 'Choose a report plan';

  @override
  String get reportPaidContentHint =>
      'Alerts for clear abnormalities remain free. Paid content includes more detailed trend summaries and everyday wellness suggestions.';

  @override
  String get wechatPayLabel => 'WeChat Pay';

  @override
  String get alipayLabel => 'Alipay';

  @override
  String get reportPurchaseTerms =>
      'Check the plan and price before purchasing. Health membership does not renew automatically, and unused credits do not roll over after expiry.';

  @override
  String get detailedHealthReport => 'Detailed health report';

  @override
  String get reportInsufficientDataHint =>
      'No payment order is created when data is insufficient. Wear your watch as usual, sync its data, then try again.';

  @override
  String get waitingPaymentConfirmation => 'Waiting for payment confirmation';

  @override
  String get paymentReturnRefreshHint =>
      'After paying, return to this page and refresh. Your available credits will update once the payment is verified.';

  @override
  String get reportPurchaseDataMissing =>
      'There is not enough data yet, so purchasing is unavailable.';

  @override
  String get heartRateUpperLimit => 'Heart rate upper limit';

  @override
  String get systolicUpperLimit => 'Systolic pressure upper limit';

  @override
  String get diastolicUpperLimit => 'Diastolic pressure upper limit';

  @override
  String get temperatureUpperLimit => 'Temperature upper limit';

  @override
  String get calibrateOnWatchHint =>
      'Follow the instructions on your watch to complete calibration.';

  @override
  String get spotCheckCuffHint =>
      'This is a resting spot check for reference only. For a more accurate reading, use the watch’s pump-and-cuff measurement.';

  @override
  String get setHealthUpperLimits => 'Set upper-limit health alerts';

  @override
  String get healthUpperLimitHint =>
      'Receive an alert when a value exceeds your chosen limit.';

  @override
  String get heartRateAlertLabel => 'Heart rate alert';

  @override
  String get heartRateAlertHint =>
      'Alerts when heart rate exceeds the set limit';

  @override
  String get bloodPressureAlertLabel => 'Blood pressure alert';

  @override
  String get bloodPressureAlertHint =>
      'Alerts when systolic or diastolic pressure exceeds the set limit';

  @override
  String get temperatureAlertLabel => 'Temperature alert';

  @override
  String get temperatureAlertHint =>
      'Alerts when temperature exceeds the set limit';

  @override
  String get saveHealthAlerts => 'Save alert settings';

  @override
  String get healthAlertHistory => 'Alert history';

  @override
  String get seekProfessionalCare =>
      'If you feel significantly unwell, seek advice from a healthcare professional promptly.';

  @override
  String get watchHealthReference =>
      'Watch measurements are for everyday wellness reference.';

  @override
  String get calibrationReferenceHint =>
      'Use a value just measured with professional equipment.';

  @override
  String get calibrationWearerHint =>
      'Calibration applies only to the current wearer. Disable or repeat calibration when the wearer changes.';

  @override
  String get enableCalibration => 'Enable calibration';

  @override
  String get calibrationDisabledHint =>
      'Turning this off restores the watch’s general measurement mode.';

  @override
  String get diastolicLowerLabel => 'Diastolic pressure (lower number)';

  @override
  String get longTermTrendHint =>
      'Long-term trends provide more useful context.';

  @override
  String get measurementVariationHint =>
      'A single measurement can be affected by fit, activity and surroundings. If you feel unwell, consult a healthcare professional.';

  @override
  String get ecgDetailTitle => 'ECG details';

  @override
  String get viewFullReport => 'View full report';

  @override
  String get ecgReferenceHint => 'ECG results are for wellness reference only.';

  @override
  String get ecgVariationSafety =>
      'Individual measurements are affected by fit, activity and surroundings and cannot replace a medical diagnosis. If you feel unwell, seek medical care promptly.';

  @override
  String get ecgBasicOnly =>
      'Only basic ECG data was returned for this measurement.';

  @override
  String get measurementIndicators => 'Measurement indicators';

  @override
  String get riskIndicatorsMissing =>
      'The watch did not return risk indicators for this measurement.';

  @override
  String get riskAnalysisTitle => 'Risk analysis';

  @override
  String get watchAlgorithmReference =>
      'The values below come from the watch’s algorithm and are for health trend reference only.';

  @override
  String get ecgHealthReport => 'ECG health report';

  @override
  String get brandedEcgReport => 'Saydian · ECG health report';

  @override
  String get ecgReportSafety =>
      'Note: this report uses watch measurement data. It is for wellness reference only and cannot replace a doctor’s diagnosis.';

  @override
  String get installedWatchFaces => 'Installed watch faces';

  @override
  String get switchInstalledWatchFace =>
      'Switch between watch faces already on your watch.';

  @override
  String get useSelectedWatchFace => 'Use';

  @override
  String get downloadUseWatchFace => 'Tap to download and use';

  @override
  String get photoWatchFaceHint =>
      'Choose a clear photo, check the preview, then send it to your watch.';

  @override
  String get timeDisplayPosition => 'Time position';

  @override
  String get transferSetWatchFace => 'Send and set as watch face';

  @override
  String get watchTransferKeepNear =>
      'Keep the watch near your phone during transfer and stay on this page.';

  @override
  String get callMediaAudio => 'Call and media audio';

  @override
  String get useCelsius => 'Use Celsius';

  @override
  String get sosContactHint =>
      'When SOS is triggered on the watch, it will first contact the person selected here. Choose a family member you contact regularly.';

  @override
  String get noHealthAssessments =>
      'No configurable health assessments are available on this watch.';

  @override
  String get modelFeaturesVary =>
      'Supported features vary by model. Refer to the features shown on your watch.';

  @override
  String get assessmentEnabledHint =>
      'When enabled, the watch provides daily trend information.';

  @override
  String get assessmentSafety =>
      'Supplementary assessments are for everyday wellness reference, not diagnosis or treatment.';

  @override
  String get autoMonitorIntervalHint =>
      'When enabled, the watch measures automatically at its configured interval.';

  @override
  String get watchHeartRateAlert => 'Watch heart rate alert';

  @override
  String get sustainedLimitWatchAlert =>
      'The watch alerts you if the value stays above the limit.';

  @override
  String get ecgWaveformTitle => 'ECG waveform';

  @override
  String get ecgWaveformMissing =>
      'No valid ECG waveform was returned for this measurement.';

  @override
  String get ecgElectrodeHint =>
      'Heart rate and HRV results remain available. Keep touching the watch electrode throughout your next measurement.';

  @override
  String get screenAutoTimeHint =>
      'The watch adjusts automatically based on the time.';

  @override
  String get raiseWristScreenHint =>
      'The screen lights up when you raise your wrist.';

  @override
  String get watchHighHeartRate => 'High heart rate alert';

  @override
  String get watchThresholdHint =>
      'The watch alerts you when the limit is reached.';

  @override
  String get watchMeasurementSafety =>
      'Measurements are for wellness reference only, not diagnosis or treatment.';

  @override
  String get healthDataExplanation => 'About health data';

  @override
  String get trendUnavailable => 'Trends are temporarily unavailable.';

  @override
  String get recentData => 'Recent data';

  @override
  String get trendReferenceOnly =>
      'Trends are for everyday wellness reference only.';

  @override
  String get trendVariationSafety =>
      'Individual and period-to-period changes may be affected by fit, activity and surroundings and do not replace a medical diagnosis.';

  @override
  String get watchFaceDownloadHint =>
      'After downloading, the watch face will be sent to your watch. Keep the watch near your phone and stay on this page during transfer.';

  @override
  String get refreshWatchFaces => 'Refresh watch faces';

  @override
  String get openTestFlight => 'Open TestFlight';

  @override
  String get articlesEmpty => 'No articles are available in this category yet.';

  @override
  String get articlesUnavailable => 'The health library could not be loaded.';

  @override
  String get articleContentUnavailable =>
      'The article content is not available yet.';

  @override
  String get imageUnavailable => 'The image could not be loaded.';

  @override
  String get allowNotifications => 'Allow notifications';

  @override
  String get updateNow => 'Update now';

  @override
  String get analysisConsentUnavailable =>
      'Health analysis is not available yet. Existing reports are still available.';

  @override
  String get analysisReadAgree =>
      'I have read and agree to the health analysis information above.';

  @override
  String get agreeContinue => 'Agree and continue';

  @override
  String get notGrantNow => 'Not now';

  @override
  String get analysisConsentSaved => 'Health analysis consent saved.';

  @override
  String get withdrawAnalysisConsent => 'Withdraw health analysis consent?';

  @override
  String get withdrawAnalysisExplanation =>
      'No new detailed reports will be generated. Existing reports that have not been refunded will remain available.';

  @override
  String get confirmWithdraw => 'Confirm withdrawal';

  @override
  String get analysisConsentWithdrawn => 'Health analysis consent withdrawn.';

  @override
  String get consentGrantedHint =>
      'Consent given. You can withdraw it at any time.';

  @override
  String get consentNeededHint =>
      'Separate consent is required before generating a detailed report.';

  @override
  String get withdraw => 'Withdraw';

  @override
  String get reportHistory => 'Report history';

  @override
  String get saving => 'Saving…';

  @override
  String get pauseWorkout => 'Pause workout';

  @override
  String get resumeWorkout => 'Resume workout';

  @override
  String get finishWorkout => 'Finish workout';

  @override
  String get watchDistance => 'Watch distance';

  @override
  String get watchSteps => 'Watch steps';

  @override
  String get liveHeartRate => 'Live heart rate';

  @override
  String get watchCalories => 'Watch calories';

  @override
  String get connectForWorkout =>
      'Connect your watch on the Device page first. Your watch will record the workout.';

  @override
  String latestVersion(String version) {
    return 'You are using the latest version: V$version';
  }

  @override
  String workoutPaused(String mode) {
    return '$mode paused';
  }

  @override
  String workoutInProgress(String mode) {
    return '$mode in progress';
  }

  @override
  String workoutReady(String mode) {
    return 'Ready to start $mode';
  }

  @override
  String startWorkout(String mode) {
    return 'Start $mode';
  }

  @override
  String finishOtherWorkout(String mode) {
    return 'Finish $mode first';
  }

  @override
  String workoutDetails(String mode) {
    return '$mode details';
  }

  @override
  String stepCount(int count) {
    return '$count steps';
  }

  @override
  String get appName => 'Saydian';

  @override
  String get searchingNearby => 'Searching for nearby watches';

  @override
  String get noDevices => 'No devices found';

  @override
  String get selectWatch => 'Select the watch you want to connect';

  @override
  String get searchingHint => 'Searching. Keep your watch near your phone.';

  @override
  String get activateWatch =>
      'Charge your watch to activate it, then place it near your phone';

  @override
  String get checkWatchConnection =>
      'Check that your watch is charged and not connected to another phone, then search again';

  @override
  String get running => 'Running';

  @override
  String get walking => 'Walking';

  @override
  String get cycling => 'Cycling';

  @override
  String get hiking => 'Hiking';

  @override
  String get mountaineering => 'Mountaineering';

  @override
  String metricAnalysis(String metric) {
    return '$metric analysis';
  }

  @override
  String metricAllData(String metric) {
    return 'All $metric data';
  }

  @override
  String metricMeasurement(String metric) {
    return 'Measure $metric';
  }

  @override
  String metricCalibration(String metric) {
    return 'Calibrate $metric';
  }

  @override
  String metricDetails(String metric) {
    return '$metric details';
  }

  @override
  String get add => 'Add';

  @override
  String get endTime => 'End time';

  @override
  String get reminderInterval => 'Reminder interval';

  @override
  String get reminderName => 'Reminder name';

  @override
  String get repeat => 'Repeat';

  @override
  String get addAlarm => 'Add alarm';

  @override
  String get alarmTime => 'Alarm time';

  @override
  String get enableAlarm => 'Enable alarm';

  @override
  String get emergencyContact => 'SOS emergency contact';

  @override
  String get selectEmergencyContact => 'Select SOS contact';

  @override
  String get confirmEmergencyContact => 'Set as SOS contact';

  @override
  String get addWorldClock => 'Add world clock';

  @override
  String get autoBrightness => 'Automatic brightness';

  @override
  String get raiseToWake => 'Raise to wake';

  @override
  String get activeTime => 'Active time';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get helpFeedback => 'Help and feedback';

  @override
  String get issueType => 'Issue type';

  @override
  String get issueDescription => 'Description';

  @override
  String get describeIssue =>
      'Describe the problem and the steps to reproduce it';

  @override
  String get contactOptional => 'Contact information (optional)';

  @override
  String get phoneOrEmail => 'Phone number or email';

  @override
  String get call => 'Call';

  @override
  String get addContact => 'Add contact';

  @override
  String get contactName => 'Name';

  @override
  String get contactPhone => 'Phone number';

  @override
  String get cart => 'Cart';

  @override
  String get searchProducts => 'Search products';

  @override
  String get selectVariant => 'Select an option';

  @override
  String get variant => 'Options';

  @override
  String get buyNow => 'Buy now';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get returnShop => 'Back to shop';

  @override
  String get selectAll => 'Select all';

  @override
  String get checkout => 'Checkout';

  @override
  String get clearCart => 'Clear cart?';

  @override
  String get clearCartHint => 'All items in your cart will be removed.';

  @override
  String get viewOrder => 'View order';

  @override
  String get confirmOrder => 'Confirm order';

  @override
  String get productInfo => 'Product information';

  @override
  String get orderNote => 'Note';

  @override
  String get noteToSeller => 'Leave a note for the seller';

  @override
  String get paymentCheckout => 'Payment';

  @override
  String get orderTotal => 'Order total';

  @override
  String get selectPayment => 'Select payment method';

  @override
  String get refreshOrder => 'Refresh order status';

  @override
  String get viewMyOrders => 'View my orders';

  @override
  String get backToProduct => 'Back to product';

  @override
  String get newAddress => 'Add address';

  @override
  String get recipient => 'Recipient';

  @override
  String get province => 'State / province';

  @override
  String get district => 'District / county';

  @override
  String get streetAddress => 'Street address';

  @override
  String get defaultAddress => 'Set as default address';

  @override
  String get shippingInfo => 'Shipping information';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get refresh => 'Refresh';

  @override
  String get useWatchFace => 'Use this watch face?';

  @override
  String get downloadAndUse => 'Download and use';

  @override
  String get watchFaceFailed => 'Could not set the watch face';

  @override
  String get statusNormal => 'Normal';

  @override
  String get statusRecorded => 'Recorded';

  @override
  String get statusAttention => 'Check reading';

  @override
  String get statusOutOfRange => 'Outside reference';

  @override
  String get statusLow => 'Low';

  @override
  String get statusHigh => 'High';

  @override
  String get careInviteHint =>
      'Invite an international Saydian account by email or international phone number.';

  @override
  String get careSharingHint =>
      'Only the measurements you select are shared. You can stop sharing at any time.';

  @override
  String get carePending => 'Pending';

  @override
  String get careActive => 'Active';

  @override
  String get careClosed => 'Closed';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get stopSharing => 'Stop sharing';

  @override
  String get sharedMeasurements => 'Shared measurements';

  @override
  String get invitationSent => 'Invitation sent';

  @override
  String get invalidCareContact =>
      'Enter an email or a phone number with country code.';

  @override
  String get carePermissionDenied =>
      'This measurement has not been shared with you.';

  @override
  String get reload => 'Reload';

  @override
  String get applyAfterSales => 'Request support';

  @override
  String get analysisConsent => 'Health analysis consent';

  @override
  String get workoutRecords => 'Workout records';

  @override
  String get startTime => 'Start time';

  @override
  String get addCare => 'Add a care member';

  @override
  String get confirmReceipt => 'Confirm receipt';

  @override
  String get personalInfo => 'Personal information';

  @override
  String get deliveryAddresses => 'Delivery addresses';

  @override
  String get readAgain => 'Read again';

  @override
  String get smsCode => 'SMS verification code';

  @override
  String get watchFaceShop => 'Watch face store';

  @override
  String get selectCity => 'Select city';

  @override
  String get city => 'City';

  @override
  String get confirm => 'Confirm';

  @override
  String get productDetails => 'Product details';

  @override
  String get clear => 'Clear';

  @override
  String get settings => 'Settings';

  @override
  String get goals => 'Goals';

  @override
  String get send => 'Send';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get devicesFound => 'Devices found';

  @override
  String get connect => 'Connect';

  @override
  String get searchAgain => 'Search again';

  @override
  String get searchRecovery =>
      'Try turning Bluetooth off and on, moving the watch closer, or disconnecting it from another phone.';

  @override
  String get deviceName => 'Device name';

  @override
  String get deviceModel => 'Device model';

  @override
  String get connectionStatus => 'Connection status';

  @override
  String get firmwareVersion => 'Firmware version';

  @override
  String get watchBattery => 'Watch battery';

  @override
  String get chargingStatus => 'Charging status';

  @override
  String get messageDetails => 'Message details';

  @override
  String get dailySummary => 'Daily summary';

  @override
  String get remoteMemberData => 'Care member’s data';

  @override
  String get ecgWaveformUnavailable => 'No ECG waveform available';

  @override
  String get orderDetails => 'Order details';

  @override
  String get viewShipping => 'Track shipment';

  @override
  String get measureAgain => 'Measure again';

  @override
  String get checkPaymentStatus => 'Check payment status';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get confirmDeleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountHint =>
      'You will be signed out after your account and related data have been deleted.';

  @override
  String get confirmDelete => 'Confirm deletion';

  @override
  String get exit => 'Exit';

  @override
  String get nickname => 'Nickname';

  @override
  String get gender => 'Gender';

  @override
  String get birthDate => 'Date of birth';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get choose => 'Select';

  @override
  String get connectWatchToUse => 'Connect a watch to use this feature';

  @override
  String get selectPhoto => 'Select photo';

  @override
  String get saved => 'Saved';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get notificationsOff => 'System notifications are off';

  @override
  String get privacyAgreement => 'Privacy policy';

  @override
  String get appPermissions => 'App permissions';

  @override
  String get openSystemSettings => 'Open system app settings';

  @override
  String get monitoringHint =>
      'Available health monitoring settings appear after connecting your watch.';

  @override
  String get previewUnavailable => 'Preview unavailable';

  @override
  String get distance => 'Distance';

  @override
  String get calories => 'Calories';

  @override
  String get healthProfile => 'Health profile';

  @override
  String get photoWatchFace => 'Photo watch face';

  @override
  String get cameraRemote => 'Camera remote';

  @override
  String get phoneCalls => 'Phone calls';

  @override
  String get contacts => 'Contacts';

  @override
  String get notifications => 'Notifications';

  @override
  String get alarms => 'Alarms';

  @override
  String get weather => 'Weather';

  @override
  String get worldClock => 'World clock';

  @override
  String get healthReminders => 'Wellness reminders';

  @override
  String get healthMonitoring => 'Health monitoring';

  @override
  String get healthAssessment => 'Wellness assessment';

  @override
  String get screenDisplay => 'Display';

  @override
  String get scanning => 'Searching…';

  @override
  String get connecting => 'Connecting…';

  @override
  String get waitingConfirmation => 'Waiting for confirmation';

  @override
  String get syncing => 'Syncing…';

  @override
  String get measuring => 'Measuring…';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get tapToOpen => 'Tap to open';

  @override
  String get deviceInfoHint => 'View device information';

  @override
  String get connectionInstructions =>
      '1. Turn on Bluetooth and allow nearby device access.\n2. Charge your watch and place it near your phone.\n3. Tap Find devices and select your watch.\n4. Confirm on the watch if prompted.';

  @override
  String get syncNearbyHint =>
      'Keep your watch charged and near your phone while connecting or syncing.';

  @override
  String get invalidCode => 'Check the code and try again';

  @override
  String get codeExpired => 'This code has expired. Request a new code.';

  @override
  String get tooManyAttempts => 'Too many attempts. Please wait and try again.';

  @override
  String get readTerms => 'Read the terms and privacy policy to continue';

  @override
  String verificationSentTo(String contact) {
    return 'Code sent to $contact';
  }

  @override
  String get addSmartDevice => 'Add a smart device';

  @override
  String get watchNearbyHint =>
      'Turn on Bluetooth and keep your watch near your phone';

  @override
  String get startSearch => 'Find devices';

  @override
  String get readingData => 'Reading data…';

  @override
  String get readingCapabilities => 'Checking watch features…';

  @override
  String get capabilitiesHint =>
      'Only features available on this watch will be shown';

  @override
  String get capabilitiesFailed => 'Could not read this watch’s features';

  @override
  String get keepWatchNear => 'Keep your watch near your phone and try again';

  @override
  String get personalizeWatch => 'Watch faces & style';

  @override
  String get signInCloudHint => 'Sign in to use cloud health services';

  @override
  String get aiQuestion => 'Ask AI';

  @override
  String get aiQuestionHint => 'Ask your AI assistant about wellbeing';

  @override
  String get language => 'Language';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get signOut => 'Sign out';

  @override
  String get email => 'Email';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get countryRegion => 'Country or region';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get verificationCode => 'Verification code';

  @override
  String get sendCode => 'Send code';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get createAccount => 'Create account';

  @override
  String get continueAction => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Try again';

  @override
  String get loading => 'Loading…';

  @override
  String get pleaseWait => 'Please wait…';

  @override
  String get emailOrPhone => 'Email or phone number';

  @override
  String get enterEmail => 'Enter your email address';

  @override
  String get enterPhone => 'Enter your phone number';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get passwordRequirement =>
      'At least 8 characters. Up to 72 English letters or numbers; fewer for other characters.';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get invalidPhone => 'Check the country code and phone number';

  @override
  String get codeSent => 'Code sent. Check your messages.';

  @override
  String get codeRequired => 'Enter the verification code';

  @override
  String get consentRequired =>
      'Please read and accept the terms and privacy policy';

  @override
  String get agreeToTerms => 'I have read and agree to';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get registrationUnavailable =>
      'Registration is temporarily unavailable. Please try again later.';

  @override
  String get loginFailed =>
      'Could not sign in. Please check your details and try again.';

  @override
  String get accountAlreadyExists =>
      'This account already exists. Sign in instead.';

  @override
  String get networkUnavailable =>
      'Check your internet connection and try again';

  @override
  String get serviceUnavailable =>
      'This feature is temporarily unavailable. Please try again later.';

  @override
  String get accountCreated => 'Your account is ready';

  @override
  String get passwordReset => 'Password updated';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get noAccount => 'New to Saydian?';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get selectCountry => 'Select country or region';

  @override
  String get registrationMethod => 'Register with';

  @override
  String get changeLanguageFailed =>
      'Could not save the language. Please try again.';

  @override
  String get health => 'Health';

  @override
  String get device => 'Device';

  @override
  String get profile => 'Me';

  @override
  String get healthData => 'Health data';

  @override
  String get allData => 'All data';

  @override
  String get healthRecords => 'Health records';

  @override
  String get workoutsAndRecords => 'Workouts and records';

  @override
  String get healthDisclaimer =>
      'Measurements are for wellness reference only. Consult a healthcare professional if you feel unwell.';

  @override
  String get healthSafetyAdvice =>
      'Rest and measure again. If you feel unwell, seek medical advice.';

  @override
  String get defaultUser => 'Saydian user';

  @override
  String get dailyGreeting => 'Take care of yourself today';

  @override
  String get messages => 'Messages';

  @override
  String get aiAssistant => 'AI wellness assistant';

  @override
  String get aiAssistantIntro => 'Ask me a question about your wellbeing.';

  @override
  String get askNow => 'Ask now';

  @override
  String get remoteCare => 'Family care';

  @override
  String get healthLibrary => 'Health library';

  @override
  String get healthAlerts => 'Health alerts';

  @override
  String get shop => 'Shop';

  @override
  String get connectWatch => 'Connect a watch';

  @override
  String get addDevice => 'Add device';

  @override
  String get connectWatchForData =>
      'Connect your watch to view supported health data';

  @override
  String get noHealthData => 'No health data to show yet';

  @override
  String get noData => 'No data yet';

  @override
  String get connected => 'Connected';

  @override
  String get notConnected => 'Not connected';

  @override
  String get online => 'Online';

  @override
  String get syncData => 'Sync data';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get findWatch => 'Find watch';

  @override
  String get watchFaces => 'Watch faces';

  @override
  String get deviceFeatures => 'Device features';

  @override
  String get aboutDevice => 'About device';

  @override
  String get connectionHelp => 'Connection help';

  @override
  String get searchNearbyWatch => 'Find and connect a nearby Saydian watch';

  @override
  String get useWatch => 'Please use this feature on your watch';

  @override
  String get myOrders => 'My orders';

  @override
  String get all => 'All';

  @override
  String get awaitingPayment => 'To pay';

  @override
  String get awaitingShipment => 'To ship';

  @override
  String get awaitingDelivery => 'To receive';

  @override
  String get afterSales => 'Returns & support';

  @override
  String get careMembers => 'Care members';

  @override
  String get unitSettings => 'Units';

  @override
  String get unitSettingsHint => 'Choose distance, temperature and other units';

  @override
  String get myServices => 'My services';

  @override
  String get accountSettings => 'Account settings';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get permissions => 'Permissions';

  @override
  String get feedback => 'Feedback';

  @override
  String get customerService => 'Customer support';

  @override
  String get aboutApp => 'About Saydian';

  @override
  String get security => 'Account security';

  @override
  String get goToSettings => 'Open settings';

  @override
  String get close => 'Close';

  @override
  String get view => 'View';

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get onlineUpdate => 'App update';

  @override
  String get updateRequired => 'Update to continue';

  @override
  String get updateReady => 'An update is ready';

  @override
  String get preparingUpdate => 'Preparing a secure update…';

  @override
  String get openingUpdate => 'Opening the system update page…';

  @override
  String get updateAppStore => 'Update in the App Store';

  @override
  String get updateStore => 'Update in the app store';

  @override
  String get downloadAndInstall => 'Download and install securely';

  @override
  String get gettingReady => 'Getting things ready…';

  @override
  String get enableNotifications => 'Enable Saydian notifications';

  @override
  String get notificationExplanation =>
      'Get health alerts and care invitations. Health values are not shown on the lock screen. You can turn notifications off in system settings.';

  @override
  String get notNow => 'Not now';

  @override
  String get enable => 'Enable';

  @override
  String get newCareRequest => 'New care request';

  @override
  String get dismissHealthAlert => 'Dismiss health alert';

  @override
  String get dismissCareAlert => 'Dismiss care reminder';

  @override
  String get bloodPressure => 'Blood pressure';

  @override
  String get heartRate => 'Heart rate';

  @override
  String get bloodOxygen => 'Blood oxygen';

  @override
  String get bloodGlucose => 'Blood glucose';

  @override
  String get bodyTemperature => 'Temperature';

  @override
  String get ecg => 'ECG';

  @override
  String get hrv => 'HRV';

  @override
  String get bodyComposition => 'Body composition';

  @override
  String get bloodComposition => 'Blood composition';

  @override
  String get sleep => 'Sleep';

  @override
  String get steps => 'Steps';

  @override
  String get workouts => 'Workouts';

  @override
  String welcome(String name) {
    return 'Hello, $name';
  }

  @override
  String resendCode(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String memberId(String id) {
    return 'Member ID: $id';
  }

  @override
  String unreadMessages(int count) {
    return 'Messages, $count unread';
  }

  @override
  String recordCount(int count) {
    return '$count records';
  }

  @override
  String memberCount(int count) {
    return '$count members';
  }

  @override
  String versionBuild(String version, int build) {
    return 'V$version · Build $build';
  }
}
