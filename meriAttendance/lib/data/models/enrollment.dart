/// Face enrollment pose sequence values.
enum EnrollmentPose { straight, left, right }

extension EnrollmentPoseX on EnrollmentPose {
  String get label => switch (this) {
        EnrollmentPose.straight => 'Straight',
        EnrollmentPose.left => 'Left',
        EnrollmentPose.right => 'Right',
      };

  String get instruction => switch (this) {
        EnrollmentPose.straight => 'Look straight at the camera',
        EnrollmentPose.left => 'Slowly turn your head to the left',
        EnrollmentPose.right => 'Slowly turn your head to the right',
      };

  /// Pose value expected by the backend AI contract
  /// (AiDtos.EnrollFace.pose -> Python AI).
  String get apiValue => name;
}

/// One captured face crop submitted to POST /api/students/me/enroll.
/// Mirrors the backend AiDtos.EnrollFace contract:
/// `{ pose, quality: { brightness, sharpness, yaw }, image_b64 }`.
class EnrollmentCapture {
  const EnrollmentCapture({
    required this.pose,
    required this.imageB64,
    this.brightness,
    this.sharpness,
  });

  final EnrollmentPose pose;

  /// Plain base64 JPEG (no data-URL prefix needed — the backend strips both).
  final String imageB64;

  /// Mean luminance 0..1, computed locally on the raw capture.
  final double? brightness;

  /// Normalized mean-gradient sharpness, computed locally on the raw capture.
  final double? sharpness;

  Map<String, dynamic> toApiJson() => <String, dynamic>{
        'pose': pose.apiValue,
        'quality': <String, dynamic>{
          'brightness': brightness,
          'sharpness': sharpness,
          'yaw': null, // nullable Double in the backend contract
        },
        'image_b64': imageB64,
      };
}

/// The fixed capture sequence: Straight x3, Left x2, Right x2 = 7 total.
const List<EnrollmentPose> kEnrollmentPoseSequence = <EnrollmentPose>[
  EnrollmentPose.straight,
  EnrollmentPose.straight,
  EnrollmentPose.straight,
  EnrollmentPose.left,
  EnrollmentPose.left,
  EnrollmentPose.right,
  EnrollmentPose.right,
];

