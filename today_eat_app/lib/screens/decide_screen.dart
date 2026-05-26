import 'dart:io';

import 'package:flutter/material.dart';

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
                    gradient: LinearGradient(
                      colors: [
                        widget.config.theme.seedColor,
                        widget.config.theme.accentColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    _loading ? '思考中...' : (_suggestion?.title ?? '点我决定'),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<DecisionMode>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: '选择模式'),
              items: [
                DropdownMenuItem(
                  value: DecisionMode.random,
                  child: Text(decision.randomModeName),
                ),
                DropdownMenuItem(
                  value: DecisionMode.preference,
                  child: Text(decision.preferenceModeName),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _mode = value);
                _resetSuggestionState();
              },
            ),
            const SizedBox(height: 12),
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
    final suggestion = await widget.repository.suggestMeal(_mode);
    if (!mounted) {
      return;
    }
    setState(() {
      _suggestion = suggestion;
      _loading = false;
    });
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
