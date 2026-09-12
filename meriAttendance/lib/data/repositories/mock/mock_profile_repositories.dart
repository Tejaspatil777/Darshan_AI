import '../repositories.dart';
import '../../models/user.dart';
import 'demo_data.dart';

/// Demo student/faculty profile repositories.
class MockStudentRepository implements StudentRepository {
  MockStudentRepository({this.latency = const Duration(milliseconds: 300)});

  final Duration latency;

  @override
  Future<Student> getStudentProfile(String studentId) async {
    await Future<void>.delayed(latency);
    return DemoData.demoStudent;
  }
}

class MockFacultyRepository implements FacultyRepository {
  MockFacultyRepository({this.latency = const Duration(milliseconds: 300)});

  final Duration latency;

  @override
  Future<Faculty> getFacultyProfile(String facultyId) async {
    await Future<void>.delayed(latency);
    return DemoData.demoFaculty;
  }
}
