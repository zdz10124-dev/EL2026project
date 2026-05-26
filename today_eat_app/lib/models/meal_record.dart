class MealRecord {
  MealRecord({
    this.id,
    required this.createdAt,
    required this.imagePath,
    required this.dishName,
    required this.location,
    required this.price,
    required this.ratingScore,
    required this.ratingLabel,
    required this.mainDish,
    this.sideDish,
    this.drink,
    this.snack,
    this.province,
    this.city,
    this.street,
    this.spiceLevel,
    this.ingredients,
    this.cuisine,
  });

  final int? id;
  final DateTime createdAt;
  final String imagePath;
  final String dishName;
  final String location;
  final double? price;
  final double? ratingScore;
  final String ratingLabel;
  final String mainDish;
  final String? sideDish;
  final String? drink;
  final String? snack;
  final String? province;
  final String? city;
  final String? street;
  final String? spiceLevel;
  final String? ingredients;
  final String? cuisine;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'year': createdAt.year,
      'month': createdAt.month,
      'day': createdAt.day,
      'hour': createdAt.hour,
      'minute': createdAt.minute,
      'created_at': createdAt.toIso8601String(),
      'image_path': imagePath,
      'dish_name': dishName,
      'location': location,
      'price': price,
      'province': province,
      'city': city,
      'street': street,
      'main_dish': mainDish,
      'side_dish': sideDish,
      'drink': drink,
      'snack': snack,
      'rating_score': ratingScore,
      'rating_label': ratingLabel,
      'spice_level': spiceLevel,
      'ingredients': ingredients,
      'cuisine': cuisine,
    };
  }

  factory MealRecord.fromMap(Map<String, Object?> map) {
    return MealRecord(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      imagePath: map['image_path'] as String,
      dishName: map['dish_name'] as String,
      location: map['location'] as String,
      price: (map['price'] as num?)?.toDouble(),
      ratingScore: (map['rating_score'] as num?)?.toDouble(),
      ratingLabel: map['rating_label'] as String? ?? '未打分',
      mainDish: map['main_dish'] as String,
      sideDish: map['side_dish'] as String?,
      drink: map['drink'] as String?,
      snack: map['snack'] as String?,
      province: map['province'] as String?,
      city: map['city'] as String?,
      street: map['street'] as String?,
      spiceLevel: map['spice_level'] as String?,
      ingredients: map['ingredients'] as String?,
      cuisine: map['cuisine'] as String?,
    );
  }
}
