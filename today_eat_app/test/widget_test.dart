// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:today_eat_app/main.dart';
import 'package:today_eat_app/models/ui_config.dart';

void main() {
  testWidgets('应用可以正常渲染底部导航', (WidgetTester tester) async {
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
    await tester.pumpAndSettle();

    expect(find.text('记录'), findsOneWidget);
    expect(find.text('吃什么'), findsOneWidget);
  });
}
