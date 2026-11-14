import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/ui/sync_diagnostics_page.dart';
import 'sync_diagnostics_recovery_test.dart' as fixture;

void main() {
  testWidgets('diagnostics remains readable on 332dp with large text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(332, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ring = fixture.Ring();
    final controller = AppController(
      MemorySessionVault(),
      fixture.Remote(),
      MemoryHealthStore(),
      ring,
    );
    addTearDown(controller.dispose);
    addTearDown(ring.source.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: SyncDiagnosticsPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('sync-diagnostic-upload')),
      250,
    );
    expect(find.text('上传诊断供客服核查'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
