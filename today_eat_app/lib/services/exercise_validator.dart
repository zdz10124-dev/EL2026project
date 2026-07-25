import '../models/exercise_draft.dart';

List<String> validateExerciseDraft(ExerciseDraft draft) {
  final errors = <String>[];
  if (draft.durationSeconds <= 0) errors.add('运动时长必须大于 0');
  if ((draft.distanceMeters ?? 0) < 0) errors.add('运动距离不能为负数');
  if ((draft.caloriesKcal ?? 0) < 0) errors.add('消耗热量不能为负数');
  for (final value in [draft.averageHeartRateBpm, draft.peakHeartRateBpm]) {
    if (value != null && (value < 30 || value > 230)) {
      errors.add('心率应在 30 到 230 之间');
      break;
    }
  }
  if (draft.averageHeartRateBpm != null &&
      draft.peakHeartRateBpm != null &&
      draft.peakHeartRateBpm! < draft.averageHeartRateBpm!) {
    errors.add('峰值心率不能低于平均心率');
  }
  if (draft.rpe != null && (draft.rpe! < 1 || draft.rpe! > 10)) {
    errors.add('主观疲劳评分应在 1 到 10 之间');
  }
  return errors;
}
