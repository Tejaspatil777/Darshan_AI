import '../../models/user.dart';
import '../repositories.dart';
import '../../../core/network/api_client.dart';

/// Builds the view [Student] from the backend GET /api/users/me payload
/// (UserMeResponse). Fields the backend does not provide stay null and are
/// rendered as empty states — never faked.
Student studentFromUserMe(Map<String, dynamic> me) {
  return Student(
    id: _str(me['enrollmentNo']) ?? _str(me['rollNo']) ?? _str(me['userId']) ?? '',
    name: _str(me['name']) ?? _str(me['username']) ?? 'Student',
    email: _str(me['email']),
    phone: _str(me['phone']),
    dateOfBirth: _date(me['dateOfBirth']),
    department: _str(me['department']),
    semester: _int(me['semester']) != null ? 'Semester ${_int(me['semester'])}' : null,
    section: _str(me['className']),
    rollNo: _str(me['rollNo']),
    address: _str(me['address']),
    faceEnrolled: me['faceEnrollmentCompleted'] == true,
  );
}

/// Builds the view [Faculty] from GET /api/users/me.
Faculty facultyFromUserMe(Map<String, dynamic> me) {
  return Faculty(
    id: _str(me['employeeId']) ?? _str(me['userId']) ?? '',
    name: _str(me['name']) ?? _str(me['username']) ?? 'Faculty',
    email: _str(me['email']),
    phone: _str(me['phone']),
    department: _str(me['department']),
    branch: null, // not provided by the backend
  );
}

class StudentApiRepository implements StudentRepository {
  StudentApiRepository(this._client);

  final ApiClient _client;

  @override
  Future<Student> getStudentProfile(String userId) async {
    final dynamic me = await _client.get('/api/users/me');
    if (me is! Map<String, dynamic>) {
      throw AppException('The server returned an unexpected profile response.');
    }
    return studentFromUserMe(me);
  }
}

class FacultyApiRepository implements FacultyRepository {
  FacultyApiRepository(this._client);

  final ApiClient _client;

  @override
  Future<Faculty> getFacultyProfile(String userId) async {
    final dynamic me = await _client.get('/api/users/me');
    if (me is! Map<String, dynamic>) {
      throw AppException('The server returned an unexpected profile response.');
    }
    return facultyFromUserMe(me);
  }
}

String? _str(dynamic value) => value is String && value.isNotEmpty ? value : null;

int? _int(dynamic value) => value is int ? value : null;

/// Parses an ISO date ("2005-04-12") from the backend payload.
DateTime? _date(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
