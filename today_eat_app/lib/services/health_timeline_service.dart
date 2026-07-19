import '../models/exercise_record.dart';
import '../models/health_timeline_item.dart';
import '../models/meal_record.dart';

class HealthTimelineService {
  List<HealthTimelineItem> merge({
    required List<MealRecord> meals,
    required List<ExerciseRecord> exercises,
  }) {
    final items = <HealthTimelineItem>[
      ...meals.map(HealthTimelineItem.meal),
      ...exercises.map(HealthTimelineItem.exercise),
    ];
    items.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return items;
  }
}
