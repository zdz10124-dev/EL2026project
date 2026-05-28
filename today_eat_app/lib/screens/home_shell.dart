import 'package:flutter/material.dart';

import '../models/ui_config.dart';
import '../services/meal_repository.dart';
import 'capture_screen.dart';
import 'decide_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.config});

  final UiConfig config;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final MealRepository _repository;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = MealRepository()..initialize();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CaptureScreen(config: widget.config, repository: _repository),
      DecideScreen(
        config: widget.config,
        repository: _repository,
        isActive: _currentIndex == 1,
      ),
      InsightsScreen(config: widget.config, repository: _repository),
      SettingsScreen(config: widget.config, repository: _repository),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.photo_camera_outlined),
            label: widget.config.pages.recordTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.ramen_dining_outlined),
            label: widget.config.pages.decideTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            label: widget.config.pages.insightTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: widget.config.pages.settingsTab,
          ),
        ],
      ),
    );
  }
}
