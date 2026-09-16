import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/camera_view.dart';
import '../../core/widgets/camera_preview.dart';
import '../../core/widgets/capture_widgets.dart';
import '../../core/widgets/dashed_border.dart';
import '../../routing/app_router.dart';
import '../../state/attendance_provider.dart';

/// Classroom photo capture: FULL-SCREEN live camera with a transparent 3x3
/// composition grid (visual guide only), 5-10 manual captures, thumbnail
/// strip with delete / retake / preview.
///
/// The grid is an overlay layer only: it never modifies the captured photo,
/// never intercepts touches, and never blocks the camera or capture. The
/// capture flow (AttendanceProvider.addPhoto -> multipart upload) is
/// unchanged.
class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  CameraController? _camera;
  AttendanceProvider? _provider;

  /// Ancestor lookups are only safe here (framework contract). Cache the
  /// provider so [_onCameraReady] — which is also called from
  /// CameraView.dispose() — never performs a lookup on a deactivated tree.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<AttendanceProvider>();
  }

  /// Takes one real classroom photo and returns its JPEG bytes for the
  /// multipart upload (exact backend field: photos[]).
  Future<Uint8List> _takePhoto() async {
    final CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Camera is not ready');
    }
    final XFile file = await controller.takePicture();
    final List<int> bytes = await file.readAsBytes();
    return Uint8List.fromList(bytes);
  }

  void _onCameraReady(CameraController? controller) {
    if (controller == null) {
      // CameraView.dispose() teardown path: never touch the widget tree here
      // (no setState — this element may already be unmounted). Only drop the
      // photo source so later taps cannot use a dead controller.
      _camera = null;
      _provider?.photoSource = null;
      return;
    }
    if (!mounted) return;
    setState(() => _camera = controller);
    _provider?.photoSource = _takePhoto;
  }

  void _showPreview(BuildContext context, Uint8List? bytes, int seed) {
    final AttendanceProvider p = context.read<AttendanceProvider>();
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Photo preview'),
        content: SizedBox(
          height: 220,
          child: bytes != null
              ? ClipRRect(
                  borderRadius: AppRadius.previewBox,
                  child: Image.memory(bytes, fit: BoxFit.cover),
                )
              : ClassroomPreview(seed: seed),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              p.deleteLast();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              p.retakeLast();
            },
            child: const Text('Retake'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceProvider p = context.watch<AttendanceProvider>();
    final int count = p.photos.length;
    final bool atMax = count >= AttendanceProvider.maxPhotos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Capture Photos'),
      body: SafeArea(
        child: Column(
          children: [
            // Full-screen camera area: every pixel below the header, above
            // the capture controls.
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CameraView(
                      direction: CameraLensDirection.back,
                      onControllerReady: _onCameraReady,
                    ),
                  ),
                  // Transparent rule-of-thirds guide: over the preview,
                  // under the pills. Overlay only.
                  const Positioned.fill(child: CompositionGrid()),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _DarkPill(text: 'Now capture: ${p.nextArea}'),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(
                      child: _DarkPill(text: 'Frame the classroom using the grid'),
                    ),
                  ),
                ],
              ),
            ),
            _CaptureControls(count: count, atMax: atMax, onPreview: _showPreview),
          ],
        ),
      ),
    );
  }
}

/// Bottom capture controls: counter, shutter, thumbnails, retake/next.
class _CaptureControls extends StatelessWidget {
  const _CaptureControls({
    required this.count,
    required this.atMax,
    required this.onPreview,
  });

  final int count;
  final bool atMax;
  final void Function(BuildContext, Uint8List?, int seed) onPreview;

  @override
  Widget build(BuildContext context) {
    final AttendanceProvider p = context.read<AttendanceProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count / ${AttendanceProvider.maxPhotos}',
              style: AppTypography.title),
          const SizedBox(height: 12),
          _Shutter(atMax: atMax),
          const SizedBox(height: 8),
          Text(atMax ? 'Maximum of 10 photos' : 'Tap to capture',
              style: AppTypography.caption),
          const SizedBox(height: 12),
          _ThumbStrip(onPreview: onPreview),
          if (count < AttendanceProvider.minPhotos) ...[
            const SizedBox(height: 8),
            Text(
              'Capture at least ${AttendanceProvider.minPhotos} photos to continue.',
              style: AppTypography.caption.copyWith(color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Retake',
                  onPressed: count > 0 ? p.retakeLast : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Next',
                  onPressed: p.canSubmit
                      ? () => Navigator.of(context).pushNamed(AppRoutes.processing)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Dark rounded pill used for the on-preview instructions.
class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC111827),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTypography.helper.copyWith(color: Colors.white),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.atMax});

  final bool atMax;

  @override
  Widget build(BuildContext context) {
    final AttendanceProvider p = context.read<AttendanceProvider>();
    return GestureDetector(
      onTap: atMax ? null : () => p.addPhoto(),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: atMax ? AppColors.border : AppColors.primary,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: atMax ? AppColors.disabled : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.onPreview});

  final void Function(BuildContext, Uint8List?, int seed) onPreview;

  @override
  Widget build(BuildContext context) {
    final AttendanceProvider p = context.watch<AttendanceProvider>();
    final bool atMax = p.photos.length >= AttendanceProvider.maxPhotos;
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final photo in p.photos)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: CaptureThumb(
                seed: photo.seed,
                bytes: photo.bytes,
                onTap: () => onPreview(context, photo.bytes, photo.seed),
                onDelete: () => p.deletePhoto(photo.id),
              ),
            ),
          if (!atMax) const _AddTile(),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile();

  @override
  Widget build(BuildContext context) {
    final AttendanceProvider p = context.read<AttendanceProvider>();
    return GestureDetector(
      onTap: () => p.addPhoto(),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadius.thumbBox,
        ),
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: AppColors.borderStrong,
            radius: AppRadius.thumb,
          ),
          child:
              const Icon(Icons.add, size: 22, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

