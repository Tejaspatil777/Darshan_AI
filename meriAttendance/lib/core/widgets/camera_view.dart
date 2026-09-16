import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'capture_widgets.dart';

/// Live camera preview used by the face-capture and classroom-photo screens.
///
/// The widget renders inside the existing preview boxes. When no camera is
/// available (permission denied, emulator without webcam, desktop) it falls
/// back to a clear placeholder message, and [onControllerReady] receives null
/// so the flow degrades honestly instead of faking captures.
///
/// PREVIEW RENDERING (the important part): the plugin's [CameraPreview]
/// self-sizes with an AspectRatio render object, which REQUIRES bounded
/// constraints — it throws "RenderAspectRatio has unbounded constraints" when
/// nested directly inside a FittedBox (FittedBox lays its child out with fully
/// unbounded constraints). That made the live preview render as a blank white
/// area on real Android devices while captures / ML Kit kept working.
/// The fix: CameraPreview always receives an explicit, finite,
/// correctly-aspected size (derived from controller.value.previewSize — which
/// is in sensor orientation — plus the available box, with BoxFit.cover crop
/// math), so the texture always has real bounds to fill. Cropping is used to
/// fill; the image is never stretched.
///
/// When [onFrame] is non-null (Android/iOS only) the camera frame stream is
/// started with the format ML Kit expects (NV21 on Android, BGRA on iOS) and
/// every frame is delivered to the callback for on-device face detection.
/// [mirrorPreview] mirrors the preview horizontally — natural for the front
/// camera, matching the e-KYC-style guided capture.
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    this.direction = CameraLensDirection.front,
    this.onControllerReady,
    this.borderRadius,
    this.onFrame,
    this.mirrorPreview = false,
  });

  final CameraLensDirection direction;
  final void Function(CameraController? controller)? onControllerReady;
  final BorderRadius? borderRadius;

  /// Called with every streamed [CameraImage] when non-null. Only active on
  /// Android/iOS; on other platforms the stream is not started.
  final void Function(CameraImage image)? onFrame;

  final bool mirrorPreview;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  bool _failed = false;

  /// Set when the camera plugin reports a permission problem, so the UI can
  /// show the actionable message instead of a blank area.
  bool _permissionDenied = false;
  bool _streaming = false;

  bool get _wantsStream => widget.onFrame != null && _platformSupportsStream();

  static void _camLog(String message) {
    if (kDebugMode) debugPrint('[CAMERA] $message');
  }

  static bool _platformSupportsStream() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// The stream format ML Kit accepts on the current platform.
  static ImageFormatGroup _streamFormat() {
    if (kIsWeb) return ImageFormatGroup.jpeg;
    return defaultTargetPlatform == TargetPlatform.android
        ? ImageFormatGroup.nv21
        : ImageFormatGroup.bgra8888;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _camLog('initializing');
    try {
      final List<CameraDescription> cameras = await availableCameras();
      _camLog('available cameras: ${cameras.length}');
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
      _camLog('selected camera: ${description.lensDirection.name}');
      final CameraController controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            _wantsStream ? _streamFormat() : ImageFormatGroup.jpeg,
      );
      _camLog('initializing controller');
      await controller.initialize();
      if (!mounted) {
        _camLog('unmounted during init — disposing controller');
        await controller.dispose();
        return;
      }
      _camLog('controller initialized: '
          'previewSize=${controller.value.previewSize} '
          'aspectRatio=${controller.value.aspectRatio.toStringAsFixed(3)} '
          'isInitialized=${controller.value.isInitialized}');
      setState(() => _controller = controller);
      widget.onControllerReady?.call(controller);
      if (_wantsStream) {
        unawaited(_startStream(controller));
      }
    } on CameraException catch (e) {
      _camLog('initialization failed: ${e.code} - ${e.description}');
      if (mounted) {
        setState(() {
          _failed = true;
          _permissionDenied = e.code == 'cameraPermission';
        });
      }
      widget.onControllerReady?.call(null);
    } catch (e) {
      _camLog('initialization failed: $e');
      if (mounted) setState(() => _failed = true);
      widget.onControllerReady?.call(null);
    }
  }

  Future<void> _startStream(CameraController controller) async {
    if (_streaming || !controller.value.isInitialized) return;
    try {
      await controller.startImageStream((CameraImage image) {
        widget.onFrame?.call(image);
      });
      _camLog('image stream started');
      if (mounted) _streaming = true;
    } catch (_) {
      // Streaming is best-effort: face detection simply won't run and the
      // caller's manual fallback keeps the flow usable.
    }
  }

  Future<void> _stopStream() async {
    final CameraController? controller = _controller;
    if (controller == null || !_streaming) return;
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Already stopped / controller disposed.
    }
    _streaming = false;
  }

  @override
  void dispose() {
    final void Function(CameraController? controller)? callback =
        widget.onControllerReady;
    _stopStream();
    _controller?.dispose();
    super.dispose();
    // Notify AFTER the subtree is torn down: the parent callback only mutates
    // provider state (no setState on this element), so notifying here cannot
    // trigger a "setState() called after dispose()".
    callback?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      // Render the preview ONLY for an initialized controller, and ALWAYS
      // with explicit finite bounds: the child SizedBox below is sized to the
      // frame's DISPLAY aspect (previewSize is sensor-oriented, w > h on a
      // portrait phone) and scaled to COVER the available box — cropping the
      // overflow, never stretching the image. This keeps the plugin's
      // internal AspectRatio out of unbounded-constraint trouble.
      Widget preview = ClipRRect(
        borderRadius: widget.borderRadius ?? AppRadius.previewBox,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final Size sensor =
                controller.value.previewSize ?? const Size(3, 4);
            final double sensorAspect = sensor.width / sensor.height;
            final bool landscapeDisplay =
                MediaQuery.orientationOf(context) == Orientation.landscape;
            final double displayAspect =
                landscapeDisplay ? sensorAspect : 1 / sensorAspect;

            double w = box.maxWidth.isFinite ? box.maxWidth : 360;
            double h = box.maxHeight.isFinite ? box.maxHeight : w / displayAspect;
            if (w > 0 && h > 0) {
              if (w / h > displayAspect) {
                h = w / displayAspect; // box wider than frame: crop top/bottom
              } else {
                w = h * displayAspect; // box taller than frame: crop sides
              }
            }

            return FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: w,
                height: h,
                child: CameraPreview(controller),
              ),
            );
          },
        ),
      );
      if (widget.mirrorPreview) {
        preview = Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
          child: preview,
        );
      }
      return preview;
    }
    return ClipRRect(
      borderRadius: widget.borderRadius ?? AppRadius.previewBox,
      child: Container(
        color: AppColors.cameraBg,
        child: _failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _permissionDenied
                        ? 'Camera permission is required. '
                            'Enable it in app settings and try again.'
                        : 'Camera unavailable',
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

