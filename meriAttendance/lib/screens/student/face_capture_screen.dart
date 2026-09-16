import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    show Face;
import 'package:provider/provider.dart';

import '../../core/mlkit/camera_rotation.dart';
import '../../core/mlkit/face_detection_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/image_metrics.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/camera_view.dart';
import '../../core/widgets/capture_widgets.dart';
import '../../core/widgets/progress_dots.dart';
import '../../data/models/enrollment.dart';
import '../../data/repositories/repositories.dart';
import '../../routing/app_router.dart';
import '../../state/enrollment_provider.dart';

/// Face-enrollment auto-capture — deliberate and reliable.
///
/// Per frame ML Kit answers "is there a face?", and the frame loop applies
/// two cheap gates before arming a capture:
///  1. the face CENTRE (mapped from the analysis frame into the mirrored,
///     cover-cropped preview) lies inside the circular guide, and
///  2. the pose matches the wizard's current requirement
///     (Straight x3 → Left x2 → Right x2, via headEulerAngleY).
///
/// When both hold continuously for [_stableDuration], the screen takes a
/// full-resolution picture (a real, separate camera frame every time),
/// base64-encodes it and hands it to [EnrollmentProvider.registerCapture] —
/// which drives the existing 7-capture wizard and the unchanged
/// POST /api/students/me/enroll contract. The counter/dots only ever show
/// REAL registered captures: "7 / 7" ⇒ 7 actual images.
///
/// Every capture attempt arms a [_captureCooldown] lock, so the same instant
/// is never photographed twice. Quality validation, alignment and ArcFace
/// embeddings belong to the backend (Python AI), which rejects bad captures
/// at submit time. Non-mobile environments (tests, web) and devices without a
/// usable camera fall back to the manual/simulated capture button so the
/// wizard stays usable end-to-end.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  /// The face must stay detected continuously for this long before a capture
  /// fires (skips flickering single-frame detections / sensor warm-up).
  static const Duration _stableDuration = Duration(milliseconds: 700);

  /// Lock after EVERY capture attempt (success or failure): guarantees
  /// separate captures and prevents tight retry loops.
  static const Duration _captureCooldown = Duration(milliseconds: 1600);

  /// Brief "Captured" feedback shown between two auto captures.
  static const Duration _capturedFlashDuration = Duration(milliseconds: 900);

  /// Yaw (ML Kit `headEulerAngleY`, degrees) gates for the pose sequence.
  /// ML Kit convention: positive = the face is turned to the SUBJECT's left.
  /// [_turnSign] exists so a device test can flip the convention in one place
  /// without touching any other code.
  static const double _frontYawTolerance = 15;
  static const double _turnYawThreshold = 15;
  static const double _turnSign = 1;

  /// Containment tolerance: the face CENTRE may sit up to this fraction of
  /// the guide radius away from the guide centre (1.0 = exactly on the ring).
  /// A small margin keeps the UX from feeling frustratingly strict.
  static const double _guideTolerance = 1.1;

  CameraController? _camera;
  EnrollmentProvider? _provider;
  FaceDetectionService? _faceService;

  /// True once CameraView reports a hard camera failure (permission denied,
  /// no camera). Only then does the manual fallback render disabled.
  bool _unavailable = false;

  bool _facePresent = false;

  /// Face centre (mapped into preview coordinates) is inside the guide circle.
  bool _insideCircle = false;

  /// The pose required for the current capture is satisfied (yaw checked).
  bool _poseOk = false;

  /// Camera preview box size, captured during build so the frame loop can map
  /// ML Kit coordinates into the same space the overlay draws in.
  Size? _previewBox;

  /// A capture attempt (takePicture + base64 + register) is in flight.
  bool _capturing = false;

  /// Brief success feedback between two captures.
  bool _capturedFlash = false;

  DateTime? _stableSince;
  DateTime? _lastCaptureAt;
  int _frameCount = 0;
  Timer? _flashTimer;

  /// The auto-capture flow is live only with a working camera + ML Kit on a
  /// mobile platform. Everything else uses the manual fallback button.
  bool get _guided => _faceService != null && _camera != null && !_unavailable;

  bool get _busy => _capturing || _capturedFlash;

  void _faceLog(String message) {
    if (kDebugMode) debugPrint('[FACE] $message');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (FaceDetectionService.supported) {
      _faceService = FaceDetectionService();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<EnrollmentProvider>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // While backgrounded the camera stream pauses; reset stability so we never
    // auto-capture a stale frame on resume.
    if (state != AppLifecycleState.resumed) {
      _stableSince = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _faceService?.close();
    super.dispose();
  }

  // ---------------------------------------------------------------- camera

  void _onCameraReady(CameraController? controller) {
    if (controller == null) {
      _camera = null;
      _faceLog('camera unavailable');
      if (mounted) setState(() => _unavailable = true);
      return;
    }
    _faceLog(
      'camera initialized (${controller.description.lensDirection.name})',
    );
    if (!mounted) return;
    setState(() => _camera = controller);
  }

  // ------------------------------------------------------------- frame loop

  Future<void> _onFrame(CameraImage image) async {
    if (!mounted || !_guided || _busy) return;
    final EnrollmentProvider? provider = _provider;
    if (provider == null ||
        provider.captureComplete ||
        provider.detecting ||
        provider.enrolled) {
      return;
    }

    // Low-frequency frame log (~1/s at 30fps) keeps the console readable.
    _frameCount++;
    final bool tick = _frameCount % 30 == 1;
    if (tick) _faceLog('frame received #$_frameCount');

    // Cooldown: skip detection entirely while the capture lock is armed.
    final DateTime now = DateTime.now();
    final DateTime? last = _lastCaptureAt;
    if (last != null && now.difference(last) < _captureCooldown) return;

    final CameraController? controller = _camera;
    final FaceDetectionService? service = _faceService;
    if (controller == null || service == null) return;
    final Orientation orientation = MediaQuery.orientationOf(context);
    if (tick) _faceLog('detecting...');

    final int rotation = mlKitRotationDegrees(
      controller: controller,
      deviceOrientation: orientation,
    );
    final List<Face>? faces = await service.detect(image, rotation);
    if (faces == null || !mounted || _busy) return; // frame skipped

    // Largest face wins when several people are visible.
    final Face? face = faces.isEmpty
        ? null
        : faces.reduce(
            (Face a, Face b) =>
                a.boundingBox.width * a.boundingBox.height >=
                    b.boundingBox.width * b.boundingBox.height
                ? a
                : b,
          );

    final EnrollmentPose? required = provider.currentPose;
    final bool present = face != null;
    final bool inside =
        present && _faceInsideCircle(image, rotation, orientation, face);
    final bool poseOk = present && _poseMatches(face, required);

    if (present != _facePresent ||
        inside != _insideCircle ||
        poseOk != _poseOk) {
      setState(() {
        _facePresent = present;
        _insideCircle = inside;
        _poseOk = poseOk;
      });
    }
    if (tick) {
      _faceLog(
        'faces=${faces.length} insideCircle=$inside '
        'requiredPose=${required?.label ?? "-"} poseValid=$poseOk '
        'yaw=${face?.headEulerAngleY?.toStringAsFixed(1)} '
        'isCapturing=$_capturing',
      );
    }

    if (!present) {
      _stableSince = null;
      return;
    }

    // Every gate must hold CONTINUOUSLY for the stability window before the
    // capture fires. Face detected != capture: gates come first, and the
    // counter advances only after takePicture + Base64 + registerCapture.
    final bool allOk = inside && poseOk;
    _stableSince = allOk ? (_stableSince ?? now) : null;
    final Duration? held = _stableSince == null
        ? null
        : now.difference(_stableSince!);
    if (tick) {
      _faceLog(
        'stable=${held?.inMilliseconds ?? -1}ms '
        'canCapture=${allOk && held != null && held >= _stableDuration}',
      );
    }
    if (allOk && held != null && held >= _stableDuration) {
      _faceLog('AUTO CAPTURE START (pose=${required?.label})');
      _stableSince = null;
      unawaited(_autoCapture());
    }
  }

  /// Maps the ML Kit face bounding box into the mirrored, cover-cropped
  /// preview box and checks whether the face CENTRE lies inside the circular
  /// guide drawn by [_EnrollmentOverlay] (identical geometry via
  /// [_guideCircleFor]).
  ///
  /// Mapping (portrait phone — analysis frames arrive landscape):
  ///  * ML Kit reports boxes in the ROTATED (upright) space when the frame is
  ///    handed over with the correct InputImageRotation, so for 90°/270° the
  ///    upright analysis size is (image.height, image.width).
  ///  * Both the preview texture and the analysis frame cover-fill the box:
  ///    full height visible, sides cropped. A face at analysis fraction nx
  ///    lands at boxWidth * (0.5 + (nx - 0.5) * k) on screen, where
  ///    k = analysisAspect / previewAspect (the 16:9 preview is a narrower
  ///    crop of the scene than the 4:3 analysis frame).
  ///  * The front-camera preview is mirrored horizontally.
  bool _faceInsideCircle(
    CameraImage image,
    int rotation,
    Orientation orientation,
    Face face,
  ) {
    final Size? box = _previewBox;
    final CameraController? controller = _camera;
    if (box == null ||
        controller == null ||
        box.width <= 0 ||
        box.height <= 0) {
      return false;
    }
    final bool rotated = rotation == 90 || rotation == 270;
    final double uprightW = (rotated ? image.height : image.width).toDouble();
    final double uprightH = (rotated ? image.width : image.height).toDouble();
    if (uprightW <= 0 || uprightH <= 0) return false;

    final Rect fb = face.boundingBox;
    final double nx = fb.center.dx / uprightW; // 0..1 in upright frame
    final double ny = fb.center.dy / uprightH;

    final Size sensor = controller.value.previewSize ?? const Size(3, 4);
    final double sensorAspect = sensor.width / sensor.height;
    final bool landscape = orientation == Orientation.landscape;
    final double displayAspect = landscape ? sensorAspect : 1 / sensorAspect;
    final double analysisAspect = uprightW / uprightH;
    final double boxAspect = box.width / box.height;

    // Scene -> preview: the 16:9 preview stream is a centre-crop of the 4:3
    // analysis frame (portrait: full height, sides cropped), so a face at
    // analysis fraction nx lands at preview fraction 0.5 + (nx-0.5)*fovRatio.
    final double fovRatio = displayAspect > 0
        ? (analysisAspect / displayAspect).clamp(1.0, 2.0)
        : 1.0;
    // Preview -> widget box: BoxFit.cover crops whichever axis overflows.
    final double hFactor = boxAspect < displayAspect
        ? displayAspect /
              boxAspect // box taller than the frame: sides cropped
        : 1.0;
    final double vFactor = boxAspect > displayAspect
        ? boxAspect /
              displayAspect // box wider than the frame: t/b cropped
        : 1.0;

    double px = box.width * (0.5 + (nx - 0.5) * fovRatio * hFactor);
    double py = box.height * (0.5 + (ny - 0.5) * vFactor);
    if (controller.description.lensDirection == CameraLensDirection.front) {
      px = box.width - px; // mirrored front-camera preview
    }

    // Normalised ellipse containment: the face CENTRE must sit inside the
    // visible guide (with a small tolerance) before a capture may arm.
    final ({Offset center, double radius}) circle = _guideCircleFor(box);
    final double ndx =
        (px - circle.center.dx) / (circle.radius * _guideTolerance);
    final double ndy =
        (py - circle.center.dy) / (circle.radius * _guideTolerance);
    return ndx * ndx + ndy * ndy <= 1.0;
  }

  /// Yaw gate for the pose sequence, via ML Kit's `headEulerAngleY`
  /// (degrees, −90..90). ML Kit convention: positive = the face is turned to
  /// the SUBJECT's left, hence LEFT captures at yaw >= +threshold and RIGHT
  /// at yaw <= −threshold. If a physical test ever shows the trigger
  /// inverted, flip [_turnSign] — the only place the convention is encoded.
  ///
  /// A device that omits Euler data (null yaw) must never get permanently
  /// stuck, so a null yaw is treated as pose-OK — the backend Python AI still
  /// validates every image at submit time.
  bool _poseMatches(Face face, EnrollmentPose? pose) {
    if (pose == null) return true;
    final double? yaw = face.headEulerAngleY;
    if (yaw == null) return true;
    final double signed = yaw * _turnSign;
    return switch (pose) {
      EnrollmentPose.straight => signed.abs() <= _frontYawTolerance,
      EnrollmentPose.left => signed >= _turnYawThreshold,
      EnrollmentPose.right => signed <= -_turnYawThreshold,
    };
  }

  // ---------------------------------------------------------------- capture

  /// Takes ONE full-resolution photo, converts it to the existing Base64
  /// enrollment payload and registers it with the provider. The cooldown
  /// check makes duplicate captures of the same instant impossible.
  Future<void> _autoCapture() async {
    final EnrollmentProvider? provider = _provider;
    final CameraController? controller = _camera;
    if (_capturing || controller == null || provider == null) return;
    if (provider.captureComplete || provider.detecting || provider.enrolled) {
      return;
    }
    // Conditions may have drifted since the arming frame — never capture a
    // face that is outside the circle or in the wrong pose.
    if (!_insideCircle || !_poseOk) {
      _faceLog('capture aborted (inside=$_insideCircle poseOk=$_poseOk)');
      return;
    }
    final DateTime? last = _lastCaptureAt;
    if (last != null && DateTime.now().difference(last) < _captureCooldown) {
      return;
    }

    _capturing = true;
    if (mounted) setState(() => _capturedFlash = false);
    _faceLog('capture started');
    try {
      if (!controller.value.isInitialized) {
        throw StateError('Camera is not ready');
      }
      final XFile file = await controller.takePicture();
      final List<int> bytes = await file.readAsBytes();
      final ImageMetrics metrics = await computeImageMetrics(
        Uint8List.fromList(bytes),
      );

      final EnrollmentPose pose = provider.currentPose!;
      final EnrollmentCapture capture = EnrollmentCapture(
        pose: pose,
        imageB64: base64Encode(bytes),
        brightness: metrics.brightness,
        sharpness: metrics.sharpness,
      );
      _faceLog('base64 created (${bytes.length} bytes)');

      final bool registered = provider.registerCapture(capture);
      _faceLog('capture completed (registered=$registered)');
      _faceLog('enrollment image count: ${provider.captures.length}');

      _lastCaptureAt = DateTime.now();
      if (registered && mounted) {
        setState(() => _capturedFlash = true);
        _flashTimer?.cancel();
        _flashTimer = Timer(_capturedFlashDuration, () {
          if (!mounted) return;
          setState(() => _capturedFlash = false);
        });
      }
    } catch (error) {
      _faceLog('capture failed: $error');
      // Cooldown also applies to failures so a broken camera cannot loop.
      _lastCaptureAt = DateTime.now();
      if (mounted) {
        showSnack(
          context,
          'Capture failed — trying again shortly.',
          error: true,
        );
      }
    } finally {
      _capturing = false;
    }
  }

  // --------------------------------------------- manual fallback (no camera)

  Future<void> _capture(BuildContext context) async {
    final EnrollmentProvider provider = context.read<EnrollmentProvider>();
    if (provider.detecting || provider.captureComplete) return;
    await provider.capture();
  }

  void _retakeLast() {
    _provider?.retakeLast();
    _stableSince = null;
    _lastCaptureAt = null;
    if (mounted) {
      setState(() => _capturedFlash = false);
    }
  }

  Future<void> _submit(BuildContext context) async {
    final EnrollmentProvider p = context.read<EnrollmentProvider>();
    if (p.submitting || !p.captureComplete) return;
    bool ok = false;
    try {
      ok = await p.submitEnrollment();
    } catch (e) {
      if (!context.mounted) return;
      showSnack(
        context,
        e is AppException ? e.message : friendlyError(e),
        error: true,
      );
      return;
    }
    if (!context.mounted || !ok) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.enrollmentComplete);
  }

  // ------------------------------------------------------------------- build

  String _headingFor(EnrollmentProvider p, EnrollmentPose? pose) {
    if (_unavailable) {
      return 'Camera unavailable. Allow camera access and try again.';
    }
    if (p.captureComplete) {
      return 'All captures complete. Submit to finish your enrollment.';
    }
    if (!_guided) {
      return pose?.instruction ?? '';
    }
    return 'Keep your face visible to the camera';
  }

  /// Status text + colour for the guided overlay. The ring is green ONLY when
  /// a face is present AND inside the circle AND the required pose matches;
  /// red ("Keep your face inside the circle" / pose instruction) when a face
  /// is visible but a gate is unmet; neutral orange without a face.
  ({String text, Color color}) _previewStatus(EnrollmentProvider p) {
    if (p.captureComplete) {
      return (text: 'All captures complete', color: AppColors.success);
    }
    if (_capturing) {
      // The pill keeps "Face detected" while the line beneath it shows
      // "Capturing automatically..." (eKYC reference design).
      return (text: 'Face detected', color: AppColors.success);
    }
    if (_capturedFlash) {
      return (text: 'Captured \u2713', color: AppColors.success);
    }
    if (!_facePresent) {
      return (text: 'No face detected', color: AppColors.warning);
    }
    if (!_insideCircle) {
      return (text: 'Keep your face inside the circle', color: AppColors.error);
    }
    if (!_poseOk) {
      final EnrollmentPose? pose = p.currentPose;
      return (
        text: pose?.instruction ?? 'Look straight at the camera',
        color: AppColors.error,
      );
    }
    // All gates OK: green READY state while the stability window elapses.
    return (text: 'Face ready', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final EnrollmentProvider p = context.watch<EnrollmentProvider>();
    final EnrollmentPose? pose = p.currentPose;
    final int total = EnrollmentProvider.totalCaptures;
    final ({String text, Color color}) status = _previewStatus(p);
    // Truthful counter: always the number of REAL captures registered so
    // far. "7 / 7" can therefore only ever appear once 7 images have
    // actually been captured, base64-encoded and stored — never from mere
    // face detection. (The previous "captureIndex + 1" display showed
    // "7 / 7" while only 6 images existed.)
    final String counter = '${p.captureIndex.clamp(0, total)} / $total';
    // Ring colour follows the guide state exactly: green = all capture gates
    // OK (face inside circle + required pose), red = a gate is unmet, neutral
    // orange = no face.
    final Color ringColor = status.color;
    // Subline under the status pill: "Hold still..." while all gates are OK
    // and the stability window elapses; "Capturing automatically..." ONLY
    // while a real takePicture() is in flight. Null = no line at all.
    final String? subline = p.captureComplete
        ? null
        : _capturing
        ? 'Capturing automatically...'
        : (_capturedFlash
              ? null
              : (_facePresent && _insideCircle && _poseOk
                    ? 'Hold still...'
                    : null));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Face Enrollment'),
      body: SafeArea(
        child: Column(
          children: [
            // Live camera, edge to edge, with the eKYC-style circular face
            // guide drawn on top. The guide is visual only — it never blocks
            // touches and never gates the capture (ML Kit presence does).
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // Geometry cache for the frame loop's containment check —
                  // must match the circle the overlay draws (see
                  // _guideCircleFor below).
                  _previewBox = constraints.biggest;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CameraView(
                          direction: CameraLensDirection.front,
                          onControllerReady: _onCameraReady,
                          onFrame: _faceService != null ? _onFrame : null,
                          mirrorPreview: true,
                        ),
                      ),
                      if (_guided)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _EnrollmentOverlay(
                              ringColor: ringColor,
                              pillGreen: status.color == AppColors.success,
                              capturing: _capturing,
                              subline: subline,
                              statusText: status.text,
                              counter: counter,
                              total: total,
                              completed: p.captureIndex,
                            ),
                          ),
                        ),
                      if (_guided)
                        const Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: IgnorePointer(child: _GuidanceCard()),
                        ),
                    ],
                  );
                },
              ),
            ),
            // White footer strip under the preview.
            Container(
              width: double.infinity,
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              child: p.captureComplete
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PrimaryButton(
                          label: 'Submit Enrollment',
                          loading: p.submitting,
                          onPressed: p.submitting
                              ? null
                              : () => _submit(context),
                        ),
                        TextButton(
                          onPressed:
                              p.captureIndex > 0 &&
                                  !p.detecting &&
                                  !p.submitting
                              ? _retakeLast
                              : null,
                          child: const Text('Retake last'),
                        ),
                      ],
                    )
                  : _guided
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Keep your face inside the circle',
                          style: AppTypography.heading,
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed:
                              p.captureIndex > 0 &&
                                  !p.detecting &&
                                  !p.submitting
                              ? _retakeLast
                              : null,
                          child: const Text('Retake last'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Manual fallback (tests / web / no camera):
                        // heading, counter, dots and capture button.
                        Text(
                          _headingFor(p, pose),
                          style: AppTypography.heading,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(counter, style: AppTypography.title),
                        const SizedBox(height: 12),
                        ProgressDots(total: total, completed: p.captureIndex),
                        const SizedBox(height: 16),
                        _CaptureButton(
                          key: const ValueKey('captureButton'),
                          detecting: p.detecting,
                          disabled: _unavailable,
                          onTap: () => _capture(context),
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'ML Kit face detection is device-only — '
                            'automatic capture runs in the Android/iOS app.',
                            style: AppTypography.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        TextButton(
                          onPressed:
                              p.captureIndex > 0 &&
                                  !p.detecting &&
                                  !p.submitting
                              ? _retakeLast
                              : null,
                          child: const Text('Retake last'),
                        ),
                        const SizedBox(height: AppSpacing.bottomCta),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The circular face guide geometry — SINGLE source of truth shared by the
/// overlay painter and the frame loop's containment check, so the invisible
/// capture gate always coincides with the visible circle.
///
/// Sizing: 85% of the smaller preview dimension (responsive, no fixed
/// pixels; clamped only as a safety cap for huge desktop/web windows), so
/// the guide occupies most of the camera area with reasonable margins.
({Offset center, double radius}) _guideCircleFor(Size box) {
  final double diameter = (math.min(box.width, box.height) * 0.85)
      .clamp(220.0, 480.0)
      .toDouble();
  return (
    center: Offset(box.width / 2, box.height * 0.35),
    radius: diameter / 2,
  );
}

/// Status pill under the circular guide: bright green with a check while a
/// face is detected, neutral dark with an amber dot otherwise.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.green});

  final String text;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: green ? AppColors.success : const Color(0xE6111827),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (green)
            const Icon(Icons.check_circle, color: Colors.white, size: 20)
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark treatment drawn over the live preview: everything OUTSIDE the
/// circular guide is dimmed.
///
/// The scrim is ONE even-odd path (full rect minus the circle), so the circle
/// is simply never painted and the live camera frame underneath stays fully
/// visible inside it. The previous version erased the circle with
/// `BlendMode.clear`, which produced an opaque BLACK hole on a real Android
/// device: `clear` blends against the composited layer (the camera texture
/// lives in a separate platform layer), so the hole was filled with black
/// instead of letting the live preview show through.
class _CircleScrimPainter extends CustomPainter {
  _CircleScrimPainter({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // Geometric difference (fill-rule independent): the dark ring is the
    // rect MINUS the circle, so the circle interior is never painted on any
    // renderer and the live camera always shows through it. (The earlier
    // even-odd construction is correct in theory but fragile in practice on
    // device renderers; Path.combine cannot accidentally union.)
    final Path scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: 0.74),
    );
  }

  @override
  bool shouldRepaint(covariant _CircleScrimPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.radius != radius;
}

/// eKYC/Aadhaar-style enrollment overlay: dark scrim with a transparent
/// circular window, glowing face ring, detection status, "Capturing
/// automatically...", counter and progress dots. Purely visual — detection
/// and capture are driven entirely by the ML Kit frame loop.
class _EnrollmentOverlay extends StatelessWidget {
  const _EnrollmentOverlay({
    required this.ringColor,
    required this.pillGreen,
    required this.capturing,
    required this.subline,
    required this.statusText,
    required this.counter,
    required this.total,
    required this.completed,
  });

  final Color ringColor;
  final bool pillGreen;
  final bool capturing;
  final String? subline;
  final String statusText;
  final String counter;
  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bounds) {
        final ({Offset center, double radius}) circle = _guideCircleFor(
          bounds.biggest,
        );
        final Offset center = circle.center;
        final double radius = circle.radius;
        final double diameter = radius * 2;

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CircleScrimPainter(
                  center: center,
                  radius: radius + 6,
                ),
              ),
            ),
            Positioned(
              left: center.dx - radius,
              top: center.dy - radius,
              width: diameter,
              height: diameter,
              child: CircularFaceGuide(
                size: diameter,
                color: ringColor,
                animating: capturing,
                strokeWidth: 5,
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: center.dy + radius + 18,
              child: Column(
                children: [
                  _StatusPill(text: statusText, green: pillGreen),
                  if (subline != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      subline!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    counter,
                    style: AppTypography.display.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  ProgressDots(total: total, completed: completed, size: 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom guidance card over the dark preview area.
class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x66111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0x33FFFFFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.center_focus_strong,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay still for a moment',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Photo will be captured automatically',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFFD1D5DB)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual capture button for the fallback path (tests / web / no camera).
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    super.key,
    required this.detecting,
    required this.disabled,
    required this.onTap,
  });

  final bool detecting;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: detecting || disabled ? null : onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: disabled ? AppColors.border : AppColors.primary,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled
                ? AppColors.disabled
                : detecting
                ? AppColors.primarySoft
                : AppColors.primary,
          ),
          child: detecting
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
