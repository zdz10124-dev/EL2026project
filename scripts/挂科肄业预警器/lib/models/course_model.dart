/// 课程模型
class CourseModel {
  final String id;
  final String name;
  final String teacher;
  final String? classroom;
  final String? weekday;
  final String? startTime;
  final String? endTime;
  final double credit;
  final String category; // 必修、选修、通识、体育等
  final bool isImportant;
  final int skipCount; // 翘课次数
  final double? regularScore; // 平时分
  final double? midtermScore; // 期中分
  final double? finalScore; // 期末分
  final double regularWeight; // 平时分占比
  final double midtermWeight; // 期中分占比
  final double finalWeight; // 期末分占比
  final double skipDeduction; // 翘课扣分
  final bool scoreTrackingEnabled; // 是否开启分数追踪

  CourseModel({
    required this.id,
    required this.name,
    required this.teacher,
    this.classroom,
    this.weekday,
    this.startTime,
    this.endTime,
    this.credit = 0,
    this.category = '必修',
    this.isImportant = false,
    this.skipCount = 0,
    this.regularScore,
    this.midtermScore,
    this.finalScore,
    this.regularWeight = 0.3,
    this.midtermWeight = 0.3,
    this.finalWeight = 0.4,
    this.skipDeduction = 5.0,
    this.scoreTrackingEnabled = false,
  });

  /// 计算加权平均分
  double get weightedAverageScore {
    if (!scoreTrackingEnabled) return 0;
    final r = (regularScore ?? 0) * regularWeight;
    final m = (midtermScore ?? 0) * midtermWeight;
    final f = (finalScore ?? 0) * finalWeight;
    final totalWeight = regularWeight + midtermWeight + finalWeight;
    if (totalWeight == 0) return 0;
    return (r + m + f) / totalWeight;
  }

  /// 是否触发翘课预警（翘课 >= 2 次）
  bool get isSkipWarning => skipCount >= 2;

  /// 是否触发挂科预警（加权平均分 < 60）
  bool get isFailWarning => scoreTrackingEnabled && weightedAverageScore < 60;

  /// 获取分数状态颜色标识
  String get scoreStatus {
    if (!scoreTrackingEnabled) return '未追踪';
    final score = weightedAverageScore;
    if (score < 60) return '危险';
    if (score < 70) return '警告';
    return '安全';
  }

  /// 从 JSON 创建
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      teacher: json['teacher'] as String,
      classroom: json['classroom'] as String?,
      weekday: json['weekday'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      credit: (json['credit'] as num).toDouble(),
      category: json['category'] as String? ?? '必修',
      isImportant: json['is_important'] as bool? ?? false,
      skipCount: json['skip_count'] as int? ?? 0,
      regularScore: (json['regular_score'] as num?)?.toDouble(),
      midtermScore: (json['midterm_score'] as num?)?.toDouble(),
      finalScore: (json['final_score'] as num?)?.toDouble(),
      regularWeight: (json['regular_weight'] as num?)?.toDouble() ?? 0.3,
      midtermWeight: (json['midterm_weight'] as num?)?.toDouble() ?? 0.3,
      finalWeight: (json['final_weight'] as num?)?.toDouble() ?? 0.4,
      skipDeduction: (json['skip_deduction'] as num?)?.toDouble() ?? 5.0,
      scoreTrackingEnabled: json['score_tracking_enabled'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'classroom': classroom,
      'weekday': weekday,
      'start_time': startTime,
      'end_time': endTime,
      'credit': credit,
      'category': category,
      'is_important': isImportant,
      'skip_count': skipCount,
      'regular_score': regularScore,
      'midterm_score': midtermScore,
      'final_score': finalScore,
      'regular_weight': regularWeight,
      'midterm_weight': midtermWeight,
      'final_weight': finalWeight,
      'skip_deduction': skipDeduction,
      'score_tracking_enabled': scoreTrackingEnabled,
    };
  }

  /// 复制并修改部分字段
  CourseModel copyWith({
    String? id,
    String? name,
    String? teacher,
    String? classroom,
    String? weekday,
    String? startTime,
    String? endTime,
    double? credit,
    String? category,
    bool? isImportant,
    int? skipCount,
    double? regularScore,
    double? midtermScore,
    double? finalScore,
    double? regularWeight,
    double? midtermWeight,
    double? finalWeight,
    double? skipDeduction,
    bool? scoreTrackingEnabled,
  }) {
    return CourseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      classroom: classroom ?? this.classroom,
      weekday: weekday ?? this.weekday,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      credit: credit ?? this.credit,
      category: category ?? this.category,
      isImportant: isImportant ?? this.isImportant,
      skipCount: skipCount ?? this.skipCount,
      regularScore: regularScore ?? this.regularScore,
      midtermScore: midtermScore ?? this.midtermScore,
      finalScore: finalScore ?? this.finalScore,
      regularWeight: regularWeight ?? this.regularWeight,
      midtermWeight: midtermWeight ?? this.midtermWeight,
      finalWeight: finalWeight ?? this.finalWeight,
      skipDeduction: skipDeduction ?? this.skipDeduction,
      scoreTrackingEnabled: scoreTrackingEnabled ?? this.scoreTrackingEnabled,
    );
  }
}
