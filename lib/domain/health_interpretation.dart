import 'models.dart';

class HealthInterpretation {
  const HealthInterpretation({required this.title, required this.detail});

  final String title;
  final String detail;
}

HealthInterpretation interpretHealthRecord(HealthRecord record) {
  final values = record.values;
  switch (record.metric) {
    case HealthMetric.bloodPressure:
      final high = values['systolic'];
      final low = values['diastolic'];
      if (high == null || low == null) return _insufficient;
      if (high >= 140 || low >= 90) {
        return const HealthInterpretation(
          title: '本次读数偏高',
          detail: '请静坐后再次测量；若多次偏高或伴有不适，请及时咨询专业医务人员。',
        );
      }
      if (high < 90 || low < 60) {
        return const HealthInterpretation(
          title: '本次读数偏低',
          detail: '请确认佩戴位置并静坐复测；如伴头晕、乏力等不适，请咨询专业医务人员。',
        );
      }
      return const HealthInterpretation(
        title: '本次读数处于常见参考范围',
        detail: '单次结果会受姿势、运动和情绪影响，建议在相同条件下持续观察趋势。',
      );
    case HealthMetric.heartRate:
      final value = values['value'];
      if (value == null) return _insufficient;
      if (value < 60 || value > 100) {
        return const HealthInterpretation(
          title: '本次静息心率超出常见参考范围',
          detail: '运动、情绪和药物等都会影响心率；静坐复测后仍异常或有不适时请咨询医务人员。',
        );
      }
      return const HealthInterpretation(
        title: '本次静息心率处于常见参考范围',
        detail: '建议结合个人长期趋势观察，不以单次结果作诊断。',
      );
    case HealthMetric.bloodOxygen:
      final value = values['value'];
      if (value == null) return _insufficient;
      return value >= 95
          ? const HealthInterpretation(
              title: '本次血氧处于常见参考范围',
              detail: '手指活动、佩戴松动和低温可能影响结果，请结合多次测量观察。',
            )
          : const HealthInterpretation(
              title: '本次血氧偏低',
              detail: '请保持静止并正确佩戴后复测；如持续偏低或伴呼吸不适，请及时就医。',
            );
    case HealthMetric.bodyTemperature:
      final value = values['value'];
      if (value == null) return _insufficient;
      return const HealthInterpretation(
        title: '已记录本次皮肤温度',
        detail: '皮肤温度会受环境、佩戴松紧和活动影响，适合与个人基线比较，不能作为核心体温或医用体温计读数。',
      );
    case HealthMetric.ecg:
      final riskSignals = [
        values['deviceAbnormalFlags'] ?? 0,
        values['diseaseRisk'] ?? 0,
        values['myocarditisRisk'] ?? 0,
        values['chdRisk'] ?? 0,
        values['angioscleroticRisk'] ?? 0,
      ];
      if (riskSignals.any((value) => value > 0)) {
        return const HealthInterpretation(
          title: '设备标记到需关注的心电特征',
          detail:
              '已结合戒指返回的节律及风险标记进行解读。该结果不是医学诊断；如反复出现或伴胸闷、心悸等不适，请携带完整波形咨询专业医务人员。',
        );
      }
      return const HealthInterpretation(
        title: '已生成本次心电趋势记录',
        detail: '平均心率、HRV、QT 间期和波形仅用于日常观察，不能替代医疗级心电图诊断。',
      );
    case HealthMetric.hrv:
      return const HealthInterpretation(
        title: 'HRV 更适合观察个人长期趋势',
        detail: '不同人的基线差异较大，请在相近时间和状态下比较，不以单次数值判断健康状况。',
      );
    case HealthMetric.stress:
      final value = values['value'];
      if (value == null) return _insufficient;
      final title = value <= 29
          ? '本次压力处于放松状态'
          : value <= 59
          ? '本次压力处于正常范围'
          : value <= 79
          ? '本次压力处于中等范围'
          : '本次压力偏高';
      return HealthInterpretation(
        title: title,
        detail: '该值由戒指基于 HRV 算法估算，适合观察个人趋势；运动、情绪和佩戴状态都可能影响结果。',
      );
    case HealthMetric.bodyComposition:
      return const HealthInterpretation(
        title: '身体成分测量完成',
        detail: '饮水、运动和电极接触会影响结果，建议在固定时段、相同条件下观察长期变化。',
      );
    case HealthMetric.bloodComposition:
      return const HealthInterpretation(
        title: '血液成分估算完成',
        detail: '戒指结果仅作趋势参考，不能替代医院采血化验；异常结果请以医疗机构检测为准。',
      );
    default:
      return const HealthInterpretation(
        title: '建议结合长期趋势观察',
        detail: '单次结果可能受佩戴、运动和环境影响，如有不适请咨询专业医务人员。',
      );
  }
}

const _insufficient = HealthInterpretation(
  title: '本次数据不足',
  detail: '请确认戒指正确佩戴后重新测量。',
);

String healthValueLabel(String key, HealthMetric metric) => switch (key) {
  'value' => metric.label,
  'deepHours' when metric == HealthMetric.sleep => '深睡时长',
  'lightHours' when metric == HealthMetric.sleep => '浅睡时长',
  'remHours' when metric == HealthMetric.sleep => '快速眼动时长',
  'awakeMinutes' when metric == HealthMetric.sleep => '清醒时长',
  'score' when metric == HealthMetric.sleep => '设备睡眠评分',
  'efficiency' when metric == HealthMetric.sleep => '睡眠效率',
  'systolic' => '收缩压',
  'diastolic' => '舒张压',
  'skinTemperature' => '皮肤温度',
  'meanHeartRate' || 'averageHeartRate' => '平均心率',
  'averageHRV' || 'hrv' => 'HRV',
  'averageTimeInterval' || 'qt' => 'QT 间期',
  'respiratoryRate' => '平均呼吸率',
  'sampleFrequency' => '采样频率',
  'deviceAbnormalFlags' => '设备异常标记数',
  'diseaseRisk' => '设备风险指数',
  'pressureIndex' => '压力指数',
  'fatigueIndex' => '疲劳指数',
  'myocarditisRisk' => '心肌风险指数',
  'chdRisk' => '冠心风险指数',
  'angioscleroticRisk' => '动脉硬化风险指数',
  'qrsTime' => 'QRS 时限',
  'qrsAmplitude' => 'QRS 振幅',
  'pulseWaveVelocity' => '脉搏波速度',
  'stAmplitude' => 'ST 振幅',
  'sdnn' => 'SDNN',
  'rmssd' => 'RMSSD',
  'bmi' || 'BMI' => 'BMI',
  'bodyFatRate' || 'bodyFatPercentage' => '体脂率',
  'fatMass' => '脂肪量',
  'fatFreeMass' => '去脂体重',
  'muscleRate' => '肌肉率',
  'muscleMass' => '肌肉量',
  'subcutaneousFat' => '皮下脂肪率',
  'bodyWaterRate' || 'bodyMoisture' => '体水分率',
  'waterMass' => '水分量',
  'skeletalMuscleRate' => '骨骼肌率',
  'boneMass' => '骨量',
  'proteinRate' => '蛋白质率',
  'proteinMass' => '蛋白质量',
  'basalMetabolicRate' || 'basalMetabolism' => '基础代谢',
  'uricAcid' => '尿酸',
  'totalCholesterol' => '总胆固醇',
  'triglycerides' => '甘油三酯',
  'highDensityLipoprotein' => '高密度脂蛋白',
  'lowDensityLipoprotein' => '低密度脂蛋白',
  _ => key,
};

String healthValueUnit(String key, HealthRecord record) => switch (key) {
  'deepHours' ||
  'lightHours' ||
  'remHours' when record.metric == HealthMetric.sleep => '小时',
  'awakeMinutes' when record.metric == HealthMetric.sleep => '分钟',
  'score' when record.metric == HealthMetric.sleep => '分',
  'efficiency' when record.metric == HealthMetric.sleep => '%',
  'meanHeartRate' || 'averageHeartRate' => 'bpm',
  'averageHRV' || 'hrv' || 'averageTimeInterval' || 'qt' => 'ms',
  'respiratoryRate' => '次/分',
  'sampleFrequency' => 'Hz',
  'deviceAbnormalFlags' ||
  'diseaseRisk' ||
  'pressureIndex' ||
  'fatigueIndex' ||
  'myocarditisRisk' ||
  'chdRisk' ||
  'angioscleroticRisk' ||
  'qrsAmplitude' ||
  'stAmplitude' ||
  'bmi' ||
  'BMI' => '',
  'qrsTime' || 'sdnn' || 'rmssd' => 'ms',
  'pulseWaveVelocity' => 'cm/s',
  'bodyFatRate' ||
  'bodyFatPercentage' ||
  'muscleRate' ||
  'subcutaneousFat' ||
  'bodyWaterRate' ||
  'bodyMoisture' ||
  'skeletalMuscleRate' ||
  'proteinRate' => '%',
  'fatMass' ||
  'fatFreeMass' ||
  'muscleMass' ||
  'waterMass' ||
  'boneMass' ||
  'proteinMass' => 'kg',
  'basalMetabolicRate' || 'basalMetabolism' => 'kcal/日',
  'uricAcid' => 'μmol/L',
  'totalCholesterol' ||
  'triglycerides' ||
  'highDensityLipoprotein' ||
  'lowDensityLipoprotein' => 'mmol/L',
  _ => record.unit,
};
