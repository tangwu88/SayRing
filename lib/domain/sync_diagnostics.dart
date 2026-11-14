import 'dart:convert';

enum SyncDiagnosticStage {
  connect,
  initialization,
  capabilities,
  read,
  persist,
  upload,
  recover,
}

enum SyncDiagnosticState { pending, ok, partial, failed, blocked, empty }

enum SyncDiagnosticCode {
  none('none'),
  unknown('unknown'),
  notConnected('not_connected'),
  connectionLost('connection_lost'),
  connectFailed('connect_failed'),
  initializationPending('initialization_pending'),
  decisionUnknown('decision_unknown'),
  clearRequested('clear_requested'),
  clearAcknowledged('clear_acknowledged'),
  capabilitiesMissing('capabilities_missing'),
  readTimeout('read_timeout'),
  readPartial('read_partial'),
  noData('no_data'),
  saveFailed('save_failed'),
  uploadFailed('upload_failed'),
  uploadRejected('upload_rejected'),
  unsupportedMetric('unsupported_metric'),
  recordConflict('record_conflict'),
  invalidRecord('invalid_record'),
  networkError('network_error'),
  authExpired('auth_expired'),
  backendUnavailable('backend_unavailable'),
  busy('busy'),
  cancelled('cancelled');

  const SyncDiagnosticCode(this.wireName);
  final String wireName;
}

const syncDiagnosticModelNames = {
  'R7Pro',
  'R7Ultra',
  'R7',
  'R7p',
  'R8',
  'R8Pro',
  'R21',
  'R22',
  'HR01',
  'HR05',
  'K80',
  'U19',
  'U19S',
  'U19M',
  'other',
  'unknown',
};
const syncDiagnosticMetricNames = {
  'heart_rate',
  'blood_oxygen',
  'body_temperature',
  'hrv',
  'stress',
  'sleep',
  'steps',
  'distance',
  'calories',
  'blood_pressure',
  'ecg',
  'blood_glucose',
};

/// Only fixed enums and bounded counters cross the diagnostics boundary.
/// Never pass SDK maps, exception text, device identifiers or health records.
class SyncDiagnosticEvent {
  const SyncDiagnosticEvent(
    this.stage,
    this.state,
    this.code,
    this.elapsedMs, {
    this.received,
    this.saved,
    this.uploaded,
    this.rejected,
  });
  final SyncDiagnosticStage stage;
  final SyncDiagnosticState state;
  final SyncDiagnosticCode code;
  final int elapsedMs;
  final int? received, saved, uploaded, rejected;
  Map<String, Object?> toJson() => {
    'stage': stage.name,
    'state': state.name,
    'code': code.wireName,
    'elapsedMs': elapsedMs.clamp(0, 3600000),
    if (received != null) 'received': received!.clamp(0, 1000000),
    if (saved != null) 'saved': saved!.clamp(0, 1000000),
    if (uploaded != null) 'uploaded': uploaded!.clamp(0, 1000000),
    if (rejected != null) 'rejected': rejected!.clamp(0, 1000000),
  };
}

Map<String, Object?> diagnosticDeviceSnapshot({
  required String platform,
  required String sdk,
  required String? model,
  String? firmware,
  required String connectionState,
  required String initializationState,
  required String capabilityState,
  required Iterable<String> metrics,
}) => {
  'platform': const {'android', 'ios', 'harmonyos'}.contains(platform)
      ? platform
      : 'android',
  'sdk': const {'coolwear', 'qring', 'yucheng', 'veepoo', 'urion'}.contains(sdk)
      ? sdk
      : 'unknown',
  'model': syncDiagnosticModelNames.contains(model) ? model : 'other',
  if (firmware != null && RegExp(r'^\d[\d.]{0,31}$').hasMatch(firmware))
    'firmware': firmware,
  'connectionState':
      const {
        'disconnected',
        'scanning',
        'connecting',
        'authenticating',
        'syncing',
        'ready',
        'error',
      }.contains(connectionState)
      ? connectionState
      : 'disconnected',
  'initializationState':
      const {
        'ready',
        'decision_required',
        'decision_unknown',
        'reset_attempted',
        'history_clear_acknowledged',
        'native_pending',
        'unavailable',
      }.contains(initializationState)
      ? initializationState
      : 'unavailable',
  'capabilityState':
      const {
        'disconnected',
        'loading',
        'ready',
        'unavailable',
      }.contains(capabilityState)
      ? capabilityState
      : 'unavailable',
  'metrics': (metrics.where(syncDiagnosticMetricNames.contains).toSet().toList()
    ..sort()),
};

bool isBoundedDiagnosticReport(Map<String, Object?> report) {
  const keys = {
    'schemaVersion',
    'product',
    'reportId',
    'connectionId',
    'mode',
    'platform',
    'appVersion',
    'buildNumber',
    'sdk',
    'model',
    'firmware',
    'osMajor',
    'connectionState',
    'initializationState',
    'capabilityState',
    'metrics',
    'stages',
  };
  if (report.keys.any((k) => !keys.contains(k))) return false;
  if (utf8.encode(jsonEncode(report)).length > 4096) return false;
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  bool count(Object? v, int max) => v is int && v >= 0 && v <= max;
  if (report['schemaVersion'] != 1 ||
      report['product'] != 'say-ring' ||
      !uuid.hasMatch('${report['reportId']}') ||
      !uuid.hasMatch('${report['connectionId']}') ||
      !const {'automatic', 'manual', 'recovery'}.contains(report['mode']) ||
      !const {'android', 'ios', 'harmonyos'}.contains(report['platform']) ||
      !RegExp(
        r'^\d{1,4}\.\d{1,4}\.\d{1,4}$',
      ).hasMatch('${report['appVersion']}') ||
      !count(report['buildNumber'], 2147483647) ||
      !const {
        'coolwear',
        'qring',
        'yucheng',
        'veepoo',
        'urion',
        'unknown',
      }.contains(report['sdk']) ||
      !syncDiagnosticModelNames.contains(report['model']) ||
      !const {
        'disconnected',
        'scanning',
        'connecting',
        'authenticating',
        'syncing',
        'ready',
        'error',
      }.contains(report['connectionState']) ||
      !const {
        'ready',
        'decision_required',
        'decision_unknown',
        'reset_attempted',
        'history_clear_acknowledged',
        'native_pending',
        'unavailable',
      }.contains(report['initializationState']) ||
      !const {
        'disconnected',
        'loading',
        'ready',
        'unavailable',
      }.contains(report['capabilityState']) ||
      (report.containsKey('firmware') &&
          !RegExp(r'^\d[\d.]{0,31}$').hasMatch('${report['firmware']}')) ||
      (report.containsKey('osMajor') && !count(report['osMajor'], 100))) {
    return false;
  }
  final metrics = report['metrics'], rows = report['stages'];
  return metrics is List &&
      metrics.length <= syncDiagnosticMetricNames.length &&
      metrics.every(syncDiagnosticMetricNames.contains) &&
      rows is List &&
      rows.length <= 16 &&
      rows.every(
        (s) =>
            s is Map &&
            s.keys.every(
              (k) => const {
                'stage',
                'state',
                'code',
                'elapsedMs',
                'received',
                'saved',
                'uploaded',
                'rejected',
              }.contains(k),
            ) &&
            SyncDiagnosticStage.values.any((v) => v.name == s['stage']) &&
            SyncDiagnosticState.values.any((v) => v.name == s['state']) &&
            SyncDiagnosticCode.values.any((v) => v.wireName == s['code']) &&
            count(s['elapsedMs'], 3600000) &&
            const [
              'received',
              'saved',
              'uploaded',
              'rejected',
            ].every((k) => !s.containsKey(k) || count(s[k], 1000000)),
      );
}
