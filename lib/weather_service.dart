import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherSnapshot {
  final double temperature;
  final double apparentTemperature;
  final int weatherCode;
  final bool isDay;
  final int rainProbability;

  const WeatherSnapshot({
    required this.temperature,
    required this.apparentTemperature,
    required this.weatherCode,
    required this.isDay,
    required this.rainProbability,
  });

  String get condition {
    if (weatherCode == 0) return '晴';
    if (weatherCode <= 3) return '多云';
    if (weatherCode == 45 || weatherCode == 48) return '雾';
    if ((weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82)) {
      return '雨';
    }
    if ((weatherCode >= 71 && weatherCode <= 77) ||
        (weatherCode >= 85 && weatherCode <= 86)) {
      return '雪';
    }
    if (weatherCode >= 95) return '雷雨';
    return '阴';
  }

  bool get isRainy =>
      (weatherCode >= 51 && weatherCode <= 67) ||
      (weatherCode >= 80 && weatherCode <= 82) ||
      weatherCode >= 95;

  bool get rainExpected => isRainy || rainProbability >= 40;

  String get shortAdvice {
    if (rainExpected) return '记得带伞，适合防水外层和耐脏鞋款';
    if (temperature >= 30) return '适合轻薄透气的浅色穿搭';
    if (temperature <= 10) return '适合针织与保暖外套叠穿';
    if (temperature <= 18) return '适合薄外套和舒适长裤';
    return '适合清爽舒适的日常穿搭';
  }

  String get fullAdvice {
    final degrees = temperature.round();
    if (rainExpected) {
      return '当前位置 $degrees°C，$condition，今天最高降雨概率 $rainProbability%。建议选择防水外层、较短裤脚和耐脏鞋款，随身带伞。';
    }
    if (temperature >= 30) {
      return '当前位置 $degrees°C，$condition。轻薄棉质或亚麻上衣更透气，浅色系也能减少闷热感。';
    }
    if (temperature <= 10) {
      return '当前位置 $degrees°C，$condition。建议针织内层搭配保暖外套，并选择包裹性更好的鞋款。';
    }
    if (temperature <= 18) {
      return '当前位置 $degrees°C，$condition。薄外套、长裤和可以灵活增减的层次最适合今天。';
    }
    return '当前位置 $degrees°C，$condition。舒适上衣配合轻松下装即可，早晚可以准备一件薄外套。';
  }
}

class WeatherService {
  WeatherService._();

  static Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<WeatherSnapshot> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const WeatherException('请打开手机定位服务');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const WeatherException('允许定位后显示当地天气');
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    final position =
        lastKnown ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        );
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      // City-level precision is enough for weather and avoids sending an exact position.
      'latitude': position.latitude.toStringAsFixed(1),
      'longitude': position.longitude.toStringAsFixed(1),
      'current': 'temperature_2m,apparent_temperature,weather_code,is_day',
      'daily': 'precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '1',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const WeatherException('天气服务暂时不可用');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>?;
    final daily = data['daily'] as Map<String, dynamic>?;
    if (current == null) throw const WeatherException('天气数据格式异常');
    return WeatherSnapshot(
      temperature: (current['temperature_2m'] as num).toDouble(),
      apparentTemperature: (current['apparent_temperature'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      isDay: (current['is_day'] as num).toInt() == 1,
      rainProbability:
          ((daily?['precipitation_probability_max'] as List<dynamic>?)?.first
                  as num?)
              ?.toInt() ??
          0,
    );
  }
}

class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);
  @override
  String toString() => message;
}
