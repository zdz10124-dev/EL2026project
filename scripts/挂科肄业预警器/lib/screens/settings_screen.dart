import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 通知设置
          const _SectionTitle(title: '通知与提醒'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('翘课预警通知'),
                  subtitle: const Text('翘课达到2次时发送预警'),
                  value: true,
                  onChanged: (value) {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('课前提醒'),
                  subtitle: const Text('上课前20分钟发送提醒'),
                  value: true,
                  onChanged: (value) {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('挂科预警通知'),
                  subtitle: const Text('加权平均分低于60时发送预警'),
                  value: true,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 隐私设置
          const _SectionTitle(title: '隐私与安全'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('自动登录'),
                  subtitle: const Text('下次启动时自动登录'),
                  value: true,
                  onChanged: (value) {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('数据加密存储'),
                  subtitle: const Text('对本地存储的敏感数据进行加密'),
                  value: true,
                  onChanged: (value) {},
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('清除本地数据'),
                  subtitle: const Text('清除所有缓存和本地存储的数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showClearDataDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 关于
          const _SectionTitle(title: '关于'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('版本号'),
                  subtitle: Text('v1.0.0'),
                ),
                const Divider(height: 1),
                const ListTile(
                  title: Text('开发者'),
                  subtitle: Text('挂科肄业预警器团队'),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('开源许可'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 底部说明
          Center(
            child: Text(
              '挂科肄业预警器 v1.0.0',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有本地数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据已清除')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}

/// 设置区域标题
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
