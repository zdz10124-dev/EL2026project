/// 毕业要求模型
class GraduationRequirement {
  final String id;
  final String name;
  final String category; // 总学分、体育学分、通识学分、志愿时长等
  final double requiredAmount; // 要求总量
  final double completedAmount; // 已完成量
  final String unit; // 单位（学分、小时）

  GraduationRequirement({
    required this.id,
    required this.name,
    required this.category,
    required this.requiredAmount,
    this.completedAmount = 0,
    this.unit = '学分',
  });

  /// 完成进度 (0.0 ~ 1.0)
  double get progress {
    if (requiredAmount == 0) return 0;
    return (completedAmount / requiredAmount).clamp(0.0, 1.0);
  }

  /// 是否已完成
  bool get isCompleted => completedAmount >= requiredAmount;

  /// 剩余量
  double get remaining => (requiredAmount - completedAmount).clamp(0, requiredAmount);

  /// 从 JSON 创建
  factory GraduationRequirement.fromJson(Map<String, dynamic> json) {
    return GraduationRequirement(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      requiredAmount: (json['required_amount'] as num).toDouble(),
      completedAmount: (json['completed_amount'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '学分',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'required_amount': requiredAmount,
      'completed_amount': completedAmount,
      'unit': unit,
    };
  }

  /// 复制并修改
  GraduationRequirement copyWith({
    String? id,
    String? name,
    String? category,
    double? requiredAmount,
    double? completedAmount,
    String? unit,
  }) {
    return GraduationRequirement(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      requiredAmount: requiredAmount ?? this.requiredAmount,
      completedAmount: completedAmount ?? this.completedAmount,
      unit: unit ?? this.unit,
    );
  }
}

/// 毕业进度总览模型
class GraduationOverview {
  final double totalRequiredCredits; // 总要求学分
  final double totalCompletedCredits; // 总已完成学分
  final double currentSemesterAverage; // 当前学期平均分
  final double idealAverageScore; // 理想情况下平均分
  final List<GraduationRequirement> requirements; // 各项要求

  GraduationOverview({
    this.totalRequiredCredits = 160,
    this.totalCompletedCredits = 0,
    this.currentSemesterAverage = 0,
    this.idealAverageScore = 80,
    this.requirements = const [],
  });

  /// 总学分进度
  double get totalProgress {
    if (totalRequiredCredits == 0) return 0;
    return (totalCompletedCredits / totalRequiredCredits).clamp(0.0, 1.0);
  }

  /// 从 JSON 创建
  factory GraduationOverview.fromJson(Map<String, dynamic> json) {
    return GraduationOverview(
      totalRequiredCredits: (json['total_required_credits'] as num?)?.toDouble() ?? 160,
      totalCompletedCredits: (json['total_completed_credits'] as num?)?.toDouble() ?? 0,
      currentSemesterAverage: (json['current_semester_average'] as num?)?.toDouble() ?? 0,
      idealAverageScore: (json['ideal_average_score'] as num?)?.toDouble() ?? 80,
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((e) => GraduationRequirement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'total_required_credits': totalRequiredCredits,
      'total_completed_credits': totalCompletedCredits,
      'current_semester_average': currentSemesterAverage,
      'ideal_average_score': idealAverageScore,
      'requirements': requirements.map((e) => e.toJson()).toList(),
    };
  }
}
