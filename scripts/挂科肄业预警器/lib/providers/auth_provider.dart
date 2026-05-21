import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

/// 认证状态
enum AuthStatus {
  uninitialized, // 未初始化
  authenticated, // 已认证
  unauthenticated, // 未认证
}

/// 认证状态管理
class AuthProvider extends ChangeNotifier {
  final StorageService _storageService;

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel _user = UserModel.empty();
  String? _errorMessage;
  bool _isLoading = false;

  AuthProvider(this._storageService) {
    _loadUser();
  }

  // Getters
  AuthStatus get status => _status;
  UserModel get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// 从本地存储加载用户信息
  Future<void> _loadUser() async {
    try {
      final userData = _storageService.getJson('user_data');
      if (userData != null) {
        _user = UserModel.fromJson(userData);
        _status = _user.isLoggedIn
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      debugPrint('AuthProvider: 加载用户信息失败: $e');
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// 登录
  Future<bool> login(String studentId, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // TODO: 对接南大信息库进行实际登录验证
      // 当前为模拟登录
      await Future.delayed(const Duration(seconds: 1));

      if (studentId.isEmpty || password.isEmpty) {
        _errorMessage = '学号和密码不能为空';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 模拟登录成功
      _user = UserModel(
        id: studentId,
        studentId: studentId,
        name: '测试用户',
        major: '计算机科学与技术',
        grade: '2024',
        department: '计算机学院',
        isLoggedIn: true,
      );

      // 保存用户信息到本地
      await _storageService.setJson('user_data', _user.toJson());
      // 安全存储 token（模拟）
      await _storageService.setSecure(
          'auth_token', 'mock_token_${DateTime.now().millisecondsSinceEpoch}');

      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '登录失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.remove('user_data');
      await _storageService.removeSecure('auth_token');
      _user = UserModel.empty();
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      debugPrint('AuthProvider: 退出登录失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
