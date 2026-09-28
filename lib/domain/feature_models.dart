enum FeatureAvailabilityStatus {
  ready,
  needsDevice,
  needsPermission,
  unsupportedDevice,
  serviceUnavailable,
}

enum DeviceCapabilityState { disconnected, loading, ready, unavailable }

class FeatureAvailability {
  const FeatureAvailability(this.status, {this.detail});

  final FeatureAvailabilityStatus status;
  final String? detail;

  bool get isReady => status == FeatureAvailabilityStatus.ready;

  String get message =>
      detail ??
      switch (status) {
        FeatureAvailabilityStatus.ready => '可以使用',
        FeatureAvailabilityStatus.needsDevice => '连接戒指后使用',
        FeatureAvailabilityStatus.needsPermission => '允许相关权限后使用',
        FeatureAvailabilityStatus.unsupportedDevice => '当前戒指不支持此功能',
        FeatureAvailabilityStatus.serviceUnavailable => '当前戒指暂不支持在 App 中设置',
      };
}

enum DeviceFeature {
  watchFaces('watch_faces', '显示样式'),
  photoWatchFace('photo_watch_face', '照片显示'),
  findWatch('find_watch', '查找设备'),
  camera('camera', '摇一摇拍照'),
  phoneCalls('phone_calls', '电话'),
  contacts('contacts', '常用联系人'),
  notifications('notifications', '消息通知'),
  alarms('alarms', '闹钟'),
  weather('weather', '天气'),
  worldClock('world_clock', '世界时钟'),
  healthReminders('health_reminders', '健康提醒'),
  healthMonitoring('health_monitoring', '自动健康检测'),
  healthAssessment('health_assessment', '辅助评估'),
  screenDisplay('screen_display', '屏幕显示');

  const DeviceFeature(this.wireName, this.label);

  final String wireName;
  final String label;

  static DeviceFeature? tryFromWire(String value) {
    for (final feature in values) {
      if (feature.wireName == value) return feature;
    }
    return null;
  }
}

class DeviceScreenSettings {
  const DeviceScreenSettings({
    required this.brightness,
    required this.maximumBrightness,
    required this.automaticBrightness,
    this.brightnessSupported = true,
    this.durationSeconds,
    this.minimumDurationSeconds,
    this.maximumDurationSeconds,
    this.raiseToWakeEnabled = false,
    this.raiseToWakeSupported = false,
    this.raiseToWakeCustomTimeSupported = false,
    this.raiseToWakeStartMinutes = 0,
    this.raiseToWakeEndMinutes = 0,
    this.raiseToWakeSensitivity = 5,
  });

  final int brightness;
  final int maximumBrightness;
  final bool automaticBrightness;
  final bool brightnessSupported;
  final int? durationSeconds;
  final int? minimumDurationSeconds;
  final int? maximumDurationSeconds;
  final bool raiseToWakeEnabled;
  final bool raiseToWakeSupported;
  final bool raiseToWakeCustomTimeSupported;
  final int raiseToWakeStartMinutes;
  final int raiseToWakeEndMinutes;
  final int raiseToWakeSensitivity;

  factory DeviceScreenSettings.fromMap(Map<Object?, Object?> map) {
    final maximumBrightness = (map['maximumBrightness'] as num?)?.toInt() ?? 1;
    return DeviceScreenSettings(
      brightness: (map['brightness'] as num?)?.toInt() ?? 1,
      maximumBrightness: maximumBrightness,
      automaticBrightness: map['automaticBrightness'] == true,
      brightnessSupported: map.containsKey('brightnessSupported')
          ? map['brightnessSupported'] == true
          : maximumBrightness > 1,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      minimumDurationSeconds: (map['minimumDurationSeconds'] as num?)?.toInt(),
      maximumDurationSeconds: (map['maximumDurationSeconds'] as num?)?.toInt(),
      raiseToWakeEnabled: map['raiseToWakeEnabled'] == true,
      raiseToWakeSupported: map['raiseToWakeSupported'] == true,
      raiseToWakeCustomTimeSupported:
          map['raiseToWakeCustomTimeSupported'] == true,
      raiseToWakeStartMinutes:
          (map['raiseToWakeStartMinutes'] as num?)?.toInt() ?? 0,
      raiseToWakeEndMinutes:
          (map['raiseToWakeEndMinutes'] as num?)?.toInt() ?? 0,
      raiseToWakeSensitivity:
          (map['raiseToWakeSensitivity'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, Object?> toMap() => {
    'brightness': brightness,
    'maximumBrightness': maximumBrightness,
    'automaticBrightness': automaticBrightness,
    'brightnessSupported': brightnessSupported,
    'durationSeconds': durationSeconds,
    'minimumDurationSeconds': minimumDurationSeconds,
    'maximumDurationSeconds': maximumDurationSeconds,
    'raiseToWakeEnabled': raiseToWakeEnabled,
    'raiseToWakeSupported': raiseToWakeSupported,
    'raiseToWakeCustomTimeSupported': raiseToWakeCustomTimeSupported,
    'raiseToWakeStartMinutes': raiseToWakeStartMinutes,
    'raiseToWakeEndMinutes': raiseToWakeEndMinutes,
    'raiseToWakeSensitivity': raiseToWakeSensitivity,
  };

  DeviceScreenSettings copyWith({
    int? brightness,
    int? maximumBrightness,
    bool? automaticBrightness,
    bool? brightnessSupported,
    int? durationSeconds,
    int? minimumDurationSeconds,
    int? maximumDurationSeconds,
    bool? raiseToWakeEnabled,
    bool? raiseToWakeSupported,
    bool? raiseToWakeCustomTimeSupported,
    int? raiseToWakeStartMinutes,
    int? raiseToWakeEndMinutes,
    int? raiseToWakeSensitivity,
  }) => DeviceScreenSettings(
    brightness: brightness ?? this.brightness,
    maximumBrightness: maximumBrightness ?? this.maximumBrightness,
    automaticBrightness: automaticBrightness ?? this.automaticBrightness,
    brightnessSupported: brightnessSupported ?? this.brightnessSupported,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    minimumDurationSeconds:
        minimumDurationSeconds ?? this.minimumDurationSeconds,
    maximumDurationSeconds:
        maximumDurationSeconds ?? this.maximumDurationSeconds,
    raiseToWakeEnabled: raiseToWakeEnabled ?? this.raiseToWakeEnabled,
    raiseToWakeSupported: raiseToWakeSupported ?? this.raiseToWakeSupported,
    raiseToWakeCustomTimeSupported:
        raiseToWakeCustomTimeSupported ?? this.raiseToWakeCustomTimeSupported,
    raiseToWakeStartMinutes:
        raiseToWakeStartMinutes ?? this.raiseToWakeStartMinutes,
    raiseToWakeEndMinutes: raiseToWakeEndMinutes ?? this.raiseToWakeEndMinutes,
    raiseToWakeSensitivity:
        raiseToWakeSensitivity ?? this.raiseToWakeSensitivity,
  );
}

class DeviceAlarm {
  const DeviceAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.enabled,
    this.label = '闹钟',
    this.repeatDays = const <int>{},
  });

  final String id;
  final int hour;
  final int minute;
  final bool enabled;
  final String label;
  final Set<int> repeatDays;
}

class DeviceContact {
  const DeviceContact({
    required this.id,
    required this.name,
    required this.phone,
    this.isEmergency = false,
  });

  final String id;
  final String name;
  final String phone;
  final bool isEmergency;
}

class DeviceNotificationSettings {
  const DeviceNotificationSettings({
    this.incomingCall = false,
    this.sms = false,
    this.wechat = false,
    this.otherApps = false,
  });

  final bool incomingCall;
  final bool sms;
  final bool wechat;
  final bool otherApps;
}

class DeviceWeatherSettings {
  const DeviceWeatherSettings({
    this.enabled = false,
    this.city,
    this.useCelsius = true,
  });

  final bool enabled;
  final String? city;
  final bool useCelsius;
}

class DeviceWorldClock {
  const DeviceWorldClock({
    required this.id,
    required this.city,
    required this.utcOffsetMinutes,
  });

  final String id;
  final String city;
  final int utcOffsetMinutes;
}

class DeviceHealthReminder {
  const DeviceHealthReminder({
    required this.id,
    required this.label,
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.intervalMinutes,
  });

  final String id;
  final String label;
  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  final int intervalMinutes;
}
