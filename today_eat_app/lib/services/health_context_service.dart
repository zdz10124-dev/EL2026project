import '../models/exercise_record.dart';
import '../models/health_context.dart';
import '../models/health_profile.dart';
import '../models/meal_record.dart';
import '../models/recovery_check_in.dart';
import 'health_metrics_service.dart';

class HealthContextService {
  HealthContextService({HealthMetricsService? metricsService})
      : _metrics = metricsService ?? HealthMetricsService();

  final HealthMetricsService _metrics;

  HealthContext build({
    required DateTime now,
    required HealthProfile profile,
    required List<MealRecord> meals,
    required List<ExerciseRecord> exercises,
    required RecoveryCheckIn? recovery,
    required AgentFeedbackSummary feedback,
  }) {
    final date = DateTime(now.year, now.month, now.day);
    final nextDate = date.add(const Duration(days: 1));
    final sevenDayStart = nextDate.subtract(const Duration(days: 7));
    final todayMeals = meals
        .where((item) =>
            !item.createdAt.isBefore(date) && item.createdAt.isBefore(nextDate))
        .toList();
    final todayExercises = exercises
        .where((item) =>
            !item.startedAt.isBefore(date) && item.startedAt.isBefore(nextDate))
        .toList();
    final sevenDayMetrics = _metrics.calculate(
      start: sevenDayStart,
      end: nextDate,
      meals: meals,
      exercises: exercises,
    );
    final sortedExercises = [...exercises]
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    final missingInputs = <String>[
      if (recovery == null) 'today_recovery',
      if (sevenDayMetrics.mealCount == 0 &&
          sevenDayMetrics.exerciseCount == 0)
        'recent_records',
    ];
    final evidence = _buildEvidence(
      profile: profile,
      recovery: recovery,
      todayMealCount: todayMeals.length,
      todayExerciseMinutes: todayExercises.fold<int>(
        0,
        (sum, item) => sum + (item.durationSeconds / 60).round(),
      ),
      metrics: sevenDayMetrics,
      feedback: feedback,
    );
    return HealthContext(
      date: date,
      profile: profile,
      todayMealCount: todayMeals.length,
      todayExerciseMinutes: todayExercises.fold<int>(
        0,
        (sum, item) => sum + (item.durationSeconds / 60).round(),
      ),
      sevenDayMetrics: sevenDayMetrics,
      recovery: recovery,
      feedback: feedback,
      allowedEvidence: evidence,
      missingInputs: missingInputs,
      lastExercise: sortedExercises.isEmpty ? null : sortedExercises.first,
    );
  }

  List<String> _buildEvidence({
    required HealthProfile profile,
    required RecoveryCheckIn? recovery,
    required int todayMealCount,
    required int todayExerciseMinutes,
    required dynamic metrics,
    required AgentFeedbackSummary feedback,
  }) {
    final values = <String>['健康目标为${profile.goal.label}'];
    if (recovery != null) {
      values.addAll([
        '今日睡眠质量评分 ${recovery.sleepQuality}/5',
        '今日疲劳评分 ${recovery.fatigue}/5',
        '今日肌肉酸痛评分 ${recovery.soreness}/5',
        '今日精力评分 ${recovery.energy}/5',
      ]);
    }
    values.add(todayMealCount == 0 ? '今日尚未记录饮食' : '今日已记录饮食 $todayMealCount 次');
    values.add(todayExerciseMinutes == 0
        ? '今日尚未记录运动'
        : '今日已记录运动 $todayExerciseMinutes 分钟');
    values.add('近 7 天饮食记录 ${metrics.mealCount} 次');
    values.add('近 7 天运动记录 ${metrics.exerciseCount} 次');
    values.add('近 7 天运动总时长 ${(metrics.totalExerciseSeconds / 60).round()} 分钟');
    if (metrics.averageRpe != null) {
      values.add('近 7 天平均 RPE ${metrics.averageRpe!.toStringAsFixed(1)}');
    }
    if (metrics.postWorkoutMealCoverage != null) {
      values.add(
        '运动后 4 小时饮食覆盖率 '
        '${(metrics.postWorkoutMealCoverage! * 100).round()}%',
      );
    }
    if (metrics.highLoadDays.isNotEmpty) {
      values.add('近 7 天高负荷日期 ${metrics.highLoadDays.join('、')}');
    }
    if (feedback.completed > 0) values.add('近 7 天已完成行动 ${feedback.completed} 项');
    if (feedback.skipped > 0) values.add('近 7 天已跳过行动 ${feedback.skipped} 项');
    if (feedback.tooHard > 0) values.add('近 7 天反馈太难 ${feedback.tooHard} 项');
    return values;
  }
}
