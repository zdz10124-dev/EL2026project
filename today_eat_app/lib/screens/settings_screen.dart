import 'package:flutter/material.dart';

import '../models/ui_config.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.config});

  final UiConfig config;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('数据与隐私', '默认所有记录保存在本机数据库中。'),
      ('AI 扩展', '后续可在这里配置智能体接口与图片识别能力。'),
      ('定位权限', '后续可接入 GPS 自动补全地点。'),
      ('界面调节', '当前 UI 参数已拆分到 assets/config/ui_config.xml。'),
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: config.layout.pageHorizontalPadding,
          vertical: config.layout.pageVerticalPadding,
        ),
        child: ListView(
          children: [
            Text(
              config.pages.settingsTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('这里先保留常见设置布局，方便后面继续扩展具体功能。'),
            const SizedBox(height: 18),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.$1),
                    subtitle: Text(item.$2),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
