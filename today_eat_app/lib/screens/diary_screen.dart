import 'package:flutter/material.dart';

import '../models/food_diary.dart';
import '../services/agent_service.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';
import '../widgets/themed_subpage_scaffold.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.repository,
    required this.agentService,
  });

  final MealRepository repository;
  final AgentService agentService;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  bool _generating = false;
  FoodDiary? _diary;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      helpText: '选择日期范围',
      confirmText: '确定',
      cancelText: '取消',
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Future<void> _generate() async {
    if (!widget.agentService.isAvailable) {
      _showAiNotConfiguredDialog();
      return;
    }

    setState(() {
      _generating = true;
      _diary = null;
    });

    try {
      // 获取日期范围内的记录
      final allRecords = await widget.repository.fetchRecords();
      final filtered = allRecords.where((r) {
        return r.createdAt.isAfter(
              _dateRange.start.subtract(const Duration(days: 1)),
            ) &&
            r.createdAt.isBefore(_dateRange.end.add(const Duration(days: 1)));
      }).toList();

      if (filtered.isEmpty) {
        if (!mounted) return;
        setState(() => _generating = false);
        _showSnackBar('所选时间范围内没有记录');
        return;
      }

      final diary = await widget.agentService.generateFoodDiary(
        records: filtered,
        startDate: '${_dateRange.start.month}/${_dateRange.start.day}',
        endDate: '${_dateRange.end.month}/${_dateRange.end.day}',
      );

      if (!mounted) return;
      setState(() {
        _diary = diary;
        _generating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _generating = false);
      _showSnackBar(_friendlyAiError(error));
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showAiNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 未配置'),
        content: const Text(
          'AI 功能需要先在设置中配置模型。\n\n'
          '请前往「设置 → 智能功能 → AI 模型配置」完成设置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _friendlyAiError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('未配置') || text.contains('not configured')) {
      return 'AI 还没有配置好，请先到设置页完成配置。';
    }
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('invalid')) {
      return 'AI 配置似乎无效，请检查密钥、模型或服务端配置。';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'AI 请求超时了，可以稍后再试一次。';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('failed host lookup')) {
      return '网络似乎不稳定，这次日记生成没有成功。';
    }
    if (text.contains('429') || text.contains('quota')) {
      return 'AI 服务当前额度不足或请求太频繁，请稍后再试。';
    }
    return 'AI 生成失败了，请稍后重试。';
  }

  @override
  Widget build(BuildContext context) {
    return ThemedSubpageScaffold(
      appBar: AppBar(title: const Text('美食日记')),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 日期范围选择
          SectionCard(
            child: InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('选择日期范围', style: TextStyle(fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            '${_dateRange.start.month}/${_dateRange.start.day} '
                            '- '
                            '${_dateRange.end.month}/${_dateRange.end.day}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 生成按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_stories),
              label: Text(_generating ? 'AI 正在创作...' : '生成美食日记'),
            ),
          ),
          const SizedBox(height: 24),

          // 日记展示
          if (_diary != null) ...[
            // 标题
            Text(
              _diary!.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${_diary!.date}  ·  ${_diary!.mood ?? ""}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // 正文
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _diary!.content,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_diary!.summary != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _diary!.summary!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (!_generating) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '选择日期范围，点击生成按钮',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI 会为这段时间的用餐记录创作一篇温暖的日记',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
