import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        final full = value >= starNumber;
        final half = !full && value >= starNumber - 0.5;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(details.globalPosition);
            final starWidth = box.size.width / 5;
            final starLeft = index * starWidth;
            final isHalf = local.dx - starLeft < starWidth / 2;
            onChanged(index + (isHalf ? 0.5 : 1.0));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              full
                  ? Icons.star_rounded
                  : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              color: Colors.amber,
              size: 36,
            ),
          ),
        );
      }),
    );
  }
}
