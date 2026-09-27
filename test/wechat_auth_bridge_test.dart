import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/wechat_auth_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cc.saidian/app_auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('authorization is bound to a fresh single-use state', () async {
    final states = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'authorizeWechat');
      final state = (call.arguments as Map)['state'] as String;
      states.add(state);
      return {'code': 'one-time-code', 'state': state};
    });
    final bridge = MethodChannelWechatAuthBridge();
    final first = await bridge.authorize();
    final second = await bridge.authorize();
    expect(first!.code, 'one-time-code');
    expect(first.state, states.first);
    expect(second!.state, isNot(first.state));
  });

  test(
    'configured public AppID is forwarded only to the native bridge',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        final arguments = call.arguments as Map;
        expect(arguments['appId'], 'wx1234567890abcdef');
        return {'code': 'one-time-code', 'state': arguments['state']};
      });
      final result = await MethodChannelWechatAuthBridge().authorize(
        appId: 'wx1234567890abcdef',
      );
      expect(result?.code, 'one-time-code');
    },
  );

  test('foreign response cannot authenticate', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'code': 'code', 'state': 'foreign'},
    );
    await expectLater(
      MethodChannelWechatAuthBridge().authorize(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'WECHAT_AUTH_INVALID',
        ),
      ),
    );
  });

  test('user cancellation returns no code', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'state': (call.arguments as Map)['state'],
        'cancelled': true,
      },
    );
    expect(await MethodChannelWechatAuthBridge().authorize(), isNull);
  });

  test('missing one-time code cannot authenticate', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'code': '', 'state': (call.arguments as Map)['state']},
    );
    await expectLater(
      MethodChannelWechatAuthBridge().authorize(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'WECHAT_AUTH_INVALID',
        ),
      ),
    );
  });

  test(
    'duplicate request rejected and cancelled late response ignored',
    () async {
      final pending = Completer<Map<String, Object?>>();
      final started = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancelWechatAuthorization') return null;
        started.complete((call.arguments as Map)['state'] as String);
        return pending.future;
      });
      final bridge = MethodChannelWechatAuthBridge();
      final first = bridge.authorize();
      final state = await started.future;
      await expectLater(bridge.authorize(), throwsA(isA<PlatformException>()));
      await bridge.cancel();
      pending.complete({'state': state, 'code': 'late-code'});
      expect(await first, isNull);
    },
  );

  test('timeout cancels the native pending request', () async {
    final pending = Completer<Object?>();
    var cancelled = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancelWechatAuthorization') {
        cancelled = true;
        return null;
      }
      return pending.future;
    });
    await expectLater(
      MethodChannelWechatAuthBridge(
        timeout: const Duration(milliseconds: 20),
      ).authorize(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'WECHAT_AUTH_TIMEOUT',
        ),
      ),
    );
    expect(cancelled, isTrue);
    pending.complete(null);
  });
}
