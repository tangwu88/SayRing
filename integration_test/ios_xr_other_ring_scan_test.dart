import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'XR scans nearby rings without replacing the saved target',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice?.id;
      expect(owner, isNotNull);
      expect(target, isNotNull);

      String model(String name) {
        final value = name.toUpperCase().replaceAll(RegExp(r'[\s_-]'), '');
        for (final marker in const [
          'R7PRO',
          'HR05',
          'R7ULTRA',
          'R21',
          'R12',
          'R8',
        ]) {
          if (value.contains(marker)) return marker;
        }
        return 'OTHER';
      }

      try {
        await app.scanDevices().timeout(const Duration(seconds: 45));
        final found = app.scannedDevices
            .map((device) => '${model(device.name)}:${device.sdkSource.name}')
            .toList();
        binding.reportData = {
          ...?binding.reportData,
          'nearbyRings': found,
          'count': found.length,
          'scanIssue': app.deviceScanIssue?.name,
        };
        expect(app.deviceScanIssue, isNull);
      } finally {
        await app.stopDeviceScan();
      }
      expect(app.session?.accountKey, owner);
      expect(app.rememberedDevice?.id, target);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
