import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/exercise_record.dart';
import '../../services/exercise_repository.dart';
import '../../services/health_agent_service.dart';
import '../../widgets/section_card.dart';
import '../../widgets/themed_page_background.dart';
import 'exercise_editor_screen.dart';

class ExerciseRecordsScreen extends StatelessWidget {
  const ExerciseRecordsScreen({
    super.key,
    required this.repository,
    required this.agentService,
    this.embedded = false,
  });

  final ExerciseRepository repository;
  final HealthAgentService agentService;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = ThemedPageBackground(
      child: StreamBuilder<List<ExerciseRecord>>(
        stream: repository.recordsStream,
        initialData: const [],
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <ExerciseRecord>[];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Text('运动记录', style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('记录运动'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                const SectionCard(
                  child: Text('还没有运动记录。可以手动填写，也可以上传运动 App 截图识别。'),
                )
              else
                ...records.map((record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ExerciseCard(
                        record: record,
                        onEdit: () => _openEditor(context, record),
                        onDelete: () => _delete(context, record),
                      ),
                    )),
            ],
          );
        },
      ),
    );
    if (embedded) return body;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('运动记录')),
      body: body,
    );
  }

  Future<void> _openEditor(BuildContext context, [ExerciseRecord? record]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ExerciseEditorScreen(
        repository: repository,
        agentService: agentService,
        existingRecord: record,
      ),
    ));
  }

  Future<void> _delete(BuildContext context, ExerciseRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除运动记录'),
        content: const Text('记录及其本地截图将被删除，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) await repository.deleteRecord(record);
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });
  final ExerciseRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      '${(record.durationSeconds / 60).round()} 分钟',
      if (record.distanceMeters != null)
        '${(record.distanceMeters! / 1000).toStringAsFixed(2)} km',
      if (record.averageHeartRateBpm != null) '均心 ${record.averageHeartRateBpm} bpm',
      if (record.rpe != null) 'RPE ${record.rpe}',
    ];
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(_icon(record.activityType))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.activityType.label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(details.join(' · ')),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MM-dd HH:mm').format(record.startedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (record.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(record.note!),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }

  IconData _icon(ActivityType type) => switch (type) {
        ActivityType.running => Icons.directions_run,
        ActivityType.swimming => Icons.pool,
        ActivityType.cycling => Icons.directions_bike,
        ActivityType.walking => Icons.directions_walk,
        ActivityType.other => Icons.fitness_center,
      };
}
