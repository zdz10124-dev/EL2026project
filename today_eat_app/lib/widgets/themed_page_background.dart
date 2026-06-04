import 'package:flutter/material.dart';

import '../models/style_presets.dart';

class ThemedPageBackground extends StatelessWidget {
  const ThemedPageBackground({
    super.key,
    required this.child,
  });

  final Widget child;

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
          opacity: 0.92,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -12,
            child: _PageBlob(
              size: 150,
              color: chrome.heroStart.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -24,
            left: -20,
            child: _PageBlob(
              size: 130,
              color: chrome.heroEnd.withValues(alpha: 0.14),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _PageBlob extends StatelessWidget {
  const _PageBlob({
    required this.size,
    required this.color,
  });

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
