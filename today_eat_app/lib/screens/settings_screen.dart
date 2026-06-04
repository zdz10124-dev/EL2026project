import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/meal_record.dart';
import '../models/style_presets.dart';
import '../models/ui_config.dart';
import '../services/llm_service.dart';
import '../services/meal_repository.dart';
import '../widgets/rating_stars.dart';
import '../widgets/section_card.dart';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.config,
    required this.repository,
    required this.llmService,
    required this.currentAppStyleId,
    required this.currentDiaryStyleId,
    required this.onAppStyleChanged,
    required this.onDiaryStyleChanged,
    this.onConfigChanged,
  });

  final UiConfig config;
  final MealRepository repository;
  final LlmService llmService;
  final AppStyleId currentAppStyleId;
  final DiaryStyleId currentDiaryStyleId;
  final ValueChanged<AppStyleId> onAppStyleChanged;
  final ValueChanged<DiaryStyleId> onDiaryStyleChanged;
  final VoidCallback? onConfigChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _llmConfigured = false;
  bool _autoFillLocation = false;
  bool _nutritionReminder = false;
  bool _publicRecords = false;
  bool _loadingPublicRecords = true;
  late AppStyleId _appStyleId;
  late DiaryStyleId _diaryStyleId;

  @override
  void initState() {
    super.initState();
    _llmConfigured = widget.llmService.isConfigured;
    _appStyleId = widget.currentAppStyleId;
    _diaryStyleId = widget.currentDiaryStyleId;
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

            // ---- 账号与数据 ----
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

            // ---- 智能功能 ----
            _SettingsGroup(
              title: '智能功能',
              children: [
                _AiConfigTile(
                  llmService: widget.llmService,
                  onTap: _openAiConfig,
                ),
                _SettingsSwitchTile(
                  icon: Icons.image_search_outlined,
                  title: '图片识别补全菜品',
                  subtitle: _llmConfigured ? '已开启 AI 识别' : '需先配置 AI 模型',
                  value: _llmConfigured,
                  onChanged: (_) => _openAiConfig(),
                ),
                _SettingsSwitchTile(
                  icon: Icons.location_on_outlined,
                  title: '定位补全地点',
                  subtitle: '当前保留开关位置，后续可接入定位。',
                  value: _autoFillLocation,
                  onChanged: (value) => setState(() => _autoFillLocation = value),
                ),
                _SettingsSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: '营养分析提醒',
                  subtitle: '后续用于提醒用户查看营养总结。',
                  value: _nutritionReminder,
                  onChanged: (value) => setState(() => _nutritionReminder = value),
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
              title: '界面样式',
              children: [
                _StylePreviewTile(
                  icon: Icons.auto_awesome,
                  title: '应用主风格',
                  subtitle: '切换导航、卡片、底色和氛围装饰，尽量做出不同气质。',
                  value: _appStyleId.name,
                  labels: {
                    for (final style in AppStyleCatalog.styles)
                      style.id.name: style.name,
                  },
                  onChanged: (value) {
                    final selected = AppStyleCatalog.styleById(
                      AppStyleId.values.firstWhere(
                        (item) => item.name == value,
                      ),
                    );
                    setState(() => _appStyleId = selected.id);
                    widget.onAppStyleChanged(selected.id);
                  },
                ),
                _StylePreviewTile(
                  icon: Icons.menu_book_rounded,
                  title: '默认日记样式',
                  subtitle: '控制美食日记的纸张、照片框和装饰素材。',
                  value: _diaryStyleId.name,
                  labels: {
                    for (final style in AppStyleCatalog.diaryStyles)
                      style.id.name: style.name,
                  },
                  onChanged: (value) {
                    final selected = AppStyleCatalog.diaryStyleById(
                      DiaryStyleId.values.firstWhere(
                        (item) => item.name == value,
                      ),
                    );
                    setState(() => _diaryStyleId = selected.id);
                    widget.onDiaryStyleChanged(selected.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ---- 关于应用 ----
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
                  onTap: () => _showInfo('隐私说明', '当前记录默认仅保存在本地。公开记录开关未来才会接入联网能力。'),
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
            Center(
              child: Text(
                '愿你每天都能好好吃饭',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final publicRecords = await widget.repository.getPublicRecordsEnabled();
    if (!mounted) return;
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('临时缓存已清空')));
  }

  Future<void> _togglePublicRecords(bool value) async {
    setState(() {
      _publicRecords = value;
      _loadingPublicRecords = true;
    });
    await widget.repository.setPublicRecordsEnabled(value);
    if (!mounted) return;
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已删除全部记录')));
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

  void _openAiConfig() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => _AiConfigScreen(llmService: widget.llmService),
      ),
    )
        .then((changed) {
      if (changed == true) {
        _llmConfigured = widget.llmService.isConfigured;
        setState(() {});
        widget.onConfigChanged?.call();
      }
    });
  }
}

// ===== AI 配置 Tile =====

class _AiConfigTile extends StatelessWidget {
  const _AiConfigTile({required this.llmService, this.onTap});

  final LlmService llmService;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final configured = llmService.isConfigured;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.auto_awesome_outlined,
          color: configured ? Colors.green : Colors.orange,
        ),
        title: const Text('AI 模型配置'),
        subtitle: Text(configured ? '已配置' : '未配置 - 点击设置 API Key'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
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
  LlmMode _mode = LlmMode.direct;

  // Direct mode fields
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _showKey = false;

  // Server mode fields
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _authBusy = false;
  String? _authError;
  String? _loggedInUsername;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = widget.llmService.config;
    if (config != null) {
      _mode = config.mode;
      if (config.mode == LlmMode.server) {
        _serverUrlController.text = config.serverUrl ?? '';
        _loggedInUsername = config.username;
      } else {
        _apiKeyController.text = config.apiKey ?? '';
        _baseUrlController.text = config.baseUrl ?? '';
        _modelController.text = config.model ?? '';
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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
            // Mode selection
            SegmentedButton<LlmMode>(
              segments: const [
                ButtonSegment(
                  value: LlmMode.direct,
                  label: Text('直接连接'),
                  icon: Icon(Icons.cloud_outlined),
                ),
                ButtonSegment(
                  value: LlmMode.server,
                  label: Text('服务器代理'),
                  icon: Icon(Icons.dns_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selected) =>
                  setState(() => _mode = selected.first),
            ),
            const SizedBox(height: 20),

            if (_mode == LlmMode.direct) ..._buildDirectMode(),
            if (_mode == LlmMode.server) ..._buildServerMode(),

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

  List<Widget> _buildDirectMode() {
    return [
      Text(
        '配置说明',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        '直接在设备上配置 API Key，调用 OpenAI 兼容接口。'
        'API Key 安全存储在设备本地。',
        style: TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _apiKeyController,
        obscureText: !_showKey,
        decoration: InputDecoration(
          labelText: 'API Key',
          hintText: 'sk-...',
          suffixIcon: IconButton(
            icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showKey = !_showKey),
          ),
        ),
      ),
      const SizedBox(height: 14),
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
      TextField(
        controller: _modelController,
        decoration: const InputDecoration(
          labelText: '模型名称（可选）',
          hintText: 'gpt-4o',
        ),
      ),
    ];
  }

  List<Widget> _buildServerMode() {
    return [
      Text(
        '服务器代理模式',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'AI 请求通过你的服务器转发，API Key 存储在服务端，客户端不暴露。'
        '需要先注册/登录账号。',
        style: TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _serverUrlController,
        decoration: const InputDecoration(
          labelText: '服务器地址',
          hintText: 'https://api.whateattoday.xyz',
        ),
      ),
      const SizedBox(height: 16),

      if (_loggedInUsername == null) ...[
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '输入用户名',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '输入密码',
            suffixIcon: IconButton(
              icon:
                  Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_authError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _authError!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _authBusy ? null : _register,
                child: _authBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('注册'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _authBusy ? null : _login,
                child: _authBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
            ),
          ],
        ),
      ] else ...[
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text('已登录：$_loggedInUsername',
                style: const TextStyle(color: Colors.green)),
            const Spacer(),
            TextButton(
              onPressed: _logout,
              child: const Text('退出'),
            ),
          ],
        ),
      ],
    ];
  }

  Future<void> _register() async {
    await _authRequest('/v1/auth/register', '注册');
  }

  Future<void> _login() async {
    await _authRequest('/v1/auth/login', '登录');
  }

  Future<void> _authRequest(String endpoint, String action) async {
    final serverUrl = _serverUrlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (serverUrl.isEmpty) {
      setState(() => _authError = '请输入服务器地址');
      return;
    }
    if (username.isEmpty) {
      setState(() => _authError = '请输入用户名');
      return;
    }
    if (password.isEmpty) {
      setState(() => _authError = '请输入密码');
      return;
    }

    setState(() {
      _authBusy = true;
      _authError = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${serverUrl.replaceAll(RegExp(r'/+$'), '')}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['data']['token'] as String;
        await widget.llmService.saveServerConfig(
          serverUrl: serverUrl,
          authToken: token,
          username: username,
        );
        setState(() {
          _authBusy = false;
          _loggedInUsername = username;
          _usernameController.clear();
          _passwordController.clear();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action成功')),
        );
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _authBusy = false;
          _authError = body['detail']?.toString() ?? '$action失败';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authBusy = false;
        _authError = '网络错误：$e';
      });
    }
  }

  void _logout() {
    setState(() {
      _loggedInUsername = null;
      _authError = null;
    });
  }

  Future<void> _save() async {
    if (_mode == LlmMode.direct) {
      final key = _apiKeyController.text.trim();
      if (key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入 API Key')),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        await widget.llmService.saveDirectConfig(
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('配置已保存')));
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } else {
      // Server mode: ensure logged in and server URL saved
      if (_loggedInUsername == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先注册或登录')),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        // Config already saved during register/login, just pop
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('服务器代理模式已就绪')),
        );
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _clearConfig() async {
    await widget.llmService.clearConfig();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('配置已清除')));
    Navigator.of(context).pop(true);
  }
}

// ===== 本地数据管理页面 =====

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
                  Text('记录列表',
                      style: Theme.of(context).textTheme.titleLarge),
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
                                              Icons.photo_outlined),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.dishName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(record.location),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MM/dd HH:mm')
                                          .format(record.createdAt),
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
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
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

// ===== 记录编辑页面 =====

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
  late final TextEditingController _commentController;
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
    _commentController = TextEditingController(
      text: widget.record.comment ?? '',
    );
    _ratingStars = (widget.record.ratingScore ?? 0) / 2;
    _touched = widget.record.ratingScore != null;
  }

  @override
  void dispose() {
    _dishController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _commentController.dispose();
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
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '描述栏（选填）',
                    hintText: '补充口味、环境、分量、服务或个人感受',
                  ),
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
      commentInput: _commentController.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

// ===== 通用组件 =====

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

class _StylePreviewTile extends StatelessWidget {
  const _StylePreviewTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Map<String, String> labels;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels.entries.map((entry) {
              final selected = entry.key == value;
              return ChoiceChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: (_) => onChanged(entry.key),
                labelStyle: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
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
