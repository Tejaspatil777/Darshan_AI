import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/attendance.dart';
import '../data/models/user.dart' show Student;
import '../data/repositories/repositories.dart';
import 'auth_provider.dart';

/// Drives the faculty attendance workflow against the real backend:
/// Date + Subject + Class + Room setup (independent catalog picks — the
/// admin timetable is optional reference info only, NEVER a prerequisite)
/// -> 5-10 classroom captures -> multipart create (HTTP 202, PROCESSING)
/// -> polling -> review (present / unknown / not seen) -> unknown
/// resolution (PATCH) -> confirm (FINAL).
class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._repo, this._auth) {
    _auth.addListener(_onAuthChanged);
  }

  final AttendanceRepository _repo;
  final AuthProvider _auth;
  Timer? _pollTimer;

  /// Injected by the photo-capture screen when a real camera is available:
  /// takes one classroom photo and returns its JPEG bytes.
  Future<Uint8List> Function()? photoSource;

  bool _disposed = false;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // --- Setup ---------------------------------------------------------------
  String? _department;
  String? branch;
  String? subject;
  String? className;
  String? mode;
  String? room;
  DateTime? date;

  /// Real backend UUID for each pick (from the faculty catalog
  /// GET /api/faculty/me/subjects|classes|rooms) — these are what get
  /// submitted; display names never leave the device.
  String? subjectId;
  String? clsId;
  String? roomId;

  /// Independent catalog options (faculty-scoped server-side: own-dept
  /// subjects+classes, shared rooms). The selected DATE only becomes the
  /// attendance_date — it never gates these lists.
  List<SubjectOption> subjectCatalog = <SubjectOption>[];
  List<ClassOption> classCatalog = <ClassOption>[];
  List<RoomOption> roomCatalog = <RoomOption>[];
  bool loadingCatalog = false;
  String? catalogError;

  /// Lectures scheduled for the selected date (GET /api/faculty/me/lectures)
  /// — optional reference info only. A missing timetable entry NEVER blocks
  /// setup: the faculty catalog above is the source of subjects/classes/rooms.
  List<Lecture> lectures = <Lecture>[];
  bool loadingLectures = false;
  String? lecturesError;

  // --- Capture -------------------------------------------------------------
  final List<CapturePhoto> photos = <CapturePhoto>[];
  DateTime? startTime; // stamped when the FIRST photo is captured
  int _photoId = 0;
  bool _takingPhoto = false;

  static const int minPhotos = 5;
  static const int maxPhotos = 10;
  static const List<String> captureAreas = <String>[
    'Front rows',
    'Middle rows',
    'Back rows',
    'Left side',
    'Right side',
  ];

  // --- Processing / review -------------------------------------------------
  SessionStatus status = SessionStatus.idle;
  AttendanceSession? session;
  int processingStep = 0;
  bool confirming = false;
  String? errorMessage;

  List<Student> present = <Student>[];
  List<UnknownFace> unknownFaces = <UnknownFace>[];
  List<Student> notSeen = <Student>[];
  List<Student> roster = <Student>[];
  Map<String, double> matches = <String, double>{};

  /// Unknown-face crop image cache (fetched via GET /api/crops/{faceId}).
  final Map<String, Uint8List> _cropCache = <String, Uint8List>{};

  String? get department => _department;

  /// The timetable entry matching the current subject/class/room picks, if
  /// any — used ONLY to forward `lecture_slot` when one happens to exist.
  /// Missing timetable entries never block setup.
  Lecture? get selectedLecture {
    for (final Lecture lecture in lectures) {
      if (lecture.subjectName == subject &&
          lecture.className == className &&
          lecture.roomName == room) {
        return lecture;
      }
    }
    return null;
  }

  bool get setupComplete =>
      branch != null &&
      subject != null &&
      subjectId != null &&
      className != null &&
      clsId != null &&
      mode != null &&
      room != null &&
      roomId != null &&
      date != null;

  String get nextArea => captureAreas[photos.length % captureAreas.length];

  bool get canSubmit =>
      photos.length >= minPhotos && photos.length <= maxPhotos;

  int get unknownRemaining =>
      unknownFaces.where((UnknownFace f) => !f.resolved).length;

  bool get canConfirm =>
      status == SessionStatus.review && unknownRemaining == 0 && !confirming;

  /// Dropdown display names backed by the independent faculty catalog.
  /// Unlike the timetable `lectures` (date-scoped reference only), these
  /// never go empty just because the admin scheduled nothing for the day.
  List<String> get subjectOptions => <String>{
        for (final SubjectOption s in subjectCatalog) s.name,
        // Fallback while the catalog is still loading / in mock-only tests.
        for (final Lecture l in lectures) l.subjectName,
      }.toList()
        ..sort();

  List<String> get classOptions {
    final Iterable<String> names = subject == null
        ? <String>[
            for (final ClassOption c in classCatalog) c.name,
            for (final Lecture l in lectures) l.className,
          ]
        : <String>[
            for (final Lecture l in lectures)
              if (l.subjectName == subject) l.className,
            // Catalog classes have no subject link client-side; when lectures
            // are absent, still offer the whole catalog instead of nothing.
            if (lectures.isEmpty)
              for (final ClassOption c in classCatalog) c.name,
          ];
    return <String>{...names}.toList()..sort();
  }

  List<String> get roomOptions {
    if (subject != null && className != null && lectures.isNotEmpty) {
      return <String>{
        for (final Lecture l in lectures)
          if (l.subjectName == subject && l.className == className) l.roomName,
      }.toList()
        ..sort();
    }
    return <String>{
      for (final RoomOption r in roomCatalog) r.name,
      for (final Lecture l in lectures) l.roomName,
    }.toList()
      ..sort();
  }

  /// Unfiltered class list (used when Class is picked before a Subject).
  List<String> get allClassOptions => <String>{
        for (final ClassOption c in classCatalog) c.name,
        for (final Lecture l in lectures) l.className,
      }.toList()
        ..sort();

  /// Unfiltered room list (used when Room is picked before Subject/Class).
  List<String> get allRoomOptions => <String>{
        for (final RoomOption r in roomCatalog) r.name,
        for (final Lecture l in lectures) l.roomName,
      }.toList()
        ..sort();

  /// Class picked before a Subject: auto-resolves the subject when the
  /// chosen class belongs to exactly one authorized lecture subject.
  void pickClass(String value) {
    if (subject == null) {
      final Set<String> subjects = <String>{
        for (final Lecture l in lectures)
          if (l.className == value) l.subjectName,
      };
      if (subjects.length == 1) subject = subjects.first;
    }
    className = value;
    _syncIdsFromCatalog();
    room = null;
    roomId = null;
    _safeNotify();
  }

  /// Room picked before Subject/Class: auto-resolves each missing level
  /// when the chosen room maps to exactly one lecture subject (and class).
  void pickRoom(String value) {
    final List<Lecture> matches = <Lecture>[
      for (final Lecture l in lectures)
        if (l.roomName == value) l,
    ];
    if (subject == null) {
      final Set<String> subjects = <String>{
        for (final Lecture l in matches) l.subjectName,
      };
      if (subjects.length == 1) subject = subjects.first;
    }
    if (className == null) {
      final Set<String> classes = <String>{
        for (final Lecture l in matches)
          if (subject == null || l.subjectName == subject) l.className,
      };
      if (classes.length == 1) className = classes.first;
    }
    room = value;
    _syncIdsFromCatalog();
    _safeNotify();
  }

  void _onAuthChanged() {
    if (_auth.user == null) reset();
  }

  /// Locks the department from the signed-in faculty account and loads both
  /// the independent faculty catalog (subjects/classes/rooms) and the
  /// date-scoped lectures (optional reference only).
  Future<void> initSetup() async {
    if (_department == null && _auth.facultyProfile?.department != null) {
      _department = _auth.facultyProfile!.department;
    }
    branch ??= _department;
    // Default the date to today so the Date tile reflects what was actually
    // loaded and setupComplete does not demand a redundant date pick.
    date ??= _startOfDay(DateTime.now());
    await loadCatalog();
    await loadLectures();
    _syncIdsFromCatalog();
    _safeNotify();
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// GET /api/faculty/me/subjects|classes|rooms — the independent catalog
  /// that backs every setup dropdown (never gated by the timetable date).
  Future<void> loadCatalog() async {
    if (loadingCatalog) return;
    loadingCatalog = true;
    catalogError = null;
    _safeNotify();
    try {
      final List<SubjectOption> subjects = await _repo.getSubjects();
      final List<ClassOption> classes = await _repo.getClasses();
      final List<RoomOption> rooms = await _repo.getRooms();
      subjectCatalog = subjects;
      classCatalog = classes;
      roomCatalog = rooms;
      _syncIdsFromCatalog();
    } on AppException catch (e) {
      catalogError = e.message;
    }
    loadingCatalog = false;
    _safeNotify();
  }

  /// Resolves the backend UUID for every display-name pick from the loaded
  /// catalog (plus the lecture list as fallback in mock-only tests), so
  /// `setupComplete`/`buildSetup` never demand a hidden timetable match.
  void _syncIdsFromCatalog() {
    if (subject != null && subjectId == null) {
      for (final SubjectOption s in subjectCatalog) {
        if (s.name == subject) {
          subjectId = s.id;
          break;
        }
      }
      if (subjectId == null) {
        for (final Lecture l in lectures) {
          if (l.subjectName == subject) {
            subjectId = l.subjectId;
            break;
          }
        }
      }
    }
    if (className != null && clsId == null) {
      for (final ClassOption c in classCatalog) {
        if (c.name == className) {
          clsId = c.id;
          break;
        }
      }
      if (clsId == null) {
        for (final Lecture l in lectures) {
          if (l.className == className) {
            clsId = l.clsId;
            break;
          }
        }
      }
    }
    if (room != null && roomId == null) {
      for (final RoomOption r in roomCatalog) {
        if (r.name == room) {
          roomId = r.id;
          break;
        }
      }
      if (roomId == null) {
        for (final Lecture l in lectures) {
          if (l.roomName == room) {
            roomId = l.roomId;
            break;
          }
        }
      }
    }
  }

  /// GET /api/faculty/me/lectures for the selected date.
  Future<void> loadLectures() async {
    if (loadingLectures) return;
    loadingLectures = true;
    lecturesError = null;
    _safeNotify();
    try {
      lectures = await _repo.getLectures(date ?? DateTime.now());
      _syncIdsFromCatalog();
    } on AppException catch (e) {
      lectures = <Lecture>[];
      lecturesError = e.message;
    }
    loadingLectures = false;
    _safeNotify();
  }

  /// Date change reloads the authorized lectures. Catalog picks are kept:
  /// the timetable is reference info only and never invalidates the setup.
  Future<void> setDate(DateTime value) async {
    date = value;
    _safeNotify();
    await loadLectures();
    _safeNotify();
  }

  void selectBranch(String value) {
    branch = value;
    _safeNotify();
  }

  void selectMode(String value) {
    mode = value;
    _safeNotify();
  }

  void selectSubject(String value) {
    subject = value;
    subjectId = null;
    className = null;
    clsId = null;
    room = null;
    roomId = null;
    _syncIdsFromCatalog();
    _safeNotify();
  }

  void selectClass(String value) {
    className = value;
    clsId = null;
    room = null;
    roomId = null;
    _syncIdsFromCatalog();
    _safeNotify();
  }

  void selectRoom(String value) {
    room = value;
    roomId = null;
    _syncIdsFromCatalog();
    _safeNotify();
  }

  AttendanceSetup buildSetup() {
    _syncIdsFromCatalog();
    if (subject == null || className == null || room == null || date == null) {
      throw AppException(
          'Select a subject, class and room from your lectures.');
    }
    if (subjectId == null || clsId == null || roomId == null) {
      throw AppException(
          'Select a subject, class and room from your lectures.');
    }
    final Lecture? lecture = selectedLecture;
    return AttendanceSetup(
      department: _department ?? '',
      branch: branch,
      subject: subject!,
      className: className!,
      mode: mode!,
      room: room!,
      date: date!,
      clsId: clsId,
      subjectId: subjectId,
      roomId: roomId,
      lectureSlot: lecture?.lectureSlot,
    );
  }


  // ------------------------------------------------------------- capturing

  /// Captures one classroom photo.
  ///
  /// Without a camera source (tests / no permission) this appends a
  /// placeholder capture synchronously and returns true.
  /// With a real camera the JPEG bytes are taken asynchronously and stored
  /// on the CapturePhoto for the multipart upload; if the camera fails, no
  /// fake photo is appended — the user can simply tap again.
  bool addPhoto() {
    if (photos.length >= maxPhotos || _takingPhoto) return false;
    final Future<Uint8List> Function()? source = photoSource;
    if (source == null) {
      _appendPhoto(null);
      return true;
    }
    _takingPhoto = true;
    _safeNotify();
    () async {
      Uint8List? bytes;
      try {
        bytes = await source();
      } catch (_) {
        bytes = null; // no fake photo on camera failure
      }
      _takingPhoto = false;
      if (bytes != null) _appendPhoto(bytes);
      _safeNotify();
    }();
    return true;
  }

  void _appendPhoto(Uint8List? bytes) {
    if (photos.isEmpty) startTime = DateTime.now();
    _photoId += 1;
    photos.add(CapturePhoto(
      id: 'photo-$_photoId',
      areaLabel: nextArea,
      takenAt: DateTime.now(),
      seed: _photoId,
      bytes: bytes,
    ));
    _safeNotify();
  }

  void deletePhoto(String id) {
    photos.removeWhere((CapturePhoto p) => p.id == id);
    if (photos.isEmpty) startTime = null;
    _safeNotify();
  }

  void deleteLast() {
    if (photos.isNotEmpty) deletePhoto(photos.last.id);
  }

  /// Deletes the last shot and immediately captures a new one.
  void retakeLast() {
    if (photos.isEmpty) return;
    deletePhoto(photos.last.id);
    addPhoto();
  }

  // ------------------------------------------------- processing + polling

  /// Creates the real session (multipart POST -> HTTP 202) and polls
  /// GET /api/attendance/sessions/{id} until REVIEW / FINAL / FAILED.
  /// HTTP 202 only means "accepted" — never that attendance is complete.
  Future<void> runProcessing() async {
    if (status != SessionStatus.idle || !canSubmit) return;
    status = SessionStatus.processing;
    errorMessage = null;
    processingStep = 0;
    _safeNotify();

    final AttendanceSetup setup = buildSetup();
    final DateTime start = startTime ?? DateTime.now();

    try {
      session = await _repo.createSession(
        setup: setup,
        startTime: start,
        photos: List<CapturePhoto>.of(photos),
      );
    } on AppException catch (e) {
      status = SessionStatus.failed;
      errorMessage = e.message;
      _safeNotify();
      return;
    }

    // Photos are uploaded; the backend worker (AiClient -> Python AI) runs now.
    processingStep = 1;
    _safeNotify();
    await _pollUntilReview();
  }

  /// Resumes polling after a transient failure/timeout on the same session.
  Future<void> resumeProcessing() async {
    if (session == null) return runProcessing();
    status = SessionStatus.processing;
    errorMessage = null;
    _safeNotify();
    await _pollUntilReview();
  }

  Future<void> _pollUntilReview() async {
    final String sessionId = session!.id;
    final DateTime deadline = DateTime.now().add(const Duration(minutes: 3));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final ReviewData result =
            await _repo.pollReview(sessionId: sessionId).timeout(
                  const Duration(seconds: 20),
                );
        final String backendStatus = result.backendStatus ?? 'PROCESSING';
        if (backendStatus == 'REVIEW' || backendStatus == 'FINAL') {
          _applyReview(result);
          return;
        }
        if (backendStatus == 'FAILED') {
          status = SessionStatus.failed;
          errorMessage = result.warnings.isNotEmpty
              ? result.warnings.join(' · ')
              : 'The attendance session failed to process. Please try again.';
          _safeNotify();
          return;
        }
        // Still PROCESSING — the timeline shows real progress only.
        processingStep = 2;
        _safeNotify();
      } on AppException catch (e) {
        status = SessionStatus.failed;
        errorMessage = e.message;
        _safeNotify();
        return;
      } on TimeoutException {
        status = SessionStatus.failed;
        errorMessage =
            'The server is slow to respond. You can retry the review.';
        _safeNotify();
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    status = SessionStatus.failed;
    errorMessage =
        'Processing is taking longer than expected. You can retry the review.';
    _safeNotify();
  }
  void _applyReview(ReviewData result) {
    present = result.present;
    unknownFaces = result.unknown;
    notSeen = result.notSeen;
    matches = result.matches;
    roster = <Student>[...result.present, ...result.notSeen];
    session = AttendanceSession(
      id: session!.id,
      setup: session!.setup,
      startTime: session!.startTime,
      status: SessionStatus.review,
      review: result,
    );
    status = SessionStatus.review;
    _safeNotify();
  }

  // ---------------------------------------------------- unknown resolution

  /// PATCH /api/attendance/sessions/{id}/unknown/{faceId} with
  /// {studentId, action: "mark_present"}. The selection is validated against
  /// the class roster first; the refreshed review comes from the backend.
  Future<void> resolveUnknown(String unknownId, String studentId) async {
    bool inRoster = false;
    for (final Student s in roster) {
      if (s.id == studentId) {
        inRoster = true;
        break;
      }
    }
    if (!inRoster) {
      throw AppException('That student does not belong to this class.');
    }
    if (session == null) {
      throw AppException('No attendance session is open.');
    }
    final ReviewData result = await _repo.resolveUnknown(
      sessionId: session!.id,
      faceId: unknownId,
      studentId: studentId,
    );
    _applyReview(result);
  }

  // -------------------------------------------------- manual faculty marking

  /// Faculty authority: manually mark a not-seen roster student as present.
  ///
  /// The current backend review flow only persists unknown-face resolutions
  /// (PATCH .../unknown/{faceId}); there is deliberately no roster-level
  /// mark-present endpoint yet. Until such an endpoint exists this keeps the
  /// correction LOCAL to the review screen (present/notSeen lists + match
  /// map) so faculty can still fix obvious AI misses, while `confirm()` only
  /// sends the backend-supported REVIEW -> FINAL transition plus the queued
  /// unknown-face resolutions (never invented server state).
  void markPresentManually(String studentId) {
    final int idx = notSeen.indexWhere((Student s) => s.id == studentId);
    if (idx == -1) {
      throw AppException('That student does not belong to this class.');
    }
    final Student student = notSeen.removeAt(idx);
    if (!present.any((Student s) => s.id == studentId)) {
      present.add(student);
    }
    matches.remove(studentId);
    _safeNotify();
  }

  /// Faculty authority: mark a present student absent. See the note above.
  void markAbsentManually(String studentId) {
    final int idx = present.indexWhere((Student s) => s.id == studentId);
    if (idx == -1) {
      throw AppException('That student does not belong to this class.');
    }
    final Student student = present.removeAt(idx);
    matches.remove(studentId);
    if (!notSeen.any((Student s) => s.id == studentId)) {
      notSeen.add(student);
    }
    _safeNotify();
  }

  Student? resolvedStudentOf(UnknownFace face) {
    if (face.resolvedStudentId == null) return null;
    for (final Student s in roster) {
      if (s.id == face.resolvedStudentId) return s;
    }
    return null;
  }

  /// AI match percent for a present student (backend similarity), or null
  /// when the student was marked present manually.
  double? matchPercentFor(Student student) => matches[student.id];

  /// Loads the real unknown-face crop image (GET /api/crops/{faceId}),
  /// cached per face for the identification sheet.
  Future<Uint8List?> cropFor(UnknownFace face) async {
    final Uint8List? cached = _cropCache[face.id];
    if (cached != null) return cached;
    try {
      final Uint8List bytes = await _repo.fetchCrop(face.id);
      _cropCache[face.id] = bytes;
      return bytes;
    } on AppException {
      return null; // the sheet keeps its placeholder on failure
    }
  }

  // ---------------------------------------------------------------- confirm

  /// POST /api/attendance/sessions/{id}/confirm. Only the backend can move
  /// REVIEW -> FINAL; "Session Complete" is shown after that confirmation.
  Future<void> confirm() async {
    if (!canConfirm) return;
    confirming = true;
    _safeNotify();
    try {
      final ReviewData result =
          await _repo.confirmSession(sessionId: session!.id);
      session = AttendanceSession(
        id: session!.id,
        setup: session!.setup,
        startTime: session!.startTime,
        status: SessionStatus.completed,
        review: result,
      );
      status = SessionStatus.completed;
    } on AppException {
      confirming = false;
      _safeNotify();
      rethrow; // the review screen shows the real error; session stays REVIEW
    }
    confirming = false;
    _safeNotify();
  }

  void reset() {
    _pollTimer?.cancel();
    _department = null;
    branch = null;
    subject = null;
    className = null;
    mode = null;
    room = null;
    date = null;
    subjectId = null;
    clsId = null;
    roomId = null;
    subjectCatalog = <SubjectOption>[];
    classCatalog = <ClassOption>[];
    roomCatalog = <RoomOption>[];
    loadingCatalog = false;
    catalogError = null;
    lectures = <Lecture>[];
    loadingLectures = false;
    lecturesError = null;
    photos.clear();
    startTime = null;
    _photoId = 0;
    _takingPhoto = false;
    status = SessionStatus.idle;
    session = null;
    processingStep = 0;
    confirming = false;
    errorMessage = null;
    present = <Student>[];
    unknownFaces = <UnknownFace>[];
    notSeen = <Student>[];
    roster = <Student>[];
    matches = <String, double>{};
    _cropCache.clear();
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
