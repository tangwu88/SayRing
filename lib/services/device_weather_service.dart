import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'safe_resource_client.dart';

class DeviceWeatherException implements Exception {
  const DeviceWeatherException(
    this.message, {
    this.openSettings = false,
    this.locationSettings = false,
  });

  final String message;
  final bool openSettings;
  final bool locationSettings;

  @override
  String toString() => message;
}

class DeviceWeatherForecast {
  const DeviceWeatherForecast({
    required this.city,
    required this.updatedAt,
    required this.hourly,
    required this.daily,
  });

  final String city;
  final DateTime updatedAt;
  final List<Map<String, Object?>> hourly;
  final List<Map<String, Object?>> daily;

  Map<String, Object?> toFeatureValues({required bool useCelsius}) => {
    'operation': 'sync',
    'enabled': true,
    'useCelsius': useCelsius,
    'city': city,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'hourly': hourly,
    'daily': daily,
  };
}

/// Loads the same QWeather forecast used by the supplied mini-program.
///
/// The client key stays outside source control and is supplied at build time:
/// `--dart-define=QWEATHER_API_KEY=...`.
class DeviceWeatherService {
  DeviceWeatherService({http.Client? client})
    : _client = SafeResourceClient(
        inner: client,
        purpose: ResourcePurpose.weather,
      );

  final http.Client _client;

  static const _apiKey = String.fromEnvironment('QWEATHER_API_KEY');
  static const _apiHost = String.fromEnvironment(
    'QWEATHER_API_HOST',
    defaultValue: 'https://ny2tuqge5v.re.qweatherapi.com',
  );

  Future<DeviceWeatherForecast> loadCurrentLocation() async {
    if (_apiKey.isEmpty) {
      throw const DeviceWeatherException('天气服务暂时无法使用，请稍后再试');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceWeatherException(
        '请先开启手机定位，再更新天气',
        openSettings: true,
        locationSettings: true,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw DeviceWeatherException(
        '允许位置权限后使用',
        openSettings: permission == LocationPermission.deniedForever,
      );
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.medium,
                forceLocationManager: true,
                timeLimit: Duration(seconds: 20),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 20),
              ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) {
      throw const DeviceWeatherException('暂时无法获取当前位置，请稍后重试');
    }

    return _loadForecast('${position.longitude},${position.latitude}');
  }

  Future<DeviceWeatherForecast> loadCity(String city) async {
    final value = city.trim();
    if (value.isEmpty) {
      throw const DeviceWeatherException('请输入城市名称');
    }
    if (_apiKey.isEmpty) {
      throw const DeviceWeatherException('天气服务暂时无法使用，请稍后再试');
    }
    return _loadForecast(value);
  }

  Future<DeviceWeatherForecast> _loadForecast(String location) async {
    final locationData = await _get('/geo/v2/city/lookup', {
      'location': location,
    });
    final locationItems = locationData['location'];
    if (locationItems is! List || locationItems.isEmpty) {
      throw const DeviceWeatherException('未找到该城市，请检查后重试');
    }
    final locationItem = locationItems.first;
    final city = _cityLabel(locationItem);
    final locationId = locationItem is Map
        ? '${locationItem['id'] ?? ''}'.trim()
        : '';
    if (locationId.isEmpty) {
      throw const DeviceWeatherException('天气数据暂时不可用，请稍后重试');
    }
    final responses = await Future.wait([
      _get('/v7/weather/24h', {'location': locationId}),
      _get('/v7/weather/7d', {'location': locationId}),
    ]);
    final hourlyData = responses[0];
    final dailyData = responses[1];

    final hourly = _list(hourlyData['hourly']).take(24).map((item) {
      final time = DateTime.tryParse('${item['fxTime'] ?? ''}');
      final tempC = _integer(item['temp']);
      return <String, Object?>{
        'time': (time ?? DateTime.now()).millisecondsSinceEpoch,
        'temperatureC': tempC,
        'weatherCode': _watchWeatherCode('${item['text'] ?? ''}'),
        'uvIndex': 0,
        'windLevel': _windLevel(item['windScale']),
        'visibilityMeters': _visibilityMeters(item['vis']),
      };
    }).toList();
    final daily = _list(dailyData['daily']).take(7).map((item) {
      final date = DateTime.tryParse('${item['fxDate'] ?? ''}');
      return <String, Object?>{
        'time': (date ?? DateTime.now()).millisecondsSinceEpoch,
        'maximumC': _integer(item['tempMax']),
        'minimumC': _integer(item['tempMin']),
        'dayWeatherCode': _watchWeatherCode('${item['textDay'] ?? ''}'),
        'nightWeatherCode': _watchWeatherCode('${item['textNight'] ?? ''}'),
        'uvIndex': _integer(item['uvIndex']).clamp(0, 15),
        'windLevel': _windLevel(item['windScaleDay']),
        'visibilityMeters': _visibilityMeters(item['vis']),
      };
    }).toList();
    if (hourly.isEmpty || daily.isEmpty) {
      throw const DeviceWeatherException('天气数据暂时不可用，请稍后重试');
    }
    return DeviceWeatherForecast(
      city: city,
      updatedAt: DateTime.now(),
      hourly: hourly,
      daily: daily,
    );
  }

  Future<Map<String, Object?>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final base = Uri.parse(_apiHost);
    final uri = base.replace(
      path: path,
      queryParameters: {...query, 'key': _apiKey},
    );
    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const DeviceWeatherException('网络不可用，请检查后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DeviceWeatherException('天气服务暂时无法使用，请稍后再试');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || '${decoded['code'] ?? ''}' != '200') {
      throw const DeviceWeatherException('天气服务暂时无法使用，请稍后再试');
    }
    return decoded.map((key, value) => MapEntry('$key', value));
  }

  static List<Map<String, Object?>> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  static String _cityLabel(Object? value) {
    if (value is! Map) return '当前位置';
    final district = '${value['name'] ?? ''}'.trim();
    final city = '${value['adm2'] ?? ''}'.trim();
    if (city.isEmpty) return district.isEmpty ? '当前位置' : district;
    if (district.isEmpty || district == city) return city;
    return '$city$district';
  }

  static int _integer(Object? value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;

  static int _visibilityMeters(Object? value) {
    final kilometres = value is num
        ? value.toDouble()
        : double.tryParse('$value');
    return ((kilometres ?? 5) * 1000).round().clamp(0, 100000).toInt();
  }

  static String _windLevel(Object? value) {
    final text = '${value ?? '0'}'.trim();
    return text.isEmpty ? '0' : text.replaceAll('级', '');
  }

  static int _watchWeatherCode(String value) {
    if (value.contains('雷')) return 21;
    if (value.contains('冰雹')) return 25;
    if (value.contains('暴雨') || value.contains('大暴雨')) return 65;
    if (value.contains('大雨')) return 50;
    if (value.contains('中雨')) return 42;
    if (value.contains('阵雨')) return 17;
    if (value.contains('小雨') || value.contains('毛毛雨')) return 33;
    if (value.contains('暴雪') || value.contains('大雪')) return 90;
    if (value.contains('中雪')) return 85;
    if (value.contains('小雪') || value.contains('雨夹雪')) return 73;
    if (value.contains('多云')) return 120;
    if (value.contains('阴') || value.contains('雾') || value.contains('霾')) {
      return 13;
    }
    if (value.contains('晴')) return 3;
    return 120;
  }
}
