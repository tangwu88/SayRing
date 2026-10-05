import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/ui/html_text.dart';
import 'package:saydian_app/ui/pages.dart' as facade;
import 'package:saydian_app/ui/pages/content.dart' as content;
import 'package:saydian_app/ui/pages/notifications.dart' as notifications;
import 'package:saydian_app/ui/widgets/inline_notice.dart';

import 'support/dart_library_source.dart';

void main() {
  test('optimized branding retains every decoded pixel', () async {
    Future<(int, int, String)> decoded(String path) async {
      final codec = await ui.instantiateImageCodec(
        File(path).readAsBytesSync(),
      );
      final frame = await codec.getNextFrame();
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final result = (
        frame.image.width,
        frame.image.height,
        sha256.convert(pixels!.buffer.asUint8List()).toString(),
      );
      frame.image.dispose();
      codec.dispose();
      return result;
    }

    expect(
      await decoded('assets/branding/ai-health-manager-doctor-optimized.png'),
      await decoded('assets/branding/ai-health-manager-doctor.png'),
    );
  });

  test('old page imports preserve exported type identity', () {
    expect(facade.GlobalArticleLibraryPage, content.GlobalArticleLibraryPage);
    expect(facade.ArticleDetailPage, content.ArticleDetailPage);
    expect(facade.NotificationsPage, notifications.NotificationsPage);
    expect(facade.NotificationDetailPage, notifications.NotificationDetailPage);
  });

  test('source audits still include every module and avoid cycles', () {
    final dir = Directory.systemTemp.createTempSync('ring-source-audit-');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/entry.dart').writeAsStringSync(
      "part 'part.dart';\nexport 'export.dart';\nimport 'absent.dart';\nENTRY",
    );
    File(
      '${dir.path}/part.dart',
    ).writeAsStringSync("part of 'entry.dart';\nPART_MARKER");
    File('${dir.path}/export.dart').writeAsStringSync(
      "export 'entry.dart';\nexport 'part.dart';\nEXPORT_MARKER",
    );
    final source = readDartLibrarySource('${dir.path}/entry.dart');
    expect('PART_MARKER'.allMatches(source).length, 1);
    expect('EXPORT_MARKER'.allMatches(source).length, 1);
    expect(source, contains('ENTRY'));
    expect(
      readDartLibrarySource('lib/ui/pages.dart'),
      contains('device-sync-data'),
    );
    expect(
      readDartLibrarySource('lib/ui/pages.dart'),
      contains('NotificationsPage'),
    );
  });

  test('HTML plain text conversion preserves existing output', () {
    expect(
      plainTextFromHtml('<p>A&amp;B</p><br/>C&nbsp;&lt;D&gt;'),
      'A&B\n\nC <D>',
    );
    expect(plainTextFromHtml('<div>  </div>'), '');
    expect(plainTextFromHtml('<p>A</p><br/><br/><p>B</p>'), 'A\n\nB');
  });

  test(
    'prototype facade retains all pages and uses shared HTML conversion',
    () {
      final entry = File('lib/ui/prototype_pages.dart').readAsStringSync();
      final source = readDartLibrarySource('lib/ui/prototype_pages.dart');
      expect(
        RegExp(r"^part 'prototype/", multiLine: true).allMatches(entry).length,
        9,
      );
      for (final name in [
        'RegistrationPage',
        'PasswordRecoveryPage',
        'HealthWarningPage',
        'SharingManagementPage',
        'CareShareSettingsPage',
        'CareInvitationsPage',
        'HealthCalibrationPage',
        'HealthRecordDetailPage',
        'DeviceFeaturePage',
        'FeedbackPage',
        'CustomerServicePage',
        'AboutSaydianPage',
        'SecurityCenterPage',
        'ShoppingCartPage',
        'AfterSalesPage',
        'FeatureStateCard',
      ]) {
        expect(
          RegExp('class $name ').allMatches(source).length,
          1,
          reason: name,
        );
      }
      expect(source, isNot(contains('_aboutPlainText')));
      expect(source, contains('plainTextFromHtml(raw)'));
      expect(source, contains('camera-photo-settings-button'));
    },
  );

  testWidgets('shared notice remains a single accessible action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineNotice(
            message: '等待戒指靠近',
            icon: Icons.bluetooth,
            color: Colors.blue,
            compact: true,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('等待戒指靠近'), findsOneWidget);
    await tester.tap(find.text('等待戒指靠近'));
    expect(taps, 1);
  });
}
