import 'package:flutter/material.dart';

import '../models/agent_action.dart';
import 'section_card.dart';

class AgentActionCard extends StatelessWidget {
  const AgentActionCard({
    super.key,
    required this.action,
    required this.source,
    required this.onOpenEvidence,
    required this.onExecute,
    required this.onComplete,
    required this.onSkip,
    required this.onTooHard,
  });

  final AgentAction action;
  final AgentPlanSource source;
  final VoidCallback onOpenEvidence;
  final VoidCallback onExecute;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onTooHard;

  @override
  Widget build(BuildContext context) {
    final pending = action.status == AgentActionStatus.pending;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(action.category)),
              const SizedBox(width: 8),
              Text('今日主行动', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              _SourceChip(source: source),
            ],
          ),
          const SizedBox(height: 12),
          Text(action.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(action.action),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onOpenEvidence,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('查看依据'),
          ),
          if (pending) ...[
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: onExecute,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('去执行'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onComplete, child: const Text('完成')),
                TextButton(onPressed: onSkip, child: const Text('跳过')),
                TextButton(onPressed: onTooHard, child: const Text('太难了')),
              ],
            ),
          ] else
            Text('状态：${_statusText(action.status)}'),
        ],
      ),
    );
  }

  IconData _iconFor(AgentActionCategory category) => switch (category) {
    AgentActionCategory.diet => Icons.restaurant_outlined,
    AgentActionCategory.exercise => Icons.directions_run,
    AgentActionCategory.rest => Icons.bedtime_outlined,
  };

  String _statusText(AgentActionStatus status) => switch (status) {
    AgentActionStatus.pending => '待完成',
    AgentActionStatus.completed => '已完成',
    AgentActionStatus.skipped => '已跳过',
    AgentActionStatus.expired => '已过期',
  };
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});
  final AgentPlanSource source;

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(source == AgentPlanSource.ai ? 'AI 计划' : '本地行动'),
  );
}
