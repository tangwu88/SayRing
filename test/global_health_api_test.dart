import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

http.Response _ok(Object? data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);
Session _session([String owner = 'a']) => Session(
  accessToken: 'synthetic-access-$owner',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: owner,
  displayName: 'QA',
  accountKey: 'global:member:$owner',
);
HealthRecord _record(
  String id, {
  HealthMetric metric = HealthMetric.heartRate,
  String timezone = '-07:00',
  MeasurementOrigin origin = MeasurementOrigin.watchHistory,
  MeasurementSource source = MeasurementSource.wearable,
  List<num> samples = const [],
  String quality = 'unknown',
}) => HealthRecord(
  id: id,
  metric: metric,
  values: const {'value': 75},
  unit: metric.defaultUnit,
  measuredAt: DateTime.parse('2026-09-01T05:23:14Z'),
  timezone: timezone,
  deviceId: 'synthetic-device',
  firmwareVersion: 'qa-firmware',
  quality: quality,
  source: source,
  origin: origin,
  rawVersion: 2,
  samples: samples,
);
Map<String, Object?> _rule(
  String metric, {
  bool enabled = true,
  num? high = 130,
  num? secondary,
  num? low,
  bool shared = false,
}) => {
  'metric': metric,
  'enabled': enabled,
  'highThreshold': high,
  'secondaryHighThreshold': secondary,
  'lowThreshold': low,
  'shareWithCare': shared,
};

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final provenance in ['device_reported', 'sdk']) {
    test(
      'native $provenance provenance is unknown quality, never valid',
      () async {
        final original = _record('native', quality: provenance);
        final api = GlobalSaydianApiClient(
          MemorySessionVault()..session = _session(),
          client: MockClient((request) async {
            final row =
                ((jsonDecode(request.body) as Map)['records'] as List).single
                    as Map;
            expect(row['quality'], 'unknown');
            expect(row['values'], original.values);
            expect(row['source']['measurementSource'], 'wearable');
            return _ok({
              'acceptedIds': ['native'],
              'rejected': [],
              'nextCursor': null,
            });
          }),
        );
        final result = await api.uploadHealthBatch(
          SyncBatch(cursor: null, records: [original]),
        );
        expect(result.acceptedIds, {'native'});
        expect(original.quality, provenance);
      },
    );
  }

  test(
    'V2 sends every same-minute sample with original metadata and a stable key',
    () async {
      final requests = <http.Request>[];
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((request) async {
          requests.add(request);
          return _ok({
            'acceptedIds': ['a', 'b'],
            'rejected': [],
            'nextCursor': 'server-cursor',
          });
        }),
      );
      final batch = SyncBatch(
        cursor: null,
        records: [
          _record('a'),
          _record('b', metric: HealthMetric.bodyTemperature),
        ],
      );
      expect((await api.uploadHealthBatch(batch)).acceptedIds, {'a', 'b'});
      await api.uploadHealthBatch(batch);
      expect(
        requests.first.url.path,
        '/global/api/saydian-app/v2/health/records/batch',
      );
      expect(
        requests.first.headers['Idempotency-Key'],
        requests.last.headers['Idempotency-Key'],
      );
      expect(
        requests.first.headers['Idempotency-Key'],
        startsWith('global-health-'),
      );
      final rows = (jsonDecode(requests.first.body) as Map)['records'] as List;
      expect(rows, hasLength(2));
      expect(rows[0]['observedAt'], '2026-09-01T05:23:14.000Z');
      expect(rows[0]['timezoneOffsetMinutes'], -420);
      expect(rows[0]['values'], {'value': 75});
      expect(rows[0]['quality'], 'unknown');
      expect(rows[0]['source'], {
        'platform': 'android',
        'deviceId': 'synthetic-device',
        'firmware': 'qa-firmware',
        'origin': 'watch_history',
        'measurementSource': 'wearable',
        'rawVersion': 2,
      });
      expect(rows[1]['metric'], 'temperature');
    },
  );

  test(
    'partial and missing acknowledgements never become accepted IDs',
    () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient(
          (_) async => _ok({
            'acceptedIds': ['a'],
            'rejected': [
              {
                'id': 'b',
                'code': 'invalid_time',
                'message': 'raw technical details',
              },
            ],
            'nextCursor': null,
          }),
        ),
      );
      final result = await api.uploadHealthBatch(
        SyncBatch(
          cursor: null,
          records: [_record('a'), _record('b'), _record('c')],
        ),
      );
      expect(result.acceptedIds, {'a'});
      expect(result.rejected.keys.toSet(), {'b', 'c'});
      expect(result.rejected['b'], isNot(contains('raw technical')));
    },
  );

  for (final ack in [
    {
      'acceptedIds': ['not-submitted'],
      'rejected': [],
      'nextCursor': null,
    },
    {
      'acceptedIds': ['a', 'a'],
      'rejected': [],
      'nextCursor': null,
    },
    {
      'acceptedIds': ['a'],
      'rejected': [
        {'id': 'a'},
      ],
      'nextCursor': null,
    },
    {
      'acceptedIds': ['a'],
      'nextCursor': null,
    },
  ]) {
    test('reject malformed or foreign acknowledgement $ack', () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((_) async => _ok(ack)),
      );
      await expectLater(
        api.uploadHealthBatch(SyncBatch(cursor: null, records: [_record('a')])),
        throwsA(isA<ApiException>()),
      );
    });
  }

  test(
    'ECG waveform, unknown timezone, bad quality and remote data remain queued',
    () async {
      var requests = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((_) async {
          requests++;
          return _ok({'acceptedIds': [], 'rejected': [], 'nextCursor': null});
        }),
      );
      final result = await api.uploadHealthBatch(
        SyncBatch(
          cursor: 'old',
          records: [
            _record('ecg', metric: HealthMetric.ecg, samples: [0.2, 0.5]),
            _record('timezone', timezone: 'Asia/Shanghai'),
            _record('bad-offset', timezone: '+14:01'),
            _record('quality', quality: 'good'),
            _record('remote', origin: MeasurementOrigin.remoteMember),
          ],
        ),
      );
      expect(requests, 0);
      expect(result.acceptedIds, isEmpty);
      expect(result.rejected, hasLength(5));
      expect(result.nextCursor, 'old');
    },
  );

  test(
    'unknown origin stays unknown and fractional-hour offset is preserved',
    () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((request) async {
          final row = (jsonDecode(request.body)['records'] as List).single;
          expect(row['source']['origin'], 'unknown');
          expect(row['timezoneOffsetMinutes'], 345);
          return _ok({
            'acceptedIds': ['a'],
            'rejected': [],
            'nextCursor': null,
          });
        }),
      );
      await api.uploadHealthBatch(
        SyncBatch(
          cursor: null,
          records: [
            _record('a', timezone: '+05:45', origin: MeasurementOrigin.unknown),
          ],
        ),
      );
    },
  );

  test('account switch rejects a late upload acknowledgement', () async {
    final vault = MemorySessionVault()..session = _session();
    final pending = Completer<http.Response>();
    final sent = Completer<void>();
    final api = GlobalSaydianApiClient(
      vault,
      client: MockClient((_) {
        sent.complete();
        return pending.future;
      }),
    );
    final result = api.uploadHealthBatch(
      SyncBatch(cursor: null, records: [_record('a')]),
    );
    await sent.future;
    vault.session = _session('b');
    pending.complete(
      _ok({
        'acceptedIds': ['a'],
        'rejected': [],
        'nextCursor': null,
      }),
    );
    await expectLater(
      result,
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'STALE_HEALTH_SESSION',
        ),
      ),
    );
  });

  test(
    'V2 warning settings retain all three thresholds and safe defaults',
    () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/global/api/saydian-app/v2/health/warning-rules',
          );
          return _ok([
            _rule('heart_rate', high: 133),
            _rule('blood_pressure', high: 146, secondary: 94),
            _rule('temperature', high: 38.2),
          ]);
        }),
      );
      final settings = (await api.getHealthWarningSettings())!;
      expect(settings.heartRateUpper, 133);
      expect(settings.systolicUpper, 146);
      expect(settings.diastolicUpper, 94);
      expect(settings.temperatureUpper, 38.2);
    },
  );

  test(
    'save preserves low thresholds and care choices, then verifies persisted values',
    () async {
      final old = [
        _rule('heart_rate', low: 50, shared: true),
        _rule('blood_glucose', high: 8.2, shared: true),
      ];
      List<Map<String, Object?>>? posted;
      var gets = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((request) async {
          if (request.method == 'GET') {
            gets++;
            return _ok(posted ?? old);
          }
          posted = (jsonDecode(request.body)['rules'] as List)
              .cast<Map>()
              .map((r) => Map<String, Object?>.from(r))
              .toList();
          expect(posted!.map((r) => r['metric']), [
            'heart_rate',
            'blood_pressure',
            'temperature',
          ]);
          expect(posted!.first['lowThreshold'], 50);
          expect(posted!.first['shareWithCare'], true);
          return _ok([]);
        }),
      );
      await api.saveHealthWarningSettings(
        const HealthWarningSettings(
          heartRateEnabled: true,
          heartRateUpper: 135,
          bloodPressureEnabled: true,
          systolicUpper: 149,
          diastolicUpper: 95,
          temperatureEnabled: true,
          temperatureUpper: 38.1,
        ),
      );
      expect(gets, 2);
      expect(posted![1]['secondaryHighThreshold'], 95);
      expect(posted![2]['highThreshold'], 38.1);
    },
  );

  test(
    'POST 200 without matching readback is not successful settings save',
    () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((_) async => _ok([])),
      );
      await expectLater(
        api.saveHealthWarningSettings(const HealthWarningSettings()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'HEALTH_SETTINGS_UNCONFIRMED',
          ),
        ),
      );
    },
  );

  test(
    'cloud warning events are read without inventing a device origin',
    () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/global/api/saydian-app/v2/health/warnings',
          );
          return _ok({
            'items': [
              {
                'eventId': 'warning-uuid',
                'metric': 'temperature',
                'observedAt': '2026-09-01T05:23:14Z',
                'source': 'user_threshold',
                'values': {'value': 38},
              },
            ],
          });
        }),
      );
      final warning = (await api.getHealthWarningAlerts()).single;
      expect(warning.id, 'warning-uuid');
      expect(warning.metric, HealthMetric.bodyTemperature);
      expect(warning.origin, MeasurementOrigin.unknown);
      expect(warning.triggeredAt, DateTime.utc(2026, 9, 1, 5, 23, 14));
    },
  );

  test('malformed warning list is an error, not a fake empty state', () async {
    final api = GlobalSaydianApiClient(
      MemorySessionVault()..session = _session(),
      client: MockClient((_) async => _ok({'items': 'bad'})),
    );
    await expectLater(
      api.getHealthWarningAlerts(),
      throwsA(isA<ApiException>()),
    );
  });
}
