import 'package:flutter_test/flutter_test.dart';
import 'package:today_eat_app/models/exercise_record.dart';
import 'package:today_eat_app/models/health_context.dart';
import 'package:today_eat_app/models/health_profile.dart';
import 'package:today_eat_app/models/meal_record.dart';
import 'package:today_eat_app/models/recovery_check_in.dart';
import 'package:today_eat_app/services/health_context_service.dart';

void main() {
  final service = HealthContextService();

  test('builds evidence from meals exercises recovery and profile', () {
    final context = service.build(
      now: DateTime(2026, 7, 25, 9),
      profile: const HealthProfile(goal: HealthGoal.endurance),
      meals: [_mealAt(DateTime(2026, 7, 25, 8))],
      exercises: [_exerciseAt(DateTime(2026, 7, 24, 18), rpe: 8)],
      recovery: _recoveryAt('2026-07-25', fatigue: 4),
      feedback: const AgentFeedbackSummary(completed: 2, skipped: 1, tooHard: 1),
    );

    expect(context.todayMealCount, 1);
    expect(context.allowedEvidence, contains('今日疲劳评分 4/5'));
    expect(context.allowedEvidence, contains('健康目标为耐力提升'));
    expect(context.canGenerateAiPlan, isTrue);
  });

  test('requires today recovery and recent health records for ai plan', () {
    final context = service.build(
      now: DateTime(2026, 7, 25),
      profile: const HealthProfile(),
      meals: const [],
      exercises: const [],
      recovery: null,
      feedback: AgentFeedbackSummary.empty,
    );

    expect(context.canGenerateAiPlan, isFalse);
    expect(context.missingInputs, contains('today_recovery'));
    expect(context.missingInputs, contains('recent_records'));
  });
}

MealRecord _mealAt(DateTime value) => MealRecord(
      clientRecordId: 'meal-${value.microsecondsSinceEpoch}',
      createdAt: value,
      updatedAt: value,
      imagePaths: const [],
      dishName: '鸡肉蔬菜饭',
      location: '家',
      price: null,
      ratingScore: null,
      ratingLabel: '未打分',
      mainDish: '鸡肉',
      ingredients: '鸡肉,西兰花,米饭',
    );

ExerciseRecord _exerciseAt(DateTime value, {int? rpe}) => ExerciseRecord(
      clientRecordId: 'exercise-${value.microsecondsSinceEpoch}',
      activityType: ActivityType.running,
      startedAt: value,
      durationSeconds: 1800,
      rpe: rpe,
      imagePaths: const [],
      source: ExerciseSource.manual,
      createdAt: value,
      updatedAt: value,
    );

RecoveryCheckIn _recoveryAt(String date, {required int fatigue}) => RecoveryCheckIn(
      localDate: date,
      sleepQuality: 3,
      fatigue: fatigue,
      soreness: 2,
      energy: 3,
      createdAt: DateTime(2026, 7, 25),
      updatedAt: DateTime(2026, 7, 25),
    );
