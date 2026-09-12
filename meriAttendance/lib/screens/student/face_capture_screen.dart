import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/// Guided face capture: dashed oval guide over the live camera preview,
/// pose instruction, 1/7 counter, progress dots and the capture button.
/// Capture order is fixed: Straight x3, Left x2, Right x2. After the 7th
/// capture an explicit Submit Enrollment button sends the captures to
/// POST /api/students/me/enroll.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _camera;
  EnrollmentProvider? _provider;

  /// Ancestor lookups are only safe here (framework contract). Cache the
  /// provider so [_onCameraReady] — which is also called from
  /// CameraView.dispose() — never performs a lookup on a deactivated tree.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<EnrollmentProvider>();
  }

  Future<void> _capture(BuildContext context) async {
    final EnrollmentProvider provider = context.read<EnrollmentProvider>();
    if (provider.detecting || provider.captureComplete) return;
    await provider.capture();
  }

  /// Takes one real picture and maps it to the API capture contract
  /// (pose + base64 JPEG + locally computed brightness/sharpness).
  Future<EnrollmentCapture> _takeCapture() async {
    final EnrollmentProvider provider = context.read<EnrollmentProvider>();
    final CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Camera is not ready');
    }
    final XFile file = await controller.takePicture();
    final List<int> bytes = await file.readAsBytes();
    final ImageMetrics metrics = await computeImageMetrics(Uint8List.fromList(bytes));
    return EnrollmentCapture(
      pose: provider.currentPose ?? EnrollmentPose.straight,
      imageB64: base64Encode(bytes),
      brightness: metrics.brightness,
      sharpness: metrics.sharpness,
    );
  }

  void _onCameraReady(CameraController? controller) {
    if (controller == null) {
      // CameraView.dispose() teardown path: never touch the widget tree here
      // (no setState — this element may already be unmounted). Only drop the
      // capture source so later taps cannot use a dead controller.
      _camera = null;
      _provider?.captureSource = null;
      return;
    }
    if (!mounted) return;
    setState(() => _camera = controller);
    _provider?.captureSource = _takeCapture;
  }

  /// Submits the 7 captures (POST /api/students/me/enroll) and moves on to
  /// the enrollment-complete confirmation screen ONLY when the backend
  /// reports the enrollment as complete.
  Future<void> _submit(BuildContext context) async {
    final EnrollmentProvider p = context.read<EnrollmentProvider>();
    if (p.submitting || !p.captureComplete) return;
    bool ok = false;
    try {
      ok = await p.submitEnrollment();
    } catch (e) {
      if (!context.mounted) return;
      showSnack(context, e is AppException ? e.message : friendlyError(e),
          error: true);
      return;
    }
    if (!context.mounted || !ok) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.enrollmentComplete);
  }

  @override
  Widget build(BuildContext context) {
    final EnrollmentProvider p = context.watch<EnrollmentProvider>();
    final EnrollmentPose? pose = p.currentPose;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Capture Face'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  children: [
                    CameraView(
                      direction: CameraLensDirection.front,
                      onControllerReady: _onCameraReady,
                    ),
                    const Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: FaceGuideOverlay(),
                      ),
                    ),
                    if (p.detecting)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: Center(
                          child: _DetectingBadge(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                pose?.instruction ?? 'All captures complete',
                style: AppTypography.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${p.captureIndex + 1 > EnrollmentProvider.totalCaptures ? EnrollmentProvider.totalCaptures : p.captureIndex + 1}'
                ' / ${EnrollmentProvider.totalCaptures}',
                style: AppTypography.title,
              ),
              const SizedBox(height: 12),
              ProgressDots(
                total: EnrollmentProvider.totalCaptures,
                completed: p.captureIndex,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: p.captureIndex > 0 &&
                        !p.detecting &&
                        !p.submitting
                    ? p.retakeLast
                    : null,
                child: const Text('Retake last'),
              ),
              const SizedBox(height: 4),
              if (p.captureComplete) ...[
                Text(
                  'All 7 captures look good. Submit to finish your enrollment.',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Submit Enrollment',
                  loading: p.submitting,
                  onPressed: p.submitting ? null : () => _submit(context),
                ),
              ] else
                _CaptureButton(
                  key: const ValueKey('captureButton'),
                  detecting: p.detecting,
                  disabled: false,
                  onTap: () => _capture(context),
                ),
              const SizedBox(height: AppSpacing.bottomCta),
            ],
          ),
        ),
      ),
    );
  }
}

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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _DetectingBadge extends StatelessWidget {
  const _DetectingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Detecting face...',
        style: AppTypography.caption.copyWith(color: Colors.white),
      ),
    );
  }
}
