import 'package:flutter/material.dart';

import '../models/style_presets.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final chrome = context.appChrome;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: chrome.cardColor.withValues(alpha: 0.82),
        border: Border.all(
          color: chrome.cardBorderColor.withValues(alpha: 0.72),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: chrome.shadowColor,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
