import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/exercise_record.dart';
import '../../models/health_timeline_item.dart';
import '../../models/meal_record.dart';
import '../../models/ui_config.dart';
import '../../services/agent_service.dart';
import '../../services/exercise_repository.dart';
import '../../services/health_agent_service.dart';
import '../../services/health_timeline_service.dart';
import '../../services/meal_repository.dart';
import '../../widgets/section_card.dart';
import '../../widgets/themed_page_background.dart';
import '../capture_screen.dart';
import '../exercise/exercise_editor_screen.dart';

enum RecordsFilter { all, meals, exercises }

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    super.key,
    required this.config,
    required this.mealRepository,
    required this.exerciseRepository,
    required this.mealAgentService,
    required this.healthAgentService,
  });

  final UiConfig config;
  final MealRepository mealRepository;
  final ExerciseRepository exerciseRepository;
  final AgentService mealAgentService;
  final HealthAgentService healthAgentService;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _timelineService = HealthTimelineService();
  List<MealRecord> _meals = const [];
  List<ExerciseRecord> _exercises = const [];
  RecordsFilter _filter = RecordsFilter.all;
  StreamSubscription<List<MealRecord>>? _mealSubscription;
  StreamSubscription<List<ExerciseRecord>>? _exerciseSubscription;

  @override
  void initState() {
    super.initState();
    _mealSubscription = widget.mealRepository.recordsStream.listen((records) {
      if (mounted) setState(() => _meals = records);
    });
    _exerciseSubscription =
        widget.exerciseRepository.recordsStream.listen((records) {
      if (mounted) setState(() => _exercises = records);
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final meals = await widget.mealRepository.fetchRecords();
    final exercises = await widget.exerciseRepository.fetchRecords();
    if (!mounted) return;
    setState(() {
      _meals = meals;
      _exercises = exercises;
    });
  }

  @override
  void dispose() {
    _mealSubscription?.cancel();
    _exerciseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _timelineService.merge(meals: _meals, exercises: _exercises);
    final items = allItems.where((item) => switch (_filter) {
          RecordsFilter.all => true,
          RecordsFilter.meals => item.kind == HealthTimelineKind.meal,
          RecordsFilter.exercises => item.kind == HealthTimelineKind.exercise,
        });
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: widget.config.layout.pageHorizontalPadding,
          vertical: widget.config.layout.pageVerticalPadding,
        ),
        children: [
          Row(
            children: [
              Text('健康记录', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: '新增记录',
                icon: const Icon(Icons.add_circle_outline),
                onSelected: (value) =>
                    value == 'meal' ? _addMeal() : _addExercise(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'meal', child: Text('记录饮食')),
                  PopupMenuItem(value: 'exercise', child: Text('记录运动')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('饮食和运动按时间合并展示，便于查看同一天的健康行为。'),
          const SizedBox(height: 16),
          SegmentedButton<RecordsFilter>(
            segments: const [
              ButtonSegment(value: RecordsFilter.all, label: Text('全部')),
              ButtonSegment(value: RecordsFilter.meals, label: Text('饮食')),
              ButtonSegment(value: RecordsFilter.exercises, label: Text('运动')),
            ],
            selected: {_filter},
            onSelectionChanged: (value) => setState(() => _filter = value.first),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const SectionCard(child: Text('当前分类还没有记录。点击右上角添加饮食或运动。'))
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: item.kind == HealthTimelineKind.meal
                      ? _MealTimelineCard(
                          record: item.meal!,
                          onEdit: () => _editMeal(item.meal!),
                          onDelete: () => _deleteMeal(item.meal!),
                        )
                      : _ExerciseTimelineCard(
                          record: item.exercise!,
                          onEdit: () => _editExercise(item.exercise!),
                          onDelete: () => _deleteExercise(item.exercise!),
                        ),
                )),
        ],
      ),
    );
  }

  Future<void> _addMeal() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('记录饮食')),
        body: ThemedPageBackground(
          child: CaptureScreen(
            config: widget.config,
            repository: widget.mealRepository,
            agentService: widget.mealAgentService,
          ),
        ),
      ),
    ));
  }

  Future<void> _editMeal(MealRecord record) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _MealTimelineEditor(
        repository: widget.mealRepository,
        record: record,
      ),
    ));
  }

  Future<void> _deleteMeal(MealRecord record) async {
    if (await _confirmDelete('删除饮食记录', '该饮食记录及本地图片将被删除。')) {
      await widget.mealRepository.deleteRecord(record);
    }
  }

  Future<void> _addExercise() => _openExerciseEditor();

  Future<void> _editExercise(ExerciseRecord record) =>
      _openExerciseEditor(record);

  Future<void> _openExerciseEditor([ExerciseRecord? record]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ExerciseEditorScreen(
        repository: widget.exerciseRepository,
        agentService: widget.healthAgentService,
        existingRecord: record,
      ),
    ));
  }

  Future<void> _deleteExercise(ExerciseRecord record) async {
    if (await _confirmDelete('删除运动记录', '该运动记录及本地截图将被删除。')) {
      await widget.exerciseRepository.deleteRecord(record);
    }
  }

  Future<bool> _confirmDelete(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      ) ??
      false;
}

class _MealTimelineCard extends StatelessWidget {
  const _MealTimelineCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });
  final MealRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MealThumbnail(path: record.imagePath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.restaurant_outlined, size: 17),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        record.dishName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text([
                    if (record.location.trim().isNotEmpty) record.location,
                    if (record.ratingScore != null)
                      '${(record.ratingScore! / 2).toStringAsFixed(1)} 星',
                  ].join(' · ')),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MM-dd HH:mm').format(record.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _RecordMenu(onEdit: onEdit, onDelete: onDelete),
          ],
        ),
      );
}

class _ExerciseTimelineCard extends StatelessWidget {
  const _ExerciseTimelineCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });
  final ExerciseRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      '${(record.durationSeconds / 60).round()} 分钟',
      if (record.distanceMeters != null)
        '${(record.distanceMeters! / 1000).toStringAsFixed(2)} km',
      if (record.rpe != null) 'RPE ${record.rpe}',
      ...record.detail.entries
          .where((item) => !item.key.startsWith('ai_'))
          .take(2)
          .map((item) => item.value.toString()),
    ];
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(_exerciseIcon(record.activityType))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.activityType.label,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(details.join(' · ')),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MM-dd HH:mm').format(record.startedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (record.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(record.note!),
                ],
              ],
            ),
          ),
          _RecordMenu(onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

class _RecordMenu extends StatelessWidget {
  const _RecordMenu({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      );
}

class _MealThumbnail extends StatelessWidget {
  const _MealThumbnail({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.restaurant));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(path),
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const SizedBox(width: 54, height: 54, child: Icon(Icons.broken_image)),
      ),
    );
  }
}

class _MealTimelineEditor extends StatefulWidget {
  const _MealTimelineEditor({required this.repository, required this.record});
  final MealRepository repository;
  final MealRecord record;

  @override
  State<_MealTimelineEditor> createState() => _MealTimelineEditorState();
}

class _MealTimelineEditorState extends State<_MealTimelineEditor> {
  late final TextEditingController _dish;
  late final TextEditingController _location;
  late final TextEditingController _price;
  late final TextEditingController _comment;
  late double _rating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _dish = TextEditingController(text: record.dishName);
    _location = TextEditingController(text: record.location);
    _price = TextEditingController(text: record.price?.toString() ?? '');
    _comment = TextEditingController(text: record.comment ?? '');
    _rating = ((record.ratingScore ?? 0) / 2).clamp(0, 5).toDouble();
  }

  @override
  void dispose() {
    _dish.dispose();
    _location.dispose();
    _price.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('编辑饮食记录')),
        body: ThemedPageBackground(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
            SectionCard(
              child: Column(
                children: [
                  TextField(
                    controller: _dish,
                    decoration: const InputDecoration(labelText: '菜品名称'),
                  ),
                  TextField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: '地点'),
                  ),
                  TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '价格'),
                  ),
                  TextField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '备注'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('评分'),
                    Expanded(
                      child: Slider(
                        value: _rating,
                        min: 0,
                        max: 5,
                        divisions: 10,
                        label: _rating.toStringAsFixed(1),
                        onChanged: (value) => setState(() => _rating = value),
                      ),
                    ),
                    Text(_rating.toStringAsFixed(1)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存修改'),
            ),
            ],
          ),
        ),
      );

  Future<void> _save() async {
    if (_dish.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('菜品名称不能为空')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.updateRecord(
        original: widget.record,
        dishNameInput: _dish.text,
        locationInput: _location.text,
        priceText: _price.text,
        ratingScore: _rating == 0 ? null : _rating,
        commentInput: _comment.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

IconData _exerciseIcon(ActivityType type) => switch (type) {
      ActivityType.running => Icons.directions_run,
      ActivityType.swimming => Icons.pool,
      ActivityType.cycling => Icons.directions_bike,
      ActivityType.walking => Icons.directions_walk,
      ActivityType.other => Icons.fitness_center,
    };
