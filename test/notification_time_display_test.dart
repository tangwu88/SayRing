import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:saydian_app/ui/pages.dart';

void main() {
  test(
    'message UTC time is displayed in the phone timezone without raw ISO',
    () {
      final date = DateTime.utc(2026, 10, 3, 14, 28, 8);
      expect(
        notificationDisplayTime(date.toIso8601String()),
        DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal()),
      );
    },
  );
  test('explicit timezone offsets identify the same message instant', () {
    expect(
      notificationDisplayTime('2026-10-03T22:28:08+08:00'),
      notificationDisplayTime('2026-10-03T14:28:08Z'),
    );
  });
  test('missing or invalid message dates do not invent a timestamp', () {
    for (final value in [null, '', 'invalid-date', 123]) {
      expect(notificationDisplayTime(value), isEmpty);
    }
  });
}
