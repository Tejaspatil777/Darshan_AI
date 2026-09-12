import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'capture_widgets.dart';

/// Live camera preview used by the face-capture and classroom-photo screens.
///
/// The widget renders inside the EXISTING preview boxes (same size/radius as
/// the previous placeholders). When no camera is available (permission
/// denied, emulator without webcam, desktop) it falls back to the original
/// placeholder visual, and [onControllerReady] receives null so the flow
/// degrades honestly instead of faking captures.
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    this.direction = CameraLensDirection.front,
    this.onControllerReady,
    this.borderRadius,
  });

  final CameraLensDirection direction;
  final void Function(CameraController? controller)? onControllerReady;
  final BorderRadius? borderRadius;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No cameras available');
      }
      CameraDescription description = cameras.first;
      for (final CameraDescription c in cameras) {
        if (c.lensDirection == widget.direction) {
          description = c;
          break;
        }
      }
      final CameraController controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      widget.onControllerReady?.call(controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      widget.onControllerReady?.call(null);
    }
  }

  @override
  void dispose() {
    final void Function(CameraController? controller)? callback =
        widget.onControllerReady;
    _controller?.dispose();
    super.dispose();
    // Notify AFTER the subtree is torn down: the parent callback only mutates
    // provider state (no setState on this element), so notifying here cannot
    // trigger a "setState() called after dispose()" or an ancestor lookup on
    // the deactivated tree.
    callback?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      final Size size = MediaQuery.of(context).size;
      return ClipRRect(
        borderRadius: widget.borderRadius ?? AppRadius.previewBox,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.width * controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: widget.borderRadius ?? AppRadius.previewBox,
      child: Container(
        color: AppColors.cameraBg,
        child: _failed
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Camera unavailable',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : const Center(child: PersonSilhouette(size: 190)),
      ),
    );
  }
}
