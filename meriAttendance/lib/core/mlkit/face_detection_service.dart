import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Thin wrapper around Google ML Kit's [FaceDetector].
///
/// Purpose in this app: answer ONE question per camera frame —
/// "is there a face in the frame?". It is ONLY the live detection trigger for
/// the auto-capture flow; all face-quality validation, alignment and ArcFace
/// embedding work happens in the backend (Python AI service).
///
/// - Converts a streamed [CameraImage] into an [InputImage]: NV21 on Android,
///   BGRA on iOS (the formats the camera plugin streams when requested).
/// - Serialises detections: ML Kit is not thread-safe, so a frame arriving
///   while the previous one is still being processed is skipped.
/// - Exposes [supported] so non-mobile platforms (e.g. web) can degrade to the
///   manual capture UI without ever calling ML Kit.
class FaceDetectionService {
  /// Accurate mode so detections are reliable as the auto-capture trigger.
  /// Landmarks/contours/classification (yaw etc.) are not needed: the flow
  /// captures on face PRESENCE, never on pose.
  FaceDetectionService() {
    if (supported) {
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.1,
        ),
      );
    }
  }

  FaceDetector? _detector;
  bool _processing = false;

  /// ML Kit face detection is only available on Android and iOS.
  static bool get supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get isSupported => supported;
  bool get isProcessing => _processing;

  /// Builds the [InputImage] for a streamed frame. Returns null when the frame
  /// format is not usable on the current platform.
  static InputImage? toInputImage(CameraImage image, int rotationDegrees) {
    if (kIsWeb) return null;
    final Uint8List bytes;
    final InputImageFormat format;
    final int bytesPerRow;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // NV21: one plane holding Y then interleaved VU.
      if (image.planes.isEmpty) return null;
      bytes = image.planes[0].bytes;
      format = InputImageFormat.nv21;
      bytesPerRow = image.planes[0].bytesPerRow;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // BGRA: one plane.
      if (image.planes.isEmpty) return null;
      bytes = image.planes[0].bytes;
      format = InputImageFormat.bgra8888;
      bytesPerRow = image.planes[0].bytesPerRow;
    } else {
      return null;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.values.firstWhere(
          (InputImageRotation r) => r.rawValue == rotationDegrees,
          orElse: () => InputImageRotation.rotation0deg,
        ),
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  /// Detects faces in [image]. Returns null when the frame could not be
  /// processed (busy, unsupported platform, or an ML Kit error) — callers
  /// should keep the previous result for that frame.
  Future<List<Face>?> detect(CameraImage image, int rotationDegrees) async {
    if (!supported || _processing) return null;
    final FaceDetector? detector = _detector;
    if (detector == null) return null;
    final InputImage? input = toInputImage(image, rotationDegrees);
    if (input == null) return null;

    _processing = true;
    try {
      return await detector.processImage(input);
    } catch (_) {
      return null;
    } finally {
      _processing = false;
    }
  }

  Future<void> close() async {
    await _detector?.close();
    _detector = null;
  }
}
