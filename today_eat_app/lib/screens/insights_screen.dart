import 'package:flutter/material.dart';

import '../models/meal_record.dart';
import '../models/ui_config.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({
    super.key,
    required this.config,
    required this.repository,
  });

  final UiConfig config;
  final MealRepository repository;

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
                const SizedBox(height: 8),
                const Text('先把可立即落地的统计做起来，AI 分析与联网推荐后续可以在这里继续扩展。'),
                const SizedBox(height: 18),
                ...stats.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SectionCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
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
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('后续预留'),
                      SizedBox(height: 8),
                      Text('1. AI 提取菜系、食材、辣度并生成营养分析。'),
                      Text('2. 联网拉取高评分菜品做推荐。'),
                      Text('3. 生成每日日记或周期报告。'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
