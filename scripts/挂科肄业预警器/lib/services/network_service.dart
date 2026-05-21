import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// 网络请求服务
/// 封装 Dio 用于与后端 API 通信
class NetworkService {
  late final Dio _dio;
  final StorageService _storageService;
  final String _baseUrl;

  NetworkService({
    required StorageService storageService,
    String baseUrl = 'https://api.example.com',
  })  : _storageService = storageService,
        _baseUrl = baseUrl {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 添加拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 自动添加 token
          final token = await _storageService.getSecure('auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          debugPrint('[Network] ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('[Network] 响应: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('[Network] 错误: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  /// GET 请求
  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParams);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// POST 请求
  Future<ApiResponse> post(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// PUT 请求
  Future<ApiResponse> put(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// DELETE 请求
  Future<ApiResponse> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// 处理错误
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时，请稍后重试';
      case DioExceptionType.receiveTimeout:
        return '接收超时，请稍后重试';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) return '登录已过期，请重新登录';
        if (statusCode == 403) return '没有权限访问';
        if (statusCode == 404) return '请求的资源不存在';
        if (statusCode == 500) return '服务器内部错误';
        return '请求失败 ($statusCode)';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '网络异常，请检查网络连接';
    }
  }
}

/// API 统一响应封装
class ApiResponse {
  final bool isSuccess;
  final dynamic data;
  final String? errorMessage;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
  });

  factory ApiResponse.success(dynamic data) {
    return ApiResponse._(isSuccess: true, data: data);
  }

  factory ApiResponse.error(String message) {
    return ApiResponse._(isSuccess: false, errorMessage: message);
  }
}
