import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/bluetooth_control_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'emergency fallback only opens system settings without changing a radio or bond',
    () async {
      const channel = MethodChannel('test/bluetooth-control-settings');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await openBluetoothControlSettings(channel: channel);
      expect(calls.single.method, 'openBluetoothControlSettings');
      expect(calls.single.arguments, isNull);
    },
  );
}
