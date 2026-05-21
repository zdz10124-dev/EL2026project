import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_model.dart';
import '../providers/course_provider.dart';
import '../theme/app_theme.dart';

/// 课程详情页面
class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late TextEditingController _regularController;
  late TextEditingController _midtermController;
  late TextEditingController _finalController;
  late TextEditingController _regularWeightController;
  late TextEditingController _midtermWeightController;
  late TextEditingController _finalWeightController;
  late TextEditingController _skipDeductionController;

  @override
  void initState() {
    super.initState();
    final course = context.read<CourseProvider>().courses.firstWhere(
          (c) => c.id == widget.courseId,
          orElse: () => CourseModel(id: '', name: '', teacher: ''),
        );

    _regularController =
        TextEditingController(text: course.regularScore?.toString() ?? '');
    _midtermController =
        TextEditingController(text: course.midtermScore?.toString() ?? '');
    _finalController =
        TextEditingController(text: course.finalScore?.toString() ?? '');
    _regularWeightController = TextEditingController(
        text: (course.regularWeight * 100).toStringAsFixed(0));
    _midtermWeightController = TextEditingController(
        text: (course.midtermWeight * 100).toStringAsFixed(0));
    _finalWeightController = TextEditingController(
        text: (course.finalWeight * 100).toStringAsFixed(0));
    _skipDeductionController =
        TextEditingController(text: course.skipDeduction.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _regularController.dispose();
    _midtermController.dispose();
    _finalController.dispose();
    _regularWeightController.dispose();
    _midtermWeightController.dispose();
    _finalWeightController.dispose();
    _skipDeductionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CourseProvider>(
      builder: (context, courseProvider, _) {
        final course = courseProvider.courses.firstWhere(
          (c) => c.id == widget.courseId,
          orElse: () => CourseModel(id: '', name: '课程未找到', teacher: ''),
        );

        if (course.id.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('课程详情')),
            body: const Center(child: Text('课程未找到')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(course.name),
            actions: [
              IconButton(
                icon: Icon(
                  course.isImportant ? Icons.flag : Icons.flag_outlined,
                  color: course.isImportant ? AppTheme.accentColor : null,
                ),
                onPressed: () => courseProvider.toggleImportant(course.id),
                tooltip: course.isImportant ? '取消重要标记' : '标记为重要',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 课程基本信息卡片
                _buildInfoCard(course),
                const SizedBox(height: 16),

                // 翘课记录
                _buildSkipSection(course, courseProvider),
                const SizedBox(height: 16),

                // 分数追踪
                _buildScoreSection(course, courseProvider),
                const SizedBox(height: 16),

                // 权重配置
                if (course.scoreTrackingEnabled)
                  _buildWeightSection(course, courseProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(CourseModel course) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    course.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            _infoRow(Icons.person_outline, '教师', course.teacher),
            _infoRow(
                Icons.location_on_outlined, '教室', course.classroom ?? '未指定'),
            _infoRow(Icons.access_time, '时间',
                '${course.weekday ?? "未知"} ${course.startTime ?? ""}-${course.endTime ?? ""}'),
            _infoRow(Icons.grade_outlined, '学分', '${course.credit} 学分'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSkipSection(CourseModel course, CourseProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.logout, color: AppTheme.warningColor),
                const SizedBox(width: 8),
                const Text(
                  '翘课记录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (course.isSkipWarning)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '⚠ 预警',
                      style: TextStyle(
                        color: AppTheme.dangerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '已翘课 ${course.skipCount} 次',
                  style: TextStyle(
                    fontSize: 16,
                    color: course.isSkipWarning ? AppTheme.dangerColor : null,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => provider.recordSkip(course.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('记录翘课'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            if (course.isSkipWarning)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '翘课已达 $course.skipCount 次，已达到预警阈值！建议按时上课。',
                  style: const TextStyle(
                      color: AppTheme.dangerColor, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSection(CourseModel course, CourseProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.score, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '分数追踪',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: course.scoreTrackingEnabled,
                  onChanged: (_) => provider.toggleScoreTracking(course.id),
                ),
              ],
            ),
            if (course.scoreTrackingEnabled) ...[
              const Divider(),
              // 加权平均分显示
              Center(
                child: Column(
                  children: [
                    Text(
                      course.weightedAverageScore.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color:
                            AppTheme.getScoreColor(course.weightedAverageScore),
                      ),
                    ),
                    Text(
                      '加权平均分 · ${course.scoreStatus}',
                      style: TextStyle(
                        color:
                            AppTheme.getScoreColor(course.weightedAverageScore),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 分数输入
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _regularController,
                      decoration: const InputDecoration(
                        labelText: '平时分',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        provider.updateScores(
                          courseId: course.id,
                          regularScore: double.tryParse(value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _midtermController,
                      decoration: const InputDecoration(
                        labelText: '期中分',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        provider.updateScores(
                          courseId: course.id,
                          midtermScore: double.tryParse(value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _finalController,
                      decoration: const InputDecoration(
                        labelText: '期末分',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        provider.updateScores(
                          courseId: course.id,
                          finalScore: double.tryParse(value),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('开启分数追踪以查看加权平均分'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSection(CourseModel course, CourseProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  '权重配置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _regularWeightController,
                    decoration: const InputDecoration(
                      labelText: '平时占比 %',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final w = (double.tryParse(value) ?? 30) / 100;
                      provider.updateScoreWeights(
                        courseId: course.id,
                        regularWeight: w,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _midtermWeightController,
                    decoration: const InputDecoration(
                      labelText: '期中占比 %',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final w = (double.tryParse(value) ?? 30) / 100;
                      provider.updateScoreWeights(
                        courseId: course.id,
                        midtermWeight: w,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _finalWeightController,
                    decoration: const InputDecoration(
                      labelText: '期末占比 %',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final w = (double.tryParse(value) ?? 40) / 100;
                      provider.updateScoreWeights(
                        courseId: course.id,
                        finalWeight: w,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _skipDeductionController,
              decoration: const InputDecoration(
                labelText: '翘课扣分',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                provider.updateScoreWeights(
                  courseId: course.id,
                  skipDeduction: double.tryParse(value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
