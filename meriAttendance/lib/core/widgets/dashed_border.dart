import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Paints a dashed border (rounded rect or oval) — used for the face guide
/// and the "add photo" tile.
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    this.radius = 16,
    this.oval = false,
    this.dashWidth = 7,
    this.dashGap = 5,
    this.strokeWidth = 2,
  });

  final Color color;
  final double radius;
  final bool oval;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Path path;
    if (oval) {
      path = Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            Radius.circular(radius),
          ),
        );
    }

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.oval != oval;
}
