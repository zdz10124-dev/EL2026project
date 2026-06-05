import 'package:flutter/material.dart';

import 'models/style_presets.dart';
import 'models/ui_config.dart';
import 'screens/home_shell.dart';
import 'services/app_settings_service.dart';
import 'services/ui_config_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await UiConfigLoader.load();
  runApp(TodayEatApp(config: config));
}

class TodayEatApp extends StatefulWidget {
  const TodayEatApp({super.key, required this.config});

  final UiConfig config;

  @override
  State<TodayEatApp> createState() => _TodayEatAppState();
}

class _TodayEatAppState extends State<TodayEatApp> {
  final AppSettingsService _settingsService = AppSettingsService();
  AppStyleId _appStyleId = AppStyleId.marketDay;
  DiaryStyleId _diaryStyleId = DiaryStyleId.floralGarden;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadStyleSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppStyleCatalog.buildTheme(widget.config, _appStyleId);
    return MaterialApp(
      title: widget.config.appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: _loaded
          ? HomeShell(
              config: widget.config,
              currentAppStyleId: _appStyleId,
              currentDiaryStyleId: _diaryStyleId,
              onAppStyleChanged: (value) {
                _setAppStyle(value);
              },
              onDiaryStyleChanged: (value) {
                _setDiaryStyle(value);
              },
            )
          : const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
    );
  }

  Future<void> _loadStyleSettings() async {
    final savedAppStyleId = await _settingsService.getAppStyleId();
    final savedDiaryStyleId = await _settingsService.getDiaryStyleId();
    if (!mounted) {
      return;
    }
    setState(() {
      _appStyleId = AppStyleCatalog.appStyleFromStorage(savedAppStyleId);
      _diaryStyleId = AppStyleCatalog.diaryStyleFromStorage(savedDiaryStyleId);
      _loaded = true;
    });
  }

  Future<void> _setAppStyle(AppStyleId value) async {
    setState(() => _appStyleId = value);
    await _settingsService.setAppStyleId(value.name);
  }

  Future<void> _setDiaryStyle(DiaryStyleId value) async {
    setState(() => _diaryStyleId = value);
    await _settingsService.setDiaryStyleId(value.name);
  }
}
