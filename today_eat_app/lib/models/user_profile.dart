class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.avatarEmoji,
  });

  static const defaultAvatar = '🍜';
  static const defaultName = '匿名用户';

  final String displayName;
  final String avatarEmoji;

  UserProfile copyWith({
    String? displayName,
    String? avatarEmoji,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
    );
  }

  Map<String, String> toMap() {
    return {
      'display_name': displayName,
      'avatar_emoji': avatarEmoji,
    };
  }

  factory UserProfile.fromMap(Map<String, String?> map) {
    return UserProfile(
      displayName: _normalizedDisplayName(map['display_name']),
      avatarEmoji: _normalizedAvatarEmoji(map['avatar_emoji']),
    );
  }

  static String _normalizedDisplayName(String? source) {
    final value = source?.trim() ?? '';
    return value.isEmpty ? defaultName : value;
  }

  static String _normalizedAvatarEmoji(String? source) {
    final value = source?.trim() ?? '';
    return value.isEmpty ? defaultAvatar : value;
  }
}
