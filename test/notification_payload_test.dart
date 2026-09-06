import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/app_notification_service.dart';
import 'package:saydian_app/services/notification_models.dart';

void main() {
  final cases =
      (jsonDecode(
                File(
                  'test/fixtures/notification_contracts.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  for (final fixture in cases) {
    test('notification parity: ${fixture['name']}', () {
      final payload = fixture['payload'] as Map<String, dynamic>;
      for (final input in [
        payload,
        <String, dynamic>{
          'extras': {'cn.jpush.android.EXTRA': jsonEncode(payload)},
        },
      ]) {
        final result = normalizeJPushPayload(input);
        if (fixture['rejected'] == true) {
          expect(result, isNull);
          continue;
        }
        expect(result?['event_id'], fixture['eventId']);
        expect(result?['entity_id'], fixture['entityId']);
        expect(result?['event_type'], fixture['type']);
        expect(result, isNot(contains('token')));
        expect(result, isNot(contains('health')));
        final event = NotificationEvent.tryParse(result!);
        expect(event, isNotNull);
        expect(event!.eventId, fixture['eventId']);
      }
    });
  }
}
