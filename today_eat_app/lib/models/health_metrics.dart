class DataQuality {
  const DataQuality({
    required this.mealCount,
    required this.exerciseCount,
    required this.activeDays,
    required this.missingFields,
  });

  final int mealCount;
  final int exerciseCount;
  final int activeDays;
  final List<String> missingFields;

  bool get isEnoughForAi => activeDays >= 2;

  Map<String, dynamic> toJson() => {
        'meal_count': mealCount,
        'exercise_count': exerciseCount,
        'active_days': activeDays,
        'missing_fields': missingFields,
      };
}

class HealthMetrics {
  const HealthMetrics({
    required this.mealCount,
    required this.activeMealDays,
    required this.exerciseCount,
    required this.totalExerciseSeconds,
    required this.totalDistanceMeters,
    required this.highLoadDays,
    required this.postWorkoutMealCoverage,
    required this.dataQuality,
    this.averageRpe,
    this.commonIngredients = const [],
    this.commonDrinks = const [],
  });

  final int mealCount;
  final int activeMealDays;
  final int exerciseCount;
  final int totalExerciseSeconds;
  final int totalDistanceMeters;
  final double? averageRpe;
  final List<String> highLoadDays;
  final double? postWorkoutMealCoverage;
  final List<String> commonIngredients;
  final List<String> commonDrinks;
  final DataQuality dataQuality;

  Map<String, dynamic> toJson() => {
        'meal_count': mealCount,
        'active_meal_days': activeMealDays,
        'exercise_count': exerciseCount,
        'total_exercise_seconds': totalExerciseSeconds,
        'total_distance_meters': totalDistanceMeters,
        'average_rpe': averageRpe,
        'high_load_days': highLoadDays,
        'post_workout_meal_coverage': postWorkoutMealCoverage,
        'common_ingredients': commonIngredients,
        'common_drinks': commonDrinks,
        'data_quality': dataQuality.toJson(),
      };
}
