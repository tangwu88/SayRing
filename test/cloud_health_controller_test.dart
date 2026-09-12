import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'controller pulls every cloud page and keeps imports out of upload queue',
    () async {
      final store = MemoryHealthStore();
      await store.initialize();
      await store.switchOwner('global:member:owner-a');
      final api = _CloudApi();
      final controller =
          AppController(
              MemorySessionVault(),
              api,
              store,
              _Wearable(),
              allowAutomaticWearableRestore: false,
            )
            ..session = Session(
              accessToken: 'test-access',
              refreshToken: 'test-refresh',
              expiresAt: DateTime.utc(2030),
              memberId: 'owner-a',
              displayName: 'Owner A',
              accountKey: 'global:member:owner-a',
            );
      addTearDown(controller.dispose);

      await controller.synchronizeCloud();

      expect(api.requestedBefore, [null, 'older-page']);
      expect((await store.recent()).map((record) => record.id), [
        'cloud-heart',
        'cloud-oxygen',
      ]);
      expect(await store.pending(), isEmpty);
      expect(controller.healthRecords.map((record) => record.id), [
        'cloud-heart',
        'cloud-oxygen',
      ]);
    },
  );
}

HealthRecord _record(
  String id,
  HealthMetric metric,
  DateTime measuredAt,
) => HealthRecord(
  id: id,
  metric: metric,
  values: {'value': metric == HealthMetric.heartRate ? 72 : 98},
  unit: metric.defaultUnit,
  measuredAt: measuredAt,
  timezone: '+00:00',
  deviceId:
      'server:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  firmwareVersion: '1.0',
  quality: 'valid',
  source: MeasurementSource.wearable,
  rawVersion: 1,
  sourceVendor: 'yucheng',
  sourceDeviceCategory: 'ring',
  sourceApp: 'say-ring',
);

class _CloudApi extends Fake implements SaydianApi, CloudHealthRecordReader {
  final List<String?> requestedBefore = [];

  @override
  Future<CloudHealthPage> getCloudHealthRecords({
    int limit = 200,
    String? before,
  }) async {
    requestedBefore.add(before);
    return before == null
        ? CloudHealthPage(
            records: [
              _record(
                'cloud-heart',
                HealthMetric.heartRate,
                DateTime.utc(2026, 9, 13, 1),
              ),
            ],
            nextCursor: 'older-page',
          )
        : CloudHealthPage(
            records: [
              _record(
                'cloud-oxygen',
                HealthMetric.bloodOxygen,
                DateTime.utc(2026, 9, 12, 1),
              ),
            ],
            nextCursor: null,
          );
  }
}

class _Wearable extends Fake implements WearableBridge {}
