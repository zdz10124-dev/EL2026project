// 对外接口：
// - RecommendationApiService.searchRecommendations
// - RecommendationApiService.fetchRecommendationDetail
// - RecommendationApiService.uploadRecord

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/meal_record.dart';
import '../models/recommendation_models.dart';
import 'upload_image_compressor.dart';

class RecommendationApiException implements Exception {
  const RecommendationApiException(this.message, {this.shouldRetry = true});

  final String message;
  final bool shouldRetry;

  @override
  String toString() => message;
}

class RecommendationUploadResult {
  const RecommendationUploadResult({
    required this.remoteId,
    required this.updatedAt,
  });

  final String remoteId;
  final DateTime updatedAt;
}

class RecommendationApiService {
  RecommendationApiService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://api.whateattoday.xyz');

  final http.Client _client;
  final Uri _baseUri;
  final UploadImageCompressor _imageCompressor = UploadImageCompressor();

  /// [对外接口] 请求联网推荐列表。
  Future<RecommendationSearchPage> searchRecommendations(
    RecommendationQuery query,
  ) async {
    final response = await _client
        .post(
          _baseUri.resolve('/v1/recommendations/search'),
          headers: {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(query.toJson()),
        )
        .timeout(const Duration(seconds: 12));

    final body = _decodeJson(response.body);
    _throwIfFailed(response.statusCode, body);

    return RecommendationSearchPage.fromMap(
      (body['data'] as Map<String, dynamic>? ?? const {}).cast<String, Object?>(),
    );
  }

  /// [对外接口] 请求联网推荐详情。
  Future<RecommendationDetail> fetchRecommendationDetail(String id) async {
    final response = await _client
        .get(_baseUri.resolve('/v1/recommendations/$id'))
        .timeout(const Duration(seconds: 12));

    final body = _decodeJson(response.body);
    _throwIfFailed(response.statusCode, body);

    return RecommendationDetail.fromMap(
      (body['data'] as Map<String, dynamic>? ?? const {}).cast<String, Object?>(),
    );
  }

  /// [对外接口] 上传一条本地记录到联网推荐服务。
  Future<RecommendationUploadResult> uploadRecord(MealRecord record) async {
    final request = http.MultipartRequest(
      'POST',
      _baseUri.resolve('/v1/recommendations/upload-record'),
    );
    request.fields.addAll({
      'client_record_id': record.clientRecordId,
      'created_at': record.createdAt.toIso8601String(),
      'updated_at': record.updatedAt.toIso8601String(),
      'dish_name': record.dishName,
      'location_text': record.location,
      'price': record.price?.toString() ?? '',
      'rating_score': record.ratingScore?.toString() ?? '',
      'comment': record.comment ?? '',
      'province': record.province ?? '',
      'city': record.city ?? '',
      'district': record.district ?? '',
      'latitude': record.latitude?.toString() ?? '',
      'longitude': record.longitude?.toString() ?? '',
    });

    final imageFile = File(record.imagePath);
    if (await imageFile.exists()) {
      final compressed = await _imageCompressor.compressForRecommendationUpload(
        imageFile.path,
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          compressed.bytes,
          filename: compressed.filename.isNotEmpty
              ? compressed.filename
              : p.basename(imageFile.path),
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 25));
    final response = await http.Response.fromStream(streamed);
    final body = _decodeJson(response.body);
    _throwIfFailed(response.statusCode, body);

    final data = (body['data'] as Map<String, dynamic>? ?? const {})
        .cast<String, Object?>();
    return RecommendationUploadResult(
      remoteId: data['remote_id'] as String? ?? '',
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> _decodeJson(String source) {
    if (source.trim().isEmpty) {
      return const {'success': false, 'message': '服务器返回了空响应'};
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return {
        'success': false,
        'message': source.trim(),
      };
    }
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const RecommendationApiException('服务器返回格式错误');
  }

  void _throwIfFailed(int statusCode, Map<String, dynamic> body) {
    final success = body['success'] == true;
    if (statusCode >= 200 && statusCode < 300 && success) {
      return;
    }
    final message = body['message'] as String? ?? '网络请求失败';
    throw RecommendationApiException(
      message,
      shouldRetry: statusCode >= 500 || statusCode == 0,
    );
  }
}
