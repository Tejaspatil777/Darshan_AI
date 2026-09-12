import 'dart:typed_data';

import 'user.dart';

/// Lifecycle of an attendance session (mirrors the backend workflow:
/// PROCESSING -> REVIEW -> FINAL, or PROCESSING -> FAILED).
enum SessionStatus { idle, processing, review, completed, failed }

/// One classroom capture. [bytes] carries the real JPEG when a camera is
/// available; it is null only in offline/test simulation mode.
class CapturePhoto {
  const CapturePhoto({
    required this.id,
    required this.areaLabel,
    required this.takenAt,
    required this.seed,
    this.bytes,
  });

  final String id;
  final String areaLabel;
  final DateTime takenAt;
  final int seed;
  final Uint8List? bytes;
}

/// A face the AI detected but could not confidently identify.
/// Mirrors the backend `UnknownFace` DTO
/// (faceId, photoIdx, thumbnail path, similarity, resolved, resolvedStudentId).
class UnknownFace {
  const UnknownFace({
    required this.id,
    this.photoIdx,
    this.thumbnail,
    this.similarity,
    this.capturedAt,
    this.resolvedStudentId,
    this.resolved = false,
  });

  final String id;
  final int? photoIdx;

  /// Backend crop path, e.g. `/api/crops/{faceId}` (auth-gated image bytes).
  final String? thumbnail;
  final double? similarity;
  final DateTime? capturedAt; // not provided by the backend
  final String? resolvedStudentId;

  final bool resolved;

  UnknownFace copyWith({String? resolvedStudentId, bool? resolved}) =>
      UnknownFace(
        id: id,
        photoIdx: photoIdx,
        thumbnail: thumbnail,
        similarity: similarity,
        capturedAt: capturedAt,
        resolvedStudentId: resolvedStudentId ?? this.resolvedStudentId,
        resolved: resolved ?? this.resolved,
      );
}

/// Real catalog option backed by a backend master record (always carries
/// the real UUID that gets submitted — never a display name).
class SubjectOption {
  const SubjectOption({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;
}

/// A faculty lecture for a given day (backend `LectureResponse`):
/// optional reference info for the setup screen — NEVER a prerequisite.
/// Subjects / classes / rooms always come from the faculty catalog
/// (GET /api/faculty/me/subjects|classes|rooms).
class Lecture {
  const Lecture({
    required this.assignmentId,
    required this.clsId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.roomId,
    required this.roomName,
    this.lectureSlot,
    this.date,
  });

  final String assignmentId;
  final String clsId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String roomId;
  final String roomName;
  final int? lectureSlot;
  final String? date;
}

/// Real catalog option backed by a backend master record (always carries
/// the real UUID that gets submitted — never a display name).
class ClassOption {
  const ClassOption({
    required this.id,
    required this.name,
    this.semester,
    this.year,
    this.batch,
  });

  final String id;
  final String name;
  final int? semester;
  final int? year;
  final String? batch;
}

/// Real catalog option backed by a backend master record (always carries
/// the real UUID that gets submitted — never a display name).
class RoomOption {
  const RoomOption({required this.id, required this.name, this.building});

  final String id;
  final String name;
  final String? building;
}

/// Selections made on the attendance-setup screen. Display names drive the
/// UI; the UUIDs (from the faculty catalog GET /api/faculty/me/...) are
/// what gets submitted. The date is the attendance date only — it never
/// gates which subjects, classes or rooms can be picked.
class AttendanceSetup {
  const AttendanceSetup({
    required this.department,
    this.branch,
    required this.subject,
    required this.className,
    required this.mode,
    required this.room,
    required this.date,
    this.clsId,
    this.subjectId,
    this.roomId,
    this.lectureSlot,
  });

  final String department; // locked, from faculty account
  final String? branch;
  final String subject;
  final String className;
  final String mode; // Lecture / Lab (display only — backend has no mode)
  final String room;
  final DateTime date;

  final String? clsId; // backend UUID
  final String? subjectId; // backend UUID
  final String? roomId; // backend UUID
  final int? lectureSlot;
}

/// Real AI review payload (backend `SessionResultResponse`).
class ReviewData {
  const ReviewData({
    required this.present,
    required this.unknown,
    required this.notSeen,
    required this.matches,
    this.warnings = const <String>[],
    this.backendStatus,
  });

  final List<Student> present;
  final List<UnknownFace> unknown;
  final List<Student> notSeen;

  /// studentId -> AI match percent (backend similarity; null when matched
  /// manually by faculty).
  final Map<String, double> matches;
  final List<String> warnings;

  /// Raw backend status for the session (PROCESSING / REVIEW / FINAL / FAILED).
  final String? backendStatus;
}

/// An attendance session.
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.setup,
    required this.startTime,
    required this.status,
    this.review,
  });

  final String id;
  final AttendanceSetup setup;
  final DateTime startTime; // captured when the FIRST photo was taken
  final SessionStatus status;
  final ReviewData? review;
}

