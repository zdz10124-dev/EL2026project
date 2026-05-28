// 对外接口：
// - DecisionMode
// - StatsRangePreset
// - MealSuggestion
// - LocalDataSummary
// - JournalEntry
// - RecommendationSyncSummary
// - MealRepository.initialize
// - MealRepository.recordsStream
// - MealRepository.fetchRecords
// - MealRepository.captureFromCamera
// - MealRepository.pickFromGallery
// - MealRepository.consumeDraftIfFresh
// - MealRepository.cacheDraft
// - MealRepository.clearDraft
// - MealRepository.saveRecord
// - MealRepository.updateRecord
// - MealRepository.deleteRecord
// - MealRepository.deleteAllRecords
// - MealRepository.suggestMeal
// - MealRepository.filterRecords
// - MealRepository.buildJournalEntries
// - MealRepository.summarizeStats
// - MealRepository.buildDetailedStats
// - MealRepository.getLocalDataSummary
// - MealRepository.getPublicRecordsEnabled
// - MealRepository.setPublicRecordsEnabled
// - MealRepository.syncPublicRecords
// - MealRepository.searchRecommendations
// - MealRepository.fetchRecommendationDetail
// - MealRepository.dispose

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/meal_draft.dart';
import '../models/meal_record.dart';
import '../models/recommendation_models.dart';
import '../models/recommendation_upload_task.dart';
import 'app_settings_service.dart';
import 'database_service.dart';
import 'recommendation_api_service.dart';

enum DecisionMode { random, preference }

enum StatsRangePreset { last7Days, last30Days, custom }

class MealSuggestion {
  MealSuggestion({
    required this.title,
    required this.reason,
    this.sourceRecord,
  });

  final String title;
  final String reason;
  final MealRecord? sourceRecord;
}

class LocalDataSummary {
  const LocalDataSummary({
    required this.recordCount,
    required this.imageCount,
    required this.databaseBytes,
  });

  final int recordCount;
  final int imageCount;
  final int databaseBytes;
}

class JournalEntry {
  const JournalEntry({
    required this.dayStart,
    required this.records,
    required this.totalCost,
    required this.averageRating,
  });

  final DateTime dayStart;
  final List<MealRecord> records;
  final double totalCost;
  final double? averageRating;
}

class RecommendationSyncSummary {
  const RecommendationSyncSummary({
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    this.lastError,
  });

  final int successCount;
  final int failedCount;
  final int skippedCount;
  final String? lastError;

  bool get hasFailure => failedCount > 0;
}

class MealRepository {
  MealRepository({
    DatabaseService? databaseService,
    ImagePicker? imagePicker,
    AppSettingsService? appSettingsService,
    RecommendationApiService? recommendationApiService,
  }) : _databaseService = databaseService ?? DatabaseService.instance,
       _imagePicker = imagePicker ?? ImagePicker(),
       _appSettingsService = appSettingsService ?? AppSettingsService(),
       _recommendationApiService =
           recommendationApiService ?? RecommendationApiService();

  final DatabaseService _databaseService;
  final ImagePicker _imagePicker;
  final AppSettingsService _appSettingsService;
  final RecommendationApiService _recommendationApiService;
  final StreamController<List<MealRecord>> _recordsController =
      StreamController<List<MealRecord>>.broadcast();
  final Random _random = Random();

  MealDraft? _draft;
  bool _shouldUseDraftOnNextOpen = false;
  bool _publicRecordsEnabled = false;

  Stream<List<MealRecord>> get recordsStream => _recordsController.stream;

  Future<void> initialize() async {
    _publicRecordsEnabled = await _appSettingsService.getPublicRecordsEnabled();
    await refreshRecords();
  }

  Future<void> refreshRecords() async {
    final records = await _databaseService.fetchRecords();
    _recordsController.add(records);
  }

  Future<List<MealRecord>> fetchRecords() => _databaseService.fetchRecords();

  Future<XFile?> captureFromCamera() =>
      _imagePicker.pickImage(source: ImageSource.camera);

  Future<XFile?> pickFromGallery() =>
      _imagePicker.pickImage(source: ImageSource.gallery);

  MealDraft? consumeDraftIfFresh() {
    if (!_shouldUseDraftOnNextOpen) {
      return null;
    }

    _shouldUseDraftOnNextOpen = false;
    final cached = _draft;
    if (cached == null) {
      return null;
    }

    if (DateTime.now().difference(cached.updatedAt) >
        const Duration(minutes: 10)) {
      _draft = null;
      return null;
    }

    return cached;
  }

  void cacheDraft(MealDraft draft) {
    _draft = draft.hasContent ? draft.copyWith() : null;
    _shouldUseDraftOnNextOpen = _draft != null;
  }

  void clearDraft() {
    _draft = null;
    _shouldUseDraftOnNextOpen = false;
  }

  Future<void> saveRecord({
    required String sourceImagePath,
    required String dishNameInput,
    required String locationInput,
    required String priceText,
    required double? ratingScore,
    String? commentInput,
    String? province,
    String? city,
    String? district,
    double? latitude,
    double? longitude,
  }) async {
    final now = DateTime.now();
    final savedImagePath = await _copyImageToAppDir(sourceImagePath);
    final record = buildRecord(
      clientRecordId: _generateClientRecordId(now),
      createdAt: now,
      updatedAt: now,
      imagePath: savedImagePath,
      dishNameInput: dishNameInput,
      locationInput: locationInput,
      priceText: priceText,
      ratingScore: ratingScore,
      commentInput: commentInput,
      province: province,
      city: city,
      district: district,
      latitude: latitude,
      longitude: longitude,
    );

    final recordId = await _databaseService.insertRecord(record);
    final savedRecord = record.copyWith(id: recordId);
    await _databaseService.ensureUploadTasksForRecords([savedRecord]);
    clearDraft();
    await refreshRecords();
  }

  Future<void> updateRecord({
    required MealRecord original,
    required String dishNameInput,
    required String locationInput,
    required String priceText,
    required double? ratingScore,
    String? commentInput,
    String? province,
    String? city,
    String? district,
    double? latitude,
    double? longitude,
  }) async {
    final updated = buildRecord(
      id: original.id,
      clientRecordId: original.clientRecordId,
      createdAt: original.createdAt,
      updatedAt: DateTime.now(),
      imagePath: original.imagePath,
      dishNameInput: dishNameInput,
      locationInput: locationInput,
      priceText: priceText,
      ratingScore: ratingScore,
      commentInput: commentInput ?? original.comment,
      province: province ?? original.province,
      city: city ?? original.city,
      district: district ?? original.district,
      latitude: latitude ?? original.latitude,
      longitude: longitude ?? original.longitude,
    );
    await _databaseService.updateRecord(updated);
    if (updated.id != null) {
      await _databaseService.ensureUploadTasksForRecords([updated]);
    }
    await refreshRecords();
  }

  MealRecord buildRecord({
    int? id,
    required String clientRecordId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String imagePath,
    required String dishNameInput,
    required String locationInput,
    required String priceText,
    required double? ratingScore,
    String? commentInput,
    String? province,
    String? city,
    String? district,
    double? latitude,
    double? longitude,
  }) {
    final dishName = _fallbackText(dishNameInput);
    final location = _fallbackText(locationInput);
    final parsedPrice = double.tryParse(priceText.trim());
    final score = ratingScore == null ? null : ratingScore * 2;
    return MealRecord(
      id: id,
      clientRecordId: clientRecordId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      imagePath: imagePath,
      dishName: dishName,
      location: location,
      price: parsedPrice,
      ratingScore: score,
      ratingLabel: score == null
          ? '未打分'
          : '${score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1)}分',
      mainDish: dishName,
      comment: _nullableText(commentInput),
      province: _nullableText(province),
      city: _nullableText(city),
      district: _nullableText(district),
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> deleteRecord(MealRecord record) async {
    if (record.id != null) {
      await _databaseService.deleteRecord(record.id!);
      await _databaseService.deleteUploadTaskByRecordId(record.id!);
    }
    await _deleteImageIfExists(record.imagePath);
    await refreshRecords();
  }

  Future<void> deleteAllRecords() async {
    final records = await fetchRecords();
    await _databaseService.deleteAllRecords();
    for (final record in records) {
      await _deleteImageIfExists(record.imagePath);
    }
    await refreshRecords();
  }

  Future<bool> getPublicRecordsEnabled() async {
    _publicRecordsEnabled = await _appSettingsService.getPublicRecordsEnabled();
    return _publicRecordsEnabled;
  }

  Future<void> setPublicRecordsEnabled(bool value) async {
    _publicRecordsEnabled = value;
    await _appSettingsService.setPublicRecordsEnabled(value);
  }

  Future<RecommendationSyncSummary> syncPublicRecords() async {
    if (!_publicRecordsEnabled) {
      return const RecommendationSyncSummary(
        successCount: 0,
        failedCount: 0,
        skippedCount: 0,
      );
    }

    final records = await fetchRecords();
    await _databaseService.ensureUploadTasksForRecords(records);
    final tasks = await _databaseService.fetchUnsyncedUploadTasks();
    if (tasks.isEmpty) {
      return RecommendationSyncSummary(
        successCount: 0,
        failedCount: 0,
        skippedCount: records.isEmpty ? 0 : records.length,
      );
    }

    var successCount = 0;
    var failedCount = 0;
    String? lastError;

    for (final task in tasks) {
      final record = await _databaseService.fetchRecordById(task.recordId);
      if (record == null) {
        continue;
      }
      try {
        await _recommendationApiService.uploadRecord(record);
        await _databaseService.markUploadTaskSynced(
          clientRecordId: record.clientRecordId,
          recordUpdatedAt: record.updatedAt,
        );
        successCount++;
      } catch (error) {
        failedCount++;
        lastError = error.toString();
        await _databaseService.markUploadTaskFailed(
          clientRecordId: record.clientRecordId,
          error: lastError,
          status:
              error is RecommendationApiException && !error.shouldRetry
              ? RecommendationUploadTaskStatus.invalid
              : RecommendationUploadTaskStatus.failed,
        );
      }
    }

    return RecommendationSyncSummary(
      successCount: successCount,
      failedCount: failedCount,
      skippedCount: 0,
      lastError: lastError,
    );
  }

  Future<RecommendationSearchPage> searchRecommendations(
    RecommendationQuery query,
  ) {
    return _recommendationApiService.searchRecommendations(query);
  }

  Future<RecommendationDetail> fetchRecommendationDetail(String id) {
    return _recommendationApiService.fetchRecommendationDetail(id);
  }

  List<RecommendationItem> getMockRecommendations() => const [];

  Future<void> _deleteImageIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> _copyImageToAppDir(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, 'meal_images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath);
    final filename = 'meal_${DateTime.now().millisecondsSinceEpoch}$extension';
    final target = File(p.join(imageDir.path, filename));
    if (File(sourcePath).absolute.path == target.absolute.path) {
      return target.path;
    }
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Future<MealSuggestion> suggestMeal(DecisionMode mode) async {
    final records = await _databaseService.fetchRecords();
    final candidates = records
        .where((record) => record.mainDish.trim().isNotEmpty)
        .toList();

    if (candidates.isEmpty) {
      return MealSuggestion(
        title: '先记一顿饭吧',
        reason: '你还没有历史记录，拍下今天的美食后，这里就能开始推荐。',
      );
    }

    if (mode == DecisionMode.random) {
      final record = candidates[_random.nextInt(candidates.length)];
      return MealSuggestion(
        title: record.mainDish,
        reason: '随机模式会从你记录过的主菜里抽一个，今天先少纠结一点。',
        sourceRecord: record,
      );
    }

    final currentSlot = DateTime.now().hour < 15 ? 'lunch' : 'dinner';
    final scores = <String, double>{};
    final groupedRecords = <String, List<MealRecord>>{};

    for (final record in candidates) {
      final dishKey = _normalizeDishKey(record.mainDish);
      final recordSlot = record.createdAt.hour < 15 ? 'lunch' : 'dinner';
      var weight = 1.0;
      if (recordSlot == currentSlot) {
        weight += 1.4;
      }
      if (record.ratingScore != null) {
        weight += record.ratingScore! / 10;
      }

      scores[dishKey] = (scores[dishKey] ?? 0) + weight;
      groupedRecords.putIfAbsent(dishKey, () => []).add(record);
    }

    final selectedDishKey = _pickWeightedDish(scores);
    final recordsForDish = groupedRecords[selectedDishKey]!;
    final sourceRecord = recordsForDish[_random.nextInt(recordsForDish.length)];
    final selectedWeight = scores[selectedDishKey]!;

    return MealSuggestion(
      title: sourceRecord.mainDish,
      reason:
          '偏好模式会把相近时段更常吃、评分更高的记录累加成权重，再按权重随机抽取。'
          '这次抽到“${sourceRecord.mainDish}”，累计权重 ${selectedWeight.toStringAsFixed(1)}，'
          '共参考 ${recordsForDish.length} 条同菜品记录。',
      sourceRecord: sourceRecord,
    );
  }

  Future<List<MealRecord>> filterRecords({
    DateTime? start,
    DateTime? end,
  }) async {
    final records = await fetchRecords();
    return records.where((record) {
      final afterStart = start == null || !record.createdAt.isBefore(start);
      final beforeEnd = end == null || !record.createdAt.isAfter(end);
      return afterStart && beforeEnd;
    }).toList();
  }

  List<JournalEntry> buildJournalEntries(List<MealRecord> records) {
    final grouped = <DateTime, List<MealRecord>>{};

    for (final record in records) {
      final journalDay = _journalDayStart(record.createdAt);
      grouped.putIfAbsent(journalDay, () => []).add(record);
    }

    final entries = grouped.entries.map((entry) {
      final sortedRecords = [...entry.value]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final totalCost = sortedRecords.fold<double>(
        0,
        (sum, item) => sum + (item.price ?? 0),
      );
      final rated = sortedRecords
          .where((record) => record.ratingScore != null)
          .toList();
      final averageRating = rated.isEmpty
          ? null
          : rated.fold<double>(0, (sum, item) => sum + item.ratingScore!) /
                rated.length;
      return JournalEntry(
        dayStart: entry.key,
        records: sortedRecords,
        totalCost: totalCost,
        averageRating: averageRating,
      );
    }).toList()..sort((a, b) => a.dayStart.compareTo(b.dayStart));

    return entries;
  }

  Map<String, String> summarizeStats(List<MealRecord> records) {
    final totalCost = records.fold<double>(
      0,
      (sum, item) => sum + (item.price ?? 0),
    );
    final locations = <String, int>{};
    final dishes = <String, int>{};

    for (final record in records) {
      locations[record.location] = (locations[record.location] ?? 0) + 1;
      dishes[record.mainDish] = (dishes[record.mainDish] ?? 0) + 1;
    }

    String topEntry(Map<String, int> map) {
      if (map.isEmpty) {
        return '暂无';
      }
      final entry = map.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return '${entry.key} (${entry.value}次)';
    }

    return {
      '总记录': '${records.length} 条',
      '总花费': '￥${totalCost.toStringAsFixed(1)}',
      '常去地点': topEntry(locations),
      '常吃主菜': topEntry(dishes),
      '最近记录': records.isEmpty
          ? '暂无'
          : DateFormat('MM/dd HH:mm').format(records.first.createdAt),
    };
  }

  Map<String, dynamic> buildDetailedStats(List<MealRecord> records) {
    final totalCost = records.fold<double>(
      0,
      (sum, item) => sum + (item.price ?? 0),
    );
    final locationCounts = <String, int>{};
    final dishCounts = <String, int>{};
    final ratingCounts = <String, int>{};

    for (final record in records) {
      locationCounts[record.location] =
          (locationCounts[record.location] ?? 0) + 1;
      dishCounts[record.mainDish] = (dishCounts[record.mainDish] ?? 0) + 1;
      ratingCounts[record.ratingLabel] =
          (ratingCounts[record.ratingLabel] ?? 0) + 1;
    }

    List<MapEntry<String, int>> sortEntries(Map<String, int> map) =>
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalCost': totalCost,
      'recordCount': records.length,
      'topLocations': sortEntries(locationCounts),
      'topDishes': sortEntries(dishCounts),
      'ratingDistribution': sortEntries(ratingCounts),
    };
  }

  Future<LocalDataSummary> getLocalDataSummary() async {
    final records = await fetchRecords();
    final dbBytes = await _databaseService.getDatabaseFileSize();
    final imageCount = records
        .where((record) => File(record.imagePath).existsSync())
        .length;
    return LocalDataSummary(
      recordCount: records.length,
      imageCount: imageCount,
      databaseBytes: dbBytes,
    );
  }

  void dispose() {
    _recordsController.close();
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fallbackText(String input) {
    final value = input.trim();
    return value.isEmpty ? '未填写' : value;
  }

  String? _nullableText(String? input) {
    final value = input?.trim();
    if (value == null || value.isEmpty || value == '未填写') {
      return null;
    }
    return value;
  }

  String _pickWeightedDish(Map<String, double> scores) {
    final totalWeight = scores.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    var cursor = _random.nextDouble() * totalWeight;

    for (final entry in scores.entries) {
      cursor -= entry.value;
      if (cursor <= 0) {
        return entry.key;
      }
    }

    return scores.keys.last;
  }

  String _normalizeDishKey(String source) {
    return source.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _generateClientRecordId(DateTime time) {
    final randomPart = _random.nextInt(1 << 32).toRadixString(16);
    return 'local_${time.microsecondsSinceEpoch}_$randomPart';
  }

  DateTime _journalDayStart(DateTime time) {
    final shifted = time.subtract(const Duration(hours: 4));
    return DateTime(shifted.year, shifted.month, shifted.day, 4);
  }
}
