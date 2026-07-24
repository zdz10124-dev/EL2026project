import 'package:flutter/material.dart';

import '../../models/agent_action.dart';
import '../../services/agent_action_repository.dart';
import '../../widgets/themed_page_background.dart';

class AgentHistoryScreen extends StatelessWidget {
  const AgentHistoryScreen({super.key, required this.repository});
  final AgentActionRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('Agent 行动记录')),
    body: ThemedPageBackground(
      child: FutureBuilder<List<AgentAction>>(
        future: repository.fetchActionsSince(DateTime.now().subtract(const Duration(days: 7))),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final actions = snapshot.data!;
          final completed = actions.where((item) => item.status == AgentActionStatus.completed).length;
          final skipped = actions.where((item) => item.status == AgentActionStatus.skipped).length;
          final hard = actions.where((item) => item.difficulty == AgentActionDifficulty.tooHard).length;
          return ListView(children: [
            Padding(padding: const EdgeInsets.all(16), child: Text('完成 $completed · 跳过 $skipped · 太难 $hard')),
            ...actions.map((item) => ListTile(title: Text(item.title), subtitle: Text(item.action), trailing: Text(item.status.name))),
          ]);
        },
      ),
    ),
  );
}
