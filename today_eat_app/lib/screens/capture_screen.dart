import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/meal_draft.dart';
import '../models/meal_record.dart';
import '../models/ui_config.dart';
import '../services/meal_repository.dart';
import '../widgets/rating_stars.dart';
import '../widgets/section_card.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.config,
    required this.repository,
  });

  final UiConfig config;
  final MealRepository repository;

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
  });

  final UiConfig config;
  final MealRepository repository;
  final String imagePath;
  final bool fromCamera;
  final MealDraft initialDraft;

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  late final TextEditingController _dishController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;
  late String _imagePath;
  late double _ratingValue;
  bool _ratingTouched = false;
  bool _saving = false;

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
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'AI 接口预留：后续可在这里接入图片识别补全菜品、GPS 反查地点。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
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
