import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/graduation_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_card.dart';

/// 毕业进度页面
class GraduationProgressScreen extends StatelessWidget {
  const GraduationProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('毕业进度'),
      ),
      body: Consumer<GraduationProvider>(
        builder: (context, graduation, _) {
          final overview = graduation.overview;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 总学分进度
                ProgressCard(
                  title: '总学分进度',
                  progress: overview.totalProgress,
                  progressText: '${overview.totalCompletedCredits.toStringAsFixed(0)} / ${overview.totalRequiredCredits.toStringAsFixed(0)} 学分',
                  subtitle: '已完成 ${(overview.totalProgress * 100).toStringAsFixed(1)}%',
                  onTap: null,
                ),
                const SizedBox(height: 16),

                // 平均分对比
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '成绩概览',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ScoreIndicator(
                                label: '当前平均分',
                                score: overview.currentSemesterAverage,
                                icon: Icons.trending_up,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ScoreIndicator(
                                label: '理想平均分',
                                score: overview.idealAverageScore,
                                icon: Icons.flag,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 差距提示
                        Center(
                          child: Text(
                            _getAverageMessage(
                              overview.currentSemesterAverage,
                              overview.idealAverageScore,
                            ),
                            style: TextStyle(
                              color: AppTheme.getScoreColor(overview.currentSemesterAverage),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 各项要求进度
                const Text(
                  '各项要求进度',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // 各项进度列表
                ...overview.requirements.map((req) => _RequirementTile(
                  requirement: req,
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getAverageMessage(double current, double ideal) {
    if (current >= ideal) {
      return '🎉 当前平均分已达到理想目标！继续保持！';
    }
    final diff = ideal - current;
    return '💪 距离理想平均分还差 $diff 分，继续努力！';
  }
}

/// 分数指示器组件
class _ScoreIndicator extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;

  const _ScoreIndicator({
    required this.label,
    required this.score,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getScoreColor(score).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.getScoreColor(score), size: 28),
          const SizedBox(height: 8),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.getScoreColor(score),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单项要求进度组件
class _RequirementTile extends StatelessWidget {
  final dynamic requirement;

  const _RequirementTile({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final progress = requirement.progress as double;
    final color = AppTheme.getProgressColor(progress);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  requirement.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${requirement.completedAmount.toStringAsFixed(0)} / ${requirement.requiredAmount.toStringAsFixed(0)} ${requirement.unit}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '已完成 ${(progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
