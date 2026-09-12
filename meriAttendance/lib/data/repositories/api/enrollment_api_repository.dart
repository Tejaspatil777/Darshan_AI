import '../../models/enrollment.dart';
import '../repositories.dart';
import '../../../core/network/api_client.dart';

/// Real face-enrollment repository.
///
/// - status .... GET  /api/students/me/enrollment
///               {status: not_started|partial|complete, storedEmbeddings,
///                requiredEmbeddings}
/// - enroll .... POST /api/students/me/enroll
///               {faces: [{pose, quality:{brightness,sharpness,yaw}, image_b64}]}
///               -> {status, embeddingsStored, avgQuality, rejected[]}
///
/// The 7-capture workflow is unchanged; the backend (via the Python AI
/// service) is the only authority for "complete".
class EnrollmentApiRepository implements EnrollmentRepository {
  EnrollmentApiRepository(this._client);

  final ApiClient _client;

  static const int _requiredEmbeddings = 7;

  @override
  Future<bool> isEnrolled(String studentId) async {
    final dynamic data = await _client.get('/api/students/me/enrollment');
    if (data is! Map<String, dynamic>) return false;
    return data['status'] == 'complete';
  }

  @override
  Future<void> enroll({
    required String studentId,
    required List<EnrollmentCapture> captures,
  }) async {
    if (captures.length != _requiredEmbeddings) {
      throw AppException(
          'Enrollment requires exactly $_requiredEmbeddings face captures.');
    }
    for (final EnrollmentCapture capture in captures) {
      if (capture.imageB64.isEmpty) {
        throw AppException(
            'A face capture is missing its image. Please grant camera '
            'permission and retake the captures.');
      }
    }

    final dynamic data = await _client.post(
      '/api/students/me/enroll',
      body: <String, dynamic>{
        'faces': <Map<String, dynamic>>[
          for (final EnrollmentCapture c in captures) c.toApiJson(),
        ],
      },
    );
    if (data is! Map<String, dynamic>) {
      throw AppException('The server returned an unexpected enrollment response.');
    }

    final String status = data['status'] as String? ?? '';
    if (status != 'complete') {
      // Backend rejected some captures or stored < 7 embeddings.
      // Never fake success — surface the real reasons.
      final List<dynamic> rejected = (data['rejected'] as List<dynamic>?) ?? <dynamic>[];
      final String reasons = rejected
          .map((dynamic r) => r is Map<String, dynamic>
              ? '${r['pose'] ?? 'capture'}: ${r['reason'] ?? 'rejected'}'
              : '$r')
          .join(' · ');
      throw AppException(
        reasons.isNotEmpty
            ? 'Some captures were rejected by the AI check — $reasons. '
                'Please retake your captures.'
            : 'Enrollment incomplete (${data['embeddingsStored'] ?? 0} '
                'of $_requiredEmbeddings stored). Please retake your captures.',
      );
    }
  }
}
