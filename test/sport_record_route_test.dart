import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  test('persists route and heart samples without fabricating missing pace', () {
    final record = SportRecord(
      id: 'local:run',
      mode: SportMode.running,
      startedAt: DateTime.utc(2026, 9, 29, 9),
      durationSeconds: 600,
      distanceKm: 2,
      calories: 0,
      heartRateSamples: const [
        SportHeartRateSample(elapsedSeconds: 10, bpm: 90),
        SportHeartRateSample(elapsedSeconds: 30, bpm: 105),
      ],
      routePoints: [
        SportRoutePoint(
          latitude: 31.1,
          longitude: 121.1,
          recordedAt: DateTime.utc(2026, 9, 29, 9),
        ),
        SportRoutePoint(
          latitude: 31.2,
          longitude: 121.2,
          recordedAt: DateTime.utc(2026, 9, 29, 9, 10),
        ),
      ],
    );
    final restored = SportRecord.fromMap(record.toMap());
    expect(restored.paceSecondsPerKm, 300);
    expect(restored.heartRateSamples.map((sample) => sample.bpm), [90, 105]);
    expect(restored.routePoints, hasLength(2));
    final unknownDistance = SportRecord.fromMap({
      ...record.toMap(),
      'distanceKm': 0,
    });
    expect(unknownDistance.paceSecondsPerKm, isNull);
  });
}
