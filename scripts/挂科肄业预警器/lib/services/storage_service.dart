import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 本地存储服务
/// 使用 SharedPreferences 存储普通数据
/// 使用 FlutterSecureStorage 存储敏感数据（如 token、密码）
class StorageService {
  late SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========== SharedPreferences 方法（普通数据） ==========

  /// 保存字符串
  Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  /// 获取字符串
  String? getString(String key) {
    return _prefs.getString(key);
  }

  /// 保存布尔值
  Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  /// 获取布尔值
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  /// 保存整数
  Future<bool> setInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  /// 获取整数
  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  /// 保存 double
  Future<bool> setDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }

  /// 获取 double
  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  /// 保存 JSON 对象
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    return await _prefs.setString(key, jsonEncode(value));
  }

  /// 获取 JSON 对象
  Map<String, dynamic>? getJson(String key) {
    final str = _prefs.getString(key);
    if (str == null) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('StorageService: JSON 解析失败: $e');
      return null;
    }
  }

  /// 保存 JSON 列表
  Future<bool> setJsonList(String key, List<Map<String, dynamic>> value) async {
    return await _prefs.setString(key, jsonEncode(value));
  }

  /// 获取 JSON 列表
  List<Map<String, dynamic>>? getJsonList(String key) {
    final str = _prefs.getString(key);
    if (str == null) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('StorageService: JSON 列表解析失败: $e');
      return null;
    }
  }

  /// 删除键
  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  /// 清除所有数据
  Future<bool> clear() async {
    return await _prefs.clear();
  }

  // ========== FlutterSecureStorage 方法（敏感数据） ==========

  /// 安全保存（用于 token、密码等）
  Future<void> setSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// 安全读取
  Future<String?> getSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// 删除安全存储的键
  Future<void> removeSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  /// 清除所有安全存储
  Future<void> clearSecure() async {
    await _secureStorage.deleteAll();
  }
}
