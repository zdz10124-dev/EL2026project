import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/meal_draft.dart';
import '../models/meal_record.dart';
import '../models/ui_config.dart';
import '../services/agent_service.dart';
import '../services/location_service.dart';
import '../services/meal_repository.dart';
import '../widgets/rating_stars.dart';
import '../widgets/section_card.dart';
import '../widgets/image_viewer.dart';
import '../widgets/themed_subpage_scaffold.dart';

class MealCapturePage extends StatelessWidget {
  const MealCapturePage({
    super.key,
    required this.config,
    required this.repository,
    required this.agentService,
  });

  final UiConfig config;
  final MealRepository repository;
  final AgentService agentService;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('记录饮食')),
    body: ThemedPageBackground(
      child: CaptureScreen(
        config: config,
        repository: repository,
        agentService: agentService,
      ),
    ),
  );
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.config,
    required this.repository,
    this.agentService,
  });

  final UiConfig config;
  final MealRepository repository;
  final AgentService? agentService;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  static const int _pageSize = 12;

  bool _busy = false;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final layout = widget.config.layout;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layout.pageHorizontalPadding,
          vertical: layout.pageVerticalPadding,
        ),
        child: StreamBuilder<List<MealRecord>>(
          stream: widget.repository.recordsStream,
          initialData: const [],
          builder: (context, snapshot) {
            final records = snapshot.data ?? const <MealRecord>[];
            final visibleRecords = records.take(_visibleCount).toList();
            if (_visibleCount > records.length && records.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _visibleCount = records.length);
                }
              });
            }

            return ListView(
              children: [
                Text(
                  widget.config.capture.cameraTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.config.appSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _PreviewPlaceholder(
                  config: widget.config,
                  latestImagePath: records.isEmpty
                      ? null
                      : records.first.imagePath,
                  onTap: _busy ? null : () => _openEditor(fromCamera: true),
                ),
                const SizedBox(height: 18),
                Text(widget.config.capture.cameraHint),
                const SizedBox(height: 8),
                Text(
                  widget.config.capture.draftNotice,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CameraActionButton(
                      size: layout.cameraActionSize,
                      icon: Icons.photo_camera_rounded,
                      onPressed: _busy
                          ? null
                          : () => _openEditor(fromCamera: true),
                    ),
                    const SizedBox(width: 20),
                    _SquareActionButton(
                      size: layout.secondaryActionSize,
                      icon: Icons.collections_outlined,
                      onPressed: _busy
                          ? null
                          : () => _openEditor(fromCamera: false, multi: true),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('记录', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Text(
                      '共 ${records.length} 条',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const SectionCard(child: Text('还没有记录，拍下今天这顿饭后，这里会慢慢长起来。'))
                else ...[
                  ...visibleRecords.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecentRecordCard(
                        record: record,
                        onEdit: () => _editRecord(record),
                        onDelete: () => _deleteRecord(record),
                        onToggleAutoUpload: () => _toggleAutoUpload(record),
                        onToggleRemoteVisibility:
                            record.remoteRecommendationId?.isNotEmpty == true
                            ? () => _toggleRemoteVisibility(record)
                            : null,
                      ),
                    ),
                  ),
                  if (visibleRecords.length < records.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _visibleCount = (_visibleCount + _pageSize).clamp(
                              0,
                              records.length,
                            );
                          });
                        },
                        child: const Text('继续加载更多记录'),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEditor({
    required bool fromCamera,
    bool multi = false,
  }) async {
    widget.repository.clearDraft();
    setState(() => _busy = true);
    try {
      final List<String> paths;
      if (fromCamera) {
        final file = await widget.repository.captureFromCamera();
        paths = file != null ? [file.path] : [];
      } else if (multi) {
        final files = await widget.repository.pickMultiFromGallery();
        paths = files.map((f) => f.path).toList();
      } else {
        final file = await widget.repository.pickFromGallery();
        paths = file != null ? [file.path] : [];
      }
      if (mounted) setState(() => _busy = false);
      if (!mounted || paths.isEmpty) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => EditMealScreen(
            config: widget.config,
            repository: widget.repository,
            agentService: widget.agentService,
            imagePaths: paths,
            fromCamera: fromCamera,
            initialDraft: MealDraft.empty(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editRecord(MealRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EditMealScreen(
          config: widget.config,
          repository: widget.repository,
          agentService: widget.agentService,
          imagePaths: record.imagePaths,
          fromCamera: false,
          initialDraft: MealDraft(
            dishName: record.dishName == '未填写' ? '' : record.dishName,
            location: record.location == '未填写' ? '' : record.location,
            priceText: record.price?.toString() ?? '',
            commentText: record.comment ?? '',
            ratingScore: record.ratingScore == null
                ? null
                : record.ratingScore! / 2,
            updatedAt: record.updatedAt,
          ),
          existingRecord: record,
        ),
      ),
    );
  }

  Future<void> _deleteRecord(MealRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text(
          record.remoteRecommendationId?.isNotEmpty == true
              ? '这条记录已经上传过，删除时会尽量一并下架远端记录。确定继续吗？'
              : '确定删除这条记录吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await widget.repository.deleteRecord(record);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('记录已删除')));
  }

  Future<void> _toggleAutoUpload(MealRecord record) async {
    await widget.repository.setRecordAutoUploadEnabled(
      record,
      !record.autoUploadEnabled,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          record.autoUploadEnabled ? '已关闭这条记录的自动上传' : '已开启这条记录的自动上传',
        ),
      ),
    );
  }

  Future<void> _toggleRemoteVisibility(MealRecord record) async {
    final active =
        record.recommendationStatus == LocalRecommendationStatus.unlisted;
    await widget.repository.setRecommendationVisibility(record, active: active);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(active ? '这条记录已重新上架' : '这条记录已从联网推荐下架')),
    );
  }
}

class EditMealScreen extends StatefulWidget {
  const EditMealScreen({
    super.key,
    required this.config,
    required this.repository,
    required this.imagePaths,
    required this.fromCamera,
    required this.initialDraft,
    this.agentService,
    this.existingRecord,
  });

  final UiConfig config;
  final MealRepository repository;
  final List<String> imagePaths;
  final bool fromCamera;
  final MealDraft initialDraft;
  final AgentService? agentService;
  final MealRecord? existingRecord;

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  final LocationService _locationService = LocationService();
  final PageController _pageController = PageController();
  late final TextEditingController _dishController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;
  late final TextEditingController _commentController;
  late List<String> _imagePaths;
  int _currentImageIndex = 0;
  late double _ratingValue;
  bool _ratingTouched = false;
  bool _saving = false;
  bool _aiAnalyzing = false;
  bool _autoUploadEnabled = true;
  // AI raw result fields (before user accepts/rejects)
  String? _aiCuisine;
  String? _aiSpiceLevel;
  String? _aiIngredients;
  String? _aiMainDish;
  String? _aiSideDish;
  String? _aiDrink;
  String? _aiSnack;
  String? _aiDishName;
  // Track which fields the user has accepted
  final Set<String> _acceptedFields = {};
  bool _locating = true;
  String _locationStatus = '定位中...';
  int _locationRequestId = 0;
  LocationResult? _lastLocationResult;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRecord;
    _imagePaths = List.of(widget.imagePaths);
    _dishController = TextEditingController(text: widget.initialDraft.dishName);
    _locationController = TextEditingController(
      text: widget.initialDraft.location,
    );
    _priceController = TextEditingController(
      text: widget.initialDraft.priceText,
    );
    _commentController = TextEditingController(
      text: widget.initialDraft.commentText,
    );
    _ratingValue = widget.initialDraft.ratingScore ?? 0;
    _ratingTouched = widget.initialDraft.ratingScore != null;
    _autoUploadEnabled = existing?.autoUploadEnabled ?? true;
    _aiMainDish = existing?.mainDish;
    _aiSideDish = existing?.sideDish;
    _aiDrink = existing?.drink;
    _aiSnack = existing?.snack;
    _aiCuisine = existing?.cuisine;
    _aiSpiceLevel = existing?.spiceLevel;
    _aiIngredients = existing?.ingredients;
    _beginGpsLookup();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dishController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.config.layout;
    final capture = widget.config.capture;
    final isEditing = widget.existingRecord != null;
    return ThemedSubpageScaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? '\u7f16\u8f91\u8bb0\u5f55' : '\u65b0\u589e\u8bb0\u5f55',
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: layout.pageHorizontalPadding,
          vertical: layout.pageVerticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Multi-image preview
            SizedBox(
              height: layout.cameraFrameHeight,
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _imagePaths.length,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(layout.cardRadius),
                        child: Image.file(
                          File(_imagePaths[i]),
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  if (_imagePaths.length > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _imagePaths.length,
                        (i) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _currentImageIndex
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _dishController,
                    decoration: InputDecoration(labelText: capture.dishLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: capture.locationLabel,
                      suffixIcon: _locating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _beginGpsLookup,
                              icon: const Icon(Icons.my_location_outlined),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _locationStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: capture.priceLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '描述',
                      hintText: '写一下口味、分量、踩雷点或推荐理由',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('评分', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  RatingStars(
                    value: _ratingTouched ? _ratingValue : 0,
                    onChanged: (value) {
                      setState(() {
                        _ratingTouched = true;
                        _ratingValue = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自动上传这条记录'),
                    subtitle: const Text('关闭后只保存在本地；开启后会尝试同步到联网推荐。'),
                    value: _autoUploadEnabled,
                    onChanged: (value) {
                      setState(() => _autoUploadEnabled = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildAiSection(context),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中...' : capture.confirmText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final existing = widget.existingRecord;
    try {
      if (existing == null) {
        await widget.repository.saveRecord(
          sourceImagePaths: _imagePaths,
          dishNameInput: _dishController.text,
          locationInput: _locationController.text,
          priceText: _priceController.text,
          ratingScore: _ratingTouched ? _ratingValue : null,
          aiMainDish: _aiMainDish,
          aiSideDish: _aiSideDish,
          aiDrink: _aiDrink,
          aiSnack: _aiSnack,
          aiSpiceLevel: _aiSpiceLevel,
          aiIngredients: _aiIngredients,
          aiCuisine: _aiCuisine,
          commentInput: _commentController.text,
          province: _lastLocationResult?.province,
          city: _lastLocationResult?.city,
          district: _lastLocationResult?.district,
          latitude: _lastLocationResult?.latitude,
          longitude: _lastLocationResult?.longitude,
          autoUploadEnabled: _autoUploadEnabled,
        );
      } else {
        await widget.repository.updateRecord(
          original: existing,
          dishNameInput: _dishController.text,
          locationInput: _locationController.text,
          priceText: _priceController.text,
          ratingScore: _ratingTouched ? _ratingValue : null,
          commentInput: _commentController.text,
          province: _lastLocationResult?.province ?? existing.province,
          city: _lastLocationResult?.city ?? existing.city,
          district: _lastLocationResult?.district ?? existing.district,
          latitude: _lastLocationResult?.latitude ?? existing.latitude,
          longitude: _lastLocationResult?.longitude ?? existing.longitude,
          autoUploadEnabled: _autoUploadEnabled,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? '已保存到本地' : '记录已更新')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  Future<void> _analyzeWithAI() async {
    final agent = widget.agentService;
    if (agent == null || !agent.isAvailable) {
      _showPlainDialog(title: 'AI 未配置', content: '还没有可用的 AI 模型配置，请先到设置页完成配置。');
      return;
    }

    setState(() {
      _aiAnalyzing = true;
      _acceptedFields.clear();
    });
    try {
      final result = _imagePaths.length > 1
          ? await agent.analyzeFoodImages(_imagePaths)
          : await agent.analyzeFoodImage(_imagePaths.first);
      if (!mounted) return;
      setState(() {
        _aiAnalyzing = false;
        _aiDishName = result.dishName.isNotEmpty ? result.dishName : null;
        _aiMainDish = result.mainDish;
        _aiSideDish = result.sideDish;
        _aiDrink = result.drink;
        _aiSnack = result.snack;
        _aiCuisine = result.cuisine;
        _aiSpiceLevel = result.spiceLevel;
        _aiIngredients = result.ingredients;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _aiAnalyzing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyAiError(error))));
    }
  }

  Widget _buildAiSection(BuildContext context) {
    final hasAiResult =
        _aiMainDish?.isNotEmpty == true ||
        _aiCuisine?.isNotEmpty == true ||
        _aiIngredients?.isNotEmpty == true;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('AI 辅助', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (hasAiResult) ...[
                TextButton.icon(
                  onPressed: _adoptAll,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('全部采纳'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _clearAi,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('清除'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _aiAnalyzing ? null : _analyzeWithAI,
              child: _aiAnalyzing
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('AI 识别中...'),
                      ],
                    )
                  : Text(
                      _imagePaths.length > 1
                          ? '用 AI 识别图片（${_imagePaths.length} 张）'
                          : '用 AI 识别图片',
                    ),
            ),
          ),
          if (hasAiResult) ...[
            const SizedBox(height: 12),
            _aiField('菜品名称', _aiDishName, 'dishName'),
            _aiField('主菜', _aiMainDish, 'mainDish'),
            _aiField('配菜', _aiSideDish, 'sideDish'),
            _aiField('饮品', _aiDrink, 'drink'),
            _aiField('小吃', _aiSnack, 'snack'),
            _aiField('菜系', _aiCuisine, 'cuisine'),
            _aiField('辣度', _aiSpiceLevel, 'spiceLevel'),
            _aiField('食材', _aiIngredients, 'ingredients'),
          ],
        ],
      ),
    );
  }

  Widget _aiField(String label, String? value, String fieldKey) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final accepted = _acceptedFields.contains(fieldKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accepted ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accepted ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          if (!accepted) ...[
            _aiActionBtn(
              Icons.check_rounded,
              Colors.green,
              () => _adoptField(fieldKey),
            ),
            const SizedBox(width: 8),
            _aiActionBtn(
              Icons.close_rounded,
              Colors.red.shade400,
              () => _dismissField(fieldKey),
            ),
          ] else
            Icon(Icons.check_circle, size: 20, color: Colors.green.shade600),
        ],
      ),
    );
  }

  Widget _aiActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  void _adoptField(String key) {
    setState(() {
      _acceptedFields.add(key);
      if (key == 'dishName' && _aiDishName?.isNotEmpty == true) {
        _dishController.text = _aiDishName!;
      } else if (key == 'mainDish' && _aiMainDish?.isNotEmpty == true) {
        _dishController.text = _aiMainDish!;
      }
    });
  }

  void _dismissField(String key) {
    setState(() {
      _acceptedFields.remove(key);
      switch (key) {
        case 'dishName':
          _aiDishName = null;
          break;
        case 'mainDish':
          _aiMainDish = null;
          break;
        case 'sideDish':
          _aiSideDish = null;
          break;
        case 'drink':
          _aiDrink = null;
          break;
        case 'snack':
          _aiSnack = null;
          break;
        case 'cuisine':
          _aiCuisine = null;
          break;
        case 'spiceLevel':
          _aiSpiceLevel = null;
          break;
        case 'ingredients':
          _aiIngredients = null;
          break;
      }
    });
  }

  void _adoptAll() {
    setState(() {
      if (_aiDishName?.isNotEmpty == true) {
        _acceptedFields.add('dishName');
        _dishController.text = _aiDishName!;
      }
      for (final e in {
        'mainDish': _aiMainDish,
        'sideDish': _aiSideDish,
        'drink': _aiDrink,
        'snack': _aiSnack,
        'cuisine': _aiCuisine,
        'spiceLevel': _aiSpiceLevel,
        'ingredients': _aiIngredients,
      }.entries) {
        if (e.value?.isNotEmpty == true) _acceptedFields.add(e.key);
      }
    });
  }

  void _clearAi() {
    setState(() {
      _aiDishName = null;
      _aiMainDish = null;
      _aiSideDish = null;
      _aiDrink = null;
      _aiSnack = null;
      _aiCuisine = null;
      _aiSpiceLevel = null;
      _aiIngredients = null;
      _acceptedFields.clear();
    });
  }

  void _beginGpsLookup() {
    _locationRequestId++;
    setState(() {
      _locating = true;
      _locationStatus = '定位中...';
    });
    _loadGpsAddress(_locationRequestId);
  }

  Future<void> _loadGpsAddress(int requestId) async {
    final result = await _locationService.getCurrentAddress(
      onUpdate: (updated) {
        if (!mounted || requestId != _locationRequestId) {
          return;
        }
        setState(() {
          _lastLocationResult = updated;
          _locating = false;
          _locationStatus = updated.message;
        });
      },
    );
    if (!mounted || requestId != _locationRequestId) {
      return;
    }
    setState(() {
      _lastLocationResult = result;
      _locating = false;
      _locationStatus = result.message;
    });
  }

  String _friendlyAiError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('未配置') || text.contains('not configured')) {
      return 'AI 还没有配置好，请先到设置页完成配置。';
    }
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('invalid')) {
      return 'AI 配置似乎无效，请检查密钥、模型或服务端配置。';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'AI 请求超时了，可以稍后再试一次。';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('failed host lookup')) {
      return '网络似乎不稳定，AI 识别暂时没有成功。';
    }
    if (text.contains('429') || text.contains('quota')) {
      return 'AI 服务当前额度不足或请求太频繁，请稍后再试。';
    }
    if (text.contains('format') || text.contains('json')) {
      return 'AI 返回的内容格式不完整，这次识别没有成功。';
    }
    return 'AI 识别失败了，请稍后重试。';
  }

  void _showPlainDialog({required String title, required String content}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({
    required this.config,
    this.latestImagePath,
    this.onTap,
  });

  final UiConfig config;
  final String? latestImagePath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        latestImagePath != null && File(latestImagePath!).existsSync();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: config.layout.cameraFrameHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(config.layout.cardRadius),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.90),
              config.theme.accentColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(config.layout.cardRadius),
                child: Image.file(File(latestImagePath!), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    size: 56,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '相机预览区域',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      '当前版本使用系统相机或相册完成拍摄与选图。',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CameraActionButton extends StatelessWidget {
  const _CameraActionButton({
    required this.size,
    required this.icon,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 30),
      ),
    );
  }
}

class _SquareActionButton extends StatelessWidget {
  const _SquareActionButton({
    required this.size,
    required this.icon,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        child: Icon(icon),
      ),
    );
  }
}

class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAutoUpload,
    required this.onToggleRemoteVisibility,
  });

  final MealRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAutoUpload;
  final VoidCallback? onToggleRemoteVisibility;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => openImageViewer(context, record.imagePaths),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        File(record.imagePath),
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Container(
                          width: 82,
                          height: 82,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                  if (record.imagePaths.length > 1)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${record.imagePaths.length - 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.dishName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(record.location),
                    const SizedBox(height: 4),
                    Text(DateFormat('MM/dd HH:mm').format(record.createdAt)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(record.ratingLabel),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                        case 'upload':
                          onToggleAutoUpload();
                          break;
                        case 'visibility':
                          onToggleRemoteVisibility?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(
                        value: 'upload',
                        child: Text(
                          record.autoUploadEnabled ? '关闭自动上传' : '开启自动上传',
                        ),
                      ),
                      if (onToggleRemoteVisibility != null)
                        PopupMenuItem(
                          value: 'visibility',
                          child: Text(
                            record.recommendationStatus ==
                                    LocalRecommendationStatus.unlisted
                                ? '重新上架'
                                : '手动下架',
                          ),
                        ),
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(label: _recommendationStatusText(record)),
              _StatusPill(label: record.autoUploadEnabled ? '自动上传开启' : '仅本地'),
              if (record.comment?.trim().isNotEmpty == true)
                _StatusPill(label: '有描述'),
            ],
          ),
        ],
      ),
    );
  }

  String _recommendationStatusText(MealRecord record) {
    switch (record.recommendationStatus) {
      case LocalRecommendationStatus.localOnly:
        return '未上传';
      case LocalRecommendationStatus.pendingUpload:
        return '等待上传';
      case LocalRecommendationStatus.uploaded:
        return '已上传';
      case LocalRecommendationStatus.uploadFailed:
        return '上传失败';
      case LocalRecommendationStatus.unlisted:
        return '已下架';
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
