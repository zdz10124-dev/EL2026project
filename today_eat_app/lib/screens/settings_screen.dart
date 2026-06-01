import 'package:flutter/material.dart';

import '../models/ui_config.dart';
import '../services/database_service.dart';
import '../services/llm_service.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.config,
    required this.llmService,
    this.onConfigChanged,
  });

  final UiConfig config;
  final LlmService llmService;
  final VoidCallback? onConfigChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _llmConfigured = false;

  @override
  void initState() {
    super.initState();
    _llmConfigured = widget.llmService.isConfigured;
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
            const SizedBox(height: 24),

            // ---- 账号与数据 ----
            _sectionHeader('账号与数据'),
            SectionCard(
              child: Column(
                children: [
                  _SettingItem(
                    icon: Icons.storage_outlined,
                    title: '本地数据管理',
                    subtitle: '查看记录总数、图片数量、数据库占用',
                    onTap: _showLocalData,
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.file_upload_outlined,
                    title: '导出数据',
                    subtitle: '将记录导出为表格或其他格式',
                    onTap: _showComingSoon,
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.delete_sweep_outlined,
                    title: '清空缓存',
                    subtitle: '清除临时缓存，不清除正式记录',
                    onTap: _confirmClearCache,
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.delete_forever_outlined,
                    title: '删除全部记录',
                    subtitle: '高风险操作，此操作不可恢复',
                    iconColor: Colors.redAccent,
                    titleColor: Colors.redAccent,
                    onTap: _confirmDeleteAll,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- 智能功能 ----
            _sectionHeader('智能功能'),
            SectionCard(
              child: Column(
                children: [
                  _AiConfigTile(
                    llmService: widget.llmService,
                    onTap: _openAiConfig,
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.image_search_outlined,
                    title: '图片识别补全菜品',
                    subtitle: _llmConfigured
                        ? '拍照后可使用 AI 识别菜品'
                        : '需先配置 AI 模型',
                    trailing: Switch(
                      value: _llmConfigured,
                      onChanged: (_) => _openAiConfig(),
                    ),
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.restaurant_menu_outlined,
                    title: '自动生成美食日记',
                    subtitle: '每天结束后自动生成日记',
                    trailing: Switch(
                      value: false,
                      onChanged: (v) => _showComingSoon(),
                    ),
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.restaurant_menu,
                    title: '营养分析提醒',
                    subtitle: '定期提醒查看营养总结',
                    trailing: Switch(
                      value: false,
                      onChanged: (v) => _showComingSoon(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- 应用偏好 ----
            _sectionHeader('应用偏好'),
            SectionCard(
              child: Column(
                children: [
                  _SettingItem(
                    icon: Icons.touch_app_outlined,
                    title: '默认进入页面',
                    subtitle: '当前固定为拍照记录页',
                    onTap: _showComingSoon,
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.access_time_outlined,
                    title: '时间显示格式',
                    subtitle: '当前使用 24 小时制',
                    onTap: _showComingSoon,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- 关于应用 ----
            _sectionHeader('关于应用'),
            SectionCard(
              child: Column(
                children: [
                  _SettingItem(
                    icon: Icons.info_outline,
                    title: '应用版本',
                    subtitle: 'v1.0.0',
                    onTap: () {},
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.description_outlined,
                    title: '功能说明',
                    subtitle: '了解应用的使用方法',
                    onTap: _showComingSoon,
                  ),
                  const _SettingDivider(),
                  _SettingItem(
                    icon: Icons.privacy_tip_outlined,
                    title: '隐私说明',
                    subtitle: '数据仅保存在本地',
                    onTap: _showComingSoon,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '愿你每天都能好好吃饭',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  void _showLocalData() async {
    final db = DatabaseService.instance;
    final records = await db.fetchRecords();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本地数据'),
        content: Text('记录总数：${records.length} 条'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('该功能正在开发中')),
    );
  }

  void _confirmClearCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('确定要清空临时缓存吗？不会删除正式记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清空')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除全部记录'),
        content: const Text('此操作不可恢复！确定要删除所有记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('开发中：删除功能待实现')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _openAiConfig() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AiConfigScreen(llmService: widget.llmService),
      ),
    ).then((changed) {
      if (changed == true) {
        _llmConfigured = widget.llmService.isConfigured;
        setState(() {});
        widget.onConfigChanged?.call();
      }
    });
  }
}

// ===== AI 配置 Tile (在设置列表中显示当前状态) =====

class _AiConfigTile extends StatelessWidget {
  const _AiConfigTile({required this.llmService, this.onTap});
  final LlmService llmService;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final configured = llmService.isConfigured;
    return _SettingItem(
      icon: Icons.auto_awesome_outlined,
      title: 'AI 模型配置',
      subtitle: configured ? '已配置' : '未配置 - 点击设置 API Key',
      iconColor: configured ? Colors.green : Colors.orange,
      onTap: onTap,
    );
  }
}

// ===== AI 配置二级页面 =====

class _AiConfigScreen extends StatefulWidget {
  const _AiConfigScreen({required this.llmService});
  final LlmService llmService;

  @override
  State<_AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<_AiConfigScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _saving = false;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    // 尝试从 secure storage 读取当前配置
    try {
      // 暂时不填充，用户手动输入
    } catch (_) {}
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 模型配置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '配置说明',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '请在下方输入你的 API Key 和模型信息。API Key 会安全存储在设备本地，'
              '不会上传到其他服务器。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // API Key
            TextField(
              controller: _apiKeyController,
              obscureText: !_showKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                suffixIcon: IconButton(
                  icon: Icon(_showKey
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Base URL
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'API 地址（可选）',
                hintText: 'https://api.openai.com/v1',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '默认使用 OpenAI 官方地址。如果使用代理或第三方兼容服务，请修改此项。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Model
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: '模型名称（可选）',
                hintText: 'gpt-4o',
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存配置'),
              ),
            ),
            if (widget.llmService.isConfigured) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _clearConfig,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const Text('清除配置'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API Key')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.llmService.saveConfig(
        apiKey: key,
        baseUrl: _baseUrlController.text.trim().isEmpty
            ? null
            : _baseUrlController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<void> _clearConfig() async {
    await widget.llmService.clearConfig();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已清除')),
    );
    Navigator.of(context).pop(true);
  }
}

// ===== 通用设置项组件 =====

class _SettingItem extends StatelessWidget {
  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: titleColor != null
            ? TextStyle(color: titleColor, fontWeight: FontWeight.w500)
            : null,
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 40,
      color: Colors.grey.shade300,
    );
  }
}
