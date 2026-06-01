// 对外接口：
// - RecommendationDistanceBucket
// - RecommendationPriceBucket
// - RecommendationQuery
// - RecommendationItem
// - RecommendationDetail
// - RecommendationSearchPage

enum RecommendationDistanceBucket { within500m, within2km, within5km, beyond5km }

enum RecommendationPriceBucket { under20, between20And40, between40And60, above60 }

extension RecommendationDistanceBucketX on RecommendationDistanceBucket {
  String get label {
    switch (this) {
      case RecommendationDistanceBucket.within500m:
        return '500m';
      case RecommendationDistanceBucket.within2km:
        return '2km';
      case RecommendationDistanceBucket.within5km:
        return '5km';
      case RecommendationDistanceBucket.beyond5km:
        return '5km+';
    }
  }

  String get apiValue {
    switch (this) {
      case RecommendationDistanceBucket.within500m:
        return 'within_500m';
      case RecommendationDistanceBucket.within2km:
        return 'within_2km';
      case RecommendationDistanceBucket.within5km:
        return 'within_5km';
      case RecommendationDistanceBucket.beyond5km:
        return 'beyond_5km';
    }
  }
}

extension RecommendationPriceBucketX on RecommendationPriceBucket {
  String get label {
    switch (this) {
      case RecommendationPriceBucket.under20:
        return '0-20';
      case RecommendationPriceBucket.between20And40:
        return '20-40';
      case RecommendationPriceBucket.between40And60:
        return '40-60';
      case RecommendationPriceBucket.above60:
        return '60+';
    }
  }

  String get apiValue {
    switch (this) {
      case RecommendationPriceBucket.under20:
        return 'under_20';
      case RecommendationPriceBucket.between20And40:
        return 'between_20_40';
      case RecommendationPriceBucket.between40And60:
        return 'between_40_60';
      case RecommendationPriceBucket.above60:
        return 'above_60';
    }
  }
}

class RecommendationQuery {
  const RecommendationQuery({
    required this.distanceBuckets,
    required this.priceBuckets,
    required this.page,
    required this.pageSize,
    this.latitude,
    this.longitude,
  });

  /// 距离筛选，可多选。
  final List<RecommendationDistanceBucket> distanceBuckets;

  /// 价格筛选，可多选。
  final List<RecommendationPriceBucket> priceBuckets;

  /// 推荐列表页码，从 1 开始。
  final int page;

  /// 每页条数。
  final int pageSize;

  /// 用户当前位置纬度，可为空。
  final double? latitude;

  /// 用户当前位置经度，可为空。
  final double? longitude;

  Map<String, Object?> toJson() {
    return {
      'distance_buckets': distanceBuckets.map((item) => item.apiValue).toList(),
      'price_buckets': priceBuckets.map((item) => item.apiValue).toList(),
      'page': page,
      'page_size': pageSize,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class RecommendationAggregate {
  const RecommendationAggregate({
    required this.uploadCount,
    required this.averageRating,
    required this.averagePrice,
    required this.latestRecordedAt,
  });

  /// 同菜品累计公开记录数。
  final int uploadCount;

  /// 同菜品平均评分。
  final double? averageRating;

  /// 同菜品平均价格。
  final double? averagePrice;

  /// 同菜品最近一次被记录时间。
  final DateTime latestRecordedAt;

  factory RecommendationAggregate.fromMap(Map<String, Object?> map) {
    return RecommendationAggregate(
      uploadCount: (map['upload_count'] as num?)?.toInt() ?? 0,
      averageRating: (map['average_rating'] as num?)?.toDouble(),
      averagePrice: (map['average_price'] as num?)?.toDouble(),
      latestRecordedAt: DateTime.parse(
        map['latest_recorded_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.dishName,
    required this.location,
    required this.price,
    required this.rating,
    required this.aggregate,
    this.distanceMeters,
    required this.reason,
  });

  /// 代表记录的远端主键。
  final String id;

  /// 列表里展示的菜名。
  final String dishName;

  /// 列表里展示的地点。
  final String location;

  /// 代表记录价格。
  final double price;

  /// 代表记录评分。
  final double rating;

  /// 同菜品聚合统计。
  final RecommendationAggregate aggregate;

  /// 与当前用户距离，单位米。
  final double? distanceMeters;

  /// 后端给出的推荐理由。
  final String reason;

  /// 兼容旧界面字段。
  String get title => dishName;

  /// 兼容旧界面字段。
  String get store => location;

  /// 兼容旧界面字段。
  String get region => location;

  /// 兼容旧界面字段。
  String get cuisine => '';

  /// 兼容旧界面字段。
  String get description => reason;

  factory RecommendationItem.fromMap(Map<String, Object?> map) {
    return RecommendationItem(
      id: map['id'] as String? ?? '',
      dishName: map['dish_name'] as String? ?? '',
      location: map['location'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      aggregate: RecommendationAggregate.fromMap(
        map['aggregate'] as Map<String, Object?>? ?? const {},
      ),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      reason: map['reason'] as String? ?? '',
    );
  }
}

class RecommendationDetail {
  const RecommendationDetail({
    required this.id,
    required this.dishName,
    required this.location,
    required this.price,
    required this.rating,
    required this.createdAt,
    required this.aggregate,
    this.comment,
    this.imageUrl,
    this.distanceMeters,
    this.reason,
  });

  /// 代表记录的远端主键。
  final String id;

  /// 详情展示菜名。
  final String dishName;

  /// 详情展示地点。
  final String location;

  /// 详情展示价格。
  final double? price;

  /// 详情展示评分。
  final double? rating;

  /// 该条代表记录的记录时间。
  final DateTime createdAt;

  /// 同菜品聚合统计。
  final RecommendationAggregate aggregate;

  /// 预留的用户评价文本。
  final String? comment;

  /// 远端图片地址。
  final String? imageUrl;

  /// 与当前用户距离，单位米。
  final double? distanceMeters;

  /// 推荐理由。
  final String? reason;

  factory RecommendationDetail.fromMap(Map<String, Object?> map) {
    return RecommendationDetail(
      id: map['id'] as String? ?? '',
      dishName: map['dish_name'] as String? ?? '',
      location: map['location'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble(),
      createdAt: DateTime.parse(
        map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      aggregate: RecommendationAggregate.fromMap(
        map['aggregate'] as Map<String, Object?>? ?? const {},
      ),
      comment: map['comment'] as String?,
      imageUrl: map['image_url'] as String?,
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      reason: map['reason'] as String?,
    );
  }
}

class RecommendationSearchPage {
  const RecommendationSearchPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });

  final int total;
  final int page;
  final int pageSize;
  final List<RecommendationItem> items;

  bool get hasMore => page * pageSize < total;

  factory RecommendationSearchPage.fromMap(Map<String, Object?> map) {
    final items = (map['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(RecommendationItem.fromMap)
        .toList();
    return RecommendationSearchPage(
      total: (map['total'] as num?)?.toInt() ?? items.length,
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageSize: (map['page_size'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }
}
