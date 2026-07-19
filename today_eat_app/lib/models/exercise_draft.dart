import 'exercise_record.dart';

class ExerciseDraft {
  const ExerciseDraft({
    required this.activityType,
    required this.startedAt,
    required this.durationSeconds,
    this.distanceMeters,
    this.averageHeartRateBpm,
    this.peakHeartRateBpm,
    this.caloriesKcal,
    this.rpe,
    this.note,
    this.detail = const {},
    this.imagePaths = const [],
    this.source = ExerciseSource.manual,
  });

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

  factory ExerciseDraft.empty([ActivityType type = ActivityType.running]) =>
      ExerciseDraft(
        activityType: type,
        startedAt: DateTime.now(),
        durationSeconds: 0,
      );

  ExerciseDraft copyWith({
    ActivityType? activityType,
    DateTime? startedAt,
    int? durationSeconds,
    int? distanceMeters,
    int? averageHeartRateBpm,
    int? peakHeartRateBpm,
    int? caloriesKcal,
    int? rpe,
    String? note,
    Map<String, Object?>? detail,
    List<String>? imagePaths,
    ExerciseSource? source,
  }) =>
      ExerciseDraft(
        activityType: activityType ?? this.activityType,
        startedAt: startedAt ?? this.startedAt,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        averageHeartRateBpm: averageHeartRateBpm ?? this.averageHeartRateBpm,
        peakHeartRateBpm: peakHeartRateBpm ?? this.peakHeartRateBpm,
        caloriesKcal: caloriesKcal ?? this.caloriesKcal,
        rpe: rpe ?? this.rpe,
        note: note ?? this.note,
        detail: detail ?? this.detail,
        imagePaths: imagePaths ?? this.imagePaths,
        source: source ?? this.source,
      );
}
