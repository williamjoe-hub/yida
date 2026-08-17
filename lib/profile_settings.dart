import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum UserGender {
  male('男生'),
  female('女生');

  final String label;
  const UserGender(this.label);
}

class UserProfile {
  final String displayName;
  final UserGender gender;
  final bool onboardingComplete;
  final String? email;

  const UserProfile({
    required this.displayName,
    required this.gender,
    required this.onboardingComplete,
    this.email,
  });
}

class ProfileSettings {
  ProfileSettings._();

  static Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/profile_settings.json');
  }

  static Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _write(Map<String, dynamic> patch) async {
    final file = await _file();
    final value = await _read();
    value.addAll(patch);
    await file.writeAsString(jsonEncode(value));
  }

  static Future<UserProfile> loadProfile() async {
    final json = await _read();
    final gender = UserGender.values.firstWhere(
      (value) => value.name == json['gender'],
      orElse: () => UserGender.male,
    );
    return UserProfile(
      displayName: (json['displayName'] as String? ?? '').trim(),
      gender: gender,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      email: json['email'] as String?,
    );
  }

  static Future<UserGender> loadGender() async {
    try {
      final json = await _read();
      return UserGender.values.firstWhere(
        (value) => value.name == json['gender'],
        orElse: () => UserGender.male,
      );
    } catch (_) {
      return UserGender.male;
    }
  }

  static Future<void> saveGender(UserGender gender) async {
    await _write({'gender': gender.name});
  }

  static Future<void> completeOnboarding({
    required String displayName,
    required UserGender gender,
  }) async {
    await _write({
      'displayName': displayName.trim(),
      'gender': gender.name,
      'onboardingComplete': true,
    });
  }

  static Future<void> saveDisplayName(String displayName) async {
    await _write({'displayName': displayName.trim()});
  }
}
