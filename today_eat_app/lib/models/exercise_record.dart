import 'dart:convert';

enum ActivityType { running, swimming, cycling, walking, other }

enum ExerciseSource { manual, aiImage }

extension ActivityTypeX on ActivityType {
  String get label => switch (this) {
        ActivityType.running => '跑步',
        ActivityType.swimming => '游泳',
        ActivityType.cycling => '骑行',
        ActivityType.walking => '步行',
        ActivityType.other => '其他',
      };

  static ActivityType fromValue(String? value) => ActivityType.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ActivityType.other,
      );
}

class ExerciseRecord {
  const ExerciseRecord({
    this.id,
    required this.clientRecordId,
    required this.activityType,
    required this.startedAt,
    required this.durationSeconds,
    required this.imagePaths,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.distanceMeters,
    this.averageHeartRateBpm,
    this.peakHeartRateBpm,
    this.caloriesKcal,
    this.rpe,
    this.note,
    this.detail = const {},
  });

  final int? id;
  final String clientRecordId;
  final ActivityType activityType;
  final DateTime startedAt;
  final int durationSeconds;
  final int? distanceMeters;
  final int? averageHeartRateBpm;
  final int? peakHeartRateBpm;
  final int? caloriesKcal;
  final int? rpe;
  final String? note;
  final Map<String, Object?> detail;
  final List<String> imagePaths;
  final ExerciseSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExerciseRecord copyWith({
    int? id,
    String? clientRecordId,
    ActivityType? activityType,
    DateTime? startedAt,
    int? durationSeconds,
    int? distanceMeters,
    bool clearDistance = false,
    int? averageHeartRateBpm,
    bool clearAverageHeartRate = false,
    int? peakHeartRateBpm,
    bool clearPeakHeartRate = false,
    int? caloriesKcal,
    bool clearCalories = false,
    int? rpe,
    bool clearRpe = false,
    String? note,
    bool clearNote = false,
    Map<String, Object?>? detail,
    List<String>? imagePaths,
    ExerciseSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExerciseRecord(
      id: id ?? this.id,
      clientRecordId: clientRecordId ?? this.clientRecordId,
      activityType: activityType ?? this.activityType,
      startedAt: startedAt ?? this.startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: clearDistance ? null : distanceMeters ?? this.distanceMeters,
      averageHeartRateBpm: clearAverageHeartRate
          ? null
          : averageHeartRateBpm ?? this.averageHeartRateBpm,
      peakHeartRateBpm:
          clearPeakHeartRate ? null : peakHeartRateBpm ?? this.peakHeartRateBpm,
      caloriesKcal: clearCalories ? null : caloriesKcal ?? this.caloriesKcal,
      rpe: clearRpe ? null : rpe ?? this.rpe,
      note: clearNote ? null : note ?? this.note,
      detail: detail ?? this.detail,
      imagePaths: imagePaths ?? this.imagePaths,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'client_record_id': clientRecordId,
        'activity_type': activityType.name,
        'started_at': startedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'average_heart_rate_bpm': averageHeartRateBpm,
        'peak_heart_rate_bpm': peakHeartRateBpm,
        'calories_kcal': caloriesKcal,
        'rpe': rpe,
        'note': note,
        'detail_json': jsonEncode(detail),
        'image_paths_json': jsonEncode(imagePaths),
        'source': source.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ExerciseRecord.fromMap(Map<String, Object?> map) {
    final detailValue = jsonDecode(map['detail_json'] as String? ?? '{}');
    final pathsValue = jsonDecode(map['image_paths_json'] as String? ?? '[]');
    return ExerciseRecord(
      id: map['id'] as int?,
      clientRecordId: map['client_record_id'] as String,
      activityType: ActivityTypeX.fromValue(map['activity_type'] as String?),
      startedAt: DateTime.parse(map['started_at'] as String),
      durationSeconds: (map['duration_seconds'] as num).toInt(),
      distanceMeters: (map['distance_meters'] as num?)?.toInt(),
      averageHeartRateBpm:
          (map['average_heart_rate_bpm'] as num?)?.toInt(),
      peakHeartRateBpm: (map['peak_heart_rate_bpm'] as num?)?.toInt(),
      caloriesKcal: (map['calories_kcal'] as num?)?.toInt(),
      rpe: (map['rpe'] as num?)?.toInt(),
      note: map['note'] as String?,
      detail: detailValue is Map
          ? detailValue.map((key, value) => MapEntry(key.toString(), value))
          : const {},
      imagePaths:
          pathsValue is List ? pathsValue.map((e) => e.toString()).toList() : const [],
      source: ExerciseSource.values.firstWhere(
        (item) => item.name == map['source'],
        orElse: () => ExerciseSource.manual,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
