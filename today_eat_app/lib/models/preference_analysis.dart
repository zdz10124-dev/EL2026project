/// AI 用户偏好分析结果
class PreferenceAnalysis {
  PreferenceAnalysis({
    required this.favoriteCuisines,
    required this.favoriteIngredients,
    required this.spicePreference,
    this.favoriteDishes,
    this.favoriteLocations,
    this.trends,
    this.summary,
  });

  final List<String> favoriteCuisines;
  final List<String> favoriteIngredients;
  final String spicePreference;
  final List<String>? favoriteDishes;
  final List<String>? favoriteLocations;
  final List<String>? trends;
  final String? summary;

  factory PreferenceAnalysis.fromJson(Map<String, dynamic> json) {
    return PreferenceAnalysis(
      favoriteCuisines: _strList(json['favorite_cuisines'] ?? json['favoriteCuisines']),
      favoriteIngredients: _strList(json['favorite_ingredients'] ?? json['favoriteIngredients']),
      spicePreference: json['spice_preference'] as String? ?? json['spicePreference'] as String? ?? '未知',
      favoriteDishes: _strList(json['favorite_dishes'] ?? json['favoriteDishes']),
      favoriteLocations: _strList(json['favorite_locations'] ?? json['favoriteLocations']),
      trends: _strList(json['trends']),
      summary: json['summary'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'favorite_cuisines': favoriteCuisines,
    'favorite_ingredients': favoriteIngredients,
    'spice_preference': spicePreference,
    'favorite_dishes': favoriteDishes,
    'favorite_locations': favoriteLocations,
    'trends': trends,
    'summary': summary,
  };

  static List<String> _strList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [value.toString()];
  }
}
