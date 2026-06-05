import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _publicRecordsKey = 'public_records_enabled';
  static const String _appStyleKey = 'app_style_id';
  static const String _diaryStyleKey = 'diary_style_id';
  static const String _recommendationClientIdKey = 'recommendation_client_id';

  Future<bool> getPublicRecordsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_publicRecordsKey) ?? false;
  }

  Future<void> setPublicRecordsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_publicRecordsKey, value);
  }

  Future<String?> getAppStyleId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_appStyleKey);
  }

  Future<void> setAppStyleId(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_appStyleKey, value);
  }

  Future<String?> getDiaryStyleId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_diaryStyleKey);
  }

  Future<void> setDiaryStyleId(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_diaryStyleKey, value);
  }

  Future<String> getRecommendationClientId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_recommendationClientIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random();
    final created = 'client_${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1 << 32)}';
    await preferences.setString(_recommendationClientIdKey, created);
    return created;
  }
}
