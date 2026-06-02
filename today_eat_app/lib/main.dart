import 'package:flutter/material.dart';

import 'models/ui_config.dart';
import 'screens/home_shell.dart';
import 'services/ui_config_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await UiConfigLoader.load();
  runApp(TodayEatApp(config: config));
}


class TodayEatApp extends StatelessWidget {
  const TodayEatApp({super.key, required this.config});

  final UiConfig config;

  @override
  Widget build(BuildContext context) {
    final seedColor = config.theme.seedColor;
    return MaterialApp(
      title: config.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          surface: config.theme.surfaceColor,
        ),
        scaffoldBackgroundColor: config.theme.surfaceColor,
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(config.layout.inputRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(config.layout.inputRadius),
            borderSide: BorderSide(color: seedColor, width: 1.5),
          ),
        ),
      ),
      home: HomeShell(config: config),
    );
  }
}
