import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recommendation_models.dart';
import '../models/user_profile.dart';

class AppSettingsService {
  static const String _publicRecordsKey = 'public_records_enabled';
  static const String _autoUploadKey = 'auto_upload_records_enabled';
  static const String _appStyleKey = 'app_style_id';
  static const String _diaryStyleKey = 'diary_style_id';
  static const String _recommendationClientIdKey = 'recommendation_client_id';
  static const String _recommendationDistanceKey =
      'recommendation_distance_bucket';
  static const String _displayNameKey = 'user_display_name';
  static const String _avatarEmojiKey = 'user_avatar_emoji';

  Future<bool> getAutoUploadRecordsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.containsKey(_autoUploadKey)) {
      return preferences.getBool(_autoUploadKey) ?? true;
    }
    if (preferences.containsKey(_publicRecordsKey)) {
      return preferences.getBool(_publicRecordsKey) ?? true;
    }
    return true;
  }

  Future<void> setAutoUploadRecordsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoUploadKey, value);
    await preferences.setBool(_publicRecordsKey, value);
  }

  Future<bool> getPublicRecordsEnabled() => getAutoUploadRecordsEnabled();

  Future<void> setPublicRecordsEnabled(bool value) =>
      setAutoUploadRecordsEnabled(value);

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

  Future<RecommendationDistanceBucket?> getRecommendationDistanceBucket() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_recommendationDistanceKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final bucket in RecommendationDistanceBucket.values) {
      if (bucket.apiValue == value) {
        return bucket;
      }
    }
    return null;
  }

  Future<void> setRecommendationDistanceBucket(
    RecommendationDistanceBucket? bucket,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    if (bucket == null) {
      await preferences.remove(_recommendationDistanceKey);
      return;
    }
    await preferences.setString(_recommendationDistanceKey, bucket.apiValue);
  }

  Future<UserProfile> getUserProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final savedName = preferences.getString(_displayNameKey)?.trim() ?? '';
    final savedAvatar = preferences.getString(_avatarEmojiKey)?.trim() ?? '';
    final displayName = savedName.isNotEmpty
        ? savedName
        : _buildAnonymousDisplayName(DateTime.now());
    final avatarEmoji = savedAvatar.isNotEmpty
        ? savedAvatar
        : UserProfile.defaultAvatar;
    if (savedName.isEmpty) {
      await preferences.setString(_displayNameKey, displayName);
    }
    if (savedAvatar.isEmpty) {
      await preferences.setString(_avatarEmojiKey, avatarEmoji);
    }
    return UserProfile(
      displayName: displayName,
      avatarEmoji: avatarEmoji,
    );
  }

  Future<void> setUserProfile(UserProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    final trimmedName = profile.displayName.trim();
    final trimmedAvatar = profile.avatarEmoji.trim();
    await preferences.setString(
      _displayNameKey,
      trimmedName.isNotEmpty
          ? trimmedName
          : _buildAnonymousDisplayName(DateTime.now()),
    );
    await preferences.setString(
      _avatarEmojiKey,
      trimmedAvatar.isNotEmpty ? trimmedAvatar : UserProfile.defaultAvatar,
    );
  }

  String _buildAnonymousDisplayName(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${time.year}'
        '${twoDigits(time.month)}'
        '${twoDigits(time.day)}'
        '${twoDigits(time.hour)}'
        '${twoDigits(time.minute)}'
        '${twoDigits(time.second)}';
    return '匿名用户$timestamp';
  }
}
