import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:today_eat_app/main.dart';
import 'package:today_eat_app/models/ui_config.dart';

void main() {
  testWidgets('应用可以正常渲染底部导航', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});

    final config = UiConfig(
      appTitle: '今天吃什么',
      appSubtitle: '测试副标题',
      theme: AppThemeConfig(
        seedColor: const Color(0xFFD96C3D),
        surfaceColor: const Color(0xFFFFF7F2),
        accentColor: const Color(0xFFFFB74D),
        successColor: const Color(0xFF4F8A5B),
      ),
      layout: LayoutConfig(
        pageHorizontalPadding: 20,
        pageVerticalPadding: 16,
        cameraFrameHeight: 320,
        cameraActionSize: 76,
        secondaryActionSize: 58,
        heroButtonSize: 220,
        cardRadius: 28,
        inputRadius: 18,
      ),
      capture: CaptureConfig(
        cameraTitle: '拍下这一顿',
        cameraHint: '测试',
        draftNotice: '测试',
        dishLabel: '菜品',
        locationLabel: '地点',
        priceLabel: '价格',
        confirmText: '确定',
        retakeText: '重拍',
        reselectText: '重选',
        placeholderDish: '测试',
        placeholderLocation: '测试',
        placeholderPrice: '测试',
      ),
      decision: DecisionConfig(
        heroTitle: '吃点什么',
        heroSubtitle: '测试',
        randomModeName: '随机模式',
        randomModeDescription: '测试',
        preferenceModeName: '偏好模式',
        preferenceModeDescription: '测试',
      ),
      pages: PagesConfig(
        recordTab: '记录',
        decideTab: '吃什么',
        insightTab: '其他',
        settingsTab: '设置',
        insightTitle: '其他功能',
        settingsTitle: '设置',
      ),
    );

    await tester.pumpWidget(TodayEatApp(config: config));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(NavigationBar).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ramen_dining_outlined), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
