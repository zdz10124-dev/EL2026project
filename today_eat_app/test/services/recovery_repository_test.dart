import 'package:flutter_test/flutter_test.dart';

import 'package:today_eat_app/models/recovery_check_in.dart';
import 'package:today_eat_app/services/recovery_repository.dart';

void main() {
  group('RecoveryCheckInDraft', () {
    test('rejects ratings outside 1 to 5', () {
      final draft = RecoveryCheckInDraft(
        date: DateTime(2026, 7, 25),
        sleepQuality: 0,
        fatigue: 3,
        soreness: 2,
        energy: 4,
      );

      expect(draft.validate, throwsFormatException);
    });
  });

  group('RecoveryRepository', () {
    late _FakeRecoveryStore store;
    late RecoveryRepository repository;

    setUp(() {
      store = _FakeRecoveryStore();
      repository = RecoveryRepository(store: store);
    });

    test('saving twice on the same local date updates one record', () async {
      await repository.save(
        RecoveryCheckInDraft(
          date: DateTime(2026, 7, 25),
          sleepQuality: 3,
          fatigue: 3,
          soreness: 2,
          energy: 3,
        ),
      );
      await repository.save(
        RecoveryCheckInDraft(
          date: DateTime(2026, 7, 25, 21),
          sleepQuality: 4,
          fatigue: 2,
          soreness: 1,
          energy: 4,
        ),
      );

      final saved = await repository.findByDate(DateTime(2026, 7, 25));
      expect(saved!.sleepQuality, 4);
      expect(store.values, hasLength(1));
    });

    test('watchDate emits the saved value', () async {
      final values = <RecoveryCheckIn?>[];
      final subscription = repository
          .watchDate(DateTime(2026, 7, 25))
          .listen(values.add);

      await repository.save(
        RecoveryCheckInDraft(
          date: DateTime(2026, 7, 25),
          sleepQuality: 3,
          fatigue: 3,
          soreness: 2,
          energy: 3,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(values.last!.localDate, '2026-07-25');
      await subscription.cancel();
    });
  });
}

class _FakeRecoveryStore implements RecoveryStore {
  final Map<String, Map<String, Object?>> values = {};

  @override
  Future<Map<String, Object?>?> fetchRecoveryCheckIn(String localDate) async =>
      values[localDate];

  @override
  Future<void> upsertRecoveryCheckIn(Map<String, Object?> value) async {
    values[value['local_date']! as String] = value;
  }
}
