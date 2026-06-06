import 'recommendation_comment.dart';

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

  final List<RecommendationDistanceBucket> distanceBuckets;
  final List<RecommendationPriceBucket> priceBuckets;
  final int page;
  final int pageSize;
  final double? latitude;
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

  final int uploadCount;
  final double? averageRating;
  final double? averagePrice;
  final DateTime latestRecordedAt;

  factory RecommendationAggregate.fromMap(Map<String, Object?> map) {
    return RecommendationAggregate(
      uploadCount: (map['upload_count'] as num?)?.toInt() ?? 0,
      averageRating: (map['average_rating'] as num?)?.toDouble(),
      averagePrice: (map['average_price'] as num?)?.toDouble(),
      latestRecordedAt: DateTime.parse(
        map['latest_recorded_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
    );
  }
}

class RecommendationFeedbackSummary {
  const RecommendationFeedbackSummary({
    required this.upvoteCount,
    required this.downvoteCount,
    required this.reportCount,
    required this.voteTotal,
    required this.downvoteRatio,
    required this.currentVote,
    required this.currentReported,
    required this.isHidden,
    this.hiddenReason,
  });

  final int upvoteCount;
  final int downvoteCount;
  final int reportCount;
  final int voteTotal;
  final double downvoteRatio;
  final String? currentVote;
  final bool currentReported;
  final bool isHidden;
  final String? hiddenReason;

  RecommendationFeedbackSummary copyWith({
    int? upvoteCount,
    int? downvoteCount,
    int? reportCount,
    int? voteTotal,
    double? downvoteRatio,
    String? currentVote,
    bool? currentReported,
    bool? isHidden,
    String? hiddenReason,
  }) {
    return RecommendationFeedbackSummary(
      upvoteCount: upvoteCount ?? this.upvoteCount,
      downvoteCount: downvoteCount ?? this.downvoteCount,
      reportCount: reportCount ?? this.reportCount,
      voteTotal: voteTotal ?? this.voteTotal,
      downvoteRatio: downvoteRatio ?? this.downvoteRatio,
      currentVote: currentVote ?? this.currentVote,
      currentReported: currentReported ?? this.currentReported,
      isHidden: isHidden ?? this.isHidden,
      hiddenReason: hiddenReason ?? this.hiddenReason,
    );
  }

  factory RecommendationFeedbackSummary.fromMap(Map<String, Object?> map) {
    return RecommendationFeedbackSummary(
      upvoteCount: (map['upvote_count'] as num?)?.toInt() ?? 0,
      downvoteCount: (map['downvote_count'] as num?)?.toInt() ?? 0,
      reportCount: (map['report_count'] as num?)?.toInt() ?? 0,
      voteTotal: (map['vote_total'] as num?)?.toInt() ?? 0,
      downvoteRatio: (map['downvote_ratio'] as num?)?.toDouble() ?? 0,
      currentVote: map['current_vote'] as String?,
      currentReported: map['current_reported'] == true,
      isHidden: map['is_hidden'] == true,
      hiddenReason: map['hidden_reason'] as String?,
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
    required this.reason,
    required this.feedback,
    this.distanceMeters,
    this.description,
    this.uploaderName,
    this.uploaderAvatar,
  });

  final String id;
  final String dishName;
  final String location;
  final double price;
  final double rating;
  final RecommendationAggregate aggregate;
  final RecommendationFeedbackSummary feedback;
  final double? distanceMeters;
  final String reason;
  final String? description;
  final String? uploaderName;
  final String? uploaderAvatar;

  String get title => dishName;
  String get store => location;
  String get region => location;
  String get cuisine => '';
  String get summaryDescription => description ?? reason;

  RecommendationItem copyWith({
    String? id,
    String? dishName,
    String? location,
    double? price,
    double? rating,
    RecommendationAggregate? aggregate,
    RecommendationFeedbackSummary? feedback,
    double? distanceMeters,
    String? reason,
    String? description,
    String? uploaderName,
    String? uploaderAvatar,
  }) {
    return RecommendationItem(
      id: id ?? this.id,
      dishName: dishName ?? this.dishName,
      location: location ?? this.location,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      aggregate: aggregate ?? this.aggregate,
      feedback: feedback ?? this.feedback,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      uploaderName: uploaderName ?? this.uploaderName,
      uploaderAvatar: uploaderAvatar ?? this.uploaderAvatar,
    );
  }

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
      feedback: RecommendationFeedbackSummary.fromMap(
        map['feedback'] as Map<String, Object?>? ?? const {},
      ),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      reason: map['reason'] as String? ?? '',
      description: map['description'] as String? ?? map['comment'] as String?,
      uploaderName: map['uploader_name'] as String?,
      uploaderAvatar: map['uploader_avatar'] as String?,
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
    required this.feedback,
    this.description,
    this.imageUrl,
    this.distanceMeters,
    this.reason,
    this.uploaderName,
    this.uploaderAvatar,
    this.comments = const [],
  });

  final String id;
  final String dishName;
  final String location;
  final double? price;
  final double? rating;
  final DateTime createdAt;
  final RecommendationAggregate aggregate;
  final RecommendationFeedbackSummary feedback;
  final String? description;
  final String? imageUrl;
  final double? distanceMeters;
  final String? reason;
  final String? uploaderName;
  final String? uploaderAvatar;
  final List<RecommendationComment> comments;

  RecommendationDetail copyWith({
    String? id,
    String? dishName,
    String? location,
    double? price,
    double? rating,
    DateTime? createdAt,
    RecommendationAggregate? aggregate,
    RecommendationFeedbackSummary? feedback,
    String? description,
    String? imageUrl,
    double? distanceMeters,
    String? reason,
    String? uploaderName,
    String? uploaderAvatar,
    List<RecommendationComment>? comments,
  }) {
    return RecommendationDetail(
      id: id ?? this.id,
      dishName: dishName ?? this.dishName,
      location: location ?? this.location,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      aggregate: aggregate ?? this.aggregate,
      feedback: feedback ?? this.feedback,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      reason: reason ?? this.reason,
      uploaderName: uploaderName ?? this.uploaderName,
      uploaderAvatar: uploaderAvatar ?? this.uploaderAvatar,
      comments: comments ?? this.comments,
    );
  }

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
      feedback: RecommendationFeedbackSummary.fromMap(
        map['feedback'] as Map<String, Object?>? ?? const {},
      ),
      description: map['description'] as String? ?? map['comment'] as String?,
      imageUrl: map['image_url'] as String?,
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      reason: map['reason'] as String?,
      uploaderName: map['uploader_name'] as String?,
      uploaderAvatar: map['uploader_avatar'] as String?,
      comments: (map['comments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(RecommendationComment.fromMap)
          .toList(),
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
