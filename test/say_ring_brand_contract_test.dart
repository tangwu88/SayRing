import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all locale catalogs keep the Say Ring identity', () {
    final catalogs = Directory('lib/l10n').listSync().whereType<File>().where(
      (file) => RegExp(r'app_[^\\/]+\.arb$').hasMatch(file.path),
    );

    for (final catalog in catalogs) {
      final messages =
          jsonDecode(catalog.readAsStringSync()) as Map<String, dynamic>;
      expect(messages['appName'], 'Say Ring', reason: catalog.path);
      for (final key in const [
        'brandHealthTitle',
        'brandedEcgReport',
        'defaultUser',
        'careInviteHint',
        'noAccount',
        'aboutApp',
        'enableNotifications',
      ]) {
        final value = messages[key] as String;
        expect(value, contains('Say Ring'), reason: '${catalog.path}:$key');
        expect(
          value,
          isNot(matches(RegExp(r'Saydian|赛电'))),
          reason: '${catalog.path}:$key',
        );
      }
    }
  });

  test('generic wearable copy uses ring language in every locale', () {
    const ringFacingKeys = [
      'finishLeaveWorkoutHint',
      'workoutRouteMissing',
      'spotCheckCuffHint',
      'calibrationDisabledHint',
      'riskIndicatorsMissing',
      'modelFeaturesVary',
      'assessmentEnabledHint',
      'autoMonitorIntervalHint',
      'watchHeartRateAlert',
      'sustainedLimitWatchAlert',
      'ecgElectrodeHint',
      'watchThresholdHint',
      'watchDistance',
      'watchSteps',
      'watchCalories',
      'scanLocationHint',
      'scanPermissionHint',
      'syncFailedTryAgain',
      'findWatch',
      'useWatch',
    ];
    final forbiddenByCatalog = <String, RegExp>{
      'app_en.arb': RegExp(r'\bwatch(?:es)?\b', caseSensitive: false),
      'app_de.arb': RegExp(r'\bUhr(?:en)?\b|Zifferblatt'),
      'app_fr.arb': RegExp(r'\bmontre(?:s)?\b|cadran', caseSensitive: false),
      'app_es.arb': RegExp(r'\breloj(?:es)?\b|esfera', caseSensitive: false),
      'app_ja.arb': RegExp(r'腕時計|文字盤'),
      'app_ko.arb': RegExp(r'워치'),
      'app_zh.arb': RegExp(r'手表|表盘'),
      'app_zh_Hans.arb': RegExp(r'手表|表盘'),
      'app_zh_Hant.arb': RegExp(r'手錶|錶盤|錶面'),
    };

    for (final entry in forbiddenByCatalog.entries) {
      final file = File('lib/l10n/${entry.key}');
      final messages =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in ringFacingKeys) {
        final value = messages[key] as String;
        expect(
          value,
          isNot(matches(entry.value)),
          reason: '${file.path}:$key should describe a ring, not a watch',
        );
      }
    }
  });

  test('all localized user copy avoids device-specific watch wording', () {
    final forbiddenByCatalog = <String, RegExp>{
      'app_en.arb': RegExp(r'\bwatch(?:es)?\b', caseSensitive: false),
      'app_de.arb': RegExp(r'\bUhr(?:en)?\b'),
      'app_fr.arb': RegExp(r'\bmontre(?:s)?\b', caseSensitive: false),
      'app_es.arb': RegExp(r'\breloj(?:es)?\b', caseSensitive: false),
      'app_ja.arb': RegExp(r'腕時計'),
      'app_ko.arb': RegExp(r'워치'),
      'app_zh.arb': RegExp(r'手表'),
      'app_zh_Hans.arb': RegExp(r'手表'),
      'app_zh_Hant.arb': RegExp(r'手錶'),
    };

    for (final entry in forbiddenByCatalog.entries) {
      final file = File('lib/l10n/${entry.key}');
      final messages =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final message in messages.entries) {
        if (message.key.startsWith('@')) continue;
        if (entry.key == 'app_es.arb' &&
            const {'addWorldClock', 'worldClock'}.contains(message.key)) {
          continue;
        }
        if (message.value is! String) continue;
        expect(
          message.value as String,
          isNot(matches(entry.value)),
          reason: '${file.path}:${message.key}',
        );
      }
    }
  });

  test('Flutter wearable fallbacks cannot leak watch wording', () {
    for (final path in const [
      'lib/domain/feature_models.dart',
      'lib/domain/health_interpretation.dart',
      'lib/domain/models.dart',
      'lib/services/device_watch_face_market_service.dart',
      'lib/services/wearable_bridge.dart',
      'lib/services/app_controller.dart',
      'lib/services/wearable_routing.dart',
      'lib/services/yucheng_wearable_bridge.dart',
      'lib/ui/health_reports_page.dart',
      'lib/ui/pages.dart',
      'lib/ui/prototype_pages.dart',
      'lib/ui/watch_face_market_page.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(matches(RegExp(r'手表|表盘'))), reason: path);
    }
  });

  test('core Flutter services cannot leak the old product name', () {
    for (final path in const [
      'lib/services/app_controller.dart',
      'lib/services/wearable_routing.dart',
      'lib/services/yucheng_wearable_bridge.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('赛电')), reason: path);
    }
  });
}
