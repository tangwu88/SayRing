import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';

/// Only the current owner's exact bound ring. Preserve all original parameters.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'owned QRing gesture modes and real readback',
    (tester) async {
      final controller = AppController.production();
      addTearDown(controller.dispose);
      final checks = <String>[];
      final observations = <String, Object?>{};
      void checked(String name) {
        checks.add(name);
        debugPrint('QRING GESTURE: $name');
      }

      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 180 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(ready(), isTrue);
      }

      try {
        runApp(SaydianApp(controller: controller));
        checked('waiting_for_foreground');
        while (!binding.framesEnabled ||
            binding.lifecycleState != AppLifecycleState.resumed) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        checked('foreground_ready');
        await controller.initialize().timeout(const Duration(seconds: 45));
        await tester.pump();
        expect(controller.isAuthenticated, isTrue);
        final owner = controller.session!.accountKey;
        final target = controller.rememberedDevice!;
        expect(target.id.startsWith('qring:'), isTrue);
        void sameTarget() {
          expect(controller.session?.accountKey, owner);
          expect(controller.connectedDevice?.id, target.id);
        }

        await waitFor(
          () =>
              controller.connectedDevice?.id == target.id &&
              !controller.isDeviceSyncing &&
              controller.deviceCapabilityState == DeviceCapabilityState.ready,
        );
        sameTarget();
        checked('owned_qring_handshake');
        expect(
          controller.visibleDeviceFeatures,
          contains(DeviceFeature.gestureControl),
        );
        final original = await controller.readDeviceFeature(
          DeviceFeature.gestureControl,
        );
        observations['original'] = original;
        expect(original['readbackVerified'], true);
        expect(original['enabled'], original['rawMode'] != 0);
        final modes = (original['availableModes'] as List).cast<int>();
        expect(modes, contains(0));
        checked('actual_gesture_read');
        controller.selectTab(1);
        await tester.pump(const Duration(seconds: 1));
        final entry = find.byKey(
          const ValueKey('device-feature-gesture_control'),
        );
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pump(const Duration(milliseconds: 500));
        await waitFor(
          () => !controller.deviceFeatureBusy.contains(
            DeviceFeature.gestureControl,
          ),
        );
        expect(find.byKey(const ValueKey('gesture-mode-0')), findsOneWidget);
        checked('gesture_page_open');
        final initial = original['confirmedMode'];
        if (initial is! int || !modes.contains(initial)) {
          observations['writeSkipped'] =
              'Original mode cannot safely be restored by the supported UI modes';
        } else {
          try {
            for (final mode in modes) {
              sameTarget();
              final before = await controller.readDeviceFeature(
                DeviceFeature.gestureControl,
              );
              expect(
                await controller.writeDeviceFeature(
                  DeviceFeature.gestureControl,
                  {'mode': mode, 'expectedMode': before['rawMode']},
                ),
                isTrue,
                reason: controller.errorMessage,
              );
              final actual = await controller.readDeviceFeature(
                DeviceFeature.gestureControl,
              );
              expect(actual['confirmedMode'], mode);
              expect(actual['enabled'], mode != 0);
              expect(actual['strength'], original['strength']);
              expect(actual['duration'], original['duration']);
              checked('mode_${mode}_write_readback');
            }
          } finally {
            sameTarget();
            final before = await controller.readDeviceFeature(
              DeviceFeature.gestureControl,
            );
            expect(
              await controller.writeDeviceFeature(
                DeviceFeature.gestureControl,
                {'mode': initial, 'expectedMode': before['rawMode']},
              ),
              isTrue,
              reason: controller.errorMessage,
            );
            final restored = await controller.readDeviceFeature(
              DeviceFeature.gestureControl,
            );
            expect(restored['rawMode'], original['rawMode']);
            expect(restored['strength'], original['strength']);
            expect(restored['duration'], original['duration']);
            checked('original_mode_parameters_restored');
          }
        }
        // Refresh the actual settings page to show the final restored state.
        await tester.tap(find.byKey(const ValueKey('gesture-refresh')));
        await tester.pump(const Duration(milliseconds: 500));
        await waitFor(
          () => !controller.deviceFeatureBusy.contains(
            DeviceFeature.gestureControl,
          ),
        );
        await binding.takeScreenshot('qring-gesture-restored');
        checked('final_page_readback');
      } finally {
        binding.reportData = {
          ...?binding.reportData,
          'checks': checks,
          'observations': observations,
        };
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
