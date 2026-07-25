import 'exercise_record.dart';

enum HealthGoal { generalHealth, fatLoss, endurance, habit, performance }

extension HealthGoalX on HealthGoal {
  String get label => switch (this) {
        HealthGoal.generalHealth => '综合健康',
        HealthGoal.fatLoss => '减脂',
        HealthGoal.endurance => '耐力提升',
        HealthGoal.habit => '培养习惯',
        HealthGoal.performance => '运动表现',
      };
}

class HealthProfile {
  const HealthProfile({
    this.goal = HealthGoal.generalHealth,
    this.preferredActivities = const {},
    this.availableDaysPerWeek,
    this.maxSessionMinutes,
    this.birthYear,
    this.heightCm,
    this.weightKg,
  });

  final HealthGoal goal;
  final Set<ActivityType> preferredActivities;
  final int? availableDaysPerWeek;
  final int? maxSessionMinutes;
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;

  HealthProfile copyWith({
    HealthGoal? goal,
    Set<ActivityType>? preferredActivities,
    int? availableDaysPerWeek,
    int? maxSessionMinutes,
    int? birthYear,
    double? heightCm,
    double? weightKg,
  }) =>
      HealthProfile(
        goal: goal ?? this.goal,
        preferredActivities: preferredActivities ?? this.preferredActivities,
        availableDaysPerWeek: availableDaysPerWeek ?? this.availableDaysPerWeek,
        maxSessionMinutes: maxSessionMinutes ?? this.maxSessionMinutes,
        birthYear: birthYear ?? this.birthYear,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
      );

  Map<String, dynamic> toJson() => {
        'goal': goal.name,
        'preferred_activities':
            preferredActivities.map((item) => item.name).toList(),
        'available_days_per_week': availableDaysPerWeek,
        'max_session_minutes': maxSessionMinutes,
        'birth_year': birthYear,
        'height_cm': heightCm,
        'weight_kg': weightKg,
      };

  factory HealthProfile.fromJson(Map<String, dynamic> json) => HealthProfile(
        goal: HealthGoal.values.firstWhere(
          (item) => item.name == json['goal'],
          orElse: () => HealthGoal.generalHealth,
        ),
        preferredActivities: (json['preferred_activities'] as List? ?? const [])
            .map((value) => ActivityTypeX.fromValue(value.toString()))
            .toSet(),
        availableDaysPerWeek:
            (json['available_days_per_week'] as num?)?.toInt(),
        maxSessionMinutes: (json['max_session_minutes'] as num?)?.toInt(),
        birthYear: (json['birth_year'] as num?)?.toInt(),
        heightCm: (json['height_cm'] as num?)?.toDouble(),
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
      );
}
