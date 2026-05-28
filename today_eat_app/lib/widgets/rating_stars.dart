import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, required this.onChanged});

  static const double _iconSize = 36;
  static const double _horizontalPadding = 4;
  static const double _itemWidth = _iconSize + _horizontalPadding * 2;

  final double value;
  final ValueChanged<double> onChanged;

  static double resolveTapValue(double dx) {
    final clampedDx = dx.clamp(0, _itemWidth * 5 - 0.001);
    final index = (clampedDx / _itemWidth).floor();
    final itemStart = index * _itemWidth;
    final iconStart = itemStart + _horizontalPadding;
    final iconMid = iconStart + _iconSize / 2;
    final iconEnd = iconStart + _iconSize;

    if (clampedDx < iconStart) {
      return index.toDouble();
    }
    if (clampedDx <= iconMid) {
      return index + 0.5;
    }
    if (clampedDx <= iconEnd) {
      return index + 1.0;
    }
    return index + 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (innerContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final box = innerContext.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          onChanged(resolveTapValue(local.dx));
        },
        child: SizedBox(
          width: _itemWidth * 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              final full = value >= starNumber;
              final half = !full && value >= starNumber - 0.5;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                child: Icon(
                  full
                      ? Icons.star_rounded
                      : half
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: _iconSize,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
