// 对外接口：
// - AppSettingsService.getPublicRecordsEnabled
// - AppSettingsService.setPublicRecordsEnabled

import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _publicRecordsKey = 'public_records_enabled';

  /// [对外接口] 读取“是否公开记录”开关。
  Future<bool> getPublicRecordsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_publicRecordsKey) ?? false;
  }

  /// [对外接口] 持久化“是否公开记录”开关。
  Future<void> setPublicRecordsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_publicRecordsKey, value);
  }
}
