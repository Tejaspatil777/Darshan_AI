import 'dart:typed_data';
import 'dart:ui' as ui;

/// Result of the local quality estimation for one face capture.
class ImageMetrics {
  const ImageMetrics({required this.brightness, required this.sharpness});

  /// Mean luminance in 0..1.
  final double brightness;

  /// Normalized mean-gradient magnitude (0..~1) as a sharpness proxy.
  final double sharpness;
}

/// Computes brightness/sharpness metadata for a JPEG capture locally.
///
/// The Python AI service performs the authoritative quality gate; these
/// values are the request metadata fields of the backend contract
/// (`AiDtos.EnrollFace.quality`). yaw is not estimated locally and is sent
/// as null (nullable in the contract).
Future<ImageMetrics> computeImageMetrics(Uint8List jpegBytes) async {
  final ui.ImmutableBuffer buffer =
      await ui.ImmutableBuffer.fromUint8List(jpegBytes);
  final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
  final int sampleW = descriptor.width > 64 ? 64 : descriptor.width;
  final int sampleH = descriptor.height > 64 ? 64 : descriptor.height;
  final ui.Codec codec = await descriptor.instantiateCodec(
    targetWidth: sampleW,
    targetHeight: sampleH,
  );
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ByteData? data =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  descriptor.dispose();
  codec.dispose();
  frame.image.dispose();
  buffer.dispose();

  if (data == null) {
    return const ImageMetrics(brightness: 0, sharpness: 0);
  }

  final Uint8List pixels = data.buffer.asUint8List();
  final int w = sampleW;
  final int h = sampleH;

  // Mean luminance (Rec. 601 luma).
  double sum = 0;
  for (int i = 0; i < pixels.length; i += 4) {
    sum += 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
  }
  final double brightness = sum / (pixels.length ~/ 4) / 255.0;

  // Mean absolute horizontal+vertical gradient (sharpness proxy).
  double gradSum = 0;
  int count = 0;
  double lumaAt(int x, int y) {
    final int idx = (y * w + x) * 4;
    return 0.299 * pixels[idx] + 0.587 * pixels[idx + 1] + 0.114 * pixels[idx + 2];
  }

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final double gx = (lumaAt(x + 1, y) - lumaAt(x - 1, y)).abs();
      final double gy = (lumaAt(x, y + 1) - lumaAt(x, y - 1)).abs();
      gradSum += gx + gy;
      count++;
    }
  }
  final double sharpness =
      count == 0 ? 0 : (gradSum / count).clamp(0.0, 255.0) / 255.0;

  return ImageMetrics(
    brightness: double.parse(brightness.toStringAsFixed(4)),
    sharpness: double.parse(sharpness.toStringAsFixed(4)),
  );
}
