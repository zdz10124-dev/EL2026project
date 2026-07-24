import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/exercise_record.dart';
import '../../models/meal_record.dart';
import '../../models/recovery_check_in.dart';
import '../../models/integrated_health_analysis.dart';
import '../../models/ui_config.dart';
import '../../services/exercise_repository.dart';
import '../../services/health_agent_service.dart';
import '../../services/health_analysis_repository.dart';
import '../../services/meal_repository.dart';
import '../../services/recovery_repository.dart';
import '../../widgets/section_card.dart';
import '../../widgets/themed_page_background.dart';
import '../decide_screen.dart';
import '../exercise/exercise_editor_screen.dart';
import '../recovery/recovery_check_in_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.config,
    required this.mealRepository,
    required this.exerciseRepository,
    required this.healthAgentService,
    required this.healthAnalysisRepository,
    required this.recoveryRepository,
    required this.onRecordMeal,
    required this.onOpenHealth,
    required this.isActive,
  });

  final UiConfig config;
  final MealRepository mealRepository;
  final ExerciseRepository exerciseRepository;
  final HealthAgentService healthAgentService;
  final HealthAnalysisRepository healthAnalysisRepository;
  final RecoveryRepository recoveryRepository;
  final VoidCallback onRecordMeal;
  final VoidCallback onOpenHealth;
  final bool isActive;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<MealRecord> _meals = const [];
  List<ExerciseRecord> _exercises = const [];
  List<HealthRecommendation> _recommendations = const [];
  RecoveryCheckIn? _recovery;
  StreamSubscription<List<MealRecord>>? _mealSubscription;
  StreamSubscription<List<ExerciseRecord>>? _exerciseSubscription;
  StreamSubscription<RecoveryCheckIn?>? _recoverySubscription;

  @override
  void initState() {
    super.initState();
    _mealSubscription = widget.mealRepository.recordsStream.listen((records) {
      if (mounted) setState(() => _meals = records);
    });
    _exerciseSubscription = widget.exerciseRepository.recordsStream.listen((
      records,
    ) {
      if (mounted) setState(() => _exercises = records);
    });
    _recoverySubscription = widget.recoveryRepository.watchDate(DateTime.now()).listen((record) {
      if (mounted) setState(() => _recovery = record);
    });
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final meals = await widget.mealRepository.fetchRecords();
    final exercises = await widget.exerciseRepository.fetchRecords();
    final analysis = await widget.healthAnalysisRepository.fetchCachedAnalysis(
      AnalysisPeriod.sevenDays,
    );
    final recovery = await widget.recoveryRepository.findByDate(DateTime.now());
    if (!mounted) return;
    setState(() {
      _meals = meals;
      _exercises = exercises;
      _recommendations =
          analysis?.recommendations
              .where((item) => item.validUntil.isAfter(DateTime.now()))
              .take(3)
              .toList() ??
          const [];
      _recovery = recovery;
    });
  }

  @override
  void dispose() {
    _mealSubscription?.cancel();
    _exerciseSubscription?.cancel();
    _recoverySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayMeals = _meals
        .where((item) => _isSameDay(item.createdAt, now))
        .length;
    final todayExercises = _exercises
        .where((item) => _isSameDay(item.startedAt, now))
        .toList();
    final exerciseMinutes = todayExercises.fold<int>(
      0,
      (sum, item) => sum + (item.durationSeconds / 60).round(),
    );

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: widget.config.layout.pageHorizontalPadding,
          vertical: widget.config.layout.pageVerticalPadding,
        ),
        children: [
          Text('今天', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('把饮食、运动和恢复放在同一条健康时间线上。'),
          const SizedBox(height: 18),
          SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: _Metric(label: '饮食记录', value: '$todayMeals 餐'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Metric(label: '运动时长', value: '$exerciseMinutes 分钟'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_recommendations.isNotEmpty) ...[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日建议', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ..._recommendations.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_recommendationIcon(item.category)),
                      title: Text(item.title),
                      subtitle: Text(item.action),
                      onTap: widget.onOpenHealth,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('快速记录', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: widget.onRecordMeal,
                        icon: const Icon(Icons.restaurant_outlined),
                        label: const Text('记录饮食'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _recordExercise,
                        icon: const Icon(Icons.directions_run),
                        label: const Text('记录运动'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Row(
              children: [
                Icon(
                  _recovery == null ? Icons.bedtime_outlined : Icons.favorite_outline,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('恢复打卡', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        _recovery == null
                            ? '花 20 秒记录睡眠、疲劳、酸痛和精力。'
                            : '已打卡：睡眠 ${_recovery!.sleepQuality}/5，疲劳 ${_recovery!.fatigue}/5',
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openRecoveryCheckIn,
                  child: Text(_recovery == null ? '去打卡' : '修改'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('智能行动', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('不知道下一餐吃什么，或想了解近期饮食与运动是否平衡？'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openDecide,
                        icon: const Icon(Icons.ramen_dining_outlined),
                        label: const Text('吃什么'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenHealth,
                        icon: const Icon(Icons.monitor_heart_outlined),
                        label: const Text('健康分析'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  IconData _recommendationIcon(RecommendationCategory category) =>
      switch (category) {
        RecommendationCategory.diet => Icons.restaurant_outlined,
        RecommendationCategory.exercise => Icons.directions_run,
        RecommendationCategory.rest => Icons.bedtime_outlined,
      };

  Future<void> _recordExercise() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseEditorScreen(
          repository: widget.exerciseRepository,
          agentService: widget.healthAgentService,
        ),
      ),
    );
  }

  Future<void> _openDecide() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('今天吃什么')),
          body: ThemedPageBackground(
            child: DecideScreen(
              config: widget.config,
              repository: widget.mealRepository,
              isActive: true,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRecoveryCheckIn() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecoveryCheckInScreen(
          repository: widget.recoveryRepository,
          date: DateTime.now(),
        ),
      ),
    );
    if (saved == true) {
      await _loadInitialData();
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 5),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
