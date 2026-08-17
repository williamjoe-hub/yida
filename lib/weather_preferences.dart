import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class WeatherPreferences {
  WeatherPreferences._();

  static Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/weather_preferences.json');
  }

  static Future<bool> loadConsent() async {
    try {
      final file = await _file();
      if (!await file.exists()) return false;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json['consent'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveConsent(bool value) async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'consent': value}));
  }
}
