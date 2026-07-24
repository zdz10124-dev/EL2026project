import 'package:flutter/material.dart';

import '../models/style_presets.dart';
import '../models/ui_config.dart';
import '../services/agent_service.dart';
import '../services/exercise_repository.dart';
import '../services/health_agent_service.dart';
import '../services/health_analysis_repository.dart';
import '../services/health_profile_repository.dart';
import '../services/llm_service.dart';
import '../services/meal_repository.dart';
import '../services/recovery_repository.dart';
import 'capture_screen.dart';
import 'health/health_hub_screen.dart';
import 'records/records_screen.dart';
import 'settings_screen.dart';
import 'today/today_screen.dart';

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
  late final ExerciseRepository _exerciseRepository;
  late final LlmService _llmService;
  late final AgentService _agentService;
  late final HealthAgentService _healthAgentService;
  late final HealthProfileRepository _healthProfileRepository;
  late final HealthAnalysisRepository _healthAnalysisRepository;
  late final RecoveryRepository _recoveryRepository;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = MealRepository()..initialize();
    _exerciseRepository = ExerciseRepository()..initialize();
    _llmService = LlmService();
    _agentService = AgentService(llmService: _llmService);
    _healthAgentService = HealthAgentService(llmService: _llmService);
    _healthProfileRepository = HealthProfileRepository();
    _recoveryRepository = RecoveryRepository();
    _healthAnalysisRepository = HealthAnalysisRepository(
      mealRepository: _repository,
      exerciseRepository: _exerciseRepository,
      profileRepository: _healthProfileRepository,
      agentService: _healthAgentService,
    );
    _llmService.loadConfig().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _repository.dispose();
    _exerciseRepository.dispose();
    _recoveryRepository.dispose();
    super.dispose();
  }

  Future<void> _recordMeal() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MealCapturePage(
          config: widget.config,
          repository: _repository,
          agentService: _agentService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(
        config: widget.config,
        mealRepository: _repository,
        exerciseRepository: _exerciseRepository,
        healthAgentService: _healthAgentService,
        healthAnalysisRepository: _healthAnalysisRepository,
        recoveryRepository: _recoveryRepository,
        onRecordMeal: _recordMeal,
        onOpenHealth: () => setState(() => _currentIndex = 2),
        isActive: _currentIndex == 0,
      ),
      RecordsScreen(
        config: widget.config,
        mealRepository: _repository,
        exerciseRepository: _exerciseRepository,
        mealAgentService: _agentService,
        healthAgentService: _healthAgentService,
      ),
      HealthHubScreen(
        config: widget.config,
        mealRepository: _repository,
        mealAgentService: _agentService,
        analysisRepository: _healthAnalysisRepository,
        profileRepository: _healthProfileRepository,
        diaryStyleId: widget.currentDiaryStyleId,
      ),
      SettingsScreen(
        config: widget.config,
        repository: _repository,
        exerciseRepository: _exerciseRepository,
        healthProfileRepository: _healthProfileRepository,
        healthAnalysisRepository: _healthAnalysisRepository,
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
            icon: const Icon(Icons.today_outlined),
            label: '今天',
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_chart_outlined),
            label: '记录',
          ),
          NavigationDestination(
            icon: const Icon(Icons.monitor_heart_outlined),
            label: '健康',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: '我的',
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
              child: _CheckerStrip(
                color: chrome.heroStart.withValues(alpha: 0.18),
              ),
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
              child: _LeafBranch(
                color: chrome.heroStart.withValues(alpha: 0.18),
              ),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
