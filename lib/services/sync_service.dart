import '../domain/models.dart';
import '../domain/health_record_validation.dart';
import 'api_client.dart';
import 'local_health_store.dart';

class SyncOutcome {
  const SyncOutcome({
    required this.uploaded,
    required this.rejected,
    this.message,
  });

  final int uploaded;
  final int rejected;
  final String? message;
}

class HealthSyncService {
  const HealthSyncService(this._store, this._api);

  final HealthStore _store;
  final SaydianApi _api;

  Future<SyncOutcome> synchronizeNow() async {
    var uploaded = 0;
    var rejected = 0;
    var quarantined = 0;
    while (true) {
      // ECG records contain a calibrated waveform and can be much larger than
      // ordinary health rows. Keep cloud batches small so reading an old
      // offline queue never delays a freshly completed manual measurement for
      // tens of seconds. Uploads still continue until the queue is empty.
      final pending = await _store.pending(limit: 10);
      if (pending.isEmpty) {
        return SyncOutcome(
          uploaded: uploaded,
          rejected: rejected,
          message: quarantined == 0 ? null : '已隔离 $quarantined 条无效设备数据',
        );
      }
      final invalid = pending
          .where((record) => !hasSaneWearableTransportValues(record))
          .toList();
      if (invalid.isNotEmpty) {
        await _store.markInvalid(invalid.map((record) => record.id));
        quarantined += invalid.length;
        rejected += invalid.length;
      }
      final records = pending.where(hasSaneWearableTransportValues).toList();
      if (records.isEmpty) continue;
      final cursor = await _store.readCursor();
      try {
        final result = await _api.uploadHealthBatch(
          SyncBatch(cursor: cursor, records: records),
        );
        await _store.markSynced(result.acceptedIds);
        if (result.nextCursor != null) {
          await _store.writeCursor(result.nextCursor!);
        }
        uploaded += result.acceptedIds.length;
        rejected += result.rejected.length;
        if (result.acceptedIds.isEmpty) {
          return SyncOutcome(
            uploaded: uploaded,
            rejected: rejected,
            message: '服务器未接收任何记录，已保留本地队列',
          );
        }
      } on FeatureNotConfiguredException catch (error) {
        return SyncOutcome(
          uploaded: uploaded,
          rejected: rejected,
          message: error.message,
        );
      }
    }
  }
}
