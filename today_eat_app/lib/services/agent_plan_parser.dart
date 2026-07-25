import '../models/agent_action.dart';
import '../models/recovery_check_in.dart';

class AgentPlanParseContext {
  const AgentPlanParseContext({
    required this.date,
    required this.dataFingerprint,
    required this.allowedEvidence,
    required this.source,
  });

  final DateTime date;
  final String dataFingerprint;
  final Set<String> allowedEvidence;
  final AgentPlanSource source;
}

DailyAgentPlan parseAgentPlan(
  Map<String, dynamic> json,
  AgentPlanParseContext context,
) {
  final summary = json['summary']?.toString().trim() ?? '';
  if (summary.isEmpty || summary.length > 240) {
    throw const FormatException('AI 计划摘要无效');
  }
  final rawActions = json['actions'];
  if (rawActions is! List || rawActions.isEmpty) {
    throw const FormatException('AI 计划缺少行动');
  }
  final now = DateTime.now();
  final planDate = recoveryDateKey(context.date);
  final validUntil = DateTime(
    context.date.year,
    context.date.month,
    context.date.day + 1,
  );
  final actions = <AgentAction>[];
  for (final entry in rawActions) {
    if (entry is! Map) {
      throw const FormatException('AI 行动格式无效');
    }
    final raw = entry.cast<String, dynamic>();
    final title = raw['title']?.toString().trim() ?? '';
    final action = raw['action']?.toString().trim() ?? '';
    if (title.isEmpty || title.length > 40 || action.isEmpty || action.length > 160) {
      throw const FormatException('AI 行动文本无效');
    }
    if (_containsMedicalClaim('$title $action')) {
      throw const FormatException('AI 行动包含医疗诊断或治疗措辞');
    }
    final evidence = (raw['evidence'] as List? ?? const [])
        .map((value) => value.toString().trim())
        .where(context.allowedEvidence.contains)
        .toSet()
        .take(5)
        .toList();
    if (evidence.isEmpty) {
      throw const FormatException('AI 行动缺少可信依据');
    }
    actions.add(AgentAction(
      clientActionId: 'agent_${context.date.microsecondsSinceEpoch}_${actions.length}',
      planDate: planDate,
      category: _parseEnum(
        AgentActionCategory.values,
        raw['category'],
        '行动类别',
      ),
      priority: _parseEnum(
        AgentActionPriority.values,
        raw['priority'],
        '行动优先级',
      ),
      title: title,
      action: action,
      evidence: evidence,
      target: _parseEnum(
        AgentActionTarget.values,
        raw['target'],
        '行动目标',
      ),
      status: AgentActionStatus.pending,
      validUntil: validUntil,
      createdAt: now,
      updatedAt: now,
    ));
  }
  actions.sort((left, right) => _priorityWeight(right.priority)
      .compareTo(_priorityWeight(left.priority)));
  return DailyAgentPlan(
    localDate: planDate,
    dataFingerprint: context.dataFingerprint,
    summary: summary,
    actions: actions.take(3).toList(),
    generatedAt: now,
    source: context.source,
    needsRefresh: false,
  );
}

T _parseEnum<T extends Enum>(List<T> values, Object? raw, String field) {
  final value = raw?.toString();
  for (final item in values) {
    if (item.name == value) return item;
  }
  throw FormatException('AI 返回非法$field: $value');
}

int _priorityWeight(AgentActionPriority value) => switch (value) {
      AgentActionPriority.high => 3,
      AgentActionPriority.medium => 2,
      AgentActionPriority.low => 1,
    };

bool _containsMedicalClaim(String value) => RegExp(
      r'疾病|诊断|处方|治疗|药物|用药|住院|手术',
    ).hasMatch(value);
