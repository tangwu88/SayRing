import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/widgets/device_wait_status.dart';

class _Api extends Fake implements SaydianApi {}

class _Bridge extends Fake implements WearableBridge {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reconnect keeps the saved target; a newly connected ring wins', () {
    final c = AppController(
      MemorySessionVault(),
      _Api(),
      MemoryHealthStore(),
      _Bridge(),
    );
    addTearDown(() {
      c.rememberedDevice = null;
      c.connectedDevice = null;
      c.dispose();
    });
    c.rememberedDevice = const DeviceInfo(id: 'urion:u19', name: 'U19S');
    c.wearableRecoveryMessage = '等待戒指靠近，靠近后会自动连接';
    c.measurementErrorMessage = '戒指连接中断，测量已停止；重连后请重试';
    c.syncStatus = '已接收 23 条，正在读取戒指数据';
    expect(c.wearableRecoveryMessage, '等待设备靠近，靠近后会自动连接');
    expect(c.measurementErrorMessage, '设备连接中断，测量已停止；重连后请重试');
    expect(c.syncStatus, '已接收 23 条，正在读取设备数据');
    for (final model in [
      'R8',
      'R8 Pro',
      'R21',
      'R22',
      'R7C',
      'R7 Pro',
      'R7 Ultra',
      'HR05',
    ]) {
      final channel = ['R7 Pro', 'R7 Ultra', 'HR05'].contains(model)
          ? 'coolwear'
          : 'qring';
      c.connectedDevice = DeviceInfo(id: '$channel:id', name: model);
      expect(c.wearableRecoveryMessage, startsWith('等待戒指'), reason: model);
      expect(c.syncStatus, endsWith('读取戒指数据'), reason: model);
    }
  });

  test(
    'English progress and disconnect are localized without altering arbitrary data',
    () {
      expect(
        localizeGenericDeviceStatus('正在读取戒指数据 75%', english: true),
        'Reading device data 75%',
      );
      expect(
        localizeGenericDeviceStatus('戒指连接中断，测量已停止；重连后请重试', english: true),
        startsWith('Device disconnected.'),
      );
      expect(localizeGenericDeviceStatus('我的戒指 Ring', english: true), isNull);
    },
  );

  for (final locale in [
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale('en'),
  ]) {
    testWidgets(
      'device and ring wording changes in the same route: ${locale.languageCode}',
      (tester) async {
        final terms = ValueNotifier(true);
        addTearDown(terms.dispose);
        const name = 'Say Ring · 戒指 Ring';
        final zh = locale.languageCode == 'zh';
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: GlobalLocaleController.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: ValueListenableBuilder<bool>(
              valueListenable: terms,
              builder: (context, v, child) =>
                  DevicePromptScope(generic: v, child: child!),
              child: Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      const DeviceWaitStatus(connected: false),
                      Text(
                        devicePromptLabel(
                          context,
                          context.l10n.deviceSearchHelpTitle,
                        ),
                      ),
                      Text(
                        uiCopy(
                          context,
                          '戒指电量 {p0}，{p1}',
                          parameters: [name, '82%'],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.textContaining(
            zh ? '将设备放在手机附近' : 'device near',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(zh ? '找不到设备' : 'device', findRichText: true),
          findsWidgets,
        );
        expect(find.textContaining(name), findsOneWidget);
        terms.value = false;
        await tester.pump();
        expect(
          find.textContaining(
            zh ? '将戒指放在手机附近' : "Can't find your ring?",
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(zh ? '戒指电量' : 'Ring battery'),
          findsOneWidget,
        );
        expect(find.textContaining(name), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
