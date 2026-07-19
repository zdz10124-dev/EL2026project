import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exercise_draft.dart';
import '../models/exercise_record.dart';
import 'exercise_repository.dart';
import 'meal_repository.dart';

class DemoImportResult {
  const DemoImportResult({required this.meals, required this.exercises});
  final int meals;
  final int exercises;
  int get total => meals + exercises;
}

class DemoDataService {
  DemoDataService({
    required MealRepository mealRepository,
    required ExerciseRepository exerciseRepository,
  })  : _meals = mealRepository,
        _exercises = exerciseRepository;

  static const _demoLocation = '比赛演示数据';
  static const _demoNote = '比赛演示数据';

  final MealRepository _meals;
  final ExerciseRepository _exercises;

  Future<DemoImportResult> import() async {
    final source = await rootBundle.loadString(
      'assets/demo/demo_health_records.json',
    );
    final data = (jsonDecode(source) as Map).cast<String, dynamic>();
    final existingMeals = await _meals.fetchRecords();
    final existingExercises = await _exercises.fetchRecords();
    var mealCount = 0;
    var exerciseCount = 0;

    for (final raw in data['meals'] as List? ?? const []) {
      if (raw is! Map) continue;
      final item = raw.cast<String, dynamic>();
      final dishName = item['dish_name']?.toString() ?? '';
      if (dishName.isEmpty ||
          existingMeals.any((record) =>
              record.dishName == dishName && record.location == _demoLocation)) {
        continue;
      }
      await _meals.saveRecord(
        sourceImagePaths: const [],
        dishNameInput: dishName,
        locationInput: _demoLocation,
        priceText: '',
        ratingScore: null,
        aiIngredients: item['ingredients']?.toString(),
        aiDrink: item['drink']?.toString(),
        commentInput: _demoNote,
        occurredAt: _dateForOffset(item['day_offset']),
        autoUploadEnabled: false,
      );
      mealCount++;
    }

    for (final raw in data['exercises'] as List? ?? const []) {
      if (raw is! Map) continue;
      final item = raw.cast<String, dynamic>();
      final type = ActivityTypeX.fromValue(item['activity_type']?.toString());
      final startedAt = _dateForOffset(item['day_offset']);
      final duplicate = existingExercises.any((record) =>
          record.note == _demoNote &&
          record.activityType == type &&
          _sameDay(record.startedAt, startedAt));
      if (duplicate) continue;
      await _exercises.saveDraft(ExerciseDraft(
        activityType: type,
        startedAt: startedAt,
        durationSeconds: _int(item['duration_seconds']) ?? 0,
        distanceMeters: _int(item['distance_meters']),
        averageHeartRateBpm: _int(item['average_heart_rate_bpm']),
        peakHeartRateBpm: _int(item['peak_heart_rate_bpm']),
        caloriesKcal: _int(item['calories_kcal']),
        rpe: _int(item['rpe']),
        note: _demoNote,
      ));
      exerciseCount++;
    }

    return DemoImportResult(meals: mealCount, exercises: exerciseCount);
  }

  DateTime _dateForOffset(dynamic value) {
    final now = DateTime.now();
    final offset = _int(value) ?? 0;
    final day = DateTime(now.year, now.month, now.day, 12)
        .add(Duration(days: offset));
    return day;
  }

  int? _int(dynamic value) =>
      value is num ? value.round() : int.tryParse(value?.toString() ?? '');

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year && left.month == right.month && left.day == right.day;
}
