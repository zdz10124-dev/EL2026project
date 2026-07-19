import 'package:flutter/material.dart';

import '../../models/exercise_record.dart';
import '../../models/health_profile.dart';
import '../../services/health_profile_repository.dart';
import '../../widgets/section_card.dart';
import '../../widgets/themed_page_background.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key, required this.repository});
  final HealthProfileRepository repository;

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  HealthProfile _profile = const HealthProfile();
  final _days = TextEditingController();
  final _minutes = TextEditingController();
  final _birthYear = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _days.dispose();
    _minutes.dispose();
    _birthYear.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _days.text = profile.availableDaysPerWeek?.toString() ?? '';
      _minutes.text = profile.maxSessionMinutes?.toString() ?? '';
      _birthYear.text = profile.birthYear?.toString() ?? '';
      _height.text = profile.heightCm?.toString() ?? '';
      _weight.text = profile.weightKg?.toString() ?? '';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('健康目标')),
      body: ThemedPageBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前目标', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<HealthGoal>(
                          initialValue: _profile.goal,
                          items: HealthGoal.values
                              .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                              .toList(),
                          onChanged: (value) => setState(() {
                            if (value != null) _profile = _profile.copyWith(goal: value);
                          }),
                        ),
                        const SizedBox(height: 16),
                        const Text('偏好运动'),
                        Wrap(
                          spacing: 8,
                          children: ActivityType.values.map((type) => FilterChip(
                                label: Text(type.label),
                                selected: _profile.preferredActivities.contains(type),
                                onSelected: (selected) {
                                  final values = {..._profile.preferredActivities};
                                  selected ? values.add(type) : values.remove(type);
                                  setState(() => _profile =
                                      _profile.copyWith(preferredActivities: values));
                                },
                              )).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(children: [
                      _field(_days, '每周可运动天数（可选）'),
                      _field(_minutes, '单次最长分钟数（可选）'),
                      _field(_birthYear, '出生年份（可选）'),
                      _field(_height, '身高 cm（可选）', decimal: true),
                      _field(_weight, '体重 kg（可选）', decimal: true),
                      const Text('身体数据为可选项。未填写时，AI 不会输出精确热量缺口或体重预测。'),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _save, child: const Text('保存健康目标')),
                ],
              ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool decimal = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _save() async {
    final days = int.tryParse(_days.text.trim());
    final minutes = int.tryParse(_minutes.text.trim());
    final birthYear = int.tryParse(_birthYear.text.trim());
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    final currentYear = DateTime.now().year;
    if (days != null && (days < 1 || days > 7)) {
      _showError('每周可运动天数应在 1 到 7 之间');
      return;
    }
    if (minutes != null && minutes <= 0) {
      _showError('单次运动分钟数必须大于 0');
      return;
    }
    if (birthYear != null && (birthYear < 1900 || birthYear > currentYear)) {
      _showError('请输入有效的出生年份');
      return;
    }
    if (height != null && (height < 80 || height > 250)) {
      _showError('请输入有效的身高');
      return;
    }
    if (weight != null && (weight < 20 || weight > 400)) {
      _showError('请输入有效的体重');
      return;
    }
    final profile = HealthProfile(
      goal: _profile.goal,
      preferredActivities: _profile.preferredActivities,
      availableDaysPerWeek: days,
      maxSessionMinutes: minutes,
      birthYear: birthYear,
      heightCm: height,
      weightKg: weight,
    );
    await widget.repository.save(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('健康目标已保存')));
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
