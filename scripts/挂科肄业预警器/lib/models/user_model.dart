/// 用户模型
class UserModel {
  final String id;
  final String studentId;
  final String name;
  final String? avatarUrl;
  final String? major;
  final String? grade;
  final String? department;
  final bool isLoggedIn;

  UserModel({
    required this.id,
    required this.studentId,
    required this.name,
    this.avatarUrl,
    this.major,
    this.grade,
    this.department,
    this.isLoggedIn = false,
  });

  /// 从 JSON 创建
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      major: json['major'] as String?,
      grade: json['grade'] as String?,
      department: json['department'] as String?,
      isLoggedIn: json['is_logged_in'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'name': name,
      'avatar_url': avatarUrl,
      'major': major,
      'grade': grade,
      'department': department,
      'is_logged_in': isLoggedIn,
    };
  }

  /// 创建空用户（未登录状态）
  static UserModel empty() {
    return UserModel(
      id: '',
      studentId: '',
      name: '',
      isLoggedIn: false,
    );
  }

  /// 复制并修改部分字段
  UserModel copyWith({
    String? id,
    String? studentId,
    String? name,
    String? avatarUrl,
    String? major,
    String? grade,
    String? department,
    bool? isLoggedIn,
  }) {
    return UserModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      major: major ?? this.major,
      grade: grade ?? this.grade,
      department: department ?? this.department,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}
