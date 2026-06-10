enum LocalRecommendationStatus {
  localOnly,
  pendingUpload,
  uploaded,
  uploadFailed,
  unlisted,
}

extension LocalRecommendationStatusX on LocalRecommendationStatus {
  String get dbValue {
    switch (this) {
      case LocalRecommendationStatus.localOnly:
        return 'local_only';
      case LocalRecommendationStatus.pendingUpload:
        return 'pending_upload';
      case LocalRecommendationStatus.uploaded:
        return 'uploaded';
      case LocalRecommendationStatus.uploadFailed:
        return 'upload_failed';
      case LocalRecommendationStatus.unlisted:
        return 'unlisted';
    }
  }

  static LocalRecommendationStatus fromDb(String? value) {
    switch (value) {
      case 'pending_upload':
        return LocalRecommendationStatus.pendingUpload;
      case 'uploaded':
        return LocalRecommendationStatus.uploaded;
      case 'upload_failed':
        return LocalRecommendationStatus.uploadFailed;
      case 'unlisted':
        return LocalRecommendationStatus.unlisted;
      default:
        return LocalRecommendationStatus.localOnly;
    }
  }
}

class MealRecord {
  MealRecord({
    this.id,
    required this.clientRecordId,
    required this.createdAt,
    required this.updatedAt,
    required this.imagePaths,
    required this.dishName,
    required this.location,
    required this.price,
    required this.ratingScore,
    required this.ratingLabel,
    required this.mainDish,
    this.comment,
    this.remoteRecommendationId,
    this.autoUploadEnabled = true,
    this.recommendationStatus = LocalRecommendationStatus.localOnly,
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

  final int? id;
  final String clientRecordId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> imagePaths;

  /// Backward-compat: first image is primary
  String get imagePath =>
      imagePaths.isNotEmpty ? imagePaths.first : '';
  final String dishName;
  final String location;
  final double? price;
  final double? ratingScore;
  final String ratingLabel;
  final String mainDish;
  final String? comment;
  final String? remoteRecommendationId;
  final bool autoUploadEnabled;
  final LocalRecommendationStatus recommendationStatus;
  final String? sideDish;
  final String? drink;
  final String? snack;
  final String? province;
  final String? city;
  final String? district;
  final double? latitude;
  final double? longitude;
  final String? spiceLevel;
  final String? ingredients;
  final String? cuisine;

  MealRecord copyWith({
    int? id,
    String? clientRecordId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? imagePaths,
    String? dishName,
    String? location,
    double? price,
    double? ratingScore,
    String? ratingLabel,
    String? mainDish,
    String? comment,
    String? remoteRecommendationId,
    bool? autoUploadEnabled,
    LocalRecommendationStatus? recommendationStatus,
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
      imagePaths: imagePaths ?? this.imagePaths,
      dishName: dishName ?? this.dishName,
      location: location ?? this.location,
      price: price ?? this.price,
      ratingScore: ratingScore ?? this.ratingScore,
      ratingLabel: ratingLabel ?? this.ratingLabel,
      mainDish: mainDish ?? this.mainDish,
      comment: comment ?? this.comment,
      remoteRecommendationId:
          remoteRecommendationId ?? this.remoteRecommendationId,
      autoUploadEnabled: autoUploadEnabled ?? this.autoUploadEnabled,
      recommendationStatus: recommendationStatus ?? this.recommendationStatus,
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
      'image_path': imagePaths.isNotEmpty ? imagePaths.first : '',
      'image_paths': imagePaths.join(','),
      'dish_name': dishName,
      'location': location,
      'price': price,
      'comment': comment,
      'remote_recommendation_id': remoteRecommendationId,
      'auto_upload_enabled': autoUploadEnabled ? 1 : 0,
      'recommendation_status': recommendationStatus.dbValue,
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

  static List<String> _parseImagePaths(Map<String, Object?> map) {
    // Try new multi-path column first
    final pathsStr = map['image_paths'] as String?;
    if (pathsStr != null && pathsStr.isNotEmpty) {
      return pathsStr.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }
    // Fallback: old single image_path
    final single = map['image_path'] as String?;
    if (single != null && single.isNotEmpty) {
      return [single];
    }
    return [];
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
      imagePaths: _parseImagePaths(map),
      dishName: map['dish_name'] as String,
      location: map['location'] as String,
      price: (map['price'] as num?)?.toDouble(),
      ratingScore: (map['rating_score'] as num?)?.toDouble(),
      ratingLabel: map['rating_label'] as String? ?? '未打分',
      mainDish: map['main_dish'] as String,
      comment: map['comment'] as String?,
      remoteRecommendationId: map['remote_recommendation_id'] as String?,
      autoUploadEnabled: (map['auto_upload_enabled'] as num?)?.toInt() != 0,
      recommendationStatus: LocalRecommendationStatusX.fromDb(
        map['recommendation_status'] as String?,
      ),
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
