import 'package:shared_preferences/shared_preferences.dart';

import '../repositories.dart';
import '../../models/enrollment.dart';

/// Demo enrollment repository. Simulates POST /api/students/me/enroll
/// (Spring Boot -> Python AI -> ArcFace embeddings stored, enrollment ACTIVE).
class MockEnrollmentRepository implements EnrollmentRepository {
  MockEnrollmentRepository({
    this.latency = const Duration(milliseconds: 1400),
  });

  final Duration latency;

  static const String _kFlagPrefix = 'demo.enrolled.';

  @override
  Future<bool> isEnrolled(String studentId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kFlagPrefix$studentId') ?? false;
  }

  @override
  Future<void> enroll({
    required String studentId,
    required List<EnrollmentCapture> captures,
  }) async {
    if (captures.length != 7) {
      throw AppException('Enrollment requires exactly 7 face captures.');
    }
    // Simulate AI processing time (detect -> align -> embed -> store).
    await Future<void>.delayed(latency);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kFlagPrefix$studentId', true);
  }
}
