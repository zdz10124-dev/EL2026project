import 'package:flutter_test/flutter_test.dart';
import 'package:today_eat_app/models/agent_action.dart';
import 'package:today_eat_app/services/agent_plan_parser.dart';

void main() {
  final context = AgentPlanParseContext(
    date: DateTime(2026, 7, 25),
    dataFingerprint: 'fingerprint',
    allowedEvidence: const {'今日疲劳评分 4/5', '今日尚未记录饮食'},
    source: AgentPlanSource.ai,
  );

  test('rejects actions whose evidence is not allowed', () {
    expect(
      () => parseAgentPlan(_action(evidence: ['模型自己推断的依据']), context),
      throwsFormatException,
    );
  });

  test('rejects unknown action target instead of defaulting', () {
    expect(
      () => parseAgentPlan(_action(target: 'openUnknown'), context),
      throwsFormatException,
    );
  });

  test('rejects medical claims', () {
    expect(
      () => parseAgentPlan(_action(action: '建议治疗并用药'), context),
      throwsFormatException,
    );
  });

  test('keeps at most three valid actions ordered by priority', () {
    final plan = parseAgentPlan({
      'summary': '今日先恢复，再完成必要记录。',
      'actions': [
        _rawAction(priority: 'low', title: '低优先级'),
        _rawAction(priority: 'high', title: '高优先级'),
        _rawAction(priority: 'medium', title: '中优先级'),
        _rawAction(priority: 'low', title: '额外行动'),
      ],
    }, context);

    expect(plan.actions, hasLength(3));
    expect(plan.actions.first.title, '高优先级');
    expect(plan.actions.first.status, AgentActionStatus.pending);
  });
}

Map<String, dynamic> _action({
  List<String>? evidence,
  String? target,
  String? action,
}) => {
      'summary': '今日先恢复，再完成必要记录。',
      'actions': [
        _rawAction(
          evidence: evidence,
          target: target,
          action: action,
        ),
      ],
    };

Map<String, dynamic> _rawAction({
  String priority = 'high',
  String title = '安排恢复',
  List<String>? evidence,
  String? target,
  String? action,
}) => {
      'category': 'rest',
      'priority': priority,
      'title': title,
      'action': action ?? '今晚安排 15 分钟舒缓活动。',
      'evidence': evidence ?? ['今日疲劳评分 4/5'],
      'target': target ?? 'recoveryCheckIn',
    };
