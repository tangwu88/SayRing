import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/cycle_tracking.dart';
import 'package:saydian_app/services/cycle_tracking_service.dart';
import 'package:saydian_app/services/local_health_store.dart';

const settings = CycleSettings(
  enabled: true,
  adultConfirmed: true,
  purposeAccepted: true,
  historyComplete: true,
);
CycleEntry p(String id, String start, String? end) => CycleEntry(
  id: id,
  kind: 'period',
  data: {'start': start, 'end': ?end},
  revision: 1,
);
List<CycleEntry> history() => [
  p('p1', '2026-07-03', '2026-07-08'),
  p('p2', '2026-07-31', '2026-08-05'),
  p('p3', '2026-08-30', '2026-09-04'),
  p('p4', '2026-10-01', null),
];

class Notifications extends CycleNotifications {
  String? active;
  List<Map<String, Object?>> plans = [];
  @override
  Future<void> owner(String? value) async {
    active = value;
    plans = [];
  }

  @override
  Future<bool> schedule(
    String owner,
    List<Map<String, Object?>> plans, {
    bool request = false,
  }) async {
    if (owner != active) return false;
    this.plans = plans;
    return true;
  }
}

class DelayedNotifications extends Notifications {
  final started = Completer<void>();
  final response = Completer<bool>();
  @override
  Future<bool> schedule(
    String owner,
    List<Map<String, Object?>> plans, {
    bool request = false,
  }) {
    if (!request) return super.schedule(owner, plans, request: request);
    started.complete();
    return response.future;
  }
}

class Remote implements CycleRemote {
  final rows = <String, Map<String, Object?>>{};
  int seq = 0;
  final changes = <Map<String, Object?>>[];
  Completer<Map<String, Object?>>? held;
  @override
  Future<Map<String, Object?>> cycleRequest(
    String owner,
    String method,
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    if (held != null) return held!.future;
    if (path == 'sync') {
      final results = <Map<String, Object?>>[];
      for (final raw in body['rows'] as List) {
        final r = Map<String, Object?>.from(raw as Map);
        final old = rows[r['id']];
        if ((old?['revision'] ?? 0) != r['baseRevision']) {
          results.add({'id': r['id'], 'conflict': old});
          continue;
        }
        final saved = {
          'id': r['id'],
          'kind': r['kind'],
          'data': r['data'],
          'deleted': r['deleted'],
          'revision': (old?['revision'] as int? ?? 0) + 1,
        };
        rows[r['id'] as String] = saved;
        changes.add(saved);
        seq++;
        results.add({
          'id': r['id'],
          'row': saved,
          'mutationId': r['mutationId'],
        });
      }
      return {'results': results, 'sequence': seq};
    }
    if (path.startsWith('changes')) {
      return {'rows': rows.values.toList(), 'cursor': seq, 'hasMore': false};
    }
    if (path == 'erase') {
      rows.clear();
      return {'deleted': true};
    }
    return {};
  }
}

void main() {
  test(
    'late notification permission result cannot change the new account',
    () async {
      final n = DelayedNotifications();
      final c = CycleTrackingService(MemoryHealthStore(), notifications: n);
      addTearDown(c.dispose);
      c.setOwner('a');
      await c.load();
      await c.saveSettings(settings);
      final pending = c.enableNotifications(true);
      await n.started.future;
      c.setOwner('b');
      n.response.complete(true);
      await pending;
      expect(c.owner, 'b');
      expect(c.notificationAccepted, false);
      expect(c.notificationOptIn, false);
    },
  );
  test(
    '28 30 32 real cycles yield Oct29 to Nov2, no inferred actual dates',
    () {
      final r = cyclePrediction(history(), settings, '2026-10-10');
      expect(r.from, '2026-10-29');
      expect(r.to, '2026-11-02');
      expect(r.completeCycles, 3);
      expect(history().last.end, isNull);
    },
  );
  test('missing periods, incomplete history and record-only never predict', () {
    expect(
      cyclePrediction(history().take(3), settings, '2026-10-10').from,
      isNull,
    );
    expect(
      cyclePrediction(
        history(),
        const CycleSettings(enabled: true),
        '2026-10-10',
      ).from,
      isNull,
    );
    expect(
      cyclePrediction(
        history(),
        const CycleSettings(
          enabled: true,
          recordOnly: true,
          historyComplete: true,
        ),
        '2026-10-10',
      ).from,
      isNull,
    );
  });
  test('past window does not roll forward, editing source changes basis', () {
    expect(
      cyclePrediction(history(), settings, '2026-11-04').status,
      'needs_confirmation',
    );
    final h = history()..removeAt(1);
    expect(cyclePrediction(h, settings, '2026-10-10').from, isNull);
  });
  test('real dates handle leap days and reject normalized invalid dates', () {
    expect(cycleDays('2024-02-28', '2024-03-01'), 2);
    expect(() => parseCycleDate('2026-02-30'), throwsFormatException);
    expect(cycleDays('2026-03-07', '2026-03-09'), 2);
  });
  test(
    'future overlapping and reversed records rejected, missing versus none preserved',
    () {
      expect(
        () => validateCycleEntry(
          p('new', '2026-07-05', '2026-07-09'),
          history(),
          '2026-11-04',
        ),
        throwsFormatException,
      );
      expect(
        () => validateCycleEntry(
          p('future', '2027-01-01', null),
          [],
          '2026-11-04',
        ),
        throwsFormatException,
      );
      expect(
        () => validateCycleEntry(
          p('bad', '2026-01-05', '2026-01-01'),
          [],
          '2026-11-04',
        ),
        throwsFormatException,
      );
      final e = CycleEntry(
        id: 'd',
        kind: 'daily',
        data: {'date': '2026-10-01', 'pain': 'none'},
      );
      validateCycleEntry(e, [], '2026-11-04');
      expect(e.data.containsKey('fatigue'), false);
    },
  );
  test(
    'offline edits and settings survive restart without modifying health records',
    () async {
      final store = MemoryHealthStore(), n = Notifications();
      await store.switchOwner('a');
      final c = CycleTrackingService(
        store,
        notifications: n,
        clock: () => DateTime(2026, 11, 4),
      );
      c.setOwner('a');
      await c.load();
      await c.saveSettings(settings);
      await c.save(p('p1', '2026-10-01', '2026-10-05'));
      expect(c.pendingCount, 2);
      final next = CycleTrackingService(store, notifications: Notifications());
      next.setOwner('a');
      await next.load();
      expect(next.entries.single.start, '2026-10-01');
      expect(next.settings.enabled, true);
      expect(await store.recent(), isEmpty);
      c.dispose();
      next.dispose();
    },
  );
  test(
    'cloud roundtrip and tombstones retain local settings and prevent resurrection',
    () async {
      final store = MemoryHealthStore(),
          r = Remote(),
          c = CycleTrackingService(
            store,
            remote: r,
            notifications: Notifications(),
          );
      c.setOwner('a');
      await c.load();
      await c.saveSettings(settings);
      await c.save(p('p1', '2026-10-01', '2026-10-05'));
      expect(c.pendingCount, 0);
      await c.save(
        CycleEntry(id: 'p1', kind: 'period', data: {}, deleted: true),
      );
      expect(c.entries, isEmpty);
      expect(r.rows['p1']?['deleted'], true);
      await c.sync();
      expect(c.entries, isEmpty);
      c.dispose();
    },
  );
  test(
    'late old-owner cloud callback cannot publish data or reschedule notifications',
    () async {
      final store = MemoryHealthStore(),
          r = Remote(),
          n = Notifications(),
          c = CycleTrackingService(store, remote: null, notifications: n);
      c.setOwner('a');
      await c.load();
      await c.saveSettings(settings);
      c.setOwner('b');
      await c.load();
      expect(c.entries, isEmpty);
      expect(c.settings.enabled, false);
      expect(n.active, 'b');
      final other = CycleTrackingService(
        store,
        remote: r,
        notifications: Notifications(),
      );
      other.setOwner('a');
      r.held = Completer();
      final pending = other.load();
      await Future<void>.delayed(Duration.zero);
      other.setOwner('b');
      r.held!.complete({'rows': [], 'cursor': 9, 'hasMore': false});
      await pending;
      expect(other.settings.enabled, false);
      expect(other.owner, 'b');
      other.dispose();
      c.dispose();
    },
  );
  test(
    'reminders are opt-in per phone; disabled setting cancels plans',
    () async {
      final n = Notifications(),
          c = CycleTrackingService(
            MemoryHealthStore(),
            notifications: n,
            clock: () => DateTime(2026, 10, 10),
          );
      c.setOwner('a');
      await c.load();
      await c.saveSettings(
        CycleSettings.fromJson({...settings.toJson(), 'recordRemind': true}),
      );
      expect(n.plans, isEmpty);
      await c.enableNotifications(true);
      expect(n.plans.length, 30);
      expect(n.plans.map((p) => p['date']), [
        for (var i = 0; i < 30; i++) shiftCycleDate('2026-10-10', i),
      ]);
      await c.saveSettings(const CycleSettings());
      expect(n.plans, isEmpty);
      c.dispose();
    },
  );
  test(
    'erase offline clears data and does not bring back cloud history',
    () async {
      final store = MemoryHealthStore(),
          c = CycleTrackingService(store, notifications: Notifications());
      c.setOwner('a');
      await c.load();
      await c.saveSettings(settings);
      await c.save(p('p', '2026-10-01', null));
      await c.erase();
      expect(c.entries, isEmpty);
      expect(c.settings.enabled, false);
      expect(
        (await store.cycleRows('a')).any((r) => r['id'] == 'erase-pending'),
        true,
      );
      c.dispose();
    },
  );
}
