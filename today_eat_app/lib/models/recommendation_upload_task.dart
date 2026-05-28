// 对外接口：
// - RecommendationUploadTask
// - RecommendationUploadTaskStatus

enum RecommendationUploadTaskStatus { pending, failed, invalid, synced }

extension RecommendationUploadTaskStatusX on RecommendationUploadTaskStatus {
  String get dbValue {
    switch (this) {
      case RecommendationUploadTaskStatus.pending:
        return 'pending';
      case RecommendationUploadTaskStatus.failed:
        return 'failed';
      case RecommendationUploadTaskStatus.invalid:
        return 'invalid';
      case RecommendationUploadTaskStatus.synced:
        return 'synced';
    }
  }

  static RecommendationUploadTaskStatus fromDb(String? value) {
    switch (value) {
      case 'failed':
        return RecommendationUploadTaskStatus.failed;
      case 'invalid':
        return RecommendationUploadTaskStatus.invalid;
      case 'synced':
        return RecommendationUploadTaskStatus.synced;
      default:
        return RecommendationUploadTaskStatus.pending;
    }
  }
}

class RecommendationUploadTask {
  const RecommendationUploadTask({
    required this.clientRecordId,
    required this.recordId,
    required this.recordUpdatedAt,
    required this.status,
    required this.attemptCount,
    required this.updatedAt,
    this.lastError,
  });

  final String clientRecordId;
  final int recordId;
  final DateTime recordUpdatedAt;
  final RecommendationUploadTaskStatus status;
  final int attemptCount;
  final DateTime updatedAt;
  final String? lastError;

  Map<String, Object?> toMap() {
    return {
      'client_record_id': clientRecordId,
      'record_id': recordId,
      'record_updated_at': recordUpdatedAt.toIso8601String(),
      'status': status.dbValue,
      'attempt_count': attemptCount,
      'last_error': lastError,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory RecommendationUploadTask.fromMap(Map<String, Object?> map) {
    return RecommendationUploadTask(
      clientRecordId: map['client_record_id'] as String? ?? '',
      recordId: (map['record_id'] as num?)?.toInt() ?? 0,
      recordUpdatedAt: DateTime.parse(
        map['record_updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      status: RecommendationUploadTaskStatusX.fromDb(map['status'] as String?),
      attemptCount: (map['attempt_count'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.parse(
        map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      lastError: map['last_error'] as String?,
    );
  }
}
