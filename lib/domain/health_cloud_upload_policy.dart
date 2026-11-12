import 'models.dart';
import 'wellness_release_policy.dart';

/// 仅用于账号云同步，不作为设备能力、页面展示或手动测量的授权。
/// 2026-11-04 用户确认：已登录账号统一自动上传真实生理记录，无额外开关。
class HealthCloudUploadPolicy extends WellnessReleasePolicy {
  const HealthCloudUploadPolicy({this.preserveActivityPayload = false})
    : super(enabled: true);

  // Android previously uploaded complete activity/sleep values. Preserve that
  // payload so retrying a lost ACK cannot conflict with the same stored ID.
  // Existing restricted iOS projection remains the default.
  final bool preserveActivityPayload;

  static const physiologicalMetrics = <HealthMetric>{
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
    HealthMetric.bloodPressure,
    HealthMetric.hrv,
    HealthMetric.bodyTemperature,
  };

  @override
  Set<HealthMetric> get allowedMetrics => const {
    ...WellnessReleasePolicy.activitySleepMetrics,
    ...physiologicalMetrics,
  };

  @override
  Map<String, num> projectValues(HealthMetric metric, Map<String, num> values) {
    // 生理记录保留原单位下的真实值及质量依据。尤其不能只留下血压 value
    // 而丢失收缩压/舒张压，也不能丢失 CoolWear HRV 校验需要的 SDNN/质量字段。
    if (preserveActivityPayload || physiologicalMetrics.contains(metric)) {
      return Map.unmodifiable(values);
    }
    return super.projectValues(metric, values);
  }

  @override
  HealthRecord? projectRecord(HealthRecord record) {
    if (!allowsMetric(record.metric)) return null;
    // 不去掉非空原始波形：上传层必须拒绝并保留该行，不能丢波形后假记成功。
    if (record.samples.isNotEmpty) return record;
    if (preserveActivityPayload ||
        physiologicalMetrics.contains(record.metric)) {
      return record;
    }
    return super.projectRecord(record);
  }
}
