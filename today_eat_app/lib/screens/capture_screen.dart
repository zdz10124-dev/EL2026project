import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/meal_draft.dart';
import '../models/meal_record.dart';
import '../models/ui_config.dart';
import '../services/agent_service.dart';
import '../services/location_service.dart';
import '../services/meal_repository.dart';
import '../widgets/rating_stars.dart';
import '../widgets/section_card.dart';

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
  bool _busy = false;

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
            final records = snapshot.data ?? const [];
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
                      icon: Icons.image_outlined,
                      onPressed: _busy
                          ? null
                          : () => _openEditor(fromCamera: false),
                    ),
                  ],
                ),
                if (records.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ...List.generate(records.take(3).length, (index) {
                    final isLast = index == records.take(3).length - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: _RecentRecordCard(record: records[index]),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAiNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 未配置'),
        content: const Text('AI 功能需要先在设置中配置模型。\n\n'
            '请前往「设置 → 智能功能 → AI 模型配置」完成设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor({required bool fromCamera}) async {
    widget.repository.clearDraft();
    setState(() => _busy = true);
    final XFile? file = fromCamera
        ? await widget.repository.captureFromCamera()
        : await widget.repository.pickFromGallery();
    setState(() => _busy = false);
    if (!mounted || file == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EditMealScreen(
          config: widget.config,
          repository: widget.repository,
          agentService: widget.agentService,
          imagePath: file.path,
          fromCamera: fromCamera,
          initialDraft: MealDraft.empty(),
        ),
      ),
    );
  }
}

class EditMealScreen extends StatefulWidget {
  const EditMealScreen({
    super.key,
    required this.config,
    required this.repository,
    required this.imagePath,
    required this.fromCamera,
    required this.initialDraft,
    this.agentService,
  });

  final UiConfig config;
  final MealRepository repository;
  final String imagePath;
  final bool fromCamera;
  final MealDraft initialDraft;
  final AgentService? agentService;

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  final LocationService _locationService = LocationService();
  late final TextEditingController _dishController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;
  late String _imagePath;
  late double _ratingValue;
  bool _ratingTouched = false;
  bool _saving = false;
  // AI fields
  bool _aiAnalyzing = false;
  String? _aiCuisine;
  String? _aiSpiceLevel;
  String? _aiIngredients;
  String? _aiMainDish;
  String? _aiSideDish;
  String? _aiDrink;
  String? _aiSnack;
  // GPS fields
  bool _locating = true;
  String _locationStatus = '定位中...';
  int _locationRequestId = 0;
  LocationResult? _lastLocationResult;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _dishController = TextEditingController(text: widget.initialDraft.dishName);
    _locationController = TextEditingController(
      text: widget.initialDraft.location,
    );
    _priceController = TextEditingController(
      text: widget.initialDraft.priceText,
    );
    _ratingValue = widget.initialDraft.ratingScore ?? 0;
    _ratingTouched = widget.initialDraft.ratingScore != null;
    _beginGpsLookup();
  }

  @override
  void dispose() {
    _dishController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.config.layout;
    final capture = widget.config.capture;
    return Scaffold(
      appBar: AppBar(title: const Text('编辑记录')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: layout.pageHorizontalPadding,
            vertical: layout.pageVerticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(layout.cardRadius),
                child: Image.file(
                  File(_imagePath),
                  height: layout.cameraFrameHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                child: Column(
                  children: [
                    RatingStars(
                      value: _ratingValue,
                      onChanged: (value) => setState(() {
                        _ratingTouched = true;
                        _ratingValue = value;
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(_ratingTouched ? '当前评分：$_ratingValue 星' : '当前评分：未打分'),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _dishController,
                      decoration: InputDecoration(
                        labelText: capture.dishLabel,
                        hintText: capture.placeholderDish,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: capture.locationLabel,
                        hintText: capture.placeholderLocation,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: capture.priceLabel,
                        hintText: capture.placeholderPrice,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '记录时间：${DateFormat('MM/dd HH:mm').format(DateTime.now())}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _locating
                                  ? 'GPS 定位中...'
                                  : 'GPS 地点：$_locationStatus',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '重新定位',
                            onPressed: _locating ? null : _beginGpsLookup,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // AI 智能识别
                    if (widget.agentService != null &&
                        widget.agentService!.isAvailable) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _aiAnalyzing ? null : _analyzeWithAI,
                          icon: _aiAnalyzing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                              _aiAnalyzing ? 'AI 识别中...' : 'AI 识别图片'),
                        ),
                      ),
                      if (_aiMainDish != null ||
                          _aiCuisine != null ||
                          _aiSpiceLevel != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('AI 识别结果',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              if (_aiMainDish != null)
                                Text('主菜：$_aiMainDish',
                                    style: const TextStyle(fontSize: 12)),
                              if (_aiSideDish != null)
                                Text('配菜：$_aiSideDish',
                                    style: const TextStyle(fontSize: 12)),
                              if (_aiDrink != null)
                                Text('饮品：$_aiDrink',
                                    style: const TextStyle(fontSize: 12)),
                              if (_aiSnack != null)
                                Text('小吃：$_aiSnack',
                                    style: const TextStyle(fontSize: 12)),
                              if (_aiCuisine != null)
                                Text('菜系：$_aiCuisine',
                                    style: const TextStyle(fontSize: 12)),
                              if (_aiSpiceLevel != null)
                                Text('辣度：$_aiSpiceLevel',
                                    style: const TextStyle(fontSize: 12)),
                              if (_aiIngredients != null)
                                Text('食材：$_aiIngredients',
                                    style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _handleRetry,
                      child: Text(
                        widget.fromCamera
                            ? capture.retakeText
                            : capture.reselectText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _handleSave,
                      child: Text(capture.confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRetry() async {
    widget.repository.cacheDraft(
      MealDraft(
        dishName: _dishController.text,
        location: _locationController.text,
        priceText: _priceController.text,
        ratingScore: _ratingTouched ? _ratingValue : null,
      ),
    );

    final XFile? file = widget.fromCamera
        ? await widget.repository.captureFromCamera()
        : await widget.repository.pickFromGallery();

    if (!mounted) {
      return;
    }
    if (file == null) {
      Navigator.of(context).pop();
      return;
    }

    final draft = widget.repository.consumeDraftIfFresh() ?? MealDraft.empty();
    setState(() {
      _imagePath = file.path;
      _dishController.text = draft.dishName;
      _locationController.text = draft.location;
      _priceController.text = draft.priceText;
      _ratingTouched = draft.ratingScore != null;
      _ratingValue = draft.ratingScore ?? 0;
    });
    _beginGpsLookup();
  }

  Future<void> _handleSave() async {
    final priceText = _priceController.text.trim();
    if (priceText.isNotEmpty && double.tryParse(priceText) == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('金额格式有误'),
          content: const Text('请输入整数或小数金额，例如 12 或 12.5。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _saving = true);
    await widget.repository.saveRecord(
      sourceImagePath: _imagePath,
      dishNameInput: _dishController.text,
      locationInput: _locationController.text,
      priceText: priceText,
      ratingScore: _ratingTouched ? _ratingValue : null,
      aiMainDish: _aiMainDish,
      aiSideDish: _aiSideDish,
      aiDrink: _aiDrink,
      aiSnack: _aiSnack,
      aiSpiceLevel: _aiSpiceLevel,
      aiIngredients: _aiIngredients,
      aiCuisine: _aiCuisine,
      province: _lastLocationResult?.province,
      city: _lastLocationResult?.city,
      district: _lastLocationResult?.district,
      latitude: _lastLocationResult?.latitude,
      longitude: _lastLocationResult?.longitude,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存到本地数据库')));
    Navigator.of(context).pop();
  }

  Future<void> _analyzeWithAI() async {
    final agent = widget.agentService;
    if (agent == null || !agent.isAvailable) {
      _showAiNotConfiguredDialog();
      return;
    }

    setState(() => _aiAnalyzing = true);
    try {
      final result = await agent.analyzeFoodImage(_imagePath);
      if (!mounted) return;
      setState(() {
        _aiAnalyzing = false;
        _aiMainDish = result.mainDish;
        _aiSideDish = result.sideDish;
        _aiDrink = result.drink;
        _aiSnack = result.snack;
        _aiCuisine = result.cuisine;
        _aiSpiceLevel = result.spiceLevel;
        _aiIngredients = result.ingredients;
        // 如果用户还没填菜品，用 AI 识别的结果填充
        if (_dishController.text.isEmpty && result.dishName.isNotEmpty) {
          _dishController.text = result.dishName;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 识别失败：$e')),
      );
    }
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

  void _showAiNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 未配置'),
        content: const Text('AI 功能需要先在设置中配置模型。\n\n'
            '请前往「设置 → 智能功能 → AI 模型配置」完成设置。'),
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
  const _PreviewPlaceholder({required this.config, this.latestImagePath});

  final UiConfig config;
  final String? latestImagePath;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        latestImagePath != null && File(latestImagePath!).existsSync();
    return Container(
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
                    '当前版本使用系统相机/相册完成拍摄与选图，后续可切换为实时摄像头预览。',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ),
              ],
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
  const _RecentRecordCard({required this.record});

  final MealRecord record;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
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
          Text(record.ratingLabel),
        ],
      ),
    );
  }
}
