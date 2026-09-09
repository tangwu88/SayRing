import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

Session account(String id) => Session(
  accessToken: 'synthetic-$id',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Synthetic',
  accountKey: 'global:member:$id',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final operation in ['AI history', 'AI reply', 'orders']) {
    for (final fail in [false, true]) {
      test(
        '$operation late ${fail ? 'error' : 'success'} cannot enter another account',
        () async {
          final api = DeferredApi();
          final controller = AppController(
            MemorySessionVault(),
            api,
            MemoryHealthStore(),
            FakeWearable(),
          )..session = account('owner-a');
          addTearDown(controller.dispose);
          final Future<Object?> request = switch (operation) {
            'AI history' => controller.refreshAiMessages(app: 1),
            'AI reply' => controller.sendAiMessage(
              app: 1,
              message: 'Private original',
            ),
            _ => controller.loadOrders(null),
          };
          await api.started.future;
          await controller.logout();
          controller.session = account('owner-b');
          controller.errorMessage = 'New account';
          controller.orderStatus = 'New orders';
          controller.isBusy = true;
          var notifications = 0;
          controller.addListener(() => notifications++);
          if (fail) {
            api.pending.completeError(const ApiException('Old account error'));
          } else {
            api.pending.complete({
              'message': 'Old private reply',
              'session_id': 'private-a',
            });
          }
          await request;
          expect(controller.aiMessages, isEmpty);
          expect(controller.orders, isEmpty);
          expect(controller.errorMessage, 'New account');
          expect(controller.orderStatus, 'New orders');
          expect(controller.isBusy, isTrue);
          expect(notifications, 0);
        },
      );
    }
  }
}

class DeferredApi extends Fake implements SaydianApi {
  final started = Completer<void>();
  final pending = Completer<Map<String, Object?>>();
  Future<Map<String, Object?>> wait() {
    started.complete();
    return pending.future;
  }

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async => [await wait()];
  @override
  Future<Map<String, Object?>> sendAiMessage({
    required int app,
    required String message,
    String? sessionId,
  }) => wait();
  @override
  Future<List<Map<String, Object?>>> getOrders({int? status}) async => [
    await wait(),
  ];
  @override
  Future<void> logout() async {}
}

class FakeWearable extends Fake implements WearableBridge {}
