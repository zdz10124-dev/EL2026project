// 对外接口：
// - NetworkRecommendationPage
// - RecommendationDetailPage

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recommendation_models.dart';
import '../services/location_service.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';
import '../widgets/themed_page_background.dart';

class NetworkRecommendationPage extends StatefulWidget {
  const NetworkRecommendationPage({super.key, required this.repository});

  final MealRepository repository;

  @override
  State<NetworkRecommendationPage> createState() =>
      _NetworkRecommendationPageState();
}

class _NetworkRecommendationPageState extends State<NetworkRecommendationPage> {
  static const int _pageSize = 12;

  final ScrollController _scrollController = ScrollController();
  final LocationService _locationService = LocationService();

  List<RecommendationItem> _items = const [];
  List<RecommendationDistanceBucket> _distanceBuckets = const [];
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
    _scrollController.addListener(_handleScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
      body: ThemedPageBackground(
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
                _MultiSelectFilterChip(
                  label: '距离',
                  valueText: _distanceBuckets.isEmpty
                      ? '不限'
                      : _distanceBuckets.map((item) => item.label).join(' / '),
                  onTap: _showDistanceSelector,
                ),
                _MultiSelectFilterChip(
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
              const SectionCard(child: Text('当前筛选条件下还没有可用推荐'))
            else ...[
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecommendationListCard(
                    item: item,
                    repository: widget.repository,
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
      ),
    );
  }

  Future<void> _bootstrap() async {
    await _resolveLocation();
    unawaited(_syncUploadsSilently());
    await _loadRecommendations(refresh: true);
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
      // 静默忽略补传异常，避免阻塞用户查看联网推荐。
    }
  }

  Future<void> _loadRecommendations({required bool refresh}) async {
    final nextPage = refresh ? 1 : _page + 1;
    if (refresh) {
      setState(() {
        _loading = true;
        _errorText = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final query = RecommendationQuery(
        distanceBuckets: _canUseDistanceFilter ? _distanceBuckets : const [],
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorText = error.toString();
      });
    }
  }

  bool get _canUseDistanceFilter =>
      _locationResult?.success == true &&
      _locationResult?.latitude != null &&
      _locationResult?.longitude != null;

  void _handleScroll() {
    if (_loadingMore || _loading || _items.length >= _total) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadRecommendations(refresh: false);
    }
  }

  Future<void> _showDistanceSelector() async {
    final selected =
        await showModalBottomSheet<List<RecommendationDistanceBucket>>(
          context: context,
          showDragHandle: true,
          builder: (context) =>
              _BucketSelectorSheet<RecommendationDistanceBucket>(
                title: '距离筛选',
                options: RecommendationDistanceBucket.values,
                initialSelected: _distanceBuckets,
                labelBuilder: (item) => item.label,
              ),
        );
    if (selected == null) {
      return;
    }
    setState(() => _distanceBuckets = selected);
    await _loadRecommendations(refresh: true);
  }

  Future<void> _showPriceSelector() async {
    final selected = await showModalBottomSheet<List<RecommendationPriceBucket>>(
      context: context,
      showDragHandle: true,
      builder: (context) => _BucketSelectorSheet<RecommendationPriceBucket>(
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
        ? '正在获取推荐所需的当前位置...'
        : _locationResult!.message;
    final warning =
        !_canUseDistanceFilter && _distanceBuckets.isNotEmpty ? '未能获取可用定位，距离筛选已暂时忽略。' : null;

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
    try {
      final result = await widget.repository.submitRecommendationVote(
        recommendationId: item.id,
        action: action,
      );
      if (!mounted) return;
      if (result.feedback.isHidden) {
        setState(() {
          _items = _items.where((entry) => entry.id != item.id).toList();
          _total = (_total - 1).clamp(0, 1 << 30);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该推荐已达到下架阈值，现已永久下架')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'upvote' ? '已点赞' : '已点踩')),
      );
      await _loadRecommendations(refresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$error')),
      );
    }
  }

  Future<void> _handleReport(RecommendationItem item) async {
    try {
      final result = await widget.repository.submitRecommendationReport(
        recommendationId: item.id,
      );
      if (!mounted) return;
      if (result.feedback.isHidden) {
        setState(() {
          _items = _items.where((entry) => entry.id != item.id).toList();
          _total = (_total - 1).clamp(0, 1 << 30);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('举报达到阈值，该推荐已永久下架')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('举报已提交')),
      );
      await _loadRecommendations(refresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('举报失败：$error')),
      );
    }
  }
}

class RecommendationDetailPage extends StatelessWidget {
  const RecommendationDetailPage({
    super.key,
    required this.repository,
    required this.itemId,
  });

  final MealRepository repository;
  final String itemId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecommendationDetail>(
      future: repository.fetchRecommendationDetail(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: ThemedPageBackground(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('推荐详情')),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(snapshot.error?.toString() ?? '详情加载失败'),
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

        final item = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: Text(item.dishName)),
          body: ListView(
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
              Text(
                item.dishName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(item.location),
              const SizedBox(height: 8),
              Text('价格：${item.price?.toStringAsFixed(1) ?? '未填写'}'),
              const SizedBox(height: 8),
              Text('评分：${item.rating?.toStringAsFixed(1) ?? '未打分'}'),
              const SizedBox(height: 8),
              Text(
                '记录时间：${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)}',
              ),
              if (item.distanceMeters != null) ...[
                const SizedBox(height: 8),
                Text('距离你约：${_formatDistance(item.distanceMeters!)}'),
              ],
              const SizedBox(height: 18),
              const Text('推荐理由'),
              const SizedBox(height: 8),
              Text(
                item.reason?.isNotEmpty == true
                    ? item.reason!
                    : '这道菜在当前筛选条件下更容易被系统抽到。',
              ),
              const SizedBox(height: 18),
              const Text('评价'),
              const SizedBox(height: 8),
              Text(item.comment?.trim().isNotEmpty == true ? item.comment! : '暂未填写'),
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
      },
    );
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

class _RecommendationListCard extends StatelessWidget {
  const _RecommendationListCard({
    required this.item,
    required this.repository,
    required this.onVote,
    required this.onReport,
  });

  final RecommendationItem item;
  final MealRepository repository;
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
              Text('距离你约 ${RecommendationDetailPage._formatDistance(item.distanceMeters!)}'),
            ],
            const SizedBox(height: 10),
            Text(
              item.reason.isNotEmpty ? item.reason : '同菜品下高分、较近且更热门的记录更容易被推荐到这里。',
            ),
            const SizedBox(height: 10),
            Text(
              '公开记录 ${item.aggregate.uploadCount} · 均分 ${item.aggregate.averageRating?.toStringAsFixed(1) ?? '暂无'} · '
              '均价 ${item.aggregate.averagePrice?.toStringAsFixed(1) ?? '暂无'} · '
              '最近 ${DateFormat('MM/dd HH:mm').format(item.aggregate.latestRecordedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 18,
                    color: item.feedback.currentVote == 'upvote'
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  label: Text('点赞 ${item.feedback.upvoteCount}'),
                  onPressed: () => onVote(item, 'upvote'),
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.thumb_down_alt_outlined,
                    size: 18,
                    color: item.feedback.currentVote == 'downvote'
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  label: Text('点踩 ${item.feedback.downvoteCount}'),
                  onPressed: () => onVote(item, 'downvote'),
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: item.feedback.currentReported
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  label: Text('举报 ${item.feedback.reportCount}'),
                  onPressed: () => onReport(item),
                ),
              ],
            ),
          ],
        ),
      ),
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

class _MultiSelectFilterChip extends StatelessWidget {
  const _MultiSelectFilterChip({
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

class _BucketSelectorSheet<T> extends StatefulWidget {
  const _BucketSelectorSheet({
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
  State<_BucketSelectorSheet<T>> createState() => _BucketSelectorSheetState<T>();
}

class _BucketSelectorSheetState<T> extends State<_BucketSelectorSheet<T>> {
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
                  onPressed: () => Navigator.of(context).pop(_selected.toList()),
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
