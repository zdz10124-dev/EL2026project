import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/exercise_record.dart';
import '../../models/meal_record.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/section_card.dart';
import '../../widgets/themed_page_background.dart';

class MealRecordDetailScreen extends StatelessWidget {
  const MealRecordDetailScreen({super.key, required this.record});

  final MealRecord record;

  @override
  Widget build(BuildContext context) {
    final values = <_DetailValue>[
      _DetailValue(
        '记录时间',
        DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt),
      ),
      _DetailValue('地点', record.location),
      _DetailValue(
        '价格',
        record.price == null ? null : '¥${record.price!.toStringAsFixed(2)}',
      ),
      _DetailValue(
        '评分',
        record.ratingScore == null
            ? record.ratingLabel
            : '${(record.ratingScore! / 2).toStringAsFixed(1)} 星 · ${record.ratingLabel}',
      ),
      _DetailValue('主食', record.mainDish),
      _DetailValue('配菜', record.sideDish),
      _DetailValue('饮品', record.drink),
      _DetailValue('加餐', record.snack),
      _DetailValue('菜系', record.cuisine),
      _DetailValue('辣度', record.spiceLevel),
      _DetailValue('食材', record.ingredients),
      _DetailValue('备注', record.comment),
    ];

    return _RecordDetailScaffold(
      title: '饮食详情',
      headerIcon: Icons.restaurant_outlined,
      headerTitle: record.dishName,
      images: record.imagePaths,
      values: values,
    );
  }
}

class ExerciseRecordDetailScreen extends StatelessWidget {
  const ExerciseRecordDetailScreen({super.key, required this.record});

  final ExerciseRecord record;

  @override
  Widget build(BuildContext context) {
    final values = <_DetailValue>[
      _DetailValue(
        '开始时间',
        DateFormat('yyyy-MM-dd HH:mm').format(record.startedAt),
      ),
      _DetailValue('运动时长', _formatDuration(record.durationSeconds)),
      _DetailValue(
        '距离',
        record.distanceMeters == null
            ? null
            : '${(record.distanceMeters! / 1000).toStringAsFixed(2)} km',
      ),
      _DetailValue(
        '平均心率',
        record.averageHeartRateBpm == null
            ? null
            : '${record.averageHeartRateBpm} bpm',
      ),
      _DetailValue(
        '峰值心率',
        record.peakHeartRateBpm == null
            ? null
            : '${record.peakHeartRateBpm} bpm',
      ),
      _DetailValue(
        '消耗热量',
        record.caloriesKcal == null ? null : '${record.caloriesKcal} kcal',
      ),
      _DetailValue('主观疲劳', record.rpe == null ? null : 'RPE ${record.rpe}'),
      _DetailValue(
        '记录方式',
        record.source == ExerciseSource.aiImage ? '图片识别' : '手动录入',
      ),
      ...record.detail.entries
          .where(
            (entry) =>
                !entry.key.startsWith('ai_') &&
                entry.value != null &&
                entry.value.toString().trim().isNotEmpty,
          )
          .map(
            (entry) => _DetailValue(
              _exerciseDetailLabel(entry.key),
              entry.value.toString(),
            ),
          ),
      _DetailValue('备注', record.note),
    ];

    return _RecordDetailScaffold(
      title: '运动详情',
      headerIcon: _exerciseIcon(record.activityType),
      headerTitle: record.activityType.label,
      images: record.imagePaths,
      values: values,
    );
  }
}

class _RecordDetailScaffold extends StatelessWidget {
  const _RecordDetailScaffold({
    required this.title,
    required this.headerIcon,
    required this.headerTitle,
    required this.images,
    required this.values,
  });

  final String title;
  final IconData headerIcon;
  final String headerTitle;
  final List<String> images;
  final List<_DetailValue> values;

  @override
  Widget build(BuildContext context) {
    final visibleValues = values
        .where((item) => item.value?.trim().isNotEmpty == true)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '编辑',
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ThemedPageBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              child: Row(
                children: [
                  CircleAvatar(child: Icon(headerIcon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      headerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RecordImages(imagePaths: images),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < visibleValues.length;
                    index++
                  ) ...[
                    _DetailRow(value: visibleValues[index]),
                    if (index < visibleValues.length - 1)
                      const Divider(height: 24),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RecordImages extends StatelessWidget {
  const _RecordImages({required this.imagePaths});

  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    final validPaths = existingImagePaths(imagePaths);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            validPaths.isEmpty ? '记录图片' : '记录图片（${validPaths.length}）',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (validPaths.isEmpty)
            const Row(
              children: [
                Icon(Icons.image_not_supported_outlined),
                SizedBox(width: 8),
                Text('没有可查看的本地图片'),
              ],
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: validPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () =>
                      openImageViewer(context, validPaths, initialIndex: index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(validPaths[index]),
                      width: 108,
                      height: 108,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailValue {
  const _DetailValue(this.label, this.value);

  final String label;
  final String? value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.value});

  final _DetailValue value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 82,
        child: Text(value.label, style: Theme.of(context).textTheme.bodyMedium),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(value.value!, style: Theme.of(context).textTheme.bodyLarge),
      ),
    ],
  );
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '$hours 小时 $minutes 分钟';
  if (minutes > 0) return '$minutes 分钟 $remainingSeconds 秒';
  return '$remainingSeconds 秒';
}

String _exerciseDetailLabel(String key) => switch (key) {
  'average_pace' => '平均配速',
  'cadence_spm' => '平均步频',
  'stroke' => '主要泳姿',
  'laps' => '趟数',
  'average_speed_kmh' => '平均速度',
  'elevation_gain_m' => '累计爬升',
  'steps' => '步数',
  'activity_name' => '运动名称',
  'detail' => '专项数据',
  _ => key,
};

IconData _exerciseIcon(ActivityType type) => switch (type) {
  ActivityType.running => Icons.directions_run,
  ActivityType.swimming => Icons.pool,
  ActivityType.cycling => Icons.directions_bike,
  ActivityType.walking => Icons.directions_walk,
  ActivityType.other => Icons.fitness_center,
};
