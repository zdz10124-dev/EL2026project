import 'exercise_record.dart';
import 'health_metrics.dart';
import 'health_profile.dart';
import 'recovery_check_in.dart';

class AgentFeedbackSummary {
  const AgentFeedbackSummary({
    required this.completed,
    required this.skipped,
    required this.tooHard,
  });

  static const empty = AgentFeedbackSummary(
    completed: 0,
    skipped: 0,
    tooHard: 0,
  );

  final int completed;
  final int skipped;
  final int tooHard;

  Map<String, int> toJson() => {
        'completed': completed,
        'skipped': skipped,
        'too_hard': tooHard,
      };
}

class HealthContext {
  const HealthContext({
    required this.date,
    required this.profile,
    required this.todayMealCount,
    required this.todayExerciseMinutes,
    required this.sevenDayMetrics,
    required this.recovery,
    required this.feedback,
    required this.allowedEvidence,
    required this.missingInputs,
    this.lastExercise,
  });

  final DateTime date;
  final HealthProfile profile;
  final int todayMealCount;
  final int todayExerciseMinutes;
  final HealthMetrics sevenDayMetrics;
  final RecoveryCheckIn? recovery;
  final AgentFeedbackSummary feedback;
  final List<String> allowedEvidence;
  final List<String> missingInputs;
  final ExerciseRecord? lastExercise;

  bool get canGenerateAiPlan => missingInputs.isEmpty;

  Map<String, Object?> toPromptJson() => {
        'date': _dateKey(date),
        'profile': _profileJson(),
        'today': {
          'meal_count': todayMealCount,
          'exercise_minutes': todayExerciseMinutes,
        },
        'seven_day_metrics': sevenDayMetrics.toJson(),
        'recovery': _recoveryJson(),
        'feedback': feedback.toJson(),
        'missing_inputs': missingInputs,
        'allowed_evidence': allowedEvidence,
      };

  Map<String, Object?> toFingerprintJson() => {
        'date': _dateKey(date),
        'profile': _profileJson(),
        'today_meal_count': todayMealCount,
        'today_exercise_minutes': todayExerciseMinutes,
        'seven_day_metrics': sevenDayMetrics.toJson(),
        'recovery': _recoveryJson(),
        'feedback': feedback.toJson(),
        'missing_inputs': missingInputs,
        'allowed_evidence': allowedEvidence,
        'last_exercise': lastExercise == null
            ? null
            : {
                'activity_type': lastExercise!.activityType.name,
                'started_at': lastExercise!.startedAt.toIso8601String(),
                'duration_seconds': lastExercise!.durationSeconds,
                'rpe': lastExercise!.rpe,
              },
      };

  Map<String, Object?> _profileJson() => {
        'goal': profile.goal.name,
        'preferred_activities': profile.preferredActivities
            .map((item) => item.name)
            .toList()
          ..sort(),
        'available_days_per_week': profile.availableDaysPerWeek,
        'max_session_minutes': profile.maxSessionMinutes,
      };

  Map<String, int>? _recoveryJson() {
    final value = recovery;
    if (value == null) return null;
    return {
      'sleep_quality': value.sleepQuality,
      'fatigue': value.fatigue,
      'soreness': value.soreness,
      'energy': value.energy,
    };
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
