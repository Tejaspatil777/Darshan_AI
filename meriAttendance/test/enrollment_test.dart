import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meritendance/data/models/enrollment.dart';
import 'package:meritendance/data/repositories/mock/mock_auth_repository.dart';
import 'package:meritendance/data/repositories/mock/mock_enrollment_repository.dart';
import 'package:meritendance/data/repositories/mock/mock_profile_repositories.dart';
import 'package:meritendance/data/repositories/repositories.dart';
import 'package:meritendance/state/auth_provider.dart';
import 'package:meritendance/state/enrollment_provider.dart';

AuthProvider _auth() => AuthProvider(
      MockAuthRepository(latency: Duration.zero),
      MockStudentRepository(latency: Duration.zero),
      MockFacultyRepository(latency: Duration.zero),
    );

EnrollmentProvider _provider(AuthProvider auth) => EnrollmentProvider(
      MockEnrollmentRepository(latency: Duration.zero),
      auth,
    );

void main() {
  group('pose sequence', () {
    test('is Straight x3, Left x2, Right x2 = 7 total', () {
      expect(kEnrollmentPoseSequence, hasLength(7));
      expect(kEnrollmentPoseSequence.sublist(0, 3),
          everyElement(EnrollmentPose.straight));
      expect(kEnrollmentPoseSequence.sublist(3, 5),
          everyElement(EnrollmentPose.left));
      expect(kEnrollmentPoseSequence.sublist(5, 7),
          everyElement(EnrollmentPose.right));
    });
  });

  group('guided capture', () {
    test('advances through all 7 poses and blocks over-capture', () {
      fakeAsync((FakeAsync async) {
        final EnrollmentProvider p = _provider(_auth());
        expect(EnrollmentProvider.totalCaptures, 7);
        expect(p.currentPose, EnrollmentPose.straight);
        for (int i = 1; i <= 7; i++) {
          p.capture();
          async.elapse(const Duration(milliseconds: 750));
          expect(p.captureIndex, i);
        }
        expect(p.captureComplete, isTrue);
        expect(p.currentPose, isNull);
        // Capture is a no-op once complete.
        p.capture();
        async.elapse(const Duration(milliseconds: 750));
        expect(p.captureIndex, 7);
        p.dispose();
      });
    });

    test('retakeLast goes back one capture', () {
      fakeAsync((FakeAsync async) {
        final EnrollmentProvider p = _provider(_auth());
        p.capture();
        async.elapse(const Duration(milliseconds: 750));
        expect(p.captureIndex, 1);
        p.retakeLast();
        expect(p.captureIndex, 0);
        p.dispose();
      });
    });
  });

  group('submission', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('repository enforces exactly 7 captures', () async {
      final MockEnrollmentRepository repo =
          MockEnrollmentRepository(latency: Duration.zero);
      await expectLater(
        repo.enroll(
          studentId: '21BCS001',
          captures: <EnrollmentCapture>[
            const EnrollmentCapture(
                pose: EnrollmentPose.straight, imageB64: 'x'),
          ],
        ),
        throwsA(isA<AppException>()),
      );
      await repo.enroll(
          studentId: '21BCS001',
          captures: <EnrollmentCapture>[
            for (final EnrollmentPose pose in kEnrollmentPoseSequence)
              EnrollmentCapture(pose: pose, imageB64: 'x'),
          ]);
    });

    test('submitEnrollment marks the student as enrolled', () async {
      final AuthProvider auth = _auth();
      await auth.login(usernameOrEmail: 'student', password: 'Student@123');
      await auth.completeFirstLogin('Student@1234');
      expect(auth.studentProfile, isNotNull);
      final EnrollmentProvider p = _provider(auth);
      final bool ok = await p.submitEnrollment();
      expect(ok, isTrue);
      expect(p.enrolled, isTrue);
      p.dispose();
    });
  });
}