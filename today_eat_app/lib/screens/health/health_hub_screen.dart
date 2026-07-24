import 'package:flutter/material.dart';

import '../../models/style_presets.dart';
import '../../models/ui_config.dart';
import '../../services/agent_service.dart';
import '../../services/health_analysis_repository.dart';
import '../../services/health_profile_repository.dart';
import '../../services/meal_repository.dart';
import '../../services/agent_action_repository.dart';
import '../../widgets/section_card.dart';
import '../../widgets/themed_page_background.dart';
import '../insights_screen.dart';
import 'health_profile_screen.dart';
import 'integrated_health_screen.dart';
import 'agent_history_screen.dart';

class HealthHubScreen extends StatelessWidget {
  const HealthHubScreen({
    super.key,
    required this.config,
    required this.mealRepository,
    required this.mealAgentService,
    required this.analysisRepository,
    required this.profileRepository,
    required this.diaryStyleId,
    required this.agentActionRepository,
  });

  final UiConfig config;
  final MealRepository mealRepository;
  final AgentService mealAgentService;
  final HealthAnalysisRepository analysisRepository;
  final HealthProfileRepository profileRepository;
  final DiaryStyleId diaryStyleId;
  final AgentActionRepository agentActionRepository;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: config.layout.pageHorizontalPadding,
            vertical: config.layout.pageVerticalPadding,
          ),
          children: [
            Text('健康', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('基于饮食与运动记录生成有依据、可执行的健康建议。'),
            const SizedBox(height: 18),
            _HealthEntry(
              icon: Icons.monitor_heart_outlined,
              title: '综合健康分析',
              description: '汇总近 7 天或 30 天数据，给出饮食、运动与休息建议。',
              onTap: () => _open(
                context,
                IntegratedHealthScreen(repository: analysisRepository),
              ),
            ),
            const SizedBox(height: 12),
            _HealthEntry(
              icon: Icons.history_outlined,
              title: 'Agent 行动记录',
              description: '查看近七天行动完成、跳过和难度反馈。',
              onTap: () => _open(
                context,
                AgentHistoryScreen(repository: agentActionRepository),
              ),
            ),
            const SizedBox(height: 12),
            _HealthEntry(
              icon: Icons.flag_outlined,
              title: '健康目标与身体信息',
              description: '设置目标、可运动时间和可选身体数据，提高建议相关性。',
              onTap: () => _open(
                context,
                HealthProfileScreen(repository: profileRepository),
              ),
            ),
            const SizedBox(height: 12),
            _HealthEntry(
              icon: Icons.insights_outlined,
              title: '饮食洞察工具',
              description: '保留原有日记、统计、营养分析与联网推荐功能。',
              onTap: () => _open(
                context,
                Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(title: const Text('饮食洞察')),
                  body: ThemedPageBackground(
                    child: InsightsScreen(
                      config: config,
                      repository: mealRepository,
                      agentService: mealAgentService,
                      defaultDiaryStyleId: diaryStyleId,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const SectionCard(
              child: Text('健康分析仅用于生活方式参考，不替代医生诊断、治疗或紧急医疗建议。'),
            ),
          ],
        ),
      );

  Future<void> _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _HealthEntry extends StatelessWidget {
  const _HealthEntry({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SectionCard(
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(description),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
}
