import 'package:flutter/material.dart';

import '../models/style_presets.dart';
import '../models/ui_config.dart';
import '../services/agent_service.dart';
import '../services/llm_service.dart';
import '../services/meal_repository.dart';
import 'capture_screen.dart';
import 'decide_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.config,
    required this.currentAppStyleId,
    required this.currentDiaryStyleId,
    required this.onAppStyleChanged,
    required this.onDiaryStyleChanged,
  });

  final UiConfig config;
  final AppStyleId currentAppStyleId;
  final DiaryStyleId currentDiaryStyleId;
  final ValueChanged<AppStyleId> onAppStyleChanged;
  final ValueChanged<DiaryStyleId> onDiaryStyleChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final MealRepository _repository;
  late final LlmService _llmService;
  late final AgentService _agentService;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = MealRepository()..initialize();
    _llmService = LlmService();
    _agentService = AgentService(llmService: _llmService);
    _llmService.loadConfig();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CaptureScreen(
        config: widget.config,
        repository: _repository,
        agentService: _agentService,
      ),
      DecideScreen(
        config: widget.config,
        repository: _repository,
        isActive: _currentIndex == 1,
      ),
      InsightsScreen(
        config: widget.config,
        repository: _repository,
        agentService: _agentService,
        defaultDiaryStyleId: widget.currentDiaryStyleId,
      ),
      SettingsScreen(
        config: widget.config,
        repository: _repository,
        llmService: _llmService,
        currentAppStyleId: widget.currentAppStyleId,
        currentDiaryStyleId: widget.currentDiaryStyleId,
        onAppStyleChanged: widget.onAppStyleChanged,
        onDiaryStyleChanged: widget.onDiaryStyleChanged,
        onConfigChanged: () => setState(() {}),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const _AppBackdrop(),
          IndexedStack(index: _currentIndex, children: pages),
        ],
      ),
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

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop();

  @override
  Widget build(BuildContext context) {
    final chrome = context.appChrome;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [chrome.backgroundTop, chrome.backgroundBottom],
        ),
        image: DecorationImage(
          image: AssetImage(chrome.backgroundAssetPath),
          fit: BoxFit.cover,
          opacity: 0.95,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -20,
            child: _BackdropBlob(
              size: 180,
              color: chrome.heroStart.withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            top: 150,
            left: -40,
            child: _BackdropBlob(
              size: 150,
              color: chrome.ornamentColor.withValues(alpha: 0.24),
            ),
          ),
          Positioned(
            bottom: -30,
            right: 40,
            child: _BackdropBlob(
              size: 220,
              color: chrome.heroEnd.withValues(alpha: 0.16),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: _BackdropAccent(chrome: chrome)),
          ),
        ],
      ),
    );
  }
}

class _BackdropAccent extends StatelessWidget {
  const _BackdropAccent({required this.chrome});

  final AppChromeTheme chrome;

  @override
  Widget build(BuildContext context) {
    switch (chrome.id) {
      case AppStyleId.marketDay:
        return Stack(
          children: [
            Positioned(
              top: 96,
              right: 28,
              child: _AccentLabel(
                text: 'fresh today',
                color: chrome.heroStart.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: 180,
              left: 26,
              child: _AccentDots(color: chrome.heroEnd.withValues(alpha: 0.22)),
            ),
          ],
        );
      case AppStyleId.retroDiner:
        return Stack(
          children: [
            Positioned(
              top: 110,
              left: 20,
              child: _CheckerStrip(color: chrome.heroStart.withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: 150,
              right: 30,
              child: _AccentSpark(
                color: chrome.heroEnd.withValues(alpha: 0.28),
                size: 54,
              ),
            ),
          ],
        );
      case AppStyleId.matchaAtelier:
        return Stack(
          children: [
            Positioned(
              top: 120,
              right: 24,
              child: _LeafBranch(color: chrome.heroStart.withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: 170,
              left: 32,
              child: _AccentLabel(
                text: 'slow lunch',
                color: chrome.heroEnd.withValues(alpha: 0.14),
              ),
            ),
          ],
        );
    }
  }
}

class _BackdropBlob extends StatelessWidget {
  const _BackdropBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.42),
      ),
    );
  }
}

class _AccentDots extends StatelessWidget {
  const _AccentDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        6,
        (_) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _AccentLabel extends StatelessWidget {
  const _AccentLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.08,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _CheckerStrip extends StatelessWidget {
  const _CheckerStrip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(
        12,
        (index) => Container(
          width: 14,
          height: 14,
          color: index.isEven ? color : Colors.transparent,
        ),
      ),
    );
  }
}

class _AccentSpark extends StatelessWidget {
  const _AccentSpark({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 6, height: size, color: color),
          Container(width: size, height: 6, color: color),
          Transform.rotate(
            angle: 0.78,
            child: Container(width: 5, height: size * 0.78, color: color),
          ),
          Transform.rotate(
            angle: -0.78,
            child: Container(width: 5, height: size * 0.78, color: color),
          ),
        ],
      ),
    );
  }
}

class _LeafBranch extends StatelessWidget {
  const _LeafBranch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 110,
      child: Stack(
        children: [
          Positioned(
            left: 42,
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: color),
          ),
          ...List.generate(
            5,
            (index) => Positioned(
              left: index.isEven ? 8 : 44,
              top: 10 + index * 18,
              child: Transform.rotate(
                angle: index.isEven ? -0.55 : 0.55,
                child: Container(
                  width: 28,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
