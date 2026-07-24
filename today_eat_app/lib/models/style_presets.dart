import 'package:flutter/material.dart';

import 'ui_config.dart';

enum AppStyleId { marketDay, retroDiner, matchaAtelier }

enum DiaryStyleId { floralGarden, retroMenu, midnightCinema, receiptCollage }

class AppChromeTheme extends ThemeExtension<AppChromeTheme> {
  const AppChromeTheme({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.ornamentColor,
    required this.cardColor,
    required this.cardBorderColor,
    required this.shadowColor,
    required this.heroStart,
    required this.heroEnd,
    required this.backgroundAssetPath,
    required this.decideButtonAssetPath,
  });

  final AppStyleId id;
  final String name;
  final String subtitle;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color ornamentColor;
  final Color cardColor;
  final Color cardBorderColor;
  final Color shadowColor;
  final Color heroStart;
  final Color heroEnd;
  final String backgroundAssetPath;
  final String decideButtonAssetPath;

  @override
  ThemeExtension<AppChromeTheme> copyWith({
    AppStyleId? id,
    String? name,
    String? subtitle,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? ornamentColor,
    Color? cardColor,
    Color? cardBorderColor,
    Color? shadowColor,
    Color? heroStart,
    Color? heroEnd,
    String? backgroundAssetPath,
    String? decideButtonAssetPath,
  }) {
    return AppChromeTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      ornamentColor: ornamentColor ?? this.ornamentColor,
      cardColor: cardColor ?? this.cardColor,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      shadowColor: shadowColor ?? this.shadowColor,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      backgroundAssetPath: backgroundAssetPath ?? this.backgroundAssetPath,
      decideButtonAssetPath: decideButtonAssetPath ?? this.decideButtonAssetPath,
    );
  }

  @override
  ThemeExtension<AppChromeTheme> lerp(
    covariant ThemeExtension<AppChromeTheme>? other,
    double t,
  ) {
    if (other is! AppChromeTheme) {
      return this;
    }
    return AppChromeTheme(
      id: t < 0.5 ? id : other.id,
      name: t < 0.5 ? name : other.name,
      subtitle: t < 0.5 ? subtitle : other.subtitle,
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom:
          Color.lerp(backgroundBottom, other.backgroundBottom, t)!,
      ornamentColor: Color.lerp(ornamentColor, other.ornamentColor, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      cardBorderColor:
          Color.lerp(cardBorderColor, other.cardBorderColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      backgroundAssetPath: t < 0.5 ? backgroundAssetPath : other.backgroundAssetPath,
      decideButtonAssetPath:
          t < 0.5 ? decideButtonAssetPath : other.decideButtonAssetPath,
    );
  }
}

class DiaryStyleSpec {
  const DiaryStyleSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.pageBackgroundColor,
    required this.paperColor,
    required this.inkColor,
    required this.accentColor,
    required this.shadowColor,
    this.backgroundAssetPath,
    this.frameAssetPath,
    this.decoAssetPath,
    this.useDivider = true,
    this.useTape = false,
    this.roundPhoto = true,
    this.showPageGlow = false,
  });

  final DiaryStyleId id;
  final String name;
  final String description;
  final Color pageBackgroundColor;
  final Color paperColor;
  final Color inkColor;
  final Color accentColor;
  final Color shadowColor;
  final String? backgroundAssetPath;
  final String? frameAssetPath;
  final String? decoAssetPath;
  final bool useDivider;
  final bool useTape;
  final bool roundPhoto;
  final bool showPageGlow;
}

class AppStyleCatalog {
  static const List<AppChromeTheme> styles = [
    AppChromeTheme(
      id: AppStyleId.marketDay,
      name: '集市',
      subtitle: '手作食堂感',
      backgroundTop: Color(0xFFFFF3E7),
      backgroundBottom: Color(0xFFF7DCC7),
      ornamentColor: Color(0x33D96C3D),
      cardColor: Color(0xD1FFFBF7),
      cardBorderColor: Color(0xFFEAC4A7),
      shadowColor: Color(0x22B35D37),
      heroStart: Color(0xFFD96C3D),
      heroEnd: Color(0xFFF1A94E),
      backgroundAssetPath: 'assets/theme/app_bg_market.png',
      decideButtonAssetPath: 'assets/theme/decide_market.png',
    ),
    AppChromeTheme(
      id: AppStyleId.retroDiner,
      name: '复古',
      subtitle: 'diner 餐牌感',
      backgroundTop: Color(0xFFFFF8EF),
      backgroundBottom: Color(0xFFF7E2D7),
      ornamentColor: Color(0x33C83E4D),
      cardColor: Color(0xD1FFFCF6),
      cardBorderColor: Color(0xFFC83E4D),
      shadowColor: Color(0x223F8E83),
      heroStart: Color(0xFFC83E4D),
      heroEnd: Color(0xFF3F8E83),
      backgroundAssetPath: 'assets/theme/app_bg_retro.png',
      decideButtonAssetPath: 'assets/theme/decide_retro.png',
    ),
    AppChromeTheme(
      id: AppStyleId.matchaAtelier,
      name: '抹茶',
      subtitle: '安静工房感',
      backgroundTop: Color(0xFFF5F7EE),
      backgroundBottom: Color(0xFFE2ECD9),
      ornamentColor: Color(0x334B7A52),
      cardColor: Color(0xD1FFFEFA),
      cardBorderColor: Color(0xFFC6D5BF),
      shadowColor: Color(0x224B7A52),
      heroStart: Color(0xFF4B7A52),
      heroEnd: Color(0xFFCE8B5B),
      backgroundAssetPath: 'assets/theme/app_bg_matcha.png',
      decideButtonAssetPath: 'assets/theme/decide_matcha.png',
    ),
  ];

  static const List<DiaryStyleSpec> diaryStyles = [
    DiaryStyleSpec(
      id: DiaryStyleId.floralGarden,
      name: '花草',
      description: '压花纸页与柔软手账装饰',
      pageBackgroundColor: Color(0xD1F3E7D8),
      paperColor: Color(0xD1FFFCF5),
      inkColor: Color(0xFF604F43),
      accentColor: Color(0xFFB76D79),
      shadowColor: Color(0x223C5C46),
      backgroundAssetPath: 'assets/journal/journal_notebook_bg_floral.png',
      useTape: true,
      roundPhoto: true,
    ),
    DiaryStyleSpec(
      id: DiaryStyleId.retroMenu,
      name: '餐牌',
      description: '棋盘角标和老餐厅菜单感',
      pageBackgroundColor: Color(0xD1F8E5D4),
      paperColor: Color(0xD1FFFAF1),
      inkColor: Color(0xFF462C22),
      accentColor: Color(0xFFC83E4D),
      shadowColor: Color(0x223F8E83),
      backgroundAssetPath: 'assets/journal/journal_notebook_bg_retro.png',
      useTape: false,
      roundPhoto: false,
    ),
    DiaryStyleSpec(
      id: DiaryStyleId.midnightCinema,
      name: '胶片',
      description: '暗场留白与电影放映氛围',
      pageBackgroundColor: Color(0xFF182033),
      paperColor: Color(0xFF20283D),
      inkColor: Color(0xFFF4E7C7),
      accentColor: Color(0xFFE6B95A),
      shadowColor: Color(0x44000000),
      backgroundAssetPath: 'assets/journal/journal_notebook_bg_midnight.png',
      useDivider: false,
      useTape: false,
      roundPhoto: false,
      showPageGlow: true,
    ),
    DiaryStyleSpec(
      id: DiaryStyleId.receiptCollage,
      name: '拼贴',
      description: '票据、印章和便签混排',
      pageBackgroundColor: Color(0xD1E8DED0),
      paperColor: Color(0xD1FFFBF3),
      inkColor: Color(0xFF4F463E),
      accentColor: Color(0xFFB2603A),
      shadowColor: Color(0x222D241F),
      backgroundAssetPath: 'assets/journal/journal_notebook_bg_receipt.png',
      useTape: true,
      roundPhoto: false,
    ),
  ];

  static AppChromeTheme styleById(AppStyleId id) {
    return styles.firstWhere((style) => style.id == id);
  }

  static DiaryStyleSpec diaryStyleById(DiaryStyleId id) {
    return diaryStyles.firstWhere((style) => style.id == id);
  }

  static AppStyleId appStyleFromStorage(String? value) {
    return AppStyleId.values.firstWhere(
      (style) => style.name == value,
      orElse: () => AppStyleId.marketDay,
    );
  }

  static DiaryStyleId diaryStyleFromStorage(String? value) {
    return DiaryStyleId.values.firstWhere(
      (style) => style.name == value,
      orElse: () => DiaryStyleId.floralGarden,
    );
  }

  static ThemeData buildTheme(UiConfig config, AppStyleId appStyleId) {
    final chrome = styleById(appStyleId);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: chrome.heroStart,
        primary: chrome.heroStart,
        secondary: chrome.heroEnd,
        surface: chrome.cardColor,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      cardColor: chrome.cardColor.withValues(alpha: 0.82),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: chrome.backgroundTop,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: chrome.inkOnSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: chrome.inkOnSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: chrome.cardColor.withValues(alpha: 0.78),
        indicatorColor: chrome.heroEnd.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: chrome.inkOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chrome.cardColor.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(config.layout.inputRadius),
          borderSide: BorderSide(color: chrome.cardBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(config.layout.inputRadius),
          borderSide: BorderSide(color: chrome.cardBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(config.layout.inputRadius),
          borderSide: BorderSide(color: chrome.heroStart, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: chrome.heroStart,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: chrome.cardBorderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textTheme: const TextTheme().copyWith(
        headlineMedium: TextStyle(
          color: chrome.inkOnSurface,
          fontSize: 30,
          fontWeight: FontWeight.w900,
          height: 1.02,
        ),
        titleLarge: TextStyle(
          color: chrome.inkOnSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: chrome.inkOnSurface,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: chrome.inkOnSurface.withValues(alpha: 0.84),
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: chrome.inkOnSurface.withValues(alpha: 0.62),
          fontSize: 12,
        ),
      ),
      extensions: [chrome],
    );
  }
}

extension AppChromeThemeAccess on BuildContext {
  AppChromeTheme get appChrome =>
      Theme.of(this).extension<AppChromeTheme>() ??
      AppStyleCatalog.styleById(AppStyleId.marketDay);
}

extension on AppChromeTheme {
  Color get inkOnSurface {
    final estimate = ThemeData.estimateBrightnessForColor(cardColor);
    return estimate == Brightness.dark ? Colors.white : const Color(0xFF2E241F);
  }
}
