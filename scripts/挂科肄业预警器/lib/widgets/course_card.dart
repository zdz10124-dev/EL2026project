import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../theme/app_theme.dart';

/// 课程卡片组件
/// 用于在列表中显示课程信息
class CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 判断是否有预警
    final hasWarning = course.isSkipWarning || course.isFailWarning;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasWarning
            ? const BorderSide(color: AppTheme.dangerColor, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 左侧颜色标识
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: _getCourseColor(),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // 课程信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (course.isImportant)
                          const Icon(
                            Icons.flag,
                            color: AppTheme.accentColor,
                            size: 18,
                          ),
                        if (hasWarning)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.dangerColor,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.teacher,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${course.credit} 学分',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (course.weekday != null) ...[
                          const Text(' · ', style: TextStyle(color: Colors.grey)),
                          Text(
                            '${course.weekday} ${course.startTime ?? ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                        if (course.scoreTrackingEnabled) ...[
                          const Text(' · ', style: TextStyle(color: Colors.grey)),
                          Text(
                            '${course.weightedAverageScore.toStringAsFixed(1)}分',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getScoreColor(course.weightedAverageScore),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 右侧箭头
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// 根据课程状态获取颜色
  Color _getCourseColor() {
    if (course.isFailWarning) return AppTheme.dangerColor;
    if (course.isSkipWarning) return AppTheme.warningColor;
    if (course.isImportant) return AppTheme.accentColor;
    return AppTheme.primaryColor;
  }
}
