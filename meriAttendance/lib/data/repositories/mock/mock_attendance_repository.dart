import 'dart:math' as math;
import 'dart:typed_data';

import '../repositories.dart';
import '../../models/attendance.dart';
import '../../models/user.dart';
import 'demo_data.dart';

/// Demo attendance repository. Simulates:
/// - POST /api/attendance/sessions      -> HTTP 202, session PROCESSING
/// - background AI worker               -> REVIEW payload
/// - PATCH /api/attendance/sessions/{id}/unknown/{faceId} -> mark present
/// - POST /api/attendance/sessions/{id}/confirm -> FINAL
///
/// ONLY used by tests — the active runtime path uses the API repositories.
class MockAttendanceRepository implements AttendanceRepository {
  MockAttendanceRepository({this.latency = const Duration(milliseconds: 900)});

  final Duration latency;

  int _sessionCounter = 0;
  final Map<String, _DemoSession> _sessions = <String, _DemoSession>{};

  @override
  Future<AttendanceSession> createSession({
    required AttendanceSetup setup,
    required DateTime startTime,
    required List<CapturePhoto> photos,
  }) async {
    if (photos.length < 5 || photos.length > 10) {
      throw AppException('A session needs 5 to 10 classroom photos.');
    }
    await Future<void>.delayed(latency);
    _sessionCounter += 1;
    final String sessionId =
        'SES-2025-${_sessionCounter.toString().padLeft(4, '0')}';
    _sessions[sessionId] = _DemoSession.fromRoster();
    return AttendanceSession(
      id: sessionId,
      setup: setup,
      startTime: startTime,
      status: SessionStatus.processing,
    );
  }

  @override
  Future<ReviewData> pollReview({required String sessionId}) async {
    // Simulated background AI processing time (respects test latency).
    await Future<void>.delayed(latency);
    final _DemoSession? session = _sessions[sessionId];
    if (session == null) {
      throw AppException('Session not found.');
    }
    return session.review();
  }

  @override
  Future<ReviewData> resolveUnknown({
    required String sessionId,
    required String faceId,
    required String studentId,
  }) async {
    await Future<void>.delayed(latency);
    final _DemoSession? session = _sessions[sessionId];
    if (session == null) {
      throw AppException('Session not found.');
    }
    session.resolve(faceId, studentId);
    return session.review();
  }

  @override
  Future<ReviewData> confirmSession({required String sessionId}) async {
    await Future<void>.delayed(latency);
    final _DemoSession? session = _sessions[sessionId];
    if (session == null) {
      throw AppException('Session not found.');
    }
    session.finalized = true;
    return session.review();
  }

  @override
  Future<List<SubjectOption>> getSubjects() async {
    await Future<void>.delayed(latency);
    return <SubjectOption>[
      for (int i = 0; i < DemoData.subjects.length; i++)
        SubjectOption(
            id: DemoData.subjectIds[i], name: DemoData.subjects[i]),
    ];
  }

  @override
  Future<List<ClassOption>> getClasses() async {
    await Future<void>.delayed(latency);
    return <ClassOption>[
      for (int i = 0; i < DemoData.classes.length; i++)
        ClassOption(id: DemoData.classIds[i], name: DemoData.classes[i]),
    ];
  }

  @override
  Future<List<RoomOption>> getRooms() async {
    await Future<void>.delayed(latency);
    return <RoomOption>[
      for (int i = 0; i < DemoData.rooms.length; i++)
        RoomOption(id: DemoData.roomIds[i], name: DemoData.rooms[i]),
    ];
  }

  @override
  Future<List<Lecture>> getLectures(DateTime date) async {
    await Future<void>.delayed(latency);
    return DemoData.demoLectures;
  }

  @override
  Future<Uint8List> fetchCrop(String faceId) async {
    throw AppException('Demo mode has no crop images.');
  }
}

/// Mutable demo state for one session, mirroring the backend worker flow.
class _DemoSession {
  _DemoSession(this.present, this.unknown, this.notSeen, this.roster);

  bool finalized = false;

  final List<Student> present;
  final List<UnknownFace> unknown;
  final List<Student> notSeen;
  final List<Student> roster;

  factory _DemoSession.fromRoster() {
    final List<Student> roster = DemoData.roster;
    final List<Student> shuffled = List<Student>.of(roster)
      ..shuffle(math.Random(42));

    final List<Student> present = shuffled.sublist(0, 25);
    final List<Student> notSeen = shuffled.sublist(25);

    final DateTime now = DateTime.now();
    final List<UnknownFace> unknown = List<UnknownFace>.generate(
      3,
      (int i) => UnknownFace(
        id: 'UNK-DEMO-$i',
        photoIdx: i,
        capturedAt: now.subtract(Duration(minutes: 12 - i * 4)),
      ),
    );

    return _DemoSession(present, unknown, notSeen, roster);
  }

  ReviewData review() {
    final Map<String, double> matches = <String, double>{
      for (int i = 0; i < present.length; i++)
        present[i].id:
            88.0 + math.Random(present[i].hashCode).nextDouble() * 10,
    };
    return ReviewData(
      present: List<Student>.of(present),
      unknown: List<UnknownFace>.of(unknown),
      notSeen: List<Student>.of(notSeen),
      matches: matches,
      backendStatus: finalized ? 'FINAL' : 'REVIEW',
    );
  }

  void resolve(String faceId, String studentId) {
    Student? student;
    for (final Student s in roster) {
      if (s.id == studentId) {
        student = s;
        break;
      }
    }
    if (student == null) {
      throw AppException('That student does not belong to this class.');
    }
    for (int i = 0; i < unknown.length; i++) {
      if (unknown[i].id == faceId) {
        unknown[i] = unknown[i].copyWith(
            resolvedStudentId: studentId, resolved: true);
        break;
      }
    }
    notSeen.removeWhere((Student s) => s.id == studentId);
    if (!present.any((Student s) => s.id == studentId)) {
      present.add(student);
    }
  }
}

/// Demo AI match percent helper (stable per student).
double demoMatchPercent(Student student) =>
    88.0 + math.Random(student.id.hashCode).nextDouble() * 10;
