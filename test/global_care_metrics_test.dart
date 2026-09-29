import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/ui/global_care_page.dart';

void main() {
  test('care sharing maps temperature and excludes unsupported stress', () {
    expect(
      supportedCareMetrics({
        HealthMetric.heartRate,
        HealthMetric.bodyTemperature,
        HealthMetric.stress,
      }),
      {'heart_rate', 'temperature'},
    );
    expect(supportedCareMetrics(const <HealthMetric>{}), isEmpty);
  });
}
