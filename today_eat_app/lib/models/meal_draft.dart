class MealDraft {
  MealDraft({
    required this.dishName,
    required this.location,
    required this.priceText,
    this.ratingScore,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String dishName;
  final String location;
  final String priceText;
  final double? ratingScore;
  final DateTime updatedAt;

  bool get hasContent =>
      dishName.trim().isNotEmpty ||
      location.trim().isNotEmpty ||
      priceText.trim().isNotEmpty ||
      ratingScore != null;

  MealDraft copyWith({
    String? dishName,
    String? location,
    String? priceText,
    double? ratingScore,
    bool clearRating = false,
    DateTime? updatedAt,
  }) {
    return MealDraft(
      dishName: dishName ?? this.dishName,
      location: location ?? this.location,
      priceText: priceText ?? this.priceText,
      ratingScore: clearRating ? null : ratingScore ?? this.ratingScore,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static MealDraft empty() =>
      MealDraft(dishName: '', location: '', priceText: '');
}
