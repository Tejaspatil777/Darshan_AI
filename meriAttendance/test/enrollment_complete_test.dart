import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meritendance/data/repositories/mock/mock_auth_repository.dart';
import 'package:meritendance/data/repositories/mock/mock_enrollment_repository.dart';
import 'package:meritendance/data/repositories/mock/mock_profile_repositories.dart';
import 'package:meritendance/routing/app_router.dart';
import 'package:meritendance/screens/profile/profile_screen.dart';
import 'package:meritendance/screens/student/enrollment_complete_screen.dart';
import 'package:meritendance/screens/student/face_capture_screen.dart';
import 'package:meritendance/state/auth_provider.dart';
import 'package:meritendance/state/enrollment_provider.dart';

void main() {
  Future<AuthProvider> loggedInStudent(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AuthProvider auth = AuthProvider(
      MockAuthRepository(latency: Duration.zero),
      MockStudentRepository(latency: Duration.zero),
      MockFacultyRepository(latency: Duration.zero),
    );
    // Fake-async safe login + first login: repo timers only fire when the
    // test clock is pumped.
    final Future<void> login =
        auth.login(usernameOrEmail: 'student', password: 'Student@123');
    await tester.pump(const Duration(milliseconds: 100));
    await login;
    final Future<void> first = auth.completeFirstLogin('Student@1234');
    await tester.pump(const Duration(milliseconds: 100));
    await first;
    return auth;
  }

  Widget app(
    AuthProvider auth,
    EnrollmentProvider enrollment, {
    Widget? home,
  }) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<EnrollmentProvider>.value(value: enrollment),
        ],
        child: MaterialApp(
          routes: <String, WidgetBuilder>{
            AppRoutes.studentDashboard: (_) =>
                const Scaffold(body: Text('DASHBOARD')),
            AppRoutes.enrollmentComplete: (_) =>
                const EnrollmentCompleteScreen(),
            AppRoutes.profile: (_) => const ProfileScreen(),
          },
          home: home,
        ),
      );

  testWidgets(
      'after the 7th capture the submit button enrolls and lands on the '
      'complete screen', (WidgetTester tester) async {
    final AuthProvider auth = await loggedInStudent(tester);
    final EnrollmentProvider enrollment = EnrollmentProvider(
      MockEnrollmentRepository(latency: Duration.zero),
      auth,
    );

    await tester
        .pumpWidget(app(auth, enrollment, home: const FaceCaptureScreen()));
    await tester.pumpAndSettle();

    // Capture all 7 poses (Straight x3, Left x2, Right x2). Each capture
    // runs a 700 ms fake detection timer.
    for (int i = 0; i < 7; i++) {
      await tester.tap(find.byKey(const ValueKey('captureButton')));
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pumpAndSettle();

    expect(enrollment.captureIndex, 7);
    expect(find.text('Submit Enrollment'), findsOneWidget);

    // Submit. The button shows an indeterminate spinner while busy, so the
    // busy phase is driven with timed pumps (never pumpAndSettle).
    await tester.tap(find.text('Submit Enrollment'));
    await tester.pump();
    // Let the mock repository processing complete (latency: Duration.zero,
    // but the provider sets submitting=true before calling the repo).
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(enrollment.enrolled, isTrue);
    // Landed on the enrollment-complete confirmation screen.
    expect(find.text('Face enrollment successful'), findsOneWidget);
    expect(find.text('Go to Profile'), findsOneWidget);
  });

  testWidgets('Go to Profile lands on the profile marked Completed',
      (WidgetTester tester) async {
    final AuthProvider auth = await loggedInStudent(tester);
    final EnrollmentProvider enrollment = EnrollmentProvider(
      MockEnrollmentRepository(latency: Duration.zero),
      auth,
    );
    // Pretend the captures were already submitted.
    final Future<void> submitted = enrollment.submitEnrollment();
    await tester.pump(const Duration(milliseconds: 100));
    await submitted;
    expect(enrollment.enrolled, isTrue);

    await tester.pumpWidget(app(
      auth,
      enrollment,
      home: const EnrollmentCompleteScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Face Enrollment'), findsOneWidget);
  });
}