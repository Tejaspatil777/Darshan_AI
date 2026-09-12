import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Simulated classroom photo preview (chalkboard + desks).
/// Replaced by a real CameraPreview when camera integration is added.
class ClassroomPreview extends StatelessWidget {
  const ClassroomPreview({super.key, this.seed = 0, this.borderRadius});

  final int seed;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? AppRadius.previewBox,
      child: Container(
        color: AppColors.cameraBg,
        child: CustomPaint(
          size: Size.infinite,
          painter: _ClassroomPainter(seed: seed),
        ),
      ),
    );
  }
}

class _ClassroomPainter extends CustomPainter {
  _ClassroomPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Walls and floor.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.62),
      Paint()..color = const Color(0xFFF1F3F5),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      Paint()..color = const Color(0xFFDCE0E4),
    );

    // Chalkboard.
    final RRect board = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.26, h * 0.10, w * 0.48, h * 0.26),
      const Radius.circular(6),
    );
    canvas.drawRRect(board, Paint()..color = const Color(0xFF33544A));
    canvas.drawRRect(
      board.deflate(3),
      Paint()
        ..color = const Color(0xFF3E6457)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Window on the right wall.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.82, h * 0.12, w * 0.13, h * 0.22),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE4EEF6),
    );

    // Desk rows (position varies slightly with seed so thumbs differ).
    final double shift = (seed % 3) * w * 0.02;
    final Paint desk = Paint()..color = const Color(0xFFD9B98C);
    final Paint shadow = Paint()..color = const Color(0x22000000);
    for (int row = 0; row < 3; row++) {
      final double y = h * (0.68 + row * 0.11);
      final double deskH = h * 0.045 + row * 1.2;
      for (int col = 0; col < 4; col++) {
        final double x = w * (0.06 + col * 0.24) + shift * (row + 1) / 3;
        final Rect rect = Rect.fromLTWH(x, y, w * 0.17, deskH);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.translate(0, 2), const Radius.circular(3)),
          shadow,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          desk,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClassroomPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
