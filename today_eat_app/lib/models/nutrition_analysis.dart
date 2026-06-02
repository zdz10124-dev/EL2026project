/// AI 营养分析结果
class NutritionAnalysis {
  NutritionAnalysis({
    required this.overall,
    this.vegetableScore,
    this.proteinScore,
    this.drinkStatus,
    this.spicyStatus,
    this.regularity,
    this.suggestions,
  });

  final String overall;
  final int? vegetableScore;
  final int? proteinScore;
  final String? drinkStatus;
  final String? spicyStatus;
  final String? regularity;
  final List<String>? suggestions;

  factory NutritionAnalysis.fromJson(Map<String, dynamic> json) {
    return NutritionAnalysis(
      overall: json['overall'] as String? ?? '',
      vegetableScore: json['vegetable_score'] as int? ??
          json['vegetableScore'] as int?,
      proteinScore:
          json['protein_score'] as int? ?? json['proteinScore'] as int?,
      drinkStatus:
          json['drink_status'] as String? ?? json['drinkStatus'] as String?,
      spicyStatus:
          json['spicy_status'] as String? ?? json['spicyStatus'] as String?,
      regularity: json['regularity'] as String?,
      suggestions: (json['suggestions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }
}
