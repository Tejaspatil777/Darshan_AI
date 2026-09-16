import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dashed_border.dart';

/// Grey person silhouette used inside the face-capture guide and the
/// unknown-face crop preview.
class PersonSilhouette extends StatelessWidget {
  const PersonSilhouette({super.key, this.size = 120, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SilhouettePainter(color: color ?? const Color(0xFFCBD2D9)),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double w = size.width;
    final double h = size.height;

    // Head.
    canvas.drawCircle(Offset(w / 2, h * 0.38), w * 0.21, paint);
    // Shoulders.
    canvas.drawArc(
      Rect.fromLTWH(w * 0.16, h * 0.66, w * 0.68, h * 0.9),
      3.14159,
      0,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Face guide: dashed oval over the preview area.
class FaceGuideOverlay extends StatelessWidget {
  const FaceGuideOverlay({super.key, this.color = AppColors.primary});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: DashedBorderPainter(
              color: color,
              oval: true,
              dashWidth: 8,
              dashGap: 6,
              strokeWidth: 2.2,
            ),
          );
        },
      ),
    );
  }
}

/// Captured-photo thumbnail with a delete badge. Shows the REAL photo when
/// [bytes] is provided; the placeholder visual is the fallback.
class CaptureThumb extends StatelessWidget {
  const CaptureThumb({
    super.key,
    required this.seed,
    this.bytes,
    this.onTap,
    this.onDelete,
    this.size = 54,
  });

  final int seed;
  final Uint8List? bytes;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double size;

  static const List<Color> _tones = [
    Color(0xFFB8C6D4),
    Color(0xFFC9D3C5),
    Color(0xFFD8C9B8),
    Color(0xFFC5C0D4),
    Color(0xFFD4C0C0),
  ];

  @override
  Widget build(BuildContext context) {
    final Widget image = bytes != null
        ? ClipRRect(
            borderRadius: AppRadius.thumbBox,
            child: Image.memory(
              bytes!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _tones[seed % _tones.length],
              borderRadius: AppRadius.thumbBox,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.image_outlined,
              size: size * 0.42,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          );
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          image,
          if (onDelete != null)
            Positioned(
              top: -5,
              right: -5,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xE6111827),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Unknown-face crop preview shown in the identification sheet. Renders the
/// REAL crop bytes fetched from GET /api/crops/{faceId} when provided; the
/// silhouette placeholder is the fallback while loading or on failure.
class FaceCropPreview extends StatelessWidget {
  const FaceCropPreview({super.key, this.size = 110, this.bytes});

  final double size;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.previewBox,
      ),
      child: Stack(
        children: [
          if (bytes != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: AppRadius.previewBox,
                child: Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            )
          else
            Center(child: PersonSilhouette(size: size * 0.8)),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: DashedBorderPainter(
                    color: AppColors.borderStrong,
                    radius: AppRadius.preview,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Transparent 3x3 composition grid drawn OVER the camera preview.
///
/// Purely a visual framing guide (rule-of-thirds): it is an IgnorePointer
/// overlay, is never part of the captured photo, and does not interact with
/// the camera, face detection, or capture in any way.
class CompositionGrid extends StatelessWidget {
  const CompositionGrid({
    super.key,
    this.color = const Color(0x59FFFFFF),
    this.strokeWidth = 1.2,
  });

  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CompositionGridPainter(
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _CompositionGridPainter extends CustomPainter {
  _CompositionGridPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final double dx = size.width / 3;
    final double dy = size.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(dx * i, 0), Offset(dx * i, size.height), paint);
      canvas.drawLine(Offset(0, dy * i), Offset(size.width, dy * i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CompositionGridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// eKYC/Aadhaar-style circular face guide drawn OVER the live camera preview.
///
/// Purely visual (IgnorePointer): it never gates capture — ML Kit face
/// presence is the only auto-capture trigger. States:
///  - [color] neutral/orange when no face, green when a face is detected.
///  - [animating] adds a subtle expanding ripple (used while capturing).
class CircularFaceGuide extends StatefulWidget {
  const CircularFaceGuide({
    super.key,
    required this.size,
    required this.color,
    this.animating = false,
    this.strokeWidth = 4,
  });

  final double size;
  final Color color;
  final bool animating;
  final double strokeWidth;

  @override
  State<CircularFaceGuide> createState() => _CircularFaceGuideState();
}

class _CircularFaceGuideState extends State<CircularFaceGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didUpdateWidget(covariant CircularFaceGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating != oldWidget.animating) {
      if (widget.animating) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
        _pulse.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _FaceRingPainter(
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            pulse: _pulse.value,
          ),
        ),
      ),
    );
  }
}

class _FaceRingPainter extends CustomPainter {
  _FaceRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.pulse,
  });

  final Color color;
  final double strokeWidth;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - strokeWidth;

    // Neon-style halo behind the ring (matches the eKYC reference design).
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // Soft outer glow.
    canvas.drawCircle(
      center,
      radius + strokeWidth,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.8,
    );
    // Main ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
    // Subtle ripple while capturing.
    if (pulse > 0) {
      canvas.drawCircle(
        center,
        radius * (1 + 0.10 * pulse),
        Paint()
          ..color = color.withValues(alpha: 0.45 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * (1 + 0.5 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaceRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.pulse != pulse;
}


