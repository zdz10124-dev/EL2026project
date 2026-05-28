import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/meal_record.dart';
import '../models/recommendation_models.dart';
import '../models/ui_config.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';
import 'network_recommendation_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({
    super.key,
    required this.config,
    required this.repository,
  });

  final UiConfig config;
  final MealRepository repository;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        icon: Icons.menu_book_rounded,
        title: '美食日记',
        subtitle: '按时间生成可翻页的吃饭笔记预览',
        page: JournalGeneratorPage(repository: repository),
      ),
      (
        icon: Icons.analytics_outlined,
        title: '统计分析',
        subtitle: '查看金额、菜品、地点与评分分布',
        page: StatsAnalysisPage(repository: repository),
      ),
      (
        icon: Icons.spa_outlined,
        title: '营养分析',
        subtitle: '保留 AI 总评与营养接口位置',
        page: const NutritionAnalysisPage(),
      ),
      (
        icon: Icons.public_rounded,
        title: '联网推荐',
        subtitle: '按地区、菜系、价格区间筛选推荐',
        page: NetworkRecommendationPage(repository: repository),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: config.layout.pageHorizontalPadding,
          vertical: config.layout.pageVerticalPadding,
        ),
        child: StreamBuilder<List<MealRecord>>(
          stream: repository.recordsStream,
          initialData: const [],
          builder: (context, snapshot) {
            final records = snapshot.data ?? const [];
            return ListView(
              children: [
                Text(
                  config.pages.insightTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  records.isEmpty
                      ? '先记录几顿饭，再来看看这里的内容。'
                      : '从日记、统计、营养和推荐四个方向继续展开。',
                ),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => card.page),
                      ),
                      child: SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(card.icon, size: 28),
                            const SizedBox(height: 14),
                            Text(
                              card.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Expanded(child: Text(card.subtitle)),
                            const SizedBox(height: 10),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Icon(Icons.arrow_forward_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class JournalGeneratorPage extends StatefulWidget {
  const JournalGeneratorPage({super.key, required this.repository});

  final MealRepository repository;

  @override
  State<JournalGeneratorPage> createState() => _JournalGeneratorPageState();
}

class _JournalGeneratorPageState extends State<JournalGeneratorPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();
  String _style = '标准模式';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('美食日记')),
      body: FutureBuilder<List<MealRecord>>(
        future: widget.repository.filterRecords(
          start: DateTime(_startDate.year, _startDate.month, _startDate.day),
          end: DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            23,
            59,
            59,
          ),
        ),
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <MealRecord>[];
          final journalEntries = widget.repository.buildJournalEntries(records);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DateCard(
                      label: '开始日期',
                      value: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateCard(
                      label: '结束日期',
                      value: _endDate,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: journalEntries.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => JournalNotebookPage(
                            entries: journalEntries,
                            styleName: _style,
                          ),
                        ),
                      ),
                child: const Text('生成美食日记'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _style,
                decoration: const InputDecoration(labelText: '日记样式'),
                items: const [
                  DropdownMenuItem(value: '标准模式', child: Text('标准模式')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _style = value);
                  }
                },
              ),
              const SizedBox(height: 18),
              Text('预览', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (journalEntries.isEmpty)
                const SectionCard(child: Text('当前时间范围内没有记录，暂时无法生成美食日记。'))
              else
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('样式：$_style'),
                      const SizedBox(height: 8),
                      Text(
                        '将生成 ${journalEntries.length} 个日期段，按“凌晨 4 点到次日凌晨 4 点”为一天分组。',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '第一页预览日期：${DateFormat('yyyy/MM/dd').format(journalEntries.first.dayStart)}',
                      ),
                      const SizedBox(height: 8),
                      ...journalEntries.first.records
                          .take(4)
                          .map(
                            (record) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• ${record.dishName} / ${record.location} / ${DateFormat('MM/dd HH:mm').format(record.createdAt)}',
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (isStart) {
        _startDate = selected;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = selected;
        if (_startDate.isAfter(_endDate)) {
          _startDate = _endDate;
        }
      }
    });
  }
}

class JournalNotebookPage extends StatefulWidget {
  const JournalNotebookPage({
    super.key,
    required this.entries,
    required this.styleName,
  });

  final List<JournalEntry> entries;
  final String styleName;

  @override
  State<JournalNotebookPage> createState() => _JournalNotebookPageState();
}

class _JournalNotebookPageState extends State<JournalNotebookPage> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(widget.entries);
    final page = pages[_pageIndex];
    final canGoPrev = _pageIndex > 0;
    final canGoNext = _pageIndex < pages.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text('美食日记 · ${widget.styleName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F4E8),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: _NotebookPage(pageNumber: _pageIndex + 1, items: page),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: canGoPrev
                      ? () => setState(() => _pageIndex--)
                      : null,
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                ),
                Text('第 ${_pageIndex + 1} / ${pages.length} 页'),
                IconButton(
                  onPressed: canGoNext
                      ? () => setState(() => _pageIndex++)
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<List<_NotebookItem>> _buildPages(List<JournalEntry> entries) {
    final flat = <_NotebookItem>[];
    for (final entry in entries) {
      for (var index = 0; index < entry.records.length; index++) {
        flat.add(
          _NotebookItem(
            record: entry.records[index],
            showDateHeader: index == 0,
            journalDay: entry.dayStart,
          ),
        );
      }
    }

    final pages = <List<_NotebookItem>>[];
    for (var index = 0; index < flat.length; index += 4) {
      final chunk = flat.skip(index).take(4).toList();
      final firstImageOnLeft = Random(index + 1).nextBool();
      for (var itemIndex = 0; itemIndex < chunk.length; itemIndex++) {
        chunk[itemIndex] = chunk[itemIndex].copyWith(
          imageOnLeft: itemIndex.isEven ? firstImageOnLeft : !firstImageOnLeft,
        );
      }
      pages.add(chunk);
    }
    return pages.isEmpty ? [const <_NotebookItem>[]] : pages;
  }
}

class StatsAnalysisPage extends StatefulWidget {
  const StatsAnalysisPage({super.key, required this.repository});

  final MealRepository repository;

  @override
  State<StatsAnalysisPage> createState() => _StatsAnalysisPageState();
}

class _StatsAnalysisPageState extends State<StatsAnalysisPage> {
  StatsRangePreset _preset = StatsRangePreset.last7Days;
  DateTime _customStart = DateTime.now().subtract(const Duration(days: 29));
  DateTime _customEnd = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('统计分析')),
      body: FutureBuilder<List<MealRecord>>(
        future: widget.repository.filterRecords(
          start: _currentRange().$1,
          end: _currentRange().$2,
        ),
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <MealRecord>[];
          final details = widget.repository.buildDetailedStats(records);
          final totalCost = details['totalCost'] as double;
          final recordCount = details['recordCount'] as int;
          final topLocations =
              details['topLocations'] as List<MapEntry<String, int>>;
          final topDishes = details['topDishes'] as List<MapEntry<String, int>>;
          final ratings =
              details['ratingDistribution'] as List<MapEntry<String, int>>;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('近7天'),
                    selected: _preset == StatsRangePreset.last7Days,
                    onSelected: (_) =>
                        setState(() => _preset = StatsRangePreset.last7Days),
                  ),
                  ChoiceChip(
                    label: const Text('近30天'),
                    selected: _preset == StatsRangePreset.last30Days,
                    onSelected: (_) =>
                        setState(() => _preset = StatsRangePreset.last30Days),
                  ),
                  ChoiceChip(
                    label: const Text('自定义时间'),
                    selected: _preset == StatsRangePreset.custom,
                    onSelected: (_) =>
                        setState(() => _preset = StatsRangePreset.custom),
                  ),
                ],
              ),
              if (_preset == StatsRangePreset.custom) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DateCard(
                        label: '开始',
                        value: _customStart,
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateCard(
                        label: '结束',
                        value: _customEnd,
                        onTap: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatTile(
                    title: '总花费',
                    value: '¥${totalCost.toStringAsFixed(1)}',
                  ),
                  _StatTile(title: '记录次数', value: '$recordCount 条'),
                  _StatExpandableTile(title: '常去地点', entries: topLocations),
                  _StatExpandableTile(title: '常吃主菜', entries: topDishes),
                  _StatExpandableTile(title: '评分分布', entries: ratings),
                ],
              ),
              const SizedBox(height: 18),
              const SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI 观察'),
                    SizedBox(height: 8),
                    Text('后续这里将用于总结偏好菜品、地区、辣度和饮食规律。'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  (DateTime, DateTime) _currentRange() {
    final now = DateTime.now();
    switch (_preset) {
      case StatsRangePreset.last7Days:
        return (
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case StatsRangePreset.last30Days:
        return (
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29)),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case StatsRangePreset.custom:
        return (
          DateTime(_customStart.year, _customStart.month, _customStart.day),
          DateTime(
            _customEnd.year,
            _customEnd.month,
            _customEnd.day,
            23,
            59,
            59,
          ),
        );
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final current = isStart ? _customStart : _customEnd;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (isStart) {
        _customStart = selected;
      } else {
        _customEnd = selected;
      }
    });
  }
}

class NutritionAnalysisPage extends StatefulWidget {
  const NutritionAnalysisPage({super.key});

  @override
  State<NutritionAnalysisPage> createState() => _NutritionAnalysisPageState();
}

class _NutritionAnalysisPageState extends State<NutritionAnalysisPage> {
  String _range = '本周';

  @override
  Widget build(BuildContext context) {
    final items = ['蔬菜摄入', '蛋白质摄入', '饮品情况', '重口味情况', '规律程度'];
    return Scaffold(
      appBar: AppBar(title: const Text('营养分析')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '本周', label: Text('本周')),
              ButtonSegment(value: '本月', label: Text('本月')),
            ],
            selected: {_range},
            onSelectionChanged: (values) =>
                setState(() => _range = values.first),
          ),
          const SizedBox(height: 18),
          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('总评'),
                SizedBox(height: 8),
                Text('功能准备中。后续这里将显示 AI 生成的总体营养评价。'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('接口预留中，当前先保留固定布局。'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecommendationListPage extends StatefulWidget {
  const RecommendationListPage({super.key, required this.repository});

  final MealRepository repository;

  @override
  State<RecommendationListPage> createState() => _RecommendationListPageState();
}

class _RecommendationListPageState extends State<RecommendationListPage> {
  String _region = '全部';
  String _cuisine = '全部';
  String _priceRange = '全部';
  String _sort = '评分优先';

  @override
  Widget build(BuildContext context) {
    final all = widget.repository.getMockRecommendations();
    var items = all.where((item) {
      final regionOk = _region == '全部' || item.region == _region;
      final cuisineOk = _cuisine == '全部' || item.cuisine == _cuisine;
      final priceOk =
          _priceRange == '全部' ||
          (_priceRange == '20元以下' && item.price < 20) ||
          (_priceRange == '20-30元' && item.price >= 20 && item.price <= 30) ||
          (_priceRange == '30元以上' && item.price > 30);
      return regionOk && cuisineOk && priceOk;
    }).toList();

    if (_sort == '评分优先') {
      items.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      items.sort((a, b) => a.price.compareTo(b.price));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('联网推荐')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FilterChip(
                label: '地区',
                value: _region,
                options: const ['全部', '鼓楼校区', '仙林校区', '上海'],
                onChanged: (value) => setState(() => _region = value),
              ),
              _FilterChip(
                label: '菜系',
                value: _cuisine,
                options: const ['全部', '家常菜', '川味', '简餐'],
                onChanged: (value) => setState(() => _cuisine = value),
              ),
              _FilterChip(
                label: '价格区间',
                value: _priceRange,
                options: const ['全部', '20元以下', '20-30元', '30元以上'],
                onChanged: (value) => setState(() => _priceRange = value),
              ),
              _FilterChip(
                label: '排序',
                value: _sort,
                options: const ['评分优先', '价格优先'],
                onChanged: (value) => setState(() => _sort = value),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const SectionCard(child: Text('暂时没有可用推荐'))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RecommendationDetailPage(item: item),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD96C3D), Color(0xFFFFC46C)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.store} · ${item.region} · ¥${item.price.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '评分 ${item.rating.toStringAsFixed(1)} · ${item.reason}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RecommendationDetailPage extends StatelessWidget {
  const RecommendationDetailPage({super.key, required this.item});

  final RecommendationItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFD96C3D), Color(0xFFFFC46C)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Text(item.store, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '${item.region} · ${item.cuisine} · ¥${item.price.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          Text('推荐评分：${item.rating.toStringAsFixed(1)}'),
          const SizedBox(height: 18),
          const Text('推荐理由'),
          const SizedBox(height: 8),
          Text(item.reason),
          const SizedBox(height: 18),
          const Text('详细介绍'),
          const SizedBox(height: 8),
          Text(item.description),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 6),
            Text(DateFormat('yyyy/MM/dd').format(value)),
          ],
        ),
      ),
    );
  }
}

class _NotebookItem {
  const _NotebookItem({
    required this.record,
    required this.showDateHeader,
    required this.journalDay,
    this.imageOnLeft = true,
  });

  final MealRecord record;
  final bool showDateHeader;
  final DateTime journalDay;
  final bool imageOnLeft;

  _NotebookItem copyWith({
    MealRecord? record,
    bool? showDateHeader,
    DateTime? journalDay,
    bool? imageOnLeft,
  }) {
    return _NotebookItem(
      record: record ?? this.record,
      showDateHeader: showDateHeader ?? this.showDateHeader,
      journalDay: journalDay ?? this.journalDay,
      imageOnLeft: imageOnLeft ?? this.imageOnLeft,
    );
  }
}

class _NotebookPage extends StatelessWidget {
  const _NotebookPage({required this.pageNumber, required this.items});

  final int pageNumber;
  final List<_NotebookItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFFFFFBF4),
              ),
            ),
          ),
          items.isEmpty
              ? const Center(child: Text('这一页暂时没有内容'))
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _NotebookRecordCard(
                        item: item,
                        seed: pageNumber * 10 + index,
                      ),
                    );
                  },
                ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Text(
              '$pageNumber',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.brown.shade400),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotebookRecordCard extends StatelessWidget {
  const _NotebookRecordCard({required this.item, required this.seed});

  final _NotebookItem item;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final random = Random(seed);
    final rotate = (random.nextDouble() * 50 - 25) * pi / 180;
    final record = item.record;

    final image = Transform.rotate(
      angle: rotate,
      child: Container(
        width: 110,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: File(record.imagePath).existsSync()
              ? Image.file(File(record.imagePath), fit: BoxFit.cover)
              : const Icon(Icons.photo_outlined),
        ),
      ),
    );

    final dishText = record.dishName == '未填写' ? '' : record.dishName;
    final locationText = record.location == '未填写' ? '' : record.location;

    final text = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dishText.isNotEmpty)
            Text(dishText, style: Theme.of(context).textTheme.titleMedium),
          if (dishText.isNotEmpty && locationText.isNotEmpty)
            const SizedBox(height: 6),
          if (locationText.isNotEmpty) Text(locationText),
          if (dishText.isNotEmpty || locationText.isNotEmpty)
            const SizedBox(height: 4),
          Text(DateFormat('HH:mm').format(record.createdAt)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.showDateHeader) ...[
          Text(
            DateFormat('yyyy/MM/dd').format(item.journalDay),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300, height: 16),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: item.imageOnLeft
              ? [image, const SizedBox(width: 14), text]
              : [text, const SizedBox(width: 14), image],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 28,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _StatExpandableTile extends StatelessWidget {
  const _StatExpandableTile({required this.title, required this.entries});

  final String title;
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width - 40,
      child: SectionCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(
            entries.isEmpty
                ? '暂无'
                : '${entries.first.key} · ${entries.first.value}次',
          ),
          children: entries.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('暂无数据'),
                  ),
                ]
              : entries
                    .map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.key),
                        trailing: Text('${entry.value}次'),
                      ),
                    )
                    .toList(),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox.shrink(),
      items: options
          .map(
            (option) =>
                DropdownMenuItem(value: option, child: Text('$label：$option')),
          )
          .toList(),
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}
