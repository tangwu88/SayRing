import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

void main() {
  testWidgets('login page renders the required account and privacy controls', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: LoginPage(controller: controller),
      ),
    );

    expect(find.text('欢迎使用 Saydian 赛电'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.textContaining('不用于诊断或治疗'), findsNothing);
    expect(find.textContaining('隐私政策'), findsWidgets);
  });

  testWidgets(
    'agreement remains visible and tappable at 320x568 and 1.5x text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        _NoopWearable(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: LoginPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final agreement = find.byKey(const Key('login-agreement'));
      expect(agreement, findsOneWidget);
      expect(
        tester.getBottomRight(agreement).dy,
        lessThanOrEqualTo(568),
        reason: '协议应在小屏登录首屏内可见',
      );
      await tester.ensureVisible(agreement);
      await tester.pump();
      expect(find.text('用户协议'), findsOneWidget);
      expect(find.text('隐私政策'), findsOneWidget);

      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registration includes SMS verification before submit', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: RegistrationPage(controller: controller),
      ),
    );

    expect(find.byKey(const Key('registration-mobile')), findsOneWidget);
    expect(find.byKey(const Key('registration-code')), findsOneWidget);
    expect(find.byKey(const Key('registration-send-code')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('registration-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('registration-submit')), findsOneWidget);
  });

  testWidgets('password recovery includes SMS code and new password fields', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: PasswordRecoveryPage(controller: controller),
      ),
    );

    expect(find.byKey(const Key('password-recovery-mobile')), findsOneWidget);
    expect(find.byKey(const Key('password-recovery-code')), findsOneWidget);
    expect(find.byKey(const Key('password-recovery-password')), findsOneWidget);
    expect(find.byKey(const Key('password-recovery-submit')), findsOneWidget);
  });

  testWidgets('profile editor exposes avatar change and logout actions', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    )..enterPreview();
    controller.memberProfile = const {
      'nickname': '体验用户',
      'birthday': '1990-01-01',
      'height': 170,
      'weight': 60,
      'gender': 1,
    };
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: ProfileEditPage(controller: controller),
      ),
    );

    expect(find.byKey(const Key('profile-avatar-picker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-avatar-picker')));
    await tester.pump();
    expect(find.text('登录后可更换头像'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-logout')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('profile-logout')), findsOneWidget);
    expect(find.text('退出体验'), findsOneWidget);
  });

  testWidgets('health alarm is visible above every app page until dismissed', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    )..enterPreview();
    controller.isBooting = false;
    controller.activeHealthWarningAlert = HealthWarningAlert(
      id: 'alert-1',
      metric: HealthMetric.bodyTemperature,
      title: '体温健康预警',
      message: '体温 38.2℃，超过设定值 37.5℃',
      triggeredAt: DateTime.now(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(SaydianApp(controller: controller));
    await tester.pump();

    expect(find.byKey(const Key('global-health-warning')), findsOneWidget);
    expect(find.textContaining('38.2℃'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dismiss-health-warning')));
    await tester.pump();
    expect(find.byKey(const Key('global-health-warning')), findsNothing);
  });
}

class _NoopApi implements SaydianApi {
  @override
  Future<Map<String, Object?>> addCare(String mobile) async => const {};

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];

  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) async => const {};

  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {};

  @override
  Future<void> saveMemberProfile({
    required String nickname,
    required int gender,
    required String birthday,
    required double height,
    required double weight,
    String? headPortrait,
  }) async {}

  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {};

  @override
  Future<void> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  }) async {}

  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];

  @override
  Future<Map<String, Object?>> getArticle(int id) async => const {};

  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async => const {};

  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      const [];

  @override
  Future<Map<String, Object?>> getNotification(int id) async => const {};

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async => const [];

  @override
  Future<Map<String, Object?>> sendAiMessage({
    required int app,
    required String message,
    String? sessionId,
  }) async => const {};

  @override
  Future<List<Map<String, Object?>>> getOrders({int? status}) async => const [];

  @override
  Future<Map<String, Object?>> getOrderDetail(int id) async => const {};

  @override
  Future<List<Map<String, Object?>>> getAddresses() async => const [];

  @override
  Future<Session> login(String username, String password) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<Session> register(String mobile, String password) =>
      throw UnimplementedError();

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) =>
      throw UnimplementedError();
}

class _NoopWearable implements WearableBridge {
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      const {};

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {}

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {}

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async => const {};

  @override
  Future<int?> readHeartRateWarning() async => null;

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async {}

  @override
  Future<void> setHeartRateWarning(int value) async {}

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<WearableEvent> get events => const Stream.empty();

  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {});

  @override
  Future<List<DeviceInfo>> scanDevices() async => const [];

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> startMeasurement(HealthMetric metric) async {}

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}

  @override
  Future<void> startSport(SportMode mode) async {}

  @override
  Future<void> stopSport() async {}

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];
}
