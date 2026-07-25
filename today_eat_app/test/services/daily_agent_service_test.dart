import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:today_eat_app/models/health_context.dart';
import 'package:today_eat_app/models/health_metrics.dart';
import 'package:today_eat_app/models/health_profile.dart';
import 'package:today_eat_app/services/health_api_service.dart';

void main() {
  test('daily plan payload sends only de-identified context and evidence', () {
    final payload = jsonEncode(buildDailyPlanPayload(_context()));

    expect(payload, contains('allowed_evidence'));
    expect(payload, isNot(contains('image_path')));
    expect(payload, isNot(contains('location')));
    expect(payload, isNot(contains('note')));
  });
}

HealthContext _context() => HealthContext(
  date: DateTime(2026, 7, 25),
  profile: const HealthProfile(goal: HealthGoal.endurance),
  todayMealCount: 1,
  todayExerciseMinutes: 30,
  sevenDayMetrics: const HealthMetrics(
    mealCount: 6,
    activeMealDays: 4,
    exerciseCount: 2,
    totalExerciseSeconds: 3600,
    totalDistanceMeters: 5000,
    highLoadDays: [],
    postWorkoutMealCoverage: 0.5,
    dataQuality: DataQuality(
      mealCount: 6,
      exerciseCount: 2,
      activeDays: 4,
      missingFields: [],
    ),
  ),
  recovery: null,
  feedback: AgentFeedbackSummary.empty,
  allowedEvidence: const ['今日饮食记录 1 次'],
  missingInputs: const [],
);
