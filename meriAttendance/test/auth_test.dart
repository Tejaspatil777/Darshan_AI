import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meritendance/data/models/user.dart';
import 'package:meritendance/data/repositories/mock/mock_auth_repository.dart';
import 'package:meritendance/data/repositories/mock/mock_profile_repositories.dart';
import 'package:meritendance/data/repositories/repositories.dart';
import 'package:meritendance/state/auth_provider.dart';

AuthProvider _auth() => AuthProvider(
      MockAuthRepository(latency: Duration.zero),
      MockStudentRepository(latency: Duration.zero),
      MockFacultyRepository(latency: Duration.zero),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('student login requires a first-login password change', () async {
    final AuthProvider auth = _auth();
    await auth.login(usernameOrEmail: 'student', password: 'Student@123');
    expect(auth.status, AuthStatus.firstLoginRequired);
    expect(auth.user?.role, UserRole.student);
    expect(auth.user?.forcePasswordChange, isTrue);
  });

  test('first-login completion authenticates without re-login', () async {
    final AuthProvider auth = _auth();
    await auth.login(usernameOrEmail: 'student', password: 'Student@123');
    await auth.completeFirstLogin('Student@1234');
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.isStudent, isTrue);
    expect(auth.studentProfile?.name, 'Aarav Sharma');
    expect(auth.studentProfile?.id, '21BCS001');
  });

  test('faculty logs in directly with profile', () async {
    final AuthProvider auth = _auth();
    await auth.login(usernameOrEmail: 'faculty', password: 'Faculty@123');
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.isFaculty, isTrue);
    expect(auth.facultyProfile?.department, 'Computer Science');
  });

  test('incorrect password throws a friendly AppException', () async {
    final AuthProvider auth = _auth();
    await expectLater(
      auth.login(usernameOrEmail: 'faculty', password: 'wrong'),
      throwsA(isA<AppException>()),
    );
  });

  test('logout clears the session and restore returns null', () async {
    final AuthProvider auth = _auth();
    await auth.login(usernameOrEmail: 'faculty', password: 'Faculty@123');
    await auth.logout();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.user, isNull);
    await auth.restoreSession();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.user, isNull);
  });
}