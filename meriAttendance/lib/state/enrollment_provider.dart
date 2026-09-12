import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/enrollment.dart';
import '../data/repositories/repositories.dart';
import 'auth_provider.dart';

/// Drives the student face-enrollment wizard:
/// steps 1-4 (details/review) followed by the guided 7-pose capture
/// (Straight x3, Left x2, Right x2) and submission to the real backend
/// (POST /api/students/me/enroll -> Python AI via Spring Boot).
class EnrollmentProvider extends ChangeNotifier {
  EnrollmentProvider(this._repo, this._auth) {
    _auth.addListener(_onAuthChanged);
  }

  final EnrollmentRepository _repo;
  final AuthProvider _auth;
  Timer? _detectTimer;

  /// Injected by the capture screen when a real camera is available:
  /// takes a picture and returns the API-ready capture
  /// (pose + base64 JPEG + locally computed quality metrics).
  Future<EnrollmentCapture> Function()? captureSource;

  static const int totalCaptures = 7;
  static const List<EnrollmentPose> poseSequence = kEnrollmentPoseSequence;

  int wizardStep = 0;
  int captureIndex = 0;
  bool detecting = false;
  bool submitting = false;
  bool enrolled = false;

  /// Captures taken with the real camera, aligned with captureIndex.
  final List<EnrollmentCapture> captures = <EnrollmentCapture>[];

  bool get captureComplete => captureIndex >= totalCaptures;

  EnrollmentPose? get currentPose =>
      captureComplete ? null : poseSequence[captureIndex];

  void _onAuthChanged() {
    if (_auth.user == null) {
      reset();
    }
  }

  /// Loads the real enrollment status for the current student
  /// (GET /api/students/me/enrollment) — the backend is the source of truth,
  /// never a local boolean.
  Future<void> refreshEnrolled() async {
    final student = _auth.studentProfile;
    if (student == null) return;
    try {
      enrolled = await _repo.isEnrolled(student.id);
      if (enrolled && _auth.studentProfile?.faceEnrolled != true) {
        _auth.studentProfile = _auth.studentProfile!.copyWith(faceEnrolled: true);
      }
    } on AppException {
      // Leave the last known status on transient errors.
    }
    notifyListeners();
  }

  void nextWizardStep() {
    if (wizardStep < 3) {
      wizardStep += 1;
      notifyListeners();
    }
  }

  /// One guided capture. With a real camera the frame is taken immediately;
  /// the brief "Detecting face..." badge covers the capture + metrics work.
  /// Without a camera (tests / permission denied) the previous simulated
  /// timing is preserved so the wizard flow is unchanged.
  Future<void> capture() async {
    if (detecting || captureComplete) return;
    detecting = true;
    notifyListeners();
    final Future<EnrollmentCapture> Function()? source = captureSource;
    if (source != null) {
      try {
        final EnrollmentPose pose = poseSequence[captureIndex];
        final EnrollmentCapture taken = await source();
        // Guard against pose drift during the async capture.
        captures.add(EnrollmentCapture(
          pose: pose,
          imageB64: taken.imageB64,
          brightness: taken.brightness,
          sharpness: taken.sharpness,
        ));
        captureIndex += 1;
      } catch (_) {
        // Camera failure keeps the wizard on the same pose; the screen can
        // retry. Do not advance or fake a capture.
      } finally {
        detecting = false;
        notifyListeners();
      }
      return;
    }
    _detectTimer = Timer(const Duration(milliseconds: 700), () {
      detecting = false;
      captureIndex += 1;
      notifyListeners();
    });
  }

  void retakeLast() {
    if (captureIndex > 0) {
      captureIndex -= 1;
      if (captures.length > captureIndex) {
        captures.removeRange(captureIndex, captures.length);
      }
      notifyListeners();
    }
  }

  /// Submits the 7 captures (POST /api/students/me/enroll). "Enrollment
  /// Complete" is shown ONLY when the backend reports status == complete.
  Future<bool> submitEnrollment() async {
    final student = _auth.studentProfile;
    if (student == null || submitting || enrolled) return enrolled;
    submitting = true;
    notifyListeners();
    try {
      // With a camera the real captures are used; in test/simulation mode
      // (no images) the API repository rejects the request honestly instead
      // of faking success.
      final List<EnrollmentCapture> faces = captures.length == totalCaptures
          ? List<EnrollmentCapture>.of(captures)
          : <EnrollmentCapture>[
              for (final EnrollmentPose pose in poseSequence)
                EnrollmentCapture(pose: pose, imageB64: ''),
            ];
      await _repo.enroll(studentId: student.id, captures: faces);
      enrolled = true;
    } catch (_) {
      submitting = false;
      notifyListeners();
      rethrow;
    }
    submitting = false;
    notifyListeners();
    return true;
  }

  void reset() {
    _detectTimer?.cancel();
    wizardStep = 0;
    captureIndex = 0;
    detecting = false;
    submitting = false;
    captures.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _detectTimer?.cancel();
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

