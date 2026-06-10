import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/meal_record.dart';
import '../models/style_presets.dart';
import '../services/meal_repository.dart';
import '../widgets/image_viewer.dart';
import '../widgets/themed_subpage_scaffold.dart';

class OptimizedJournalNotebookPage extends StatefulWidget {
  const OptimizedJournalNotebookPage({
    super.key,
    required this.entries,
    required this.style,
  });

  final List<JournalEntry> entries;
  final DiaryStyleSpec style;

  @override
  State<OptimizedJournalNotebookPage> createState() =>
      _OptimizedJournalNotebookPageState();
}

class _OptimizedJournalNotebookPageState
    extends State<OptimizedJournalNotebookPage> {
  static const int _neighborPreloadCount = 1;
  static const double _pageContentMaxHeight = 540;

  late final List<_NotebookPageData> _pages = _buildPages(widget.entries);
  late final List<GlobalKey> _pageKeys = List<GlobalKey>.generate(
    _pages.length,
    (_) => GlobalKey(),
  );
  final Map<String, ImageProvider> _imageProviderCache = {};
  int _pageIndex = 0;
  bool _exporting = false;
  bool _renderAllPages = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_warmVisiblePages());
    });
  }

  @override
  Widget build(BuildContext context) {
    final canGoPrev = _pageIndex > 0;
    final canGoNext = _pageIndex < _pages.length - 1;

    return ThemedSubpageScaffold(
      appBar: AppBar(
        title: Text('美食日记 · ${widget.style.name}'),
        actions: [
          PopupMenuButton<String>(
            enabled: !_exporting,
            onSelected: _handleExportAction,
            itemBuilder: (context) => const [
              PopupMenuItem<String>(value: 'share_image', child: Text('分享长图')),
              PopupMenuItem<String>(value: 'share_pdf', child: Text('分享 PDF')),
            ],
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  for (final pageIndex in _renderedPageIndexes)
                    Offstage(
                      offstage: pageIndex != _pageIndex,
                      child: RepaintBoundary(
                        key: _pageKeys[pageIndex],
                        child: _PageSurface(
                          style: widget.style,
                          child: _NotebookPage(
                            pageNumber: pageIndex + 1,
                            pageData: _pages[pageIndex],
                            style: widget.style,
                            imageProviders: _imageProviderCache,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: canGoPrev
                      ? () => _changePage(_pageIndex - 1)
                      : null,
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                ),
                Text('第 ${_pageIndex + 1} / ${_pages.length} 页'),
                IconButton(
                  onPressed: canGoNext
                      ? () => _changePage(_pageIndex + 1)
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

  List<int> get _renderedPageIndexes {
    if (_renderAllPages) {
      return List<int>.generate(_pages.length, (index) => index);
    }
    final start = max(0, _pageIndex - _neighborPreloadCount);
    final end = min(_pages.length - 1, _pageIndex + _neighborPreloadCount);
    return [for (var index = start; index <= end; index++) index];
  }

  Future<void> _changePage(int nextPageIndex) async {
    if (_pageIndex == nextPageIndex) {
      return;
    }
    setState(() => _pageIndex = nextPageIndex);
    await _waitForNextFrame();
    await _warmVisiblePages();
  }

  Future<void> _handleExportAction(String value) async {
    switch (value) {
      case 'share_image':
        await _shareAllPagesAsLongImage();
        return;
      case 'share_pdf':
        await _saveAllPagesAsPdf(shareAfterSave: true);
        return;
    }
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
    if (_exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      await action();
    } catch (error) {
      _showExportMessage('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _renderAllPages = false;
        });
      }
      if (mounted) {
        unawaited(_warmVisiblePages());
      }
    }
  }

  Future<File> _buildLongImageFile() async {
    final pageBytes = await _captureAllPagePngs();
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
    final pageBytes = await _captureAllPagePngs();
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

  Future<List<Uint8List>> _captureAllPagePngs() async {
    final originalPageIndex = _pageIndex;
    final images = <Uint8List>[];
    for (var index = 0; index < _pages.length; index++) {
      if (_pageIndex != index) {
        setState(() => _pageIndex = index);
        await _waitForNextFrame();
      }
      await _warmVisiblePages();
      await _waitForPaintStable(index);
      images.add(await _capturePagePng(index));
    }
    if (_pageIndex != originalPageIndex && mounted) {
      setState(() => _pageIndex = originalPageIndex);
      await _waitForNextFrame();
      await _warmVisiblePages();
    }
    return images;
  }

  Future<void> _warmVisiblePages() async {
    final start = max(0, _pageIndex - _neighborPreloadCount);
    final end = min(_pages.length - 1, _pageIndex + _neighborPreloadCount);
    await _precachePageRange(start, end);
  }

  Future<void> _precachePageRange(int start, int end) async {
    if (!mounted) {
      return;
    }
    final futures = <Future<void>>[];
    for (var pageIndex = start; pageIndex <= end; pageIndex++) {
      for (final imagePath in _pages[pageIndex].imagePaths) {
        futures.add(precacheImage(_imageProviderFor(imagePath), context));
      }
    }
    if (widget.style.backgroundAssetPath != null) {
      futures.add(
        precacheImage(AssetImage(widget.style.backgroundAssetPath!), context),
      );
    }
    if (futures.isEmpty) {
      return;
    }
    await Future.wait(futures);
  }

  ImageProvider _imageProviderFor(String imagePath) {
    return _imageProviderCache.putIfAbsent(
      imagePath,
      () => ResizeImage.resizeIfNeeded(420, 360, FileImage(File(imagePath))),
    );
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  Future<Uint8List> _capturePagePng(int pageIndex) async {
    final boundary =
        _pageKeys[pageIndex].currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _waitForPaintStable(int pageIndex) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      await _waitForNextFrame();
      final renderObject = _pageKeys[pageIndex].currentContext
          ?.findRenderObject();
      if (renderObject case final RenderRepaintBoundary boundary
          when !boundary.debugNeedsPaint) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
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
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<_NotebookPageData> _buildPages(List<JournalEntry> entries) {
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

    final pages = <_NotebookPageData>[];
    var cursor = 0;
    var pageSeed = 0;
    while (cursor < flat.length) {
      final chunk = <_NotebookItem>[];
      var usedHeight = 0.0;
      while (cursor < flat.length && chunk.length < 4) {
        final nextItem = flat[cursor];
        final estimatedHeight = _estimateItemHeight(nextItem);
        if (chunk.isNotEmpty &&
            usedHeight + estimatedHeight > _pageContentMaxHeight) {
          break;
        }
        chunk.add(nextItem);
        usedHeight += estimatedHeight;
        cursor++;
      }
      if (chunk.isEmpty) {
        chunk.add(flat[cursor]);
        cursor++;
      }
      final firstImageOnLeft = Random(pageSeed + 1).nextBool();
      for (var itemIndex = 0; itemIndex < chunk.length; itemIndex++) {
        chunk[itemIndex] = chunk[itemIndex].copyWith(
          imageOnLeft: itemIndex.isEven ? firstImageOnLeft : !firstImageOnLeft,
        );
      }
      pages.add(
        _NotebookPageData(
          items: List<_NotebookItem>.unmodifiable(chunk),
          imagePaths: {
            for (final item in chunk)
              if (item.record.imagePath.trim().isNotEmpty)
                item.record.imagePath,
          },
        ),
      );
      pageSeed++;
    }

    return pages.isEmpty
        ? const [
            _NotebookPageData(items: <_NotebookItem>[], imagePaths: <String>{}),
          ]
        : pages;
  }

  double _estimateItemHeight(_NotebookItem item) {
    var height = 126.0;
    if (item.showDateHeader) {
      height += widget.style.useDivider ? 42.0 : 28.0;
    }
    height += _estimateTextBlockHeight(item.record.dishName);
    height += _estimateTextBlockHeight(item.record.location);
    return height;
  }

  double _estimateTextBlockHeight(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '未填写') {
      return 0;
    }
    if (trimmed.length <= 14) {
      return 0;
    }
    if (trimmed.length <= 28) {
      return 18;
    }
    return 36;
  }
}

class _NotebookPageData {
  const _NotebookPageData({required this.items, required this.imagePaths});

  final List<_NotebookItem> items;
  final Set<String> imagePaths;
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

class _PageSurface extends StatelessWidget {
  const _PageSurface({required this.style, required this.child});

  final DiaryStyleSpec style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: style.pageBackgroundColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: style.shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NotebookPage extends StatelessWidget {
  const _NotebookPage({
    required this.pageNumber,
    required this.pageData,
    required this.style,
    required this.imageProviders,
  });

  final int pageNumber;
  final _NotebookPageData pageData;
  final DiaryStyleSpec style;
  final Map<String, ImageProvider> imageProviders;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _NotebookPaperBackground(style: style),
            ),
          ),
          if (pageData.items.isEmpty)
            Center(
              child: Text(
                '这一页暂时还没有内容',
                style: TextStyle(color: style.inkColor),
              ),
            )
          else
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pageData.items.length,
              itemBuilder: (context, index) {
                final item = pageData.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _NotebookRecordCard(
                    item: item,
                    seed: pageNumber * 10 + index,
                    style: style,
                    imageProvider: item.record.imagePath.trim().isEmpty
                        ? null
                        : imageProviders.putIfAbsent(
                            item.record.imagePath,
                            () => ResizeImage.resizeIfNeeded(
                              420,
                              360,
                              FileImage(File(item.record.imagePath)),
                            ),
                          ),
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

class _NotebookPaperBackground extends StatelessWidget {
  const _NotebookPaperBackground({required this.style});

  final DiaryStyleSpec style;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
    );
  }
}

class _NotebookRecordCard extends StatelessWidget {
  const _NotebookRecordCard({
    required this.item,
    required this.seed,
    required this.style,
    required this.imageProvider,
  });

  final _NotebookItem item;
  final int seed;
  final DiaryStyleSpec style;
  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    final random = Random(seed);
    final rotate = (random.nextDouble() * 8 - 4) * pi / 180;
    final record = item.record;
    final dishText = record.dishName == '未填写' ? '' : record.dishName;
    final locationText = record.location == '未填写' ? '' : record.location;
    final extraCount = record.imagePaths.length > 1
        ? record.imagePaths.length - 1
        : 0;

    final image = Transform.rotate(
      angle: rotate,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => openImageViewer(context, record.imagePaths),
            child: Container(
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
                child: imageProvider != null
                    ? Image(
                        image: imageProvider!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                      )
                    : Container(
                        color: style.paperColor,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.photo_outlined,
                          color: style.inkColor,
                        ),
                      ),
              ),
            ),
          ),
          if (extraCount > 0)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: style.inkColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                    color: style.paperColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
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
