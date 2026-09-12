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
