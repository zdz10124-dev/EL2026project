import 'package:flutter/material.dart';

import '../../models/recovery_check_in.dart';
import '../../services/recovery_repository.dart';

class RecoveryCheckInScreen extends StatefulWidget {
  const RecoveryCheckInScreen({
    super.key,
    required this.repository,
    required this.date,
  });

  final RecoveryRepository repository;
  final DateTime date;

  @override
  State<RecoveryCheckInScreen> createState() => _RecoveryCheckInScreenState();
}

class _RecoveryCheckInScreenState extends State<RecoveryCheckInScreen> {
  final TextEditingController _noteController = TextEditingController();
  int? _sleepQuality;
  int? _fatigue;
  int? _soreness;
  int? _energy;
  bool _loading = true;
  bool _saving = false;

  bool get _canSave =>
      _sleepQuality != null &&
      _fatigue != null &&
      _soreness != null &&
      _energy != null &&
      !_saving;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final existing = await widget.repository.findByDate(widget.date);
    if (!mounted) {
      return;
    }
    setState(() {
      _sleepQuality = existing?.sleepQuality;
      _fatigue = existing?.fatigue;
      _soreness = existing?.soreness;
      _energy = existing?.energy;
      _noteController.text = existing?.note ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        RecoveryCheckInDraft(
          date: widget.date,
          sleepQuality: _sleepQuality!,
          fatigue: _fatigue!,
          soreness: _soreness!,
          energy: _energy!,
          note: _noteController.text,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('恢复打卡')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Text('用 20 秒了解今天的恢复状态',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('这些评分只用于调整你的运动、饮食和休息建议。'),
                  const SizedBox(height: 22),
                  _RatingField(
                    label: '睡眠质量',
                    lowLabel: '很差',
                    highLabel: '很好',
                    value: _sleepQuality,
                    onChanged: (value) => setState(() => _sleepQuality = value),
                  ),
                  _RatingField(
                    label: '疲劳程度',
                    lowLabel: '轻松',
                    highLabel: '很疲劳',
                    value: _fatigue,
                    onChanged: (value) => setState(() => _fatigue = value),
                  ),
                  _RatingField(
                    label: '肌肉酸痛',
                    lowLabel: '没有',
                    highLabel: '明显',
                    value: _soreness,
                    onChanged: (value) => setState(() => _soreness = value),
                  ),
                  _RatingField(
                    label: '精力水平',
                    lowLabel: '很低',
                    highLabel: '很充足',
                    value: _energy,
                    onChanged: (value) => setState(() => _energy = value),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLength: 120,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '补充说明（可选）',
                      hintText: '例如：昨晚加班，今天想降低训练强度',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _canSave ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.favorite_outline),
                    label: Text(_saving ? '保存中' : '保存状态'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RatingField extends StatelessWidget {
  const _RatingField({
    required this.label,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String lowLabel;
  final String highLabel;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: List.generate(
              5,
              (index) => ButtonSegment<int>(value: index + 1, label: Text('${index + 1}')),
            ),
            selected: value == null ? const {} : {value!},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(lowLabel), Text(highLabel)],
          ),
        ],
      ),
    );
  }
}
