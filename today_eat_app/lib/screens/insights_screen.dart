import 'package:flutter/material.dart';

import '../models/meal_record.dart';
import '../models/ui_config.dart';
import '../services/agent_service.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';
import 'diary_screen.dart';
import 'nutrition_screen.dart';
import 'preference_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({
    super.key,
    required this.config,
    required this.repository,
    this.agentService,
  });

  final UiConfig config;
  final MealRepository repository;
  final AgentService? agentService;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: config.layout.pageHorizontalPadding,
          vertical: config.layout.pageVerticalPadding,
        ),
        child: StreamBuilder<List<MealRecord>>(
          stream: repository.recordsStream,
          initialData: const [],
          builder: (context, snapshot) {
            final records = snapshot.data ?? const [];
            final stats = repository.summarizeStats(records);
            return ListView(
              children: [
                Text(
                  config.pages.insightTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),

                // ---- 功能入口卡片 ----
                _FeatureCard(
                  icon: Icons.auto_stories_outlined,
                  title: '美食日记',
                  subtitle: 'AI 为你生成每一天的吃饭故事',
                  color: Colors.amber,
                  onTap: agentService == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DiaryScreen(
                                repository: repository,
                                agentService: agentService!,
                              ),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.insights_outlined,
                  title: '统计分析',
                  subtitle: '金额、常吃菜品、常去地点等基础数据',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _StatsDetailScreen(records: records, stats: stats),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.restaurant_menu,
                  title: '营养分析',
                  subtitle: agentService?.isAvailable == true
                      ? 'AI 评估你的营养摄入'
                      : '需先配置 AI 模型',
                  color: Colors.green,
                  onTap: agentService == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NutritionScreen(
                                repository: repository,
                                agentService: agentService!,
                              ),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.language_outlined,
                  title: '联网推荐',
                  subtitle: '查看其他人吃过的高评分菜品',
                  color: Colors.purple,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('联网推荐功能正在开发中')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.person_outline,
                  title: '偏好分析',
                  subtitle: agentService?.isAvailable == true
                      ? 'AI 分析你的口味偏好'
                      : '需先配置 AI 模型',
                  color: Colors.orange,
                  onTap: agentService == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PreferenceScreen(
                                repository: repository,
                                agentService: agentService!,
                              ),
                            ),
                          );
                        },
                ),

                if (records.isEmpty) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '先记录几顿饭，再来看看这里的内容',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ===== 功能入口卡片 =====

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: onTap != null ? Colors.grey : Colors.grey.shade300),
        onTap: onTap,
      ),
    );
  }
}

// ===== 统计详情二级页面 =====

class _StatsDetailScreen extends StatelessWidget {
  const _StatsDetailScreen({
    required this.records,
    required this.stats,
  });

  final List<MealRecord> records;
  final Map<String, String> stats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('统计分析')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 总览统计
          ...stats.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (records.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('评分分布',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SectionCard(
              child: _RatingDistribution(records: records),
            ),
          ],

          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  '还没有记录',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingDistribution extends StatelessWidget {
  const _RatingDistribution({required this.records});
  final List<MealRecord> records;

  @override
  Widget build(BuildContext context) {
    final distribution = <int, int>{};
    for (final r in records) {
      if (r.ratingScore != null) {
        final bucket = r.ratingScore!.round();
        distribution[bucket] = (distribution[bucket] ?? 0) + 1;
      }
    }

    if (distribution.isEmpty) {
      return const Text('暂无评分数据');
    }

    final maxCount = distribution.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: List.generate(10, (i) {
        final score = 10 - i;
        final count = distribution[score] ?? 0;
        final ratio = maxCount > 0 ? count / maxCount : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text('$score 分',
                    style: const TextStyle(fontSize: 11)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 18,
                    backgroundColor: Colors.grey.shade100,
                    color: _barColor(score),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _barColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    if (score >= 4) return Colors.amber;
    return Colors.red;
  }
}
