import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/health_metrics.dart';
import '../../models/integrated_health_analysis.dart';
import '../../services/health_analysis_repository.dart';
import '../../widgets/section_card.dart';
import '../../widgets/themed_page_background.dart';

class IntegratedHealthScreen extends StatefulWidget {
  const IntegratedHealthScreen({super.key, required this.repository});

  final HealthAnalysisRepository repository;

  @override
  State<IntegratedHealthScreen> createState() => _IntegratedHealthScreenState();
}

class _IntegratedHealthScreenState extends State<IntegratedHealthScreen> {
  AnalysisPeriod _period = AnalysisPeriod.sevenDays;
  HealthAnalysisState? _state;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final state = await widget.repository.load(_period, forceRefresh: force);
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('综合健康分析'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh),
            tooltip: '重新分析',
          ),
        ],
      ),
      body: ThemedPageBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<AnalysisPeriod>(
              segments: AnalysisPeriod.values
                  .map((item) => ButtonSegment(value: item, label: Text(item.label)))
                  .toList(),
              selected: {_period},
              onSelectionChanged: _loading
                  ? null
                  : (value) {
                      setState(() => _period = value.first);
                      _load();
                    },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const SectionCard(
                child: Row(children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Expanded(child: Text('正在汇总饮食与运动数据…')),
                ]),
              )
            else if (_state != null) ..._buildState(_state!),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildState(HealthAnalysisState state) {
    final widgets = <Widget>[
      _AnalysisStatusCard(state: state),
      const SizedBox(height: 12),
      _MetricsCard(metrics: state.metrics),
      const SizedBox(height: 12),
    ];
    if (state.message != null) {
      widgets.add(SectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(state.message!)),
          ],
        ),
      ));
      widgets.add(const SizedBox(height: 12));
    }
    final analysis = state.analysis;
    if (analysis == null) {
      widgets.add(const SectionCard(
        child: Text('当前仍可查看本地统计。记录至少两天数据并配置 AI 后，可生成综合建议。'),
      ));
      return widgets;
    }
    widgets.add(SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('健康概览', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(analysis.overview),
        ],
      ),
    ));
    for (final category in RecommendationCategory.values) {
      final items = analysis.recommendations
          .where((item) => item.category == category)
          .toList();
      if (items.isEmpty) continue;
      widgets.add(const SizedBox(height: 12));
      widgets.add(Text(category.label, style: Theme.of(context).textTheme.titleLarge));
      widgets.add(const SizedBox(height: 8));
      widgets.addAll(items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RecommendationCard(item: item),
          )));
    }
    if (analysis.riskAlerts.isNotEmpty) {
      widgets.add(SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('风险提示', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...analysis.riskAlerts.map((item) => Text('• $item')),
          ],
        ),
      ));
    }
    widgets.add(const SizedBox(height: 12));
    widgets.add(Text(analysis.disclaimer, style: Theme.of(context).textTheme.bodySmall));
    return widgets;
  }
}

class _AnalysisStatusCard extends StatelessWidget {
  const _AnalysisStatusCard({required this.state});
  final HealthAnalysisState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.status) {
      HealthAnalysisStatus.insufficientData => '数据不足',
      HealthAnalysisStatus.aiUnavailable => 'AI 未配置',
      HealthAnalysisStatus.fresh => '刚刚生成',
      HealthAnalysisStatus.cached => '当前数据缓存',
      HealthAnalysisStatus.staleCache => '历史缓存',
      HealthAnalysisStatus.failure => '分析失败',
    };
    final generatedAt = state.analysis?.generatedAt;
    return SectionCard(
      child: Row(
        children: [
          const Icon(Icons.verified_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(generatedAt == null
                ? '分析状态：$label'
                : '分析状态：$label · ${DateFormat('MM-dd HH:mm').format(generatedAt)}'),
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics});
  final HealthMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('数据概览', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric('饮食记录', '${metrics.mealCount} 条'),
              _metric('运动次数', '${metrics.exerciseCount} 次'),
              _metric('运动时长', '${(metrics.totalExerciseSeconds / 60).round()} 分钟'),
              _metric('运动距离', '${(metrics.totalDistanceMeters / 1000).toStringAsFixed(1)} km'),
              _metric('活跃天数', '${metrics.dataQuality.activeDays} 天'),
              if (metrics.averageRpe != null)
                _metric('平均 RPE', metrics.averageRpe!.toStringAsFixed(1)),
              if (metrics.postWorkoutMealCoverage != null)
                _metric(
                  '运动后饮食',
                  '${(metrics.postWorkoutMealCoverage! * 100).round()}%',
                ),
            ],
          ),
          if (metrics.highLoadDays.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('高负荷日期：${metrics.highLoadDays.join('、')}'),
          ],
          if (metrics.dataQuality.missingFields.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('数据缺口：${metrics.dataQuality.missingFields.join('、')}'),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item});
  final HealthRecommendation item;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(switch (item.category) {
          RecommendationCategory.diet => Icons.restaurant_outlined,
          RecommendationCategory.exercise => Icons.directions_run,
          RecommendationCategory.rest => Icons.bedtime_outlined,
        }),
        title: Text(item.title),
        subtitle: Text(item.action),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('建议依据\n${item.evidence.map((e) => '• $e').join('\n')}'),
          ),
        ],
      ),
    );
  }
}
