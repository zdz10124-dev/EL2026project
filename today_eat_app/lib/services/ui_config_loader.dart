import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../models/ui_config.dart';

class UiConfigLoader {
  static Future<UiConfig> load() async {
    final raw = await rootBundle.loadString('assets/config/ui_config.xml');
    final doc = XmlDocument.parse(raw);
    final root = doc.rootElement;

    String text(String section, String name) =>
        root.getElement(section)!.getElement(name)!.innerText.trim();
    double number(String section, String name) =>
        double.parse(text(section, name));
    Color color(String section, String name) =>
        _parseColor(text(section, name));

    return UiConfig(
      appTitle: text('app', 'title'),
      appSubtitle: text('app', 'subtitle'),
      theme: AppThemeConfig(
        seedColor: color('theme', 'seedColor'),
        surfaceColor: color('theme', 'surfaceColor'),
        accentColor: color('theme', 'accentColor'),
        successColor: color('theme', 'successColor'),
      ),
      layout: LayoutConfig(
        pageHorizontalPadding: number('layout', 'pageHorizontalPadding'),
        pageVerticalPadding: number('layout', 'pageVerticalPadding'),
        cameraFrameHeight: number('layout', 'cameraFrameHeight'),
        cameraActionSize: number('layout', 'cameraActionSize'),
        secondaryActionSize: number('layout', 'secondaryActionSize'),
        heroButtonSize: number('layout', 'heroButtonSize'),
        cardRadius: number('layout', 'cardRadius'),
        inputRadius: number('layout', 'inputRadius'),
      ),
      capture: CaptureConfig(
        cameraTitle: text('capture', 'cameraTitle'),
        cameraHint: text('capture', 'cameraHint'),
        draftNotice: text('capture', 'draftNotice'),
        dishLabel: text('capture', 'dishLabel'),
        locationLabel: text('capture', 'locationLabel'),
        priceLabel: text('capture', 'priceLabel'),
        confirmText: text('capture', 'confirmText'),
        retakeText: text('capture', 'retakeText'),
        reselectText: text('capture', 'reselectText'),
        placeholderDish: text('capture', 'placeholderDish'),
        placeholderLocation: text('capture', 'placeholderLocation'),
        placeholderPrice: text('capture', 'placeholderPrice'),
      ),
      decision: DecisionConfig(
        heroTitle: text('decision', 'heroTitle'),
        heroSubtitle: text('decision', 'heroSubtitle'),
        randomModeName: text('decision', 'randomModeName'),
        randomModeDescription: text('decision', 'randomModeDescription'),
        preferenceModeName: text('decision', 'preferenceModeName'),
        preferenceModeDescription: text(
          'decision',
          'preferenceModeDescription',
        ),
      ),
      pages: PagesConfig(
        recordTab: text('pages', 'recordTab'),
        decideTab: text('pages', 'decideTab'),
        insightTab: text('pages', 'insightTab'),
        settingsTab: text('pages', 'settingsTab'),
        insightTitle: text('pages', 'insightTitle'),
        settingsTitle: text('pages', 'settingsTitle'),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.parse(normalized, radix: 16));
  }
}
