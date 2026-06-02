import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _cacheKeyAnalysis = 'cached_nutrition_analysis';
  static const _cacheKeyTime = 'cached_nutrition_analysis_time';
  static const _cacheKeyPeriod = 'cached_nutrition_period';

  NutritionAnalysis? _analysis;
  bool _loading = false;
  bool _isCached = false;
  String? _cachedTime;
  String _period = 'week';

  @override
  void initState() {
    super.initState();
    _loadCachedOrAnalyze();
  }

  String get _cacheKeyWithPeriod => '$_cacheKeyAnalysis-$_period';

  Future<void> _loadCachedOrAnalyze() async {
    final cached = await _loadCached();
    if (cached != null) {
      setState(() {
        _analysis = cached;
        _isCached = true;
      });
    } else {
      _analyze();
    }
  }

  Future<NutritionAnalysis?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKeyWithPeriod);
      if (json == null || json.isEmpty) return null;
      _cachedTime = prefs.getString(_cacheKeyTime);
      return NutritionAnalysis.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheResult(NutritionAnalysis result) async {
    final prefs = await SharedPreferences.getInstance();
    final now = '${DateTime.now().month}/${DateTime.now().day} '
        '${DateTime.now().hour.toString().padLeft(2, '0')}:'
        '${DateTime.now().minute.toString().padLeft(2, '0')}';
    await prefs.setString(_cacheKeyWithPeriod, jsonEncode(result.toJson()));
    await prefs.setString(_cacheKeyTime, now);
    await prefs.setString(_cacheKeyPeriod, _period);
    _cachedTime = now;
  }

  Future<void> _analyze() async {
    if (!widget.agentService.isAvailable) return;

    setState(() => _loading = true);

    try {
      final allRecords = await widget.repository.fetchRecords();
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
      await _cacheResult(result);
      setState(() {
        _analysis = result;
        _loading = false;
        _isCached = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分析失败：$e')),
      );
    }
  }

  Future<void> _switchPeriod(String period) async {
    if (period == _period) return;
    setState(() {
      _period = period;
      _analysis = null;
      _isCached = false;
      _cachedTime = null;
    });
    _loadCachedOrAnalyze();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('营养分析'),
        actions: [
          if (widget.agentService.isAvailable &&
              !_loading &&
              _analysis != null)
            IconButton(
              tooltip: '刷新分析',
              onPressed: _analyze,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              _PeriodChip(
                label: '近 7 天',
                selected: _period == 'week',
                onTap: () => _switchPeriod('week'),
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: '近 30 天',
                selected: _period == 'month',
                onTap: () => _switchPeriod('month'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading) ...[
            _LoadingBanner(isCached: _analysis != null),
            if (_analysis != null) ...[
              const SizedBox(height: 12),
              _CachedBadge(time: _cachedTime),
            ],
          ],

          if (!_loading && _isCached && _analysis != null)
            _CachedBadge(time: _cachedTime),

          if (_analysis == null) ...[
            if (_loading)
              _emptyState('分析中...', 'AI 正在分析您的营养摄入情况，请稍候')
            else if (!widget.agentService.isAvailable)
              _emptyState('功能准备中', '请先在设置中配置 AI 模型',
                  icon: Icons.settings_outlined)
            else
              _emptyState('数据不足', '这段时间还没有用餐记录',
                  icon: Icons.restaurant_menu),
          ] else ...[
            const SizedBox(height: 8),
            _buildAnalysis(),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysis() {
    final a = _analysis!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          child: Column(
            children: [
              const Icon(Icons.health_and_safety, size: 48, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                a.overall,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (a.vegetableScore != null)
          _ScoreCard(
            label: '蔬菜摄入',
            score: a.vegetableScore!,
            icon: Icons.eco_outlined,
            color: Colors.green,
          ),
        if (a.proteinScore != null)
          _ScoreCard(
            label: '蛋白质摄入',
            score: a.proteinScore!,
            icon: Icons.fitness_center_outlined,
            color: Colors.blue,
          ),
        if (a.drinkStatus != null)
          _InfoCard(
            label: '饮品情况',
            value: a.drinkStatus!,
            icon: Icons.local_cafe_outlined,
          ),
        if (a.spicyStatus != null)
          _InfoCard(
            label: '口味情况',
            value: a.spicyStatus!,
            icon: Icons.whatshot_outlined,
          ),
        if (a.regularity != null)
          _InfoCard(
            label: '规律程度',
            value: a.regularity!,
            icon: Icons.schedule_outlined,
          ),
        if (a.suggestions != null && a.suggestions!.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('改善建议',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...a.suggestions!.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(fontSize: 13)),
                        Expanded(
                            child: Text(s, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyState(String title, String subtitle,
      {IconData icon = Icons.restaurant_menu}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
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
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade100,
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

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner({required this.isCached});

  final bool isCached;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCached
                  ? 'AI 正在重新分析您的营养状况...'
                  : 'AI 正在分析您的营养摄入情况，首次分析可能需要 10-30 秒...',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CachedBadge extends StatelessWidget {
  const _CachedBadge({required this.time});

  final String? time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            time != null ? '上次分析：$time' : '历史分析结果',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
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
            Text('$score/100',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
                  Text(label,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
