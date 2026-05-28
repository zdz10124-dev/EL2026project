import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/meal_record.dart';
import '../models/ui_config.dart';
import '../services/meal_repository.dart';
import '../widgets/rating_stars.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.config,
    required this.repository,
  });

  final UiConfig config;
  final MealRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoFillDish = false;
  bool _autoFillLocation = false;
  bool _nutritionReminder = false;
  bool _publicRecords = false;
  bool _loadingPublicRecords = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.config.layout.pageHorizontalPadding,
          vertical: widget.config.layout.pageVerticalPadding,
        ),
        child: ListView(
          children: [
            Text(
              widget.config.pages.settingsTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('这里按账号与数据、智能功能、关于应用三个分组组织。'),
            const SizedBox(height: 18),
            _SettingsGroup(
              title: '账号与数据',
              children: [
                _SettingsActionTile(
                  icon: Icons.storage_rounded,
                  title: '本地数据管理',
                  subtitle: '查看记录总数、图片数量、数据库占用空间，并编辑或删除记录。',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LocalDataManagementPage(
                        repository: widget.repository,
                      ),
                    ),
                  ),
                ),
                _SettingsActionTile(
                  icon: Icons.file_upload_outlined,
                  title: '导出数据',
                  subtitle: '先保留按钮与说明，后续可导出为表格。',
                  onTap: () => _showInfo('导出数据', '当前先保留按钮样式，后续接入实际导出功能。'),
                ),
                _SettingsActionTile(
                  icon: Icons.cleaning_services_outlined,
                  title: '清空缓存',
                  subtitle: '仅清除临时缓存，不影响正式记录。',
                  onTap: _clearCache,
                ),
                _SettingsActionTile(
                  icon: Icons.delete_forever_outlined,
                  title: '删除全部记录',
                  subtitle: '危险操作，不可恢复。',
                  titleColor: Colors.red.shade700,
                  onTap: _deleteAllRecords,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: '智能功能',
              children: [
                _SettingsSwitchTile(
                  icon: Icons.auto_awesome_outlined,
                  title: '图片识别补全菜品',
                  subtitle: '当前保留开关位置，后续可接入图片识别。',
                  value: _autoFillDish,
                  onChanged: (value) => setState(() => _autoFillDish = value),
                ),
                _SettingsSwitchTile(
                  icon: Icons.location_on_outlined,
                  title: '定位补全地点',
                  subtitle: '当前保留开关位置，后续可接入定位。',
                  value: _autoFillLocation,
                  onChanged: (value) =>
                      setState(() => _autoFillLocation = value),
                ),
                _SettingsSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: '营养分析提醒',
                  subtitle: '后续用于提醒用户查看营养总结。',
                  value: _nutritionReminder,
                  onChanged: (value) =>
                      setState(() => _nutritionReminder = value),
                ),
                _SettingsSwitchTile(
                  icon: Icons.public_outlined,
                  title: '是否将自己的菜品记录公开',
                  subtitle: '开启后，记录未来可能出现在联网推荐里。',
                  value: _publicRecords,
                  onChanged: _loadingPublicRecords
                      ? null
                      : (value) => _togglePublicRecords(value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: '关于应用',
              children: [
                _SettingsActionTile(
                  icon: Icons.info_outline_rounded,
                  title: '应用版本',
                  subtitle: '当前版本 1.0.0',
                  onTap: () => _showInfo('应用版本', '今天吃什么 Flutter 首版'),
                ),
                _SettingsActionTile(
                  icon: Icons.description_outlined,
                  title: '功能说明',
                  subtitle: '查看当前版本已支持的功能范围。',
                  onTap: () => _showInfo('功能说明', '当前已支持记录、推荐、统计、日记预览与本地数据管理。'),
                ),
                _SettingsActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私说明',
                  subtitle: '说明本地数据和未来联网功能的边界。',
                  onTap: () =>
                      _showInfo('隐私说明', '当前记录默认仅保存在本地。公开记录开关未来才会接入联网能力。'),
                ),
                _SettingsActionTile(
                  icon: Icons.feedback_outlined,
                  title: '意见反馈',
                  subtitle: '当前先保留入口与说明。',
                  onTap: () => _showInfo('意见反馈', '当前先保留页面位置，后续可接入反馈表单或邮箱。'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '愿你每天都能好好吃饭（后续可改）',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final publicRecords = await widget.repository.getPublicRecordsEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _publicRecords = publicRecords;
      _loadingPublicRecords = false;
    });
  }

  Future<void> _showInfo(String title, String content) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirm = await _showConfirm(
      title: '清空缓存',
      content: '这只会清除临时缓存，不会删除正式记录。',
    );
    if (confirm != true) return;
    widget.repository.clearDraft();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('临时缓存已清空')));
  }

  Future<void> _togglePublicRecords(bool value) async {
    setState(() {
      _publicRecords = value;
      _loadingPublicRecords = true;
    });
    await widget.repository.setPublicRecordsEnabled(value);
    if (!mounted) {
      return;
    }
    setState(() => _loadingPublicRecords = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? '已开启公开记录，并开始尝试同步。' : '已关闭公开记录。')),
    );
  }

  Future<void> _deleteAllRecords() async {
    final confirm = await _showConfirm(
      title: '删除全部记录',
      content: '此操作不可恢复，所有正式记录和关联图片都会被删除。',
      destructive: true,
    );
    if (confirm != true) return;
    await widget.repository.deleteAllRecords();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除全部记录')));
  }

  Future<bool?> _showConfirm({
    required String title,
    required String content,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

class LocalDataManagementPage extends StatelessWidget {
  const LocalDataManagementPage({super.key, required this.repository});

  final MealRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本地数据管理')),
      body: FutureBuilder<LocalDataSummary>(
        future: repository.getLocalDataSummary(),
        builder: (context, summarySnapshot) {
          return StreamBuilder<List<MealRecord>>(
            stream: repository.recordsStream,
            initialData: const [],
            builder: (context, recordSnapshot) {
              final records = recordSnapshot.data ?? const <MealRecord>[];
              final summary = summarySnapshot.data;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MiniTile(
                        title: '本地记录总数',
                        value: summary == null
                            ? '...'
                            : '${summary.recordCount} 条',
                      ),
                      _MiniTile(
                        title: '图片数量',
                        value: summary == null
                            ? '...'
                            : '${summary.imageCount} 张',
                      ),
                      _MiniTile(
                        title: '数据库占用',
                        value: summary == null
                            ? '...'
                            : repository.formatBytes(summary.databaseBytes),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('记录列表', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    const SectionCard(child: Text('暂无正式记录'))
                  else
                    ...records.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SectionCard(
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: File(record.imagePath).existsSync()
                                      ? Image.file(
                                          File(record.imagePath),
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.photo_outlined,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.dishName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(record.location),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'MM/dd HH:mm',
                                      ).format(record.createdAt),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => RecordEditorPage(
                                          repository: repository,
                                          record: record,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('删除该记录'),
                                        content: const Text(
                                          '删除后将同步从数据库和本地图片中移除。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('取消'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await repository.deleteRecord(record);
                                    }
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('编辑'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class RecordEditorPage extends StatefulWidget {
  const RecordEditorPage({
    super.key,
    required this.repository,
    required this.record,
  });

  final MealRepository repository;
  final MealRecord record;

  @override
  State<RecordEditorPage> createState() => _RecordEditorPageState();
}

class _RecordEditorPageState extends State<RecordEditorPage> {
  late final TextEditingController _dishController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;
  late double _ratingStars;
  late bool _touched;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dishController = TextEditingController(text: widget.record.dishName);
    _locationController = TextEditingController(text: widget.record.location);
    _priceController = TextEditingController(
      text: widget.record.price?.toString() ?? '',
    );
    _ratingStars = (widget.record.ratingScore ?? 0) / 2;
    _touched = widget.record.ratingScore != null;
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
    return Scaffold(
      appBar: AppBar(title: const Text('编辑记录')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (File(widget.record.imagePath).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(widget.record.imagePath),
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              children: [
                RatingStars(
                  value: _ratingStars,
                  onChanged: (value) => setState(() {
                    _ratingStars = value;
                    _touched = true;
                  }),
                ),
                const SizedBox(height: 8),
                Text(_touched ? '当前评分：$_ratingStars 星' : '当前评分：未打分'),
                const SizedBox(height: 16),
                TextField(
                  controller: _dishController,
                  decoration: const InputDecoration(labelText: '菜品'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: '地点'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '价格（元）'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '记录时间：${DateFormat('yyyy/MM/dd HH:mm').format(widget.record.createdAt)}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存修改'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
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
    await widget.repository.updateRecord(
      original: widget.record,
      dishNameInput: _dishController.text,
      locationInput: _locationController.text,
      priceText: priceText,
      ratingScore: _touched ? _ratingStars : null,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title, style: TextStyle(color: titleColor)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.title, required this.value});

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
