import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../services/agent_service.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({
    super.key,
    required this.repository,
    required this.agentService,
  });

  final MealRepository repository;
  final AgentService agentService;

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  NutritionAnalysis? _analysis;
  bool _loading = false;
  String _period = 'week'; // week | month

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    if (!widget.agentService.isAvailable) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final allRecords = await widget.repository.recordsStream.first;
      final cutoff = _period == 'week'
          ? DateTime.now().subtract(const Duration(days: 7))
          : DateTime.now().subtract(const Duration(days: 30));
      final filtered =
          allRecords.where((r) => r.createdAt.isAfter(cutoff)).toList();

      if (filtered.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final result = await widget.agentService.analyzeNutrition(filtered);
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分析失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('营养分析')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 时间切换
          Row(
            children: [
              _PeriodChip(
                label: '近 7 天',
                selected: _period == 'week',
                onTap: () {
                  setState(() {
                    _period = 'week';
                    _analysis = null;
                  });
                  _analyze();
                },
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: '近 30 天',
                selected: _period == 'month',
                onTap: () {
                  setState(() {
                    _period = 'month';
                    _analysis = null;
                  });
                  _analyze();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (!widget.agentService.isAvailable) ...[
            _emptyState('功能准备中', '请先在设置中配置 AI 模型'),
          ] else if (_analysis == null) ...[
            _emptyState('数据不足', '这段时间还没有用餐记录'),
          ] else ...[
            // 总体评价
            SectionCard(
              child: Column(
                children: [
                  const Icon(Icons.health_and_safety,
                      size: 48, color: Colors.green),
                  const SizedBox(height: 8),
                  Text(
                    _analysis!.overall,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 评分项
            if (_analysis!.vegetableScore != null)
              _ScoreCard(
                label: '蔬菜摄入',
                score: _analysis!.vegetableScore!,
                icon: Icons.eco_outlined,
                color: Colors.green,
              ),
            if (_analysis!.proteinScore != null)
              _ScoreCard(
                label: '蛋白质摄入',
                score: _analysis!.proteinScore!,
                icon: Icons.fitness_center_outlined,
                color: Colors.blue,
              ),
            if (_analysis!.drinkStatus != null)
              _InfoCard(
                label: '饮品情况',
                value: _analysis!.drinkStatus!,
                icon: Icons.local_cafe_outlined,
              ),
            if (_analysis!.spicyStatus != null)
              _InfoCard(
                label: '口味情况',
                value: _analysis!.spicyStatus!,
                icon: Icons.whatshot_outlined,
              ),
            if (_analysis!.regularity != null)
              _InfoCard(
                label: '规律程度',
                value: _analysis!.regularity!,
                icon: Icons.schedule_outlined,
              ),

            // 建议
            if (_analysis!.suggestions != null &&
                _analysis!.suggestions!.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('改善建议',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._analysis!.suggestions!.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: TextStyle(fontSize: 13)),
                            Expanded(child: Text(s, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
  });

  final String label;
  final int score;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: score >= 70
                    ? Colors.green
                    : score >= 40
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Text('$score/100', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
