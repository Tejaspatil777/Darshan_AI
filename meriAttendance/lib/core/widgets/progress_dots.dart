import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Row of small progress dots — used on the face-capture screen (1/7)
/// and for the splash page indicator.
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    super.key,
    required this.total,
    required this.completed,
    this.size = 8,
  });

  final int total;
  final int completed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final bool active = i < completed;
        return Container(
          width: active ? size * 2 : size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(size),
          ),
        );
      }),
    );
  }
}
