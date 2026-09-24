import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @scanLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on location'**
  String get scanLocationTitle;

  /// No description provided for @scanLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on your phone’s location services to find nearby rings, then return to this page.'**
  String get scanLocationHint;

  /// No description provided for @scanPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow device access'**
  String get scanPermissionTitle;

  /// No description provided for @scanPermissionHint.
  ///
  /// In en, this message translates to:
  /// **'Allow the required permissions in Settings, then return to find your ring.'**
  String get scanPermissionHint;

  /// No description provided for @loginProtectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in protection'**
  String get loginProtectionTitle;

  /// No description provided for @verifyContactToReset.
  ///
  /// In en, this message translates to:
  /// **'Verify your email or phone number to reset your password.'**
  String get verifyContactToReset;

  /// No description provided for @workoutStartOnWatch.
  ///
  /// In en, this message translates to:
  /// **'This ring cannot currently start a workout from the app. You can still view synced daily activity and workout records.'**
  String get workoutStartOnWatch;

  /// No description provided for @showMoreSports.
  ///
  /// In en, this message translates to:
  /// **'More workouts'**
  String get showMoreSports;

  /// No description provided for @collapseSports.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get collapseSports;

  /// No description provided for @wearRingPhoneStart.
  ///
  /// In en, this message translates to:
  /// **'Wear ring · Start on phone'**
  String get wearRingPhoneStart;

  /// No description provided for @startWorkoutToday.
  ///
  /// In en, this message translates to:
  /// **'Start today’s workout'**
  String get startWorkoutToday;

  /// No description provided for @selectWorkoutPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a workout on your phone and keep the ring connected'**
  String get selectWorkoutPhoneHint;

  /// No description provided for @finishWorkoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Finish this workout?'**
  String get finishWorkoutConfirm;

  /// No description provided for @finishLeaveWorkoutHint.
  ///
  /// In en, this message translates to:
  /// **'Before leaving, the ring workout will stop and the recorded duration and route will be saved.'**
  String get finishLeaveWorkoutHint;

  /// No description provided for @finishAndLeave.
  ///
  /// In en, this message translates to:
  /// **'Finish and leave'**
  String get finishAndLeave;

  /// No description provided for @workoutRouteMissing.
  ///
  /// In en, this message translates to:
  /// **'No phone-recorded route is available for this session. The ring workout data is still saved.'**
  String get workoutRouteMissing;

  /// No description provided for @workoutDuration.
  ///
  /// In en, this message translates to:
  /// **'Workout duration'**
  String get workoutDuration;

  /// No description provided for @workoutWatchHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Ring heart rate'**
  String get workoutWatchHeartRate;

  /// No description provided for @messageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Check your connection and try again.'**
  String get messageSendFailed;

  /// No description provided for @noWatchShopHint.
  ///
  /// In en, this message translates to:
  /// **'Need another device? Visit the Say Ring store.'**
  String get noWatchShopHint;

  /// No description provided for @notificationInAppHint.
  ///
  /// In en, this message translates to:
  /// **'In-app messages and unread indicators remain available. Enable notifications to receive care invitations and health alerts promptly.'**
  String get notificationInAppHint;

  /// No description provided for @healthAlertSafetyHint.
  ///
  /// In en, this message translates to:
  /// **'Health alerts provide timely reminders, not medical diagnoses. If you feel significantly unwell, seek medical care promptly.'**
  String get healthAlertSafetyHint;

  /// No description provided for @afterSalesService.
  ///
  /// In en, this message translates to:
  /// **'After-sales service'**
  String get afterSalesService;

  /// No description provided for @afterSalesApplyHint.
  ///
  /// In en, this message translates to:
  /// **'Select the item and enter the reason and requested amount. After submitting, check the status in your orders.'**
  String get afterSalesApplyHint;

  /// No description provided for @afterSalesAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'An after-sales request has already been submitted for this item. Please wait for the store team to review it.'**
  String get afterSalesAlreadySubmitted;

  /// No description provided for @afterSalesType.
  ///
  /// In en, this message translates to:
  /// **'Request type'**
  String get afterSalesType;

  /// No description provided for @requestedAmount.
  ///
  /// In en, this message translates to:
  /// **'Requested amount'**
  String get requestedAmount;

  /// No description provided for @afterSalesReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for request'**
  String get afterSalesReason;

  /// No description provided for @describeProblem.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem'**
  String get describeProblem;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get amountPaid;

  /// No description provided for @orderDetailsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load order details. Please try again later.'**
  String get orderDetailsLoadFailed;

  /// No description provided for @confirmItemReceived.
  ///
  /// In en, this message translates to:
  /// **'Have you received the items?'**
  String get confirmItemReceived;

  /// No description provided for @confirmReceiptHint.
  ///
  /// In en, this message translates to:
  /// **'Confirming receipt will complete the order. Do not confirm if you have not received the items.'**
  String get confirmReceiptHint;

  /// No description provided for @notConfirmYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notConfirmYet;

  /// No description provided for @unitChangesHint.
  ///
  /// In en, this message translates to:
  /// **'Unit changes take effect immediately. You may need to set them again after reinstalling the app.'**
  String get unitChangesHint;

  /// No description provided for @goalSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal settings'**
  String get goalSettingsTitle;

  /// No description provided for @dailyStepGoalField.
  ///
  /// In en, this message translates to:
  /// **'Daily step goal (steps)'**
  String get dailyStepGoalField;

  /// No description provided for @dailyDistanceGoalField.
  ///
  /// In en, this message translates to:
  /// **'Daily distance goal (km)'**
  String get dailyDistanceGoalField;

  /// No description provided for @dailyCalorieGoalField.
  ///
  /// In en, this message translates to:
  /// **'Daily calorie goal (kcal)'**
  String get dailyCalorieGoalField;

  /// No description provided for @saveGoals.
  ///
  /// In en, this message translates to:
  /// **'Save goals'**
  String get saveGoals;

  /// No description provided for @viewAccountAddresses.
  ///
  /// In en, this message translates to:
  /// **'View shipping addresses in your account'**
  String get viewAccountAddresses;

  /// No description provided for @loadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile…'**
  String get loadingProfile;

  /// No description provided for @profileSaveExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your photo and profile are saved to your account when you tap Save. They identify you in your profile and to care members.'**
  String get profileSaveExplanation;

  /// No description provided for @contactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get contactPhoneLabel;

  /// No description provided for @wechatOfficialAccount.
  ///
  /// In en, this message translates to:
  /// **'WeChat official account'**
  String get wechatOfficialAccount;

  /// No description provided for @addSupportContact.
  ///
  /// In en, this message translates to:
  /// **'Add support contact'**
  String get addSupportContact;

  /// No description provided for @contactPreparationHint.
  ///
  /// In en, this message translates to:
  /// **'Have your device model and the time of the issue ready before contacting support.'**
  String get contactPreparationHint;

  /// No description provided for @supportPrivacyWarning.
  ///
  /// In en, this message translates to:
  /// **'Do not send verification codes, passwords or complete health records to unofficial accounts.'**
  String get supportPrivacyWarning;

  /// No description provided for @brandHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Say Ring Health'**
  String get brandHealthTitle;

  /// No description provided for @accountAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account and security'**
  String get accountAndSecurity;

  /// No description provided for @cityNameLabel.
  ///
  /// In en, this message translates to:
  /// **'City name'**
  String get cityNameLabel;

  /// No description provided for @cityNameExample.
  ///
  /// In en, this message translates to:
  /// **'For example: London'**
  String get cityNameExample;

  /// No description provided for @visitStoreHint.
  ///
  /// In en, this message translates to:
  /// **'Visit the store to choose a device that suits you.'**
  String get visitStoreHint;

  /// No description provided for @selectReportPlan.
  ///
  /// In en, this message translates to:
  /// **'Choose a report plan'**
  String get selectReportPlan;

  /// No description provided for @reportPaidContentHint.
  ///
  /// In en, this message translates to:
  /// **'Alerts for clear abnormalities remain free. Paid content includes more detailed trend summaries and everyday wellness suggestions.'**
  String get reportPaidContentHint;

  /// No description provided for @wechatPayLabel.
  ///
  /// In en, this message translates to:
  /// **'WeChat Pay'**
  String get wechatPayLabel;

  /// No description provided for @alipayLabel.
  ///
  /// In en, this message translates to:
  /// **'Alipay'**
  String get alipayLabel;

  /// No description provided for @reportPurchaseTerms.
  ///
  /// In en, this message translates to:
  /// **'Check the plan and price before purchasing. Health membership does not renew automatically, and unused credits do not roll over after expiry.'**
  String get reportPurchaseTerms;

  /// No description provided for @detailedHealthReport.
  ///
  /// In en, this message translates to:
  /// **'Detailed health report'**
  String get detailedHealthReport;

  /// No description provided for @reportInsufficientDataHint.
  ///
  /// In en, this message translates to:
  /// **'No payment order is created when data is insufficient. Wear your ring as usual, sync its data, then try again.'**
  String get reportInsufficientDataHint;

  /// No description provided for @waitingPaymentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment confirmation'**
  String get waitingPaymentConfirmation;

  /// No description provided for @paymentReturnRefreshHint.
  ///
  /// In en, this message translates to:
  /// **'After paying, return to this page and refresh. Your available credits will update once the payment is verified.'**
  String get paymentReturnRefreshHint;

  /// No description provided for @reportPurchaseDataMissing.
  ///
  /// In en, this message translates to:
  /// **'There is not enough data yet, so purchasing is unavailable.'**
  String get reportPurchaseDataMissing;

  /// No description provided for @heartRateUpperLimit.
  ///
  /// In en, this message translates to:
  /// **'Heart rate upper limit'**
  String get heartRateUpperLimit;

  /// No description provided for @systolicUpperLimit.
  ///
  /// In en, this message translates to:
  /// **'Systolic pressure upper limit'**
  String get systolicUpperLimit;

  /// No description provided for @diastolicUpperLimit.
  ///
  /// In en, this message translates to:
  /// **'Diastolic pressure upper limit'**
  String get diastolicUpperLimit;

  /// No description provided for @temperatureUpperLimit.
  ///
  /// In en, this message translates to:
  /// **'Temperature upper limit'**
  String get temperatureUpperLimit;

  /// No description provided for @calibrateOnWatchHint.
  ///
  /// In en, this message translates to:
  /// **'Follow the instructions on your ring to complete calibration.'**
  String get calibrateOnWatchHint;

  /// No description provided for @spotCheckCuffHint.
  ///
  /// In en, this message translates to:
  /// **'This is a resting spot check for reference only. For a more accurate reading, use a validated upper-arm blood pressure monitor.'**
  String get spotCheckCuffHint;

  /// No description provided for @setHealthUpperLimits.
  ///
  /// In en, this message translates to:
  /// **'Set upper-limit health alerts'**
  String get setHealthUpperLimits;

  /// No description provided for @healthUpperLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Receive an alert when a value exceeds your chosen limit.'**
  String get healthUpperLimitHint;

  /// No description provided for @heartRateAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'Heart rate alert'**
  String get heartRateAlertLabel;

  /// No description provided for @heartRateAlertHint.
  ///
  /// In en, this message translates to:
  /// **'Alerts when heart rate exceeds the set limit'**
  String get heartRateAlertHint;

  /// No description provided for @bloodPressureAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure alert'**
  String get bloodPressureAlertLabel;

  /// No description provided for @bloodPressureAlertHint.
  ///
  /// In en, this message translates to:
  /// **'Alerts when systolic or diastolic pressure exceeds the set limit'**
  String get bloodPressureAlertHint;

  /// No description provided for @temperatureAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature alert'**
  String get temperatureAlertLabel;

  /// No description provided for @temperatureAlertHint.
  ///
  /// In en, this message translates to:
  /// **'Alerts when temperature exceeds the set limit'**
  String get temperatureAlertHint;

  /// No description provided for @saveHealthAlerts.
  ///
  /// In en, this message translates to:
  /// **'Save alert settings'**
  String get saveHealthAlerts;

  /// No description provided for @healthAlertHistory.
  ///
  /// In en, this message translates to:
  /// **'Alert history'**
  String get healthAlertHistory;

  /// No description provided for @seekProfessionalCare.
  ///
  /// In en, this message translates to:
  /// **'If you feel significantly unwell, seek advice from a healthcare professional promptly.'**
  String get seekProfessionalCare;

  /// No description provided for @watchHealthReference.
  ///
  /// In en, this message translates to:
  /// **'Ring measurements are for everyday wellness reference.'**
  String get watchHealthReference;

  /// No description provided for @calibrationReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Use a value just measured with professional equipment.'**
  String get calibrationReferenceHint;

  /// No description provided for @calibrationWearerHint.
  ///
  /// In en, this message translates to:
  /// **'Calibration applies only to the current wearer. Disable or repeat calibration when the wearer changes.'**
  String get calibrationWearerHint;

  /// No description provided for @enableCalibration.
  ///
  /// In en, this message translates to:
  /// **'Enable calibration'**
  String get enableCalibration;

  /// No description provided for @calibrationDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Turning this off restores the ring’s general measurement mode.'**
  String get calibrationDisabledHint;

  /// No description provided for @diastolicLowerLabel.
  ///
  /// In en, this message translates to:
  /// **'Diastolic pressure (lower number)'**
  String get diastolicLowerLabel;

  /// No description provided for @longTermTrendHint.
  ///
  /// In en, this message translates to:
  /// **'Long-term trends provide more useful context.'**
  String get longTermTrendHint;

  /// No description provided for @measurementVariationHint.
  ///
  /// In en, this message translates to:
  /// **'A single measurement can be affected by fit, activity and surroundings. If you feel unwell, consult a healthcare professional.'**
  String get measurementVariationHint;

  /// No description provided for @ecgDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'ECG details'**
  String get ecgDetailTitle;

  /// No description provided for @viewFullReport.
  ///
  /// In en, this message translates to:
  /// **'View full report'**
  String get viewFullReport;

  /// No description provided for @ecgReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'ECG results are for wellness reference only.'**
  String get ecgReferenceHint;

  /// No description provided for @ecgVariationSafety.
  ///
  /// In en, this message translates to:
  /// **'Individual measurements are affected by fit, activity and surroundings and cannot replace a medical diagnosis. If you feel unwell, seek medical care promptly.'**
  String get ecgVariationSafety;

  /// No description provided for @ecgBasicOnly.
  ///
  /// In en, this message translates to:
  /// **'Only basic ECG data was returned for this measurement.'**
  String get ecgBasicOnly;

  /// No description provided for @measurementIndicators.
  ///
  /// In en, this message translates to:
  /// **'Measurement indicators'**
  String get measurementIndicators;

  /// No description provided for @riskIndicatorsMissing.
  ///
  /// In en, this message translates to:
  /// **'The ring did not return risk indicators for this measurement.'**
  String get riskIndicatorsMissing;

  /// No description provided for @riskAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'Risk analysis'**
  String get riskAnalysisTitle;

  /// No description provided for @watchAlgorithmReference.
  ///
  /// In en, this message translates to:
  /// **'The values below come from the ring’s algorithm and are for health trend reference only.'**
  String get watchAlgorithmReference;

  /// No description provided for @ecgHealthReport.
  ///
  /// In en, this message translates to:
  /// **'ECG health report'**
  String get ecgHealthReport;

  /// No description provided for @brandedEcgReport.
  ///
  /// In en, this message translates to:
  /// **'Say Ring · ECG health report'**
  String get brandedEcgReport;

  /// No description provided for @ecgReportSafety.
  ///
  /// In en, this message translates to:
  /// **'Note: this report uses ring measurement data. It is for wellness reference only and cannot replace a doctor’s diagnosis.'**
  String get ecgReportSafety;

  /// No description provided for @installedWatchFaces.
  ///
  /// In en, this message translates to:
  /// **'Installed display styles'**
  String get installedWatchFaces;

  /// No description provided for @switchInstalledWatchFace.
  ///
  /// In en, this message translates to:
  /// **'Switch between display styles already stored on your ring.'**
  String get switchInstalledWatchFace;

  /// No description provided for @useSelectedWatchFace.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useSelectedWatchFace;

  /// No description provided for @downloadUseWatchFace.
  ///
  /// In en, this message translates to:
  /// **'Tap to download and use'**
  String get downloadUseWatchFace;

  /// No description provided for @photoWatchFaceHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a clear photo, check the preview, then send it to your ring.'**
  String get photoWatchFaceHint;

  /// No description provided for @timeDisplayPosition.
  ///
  /// In en, this message translates to:
  /// **'Time position'**
  String get timeDisplayPosition;

  /// No description provided for @transferSetWatchFace.
  ///
  /// In en, this message translates to:
  /// **'Send and set as display style'**
  String get transferSetWatchFace;

  /// No description provided for @watchTransferKeepNear.
  ///
  /// In en, this message translates to:
  /// **'Keep the ring near your phone during transfer and stay on this page.'**
  String get watchTransferKeepNear;

  /// No description provided for @callMediaAudio.
  ///
  /// In en, this message translates to:
  /// **'Call and media audio'**
  String get callMediaAudio;

  /// No description provided for @useCelsius.
  ///
  /// In en, this message translates to:
  /// **'Use Celsius'**
  String get useCelsius;

  /// No description provided for @sosContactHint.
  ///
  /// In en, this message translates to:
  /// **'When SOS is triggered on the ring, it will first contact the person selected here. Choose a family member you contact regularly.'**
  String get sosContactHint;

  /// No description provided for @noHealthAssessments.
  ///
  /// In en, this message translates to:
  /// **'No configurable health assessments are available on this ring.'**
  String get noHealthAssessments;

  /// No description provided for @modelFeaturesVary.
  ///
  /// In en, this message translates to:
  /// **'Supported features vary by model. The app shows only features available for your connected ring.'**
  String get modelFeaturesVary;

  /// No description provided for @assessmentEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the ring provides daily trend information.'**
  String get assessmentEnabledHint;

  /// No description provided for @assessmentSafety.
  ///
  /// In en, this message translates to:
  /// **'Supplementary assessments are for everyday wellness reference, not diagnosis or treatment.'**
  String get assessmentSafety;

  /// No description provided for @autoMonitorIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the ring measures automatically at its configured interval.'**
  String get autoMonitorIntervalHint;

  /// No description provided for @watchHeartRateAlert.
  ///
  /// In en, this message translates to:
  /// **'Ring heart rate alert'**
  String get watchHeartRateAlert;

  /// No description provided for @sustainedLimitWatchAlert.
  ///
  /// In en, this message translates to:
  /// **'The ring alerts you if the value stays above the limit.'**
  String get sustainedLimitWatchAlert;

  /// No description provided for @ecgWaveformTitle.
  ///
  /// In en, this message translates to:
  /// **'ECG waveform'**
  String get ecgWaveformTitle;

  /// No description provided for @ecgWaveformMissing.
  ///
  /// In en, this message translates to:
  /// **'No valid ECG waveform was returned for this measurement.'**
  String get ecgWaveformMissing;

  /// No description provided for @ecgElectrodeHint.
  ///
  /// In en, this message translates to:
  /// **'Heart rate and HRV results remain available. Keep touching the ring electrode throughout your next measurement.'**
  String get ecgElectrodeHint;

  /// No description provided for @screenAutoTimeHint.
  ///
  /// In en, this message translates to:
  /// **'The ring adjusts this automatically based on the time.'**
  String get screenAutoTimeHint;

  /// No description provided for @raiseWristScreenHint.
  ///
  /// In en, this message translates to:
  /// **'The screen lights up when you raise your wrist.'**
  String get raiseWristScreenHint;

  /// No description provided for @watchHighHeartRate.
  ///
  /// In en, this message translates to:
  /// **'High heart rate alert'**
  String get watchHighHeartRate;

  /// No description provided for @watchThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'The ring alerts you when the limit is reached.'**
  String get watchThresholdHint;

  /// No description provided for @watchMeasurementSafety.
  ///
  /// In en, this message translates to:
  /// **'Measurements are for wellness reference only, not diagnosis or treatment.'**
  String get watchMeasurementSafety;

  /// No description provided for @healthDataExplanation.
  ///
  /// In en, this message translates to:
  /// **'About health data'**
  String get healthDataExplanation;

  /// No description provided for @trendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Trends are temporarily unavailable.'**
  String get trendUnavailable;

  /// No description provided for @recentData.
  ///
  /// In en, this message translates to:
  /// **'Recent data'**
  String get recentData;

  /// No description provided for @trendReferenceOnly.
  ///
  /// In en, this message translates to:
  /// **'Trends are for everyday wellness reference only.'**
  String get trendReferenceOnly;

  /// No description provided for @trendVariationSafety.
  ///
  /// In en, this message translates to:
  /// **'Individual and period-to-period changes may be affected by fit, activity and surroundings and do not replace a medical diagnosis.'**
  String get trendVariationSafety;

  /// No description provided for @watchFaceDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'After downloading, the display style will be sent to your ring. Keep the ring near your phone and stay on this page during transfer.'**
  String get watchFaceDownloadHint;

  /// No description provided for @refreshWatchFaces.
  ///
  /// In en, this message translates to:
  /// **'Refresh display styles'**
  String get refreshWatchFaces;

  /// No description provided for @openTestFlight.
  ///
  /// In en, this message translates to:
  /// **'Open TestFlight'**
  String get openTestFlight;

  /// No description provided for @articlesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No articles are available in this category yet.'**
  String get articlesEmpty;

  /// No description provided for @articlesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The health library could not be loaded.'**
  String get articlesUnavailable;

  /// No description provided for @articleContentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The article content is not available yet.'**
  String get articleContentUnavailable;

  /// No description provided for @imageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The image could not be loaded.'**
  String get imageUnavailable;

  /// No description provided for @allowNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get allowNotifications;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @analysisConsentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Health analysis is not available yet. Existing reports are still available.'**
  String get analysisConsentUnavailable;

  /// No description provided for @analysisReadAgree.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the health analysis information above.'**
  String get analysisReadAgree;

  /// No description provided for @agreeContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get agreeContinue;

  /// No description provided for @notGrantNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notGrantNow;

  /// No description provided for @analysisConsentSaved.
  ///
  /// In en, this message translates to:
  /// **'Health analysis consent saved.'**
  String get analysisConsentSaved;

  /// No description provided for @withdrawAnalysisConsent.
  ///
  /// In en, this message translates to:
  /// **'Withdraw health analysis consent?'**
  String get withdrawAnalysisConsent;

  /// No description provided for @withdrawAnalysisExplanation.
  ///
  /// In en, this message translates to:
  /// **'No new detailed reports will be generated. Existing reports that have not been refunded will remain available.'**
  String get withdrawAnalysisExplanation;

  /// No description provided for @confirmWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Confirm withdrawal'**
  String get confirmWithdraw;

  /// No description provided for @analysisConsentWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Health analysis consent withdrawn.'**
  String get analysisConsentWithdrawn;

  /// No description provided for @consentGrantedHint.
  ///
  /// In en, this message translates to:
  /// **'Consent given. You can withdraw it at any time.'**
  String get consentGrantedHint;

  /// No description provided for @consentNeededHint.
  ///
  /// In en, this message translates to:
  /// **'Separate consent is required before generating a detailed report.'**
  String get consentNeededHint;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @reportHistory.
  ///
  /// In en, this message translates to:
  /// **'Report history'**
  String get reportHistory;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @pauseWorkout.
  ///
  /// In en, this message translates to:
  /// **'Pause workout'**
  String get pauseWorkout;

  /// No description provided for @resumeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get resumeWorkout;

  /// No description provided for @finishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish workout'**
  String get finishWorkout;

  /// No description provided for @watchDistance.
  ///
  /// In en, this message translates to:
  /// **'Ring distance'**
  String get watchDistance;

  /// No description provided for @watchSteps.
  ///
  /// In en, this message translates to:
  /// **'Ring steps'**
  String get watchSteps;

  /// No description provided for @liveHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Live heart rate'**
  String get liveHeartRate;

  /// No description provided for @watchCalories.
  ///
  /// In en, this message translates to:
  /// **'Ring calories'**
  String get watchCalories;

  /// No description provided for @connectForWorkout.
  ///
  /// In en, this message translates to:
  /// **'Connect your ring on the Device page first. Your ring will record the workout.'**
  String get connectForWorkout;

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version: V{version}'**
  String latestVersion(String version);

  /// No description provided for @workoutPaused.
  ///
  /// In en, this message translates to:
  /// **'{mode} paused'**
  String workoutPaused(String mode);

  /// No description provided for @workoutInProgress.
  ///
  /// In en, this message translates to:
  /// **'{mode} in progress'**
  String workoutInProgress(String mode);

  /// No description provided for @workoutReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to start {mode}'**
  String workoutReady(String mode);

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start {mode}'**
  String startWorkout(String mode);

  /// No description provided for @finishOtherWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish {mode} first'**
  String finishOtherWorkout(String mode);

  /// No description provided for @workoutDetails.
  ///
  /// In en, this message translates to:
  /// **'{mode} details'**
  String workoutDetails(String mode);

  /// No description provided for @stepCount.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String stepCount(int count);

  /// No description provided for @globalShopPricePending.
  ///
  /// In en, this message translates to:
  /// **'Price to be confirmed'**
  String get globalShopPricePending;

  /// No description provided for @globalShopLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get globalShopLoadMore;

  /// No description provided for @globalShopReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Browse products here. Ordering is not available in this region yet.'**
  String get globalShopReadOnly;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Say Ring'**
  String get appName;

  /// No description provided for @searchingNearby.
  ///
  /// In en, this message translates to:
  /// **'Searching for nearby rings'**
  String get searchingNearby;

  /// No description provided for @noDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get noDevices;

  /// No description provided for @selectWatch.
  ///
  /// In en, this message translates to:
  /// **'Check the name and signal, then select your ring'**
  String get selectWatch;

  /// No description provided for @searchingHint.
  ///
  /// In en, this message translates to:
  /// **'Searching. Signal strength updates without moving the list.'**
  String get searchingHint;

  /// No description provided for @activateWatch.
  ///
  /// In en, this message translates to:
  /// **'Charge your ring to activate it, then place it near your phone'**
  String get activateWatch;

  /// No description provided for @checkWatchConnection.
  ///
  /// In en, this message translates to:
  /// **'If the ring is connected in this phone\'s Bluetooth settings or on another phone, disconnect it and search again'**
  String get checkWatchConnection;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @indoorRunning.
  ///
  /// In en, this message translates to:
  /// **'Indoor running'**
  String get indoorRunning;

  /// No description provided for @walking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get walking;

  /// No description provided for @cycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get cycling;

  /// No description provided for @indoorCycling.
  ///
  /// In en, this message translates to:
  /// **'Indoor cycling'**
  String get indoorCycling;

  /// No description provided for @basketball.
  ///
  /// In en, this message translates to:
  /// **'Basketball'**
  String get basketball;

  /// No description provided for @football.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get football;

  /// No description provided for @badminton.
  ///
  /// In en, this message translates to:
  /// **'Badminton'**
  String get badminton;

  /// No description provided for @swimming.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get swimming;

  /// No description provided for @jumpRope.
  ///
  /// In en, this message translates to:
  /// **'Jump rope'**
  String get jumpRope;

  /// No description provided for @yoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get yoga;

  /// No description provided for @hiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get hiking;

  /// No description provided for @mountaineering.
  ///
  /// In en, this message translates to:
  /// **'Mountaineering'**
  String get mountaineering;

  /// No description provided for @todayActivity.
  ///
  /// In en, this message translates to:
  /// **'Today\'s activity'**
  String get todayActivity;

  /// No description provided for @dailyActivityGoalHint.
  ///
  /// In en, this message translates to:
  /// **'Keep moving toward your daily goals'**
  String get dailyActivityGoalHint;

  /// No description provided for @metricAnalysis.
  ///
  /// In en, this message translates to:
  /// **'{metric} analysis'**
  String metricAnalysis(String metric);

  /// No description provided for @metricAllData.
  ///
  /// In en, this message translates to:
  /// **'All {metric} data'**
  String metricAllData(String metric);

  /// No description provided for @metricMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Measure {metric}'**
  String metricMeasurement(String metric);

  /// No description provided for @metricCalibration.
  ///
  /// In en, this message translates to:
  /// **'Calibrate {metric}'**
  String metricCalibration(String metric);

  /// No description provided for @metricDetails.
  ///
  /// In en, this message translates to:
  /// **'{metric} details'**
  String metricDetails(String metric);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// No description provided for @reminderInterval.
  ///
  /// In en, this message translates to:
  /// **'Reminder interval'**
  String get reminderInterval;

  /// No description provided for @reminderName.
  ///
  /// In en, this message translates to:
  /// **'Reminder name'**
  String get reminderName;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @addAlarm.
  ///
  /// In en, this message translates to:
  /// **'Add alarm'**
  String get addAlarm;

  /// No description provided for @alarmTime.
  ///
  /// In en, this message translates to:
  /// **'Alarm time'**
  String get alarmTime;

  /// No description provided for @enableAlarm.
  ///
  /// In en, this message translates to:
  /// **'Enable alarm'**
  String get enableAlarm;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'SOS emergency contact'**
  String get emergencyContact;

  /// No description provided for @selectEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Select SOS contact'**
  String get selectEmergencyContact;

  /// No description provided for @confirmEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Set as SOS contact'**
  String get confirmEmergencyContact;

  /// No description provided for @addWorldClock.
  ///
  /// In en, this message translates to:
  /// **'Add world clock'**
  String get addWorldClock;

  /// No description provided for @autoBrightness.
  ///
  /// In en, this message translates to:
  /// **'Automatic brightness'**
  String get autoBrightness;

  /// No description provided for @raiseToWake.
  ///
  /// In en, this message translates to:
  /// **'Raise to wake'**
  String get raiseToWake;

  /// No description provided for @activeTime.
  ///
  /// In en, this message translates to:
  /// **'Active time'**
  String get activeTime;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @helpFeedback.
  ///
  /// In en, this message translates to:
  /// **'Help and feedback'**
  String get helpFeedback;

  /// No description provided for @issueType.
  ///
  /// In en, this message translates to:
  /// **'Issue type'**
  String get issueType;

  /// No description provided for @issueDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get issueDescription;

  /// No description provided for @describeIssue.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem and the steps to reproduce it'**
  String get describeIssue;

  /// No description provided for @contactOptional.
  ///
  /// In en, this message translates to:
  /// **'Contact information (optional)'**
  String get contactOptional;

  /// No description provided for @phoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Phone number or email'**
  String get phoneOrEmail;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactName;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get contactPhone;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchProducts;

  /// No description provided for @selectVariant.
  ///
  /// In en, this message translates to:
  /// **'Select an option'**
  String get selectVariant;

  /// No description provided for @variant.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get variant;

  /// No description provided for @buyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get buyNow;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @returnShop.
  ///
  /// In en, this message translates to:
  /// **'Back to shop'**
  String get returnShop;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @clearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear cart?'**
  String get clearCart;

  /// No description provided for @clearCartHint.
  ///
  /// In en, this message translates to:
  /// **'All items in your cart will be removed.'**
  String get clearCartHint;

  /// No description provided for @viewOrder.
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get viewOrder;

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get confirmOrder;

  /// No description provided for @productInfo.
  ///
  /// In en, this message translates to:
  /// **'Product information'**
  String get productInfo;

  /// No description provided for @orderNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get orderNote;

  /// No description provided for @noteToSeller.
  ///
  /// In en, this message translates to:
  /// **'Leave a note for the seller'**
  String get noteToSeller;

  /// No description provided for @paymentCheckout.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentCheckout;

  /// No description provided for @orderTotal.
  ///
  /// In en, this message translates to:
  /// **'Order total'**
  String get orderTotal;

  /// No description provided for @selectPayment.
  ///
  /// In en, this message translates to:
  /// **'Select payment method'**
  String get selectPayment;

  /// No description provided for @refreshOrder.
  ///
  /// In en, this message translates to:
  /// **'Refresh order status'**
  String get refreshOrder;

  /// No description provided for @viewMyOrders.
  ///
  /// In en, this message translates to:
  /// **'View my orders'**
  String get viewMyOrders;

  /// No description provided for @backToProduct.
  ///
  /// In en, this message translates to:
  /// **'Back to product'**
  String get backToProduct;

  /// No description provided for @newAddress.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get newAddress;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @province.
  ///
  /// In en, this message translates to:
  /// **'State / province'**
  String get province;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District / county'**
  String get district;

  /// No description provided for @streetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get streetAddress;

  /// No description provided for @defaultAddress.
  ///
  /// In en, this message translates to:
  /// **'Set as default address'**
  String get defaultAddress;

  /// No description provided for @shippingInfo.
  ///
  /// In en, this message translates to:
  /// **'Shipping information'**
  String get shippingInfo;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @useWatchFace.
  ///
  /// In en, this message translates to:
  /// **'Use this display style?'**
  String get useWatchFace;

  /// No description provided for @downloadAndUse.
  ///
  /// In en, this message translates to:
  /// **'Download and use'**
  String get downloadAndUse;

  /// No description provided for @watchFaceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not set the display style'**
  String get watchFaceFailed;

  /// No description provided for @statusNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get statusNormal;

  /// No description provided for @statusRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get statusRecorded;

  /// No description provided for @statusAttention.
  ///
  /// In en, this message translates to:
  /// **'Check reading'**
  String get statusAttention;

  /// No description provided for @statusOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Outside reference'**
  String get statusOutOfRange;

  /// No description provided for @statusLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get statusLow;

  /// No description provided for @statusHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get statusHigh;

  /// No description provided for @careInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Invite a Say Ring account by email or international phone number.'**
  String get careInviteHint;

  /// No description provided for @careSharingHint.
  ///
  /// In en, this message translates to:
  /// **'Only the measurements you select are shared. You can stop sharing at any time.'**
  String get careSharingHint;

  /// No description provided for @carePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get carePending;

  /// No description provided for @careActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get careActive;

  /// No description provided for @careClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get careClosed;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @stopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get stopSharing;

  /// No description provided for @sharedMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Shared measurements'**
  String get sharedMeasurements;

  /// No description provided for @invitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent'**
  String get invitationSent;

  /// No description provided for @invalidCareContact.
  ///
  /// In en, this message translates to:
  /// **'Enter an email or a phone number with country code.'**
  String get invalidCareContact;

  /// No description provided for @carePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'This measurement has not been shared with you.'**
  String get carePermissionDenied;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @applyAfterSales.
  ///
  /// In en, this message translates to:
  /// **'Request support'**
  String get applyAfterSales;

  /// No description provided for @analysisConsent.
  ///
  /// In en, this message translates to:
  /// **'Health analysis consent'**
  String get analysisConsent;

  /// No description provided for @workoutRecords.
  ///
  /// In en, this message translates to:
  /// **'Workout records'**
  String get workoutRecords;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @addCare.
  ///
  /// In en, this message translates to:
  /// **'Add a care member'**
  String get addCare;

  /// No description provided for @confirmReceipt.
  ///
  /// In en, this message translates to:
  /// **'Confirm receipt'**
  String get confirmReceipt;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get personalInfo;

  /// No description provided for @deliveryAddresses.
  ///
  /// In en, this message translates to:
  /// **'Delivery addresses'**
  String get deliveryAddresses;

  /// No description provided for @readAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get readAgain;

  /// No description provided for @smsCode.
  ///
  /// In en, this message translates to:
  /// **'SMS verification code'**
  String get smsCode;

  /// No description provided for @watchFaceShop.
  ///
  /// In en, this message translates to:
  /// **'Display style store'**
  String get watchFaceShop;

  /// No description provided for @selectCity.
  ///
  /// In en, this message translates to:
  /// **'Select city'**
  String get selectCity;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @productDetails.
  ///
  /// In en, this message translates to:
  /// **'Product details'**
  String get productDetails;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get typeMessage;

  /// No description provided for @devicesFound.
  ///
  /// In en, this message translates to:
  /// **'Devices found'**
  String get devicesFound;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @searchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get searchAgain;

  /// No description provided for @searchRecovery.
  ///
  /// In en, this message translates to:
  /// **'Keep the ring close. If it is connected in system Bluetooth or on another phone, disconnect it first, then try again.'**
  String get searchRecovery;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceName;

  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'Device model'**
  String get deviceModel;

  /// No description provided for @connectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection status'**
  String get connectionStatus;

  /// No description provided for @firmwareVersion.
  ///
  /// In en, this message translates to:
  /// **'Firmware version'**
  String get firmwareVersion;

  /// No description provided for @watchBattery.
  ///
  /// In en, this message translates to:
  /// **'Ring battery'**
  String get watchBattery;

  /// No description provided for @chargingStatus.
  ///
  /// In en, this message translates to:
  /// **'Charging status'**
  String get chargingStatus;

  /// No description provided for @messageDetails.
  ///
  /// In en, this message translates to:
  /// **'Message details'**
  String get messageDetails;

  /// No description provided for @dailySummary.
  ///
  /// In en, this message translates to:
  /// **'Daily summary'**
  String get dailySummary;

  /// No description provided for @remoteMemberData.
  ///
  /// In en, this message translates to:
  /// **'Care member’s data'**
  String get remoteMemberData;

  /// No description provided for @ecgWaveformUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No ECG waveform available'**
  String get ecgWaveformUnavailable;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetails;

  /// No description provided for @viewShipping.
  ///
  /// In en, this message translates to:
  /// **'Track shipment'**
  String get viewShipping;

  /// No description provided for @measureAgain.
  ///
  /// In en, this message translates to:
  /// **'Measure again'**
  String get measureAgain;

  /// No description provided for @checkPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Check payment status'**
  String get checkPaymentStatus;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @confirmDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get confirmDeleteAccountTitle;

  /// No description provided for @deleteAccountHint.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out after your account and related data have been deleted.'**
  String get deleteAccountHint;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get confirmDelete;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get birthDate;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get choose;

  /// No description provided for @connectWatchToUse.
  ///
  /// In en, this message translates to:
  /// **'Connect a ring to use this feature'**
  String get connectWatchToUse;

  /// No description provided for @selectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Select photo'**
  String get selectPhoto;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'System notifications are off'**
  String get notificationsOff;

  /// No description provided for @privacyAgreement.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyAgreement;

  /// No description provided for @appPermissions.
  ///
  /// In en, this message translates to:
  /// **'App permissions'**
  String get appPermissions;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system app settings'**
  String get openSystemSettings;

  /// No description provided for @monitoringHint.
  ///
  /// In en, this message translates to:
  /// **'Available health monitoring settings appear after connecting your ring.'**
  String get monitoringHint;

  /// No description provided for @previewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get previewUnavailable;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @healthProfile.
  ///
  /// In en, this message translates to:
  /// **'Health profile'**
  String get healthProfile;

  /// No description provided for @photoWatchFace.
  ///
  /// In en, this message translates to:
  /// **'Photo display'**
  String get photoWatchFace;

  /// No description provided for @cameraRemote.
  ///
  /// In en, this message translates to:
  /// **'Camera remote'**
  String get cameraRemote;

  /// No description provided for @phoneCalls.
  ///
  /// In en, this message translates to:
  /// **'Phone calls'**
  String get phoneCalls;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @alarms.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarms;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// No description provided for @worldClock.
  ///
  /// In en, this message translates to:
  /// **'World clock'**
  String get worldClock;

  /// No description provided for @healthReminders.
  ///
  /// In en, this message translates to:
  /// **'Wellness reminders'**
  String get healthReminders;

  /// No description provided for @healthMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Health monitoring'**
  String get healthMonitoring;

  /// No description provided for @healthAssessment.
  ///
  /// In en, this message translates to:
  /// **'Wellness assessment'**
  String get healthAssessment;

  /// No description provided for @screenDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get screenDisplay;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get scanning;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @waitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get waitingConfirmation;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @measuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get measuring;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @tapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get tapToOpen;

  /// No description provided for @deviceInfoHint.
  ///
  /// In en, this message translates to:
  /// **'View device information'**
  String get deviceInfoHint;

  /// No description provided for @connectionInstructions.
  ///
  /// In en, this message translates to:
  /// **'1. Turn on Bluetooth and allow nearby device access.\n2. Charge your ring and place it near your phone.\n3. Tap Find devices and select your ring.\n4. Keep the ring near your phone and wait for the app to show Connected.'**
  String get connectionInstructions;

  /// No description provided for @syncNearbyHint.
  ///
  /// In en, this message translates to:
  /// **'Keep your ring charged and near your phone while connecting or syncing.'**
  String get syncNearbyHint;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Check the code and try again'**
  String get invalidCode;

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Request a new code.'**
  String get codeExpired;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get tooManyAttempts;

  /// No description provided for @readTerms.
  ///
  /// In en, this message translates to:
  /// **'Read the terms and privacy policy to continue'**
  String get readTerms;

  /// No description provided for @verificationSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {contact}'**
  String verificationSentTo(String contact);

  /// No description provided for @addSmartDevice.
  ///
  /// In en, this message translates to:
  /// **'Add a smart device'**
  String get addSmartDevice;

  /// No description provided for @watchNearbyHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth and keep your ring near your phone'**
  String get watchNearbyHint;

  /// No description provided for @startSearch.
  ///
  /// In en, this message translates to:
  /// **'Find devices'**
  String get startSearch;

  /// No description provided for @readingData.
  ///
  /// In en, this message translates to:
  /// **'Reading data…'**
  String get readingData;

  /// No description provided for @readingCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Checking ring features…'**
  String get readingCapabilities;

  /// No description provided for @capabilitiesHint.
  ///
  /// In en, this message translates to:
  /// **'Only features available on this ring will be shown'**
  String get capabilitiesHint;

  /// No description provided for @capabilitiesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read this ring’s features'**
  String get capabilitiesFailed;

  /// No description provided for @keepWatchNear.
  ///
  /// In en, this message translates to:
  /// **'Keep your ring near your phone and try again'**
  String get keepWatchNear;

  /// No description provided for @personalizeWatch.
  ///
  /// In en, this message translates to:
  /// **'Display & personalization'**
  String get personalizeWatch;

  /// No description provided for @signInCloudHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use cloud health services'**
  String get signInCloudHint;

  /// No description provided for @aiQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get aiQuestion;

  /// No description provided for @aiQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Ask your AI assistant about wellbeing'**
  String get aiQuestionHint;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @countryRegion.
  ///
  /// In en, this message translates to:
  /// **'Country or region'**
  String get countryRegion;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get pleaseWait;

  /// No description provided for @emailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Email or phone number'**
  String get emailOrPhone;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterEmail;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhone;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @passwordRequirement.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters. Up to 72 English letters or numbers; fewer for other characters.'**
  String get passwordRequirement;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Check the country code and phone number'**
  String get invalidPhone;

  /// No description provided for @codeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent. Check your messages.'**
  String get codeSent;

  /// No description provided for @codeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code'**
  String get codeRequired;

  /// No description provided for @consentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please read and accept the terms and privacy policy'**
  String get consentRequired;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to'**
  String get agreeToTerms;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @registrationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Registration is temporarily unavailable. Please try again later.'**
  String get registrationUnavailable;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Please check your details and try again.'**
  String get loginFailed;

  /// No description provided for @accountAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This account already exists. Sign in instead.'**
  String get accountAlreadyExists;

  /// No description provided for @networkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again'**
  String get networkUnavailable;

  /// No description provided for @serviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This feature is temporarily unavailable. Please try again later.'**
  String get serviceUnavailable;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready'**
  String get accountCreated;

  /// No description provided for @passwordReset.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get passwordReset;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'New to Say Ring?'**
  String get noAccount;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country or region'**
  String get selectCountry;

  /// No description provided for @registrationMethod.
  ///
  /// In en, this message translates to:
  /// **'Register with'**
  String get registrationMethod;

  /// No description provided for @changeLanguageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the language. Please try again.'**
  String get changeLanguageFailed;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get profile;

  /// No description provided for @healthData.
  ///
  /// In en, this message translates to:
  /// **'Health data'**
  String get healthData;

  /// No description provided for @allData.
  ///
  /// In en, this message translates to:
  /// **'All data'**
  String get allData;

  /// No description provided for @healthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health records'**
  String get healthRecords;

  /// No description provided for @workoutsAndRecords.
  ///
  /// In en, this message translates to:
  /// **'Workouts and records'**
  String get workoutsAndRecords;

  /// No description provided for @healthDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Measurements are for wellness reference only. Consult a healthcare professional if you feel unwell.'**
  String get healthDisclaimer;

  /// No description provided for @healthSafetyAdvice.
  ///
  /// In en, this message translates to:
  /// **'Rest and measure again. If you feel unwell, seek medical advice.'**
  String get healthSafetyAdvice;

  /// No description provided for @defaultUser.
  ///
  /// In en, this message translates to:
  /// **'Say Ring user'**
  String get defaultUser;

  /// No description provided for @dailyGreeting.
  ///
  /// In en, this message translates to:
  /// **'Take care of yourself today'**
  String get dailyGreeting;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI wellness assistant'**
  String get aiAssistant;

  /// No description provided for @aiAssistantIntro.
  ///
  /// In en, this message translates to:
  /// **'Ask me a question about your wellbeing.'**
  String get aiAssistantIntro;

  /// No description provided for @askNow.
  ///
  /// In en, this message translates to:
  /// **'Ask now'**
  String get askNow;

  /// No description provided for @remoteCare.
  ///
  /// In en, this message translates to:
  /// **'Family care'**
  String get remoteCare;

  /// No description provided for @healthLibrary.
  ///
  /// In en, this message translates to:
  /// **'Health library'**
  String get healthLibrary;

  /// No description provided for @healthAlerts.
  ///
  /// In en, this message translates to:
  /// **'Health alerts'**
  String get healthAlerts;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @connectWatch.
  ///
  /// In en, this message translates to:
  /// **'Connect a ring'**
  String get connectWatch;

  /// No description provided for @addDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get addDevice;

  /// No description provided for @connectWatchForData.
  ///
  /// In en, this message translates to:
  /// **'Connect your ring to view supported health data'**
  String get connectWatchForData;

  /// No description provided for @noHealthData.
  ///
  /// In en, this message translates to:
  /// **'No health data to show yet'**
  String get noHealthData;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noData;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @syncData.
  ///
  /// In en, this message translates to:
  /// **'Sync data'**
  String get syncData;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Data synced'**
  String get syncComplete;

  /// No description provided for @syncFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not sync. Keep your ring nearby and try again.'**
  String get syncFailedTryAgain;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @findWatch.
  ///
  /// In en, this message translates to:
  /// **'Find ring'**
  String get findWatch;

  /// No description provided for @watchFaces.
  ///
  /// In en, this message translates to:
  /// **'Display styles'**
  String get watchFaces;

  /// No description provided for @deviceFeatures.
  ///
  /// In en, this message translates to:
  /// **'Device features'**
  String get deviceFeatures;

  /// No description provided for @aboutDevice.
  ///
  /// In en, this message translates to:
  /// **'About device'**
  String get aboutDevice;

  /// No description provided for @connectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Connection help'**
  String get connectionHelp;

  /// No description provided for @searchNearbyWatch.
  ///
  /// In en, this message translates to:
  /// **'Find and connect a nearby Say Ring'**
  String get searchNearbyWatch;

  /// No description provided for @useWatch.
  ///
  /// In en, this message translates to:
  /// **'This ring does not currently support this setting in the app'**
  String get useWatch;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @awaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'To pay'**
  String get awaitingPayment;

  /// No description provided for @awaitingShipment.
  ///
  /// In en, this message translates to:
  /// **'To ship'**
  String get awaitingShipment;

  /// No description provided for @awaitingDelivery.
  ///
  /// In en, this message translates to:
  /// **'To receive'**
  String get awaitingDelivery;

  /// No description provided for @afterSales.
  ///
  /// In en, this message translates to:
  /// **'Returns & support'**
  String get afterSales;

  /// No description provided for @careMembers.
  ///
  /// In en, this message translates to:
  /// **'Care members'**
  String get careMembers;

  /// No description provided for @unitSettings.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get unitSettings;

  /// No description provided for @unitSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose distance, temperature and other units'**
  String get unitSettingsHint;

  /// No description provided for @myServices.
  ///
  /// In en, this message translates to:
  /// **'My services'**
  String get myServices;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettings;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @customerService.
  ///
  /// In en, this message translates to:
  /// **'Customer support'**
  String get customerService;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About Say Ring'**
  String get aboutApp;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get security;

  /// No description provided for @goToSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get goToSettings;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @onlineUpdate.
  ///
  /// In en, this message translates to:
  /// **'App update'**
  String get onlineUpdate;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update to continue'**
  String get updateRequired;

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'An update is ready'**
  String get updateReady;

  /// No description provided for @preparingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Preparing a secure update…'**
  String get preparingUpdate;

  /// No description provided for @openingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Opening the system update page…'**
  String get openingUpdate;

  /// No description provided for @updateAppStore.
  ///
  /// In en, this message translates to:
  /// **'Update in the App Store'**
  String get updateAppStore;

  /// No description provided for @updateStore.
  ///
  /// In en, this message translates to:
  /// **'Update in the app store'**
  String get updateStore;

  /// No description provided for @downloadAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Download and install securely'**
  String get downloadAndInstall;

  /// No description provided for @gettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting things ready…'**
  String get gettingReady;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Say Ring notifications'**
  String get enableNotifications;

  /// No description provided for @notificationExplanation.
  ///
  /// In en, this message translates to:
  /// **'Get health alerts and care invitations. Health values are not shown on the lock screen. You can turn notifications off in system settings.'**
  String get notificationExplanation;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @newCareRequest.
  ///
  /// In en, this message translates to:
  /// **'New care request'**
  String get newCareRequest;

  /// No description provided for @dismissHealthAlert.
  ///
  /// In en, this message translates to:
  /// **'Dismiss health alert'**
  String get dismissHealthAlert;

  /// No description provided for @dismissCareAlert.
  ///
  /// In en, this message translates to:
  /// **'Dismiss care reminder'**
  String get dismissCareAlert;

  /// No description provided for @bloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get bloodPressure;

  /// No description provided for @heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get heartRate;

  /// No description provided for @bloodOxygen.
  ///
  /// In en, this message translates to:
  /// **'Blood oxygen'**
  String get bloodOxygen;

  /// No description provided for @bloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose'**
  String get bloodGlucose;

  /// No description provided for @bodyTemperature.
  ///
  /// In en, this message translates to:
  /// **'Skin temperature'**
  String get bodyTemperature;

  /// No description provided for @ecg.
  ///
  /// In en, this message translates to:
  /// **'ECG'**
  String get ecg;

  /// No description provided for @hrv.
  ///
  /// In en, this message translates to:
  /// **'HRV'**
  String get hrv;

  /// No description provided for @stress.
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get stress;

  /// No description provided for @bodyComposition.
  ///
  /// In en, this message translates to:
  /// **'Body composition'**
  String get bodyComposition;

  /// No description provided for @bloodComposition.
  ///
  /// In en, this message translates to:
  /// **'Blood composition'**
  String get bloodComposition;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String welcome(String name);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendCode(int seconds);

  /// No description provided for @memberId.
  ///
  /// In en, this message translates to:
  /// **'Member ID: {id}'**
  String memberId(String id);

  /// No description provided for @unreadMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages, {count} unread'**
  String unreadMessages(int count);

  /// No description provided for @recordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String recordCount(int count);

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String memberCount(int count);

  /// No description provided for @versionBuild.
  ///
  /// In en, this message translates to:
  /// **'V{version} · Build {build}'**
  String versionBuild(String version, int build);

  /// No description provided for @globalShopBrowseNotice.
  ///
  /// In en, this message translates to:
  /// **'You can continue browsing. Ordering opens only when delivery and payment are available for your market.'**
  String get globalShopBrowseNotice;

  /// No description provided for @shopAccount.
  ///
  /// In en, this message translates to:
  /// **'Shop account'**
  String get shopAccount;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added to cart'**
  String get addedToCart;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStock;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock or unavailable'**
  String get outOfStock;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @coupons.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get coupons;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get helpCenter;

  /// No description provided for @chooseDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose a delivery address'**
  String get chooseDeliveryAddress;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get editAddress;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAddressPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete this address?'**
  String get deleteAddressPrompt;

  /// No description provided for @postalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get postalCode;

  /// No description provided for @itemsSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Items subtotal'**
  String get itemsSubtotal;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @shippingFee.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get shippingFee;

  /// No description provided for @amountDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get amountDue;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get orderPlaced;

  /// No description provided for @orderSubmissionUncertain.
  ///
  /// In en, this message translates to:
  /// **'The order result is not confirmed. Check My orders before trying again.'**
  String get orderSubmissionUncertain;

  /// No description provided for @availableCoupons.
  ///
  /// In en, this message translates to:
  /// **'Available coupons'**
  String get availableCoupons;

  /// No description provided for @ownedCoupons.
  ///
  /// In en, this message translates to:
  /// **'My coupons'**
  String get ownedCoupons;

  /// No description provided for @couponCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get couponCode;

  /// No description provided for @redeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeem;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get claimed;

  /// No description provided for @pointsBalance.
  ///
  /// In en, this message translates to:
  /// **'Points balance'**
  String get pointsBalance;

  /// No description provided for @pointsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Balance not available yet'**
  String get pointsUnavailable;

  /// No description provided for @marketUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Ordering is not available for the selected delivery market yet.'**
  String get marketUnavailable;

  /// No description provided for @paymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment is not available in the app right now. Your cart and existing orders remain available.'**
  String get paymentUnavailable;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderNumber;

  /// No description provided for @orderDate.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get orderDate;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// No description provided for @cancelOrderPrompt.
  ///
  /// In en, this message translates to:
  /// **'Cancel this unpaid order?'**
  String get cancelOrderPrompt;

  /// No description provided for @refundOnly.
  ///
  /// In en, this message translates to:
  /// **'Refund only'**
  String get refundOnly;

  /// No description provided for @returnRefund.
  ///
  /// In en, this message translates to:
  /// **'Return and refund'**
  String get returnRefund;

  /// No description provided for @exchange.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get exchange;

  /// No description provided for @submitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get submitRequest;

  /// No description provided for @requestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Request submitted'**
  String get requestSubmitted;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get writeReview;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get submitReview;

  /// No description provided for @defaultVariant.
  ///
  /// In en, this message translates to:
  /// **'Default option'**
  String get defaultVariant;

  /// No description provided for @selectedItems.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedItems(int count);

  /// No description provided for @signInToShopHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your cart, addresses and orders.'**
  String get signInToShopHint;

  /// No description provided for @checkoutPriceChanged.
  ///
  /// In en, this message translates to:
  /// **'The order total changed. Review the refreshed amount before continuing.'**
  String get checkoutPriceChanged;

  /// No description provided for @shopHelpIntro.
  ///
  /// In en, this message translates to:
  /// **'Order, delivery and after-sales options follow the services available for your market.'**
  String get shopHelpIntro;

  /// No description provided for @shopHelpOrdering.
  ///
  /// In en, this message translates to:
  /// **'Why can’t I place an order?'**
  String get shopHelpOrdering;

  /// No description provided for @shopHelpOrderingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Ordering is enabled only after delivery and market services are available. You can keep products in your cart and try again later.'**
  String get shopHelpOrderingAnswer;

  /// No description provided for @shopHelpPayment.
  ///
  /// In en, this message translates to:
  /// **'How is payment confirmed?'**
  String get shopHelpPayment;

  /// No description provided for @shopHelpPaymentAnswer.
  ///
  /// In en, this message translates to:
  /// **'An order is marked paid only after the payment provider confirms it. Do not place another order while confirmation is pending.'**
  String get shopHelpPaymentAnswer;

  /// No description provided for @shopHelpAfterSales.
  ///
  /// In en, this message translates to:
  /// **'How do I request after-sales support?'**
  String get shopHelpAfterSales;

  /// No description provided for @shopHelpAfterSalesAnswer.
  ///
  /// In en, this message translates to:
  /// **'Open an eligible order, choose Request support, review the refund amount and submit your reason.'**
  String get shopHelpAfterSalesAnswer;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrders;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavorites;

  /// No description provided for @noCoupons.
  ///
  /// In en, this message translates to:
  /// **'No coupons available'**
  String get noCoupons;

  /// No description provided for @selectItemsToContinue.
  ///
  /// In en, this message translates to:
  /// **'Select at least one available item to continue.'**
  String get selectItemsToContinue;

  /// No description provided for @noCoupon.
  ///
  /// In en, this message translates to:
  /// **'Do not use a coupon'**
  String get noCoupon;

  /// No description provided for @pointsToUse.
  ///
  /// In en, this message translates to:
  /// **'Points value to use'**
  String get pointsToUse;

  /// No description provided for @refreshOrderTotal.
  ///
  /// In en, this message translates to:
  /// **'Refresh order total'**
  String get refreshOrderTotal;

  /// No description provided for @chooseAddressForTotal.
  ///
  /// In en, this message translates to:
  /// **'Choose an address to get the latest order total.'**
  String get chooseAddressForTotal;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @invalidInternationalPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number with country code.'**
  String get invalidInternationalPhone;

  /// No description provided for @invalidCouponCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid coupon code with 4–32 letters, numbers, hyphens or underscores.'**
  String get invalidCouponCode;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @orderItemsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Order items are not available for this older order.'**
  String get orderItemsUnavailable;

  /// No description provided for @orderCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderCompleted;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderCancelled;

  /// No description provided for @orderRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get orderRefunded;

  /// No description provided for @orderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get orderStatusPending;

  /// No description provided for @legacyOrderReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This older order can be viewed here. Contact support if you need help changing it.'**
  String get legacyOrderReadOnly;

  /// No description provided for @returnLogistics.
  ///
  /// In en, this message translates to:
  /// **'Return shipping'**
  String get returnLogistics;

  /// No description provided for @carrier.
  ///
  /// In en, this message translates to:
  /// **'Carrier'**
  String get carrier;

  /// No description provided for @trackingNumber.
  ///
  /// In en, this message translates to:
  /// **'Tracking number'**
  String get trackingNumber;

  /// No description provided for @noShippingUpdates.
  ///
  /// In en, this message translates to:
  /// **'No shipping updates yet'**
  String get noShippingUpdates;

  /// No description provided for @waitingForReturn.
  ///
  /// In en, this message translates to:
  /// **'Waiting for return'**
  String get waitingForReturn;

  /// No description provided for @requestRejected.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get requestRejected;

  /// No description provided for @requestProcessing.
  ///
  /// In en, this message translates to:
  /// **'Request processing'**
  String get requestProcessing;

  /// No description provided for @afterSalesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No item in this order is eligible for after-sales support.'**
  String get afterSalesUnavailable;

  /// No description provided for @previewRequest.
  ///
  /// In en, this message translates to:
  /// **'Review request amount'**
  String get previewRequest;

  /// No description provided for @problemPhotos.
  ///
  /// In en, this message translates to:
  /// **'Problem photos'**
  String get problemPhotos;

  /// No description provided for @afterSalePhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. Up to 9 JPG, PNG or WebP images, 10 MB each.'**
  String get afterSalePhotoHint;

  /// No description provided for @addProblemPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get addProblemPhotos;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @photoUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get photoUploading;

  /// No description provided for @photoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get photoUploaded;

  /// No description provided for @photoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Try again or remove this photo.'**
  String get photoUploadFailed;

  /// No description provided for @photoServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photos cannot be added right now. You can still submit a written description.'**
  String get photoServiceUnavailable;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Each photo must be no larger than 10 MB.'**
  String get photoTooLarge;

  /// No description provided for @photoFormatUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPG, PNG or WebP image.'**
  String get photoFormatUnsupported;

  /// No description provided for @photoReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be loaded. Please try again.'**
  String get photoReadFailed;

  /// No description provided for @afterSaleSubmissionUncertain.
  ///
  /// In en, this message translates to:
  /// **'The request result is not confirmed. Check the order status or retry the same request.'**
  String get afterSaleSubmissionUncertain;

  /// No description provided for @requestDetails.
  ///
  /// In en, this message translates to:
  /// **'Request details'**
  String get requestDetails;

  /// No description provided for @afterSaleItems.
  ///
  /// In en, this message translates to:
  /// **'Items in this request'**
  String get afterSaleItems;

  /// No description provided for @afterSaleItemsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Item details are not available for this request.'**
  String get afterSaleItemsUnavailable;

  /// No description provided for @refundProgress.
  ///
  /// In en, this message translates to:
  /// **'Refund progress'**
  String get refundProgress;

  /// No description provided for @refundResultPending.
  ///
  /// In en, this message translates to:
  /// **'The refund result is being confirmed.'**
  String get refundResultPending;

  /// No description provided for @afterSaleItem.
  ///
  /// In en, this message translates to:
  /// **'After-sales item'**
  String get afterSaleItem;

  /// No description provided for @shareProduct.
  ///
  /// In en, this message translates to:
  /// **'Share product'**
  String get shareProduct;

  /// No description provided for @customerReviews.
  ///
  /// In en, this message translates to:
  /// **'Customer reviews'**
  String get customerReviews;

  /// No description provided for @stockCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in stock'**
  String stockCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
