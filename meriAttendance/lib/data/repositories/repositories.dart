import 'dart:typed_data';

import '../models/attendance.dart';
import '../models/enrollment.dart';
import '../models/user.dart';

/// Friendly exception carrying a human-readable message for the UI.
/// [ApiError] (core/network/api_client.dart) extends this with status/code.
class AppException implements Exception {
  AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Authentication seam — real implementation hits the Spring Boot API:
/// POST /api/auth/login, POST /api/auth/first-login, POST /api/auth/refresh,
/// POST /api/auth/logout, PUT /api/auth/password.
abstract class AuthRepository {
  Future<AppUser> login({
    required String username,
    required String password,
  });

  /// POST /api/auth/first-login with the JWT from login. The backend returns
  /// a fresh token pair; no re-login and no ID re-entry happens.
  Future<AppUser> completeFirstLogin({required String newPassword});

  /// PUT /api/auth/password (authenticated). The backend revokes all
  /// sessions on change; callers keep the user signed in locally.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> logout();

  /// Tokens are persisted by the API repository itself (TokenStore); this
  /// hook exists for repositories that keep extra session state.
  Future<void> saveSession(AppUser user);

  /// Restores a session from the TokenStore, validating it against
  /// GET /api/users/me. Returns null when no valid session exists.
  Future<AppUser?> restoreSession();
}

/// Profile seam — GET /api/users/me (role-aware enriched profile).
abstract class StudentRepository {
  Future<Student> getStudentProfile(String userId);
}

/// Profile seam — GET /api/users/me (role-aware enriched profile).
abstract class FacultyRepository {
  Future<Faculty> getFacultyProfile(String userId);
}

/// Face enrollment seam:
/// - isEnrolled -> GET  /api/students/me/enrollment
/// - enroll     -> POST /api/students/me/enroll (7 faces -> Python AI via
///                 Spring Boot; "complete" is only reported by the backend).
abstract class EnrollmentRepository {
  Future<bool> isEnrolled(String studentId);

  Future<void> enroll({
    required String studentId,
    required List<EnrollmentCapture> captures,
  });
}

/// Attendance seam:
/// - createSession   -> POST /api/attendance/sessions (multipart, HTTP 202)
/// - pollReview      -> GET  /api/attendance/sessions/{id} (PROCESSING..REVIEW)
/// - resolveUnknown  -> PATCH /api/attendance/sessions/{id}/unknown/{faceId}
/// - confirmSession  -> POST /api/attendance/sessions/{id}/confirm (FINAL)
/// - getSubjects     -> GET  /api/faculty/me/subjects (own dept + global)
/// - getClasses      -> GET  /api/faculty/me/classes  (own dept only)
/// - getRooms        -> GET  /api/faculty/me/rooms    (shared resource)
/// - getLectures     -> GET  /api/faculty/me/lectures?date=YYYY-MM-DD
///                      (optional reference info only — NEVER gates setup)
/// - fetchCrop       -> GET  /api/crops/{faceId} (unknown-face image bytes)
abstract class AttendanceRepository {
  Future<AttendanceSession> createSession({
    required AttendanceSetup setup,
    required DateTime startTime,
    required List<CapturePhoto> photos,
  });

  Future<ReviewData> pollReview({required String sessionId});

  Future<ReviewData> resolveUnknown({
    required String sessionId,
    required String faceId,
    required String studentId,
  });

  Future<ReviewData> confirmSession({required String sessionId});

  Future<List<SubjectOption>> getSubjects();

  Future<List<ClassOption>> getClasses();

  Future<List<RoomOption>> getRooms();

  Future<List<Lecture>> getLectures(DateTime date);

  Future<Uint8List> fetchCrop(String faceId);
}

