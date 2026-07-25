import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/exercise_record.dart';
import '../models/health_profile.dart';
import '../models/integrated_health_analysis.dart';
import '../models/meal_record.dart';

String buildHealthDataFingerprint({
  required AnalysisPeriod period,
  required List<MealRecord> meals,
  required List<ExerciseRecord> exercises,
  required HealthProfile profile,
}) {
  final mealValues = meals
      .map((item) => {
            'id': item.clientRecordId,
            'updated': item.updatedAt.toIso8601String(),
            'dish': item.dishName,
            'ingredients': item.ingredients,
            'drink': item.drink,
          })
      .toList()
    ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
  final exerciseValues = exercises
      .map((item) => {
            'id': item.clientRecordId,
            'updated': item.updatedAt.toIso8601String(),
            'type': item.activityType.name,
            'duration': item.durationSeconds,
            'distance': item.distanceMeters,
            'rpe': item.rpe,
          })
      .toList()
    ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
  return sha256
      .convert(utf8.encode(jsonEncode({
        'period': period.key,
        'profile': profile.toJson(),
        'meals': mealValues,
        'exercises': exerciseValues,
      })))
      .toString();
}
