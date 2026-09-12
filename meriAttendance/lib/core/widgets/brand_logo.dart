import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Meritendance "face in viewfinder" brand mark, drawn with a CustomPainter
/// so no image assets are required.
class FaceLogoMark extends StatelessWidget {
  const FaceLogoMark({super.key, this.size = 80, this.color = AppColors.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FaceLogoPainter(color: color)),
    );
  }
}

class _FaceLogoPainter extends CustomPainter {
  _FaceLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Corner viewfinder brackets.
    final double m = stroke.strokeWidth;
    final double r = w * 0.20;
    final Path brackets = Path()
      ..moveTo(m, m + r * 2)
      ..lineTo(m, m + r)
      ..quadraticBezierTo(m, m, m + r, m)
      ..lineTo(m + r * 2, m)
      ..moveTo(w - m - r * 2, m)
      ..lineTo(w - m - r, m)
      ..quadraticBezierTo(w - m, m, w - m, m + r)
      ..lineTo(w - m, m + r * 2)
      ..moveTo(w - m, w - m - r * 2)
      ..lineTo(w - m, w - m - r)
      ..quadraticBezierTo(w - m, w - m, w - m - r, w - m)
      ..lineTo(w - m - r * 2, w - m)
      ..moveTo(m + r * 2, w - m)
      ..lineTo(m + r, w - m)
      ..quadraticBezierTo(m, w - m, m, w - m - r)
      ..lineTo(m, w - m - r * 2);
    canvas.drawPath(brackets, stroke);

    // Face circle.
    final double cx = w / 2;
    final double cy = w * 0.54;
    final double headR = w * 0.215;
    canvas.drawCircle(Offset(cx, cy), headR, stroke);

    // Eyes.
    final Paint dot = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - headR * 0.42, cy - headR * 0.10), w * 0.028, dot);
    canvas.drawCircle(Offset(cx + headR * 0.42, cy - headR * 0.10), w * 0.028, dot);

    // Smile.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy + headR * 0.08), radius: headR * 0.58),
      0.45,
      3.14159 - 0.9,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceLogoPainter oldDelegate) => oldDelegate.color != color;
}

/// Full splash/login brand lockup: mark + wordmark + tagline.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.markSize = 80, this.showTagline = true});

  final double markSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaceLogoMark(size: markSize),
        SizedBox(height: markSize * 0.22),
        Text('DarshanAI', style: AppTypography.display.copyWith(fontSize: 25)),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text('Face Attendance for Campus', style: AppTypography.caption),
        ],
      ],
    );
  }
}
