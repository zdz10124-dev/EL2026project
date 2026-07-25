import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'exercise_repository.dart';
import 'health_profile_repository.dart';
import 'meal_repository.dart';

class HealthDataExportService {
  HealthDataExportService({
    required MealRepository mealRepository,
    required ExerciseRepository exerciseRepository,
    required HealthProfileRepository healthProfileRepository,
  })  : _meals = mealRepository,
        _exercises = exerciseRepository,
        _profiles = healthProfileRepository;

  final MealRepository _meals;
  final ExerciseRepository _exercises;
  final HealthProfileRepository _profiles;

  Future<File> createJsonExport() async {
    final meals = await _meals.fetchRecords();
    final exercises = await _exercises.fetchRecords();
    final profile = await _profiles.load();
    final payload = {
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'health_profile': profile.toJson(),
      'meals': meals.map((record) => {
            'client_record_id': record.clientRecordId,
            'created_at': record.createdAt.toIso8601String(),
            'updated_at': record.updatedAt.toIso8601String(),
            'dish_name': record.dishName,
            'location': record.location,
            'price': record.price,
            'rating_score': record.ratingScore,
            'main_dish': record.mainDish,
            'side_dish': record.sideDish,
            'drink': record.drink,
            'snack': record.snack,
            'ingredients': record.ingredients,
            'cuisine': record.cuisine,
            'comment': record.comment,
            'image_paths': record.imagePaths,
          }).toList(),
      'exercises': exercises.map((record) => {
            'client_record_id': record.clientRecordId,
            'activity_type': record.activityType.name,
            'started_at': record.startedAt.toIso8601String(),
            'duration_seconds': record.durationSeconds,
            'distance_meters': record.distanceMeters,
            'average_heart_rate_bpm': record.averageHeartRateBpm,
            'peak_heart_rate_bpm': record.peakHeartRateBpm,
            'calories_kcal': record.caloriesKcal,
            'rpe': record.rpe,
            'note': record.note,
            'detail': record.detail,
            'source': record.source.name,
            'image_paths': record.imagePaths,
          }).toList(),
    };
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(p.join(directory.path, 'health-data-$timestamp.json'));
    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }
}
