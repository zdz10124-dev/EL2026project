import 'package:flutter/material.dart';

import '../models/preference_analysis.dart';
import '../services/agent_service.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({
    super.key,
    required this.repository,
    required this.agentService,
  });

  final MealRepository repository;
  final AgentService agentService;

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  PreferenceAnalysis? _analysis;
  bool _loading = false;

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
      if (allRecords.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final result = await widget.agentService.analyzePreferences(allRecords);
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
      appBar: AppBar(title: const Text('偏好分析')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (!widget.agentService.isAvailable) ...[
            _emptyState('功能准备中', '请先在设置中配置 AI 模型'),
          ] else if (_analysis == null) ...[
            _emptyState('数据不足', '还没有用餐记录'),
          ] else ...[
            // 整体总结
            SectionCard(
              child: Column(
                children: [
                  const Icon(Icons.person_outline,
                      size: 48, color: Colors.amber),
                  const SizedBox(height: 8),
                  Text(
                    '饮食偏好画像',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  if (_analysis!.summary != null)
                    Text(
                      _analysis!.summary!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 各维度
            _TagSection(
              icon: Icons.restaurant_outlined,
              label: '喜爱菜系',
              tags: _analysis!.favoriteCuisines,
              color: Colors.orange,
            ),
            _TagSection(
              icon: Icons.eco_outlined,
              label: '喜爱食材',
              tags: _analysis!.favoriteIngredients,
              color: Colors.green,
            ),
            _InfoRow(
              icon: Icons.whatshot_outlined,
              label: '口味偏好',
              value: _analysis!.spicePreference,
            ),
            if (_analysis!.favoriteDishes != null &&
                _analysis!.favoriteDishes!.isNotEmpty)
              _TagSection(
                icon: Icons.star_outline,
                label: '常吃菜品',
                tags: _analysis!.favoriteDishes!,
                color: Colors.amber,
              ),
            if (_analysis!.favoriteLocations != null &&
                _analysis!.favoriteLocations!.isNotEmpty)
              _TagSection(
                icon: Icons.place_outlined,
                label: '常去地点',
                tags: _analysis!.favoriteLocations!,
                color: Colors.blue,
              ),

            // 趋势
            if (_analysis!.trends != null &&
                _analysis!.trends!.isNotEmpty) ...[
              const SizedBox(height: 8),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trending_up, size: 20, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('饮食趋势',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._analysis!.trends!.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: TextStyle(fontSize: 13)),
                            Expanded(
                                child: Text(t,
                                    style: const TextStyle(fontSize: 13))),
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
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Icon(Icons.insights_outlined,
                size: 64, color: Colors.grey.shade300),
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

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.icon,
    required this.label,
    required this.tags,
    required this.color,
  });

  final IconData icon;
  final String label;
  final List<String> tags;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(t,
                            style: TextStyle(fontSize: 13, color: color)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
