import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_profile.dart';

class HealthProfileRepository {
  HealthProfileRepository({Future<void> Function()? onHealthDataChanged})
    : _onHealthDataChanged = onHealthDataChanged;

  static const _key = 'health_profile_v1';
  final Future<void> Function()? _onHealthDataChanged;

  Future<HealthProfile> load() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_key);
    if (source == null || source.isEmpty) return const HealthProfile();
    try {
      return HealthProfile.fromJson(
        (jsonDecode(source) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return const HealthProfile();
    }
  }

  Future<void> save(HealthProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(profile.toJson()));
    final callback = _onHealthDataChanged;
    if (callback != null) unawaited(callback());
  }
}
