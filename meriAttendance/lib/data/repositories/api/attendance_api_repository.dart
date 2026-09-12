import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/attendance.dart';
import '../../models/user.dart';
import '../repositories.dart';
import '../../../core/network/api_client.dart';

/// Real attendance repository backed by the Spring Boot API.
///
/// Architecture (never violated): Flutter -> Spring Boot -> Python AI.
/// The AI service is never called directly from Flutter.
class AttendanceApiRepository implements AttendanceRepository {
  AttendanceApiRepository(this._client);

  final ApiClient _client;

  // ------------------------------------------------- create session (202)

  @override
  Future<AttendanceSession> createSession({
    required AttendanceSetup setup,
    required DateTime startTime,
    required List<CapturePhoto> photos,
  }) async {
    final String? clsId = setup.clsId;
    final String? subjectId = setup.subjectId;
    final String? roomId = setup.roomId;
    if (clsId == null || subjectId == null || roomId == null) {
      throw AppException(
          'Select a subject, class and room to continue.');
    }
    if (photos.length < 5 || photos.length > 10) {
      throw AppException('A session needs 5 to 10 classroom photos.');
    }

    final List<http.MultipartFile> files = <http.MultipartFile>[];
    for (int i = 0; i < photos.length; i++) {
      final CapturePhoto photo = photos[i];
      if (photo.bytes == null || photo.bytes!.isEmpty) {
        throw AppException(
            'One of the classroom photos is missing. Please retake it.');
      }
      files.add(http.MultipartFile.fromBytes(
        'photos', // exact multipart field name from AttendanceSessionController
        photo.bytes!,
        filename: 'photo_$i.jpg',
      ));
    }

    final Map<String, String> fields = <String, String>{
      'cls_id': clsId, // backend UUIDs only — never display names
      'subject_id': subjectId,
      'room_id': roomId,
      if (setup.lectureSlot != null) 'lecture_slot': '${setup.lectureSlot}',
      'date': _isoDate(setup.date),
    };

    // HTTP 202 Accepted: processing is asynchronous; the returned session
    // status is PROCESSING — it does NOT mean attendance is done.
    final dynamic data = await _client.postMultipart(
      '/api/attendance/sessions',
      fields: fields,
      files: files,
    );
    if (data is! Map<String, dynamic> || data['sessionId'] == null) {
      throw AppException('The server did not accept the attendance session.');
    }

    final String sessionId = data['sessionId'].toString();
    final List<String> rejected = <String>[
      for (final dynamic r
          in (data['photosRejected'] as List<dynamic>? ?? <dynamic>[]))
        '$r',
    ];

    return AttendanceSession(
      id: sessionId,
      setup: setup,
      startTime: startTime,
      status: SessionStatus.processing,
      review: rejected.isEmpty
          ? null
          : ReviewData(
              present: const <Student>[],
              unknown: const <UnknownFace>[],
              notSeen: const <Student>[],
              matches: const <String, double>{},
              warnings: rejected, // non-fatal: >= 5 usable photos accepted
            ),
    );
  }

  // --------------------------------------------------------------- polling

  @override
  Future<ReviewData> pollReview({required String sessionId}) async {
    final dynamic data =
        await _client.get('/api/attendance/sessions/$sessionId');
    if (data is! Map<String, dynamic>) {
      throw AppException('The server returned an unexpected session response.');
    }
    return _resultFromJson(data);
  }

  // ---------------------------------------------------- unknown resolution

  @override
  Future<ReviewData> resolveUnknown({
    required String sessionId,
    required String faceId,
    required String studentId,
  }) async {
    final dynamic data = await _client.patch(
      '/api/attendance/sessions/$sessionId/unknown/$faceId',
      body: <String, dynamic>{
        'studentId': studentId,
        'action': 'mark_present', // the only action the backend supports
      },
    );
    if (data is! Map<String, dynamic>) {
      throw AppException('The server returned an unexpected session response.');
    }
    return _resultFromJson(data);
  }

  // ---------------------------------------------------------------- confirm

  @override
  Future<ReviewData> confirmSession({required String sessionId}) async {
    final dynamic data =
        await _client.post('/api/attendance/sessions/$sessionId/confirm');
    if (data is! Map<String, dynamic>) {
      throw AppException('The server returned an unexpected session response.');
    }
    final ReviewData result = _resultFromJson(data);
    if (result.backendStatus != 'FINAL') {
      // The backend remains the authority for REVIEW -> FINAL. Do not
      // locally mark a session FINAL when it is not.
      throw AppException(
          'The session could not be finalized (status: '
          '${result.backendStatus ?? 'unknown'}).');
    }
    return result;
  }

  // ------------------------------------------------------ faculty lectures

  // ------------------------------------------------------- faculty catalog

  /// GET /api/faculty/me/subjects — own department + institution-wide
  /// subjects (dept-scoped server-side from the JWT; never other depts).
  @override
  Future<List<SubjectOption>> getSubjects() async {
    final dynamic data = await _client.get('/api/faculty/me/subjects');
    if (data is! List<dynamic>) return const <SubjectOption>[];
    return <SubjectOption>[
      for (final dynamic item in data)
        if (item is Map<String, dynamic>)
          SubjectOption(
            id: '${item['subjectId']}',
            name: item['name'] as String? ?? 'Subject',
            code: item['code'] as String?,
          ),
    ];
  }

  /// GET /api/faculty/me/classes — own-department classes only.
  @override
  Future<List<ClassOption>> getClasses() async {
    final dynamic data = await _client.get('/api/faculty/me/classes');
    if (data is! List<dynamic>) return const <ClassOption>[];
    return <ClassOption>[
      for (final dynamic item in data)
        if (item is Map<String, dynamic>)
          ClassOption(
            id: '${item['clsId']}',
            name: item['name'] as String? ?? 'Class',
            semester: item['semester'] is int ? item['semester'] as int : null,
            year: item['year'] is int ? item['year'] as int : null,
            batch: item['batch'] as String?,
          ),
    ];
  }

  /// GET /api/faculty/me/rooms — rooms are a shared institutional resource
  /// (no department in the schema), so the full list is correct here.
  @override
  Future<List<RoomOption>> getRooms() async {
    final dynamic data = await _client.get('/api/faculty/me/rooms');
    if (data is! List<dynamic>) return const <RoomOption>[];
    return <RoomOption>[
      for (final dynamic item in data)
        if (item is Map<String, dynamic>)
          RoomOption(
            id: '${item['roomId']}',
            name: item['name'] as String? ?? 'Room',
            building: item['building'] as String?,
          ),
    ];
  }

  @override
  Future<List<Lecture>> getLectures(DateTime date) async {
    final dynamic data = await _client.get(
      '/api/faculty/me/lectures',
      query: <String, String>{'date': _isoDate(date)},
    );
    if (data is! List<dynamic>) return <Lecture>[];
    return <Lecture>[
      for (final dynamic item in data)
        if (item is Map<String, dynamic>)
          Lecture(
            assignmentId: '${item['assignmentId']}',
            clsId: '${item['clsId']}',
            className: item['className'] as String? ?? '',
            subjectId: '${item['subjectId']}',
            subjectName: item['subjectName'] as String? ?? '',
            roomId: '${item['roomId']}',
            roomName: item['roomName'] as String? ?? '',
            lectureSlot:
                item['lectureSlot'] is int ? item['lectureSlot'] as int : null,
            date: item['date'] as String?,
          ),
    ];
  }

  // -------------------------------------------------------- unknown crops

  @override
  Future<Uint8List> fetchCrop(String faceId) async {
    final List<int> bytes = await _client.getBytes('/api/crops/$faceId');
    return Uint8List.fromList(bytes);
  }

  // --------------------------------------------------------------- helpers

  ReviewData _resultFromJson(Map<String, dynamic> data) {
    final List<dynamic> presentJson =
        (data['presentStudents'] as List<dynamic>? ?? <dynamic>[]);

    final List<Student> present = <Student>[
      for (final dynamic item in presentJson)
        if (item is Map<String, dynamic>)
          Student(
            id: '${item['studentId']}',
            name: item['name'] as String? ?? 'Unknown student',
            rollNo: item['rollNo'] as String?,
            faceEnrolled: true,
          ),
    ];

    final Map<String, double> matches = <String, double>{
      for (final dynamic item in presentJson)
        if (item is Map<String, dynamic> &&
            item['aiMatched'] == true &&
            item['similarity'] is num)
          '${item['studentId']}':
              _matchPercent((item['similarity'] as num).toDouble()),
    };

    final List<UnknownFace> unknown = <UnknownFace>[
      for (final dynamic item
          in (data['unknownFaces'] as List<dynamic>? ?? <dynamic>[]))
        if (item is Map<String, dynamic>)
          UnknownFace(
            id: '${item['faceId']}',
            photoIdx: item['photoIdx'] is int ? item['photoIdx'] as int : null,
            thumbnail: item['thumbnail'] as String?,
            similarity: item['similarity'] is num
                ? (item['similarity'] as num).toDouble()
                : null,
            resolvedStudentId: item['resolvedStudentId']?.toString(),
          ),
    ];

    final List<Student> notSeen = <Student>[
      for (final dynamic item
          in (data['notSeen'] as List<dynamic>? ?? <dynamic>[]))
        if (item is Map<String, dynamic>)
          Student(
            id: '${item['studentId']}',
            name: item['name'] as String? ?? 'Unknown student',
            rollNo: item['rollNo'] as String?,
            faceEnrolled: true,
          ),
    ];

    return ReviewData(
      present: present,
      unknown: unknown,
      notSeen: notSeen,
      matches: matches,
      warnings: <String>[
        for (final dynamic w
            in (data['warnings'] as List<dynamic>? ?? <dynamic>[]))
          '$w',
      ],
      backendStatus: data['status'] as String?,
    );
  }

  /// Cosine similarity (0..1) -> percent; values > 1 are already percents.
  static double _matchPercent(double similarity) =>
      similarity <= 1.0 ? similarity * 100 : similarity;

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
