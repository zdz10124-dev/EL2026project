import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/exercise_draft.dart';
import '../../models/exercise_record.dart';
import '../../services/exercise_repository.dart';
import '../../services/exercise_validator.dart';
import '../../services/health_agent_service.dart';
import '../../widgets/section_card.dart';
import '../../widgets/themed_page_background.dart';

class ExerciseEditorScreen extends StatefulWidget {
  const ExerciseEditorScreen({
    super.key,
    required this.repository,
    required this.agentService,
    this.existingRecord,
  });

  final ExerciseRepository repository;
  final HealthAgentService agentService;
  final ExerciseRecord? existingRecord;

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  late ActivityType _activityType;
  late DateTime _startedAt;
  late final TextEditingController _duration;
  late final TextEditingController _distance;
  late final TextEditingController _averageHeartRate;
  late final TextEditingController _peakHeartRate;
  late final TextEditingController _calories;
  late final TextEditingController _rpe;
  late final TextEditingController _note;
  late final TextEditingController _detailOne;
  late final TextEditingController _detailTwo;
  List<String> _imagePaths = const [];
  bool _saving = false;
  bool _analyzing = false;
  bool _recognizedByAi = false;
  String? _aiNotice;

  @override
  void initState() {
    super.initState();
    final record = widget.existingRecord;
    _activityType = record?.activityType ?? ActivityType.running;
    _startedAt = record?.startedAt ?? DateTime.now();
    _duration = TextEditingController(
      text: record == null ? '' : (record.durationSeconds / 60).round().toString(),
    );
    _distance = TextEditingController(
      text: record?.distanceMeters == null
          ? ''
          : (record!.distanceMeters! / 1000).toStringAsFixed(2),
    );
    _averageHeartRate =
        TextEditingController(text: record?.averageHeartRateBpm?.toString() ?? '');
    _peakHeartRate =
        TextEditingController(text: record?.peakHeartRateBpm?.toString() ?? '');
    _calories = TextEditingController(text: record?.caloriesKcal?.toString() ?? '');
    _rpe = TextEditingController(text: record?.rpe?.toString() ?? '');
    _note = TextEditingController(text: record?.note ?? '');
    final detailFields = _detailFieldsFor(_activityType);
    _detailOne = TextEditingController(
      text: detailFields.isEmpty
          ? ''
          : record?.detail[detailFields.first.key]?.toString() ?? '',
    );
    _detailTwo = TextEditingController(
      text: detailFields.length < 2
          ? ''
          : record?.detail[detailFields[1].key]?.toString() ?? '',
    );
    _imagePaths = record?.imagePaths ?? const [];
    _recognizedByAi = record?.source == ExerciseSource.aiImage;
  }

  @override
  void dispose() {
    for (final controller in [
      _duration,
      _distance,
      _averageHeartRate,
      _peakHeartRate,
      _calories,
      _rpe,
      _note,
      _detailOne,
      _detailTwo,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingRecord != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(editing ? '编辑运动' : '记录运动')),
      body: ThemedPageBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('运动类型', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ActivityType.values.map((type) {
                      return ChoiceChip(
                        label: Text(type.label),
                        selected: _activityType == type,
                        onSelected: editing
                            ? null
                            : (_) => setState(() {
                                _activityType = type;
                                _detailOne.clear();
                                _detailTwo.clear();
                              }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: const Text('开始时间'),
                    subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(_startedAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickDateTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                children: [
                  _numberField(_duration, '运动时长（分钟）', Icons.timer_outlined),
                  _numberField(_distance, '距离（公里，可选）', Icons.straighten),
                  _numberField(
                    _averageHeartRate,
                    '平均心率（bpm，可选）',
                    Icons.favorite_outline,
                  ),
                  _numberField(
                    _peakHeartRate,
                    '峰值心率（bpm，可选）',
                    Icons.monitor_heart_outlined,
                  ),
                  _numberField(_calories, '消耗热量（kcal，可选）', Icons.local_fire_department_outlined),
                  _numberField(_rpe, '主观疲劳 RPE（1-10，可选）', Icons.speed_outlined),
                  ..._buildActivityDetailFields(),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
            if (!editing) ...[
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('截图识别', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      _imagePaths.isEmpty
                          ? '可上传运动 App 截图，AI 只会填写截图中明确出现的数据。'
                          : '已选择 ${_imagePaths.length} 张图片',
                    ),
                    if (_aiNotice != null) ...[
                      const SizedBox(height: 8),
                      Text(_aiNotice!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ],
                    if (_imagePaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagePaths.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(_imagePaths[index]),
                                  width: 92,
                                  height: 92,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 92,
                                    height: 92,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: IconButton.filled(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 16,
                                  onPressed: _analyzing
                                      ? null
                                      : () => setState(() {
                                            _imagePaths = [..._imagePaths]
                                              ..removeAt(index);
                                            _recognizedByAi = false;
                                            _aiNotice = null;
                                          }),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _analyzing ? null : _pickImages,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('选择截图'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _analyzing ? null : _captureImage,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('拍摄'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _imagePaths.isEmpty || _analyzing ? null : _analyzeImages,
                          icon: _analyzing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome_outlined),
                          label: const Text('AI 识别'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(editing ? '保存修改' : '保存运动'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  ExerciseDraft _draft() => ExerciseDraft(
        activityType: _activityType,
        startedAt: _startedAt,
        durationSeconds: ((double.tryParse(_duration.text.trim()) ?? 0) * 60).round(),
        distanceMeters: _optionalDouble(_distance) == null
            ? null
            : (_optionalDouble(_distance)! * 1000).round(),
        averageHeartRateBpm: _optionalInt(_averageHeartRate),
        peakHeartRateBpm: _optionalInt(_peakHeartRate),
        caloriesKcal: _optionalInt(_calories),
        rpe: _optionalInt(_rpe),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        detail: _activityDetail(),
        imagePaths: _imagePaths,
        source: _recognizedByAi ? ExerciseSource.aiImage : ExerciseSource.manual,
      );

  int? _optionalInt(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : int.tryParse(controller.text.trim());

  double? _optionalDouble(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : double.tryParse(controller.text.trim());

  Future<void> _pickImages() async {
    final files = await widget.repository.pickFromGallery();
    if (!mounted || files.isEmpty) return;
    setState(() {
      _imagePaths = files.take(4).map((item) => item.path).toList();
      _recognizedByAi = false;
      _aiNotice = null;
    });
  }

  Future<void> _captureImage() async {
    final file = await widget.repository.captureFromCamera();
    if (!mounted || file == null) return;
    setState(() {
      _imagePaths = [file.path];
      _recognizedByAi = false;
      _aiNotice = null;
    });
  }

  Future<void> _analyzeImages() async {
    if (!widget.agentService.isAvailable) {
      _showMessage('AI 未配置，你仍可手动填写并保存。');
      return;
    }
    setState(() => _analyzing = true);
    try {
      final draft = await widget.agentService.analyzeExerciseImages(
        _activityType,
        _imagePaths,
      );
      if (!mounted) return;
      setState(() {
        _startedAt = draft.startedAt;
        _duration.text = draft.durationSeconds > 0
            ? (draft.durationSeconds / 60).toStringAsFixed(1)
            : _duration.text;
        if (draft.distanceMeters != null) {
          _distance.text = (draft.distanceMeters! / 1000).toStringAsFixed(2);
        }
        _averageHeartRate.text = draft.averageHeartRateBpm?.toString() ?? _averageHeartRate.text;
        _peakHeartRate.text = draft.peakHeartRateBpm?.toString() ?? _peakHeartRate.text;
        _calories.text = draft.caloriesKcal?.toString() ?? _calories.text;
        _rpe.text = draft.rpe?.toString() ?? _rpe.text;
        final detailFields = _detailFieldsFor(_activityType);
        if (detailFields.isNotEmpty && draft.detail[detailFields.first.key] != null) {
          _detailOne.text = draft.detail[detailFields.first.key].toString();
        }
        if (detailFields.length > 1 && draft.detail[detailFields[1].key] != null) {
          _detailTwo.text = draft.detail[detailFields[1].key].toString();
        }
        _recognizedByAi = true;
        final warnings = draft.detail['ai_warnings'];
        _aiNotice = warnings is List && warnings.isNotEmpty
            ? '识别结果已填入。提示：${warnings.join('；')}'
            : '识别结果已填入，请确认或修改后保存。';
      });
    } catch (error) {
      if (mounted) _showMessage('识别失败：$error。已保留当前草稿。');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _save() async {
    final draft = _draft();
    final errors = validateExerciseDraft(draft);
    if (errors.isNotEmpty) {
      _showMessage(errors.join('\n'));
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.existingRecord;
      if (existing == null) {
        await widget.repository.saveDraft(draft);
      } else {
        await widget.repository.updateRecord(existing.copyWith(
          activityType: draft.activityType,
          startedAt: draft.startedAt,
          durationSeconds: draft.durationSeconds,
          distanceMeters: draft.distanceMeters,
          clearDistance: draft.distanceMeters == null,
          averageHeartRateBpm: draft.averageHeartRateBpm,
          clearAverageHeartRate: draft.averageHeartRateBpm == null,
          peakHeartRateBpm: draft.peakHeartRateBpm,
          clearPeakHeartRate: draft.peakHeartRateBpm == null,
          caloriesKcal: draft.caloriesKcal,
          clearCalories: draft.caloriesKcal == null,
          rpe: draft.rpe,
          clearRpe: draft.rpe == null,
          note: draft.note,
          clearNote: draft.note == null,
          detail: draft.detail,
        ));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage('保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (!mounted || time == null) return;
    setState(() {
      _startedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _buildActivityDetailFields() {
    final fields = _detailFieldsFor(_activityType);
    final controllers = [_detailOne, _detailTwo];
    return [
      for (var index = 0; index < fields.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: controllers[index],
            keyboardType: fields[index].numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: '${fields[index].label}（可选）',
              prefixIcon: Icon(fields[index].icon),
            ),
          ),
        ),
    ];
  }

  Map<String, Object?> _activityDetail() {
    final fields = _detailFieldsFor(_activityType);
    final values = [_detailOne.text.trim(), _detailTwo.text.trim()];
    return {
      for (var index = 0; index < fields.length; index++)
        if (values[index].isNotEmpty) fields[index].key: values[index],
    };
  }
}

class _DetailField {
  const _DetailField(this.key, this.label, this.icon, {this.numeric = true});
  final String key;
  final String label;
  final IconData icon;
  final bool numeric;
}

List<_DetailField> _detailFieldsFor(ActivityType type) => switch (type) {
      ActivityType.running => const [
          _DetailField('average_pace', '平均配速（分/公里）', Icons.speed),
          _DetailField('cadence_spm', '平均步频（步/分钟）', Icons.directions_run),
        ],
      ActivityType.swimming => const [
          _DetailField('stroke', '主要泳姿', Icons.pool, numeric: false),
          _DetailField('laps', '趟数', Icons.repeat),
        ],
      ActivityType.cycling => const [
          _DetailField('average_speed_kmh', '平均速度（km/h）', Icons.speed),
          _DetailField('elevation_gain_m', '累计爬升（米）', Icons.terrain),
        ],
      ActivityType.walking => const [
          _DetailField('steps', '步数', Icons.directions_walk),
          _DetailField('average_speed_kmh', '平均速度（km/h）', Icons.speed),
        ],
      ActivityType.other => const [
          _DetailField('activity_name', '运动名称', Icons.fitness_center,
              numeric: false),
          _DetailField('detail', '专项数据', Icons.notes, numeric: false),
        ],
    };
