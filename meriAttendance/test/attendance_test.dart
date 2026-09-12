import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meritendance/data/models/attendance.dart';
import 'package:meritendance/data/models/user.dart';
import 'package:meritendance/data/repositories/mock/mock_attendance_repository.dart';
import 'package:meritendance/data/repositories/mock/mock_auth_repository.dart';
import 'package:meritendance/data/repositories/mock/mock_profile_repositories.dart';
import 'package:meritendance/data/repositories/repositories.dart';
import 'package:meritendance/state/attendance_provider.dart';
import 'package:meritendance/state/auth_provider.dart';

AuthProvider _auth() => AuthProvider(
      MockAuthRepository(latency: Duration.zero),
      MockStudentRepository(latency: Duration.zero),
      MockFacultyRepository(latency: Duration.zero),
    );

AttendanceProvider _provider([AuthProvider? auth]) => AttendanceProvider(
      MockAttendanceRepository(latency: Duration.zero),
      auth ?? _auth(),
    );

Future<void> _fillSetup(AttendanceProvider p) async {
  p.branch = 'Computer Science';
  p.mode = 'Lecture';
  p.date = DateTime(2025, 9, 9);
  await p.initSetup();
  p.selectSubject('Data Structures');
  p.selectClass('Semester 5 - Section A');
  p.selectRoom('Room 101');
}

void main() {
  group('setup', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('department is locked from the signed-in faculty account', () async {
      final AuthProvider auth = _auth();
      await auth.login(usernameOrEmail: 'faculty', password: 'Faculty@123');
      expect(auth.facultyProfile?.department, 'Computer Science');
      final AttendanceProvider p = _provider(auth);
      await p.initSetup();
      expect(p.department, 'Computer Science');
      p.dispose();
    });

    test('setup requires all selections', () async {
      final AttendanceProvider p = _provider();
      expect(p.setupComplete, isFalse);
      await _fillSetup(p);
      expect(p.setupComplete, isTrue);
      p.dispose();
    });
  });

  group('photo capture', () {
    test('first photo stamps the session start time', () {
      final AttendanceProvider p = _provider();
      expect(p.startTime, isNull);
      p.addPhoto();
      expect(p.startTime, isNotNull);
      p.dispose();
    });

    test('captures are capped at 10', () {
      final AttendanceProvider p = _provider();
      for (int i = 0; i < 10; i++) {
        expect(p.addPhoto(), isTrue);
      }
      expect(p.photos, hasLength(10));
      expect(p.addPhoto(), isFalse);
      expect(p.photos, hasLength(10));
      p.dispose();
    });

    test('submit requires 5 to 10 photos', () {
      final AttendanceProvider p = _provider();
      expect(p.canSubmit, isFalse);
      for (int i = 0; i < 4; i++) {
        p.addPhoto();
      }
      expect(p.canSubmit, isFalse);
      p.addPhoto();
      expect(p.canSubmit, isTrue);
      for (int i = 0; i < 5; i++) {
        p.addPhoto();
      }
      expect(p.canSubmit, isTrue);
      p.dispose();
    });
  });

  group('processing + review', () {
    test(
        'processing produces 25 present / 3 unknown / 7 not seen and confirm '
        'is blocked while unknowns remain', () async {
      final AttendanceProvider p = _provider();
      await _fillSetup(p);
      for (int i = 0; i < 5; i++) {
        p.addPhoto();
      }
      await p.runProcessing();
      await Future.delayed(const Duration(seconds: 20));
      expect(p.status, SessionStatus.review);
      expect(p.present, hasLength(25));
      expect(p.unknownFaces, hasLength(3));
      expect(p.notSeen, hasLength(7));
      expect(p.session?.id, startsWith('SES-'));
      expect(p.unknownRemaining, 3);
      expect(p.canConfirm, isFalse);

      for (int i = 0; i < 3; i++) {
        final Student s = p.notSeen[i];
        await p.resolveUnknown(p.unknownFaces[i].id, s.id);
      }
      expect(p.unknownRemaining, 0);
      expect(p.canConfirm, isTrue);

      await expectLater(
        p.resolveUnknown(p.unknownFaces[0].id, '21BCS999'),
        throwsA(isA<AppException>()),
      );

      p.dispose();
    });

    test('confirm completes the session', () async {
      final AttendanceProvider p = _provider();
      await _fillSetup(p);
      for (int i = 0; i < 5; i++) {
        p.addPhoto();
      }
      await p.runProcessing();
      await Future.delayed(const Duration(seconds: 20));
      for (int i = 0; i < 3; i++) {
        await p.resolveUnknown(p.unknownFaces[i].id, p.notSeen[i].id);
      }
      await p.confirm();
      await Future.delayed(const Duration(seconds: 5));
      expect(p.status, SessionStatus.completed);
      expect(p.session?.status, SessionStatus.completed);
      p.dispose();
    });
  });

  group('manual faculty marking', () {
    test('faculty can mark a not-seen student present', () async {
      final AttendanceProvider p = _provider();
      await _fillSetup(p);
      for (int i = 0; i < 5; i++) {
        p.addPhoto();
      }
      await p.runProcessing();
      await Future.delayed(const Duration(seconds: 20));
      expect(p.status, SessionStatus.review);
      final int presentBefore = p.present.length;
      final Student s = p.notSeen.first;
      p.markPresentManually(s.id);
      expect(p.present, hasLength(presentBefore + 1));
      expect(p.present.any((Student x) => x.id == s.id), isTrue);
      expect(p.notSeen.any((Student x) => x.id == s.id), isFalse);
      expect(p.matches.containsKey(s.id), isFalse);
      expect(p.canConfirm, isFalse);
      p.dispose();
    });

    test('faculty can mark a present student absent', () async {
      final AttendanceProvider p = _provider();
      await _fillSetup(p);
      for (int i = 0; i < 5; i++) {
        p.addPhoto();
      }
      await p.runProcessing();
      await Future.delayed(const Duration(seconds: 20));
      expect(p.status, SessionStatus.review);
      final Student s = p.present.first;
      expect(p.matches.containsKey(s.id), isTrue);
      final int notSeenBefore = p.notSeen.length;
      p.markAbsentManually(s.id);
      expect(p.present.any((Student x) => x.id == s.id), isFalse);
      expect(p.matches.containsKey(s.id), isFalse);
      expect(p.notSeen, hasLength(notSeenBefore + 1));
      expect(p.notSeen.any((Student x) => x.id == s.id), isTrue);
      p.dispose();
    });

    test('manual marking validates the student', () async {
      final AttendanceProvider p = _provider();
      await _fillSetup(p);
      for (int i = 0; i < 5; i++) {
        p.addPhoto();
      }
      await p.runProcessing();
      await Future.delayed(const Duration(seconds: 20));
      expect(p.status, SessionStatus.review);
      expect(
        () => p.markPresentManually('21BCS999'),
        throwsA(isA<AppException>()),
      );
      expect(
        () => p.markAbsentManually('21BCS999'),
        throwsA(isA<AppException>()),
      );
      p.dispose();
    });
  });
}
