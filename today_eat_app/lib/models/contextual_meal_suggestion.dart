import 'agent_action.dart';
import 'meal_record.dart';

class ContextualMealSuggestion {
  const ContextualMealSuggestion({
    required this.title,
    required this.reason,
    required this.evidence,
    required this.source,
    this.sourceRecord,
  });

  final String title;
  final String reason;
  final List<String> evidence;
  final AgentPlanSource source;
  final MealRecord? sourceRecord;
}
