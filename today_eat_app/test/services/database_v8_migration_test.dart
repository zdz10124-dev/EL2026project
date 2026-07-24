import 'package:flutter_test/flutter_test.dart';

import 'package:today_eat_app/services/database_service.dart';

void main() {
  test('database version 8 includes the agent tables', () {
    expect(DatabaseService.databaseVersion, 8);
    expect(
      DatabaseService.agentTableSql.join('\n'),
      contains('recovery_check_ins'),
    );
    expect(
      DatabaseService.agentTableSql.join('\n'),
      contains('daily_agent_plans'),
    );
    expect(DatabaseService.agentTableSql.join('\n'), contains('agent_actions'));
  });
}
