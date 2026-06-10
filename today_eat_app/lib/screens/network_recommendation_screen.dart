import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recommendation_comment.dart';
import '../models/recommendation_models.dart';
import '../services/location_service.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';
import '../widgets/themed_page_background.dart';
import '../widgets/themed_subpage_scaffold.dart';

class NetworkRecommendationPage extends StatefulWidget {
  const NetworkRecommendationPage({super.key, required this.repository});

  final MealRepository repository;

  @override
  State<NetworkRecommendationPage> createState() =>
      _NetworkRecommendationPageState();
}

class _NetworkRecommendationPageState extends State<NetworkRecommendationPage> {
  static const int _pageSize = 12;
  static _RecommendationPageCache? _pageCache;
  static final Map<String, RecommendationDetail> _detailCache =
      <String, RecommendationDetail>{};

  final ScrollController _scrollController = ScrollController();
  final LocationService _locationService = LocationService();

  List<RecommendationItem> _items = const [];
  RecommendationDistanceBucket? _distanceBucket;
  List<RecommendationPriceBucket> _priceBuckets = const [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _errorText;
  LocationResult? _locationResult;

  @override
  void initState() {
    super.initState();
    _restoreCache();
    _scrollController.addListener(_handleScroll);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemedSubpageScaffold(
      appBar: AppBar(
        title: const Text('联网推荐'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _handleRefreshButton,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: RefreshIndicator(
        onRefresh: () => _loadRecommendations(refresh: true),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            _buildLocationBanner(context),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FilterChipButton(
                  label: '距离',
                  valueText: _distanceBucket?.label ?? '不限',
                  onTap: _showDistanceSelector,
                ),
                _FilterChipButton(
                  label: '价格区间',
                  valueText: _priceBuckets.isEmpty
                      ? '不限'
                      : _priceBuckets.map((item) => item.label).join(' / '),
                  onTap: _showPriceSelector,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorText != null)
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_errorText!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _loadRecommendations(refresh: true),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              )
            else if (_items.isEmpty)
              const SectionCard(child: Text('当前没有符合条件的记录。可以尝试清空筛选条件，或者稍后再来看看。'))
            else ...[
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecommendationListCard(
                    item: item,
                    repository: widget.repository,
                    detailCache: _detailCache,
                    onVote: _handleVote,
                    onReport: _handleReport,
                  ),
                ),
              ),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loadingMore && _items.length < _total)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('继续下滑加载更多')),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _canUseDistanceFilter =>
      _locationResult?.success == true &&
      _locationResult?.latitude != null &&
      _locationResult?.longitude != null;

  void _restoreCache() {
    final cache = _pageCache;
    if (cache == null) {
      return;
    }
    _items = List<RecommendationItem>.from(cache.items);
    _distanceBucket = cache.distanceBucket;
    _priceBuckets = List<RecommendationPriceBucket>.from(cache.priceBuckets);
    _page = cache.page;
    _total = cache.total;
    _locationResult = cache.locationResult;
    _loading = false;
  }

  Future<void> _bootstrap() async {
    _distanceBucket ??= await widget.repository
        .getSavedRecommendationDistanceBucket();
    if (!mounted) return;
    if (_distanceBucket != null && _locationResult == null) {
      _resolveLocation().timeout(const Duration(seconds: 8)).catchError((_) {});
    }
    _syncUploadsSilently();
    await _loadRecommendations(refresh: true, showSpinner: _items.isEmpty);
  }

  Future<void> _handleRefreshButton() async {
    await _resolveLocation();
    unawaited(_syncUploadsSilently());
    await _loadRecommendations(refresh: true);
  }

  Future<void> _resolveLocation() async {
    final result = await _locationService.getCurrentAddress();
    if (!mounted) {
      return;
    }
    setState(() => _locationResult = result);
  }

  Future<void> _syncUploadsSilently() async {
    try {
      await widget.repository.syncPublicRecords();
    } catch (_) {
      // Ignore background sync failures in the recommendation feed.
    }
  }

  Future<void> _loadRecommendations({
    required bool refresh,
    bool showSpinner = true,
  }) async {
    final nextPage = refresh ? 1 : _page + 1;
    if (refresh) {
      if (showSpinner) {
        setState(() {
          _loading = true;
          _errorText = null;
        });
      } else {
        setState(() => _errorText = null);
      }
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final query = RecommendationQuery(
        distanceBuckets: _canUseDistanceFilter && _distanceBucket != null
            ? <RecommendationDistanceBucket>[_distanceBucket!]
            : const <RecommendationDistanceBucket>[],
        priceBuckets: _priceBuckets,
        page: nextPage,
        pageSize: _pageSize,
        latitude: _locationResult?.latitude,
        longitude: _locationResult?.longitude,
      );
      final page = await widget.repository.searchRecommendations(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _page = page.page;
        _total = page.total;
        _items = refresh ? page.items : [..._items, ...page.items];
        _loading = false;
        _loadingMore = false;
        _errorText = null;
      });
      _persistPageCache();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorText = _friendlyRecommendationError(error);
      });
    }
  }

  String _friendlyRecommendationError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('timeout') || text.contains('timed out'))
      return '联网推荐服务响应超时，请检查网络后重试。';
    if (text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('connection') ||
        text.contains('network'))
      return '无法连接联网推荐服务，请检查网络后重试。';
    return '加载推荐失败，请稍后重试。';
  }

  void _persistPageCache() {
    _pageCache = _RecommendationPageCache(
      items: List<RecommendationItem>.from(_items),
      distanceBucket: _distanceBucket,
      priceBuckets: List<RecommendationPriceBucket>.from(_priceBuckets),
      page: _page,
      total: _total,
      locationResult: _locationResult,
    );
  }

  void _handleScroll() {
    if (_loadingMore || _loading || _items.length >= _total) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      unawaited(_loadRecommendations(refresh: false));
    }
  }

  Future<void> _showDistanceSelector() async {
    final result =
        await showModalBottomSheet<
          _SingleChoiceResult<RecommendationDistanceBucket>
        >(
          context: context,
          showDragHandle: true,
          builder: (context) =>
              _SingleChoiceSelectorSheet<RecommendationDistanceBucket>(
                title: '距离筛选',
                options: RecommendationDistanceBucket.values,
                selected: _distanceBucket,
                labelBuilder: (item) => item.label,
              ),
        );
    if (result == null) {
      return;
    }
    setState(() => _distanceBucket = result.value);
    await widget.repository.saveRecommendationDistanceBucket(result.value);
    if (result.value != null && _locationResult == null) {
      await _resolveLocation();
    }
    await _loadRecommendations(refresh: true);
  }

  Future<void> _showPriceSelector() async {
    final selected =
        await showModalBottomSheet<List<RecommendationPriceBucket>>(
          context: context,
          showDragHandle: true,
          builder: (context) =>
              _MultiChoiceSelectorSheet<RecommendationPriceBucket>(
                title: '价格区间',
                options: RecommendationPriceBucket.values,
                initialSelected: _priceBuckets,
                labelBuilder: (item) => item.label,
              ),
        );
    if (selected == null) {
      return;
    }
    setState(() => _priceBuckets = selected);
    await _loadRecommendations(refresh: true);
  }

  Widget _buildLocationBanner(BuildContext context) {
    final locationText = _locationResult == null
        ? (_distanceBucket == null
              ? '当前距离筛选为不限，不会强制获取定位。'
              : '正在获取位置，用来辅助距离筛选...')
        : _locationResult!.message;
    final warning = !_canUseDistanceFilter && _distanceBucket != null
        ? '暂时拿不到可用定位，当前会忽略距离筛选。'
        : null;

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(locationText)),
            ],
          ),
          if (warning != null) ...[
            const SizedBox(height: 8),
            Text(
              warning,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleVote(RecommendationItem item, String action) async {
    final previousItem = item;
    final optimisticItem = item.copyWith(
      feedback: _applyVoteOptimistically(item.feedback, action),
    );
    _replaceItem(optimisticItem);

    try {
      final result = await widget.repository.submitRecommendationVote(
        recommendationId: item.id,
        action: action,
      );
      if (!mounted) {
        return;
      }
      if (result.feedback.isHidden) {
        _removeItem(item.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('这条推荐已被系统下架。')));
        return;
      }
      _replaceItem(item.copyWith(feedback: result.feedback));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _replaceItem(previousItem);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  Future<void> _handleReport(RecommendationItem item) async {
    final previousItem = item;
    final optimisticItem = item.copyWith(
      feedback: _applyReportOptimistically(item.feedback),
    );
    _replaceItem(optimisticItem);

    try {
      final result = await widget.repository.submitRecommendationReport(
        recommendationId: item.id,
      );
      if (!mounted) {
        return;
      }
      if (result.feedback.isHidden) {
        _removeItem(item.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('举报达到阈值，这条推荐已下架。')));
        return;
      }
      _replaceItem(item.copyWith(feedback: result.feedback));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _replaceItem(previousItem);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('举报失败：$error')));
    }
  }

  void _replaceItem(RecommendationItem nextItem) {
    setState(() {
      _items = _items
          .map((entry) => entry.id == nextItem.id ? nextItem : entry)
          .toList(growable: false);
    });
    final cachedDetail = _detailCache[nextItem.id];
    if (cachedDetail != null) {
      _detailCache[nextItem.id] = cachedDetail.copyWith(
        feedback: nextItem.feedback,
      );
    }
    _persistPageCache();
  }

  void _removeItem(String id) {
    setState(() {
      _items = _items.where((entry) => entry.id != id).toList(growable: false);
      _total = (_total - 1).clamp(0, 1 << 30);
    });
    _detailCache.remove(id);
    _persistPageCache();
  }
}

class RecommendationDetailPage extends StatefulWidget {
  const RecommendationDetailPage({
    super.key,
    required this.repository,
    required this.itemId,
    this.initialDetail,
  });

  final MealRepository repository;
  final String itemId;
  final RecommendationDetail? initialDetail;

  @override
  State<RecommendationDetailPage> createState() =>
      _RecommendationDetailPageState();

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

class _RecommendationDetailPageState extends State<RecommendationDetailPage> {
  RecommendationDetail? _detail;
  bool _loading = true;
  String? _errorText;
  late final TextEditingController _commentController;
  bool _submittingComment = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _detail = widget.initialDetail;
    _loading = _detail == null;
    unawaited(_loadDetail(showSpinner: _detail == null));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _detail == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: ThemedPageBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorText != null && _detail == null) {
      return ThemedSubpageScaffold(
        appBar: AppBar(title: const Text('推荐详情')),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_errorText!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final item = _detail!;
    return ThemedSubpageScaffold(
      appBar: AppBar(title: Text(item.dishName)),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                item.imageUrl!,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _DetailPlaceholderTitle(title: item.dishName),
              ),
            )
          else
            _DetailPlaceholderTitle(title: item.dishName),
          const SizedBox(height: 18),
          Text(item.dishName, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(item.location),
          const SizedBox(height: 8),
          Text('价格：${item.price?.toStringAsFixed(1) ?? '未填写'}'),
          const SizedBox(height: 8),
          Text('评分：${item.rating?.toStringAsFixed(1) ?? '未打分'}'),
          const SizedBox(height: 8),
          Text('记录时间：${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)}'),
          if (item.distanceMeters != null) ...[
            const SizedBox(height: 8),
            Text(
              '距离你约：${RecommendationDetailPage.formatDistance(item.distanceMeters!)}',
            ),
          ],
          if (item.uploaderName?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('发布者：${item.uploaderAvatar ?? '🍜'} ${item.uploaderName}'),
          ],
          const SizedBox(height: 18),
          const Text('推荐理由'),
          const SizedBox(height: 8),
          Text(
            item.reason?.isNotEmpty == true
                ? item.reason!
                : '这道菜在当前筛选条件下更容易被推荐到这里。',
          ),
          const SizedBox(height: 18),
          const Text('菜品描述'),
          const SizedBox(height: 8),
          Text(
            item.description?.trim().isNotEmpty == true
                ? item.description!
                : '发布者暂时没有补充描述。',
          ),
          const SizedBox(height: 14),
          _RecommendationFeedbackBar(
            upvoteCount: item.feedback.upvoteCount,
            downvoteCount: item.feedback.downvoteCount,
            reportCount: item.feedback.reportCount,
            currentVote: item.feedback.currentVote,
            currentReported: item.feedback.currentReported,
            onVote: _handleVote,
            onReport: _handleReport,
          ),
          const SizedBox(height: 18),
          const Text('评论'),
          const SizedBox(height: 8),
          _CommentComposer(
            controller: _commentController,
            busy: _submittingComment,
            onSubmit: _submitComment,
          ),
          const SizedBox(height: 12),
          if (item.comments.isEmpty)
            const SectionCard(child: Text('还没有评论，写下第一条吧。'))
          else
            ...item.comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CommentCard(comment: comment),
              ),
            ),
          const SizedBox(height: 18),
          const Text('同菜品聚合统计'),
          const SizedBox(height: 8),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('公开记录数：${item.aggregate.uploadCount}'),
                const SizedBox(height: 6),
                Text(
                  '平均评分：${item.aggregate.averageRating?.toStringAsFixed(1) ?? '暂无'}',
                ),
                const SizedBox(height: 6),
                Text(
                  '平均价格：${item.aggregate.averagePrice?.toStringAsFixed(1) ?? '暂无'}',
                ),
                const SizedBox(height: 6),
                Text(
                  '最近记录：${DateFormat('yyyy/MM/dd HH:mm').format(item.aggregate.latestRecordedAt)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDetail({required bool showSpinner}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _errorText = null;
      });
    }
    try {
      final detail = await widget.repository.fetchRecommendationDetail(
        widget.itemId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
        _errorText = null;
      });
      _NetworkRecommendationPageState._detailCache[widget.itemId] = detail;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorText = error.toString();
      });
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _submittingComment) {
      return;
    }
    setState(() => _submittingComment = true);
    try {
      final comment = await widget.repository.createRecommendationComment(
        recommendationId: widget.itemId,
        content: content,
      );
      if (!mounted) {
        return;
      }
      _commentController.clear();
      final next = (_detail ?? widget.initialDetail)!.copyWith(
        comments: [comment, ...(_detail?.comments ?? const [])],
      );
      setState(() {
        _detail = next;
        _submittingComment = false;
      });
      _NetworkRecommendationPageState._detailCache[widget.itemId] = next;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submittingComment = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('评论失败：$error')));
    }
  }

  Future<void> _handleVote(String action) async {
    final current = _detail;
    if (current == null) {
      return;
    }
    final previous = current;
    setState(() {
      _detail = current.copyWith(
        feedback: _applyVoteOptimistically(current.feedback, action),
      );
    });
    try {
      final result = await widget.repository.submitRecommendationVote(
        recommendationId: widget.itemId,
        action: action,
      );
      if (!mounted) {
        return;
      }
      if (result.feedback.isHidden) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('这条推荐已被系统下架。')));
        Navigator.of(context).pop();
        return;
      }
      final next = previous.copyWith(feedback: result.feedback);
      setState(() => _detail = next);
      _NetworkRecommendationPageState._detailCache[widget.itemId] = next;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _detail = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  Future<void> _handleReport() async {
    final current = _detail;
    if (current == null) {
      return;
    }
    final previous = current;
    setState(() {
      _detail = current.copyWith(
        feedback: _applyReportOptimistically(current.feedback),
      );
    });
    try {
      final result = await widget.repository.submitRecommendationReport(
        recommendationId: widget.itemId,
      );
      if (!mounted) {
        return;
      }
      if (result.feedback.isHidden) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('举报达到阈值，这条推荐已下架。')));
        Navigator.of(context).pop();
        return;
      }
      final next = previous.copyWith(feedback: result.feedback);
      setState(() => _detail = next);
      _NetworkRecommendationPageState._detailCache[widget.itemId] = next;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _detail = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('举报失败：$error')));
    }
  }
}

class _RecommendationListCard extends StatelessWidget {
  const _RecommendationListCard({
    required this.item,
    required this.repository,
    required this.detailCache,
    required this.onVote,
    required this.onReport,
  });

  final RecommendationItem item;
  final MealRepository repository;
  final Map<String, RecommendationDetail> detailCache;
  final Future<void> Function(RecommendationItem item, String action) onVote;
  final Future<void> Function(RecommendationItem item) onReport;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RecommendationDetailPage(
              repository: repository,
              itemId: item.id,
              initialDetail: detailCache[item.id],
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.dishName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(item.location),
            const SizedBox(height: 6),
            Text(
              '价格 ${item.price.toStringAsFixed(1)} · 评分 ${item.rating.toStringAsFixed(1)}',
            ),
            if (item.distanceMeters != null) ...[
              const SizedBox(height: 6),
              Text(
                '距离你约 ${RecommendationDetailPage.formatDistance(item.distanceMeters!)}',
              ),
            ],
            if (item.uploaderName?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text('发布者 ${item.uploaderAvatar ?? '🍜'} ${item.uploaderName}'),
            ],
            const SizedBox(height: 10),
            Text(item.summaryDescription),
            const SizedBox(height: 10),
            Text(
              '公开记录 ${item.aggregate.uploadCount} · 均分 ${item.aggregate.averageRating?.toStringAsFixed(1) ?? '暂无'} · '
              '均价 ${item.aggregate.averagePrice?.toStringAsFixed(1) ?? '暂无'} · '
              '最近 ${DateFormat('MM/dd HH:mm').format(item.aggregate.latestRecordedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '点击查看详情',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _RecommendationFeedbackBar(
              upvoteCount: item.feedback.upvoteCount,
              downvoteCount: item.feedback.downvoteCount,
              reportCount: item.feedback.reportCount,
              currentVote: item.feedback.currentVote,
              currentReported: item.feedback.currentReported,
              onVote: (action) => onVote(item, action),
              onReport: () => onReport(item),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '写下你的看法...'),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: Text(busy ? '发送中' : '评论'),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final RecommendationComment comment;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(comment.authorAvatar)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.isMine
                          ? '${comment.authorName}（我）'
                          : comment.authorName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      DateFormat('MM/dd HH:mm').format(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(comment.content),
        ],
      ),
    );
  }
}

class _RecommendationFeedbackBar extends StatelessWidget {
  const _RecommendationFeedbackBar({
    required this.upvoteCount,
    required this.downvoteCount,
    required this.reportCount,
    required this.currentVote,
    required this.currentReported,
    required this.onVote,
    required this.onReport,
  });

  final int upvoteCount;
  final int downvoteCount;
  final int reportCount;
  final String? currentVote;
  final bool currentReported;
  final Future<void> Function(String action) onVote;
  final Future<void> Function() onReport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: Icon(
            Icons.thumb_up_alt_outlined,
            size: 18,
            color: currentVote == 'upvote'
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          label: Text('点赞 $upvoteCount'),
          onPressed: () => onVote('upvote'),
        ),
        ActionChip(
          avatar: Icon(
            Icons.thumb_down_alt_outlined,
            size: 18,
            color: currentVote == 'downvote'
                ? Theme.of(context).colorScheme.error
                : null,
          ),
          label: Text('点踩 $downvoteCount'),
          onPressed: () => onVote('downvote'),
        ),
        ActionChip(
          avatar: Icon(
            Icons.flag_outlined,
            size: 18,
            color: currentReported ? Theme.of(context).colorScheme.error : null,
          ),
          label: Text('举报 $reportCount'),
          onPressed: onReport,
        ),
      ],
    );
  }
}

class _DetailPlaceholderTitle extends StatelessWidget {
  const _DetailPlaceholderTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFD96C3D), Color(0xFFFFC46C)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.tune_rounded, size: 18),
      label: Text('$label：$valueText'),
      onPressed: onTap,
    );
  }
}

class _SingleChoiceSelectorSheet<T> extends StatefulWidget {
  const _SingleChoiceSelectorSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelBuilder,
  });

  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T item) labelBuilder;

  @override
  State<_SingleChoiceSelectorSheet<T>> createState() =>
      _SingleChoiceSelectorSheetState<T>();
}

class _SingleChoiceSelectorSheetState<T>
    extends State<_SingleChoiceSelectorSheet<T>> {
  T? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _SingleChoiceOptionTile(
              selected: _selected == null,
              label: '不限',
              onTap: () => setState(() => _selected = null),
            ),
            ...widget.options.map(
              (item) => _SingleChoiceOptionTile(
                selected: _selected == item,
                label: widget.labelBuilder(item),
                onTap: () => setState(() => _selected = item),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_SingleChoiceResult<T>(value: _selected)),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleChoiceResult<T> {
  const _SingleChoiceResult({required this.value});

  final T? value;
}

class _SingleChoiceOptionTile extends StatelessWidget {
  const _SingleChoiceOptionTile({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off_outlined,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiChoiceSelectorSheet<T> extends StatefulWidget {
  const _MultiChoiceSelectorSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.labelBuilder,
  });

  final String title;
  final List<T> options;
  final List<T> initialSelected;
  final String Function(T item) labelBuilder;

  @override
  State<_MultiChoiceSelectorSheet<T>> createState() =>
      _MultiChoiceSelectorSheetState<T>();
}

class _MultiChoiceSelectorSheetState<T>
    extends State<_MultiChoiceSelectorSheet<T>> {
  late final Set<T> _selected = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...widget.options.map(
              (item) => CheckboxListTile(
                value: _selected.contains(item),
                title: Text(widget.labelBuilder(item)),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selected.add(item);
                    } else {
                      _selected.remove(item);
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('清空'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_selected.toList()),
                  child: const Text('完成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationPageCache {
  const _RecommendationPageCache({
    required this.items,
    required this.distanceBucket,
    required this.priceBuckets,
    required this.page,
    required this.total,
    required this.locationResult,
  });

  final List<RecommendationItem> items;
  final RecommendationDistanceBucket? distanceBucket;
  final List<RecommendationPriceBucket> priceBuckets;
  final int page;
  final int total;
  final LocationResult? locationResult;
}

RecommendationFeedbackSummary _applyVoteOptimistically(
  RecommendationFeedbackSummary feedback,
  String action,
) {
  if (feedback.currentVote == action) {
    return feedback;
  }

  var upvoteCount = feedback.upvoteCount;
  var downvoteCount = feedback.downvoteCount;

  if (feedback.currentVote == 'upvote' && upvoteCount > 0) {
    upvoteCount--;
  }
  if (feedback.currentVote == 'downvote' && downvoteCount > 0) {
    downvoteCount--;
  }

  if (action == 'upvote') {
    upvoteCount++;
  } else if (action == 'downvote') {
    downvoteCount++;
  }

  final voteTotal = upvoteCount + downvoteCount;
  final downvoteRatio = voteTotal == 0 ? 0.0 : downvoteCount / voteTotal;

  return feedback.copyWith(
    upvoteCount: upvoteCount,
    downvoteCount: downvoteCount,
    voteTotal: voteTotal,
    downvoteRatio: downvoteRatio,
    currentVote: action,
  );
}

RecommendationFeedbackSummary _applyReportOptimistically(
  RecommendationFeedbackSummary feedback,
) {
  if (feedback.currentReported) {
    return feedback.copyWith(
      reportCount: feedback.reportCount > 0 ? feedback.reportCount - 1 : 0,
      currentReported: false,
    );
  }

  return feedback.copyWith(
    reportCount: feedback.reportCount + 1,
    currentReported: true,
  );
}
