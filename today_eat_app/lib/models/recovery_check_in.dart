String recoveryDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class RecoveryCheckInDraft {
  const RecoveryCheckInDraft({
    required this.date,
    required this.sleepQuality,
    required this.fatigue,
    required this.soreness,
    required this.energy,
    this.note,
  });

  final DateTime date;
  final int sleepQuality;
  final int fatigue;
  final int soreness;
  final int energy;
  final String? note;

  void validate() {
    final values = [sleepQuality, fatigue, soreness, energy];
    if (values.any((value) => value < 1 || value > 5)) {
      throw const FormatException('恢复评分必须在 1 到 5 之间');
    }
  }
}

class RecoveryCheckIn {
  const RecoveryCheckIn({
    this.id,
    required this.localDate,
    required this.sleepQuality,
    required this.fatigue,
    required this.soreness,
    required this.energy,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final int? id;
  final String localDate;
  final int sleepQuality;
  final int fatigue;
  final int soreness;
  final int energy;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'local_date': localDate,
    'sleep_quality': sleepQuality,
    'fatigue': fatigue,
    'soreness': soreness,
    'energy': energy,
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory RecoveryCheckIn.fromMap(Map<String, Object?> map) {
    return RecoveryCheckIn(
      id: (map['id'] as num?)?.toInt(),
      localDate: map['local_date'] as String,
      sleepQuality: (map['sleep_quality'] as num).toInt(),
      fatigue: (map['fatigue'] as num).toInt(),
      soreness: (map['soreness'] as num).toInt(),
      energy: (map['energy'] as num).toInt(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

abstract interface class RecoveryStore {
  Future<Map<String, Object?>?> fetchRecoveryCheckIn(String localDate);

  Future<void> upsertRecoveryCheckIn(Map<String, Object?> values);
}
