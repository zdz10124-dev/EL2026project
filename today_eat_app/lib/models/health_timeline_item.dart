import 'exercise_record.dart';
import 'meal_record.dart';

enum HealthTimelineKind { meal, exercise }

class HealthTimelineItem {
  const HealthTimelineItem._({
    required this.kind,
    required this.occurredAt,
    this.meal,
    this.exercise,
  });

  factory HealthTimelineItem.meal(MealRecord record) => HealthTimelineItem._(
        kind: HealthTimelineKind.meal,
        occurredAt: record.createdAt,
        meal: record,
      );

  factory HealthTimelineItem.exercise(ExerciseRecord record) =>
      HealthTimelineItem._(
        kind: HealthTimelineKind.exercise,
        occurredAt: record.startedAt,
        exercise: record,
      );

  final HealthTimelineKind kind;
  final DateTime occurredAt;
  final MealRecord? meal;
  final ExerciseRecord? exercise;
}
