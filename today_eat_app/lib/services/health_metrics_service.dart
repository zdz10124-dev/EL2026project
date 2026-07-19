import '../models/exercise_record.dart';
import '../models/health_metrics.dart';
import '../models/meal_record.dart';

class HealthMetricsService {
  HealthMetrics calculate({
    required DateTime start,
    required DateTime end,
    required List<MealRecord> meals,
    required List<ExerciseRecord> exercises,
  }) {
    final selectedMeals = meals
        .where((item) => !item.createdAt.isBefore(start) && item.createdAt.isBefore(end))
        .toList();
    final selectedExercises = exercises
        .where((item) => !item.startedAt.isBefore(start) && item.startedAt.isBefore(end))
        .toList();
    final mealDays = selectedMeals.map((item) => _dateKey(item.createdAt)).toSet();
    final exerciseDays = selectedExercises
        .map((item) => _dateKey(item.startedAt))
        .toSet();
    final rpes = selectedExercises
        .where((item) => item.rpe != null)
        .map((item) => item.rpe!)
        .toList();
    final highLoadDays = selectedExercises
        .where((item) => (item.rpe ?? 0) >= 7)
        .map((item) => _dateKey(item.startedAt))
        .toSet()
        .toList()
      ..sort();
    var coveredWorkouts = 0;
    for (final exercise in selectedExercises) {
      final finish = exercise.startedAt.add(Duration(seconds: exercise.durationSeconds));
      final deadline = finish.add(const Duration(hours: 4));
      if (selectedMeals.any(
        (meal) => !meal.createdAt.isBefore(finish) && !meal.createdAt.isAfter(deadline),
      )) {
        coveredWorkouts++;
      }
    }

    final missing = <String>[];
    if (selectedExercises.isNotEmpty && rpes.isEmpty) missing.add('exercise_intensity');
    if (selectedMeals.every((item) => item.ingredients?.trim().isEmpty ?? true)) {
      missing.add('meal_ingredients');
    }
    final activeDays = {...mealDays, ...exerciseDays}.length;
    return HealthMetrics(
      mealCount: selectedMeals.length,
      activeMealDays: mealDays.length,
      exerciseCount: selectedExercises.length,
      totalExerciseSeconds: selectedExercises.fold(
        0,
        (sum, item) => sum + item.durationSeconds,
      ),
      totalDistanceMeters: selectedExercises.fold(
        0,
        (sum, item) => sum + (item.distanceMeters ?? 0),
      ),
      averageRpe: rpes.isEmpty
          ? null
          : rpes.reduce((left, right) => left + right) / rpes.length,
      highLoadDays: highLoadDays,
      postWorkoutMealCoverage: selectedExercises.isEmpty
          ? null
          : coveredWorkouts / selectedExercises.length,
      commonIngredients: _topTerms(
        selectedMeals.map((item) => item.ingredients).whereType<String>(),
      ),
      commonDrinks: _topTerms(
        selectedMeals.map((item) => item.drink).whereType<String>(),
      ),
      dataQuality: DataQuality(
        mealCount: selectedMeals.length,
        exerciseCount: selectedExercises.length,
        activeDays: activeDays,
        missingFields: missing,
      ),
    );
  }

  List<String> _topTerms(Iterable<String> values) {
    final counts = <String, int>{};
    for (final source in values) {
      for (final value in source.split(RegExp(r'[,，、]'))) {
        final term = value.trim();
        if (term.isNotEmpty) counts[term] = (counts[term] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((item) => item.key).toList();
  }

  String _dateKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
