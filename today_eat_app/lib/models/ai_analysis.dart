/// AI 图片识别菜品分析结果
class ImageAnalysisResult {
  ImageAnalysisResult({
    required this.dishName,
    this.mainDish,
    this.sideDish,
    this.drink,
    this.snack,
    this.spiceLevel,
    this.ingredients,
    this.cuisine,
  });

  final String dishName;
  final String? mainDish;
  final String? sideDish;
  final String? drink;
  final String? snack;
  final String? spiceLevel;
  final String? ingredients;
  final String? cuisine;

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResult(
      dishName: json['dish_name'] as String? ?? json['dishName'] as String? ?? '',
      mainDish: json['main_dish'] as String? ?? json['mainDish'] as String?,
      sideDish: json['side_dish'] as String? ?? json['sideDish'] as String?,
      drink: json['drink'] as String?,
      snack: json['snack'] as String?,
      spiceLevel:
          json['spice_level'] as String? ?? json['spiceLevel'] as String?,
      ingredients: json['ingredients'] as String?,
      cuisine: json['cuisine'] as String?,
    );
  }
}
