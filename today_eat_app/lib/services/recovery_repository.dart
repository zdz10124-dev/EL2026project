import 'dart:async';

import '../models/recovery_check_in.dart';
import 'database_service.dart';

class RecoveryRepository {
  RecoveryRepository({RecoveryStore? store})
    : _store = store ?? DatabaseService.instance;

  final RecoveryStore _store;
  final Map<String, StreamController<RecoveryCheckIn?>> _controllers = {};

  Future<RecoveryCheckIn?> findByDate(DateTime date) async {
    final map = await _store.fetchRecoveryCheckIn(recoveryDateKey(date));
    return map == null ? null : RecoveryCheckIn.fromMap(map);
  }

  Future<RecoveryCheckIn> save(RecoveryCheckInDraft draft) async {
    draft.validate();
    final now = DateTime.now();
    final localDate = recoveryDateKey(draft.date);
    final existing = await findByDate(draft.date);
    final record = RecoveryCheckIn(
      id: existing?.id,
      localDate: localDate,
      sleepQuality: draft.sleepQuality,
      fatigue: draft.fatigue,
      soreness: draft.soreness,
      energy: draft.energy,
      note: _nullableText(draft.note),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _store.upsertRecoveryCheckIn(record.toMap());
    _controllers[localDate]?.add(record);
    return record;
  }

  Stream<RecoveryCheckIn?> watchDate(DateTime date) {
    final localDate = recoveryDateKey(date);
    final controller = _controllers.putIfAbsent(
      localDate,
      () => StreamController<RecoveryCheckIn?>.broadcast(),
    );
    unawaited(_emitInitialValue(controller, date));
    return controller.stream;
  }

  Future<void> _emitInitialValue(
    StreamController<RecoveryCheckIn?> controller,
    DateTime date,
  ) async {
    final value = await findByDate(date);
    if (!controller.isClosed) {
      controller.add(value);
    }
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
