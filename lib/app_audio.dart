import 'package:flutter/services.dart';

class AppAudio {
  AppAudio._();

  static const MethodChannel _channel = MethodChannel(
    'com.dressfit.dressfit_app/app_audio',
  );

  static Future<void> playStartup() => _safeInvoke('playStartupSound');

  static Future<void> playEffect(String effect) =>
      _safeInvoke('playEffect', {'effect': effect});

  static Future<Map<String, dynamic>> settings() async {
    try {
      final value = await _channel.invokeMapMethod<String, dynamic>(
        'getAudioSettings',
      );
      return value ?? const {};
    } catch (_) {
      return const {};
    }
  }

  static Future<void> setSetting(String key, Object value) =>
      _safeInvoke('setAudioSetting', {'key': key, 'value': value});

  static Future<void> _safeInvoke(
    String method, [
    Map<String, Object>? arguments,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (_) {
      // Sound feedback must never block a user action.
    }
  }
}
