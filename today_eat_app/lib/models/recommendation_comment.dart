class RecommendationComment {
  const RecommendationComment({
    required this.id,
    required this.recommendationId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.createdAt,
    this.isMine = false,
  });

  final String id;
  final String recommendationId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime createdAt;
  final bool isMine;

  factory RecommendationComment.fromMap(Map<String, Object?> map) {
    return RecommendationComment(
      id: map['id'] as String? ?? '',
      recommendationId: map['recommendation_id'] as String? ?? '',
      authorName: map['author_name'] as String? ?? '饭搭子',
      authorAvatar: map['author_avatar'] as String? ?? '🍜',
      content: map['content'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      isMine: map['is_mine'] == true,
    );
  }
}
