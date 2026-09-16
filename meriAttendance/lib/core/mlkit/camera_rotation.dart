import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Computes the ML Kit `InputImage` rotation (degrees of clockwise rotation
/// needed to make a streamed frame upright) for the current platform and
/// device orientation.
///
/// The camera preview is portrait-oriented in this app, so the dominant case
/// is [Orientation.portrait] (returns the sensor orientation). Landscape is
/// handled generically (+90deg). This mirrors the canonical google_mlkit
/// camera example, reduced to the 2-way `Orientation` exposed by MediaQuery.
int mlKitRotationDegrees({
  required CameraController controller,
  required Orientation deviceOrientation,
}) {
  final int sensor = controller.description.sensorOrientation;
  if (deviceOrientation == Orientation.landscape) {
    return (sensor + 90) % 360;
  }
  // Portrait (and anything else) -> upright rotation equals the sensor angle.
  return sensor % 360;
}


