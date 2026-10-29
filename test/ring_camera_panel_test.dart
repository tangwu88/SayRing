import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/ui/widgets/ring_camera_panel.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'camera controls and failed-photo retry fit 332dp scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(332, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var retry = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(332, 740),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    RingCameraPanel(
                      preview: const SizedBox(),
                      message: '保存失败，请重试',
                      remoteReady: true,
                      takingPhoto: false,
                      saved: false,
                      onCapture: () {},
                      onRetrySave: () => retry++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(
          find.byKey(const Key('camera-retry-save-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('camera-retry-save-button')));
        expect(retry, 1);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('camera-shutter-button')), findsOneWidget);
        expect(find.text('使用戒指支持的拍照动作，或轻点下方快门'), findsOneWidget);
      },
    );
  }
}
