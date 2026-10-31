import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/device_history_sync.dart';
import 'package:saydian_app/domain/wearable_sync_result.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final morning = DateTime(2026, 10, 31, 8);
  final checkpoint = DeviceHistorySyncCheckpoint(
    signature: 'caps-v1',
    fullAt: morning,
    latestAt: morning,
  );

  test(
    'only same-day confirmed history with current capabilities can be shortened',
    () {
      expect(
        checkpoint.permitsRecent(
          morning.add(const Duration(hours: 2)),
          'caps-v1',
        ),
        isTrue,
      );
      expect(
        checkpoint.permitsRecent(
          morning.subtract(const Duration(seconds: 1)),
          'caps-v1',
        ),
        isFalse,
      );
      expect(checkpoint.permitsRecent(morning, 'caps-v2'), isFalse);
      expect(
        checkpoint.permitsRecent(
          morning.add(const Duration(hours: 18)),
          'caps-v1',
        ),
        isFalse,
      );
      expect(
        checkpoint.permitsRecent(DateTime(2026, 11, 1), 'caps-v1'),
        isFalse,
      );
      expect(
        checkpoint.recentlyCompleted(
          morning.add(const Duration(seconds: 89)),
          'caps-v1',
        ),
        isTrue,
      );
      expect(
        checkpoint.recentlyCompleted(
          morning.add(const Duration(seconds: 90)),
          'caps-v1',
        ),
        isFalse,
      );
      expect(
        DeviceHistorySyncCheckpoint.parse(checkpoint.toJson())!.fullAt,
        morning.toUtc(),
      );
      expect(
        DeviceHistorySyncCheckpoint.parse({'version': 1, 'fullAt': 'null'}),
        isNull,
      );
      expect(
        DeviceHistorySyncCheckpoint(
          signature: 'caps-v1',
          fullAt: morning,
          latestAt: morning.subtract(const Duration(minutes: 1)),
        ).permitsRecent(morning, 'caps-v1'),
        isFalse,
      );
    },
  );

  test(
    'checkpoints remain scoped to stored owner and exact device; invalidation persists',
    () async {
      final store = MemoryHealthStore();
      await store.switchOwner('owner-a');
      await store.writeDeviceHistorySync('qring:r22', 'confirmed');
      expect(await store.readDeviceHistorySync('qring:other'), isNull);
      await store.switchOwner('owner-b');
      expect(await store.readDeviceHistorySync('qring:r22'), isNull);
      await store.switchOwner('owner-a');
      expect(await store.readDeviceHistorySync('qring:r22'), 'confirmed');
      await store.writeDeviceHistorySync('qring:r22', 'null');
      expect(await store.readDeviceHistorySync('qring:r22'), 'null');
    },
  );

  test(
    'Android requests explicit days, preserving partial evidence; iOS remains full history',
    () async {
      const channel = MethodChannel('test/qring-history');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {
              'records': [],
              'statuses': {'steps': 'complete', 'sleep': 'failed'},
              'historyDays': 2,
            };
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final bridge = QRingWearableBridge(methods: channel);
      final result =
          await bridge.syncRecentHealthData(days: 2) as WearableSyncResult;
      expect(calls.single.arguments, {'historyDays': 2});
      expect(result.historyDays, 2);
      expect(result.complete, isFalse);
      expect(result.partial, isTrue);
      expect(() => bridge.syncRecentHealthData(days: 0), throwsArgumentError);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(bridge.supportsRecentHistorySync, isFalse);
      expect(() => bridge.syncRecentHealthData(days: 2), throwsArgumentError);
      await bridge.syncHealthData();
      expect(calls.last.arguments, isNull);
    },
  );
}
