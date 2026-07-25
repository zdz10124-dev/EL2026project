import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/exercise_draft.dart';
import '../models/exercise_record.dart';
import 'database_service.dart';
import 'exercise_validator.dart';

class ExerciseRepository {
  ExerciseRepository({
    DatabaseService? databaseService,
    ImagePicker? imagePicker,
    Future<void> Function()? onHealthDataChanged,
  })
      : _database = databaseService ?? DatabaseService.instance,
        _imagePicker = imagePicker ?? ImagePicker(),
        _onHealthDataChanged = onHealthDataChanged;

  final DatabaseService _database;
  final ImagePicker _imagePicker;
  final Future<void> Function()? _onHealthDataChanged;
  final _records = StreamController<List<ExerciseRecord>>.broadcast();
  final _random = Random();

  Stream<List<ExerciseRecord>> get recordsStream async* {
    yield await fetchRecords();
    yield* _records.stream;
  }

  Future<void> initialize() => refresh();

  Future<void> refresh() async => _records.add(await fetchRecords());

  Future<List<ExerciseRecord>> fetchRecords() => _database.fetchExerciseRecords();

  Future<XFile?> captureFromCamera() =>
      _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);

  Future<List<XFile>> pickFromGallery() =>
      _imagePicker.pickMultiImage(limit: 4, imageQuality: 85);

  Future<ExerciseRecord> saveDraft(ExerciseDraft draft) async {
    final errors = validateExerciseDraft(draft);
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    final now = DateTime.now();
    final paths = <String>[];
    for (final source in draft.imagePaths.take(4)) {
      paths.add(await _copyImage(source));
    }
    final record = ExerciseRecord(
      clientRecordId:
          'exercise_${now.microsecondsSinceEpoch}_${_random.nextInt(1 << 32).toRadixString(16)}',
      activityType: draft.activityType,
      startedAt: draft.startedAt,
      durationSeconds: draft.durationSeconds,
      distanceMeters: draft.distanceMeters,
      averageHeartRateBpm: draft.averageHeartRateBpm,
      peakHeartRateBpm: draft.peakHeartRateBpm,
      caloriesKcal: draft.caloriesKcal,
      rpe: draft.rpe,
      note: draft.note?.trim(),
      detail: draft.detail,
      imagePaths: paths,
      source: draft.source,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _database.insertExerciseRecord(record);
    final saved = record.copyWith(id: id);
    await refresh();
    _notifyHealthDataChanged();
    return saved;
  }

  Future<void> updateRecord(ExerciseRecord record) async {
    if (record.id == null) throw const FormatException('运动记录缺少本地 ID');
    await _database.updateExerciseRecord(record.copyWith(updatedAt: DateTime.now()));
    await refresh();
    _notifyHealthDataChanged();
  }

  Future<void> deleteRecord(ExerciseRecord record) async {
    if (record.id != null) await _database.deleteExerciseRecord(record.id!);
    for (final path in record.imagePaths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await refresh();
    _notifyHealthDataChanged();
  }

  Future<void> deleteAllRecords() async {
    final records = await fetchRecords();
    await _database.deleteAllExerciseRecords();
    await _database.deleteAllHealthAnalysisCache();
    for (final record in records) {
      for (final path in record.imagePaths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
    await refresh();
  }

  Future<String> _copyImage(String source) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'exercise_images'));
    if (!await directory.exists()) await directory.create(recursive: true);
    final extension = p.extension(source).isEmpty ? '.jpg' : p.extension(source);
    final target = p.join(
      directory.path,
      'exercise_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    return (await File(source).copy(target)).path;
  }

  void dispose() => _records.close();

  void _notifyHealthDataChanged() {
    final callback = _onHealthDataChanged;
    if (callback != null) unawaited(callback());
  }
}
