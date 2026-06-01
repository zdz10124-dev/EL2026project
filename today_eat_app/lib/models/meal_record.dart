// 对外接口：
// - MealRecord

class MealRecord {
  MealRecord({
    this.id,
    required this.clientRecordId,
    required this.createdAt,
    required this.updatedAt,
    required this.imagePath,
    required this.dishName,
    required this.location,
    required this.price,
    required this.ratingScore,
    required this.ratingLabel,
    required this.mainDish,
    this.comment,
    this.sideDish,
    this.drink,
    this.snack,
    this.province,
    this.city,
    this.district,
    this.latitude,
    this.longitude,
    this.spiceLevel,
    this.ingredients,
    this.cuisine,
  });

  /// 本地数据库自增主键。
  final int? id;

  /// 上传去重使用的客户端稳定标识。
  final String clientRecordId;

  /// 用户实际记录用餐时间。
  final DateTime createdAt;

  /// 最近一次本地修改时间，用于判断是否需要重新上传。
  final DateTime updatedAt;

  /// 本地图片绝对路径。
  final String imagePath;

  /// 用户填写的菜名。
  final String dishName;

  /// 用户填写的地点文本。
  final String location;

  /// 用户填写的价格。
  final double? price;

  /// 0-10 分制评分。
  final double? ratingScore;

  /// 评分文本，用于现有统计页展示。
  final String ratingLabel;

  /// 当前版本的主菜归一字段。
  final String mainDish;

  /// 预留的用户评价文本。
  final String? comment;

  final String? sideDish;
  final String? drink;
  final String? snack;
  final String? province;
  final String? city;
  final String? district;

  /// 记录地点纬度，可为空。
  final double? latitude;

  /// 记录地点经度，可为空。
  final double? longitude;

  final String? spiceLevel;
  final String? ingredients;
  final String? cuisine;

  MealRecord copyWith({
    int? id,
    String? clientRecordId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
    String? dishName,
    String? location,
    double? price,
    double? ratingScore,
    String? ratingLabel,
    String? mainDish,
    String? comment,
    String? sideDish,
    String? drink,
    String? snack,
    String? province,
    String? city,
    String? district,
    double? latitude,
    double? longitude,
    String? spiceLevel,
    String? ingredients,
    String? cuisine,
  }) {
    return MealRecord(
      id: id ?? this.id,
      clientRecordId: clientRecordId ?? this.clientRecordId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
      dishName: dishName ?? this.dishName,
      location: location ?? this.location,
      price: price ?? this.price,
      ratingScore: ratingScore ?? this.ratingScore,
      ratingLabel: ratingLabel ?? this.ratingLabel,
      mainDish: mainDish ?? this.mainDish,
      comment: comment ?? this.comment,
      sideDish: sideDish ?? this.sideDish,
      drink: drink ?? this.drink,
      snack: snack ?? this.snack,
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      ingredients: ingredients ?? this.ingredients,
      cuisine: cuisine ?? this.cuisine,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'client_record_id': clientRecordId,
      'year': createdAt.year,
      'month': createdAt.month,
      'day': createdAt.day,
      'hour': createdAt.hour,
      'minute': createdAt.minute,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'image_path': imagePath,
      'dish_name': dishName,
      'location': location,
      'price': price,
      'comment': comment,
      'province': province,
      'city': city,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
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
    final id = map['id'] as int?;
    final createdAt = DateTime.parse(map['created_at'] as String);
    return MealRecord(
      id: id,
      clientRecordId:
          map['client_record_id'] as String? ??
          'legacy_${id ?? createdAt.microsecondsSinceEpoch}',
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(
            map['updated_at'] as String? ?? map['created_at'] as String? ?? '',
          ) ??
          createdAt,
      imagePath: map['image_path'] as String,
      dishName: map['dish_name'] as String,
      location: map['location'] as String,
      price: (map['price'] as num?)?.toDouble(),
      ratingScore: (map['rating_score'] as num?)?.toDouble(),
      ratingLabel: map['rating_label'] as String? ?? '未打分',
      mainDish: map['main_dish'] as String,
      comment: map['comment'] as String?,
      sideDish: map['side_dish'] as String?,
      drink: map['drink'] as String?,
      snack: map['snack'] as String?,
      province: map['province'] as String?,
      city: map['city'] as String?,
      district: map['district'] as String? ?? map['street'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      spiceLevel: map['spice_level'] as String?,
      ingredients: map['ingredients'] as String?,
      cuisine: map['cuisine'] as String?,
    );
  }
}
