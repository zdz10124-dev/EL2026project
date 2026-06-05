import 'dart:io';

import 'package:flutter/material.dart';

import '../models/style_presets.dart';
import '../models/ui_config.dart';
import '../services/meal_repository.dart';
import '../widgets/section_card.dart';

class DecideScreen extends StatefulWidget {
  const DecideScreen({
    super.key,
    required this.config,
    required this.repository,
    required this.isActive,
  });

  final UiConfig config;
  final MealRepository repository;
  final bool isActive;

  @override
  State<DecideScreen> createState() => _DecideScreenState();
}

class _DecideScreenState extends State<DecideScreen> {
  DecisionMode _mode = DecisionMode.random;
  MealSuggestion? _suggestion;
  bool _loading = false;

  @override
  void didUpdateWidget(covariant DecideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _resetSuggestionState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.config.decision;
    final chrome = context.appChrome;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.config.layout.pageHorizontalPadding,
          vertical: widget.config.layout.pageVerticalPadding,
        ),
        child: ListView(
          children: [
            const SizedBox(height: 12),
            Text(
              decision.heroTitle,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(decision.heroSubtitle, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Center(
              child: GestureDetector(
                onTap: _loading ? null : _refreshSuggestion,
                child: Container(
                  width: widget.config.layout.heroButtonSize,
                  height: widget.config.layout.heroButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage(chrome.decideButtonAssetPath),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(
                      color: chrome.cardColor.withValues(alpha: 0.92),
                      width: 6,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.16),
                          Colors.black.withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      _loading ? '思考中...' : (_suggestion?.title ?? '点我决定'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    title: decision.randomModeName,
                    icon: Icons.casino_rounded,
                    selected: _mode == DecisionMode.random,
                    onTap: () {
                      setState(() => _mode = DecisionMode.random);
                      _resetSuggestionState();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    title: decision.preferenceModeName,
                    icon: Icons.favorite_rounded,
                    selected: _mode == DecisionMode.preference,
                    onTap: () {
                      setState(() => _mode = DecisionMode.preference);
                      _resetSuggestionState();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _mode == DecisionMode.random
                  ? decision.randomModeDescription
                  : decision.preferenceModeDescription,
            ),
            const SizedBox(height: 18),
            if (_suggestion != null)
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '推荐理由',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_suggestion!.reason),
                    if (_suggestion!.sourceRecord != null) ...[
                      const SizedBox(height: 14),
                      Text('参考记录：${_suggestion!.sourceRecord!.location}'),
                      if (File(
                        _suggestion!.sourceRecord!.imagePath,
                      ).existsSync()) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            File(_suggestion!.sourceRecord!.imagePath),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshSuggestion() async {
    setState(() => _loading = true);
    try {
      final suggestion = await widget.repository.suggestMeal(_mode);
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取推荐失败：$e')),
      );
    }
  }

  void _resetSuggestionState() {
    if (!mounted) {
      return;
    }
    setState(() {
      _suggestion = null;
      _loading = false;
    });
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.22),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? colorScheme.primary : null),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
