import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'generated/app_localizations.dart';

extension LocalizedModelLabels on AppLocalizations {
  String sportModeName(SportMode mode) => switch (mode) {
    SportMode.running => running,
    SportMode.indoorRunning => indoorRunning,
    SportMode.walking => walking,
    SportMode.cycling => cycling,
    SportMode.indoorCycling => indoorCycling,
    SportMode.basketball => basketball,
    SportMode.football => football,
    SportMode.badminton => badminton,
    SportMode.swimming => swimming,
    SportMode.jumpRope => jumpRope,
    SportMode.yoga => yoga,
    SportMode.hiking => hiking,
    SportMode.mountaineering => mountaineering,
  };
  String metricName(HealthMetric metric) => switch (metric) {
    HealthMetric.steps => steps,
    HealthMetric.distance => distance,
    HealthMetric.calories => calories,
    HealthMetric.sleep => sleep,
    HealthMetric.heartRate => heartRate,
    HealthMetric.bloodOxygen => bloodOxygen,
    HealthMetric.bloodPressure => bloodPressure,
    HealthMetric.bloodGlucose => bloodGlucose,
    HealthMetric.bodyTemperature => bodyTemperature,
    HealthMetric.ecg => ecg,
    HealthMetric.hrv => hrv,
    HealthMetric.stress => stress,
    HealthMetric.bodyComposition => bodyComposition,
    HealthMetric.bloodComposition => bloodComposition,
  };

  String deviceFeatureName(DeviceFeature feature) => switch (feature) {
    DeviceFeature.watchFaces => watchFaces,
    DeviceFeature.photoWatchFace => photoWatchFace,
    DeviceFeature.findWatch => findWatch,
    DeviceFeature.camera => cameraRemote,
    DeviceFeature.gestureControl =>
      localeName.startsWith('zh') ? '手势控制' : 'Gesture control',
    DeviceFeature.callReminder =>
      localeName.startsWith('zh') ? '来电提醒' : 'Call reminder',
    DeviceFeature.phoneCalls => phoneCalls,
    DeviceFeature.contacts => contacts,
    DeviceFeature.notifications => notifications,
    DeviceFeature.alarms => alarms,
    DeviceFeature.weather => weather,
    DeviceFeature.worldClock => worldClock,
    DeviceFeature.healthReminders => healthReminders,
    DeviceFeature.healthMonitoring => healthMonitoring,
    DeviceFeature.healthAssessment => healthAssessment,
    DeviceFeature.screenDisplay => screenDisplay,
  };

  String connectionState(DeviceConnectionState state) => switch (state) {
    DeviceConnectionState.disconnected => notConnected,
    DeviceConnectionState.scanning => scanning,
    DeviceConnectionState.connecting => connecting,
    DeviceConnectionState.authenticating => waitingConfirmation,
    DeviceConnectionState.syncing => syncing,
    DeviceConnectionState.ready => connected,
    DeviceConnectionState.measuring => measuring,
    DeviceConnectionState.error => needsAttention,
  };
}
