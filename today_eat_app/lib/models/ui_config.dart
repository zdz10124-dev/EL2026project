import 'package:flutter/material.dart';

class UiConfig {
  UiConfig({
    required this.appTitle,
    required this.appSubtitle,
    required this.theme,
    required this.layout,
    required this.capture,
    required this.decision,
    required this.pages,
  });

  final String appTitle;
  final String appSubtitle;
  final AppThemeConfig theme;
  final LayoutConfig layout;
  final CaptureConfig capture;
  final DecisionConfig decision;
  final PagesConfig pages;
}

class AppThemeConfig {
  AppThemeConfig({
    required this.seedColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.successColor,
  });

  final Color seedColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color successColor;
}

class LayoutConfig {
  LayoutConfig({
    required this.pageHorizontalPadding,
    required this.pageVerticalPadding,
    required this.cameraFrameHeight,
    required this.cameraActionSize,
    required this.secondaryActionSize,
    required this.heroButtonSize,
    required this.cardRadius,
    required this.inputRadius,
  });

  final double pageHorizontalPadding;
  final double pageVerticalPadding;
  final double cameraFrameHeight;
  final double cameraActionSize;
  final double secondaryActionSize;
  final double heroButtonSize;
  final double cardRadius;
  final double inputRadius;
}

class CaptureConfig {
  CaptureConfig({
    required this.cameraTitle,
    required this.cameraHint,
    required this.draftNotice,
    required this.dishLabel,
    required this.locationLabel,
    required this.priceLabel,
    required this.confirmText,
    required this.retakeText,
    required this.reselectText,
    required this.placeholderDish,
    required this.placeholderLocation,
    required this.placeholderPrice,
  });

  final String cameraTitle;
  final String cameraHint;
  final String draftNotice;
  final String dishLabel;
  final String locationLabel;
  final String priceLabel;
  final String confirmText;
  final String retakeText;
  final String reselectText;
  final String placeholderDish;
  final String placeholderLocation;
  final String placeholderPrice;
}

class DecisionConfig {
  DecisionConfig({
    required this.heroTitle,
    required this.heroSubtitle,
    required this.randomModeName,
    required this.randomModeDescription,
    required this.preferenceModeName,
    required this.preferenceModeDescription,
  });

  final String heroTitle;
  final String heroSubtitle;
  final String randomModeName;
  final String randomModeDescription;
  final String preferenceModeName;
  final String preferenceModeDescription;
}

class PagesConfig {
  PagesConfig({
    required this.recordTab,
    required this.decideTab,
    required this.insightTab,
    required this.settingsTab,
    required this.insightTitle,
    required this.settingsTitle,
  });

  final String recordTab;
  final String decideTab;
  final String insightTab;
  final String settingsTab;
  final String insightTitle;
  final String settingsTitle;
}
