import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/cycle_tracking.dart';
import 'package:saydian_app/services/cycle_tracking_service.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/ui/cycle_night_trend.dart';
import 'cycle_tracking_test.dart' show Remote, Notifications, settings;

class Versioned extends Remote {
  bool capable = false, offline = false, omitAck = false;
  final sent = <Map>[];
  @override
  Future<Map<String, Object?>> cycleRequest(
    String owner,
    String method,
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    if (offline) throw StateError('offline');
    if (path == 'sync') {
      sent.addAll(List<Map>.from(body['rows'] as List));
      if (omitAck) return {'results': []};
    }
    final result = await super.cycleRequest(owner, method, path, body: body);
    return {
      ...result,
      if (capable && path.startsWith('changes')) 'schemaVersion': 2,
    };
  }
}

class LostReceipt extends Versioned {
  final receipts = <String, Map<String, Object?>>{};
  bool loseNext = false;
  @override
  Future<Map<String, Object?>> cycleRequest(
    String o,
    String method,
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    if (path != 'sync') return super.cycleRequest(o, method, path, body: body);
    final mid = ((body['rows'] as List).single as Map)['mutationId'] as String;
    final saved = receipts[mid];
    if (saved != null) return saved;
    final r = await super.cycleRequest(o, method, path, body: body);
    receipts[mid] = r;
    if (loseNext) {
      loseNext = false;
      throw StateError('lost receipt');
    }
    return r;
  }
}

void main() {
  test('提交成功但断网丢回执时，重放同一修订，不误报跨手机冲突', () async {
    final remote = LostReceipt()..capable = true;
    final c = CycleTrackingService(
      MemoryHealthStore(),
      remote: remote,
      notifications: Notifications(),
      clock: () => DateTime(2026, 11, 5),
    )..setOwner('owner');
    await c.load();
    await c.saveSettings(settings);
    remote.loseNext = true;
    await c.save(
      const CycleEntry(
        id: 'daily-2026-11-01',
        kind: 'daily',
        data: {
          'date': '2026-11-01',
          'symptoms': ['headache'],
        },
      ),
    );
    expect(c.status, '已存本机');
    expect(c.pendingCount, 1);
    await c.sync();
    expect(c.status, '已同步');
    expect(c.conflicts, isEmpty);
    expect(remote.seq, 2);
    c.dispose();
  });
  test(
    'selected civil day wins over today and predictions never fill history',
    () {
      final p = CyclePrediction(
        status: 'reference',
        from: '2027-01-02',
        to: '2027-01-09',
      );
      const actual = CycleEntry(
        id: 'p',
        kind: 'period',
        data: {'start': '2026-12-30', 'end': '2027-01-03'},
      );
      expect(cycleWeekStart('2027-01-01'), '2026-12-28');
      expect(
        cycleDayView([actual], p, '2027-01-01', '2027-01-07').periodDay,
        3,
      );
      expect(
        cycleDayView([actual], p, '2027-01-04', '2027-01-07').inReference,
        false,
      );
      expect(
        cycleDayView([actual], p, '2027-01-08', '2027-01-07').inReference,
        true,
      );
      expect(shiftCycleDate('2026-03-08', 1), '2026-03-09');
    },
  );
  test(
    'trend selects only qualified output dates and same-source nights up to the viewed day',
    () {
      CycleNightFeature n(String day, double value, String source) =>
          CycleNightFeature(
            date: day,
            sourceKey: source,
            metric: 'skin_temperature',
            value: value,
            samples: 8,
            coverageMinutes: 250,
            maxGapMinutes: 20,
            recordIds: const [],
          );
      final series = [
        n('2026-09-01', 39, 'A'),
        n('2026-11-01', 32, 'A'),
        n('2026-11-02', 37, 'B'),
        n('2026-11-04', 34, 'A'),
        n('2026-11-07', 80, 'A'),
      ];
      final s = CycleTrendSeries.build(
        series,
        'skin_temperature',
        '2026-11-04',
      )!;
      expect(s.points, [
        (date: '2026-11-01', delta: -1.0),
        (date: '2026-11-04', delta: 1.0),
      ]);
      expect(
        CycleTrendSeries.build(
          series,
          'skin_temperature',
          '2026-11-02',
        )!.points.single.delta,
        0,
      );
      expect(CycleTrendSeries.build(series, 'hrv_rmssd', '2026-11-04'), isNull);
    },
  );
  test(
    'offline restart, legacy server, missing receipts, account isolation and later capability/clear',
    () async {
      final storage = MemoryHealthStore(),
          remote = Versioned(),
          date = '2026-01-01';
      CycleTrackingService client() => CycleTrackingService(
        storage,
        remote: remote,
        notifications: Notifications(),
        clock: () => DateTime(2026, 11, 5),
      );
      var c = client()..setOwner('A');
      await c.load();
      await c.saveSettings(settings);
      CycleEntry entry(List<String> symptoms) => CycleEntry(
        id: 'daily-$date',
        kind: 'daily',
        data: {'date': date, 'mood': 'calm', 'symptoms': symptoms},
      );
      remote.offline = true;
      await c.save(entry(['headache', 'bloating']));
      expect(c.status, '已存本机');
      c.dispose();
      c = client()..setOwner('A');
      await c.load();
      expect(c.entries.single.data['symptoms'], ['headache', 'bloating']);
      remote.offline = false;
      await c.sync();
      expect(
        remote.sent.any((r) => (r['data'] as Map).containsKey('symptoms')),
        false,
      );
      c.setOwner('B');
      remote.offline = true;
      await c.load();
      expect(c.entries, isEmpty);
      c.setOwner('A');
      await c.load();
      remote.offline = false;
      remote.capable = true;
      remote.omitAck = true;
      await c.sync();
      expect(c.pendingCount, 1);
      expect(c.status, '已存本机');
      remote.omitAck = false;
      await c.sync();
      expect(c.pendingCount, 0);
      expect(c.status, '已同步');
      final rev = c.entries.single.revision;
      await c.save(entry(['headache', 'bloating']));
      expect(c.entries.single.revision, rev);
      await c.save(entry([]));
      expect((remote.rows['daily-$date']!['data'] as Map)['symptoms'], isEmpty);
      expect(c.prediction.from, isNull);
      c.dispose();
    },
  );
}
