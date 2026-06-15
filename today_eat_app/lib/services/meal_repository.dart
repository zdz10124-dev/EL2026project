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

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/meal_draft.dart';
import '../models/meal_record.dart';
import '../models/recommendation_comment.dart';
import '../models/recommendation_models.dart';
import '../models/recommendation_upload_task.dart';
import '../models/user_profile.dart';
import 'app_settings_service.dart';
import 'database_service.dart';
import 'recommendation_api_service.dart';

part 'meal_repository_analysis.dart';

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
  bool _autoUploadRecordsEnabled = true;

  Stream<List<MealRecord>> get recordsStream => _recordsController.stream;

  Future<void> initialize() async {
    _autoUploadRecordsEnabled = await _appSettingsService
        .getAutoUploadRecordsEnabled();
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

  Future<List<XFile>> pickMultiFromGallery() =>
      _imagePicker.pickMultiImage(limit: 5, imageQuality: 85);

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
    required List<String> sourceImagePaths,
    required String dishNameInput,
    required String locationInput,
    required String priceText,
    required double? ratingScore,
    String? aiMainDish,
    String? aiSideDish,
    String? aiDrink,
    String? aiSnack,
    String? aiSpiceLevel,
    String? aiIngredients,
    String? aiCuisine,
    String? commentInput,
    String? province,
    String? city,
    String? district,
    double? latitude,
    double? longitude,
    bool? autoUploadEnabled,
  }) async {
    final now = DateTime.now();
    final savedPaths = <String>[];
    for (final src in sourceImagePaths) {
      savedPaths.add(await _copyImageToAppDir(src));
    }
    final record = buildRecord(
      clientRecordId: _generateClientRecordId(now),
      createdAt: now,
      updatedAt: now,
      imagePaths: savedPaths,
      dishNameInput: dishNameInput,
      locationInput: locationInput,
      priceText: priceText,
      ratingScore: ratingScore,
      aiMainDish: aiMainDish,
      aiSideDish: aiSideDish,
      aiDrink: aiDrink,
      aiSnack: aiSnack,
      aiSpiceLevel: aiSpiceLevel,
      aiIngredients: aiIngredients,
      aiCuisine: aiCuisine,
      commentInput: commentInput,
      province: province,
      city: city,
      district: district,
      latitude: latitude,
      longitude: longitude,
      autoUploadEnabled: autoUploadEnabled ?? _autoUploadRecordsEnabled,
    );

    final recordId = await _databaseService.insertRecord(record);
    final savedRecord = record.copyWith(id: recordId);
    await _databaseService.ensureUploadTasksForRecords([savedRecord]);
    clearDraft();
    await refreshRecords();
    if (savedRecord.autoUploadEnabled) {
      unawaited(_syncRecordUploadsInBackground());
    }
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
    bool? autoUploadEnabled,
  }) async {
    final updated = buildRecord(
      id: original.id,
      clientRecordId: original.clientRecordId,
      createdAt: original.createdAt,
      updatedAt: DateTime.now(),
      imagePaths: original.imagePaths,
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
      autoUploadEnabled: autoUploadEnabled ?? original.autoUploadEnabled,
      remoteRecommendationId: original.remoteRecommendationId,
      recommendationStatus: (autoUploadEnabled ?? original.autoUploadEnabled)
          ? LocalRecommendationStatus.pendingUpload
          : LocalRecommendationStatus.localOnly,
    );
    await _databaseService.updateRecord(updated);
    if (updated.id != null && updated.autoUploadEnabled) {
      await _databaseService.ensureUploadTasksForRecords([updated]);
    } else if (updated.id != null) {
      await _databaseService.deleteUploadTaskByRecordId(updated.id!);
    }
    await refreshRecords();
    if (updated.autoUploadEnabled) {
      unawaited(_syncRecordUploadsInBackground());
    }
  }

  MealRecord buildRecord({
    int? id,
    required String clientRecordId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required List<String> imagePaths,
    required String dishNameInput,
    required String locationInput,
    required String priceText,
    required double? ratingScore,
    String? aiMainDish,
    String? aiSideDish,
    String? aiDrink,
    String? aiSnack,
    String? aiSpiceLevel,
    String? aiIngredients,
    String? aiCuisine,
    String? commentInput,
    String? province,
    String? city,
    String? district,
    double? latitude,
    double? longitude,
    String? remoteRecommendationId,
    bool autoUploadEnabled = true,
    LocalRecommendationStatus? recommendationStatus,
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
      imagePaths: imagePaths,
      dishName: dishName,
      location: location,
      price: parsedPrice,
      ratingScore: score,
      ratingLabel: score == null
          ? '未打分'
          : '${score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1)}分',
      mainDish: aiMainDish ?? dishName,
      sideDish: aiSideDish,
      drink: aiDrink,
      snack: aiSnack,
      spiceLevel: aiSpiceLevel,
      ingredients: aiIngredients,
      cuisine: aiCuisine,
      comment: _nullableText(commentInput),
      remoteRecommendationId: remoteRecommendationId,
      autoUploadEnabled: autoUploadEnabled,
      recommendationStatus:
          recommendationStatus ??
          (autoUploadEnabled
              ? LocalRecommendationStatus.pendingUpload
              : LocalRecommendationStatus.localOnly),
      province: _nullableText(province),
      city: _nullableText(city),
      district: _nullableText(district),
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> deleteRecord(MealRecord record) async {
    if (record.remoteRecommendationId?.isNotEmpty == true) {
      try {
        await setRecommendationVisibility(record, active: false);
      } catch (_) {
        // Deleting local content should still succeed even if remote unlisting fails.
      }
    }
    if (record.id != null) {
      await _databaseService.deleteRecord(record.id!);
      await _databaseService.deleteUploadTaskByRecordId(record.id!);
    }
    for (final path in record.imagePaths) {
      await _deleteImageIfExists(path);
    }
    await refreshRecords();
  }

  Future<void> deleteAllRecords() async {
    final records = await fetchRecords();
    await _databaseService.deleteAllRecords();
    for (final record in records) {
      for (final path in record.imagePaths) {
        await _deleteImageIfExists(path);
      }
    }
    await refreshRecords();
  }

  Future<bool> getPublicRecordsEnabled() async {
    _autoUploadRecordsEnabled = await _appSettingsService
        .getAutoUploadRecordsEnabled();
    return _autoUploadRecordsEnabled;
  }

  Future<void> setPublicRecordsEnabled(bool value) async {
    _autoUploadRecordsEnabled = value;
    await _appSettingsService.setAutoUploadRecordsEnabled(value);
    if (value) {
      await syncPublicRecords();
      await refreshRecords();
    }
  }

  Future<UserProfile> getUserProfile() async {
    return _appSettingsService.getUserProfile();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _appSettingsService.setUserProfile(profile);
  }

  Future<RecommendationDistanceBucket?> getSavedRecommendationDistanceBucket() {
    return _appSettingsService.getRecommendationDistanceBucket();
  }

  Future<void> saveRecommendationDistanceBucket(
    RecommendationDistanceBucket? bucket,
  ) {
    return _appSettingsService.setRecommendationDistanceBucket(bucket);
  }

  Future<RecommendationSyncSummary> syncPublicRecords() async {
    if (!_autoUploadRecordsEnabled) {
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
      if (record == null || !record.autoUploadEnabled) {
        continue;
      }
      try {
        final profile = await getUserProfile();
        final clientId = await _appSettingsService.getRecommendationClientId();
        final result = await _recommendationApiService.uploadRecord(
          record: record,
          clientId: clientId,
          profile: profile,
        );
        await _databaseService.markUploadTaskSynced(
          clientRecordId: record.clientRecordId,
          recordUpdatedAt: record.updatedAt,
        );
        await _databaseService.updateRecommendationSyncState(
          recordId: record.id!,
          status: LocalRecommendationStatus.uploaded,
          remoteRecommendationId: result.remoteId,
        );
        successCount++;
      } catch (error) {
        failedCount++;
        lastError = error.toString();
        await _databaseService.markUploadTaskFailed(
          clientRecordId: record.clientRecordId,
          error: lastError,
          status: error is RecommendationApiException && !error.shouldRetry
              ? RecommendationUploadTaskStatus.invalid
              : RecommendationUploadTaskStatus.failed,
        );
        await _databaseService.updateRecommendationSyncState(
          recordId: record.id!,
          status: LocalRecommendationStatus.uploadFailed,
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
  ) async {
    final clientId = await _appSettingsService.getRecommendationClientId();
    return _recommendationApiService.searchRecommendations(query, clientId);
  }

  Future<RecommendationDetail> fetchRecommendationDetail(String id) async {
    final clientId = await _appSettingsService.getRecommendationClientId();
    return _recommendationApiService.fetchRecommendationDetail(id, clientId);
  }

  Future<RecommendationComment> createRecommendationComment({
    required String recommendationId,
    required String content,
  }) async {
    final clientId = await _appSettingsService.getRecommendationClientId();
    final profile = await getUserProfile();
    return _recommendationApiService.createComment(
      recommendationId: recommendationId,
      content: content,
      clientId: clientId,
      profile: profile,
    );
  }

  Future<void> setRecordAutoUploadEnabled(
    MealRecord record,
    bool enabled,
  ) async {
    if (record.id == null) {
      return;
    }
    final updated = record.copyWith(
      autoUploadEnabled: enabled,
      recommendationStatus: enabled
          ? LocalRecommendationStatus.pendingUpload
          : (record.remoteRecommendationId?.isNotEmpty == true
                ? LocalRecommendationStatus.unlisted
                : LocalRecommendationStatus.localOnly),
    );
    await _databaseService.updateRecord(updated);
    if (enabled) {
      await _databaseService.ensureUploadTasksForRecords([updated]);
    } else {
      await _databaseService.deleteUploadTaskByRecordId(record.id!);
    }
    await refreshRecords();
    if (enabled) {
      unawaited(_syncRecordUploadsInBackground());
    } else if (record.remoteRecommendationId?.isNotEmpty == true) {
      unawaited(
        _pushRecommendationVisibilityInBackground(updated, active: false),
      );
    } else {
      await _databaseService.updateRecommendationSyncState(
        recordId: record.id!,
        status: LocalRecommendationStatus.localOnly,
        autoUploadEnabled: false,
        remoteRecommendationId: null,
      );
      await refreshRecords();
    }
  }

  Future<void> setRecommendationVisibility(
    MealRecord record, {
    required bool active,
  }) async {
    if (record.id == null ||
        record.remoteRecommendationId?.isNotEmpty != true) {
      return;
    }
    await _databaseService.updateRecommendationSyncState(
      recordId: record.id!,
      status: active
          ? LocalRecommendationStatus.uploaded
          : LocalRecommendationStatus.unlisted,
      autoUploadEnabled: record.autoUploadEnabled,
      remoteRecommendationId: record.remoteRecommendationId,
    );
    await refreshRecords();
    final updated = record.copyWith(
      recommendationStatus: active
          ? LocalRecommendationStatus.uploaded
          : LocalRecommendationStatus.unlisted,
    );
    unawaited(
      _pushRecommendationVisibilityInBackground(updated, active: active),
    );
  }

  Future<RecommendationModerationResult> submitRecommendationVote({
    required String recommendationId,
    required String action,
  }) async {
    final clientId = await _appSettingsService.getRecommendationClientId();
    return _recommendationApiService.submitVote(
      recommendationId: recommendationId,
      action: action,
      clientId: clientId,
    );
  }

  Future<RecommendationModerationResult> submitRecommendationReport({
    required String recommendationId,
    String? reason,
  }) async {
    final clientId = await _appSettingsService.getRecommendationClientId();
    return _recommendationApiService.submitReport(
      recommendationId: recommendationId,
      clientId: clientId,
      reason: reason,
    );
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

    final filename = 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = File(p.join(imageDir.path, filename));
    if (File(sourcePath).absolute.path == target.absolute.path) {
      return target.path;
    }
    final compressed = await _compressLocalImage(sourcePath);
    if (compressed != null) {
      await target.writeAsBytes(compressed, flush: true);
      return target.path;
    }
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Future<List<int>?> _compressLocalImage(String sourcePath) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) {
        return null;
      }

      const maxEdge = 1600;
      img.Image working = original;
      final longestEdge = max(working.width, working.height);
      if (longestEdge > maxEdge) {
        if (working.width >= working.height) {
          working = img.copyResize(working, width: maxEdge);
        } else {
          working = img.copyResize(working, height: maxEdge);
        }
      }

      return img.encodeJpg(working, quality: 82);
    } catch (_) {
      return null;
    }
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

  String _normalizeDishKey(String source) {
    var value = source.trim().toLowerCase();
    value = value
        .replaceAll('西红柿', '番茄')
        .replaceAll('蕃茄', '番茄')
        .replaceAll('马铃薯', '土豆')
        .replaceAll('洋芋', '土豆')
        .replaceAll('薯仔', '土豆')
        .replaceAll('鸡蛋', '蛋')
        .replaceAll('米饭', '饭')
        .replaceAll('白米饭', '饭');
    value = value.replaceAll(RegExp(r'[\s,，.。!！?？\-_/\\()（）【】\[\]]+'), '');
    for (final suffix in const [
      '套餐',
      '盖饭',
      '便当',
      '小份',
      '大份',
      '中份',
      '微辣',
      '中辣',
      '特辣',
    ]) {
      if (value.endsWith(suffix) && value.length > suffix.length + 1) {
        value = value.substring(0, value.length - suffix.length);
      }
    }
    return value;
  }

  String _generateClientRecordId(DateTime time) {
    final randomPart = _random.nextInt(1 << 32).toRadixString(16);
    return 'local_${time.microsecondsSinceEpoch}_$randomPart';
  }

  Future<void> _syncRecordUploadsInBackground() async {
    try {
      await syncPublicRecords();
      await refreshRecords();
    } catch (_) {
      await refreshRecords();
    }
  }

  Future<void> _pushRecommendationVisibilityInBackground(
    MealRecord record, {
    required bool active,
  }) async {
    try {
      final clientId = await _appSettingsService.getRecommendationClientId();
      await _recommendationApiService.setRecommendationVisibility(
        recommendationId: record.remoteRecommendationId!,
        active: active,
        clientId: clientId,
      );
    } catch (_) {
      // Keep the optimistic local state and avoid blocking the UI.
    }
  }
}
