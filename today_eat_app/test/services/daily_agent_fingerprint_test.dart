import 'package:flutter_test/flutter_test.dart';
import 'package:today_eat_app/models/health_context.dart';
import 'package:today_eat_app/models/health_metrics.dart';
import 'package:today_eat_app/models/health_profile.dart';
import 'package:today_eat_app/models/recovery_check_in.dart';
import 'package:today_eat_app/services/daily_agent_fingerprint.dart';

void main() {
  test('is stable for equivalent input and changes with recovery', () {
    final baseline = _context(fatigue: 3);
    final equivalent = _context(fatigue: 3);
    final changed = _context(fatigue: 4);

    expect(buildDailyAgentFingerprint(baseline), buildDailyAgentFingerprint(equivalent));
    expect(buildDailyAgentFingerprint(baseline), isNot(buildDailyAgentFingerprint(changed)));
  });
}

HealthContext _context({required int fatigue}) => HealthContext(
      date: DateTime(2026, 7, 25),
      profile: const HealthProfile(goal: HealthGoal.habit),
      todayMealCount: 1,
      todayExerciseMinutes: 30,
      sevenDayMetrics: const HealthMetrics(
        mealCount: 2,
        activeMealDays: 2,
        exerciseCount: 1,
        totalExerciseSeconds: 1800,
        totalDistanceMeters: 0,
        highLoadDays: [],
        postWorkoutMealCoverage: null,
        dataQuality: DataQuality(
          mealCount: 2,
          exerciseCount: 1,
          activeDays: 2,
          missingFields: [],
        ),
      ),
      recovery: RecoveryCheckIn(
        localDate: '2026-07-25',
        sleepQuality: 3,
        fatigue: fatigue,
        soreness: 2,
        energy: 3,
        createdAt: DateTime(2026, 7, 25),
        updatedAt: DateTime(2026, 7, 25),
      ),
      feedback: AgentFeedbackSummary.empty,
      allowedEvidence: const ['健康目标为培养习惯'],
      missingInputs: const [],
    );
