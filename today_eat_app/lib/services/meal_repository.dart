import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/meal_draft.dart';
import '../models/meal_record.dart';
import 'database_service.dart';

enum DecisionMode { random, preference }

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

class MealRepository {
  MealRepository({DatabaseService? databaseService, ImagePicker? imagePicker})
    : _databaseService = databaseService ?? DatabaseService.instance,
      _imagePicker = imagePicker ?? ImagePicker();

  final DatabaseService _databaseService;
  final ImagePicker _imagePicker;
  final StreamController<List<MealRecord>> _recordsController =
      StreamController<List<MealRecord>>.broadcast();
  final Random _random = Random();

  MealDraft? _draft;
  bool _shouldUseDraftOnNextOpen = false;

  Stream<List<MealRecord>> get recordsStream => _recordsController.stream;

  Future<void> initialize() async {
    await refreshRecords();
  }

  Future<void> refreshRecords() async {
    final records = await _databaseService.fetchRecords();
    _recordsController.add(records);
  }

  Future<XFile?> captureFromCamera() =>
      _imagePicker.pickImage(source: ImageSource.camera);

  Future<XFile?> pickFromGallery() =>
      _imagePicker.pickImage(source: ImageSource.gallery);

  Future<XFile?> pickVideoFromGallery() =>
      _imagePicker.pickVideo(source: ImageSource.gallery);

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
    // AI 分析字段（可选）
    String? aiMainDish,
    String? aiSideDish,
    String? aiDrink,
    String? aiSnack,
    String? aiSpiceLevel,
    String? aiIngredients,
    String? aiCuisine,
  }) async {
    final now = DateTime.now();
    final savedImagePath = await _copyImageToAppDir(sourceImagePath);
    final dishName = _fallbackText(dishNameInput);
    final location = _fallbackText(locationInput);
    final parsedPrice = double.tryParse(priceText.trim());
    final score = ratingScore == null ? null : ratingScore * 2;

    final record = MealRecord(
      createdAt: now,
      imagePath: savedImagePath,
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
    );

    await _databaseService.insertRecord(record);
    clearDraft();
    await refreshRecords();
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
        reason: '随机模式从你的历史主菜里抽到它，今天可以少纠结一点。',
        sourceRecord: record,
      );
    }

    final currentSlot = DateTime.now().hour < 15 ? 'lunch' : 'dinner';
    final scores = <String, double>{};
    final groupedRecords = <String, List<MealRecord>>{};

    for (final record in candidates) {
      final dishKey = record.mainDish.trim();
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

    final selectedDish = _pickWeightedDish(scores);
    final recordsForDish = groupedRecords[selectedDish]!;
    final sourceRecord = recordsForDish[_random.nextInt(recordsForDish.length)];
    final selectedWeight = scores[selectedDish]!;

    return MealSuggestion(
      title: selectedDish,
      reason:
          '偏好模式会把相近时段更常吃、评分更高的记录累加成权重，再按权重随机抽取。'
          '这次抽到“$selectedDish”，累计权重 ${selectedWeight.toStringAsFixed(1)}，'
          '共参考 ${recordsForDish.length} 条同菜品记录。',
      sourceRecord: sourceRecord,
    );
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
      '总花费': '¥${totalCost.toStringAsFixed(1)}',
      '常去地点': topEntry(locations),
      '常吃主菜': topEntry(dishes),
      '最近记录': records.isEmpty
          ? '暂无'
          : DateFormat('MM/dd HH:mm').format(records.first.createdAt),
    };
  }

  void dispose() {
    _recordsController.close();
  }

  String _fallbackText(String input) {
    final value = input.trim();
    return value.isEmpty ? '未填写' : value;
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
}
