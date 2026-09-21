import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/coolwear_wearable_bridge.dart';

void main() {
  test(
    'HR01 history remains fail-closed until its multipart ACK is verified',
    () {
      final bridge = CoolWearWearableBridge();

      expect(
        bridge.syncHealthData(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'HISTORY_UNVERIFIED',
          ),
        ),
      );
    },
  );
}
