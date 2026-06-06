import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/meal_record.dart';
import '../models/recommendation_comment.dart';
import '../models/recommendation_models.dart';
import '../models/user_profile.dart';
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

class RecommendationModerationResult {
  const RecommendationModerationResult({required this.feedback});

  final RecommendationFeedbackSummary feedback;
}

class RecommendationVisibilityResult {
  const RecommendationVisibilityResult({
    required this.recordId,
    required this.active,
  });

  final String recordId;
  final bool active;
}

class RecommendationApiService {
  RecommendationApiService({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        _baseUri = baseUri ?? Uri.parse('https://api.whateattoday.xyz');

  final http.Client _client;
  final Uri _baseUri;
  final UploadImageCompressor _imageCompressor = UploadImageCompressor();

  Future<RecommendationSearchPage> searchRecommendations(
    RecommendationQuery query,
    String clientId,
  ) async {
    final response = await _client
        .post(
          _baseUri.resolve('/v1/recommendations/search'),
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'x-client-id': clientId,
          },
          body: jsonEncode(query.toJson()),
        )
        .timeout(const Duration(seconds: 12));

    final body = _decodeJsonBytes(response.bodyBytes);
    _throwIfFailed(response.statusCode, body);

    return RecommendationSearchPage.fromMap(
      (body['data'] as Map<String, dynamic>? ?? const {}).cast<String, Object?>(),
    );
  }

  Future<RecommendationDetail> fetchRecommendationDetail(
    String id,
    String clientId,
  ) async {
    final response = await _client
        .get(
          _baseUri.resolve('/v1/recommendations/$id'),
          headers: {'x-client-id': clientId},
        )
        .timeout(const Duration(seconds: 12));

    final body = _decodeJsonBytes(response.bodyBytes);
    _throwIfFailed(response.statusCode, body);

    return RecommendationDetail.fromMap(
      (body['data'] as Map<String, dynamic>? ?? const {}).cast<String, Object?>(),
    );
  }

  Future<RecommendationUploadResult> uploadRecord({
    required MealRecord record,
    required String clientId,
    required UserProfile profile,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _baseUri.resolve('/v1/recommendations/upload-record'),
    );
    request.headers['x-client-id'] = clientId;
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
      'uploader_name': profile.displayName,
      'uploader_avatar': profile.avatarEmoji,
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
    final body = _decodeJsonBytes(response.bodyBytes);
    _throwIfFailed(response.statusCode, body);

    final data = (body['data'] as Map<String, dynamic>? ?? const {})
        .cast<String, Object?>();
    return RecommendationUploadResult(
      remoteId: data['remote_id'] as String? ?? '',
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Future<RecommendationVisibilityResult> setRecommendationVisibility({
    required String recommendationId,
    required bool active,
    required String clientId,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('/v1/recommendations/$recommendationId/visibility'),
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'x-client-id': clientId,
          },
          body: jsonEncode({'active': active}),
        )
        .timeout(const Duration(seconds: 12));

    final body = _decodeJsonBytes(response.bodyBytes);
    _throwIfFailed(response.statusCode, body);
    final data = (body['data'] as Map<String, dynamic>? ?? const {})
        .cast<String, Object?>();
    return RecommendationVisibilityResult(
      recordId: data['record_id'] as String? ?? recommendationId,
      active: data['active'] == true,
    );
  }

  Future<RecommendationComment> createComment({
    required String recommendationId,
    required String content,
    required String clientId,
    required UserProfile profile,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('/v1/recommendations/$recommendationId/comments'),
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'x-client-id': clientId,
          },
          body: jsonEncode({
            'content': content,
            'author_name': profile.displayName,
            'author_avatar': profile.avatarEmoji,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final body = _decodeJsonBytes(response.bodyBytes);
    _throwIfFailed(response.statusCode, body);
    return RecommendationComment.fromMap(
      (body['data'] as Map<String, dynamic>? ?? const {}).cast<String, Object?>(),
    );
  }

  Future<RecommendationModerationResult> submitVote({
    required String recommendationId,
    required String action,
    required String clientId,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('/v1/recommendations/$recommendationId/vote'),
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'x-client-id': clientId,
          },
          body: jsonEncode({'action': action}),
        )
        .timeout(const Duration(seconds: 12));

    final body = _decodeJsonBytes(response.bodyBytes);
    _throwIfFailed(response.statusCode, body);

    final data = (body['data'] as Map<String, dynamic>? ?? const {})
        .cast<String, Object?>();
    return RecommendationModerationResult(
      feedback: RecommendationFeedbackSummary.fromMap(
        data['feedback'] as Map<String, Object?>? ?? const {},
      ),
    );
  }

  Future<RecommendationModerationResult> submitReport({
    required String recommendationId,
    required String clientId,
    String? reason,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('/v1/recommendations/$recommendationId/report'),
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'x-client-id': clientId,
          },
          body: jsonEncode({'reason': reason}),
        )
        .timeout(const Duration(seconds: 12));

    final body = _decodeJsonBytes(response.bodyBytes);
    _throwIfFailed(response.statusCode, body);

    final data = (body['data'] as Map<String, dynamic>? ?? const {})
        .cast<String, Object?>();
    return RecommendationModerationResult(
      feedback: RecommendationFeedbackSummary.fromMap(
        data['feedback'] as Map<String, Object?>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> _decodeJson(String source) {
    if (source.trim().isEmpty) {
      return const {'success': false, 'message': '服务端返回了空响应'};
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
    throw const RecommendationApiException('服务端返回格式错误');
  }

  Map<String, dynamic> _decodeJsonBytes(List<int> bytes) {
    return _decodeJson(utf8.decode(bytes, allowMalformed: true));
  }

  void _throwIfFailed(int statusCode, Map<String, dynamic> body) {
    final success = body['success'] == true;
    if (statusCode >= 200 && statusCode < 300 && success) {
      return;
    }
    final message = body['message'] as String? ??
        body['detail'] as String? ??
        '网络请求失败';
    throw RecommendationApiException(
      message,
      shouldRetry: statusCode >= 500 || statusCode == 0,
    );
  }
}
