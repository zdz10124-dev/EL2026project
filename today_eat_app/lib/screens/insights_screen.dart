import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:gal/gal.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/meal_record.dart';
import '../models/style_presets.dart';
import '../models/ui_config.dart';
import '../services/agent_service.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';
import '../widgets/themed_subpage_scaffold.dart';
import 'journal_notebook_page.dart' as optimized_journal;
import 'network_recommendation_screen.dart';
import 'nutrition_screen.dart';
import 'preference_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({
    super.key,
    required this.config,
    required this.repository,
    required this.defaultDiaryStyleId,
    this.agentService,
  });

  final UiConfig config;
  final MealRepository repository;
  final AgentService? agentService;
  final DiaryStyleId defaultDiaryStyleId;

  @override
  Widget build(BuildContext context) {
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
            final records = snapshot.data ?? const <MealRecord>[];
            return ListView(
              children: [
                Text(
                  config.pages.insightTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  records.isEmpty
                      ? '先记下几顿饭，这里会慢慢长成你的美食地图。'
                      : '从日记、统计、营养和推荐几个方向继续展开。',
                ),
                const SizedBox(height: 18),
                _InsightsGrid(
                  repository: repository,
                  agentService: agentService,
                  defaultDiaryStyleId: defaultDiaryStyleId,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InsightsGrid extends StatelessWidget {
  const _InsightsGrid({
    required this.repository,
    required this.agentService,
    required this.defaultDiaryStyleId,
  });

  final MealRepository repository;
  final AgentService? agentService;
  final DiaryStyleId defaultDiaryStyleId;

  @override
  Widget build(BuildContext context) {
    final cards = <_FeatureCardData>[
      _FeatureCardData(
        icon: Icons.menu_book_rounded,
        title: '美食日记',
        subtitle: '把记录做成可翻页的手账样式。',
        page: JournalGeneratorPage(
          repository: repository,
          defaultStyleId: defaultDiaryStyleId,
        ),
      ),
      _FeatureCardData(
        icon: Icons.analytics_outlined,
        title: '统计分析',
        subtitle: '看花费、菜品、地点和评分分布。',
        page: StatsAnalysisPage(repository: repository),
      ),
      _FeatureCardData(
        icon: Icons.restaurant_menu,
        title: '营养分析',
        subtitle: agentService?.isAvailable == true
            ? '让 AI 帮你看近期饮食结构。'
            : '先配置 AI，再开启营养分析。',
        page: agentService == null
            ? null
            : NutritionScreen(
                repository: repository,
                agentService: agentService!,
              ),
      ),
      _FeatureCardData(
        icon: Icons.public_rounded,
        title: '联网推荐',
        subtitle: '按地区、菜系和价格区间看周边推荐。',
        page: NetworkRecommendationPage(repository: repository),
      ),
      _FeatureCardData(
        icon: Icons.person_outline,
        title: '偏好分析',
        subtitle: agentService?.isAvailable == true
            ? '总结你更爱吃什么、常去哪里。'
            : '先配置 AI，再看口味画像。',
        page: agentService == null
            ? null
            : PreferenceScreen(
                repository: repository,
                agentService: agentService!,
              ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 210,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: card.page == null
              ? null
              : () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => card.page!)),
          child: SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(card.icon, size: 28),
                const SizedBox(height: 14),
                Text(card.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    card.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
    );
  }
}

class _FeatureCardData {
  const _FeatureCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? page;
}

class JournalGeneratorPage extends StatefulWidget {
  const JournalGeneratorPage({
    super.key,
    required this.repository,
    required this.defaultStyleId,
  });

  final MealRepository repository;
  final DiaryStyleId defaultStyleId;

  @override
  State<JournalGeneratorPage> createState() => _JournalGeneratorPageState();
}

class _JournalGeneratorPageState extends State<JournalGeneratorPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();
  late DiaryStyleId _styleId;

  @override
  void initState() {
    super.initState();
    _styleId = widget.defaultStyleId;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyleCatalog.diaryStyleById(_styleId);
    return ThemedSubpageScaffold(
      appBar: AppBar(title: const Text('美食日记')),
      child: FutureBuilder<List<MealRecord>>(
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppStyleCatalog.diaryStyles.map((item) {
                  return ChoiceChip(
                    label: Text(item.name),
                    selected: _styleId == item.id,
                    onSelected: (_) => setState(() => _styleId = item.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: journalEntries.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              optimized_journal.OptimizedJournalNotebookPage(
                                entries: journalEntries,
                                style: style,
                              ),
                        ),
                      ),
                child: const Text('生成美食日记'),
              ),
              const SizedBox(height: 18),
              Text('样式预览', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SectionCard(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: style.backgroundAssetPath == null
                        ? Container(color: style.paperColor)
                        : Image.asset(
                            style.backgroundAssetPath!,
                            fit: BoxFit.cover,
                          ),
                  ),
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
    required this.style,
  });

  final List<JournalEntry> entries;
  final DiaryStyleSpec style;

  @override
  State<JournalNotebookPage> createState() => _JournalNotebookPageState();
}

class _JournalNotebookPageState extends State<JournalNotebookPage> {
  final GlobalKey _pageKey = GlobalKey();
  int _pageIndex = 0;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(widget.entries);
    final page = pages[_pageIndex];
    final canGoPrev = _pageIndex > 0;
    final canGoNext = _pageIndex < pages.length - 1;

    return ThemedSubpageScaffold(
      appBar: AppBar(
        title: Text('美食日记 · ${widget.style.name}'),
        actions: [
          PopupMenuButton<String>(
            enabled: !_exporting,
            onSelected: _handleExportAction,
            itemBuilder: (context) => const [
              PopupMenuItem<String>(value: 'export_image', child: Text('导出图片')),
              PopupMenuItem<String>(value: 'export_pdf', child: Text('导出 PDF')),
            ],
          ),
          IconButton(
            tooltip: '分享长图',
            onPressed: _exporting ? null : _shareAllPagesAsLongImage,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: '导出完整 PDF',
            onPressed: _exporting
                ? null
                : () => _saveAllPagesAsPdf(shareAfterSave: false),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                key: _pageKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.style.pageBackgroundColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: widget.style.shadowColor,
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: _NotebookPage(
                    pageNumber: _pageIndex + 1,
                    items: page,
                    style: widget.style,
                  ),
                ),
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
            if (_exporting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExportAction(String value) async {
    switch (value) {
      case 'export_image':
        await _shareAllPagesAsLongImage();
        return;
      case 'export_pdf':
        await _saveAllPagesAsPdf(shareAfterSave: true);
        return;
    }
  }

  // ignore: unused_element
  Future<void> _saveAllPagesAsLongImage() async {
    await _runExportTask(() async {
      final file = await _buildLongImageFile();
      await Gal.putImage(file.path, album: 'Today Eat');
      _showExportMessage('已保存全部长图到系统图库');
    });
  }

  Future<void> _shareAllPagesAsLongImage() async {
    await _runExportTask(() async {
      final file = await _buildLongImageFile();
      await _shareFile(
        file: file,
        mimeType: 'image/png',
        text: '分享一份完整的美食日记长图',
      );
    });
  }

  Future<void> _saveAllPagesAsPdf({required bool shareAfterSave}) async {
    await _runExportTask(() async {
      final file = await _buildPdfFile();
      if (shareAfterSave) {
        await _shareFile(
          file: file,
          mimeType: 'application/pdf',
          text: '分享一份完整的美食日记 PDF',
        );
      } else {
        _showExportMessage('完整 PDF 已导出到 ${file.path}');
      }
    });
  }

  Future<void> _runExportTask(Future<void> Function() action) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await action();
    } catch (error) {
      _showExportMessage('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<File> _buildLongImageFile() async {
    final pages = _buildPages(widget.entries);
    final pageBytes = await _captureAllPagePngs(pageCount: pages.length);
    final stitchedBytes = _stitchImagesVertically(pageBytes);
    final exportDir = await _resolveExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(
      path.join(exportDir.path, 'food_journal_full_$timestamp.png'),
    );
    await file.writeAsBytes(stitchedBytes, flush: true);
    return file;
  }

  Future<File> _buildPdfFile() async {
    final pages = _buildPages(widget.entries);
    final pageBytes = await _captureAllPagePngs(pageCount: pages.length);
    final exportDir = await _resolveExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(
      path.join(exportDir.path, 'food_journal_full_$timestamp.pdf'),
    );
    final document = pw.Document();
    for (final bytes in pageBytes) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  Future<List<Uint8List>> _captureAllPagePngs({required int pageCount}) async {
    final originalPageIndex = _pageIndex;
    final images = <Uint8List>[];
    for (var index = 0; index < pageCount; index++) {
      if (_pageIndex != index) {
        setState(() => _pageIndex = index);
        await _waitForNextFrame();
        await Future<void>.delayed(const Duration(milliseconds: 24));
      }
      images.add(await _captureCurrentPagePng());
    }
    if (_pageIndex != originalPageIndex) {
      setState(() => _pageIndex = originalPageIndex);
      await _waitForNextFrame();
    }
    return images;
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  // ignore: unused_element
  Future<void> _exportCurrentPage({
    required String extension,
    required Future<void> Function(Uint8List bytes, File file) saver,
  }) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _captureCurrentPagePng();
      final exportDir = await _resolveExportDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(
        path.join(
          exportDir.path,
          'food_journal_page_${_pageIndex + 1}_$timestamp.$extension',
        ),
      );
      await saver(bytes, file);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导出到：${file.path}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<Uint8List> _captureCurrentPagePng() async {
    await _waitForPaintStable();
    final boundary =
        _pageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _waitForPaintStable() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      await _waitForNextFrame();
      final renderObject = _pageKey.currentContext?.findRenderObject();
      if (renderObject case final RenderRepaintBoundary boundary
          when !boundary.debugNeedsPaint) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Uint8List _stitchImagesVertically(List<Uint8List> pageBytes) {
    final decoded = pageBytes
        .map(img.decodeImage)
        .whereType<img.Image>()
        .toList(growable: false);
    if (decoded.isEmpty) {
      throw StateError('没有可用于拼接的页面');
    }

    final width = decoded.fold<int>(
      0,
      (value, image) => max(value, image.width),
    );
    final height = decoded.fold<int>(0, (value, image) => value + image.height);
    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    var offsetY = 0;
    for (final page in decoded) {
      final offsetX = ((width - page.width) / 2).round();
      img.compositeImage(canvas, page, dstX: offsetX, dstY: offsetY);
      offsetY += page.height;
    }

    return Uint8List.fromList(img.encodePng(canvas));
  }

  Future<Directory> _resolveExportDirectory() async {
    Directory? baseDirectory;
    try {
      baseDirectory = await getExternalStorageDirectory();
    } catch (_) {
      baseDirectory = null;
    }
    baseDirectory ??= await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      path.join(baseDirectory.path, 'journal_exports'),
    );
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }
    return exportDirectory;
  }

  Future<void> _shareFile({
    required File file,
    required String mimeType,
    required String text,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [XFile(file.path, mimeType: mimeType)],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _showExportMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    return ThemedSubpageScaffold(
      appBar: AppBar(title: const Text('统计分析')),
      child: FutureBuilder<List<MealRecord>>(
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
                    label: const Text('近 7 天'),
                    selected: _preset == StatsRangePreset.last7Days,
                    onSelected: (_) =>
                        setState(() => _preset = StatsRangePreset.last7Days),
                  ),
                  ChoiceChip(
                    label: const Text('近 30 天'),
                    selected: _preset == StatsRangePreset.last30Days,
                    onSelected: (_) =>
                        setState(() => _preset = StatsRangePreset.last30Days),
                  ),
                  ChoiceChip(
                    label: const Text('自定义'),
                    selected: _preset == StatsRangePreset.custom,
                    onSelected: (_) =>
                        setState(() => _preset = StatsRangePreset.custom),
                  ),
                ],
              ),
              if (_preset == StatsRangePreset.custom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateCard(
                        label: '开始日期',
                        value: _customStart,
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateCard(
                        label: '结束日期',
                        value: _customEnd,
                        onTap: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatTile(title: '记录数', value: '$recordCount'),
                  _StatTile(
                    title: '总花费',
                    value: '¥${totalCost.toStringAsFixed(1)}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatExpandableTile(title: '常去地点', entries: topLocations),
              const SizedBox(height: 12),
              _StatExpandableTile(title: '常吃菜品', entries: topDishes),
              const SizedBox(height: 12),
              _StatExpandableTile(title: '评分分布', entries: ratings),
            ],
          );
        },
      ),
    );
  }

  (DateTime, DateTime) _currentRange() {
    switch (_preset) {
      case StatsRangePreset.last7Days:
        return (
          DateTime.now().subtract(const Duration(days: 7)),
          DateTime.now(),
        );
      case StatsRangePreset.last30Days:
        return (
          DateTime.now().subtract(const Duration(days: 30)),
          DateTime.now(),
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              DateFormat('yyyy/MM/dd').format(value),
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
  const _NotebookPage({
    required this.pageNumber,
    required this.items,
    required this.style,
  });

  final int pageNumber;
  final List<_NotebookItem> items;
  final DiaryStyleSpec style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: style.paperColor,
                  image: style.backgroundAssetPath == null
                      ? null
                      : DecorationImage(
                          image: AssetImage(style.backgroundAssetPath!),
                          fit: BoxFit.cover,
                          opacity: 0.92,
                        ),
                ),
              ),
            ),
          ),
          if (items.isEmpty)
            Center(
              child: Text(
                '这一页暂时还没有内容',
                style: TextStyle(color: style.inkColor),
              ),
            )
          else
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _NotebookRecordCard(
                    item: item,
                    seed: pageNumber * 10 + index,
                    style: style,
                  ),
                );
              },
            ),
          Positioned(
            right: 14,
            bottom: 10,
            child: Text(
              '$pageNumber',
              style: TextStyle(
                color: style.inkColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotebookRecordCard extends StatelessWidget {
  const _NotebookRecordCard({
    required this.item,
    required this.seed,
    required this.style,
  });

  final _NotebookItem item;
  final int seed;
  final DiaryStyleSpec style;

  @override
  Widget build(BuildContext context) {
    final random = Random(seed);
    final rotate = (random.nextDouble() * 8 - 4) * pi / 180;
    final record = item.record;
    final dishText = record.dishName == '未填写' ? '' : record.dishName;
    final locationText = record.location == '未填写' ? '' : record.location;

    final image = Transform.rotate(
      angle: rotate,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 118,
            height: 102,
            decoration: BoxDecoration(
              color: style.paperColor,
              borderRadius: BorderRadius.circular(style.roundPhoto ? 18 : 8),
              boxShadow: [
                BoxShadow(
                  color: style.shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(style.roundPhoto ? 16 : 6),
              child: File(record.imagePath).existsSync()
                  ? Image.file(File(record.imagePath), fit: BoxFit.cover)
                  : Container(
                      color: style.paperColor,
                      child: Icon(Icons.photo_outlined, color: style.inkColor),
                    ),
            ),
          ),
          if (style.useTape)
            Positioned(
              top: -10,
              left: 28,
              child: Transform.rotate(
                angle: -0.08,
                child: Container(
                  width: 56,
                  height: 20,
                  decoration: BoxDecoration(
                    color: style.accentColor.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final text = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dishText.isNotEmpty)
            Text(
              dishText,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: style.inkColor),
            ),
          if (dishText.isNotEmpty && locationText.isNotEmpty)
            const SizedBox(height: 6),
          if (locationText.isNotEmpty)
            Text(locationText, style: TextStyle(color: style.inkColor)),
          if (dishText.isNotEmpty || locationText.isNotEmpty)
            const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm').format(record.createdAt),
            style: TextStyle(color: style.inkColor.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.showDateHeader) ...[
          Text(
            DateFormat('yyyy/MM/dd').format(item.journalDay),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: style.inkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (style.useDivider) ...[
            const SizedBox(height: 4),
            Divider(
              color: style.accentColor.withValues(alpha: 0.45),
              height: 16,
            ),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 10),
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
    return SectionCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(
          entries.isEmpty
              ? '暂无'
              : '${entries.first.key} · ${entries.first.value} 次',
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
                      trailing: Text('${entry.value} 次'),
                    ),
                  )
                  .toList(),
      ),
    );
  }
}
