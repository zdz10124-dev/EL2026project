import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preference_analysis.dart';
import '../services/agent_service.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';
import '../widgets/themed_page_background.dart';

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
  static const _cacheKeyAnalysis = 'cached_preference_analysis';
  static const _cacheKeyTime = 'cached_preference_analysis_time';

  PreferenceAnalysis? _analysis;
  bool _loading = false;
  bool _isCached = false;
  String? _cachedTime;

  @override
  void initState() {
    super.initState();
    _loadCachedOrAnalyze();
  }

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

  Future<PreferenceAnalysis?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKeyAnalysis);
      if (json == null || json.isEmpty) return null;
      _cachedTime = prefs.getString(_cacheKeyTime);
      return PreferenceAnalysis.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheResult(PreferenceAnalysis result) async {
    final prefs = await SharedPreferences.getInstance();
    final now = '${DateTime.now().month}/${DateTime.now().day} '
        '${DateTime.now().hour.toString().padLeft(2, '0')}:'
        '${DateTime.now().minute.toString().padLeft(2, '0')}';
    await prefs.setString(_cacheKeyAnalysis, jsonEncode(result.toJson()));
    await prefs.setString(_cacheKeyTime, now);
    _cachedTime = now;
  }

  Future<void> _analyze() async {
    if (!widget.agentService.isAvailable) return;

    setState(() => _loading = true);

    try {
      final allRecords = await widget.repository.fetchRecords();
      if (allRecords.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final result = await widget.agentService.analyzePreferences(allRecords);
      if (!mounted) return;
      await _cacheResult(result);
      setState(() {
        _analysis = result;
        _loading = false;
        _isCached = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAiError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('偏好分析'),
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
      body: ThemedPageBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          // 加载中 + 缓存提示
          if (_loading) ...[
            _LoadingBanner(isCached: _analysis != null),
            if (_analysis != null) ...[
              const SizedBox(height: 12),
              _CachedBadge(time: _cachedTime),
            ],
          ],

          // 缓存标记（非加载中时显示）
          if (!_loading && _isCached && _analysis != null)
            _CachedBadge(time: _cachedTime),

          if (_analysis == null) ...[
            if (_loading)
              _emptyState('分析中...', 'AI 正在根据您的用餐记录分析饮食偏好，请稍候')
            else if (!widget.agentService.isAvailable)
              _emptyState('功能准备中', '请先在设置中配置 AI 模型',
                  icon: Icons.settings_outlined)
            else
              _emptyState('数据不足', '还没有足够的用餐记录',
                  icon: Icons.insights_outlined),
          ] else ...[
            const SizedBox(height: 8),
            _buildAnalysis(),
          ],
          ],
        ),
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
              const Icon(Icons.person_outline, size: 48, color: Colors.amber),
              const SizedBox(height: 8),
              Text(
                '饮食偏好画像',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              if (a.summary != null)
                Text(
                  a.summary!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TagSection(
          icon: Icons.restaurant_outlined,
          label: '喜爱菜系',
          tags: a.favoriteCuisines,
          color: Colors.orange,
        ),
        _TagSection(
          icon: Icons.eco_outlined,
          label: '喜爱食材',
          tags: a.favoriteIngredients,
          color: Colors.green,
        ),
        _InfoRow(
          icon: Icons.whatshot_outlined,
          label: '口味偏好',
          value: a.spicePreference,
        ),
        if (a.favoriteDishes != null && a.favoriteDishes!.isNotEmpty)
          _TagSection(
            icon: Icons.star_outline,
            label: '常吃菜品',
            tags: a.favoriteDishes!,
            color: Colors.amber,
          ),
        if (a.favoriteLocations != null && a.favoriteLocations!.isNotEmpty)
          _TagSection(
            icon: Icons.place_outlined,
            label: '常去地点',
            tags: a.favoriteLocations!,
            color: Colors.blue,
          ),
        if (a.trends != null && a.trends!.isNotEmpty) ...[
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
                ...a.trends!.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(fontSize: 13)),
                        Expanded(
                            child: Text(t, style: const TextStyle(fontSize: 13))),
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
      {IconData icon = Icons.insights_outlined}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
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

  String _friendlyAiError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('未配置') || text.contains('not configured')) {
      return 'AI 还没有配置好，请先到设置页完成配置。';
    }
    if (text.contains('401') || text.contains('403') || text.contains('invalid')) {
      return 'AI 配置似乎无效，请检查密钥、模型或服务端配置。';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'AI 请求超时了，可以稍后再试一次。';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('failed host lookup')) {
      return '网络似乎不稳定，这次偏好分析没有成功。';
    }
    if (text.contains('429') || text.contains('quota')) {
      return 'AI 服务当前额度不足或请求太频繁，请稍后再试。';
    }
    return 'AI 分析失败了，请稍后重试。';
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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
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
                  ? 'AI 正在重新分析您的饮食偏好...'
                  : 'AI 正在分析您的饮食偏好，首次分析可能需要 10-30 秒...',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    softWrap: true,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
