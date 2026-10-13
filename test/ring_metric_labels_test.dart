import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_interpretation.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/l10n/ui_labels.dart';

void main() {
  test('ring labels do not change health protocol identifiers or units', () {
    expect(HealthMetric.hrv.label, '心率变异性（HRV）');
    expect(HealthMetric.hrv.wireName, 'hrv');
    expect(HealthMetric.hrv.defaultUnit, 'ms');
    expect(HealthMetric.bodyTemperature.label, '皮肤温度');
    expect(HealthMetric.bodyTemperature.wireName, 'body_temperature');
    expect(HealthMetric.bodyTemperature.defaultUnit, '℃');
    expect(HealthMetric.stress.wireName, 'stress');
    expect(HealthMetric.stress, isNot(HealthMetric.hrv));
  });

  test('HRV detail aliases use the same full name and leave RRI distinct', () {
    for (final key in ['value', 'averageHRV', 'hrv']) {
      expect(healthValueLabel(key, HealthMetric.hrv), HealthMetric.hrv.label);
    }
    expect(healthValueLabel('rri', HealthMetric.hrv), 'rri');
    expect(healthValueLabel('rmssd', HealthMetric.hrv), 'RMSSD');
    expect(healthValueLabel('sdnn', HealthMetric.hrv), 'SDNN');
  });

  for (final locale in const [
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    test('$locale names HRV and skin-temperature reminders consistently', () {
      final labels = lookupAppLocalizations(locale);
      final traditional = locale.scriptCode == 'Hant';
      final temperature = traditional ? '皮膚溫度' : '皮肤温度';
      expect(
        labels.metricName(HealthMetric.hrv),
        traditional ? '心率變異性（HRV）' : HealthMetric.hrv.label,
      );
      expect(labels.metricName(HealthMetric.bodyTemperature), temperature);
      expect(labels.temperatureAlertLabel, contains(temperature));
      expect(labels.temperatureUpperLimit, contains(temperature));
      expect(labels.temperatureAlertHint, contains(temperature));
      expect(labels.temperatureAlertHint, contains(traditional ? '發熱' : '发热'));
    });
  }
}
