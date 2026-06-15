part of 'meal_repository.dart';

extension MealRepositoryAnalysis on MealRepository {
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
      final dishKey = _normalizeDishKeyForAnalysis(record.mainDish);
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

    final selectedDishKey = _pickWeightedDishForAnalysis(scores);
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
      final journalDay = _journalDayStartForAnalysis(record.createdAt);
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

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _pickWeightedDishForAnalysis(Map<String, double> scores) {
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

  String _normalizeDishKeyForAnalysis(String source) {
    var value = _normalizeDishKey(source);
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

  DateTime _journalDayStartForAnalysis(DateTime time) {
    final shifted = time.subtract(const Duration(hours: 4));
    return DateTime(shifted.year, shifted.month, shifted.day, 4);
  }
}
