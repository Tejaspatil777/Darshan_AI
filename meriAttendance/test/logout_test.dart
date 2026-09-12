import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meritendance/data/repositories/mock/mock_auth_repository.dart';
import 'package:meritendance/data/repositories/mock/mock_profile_repositories.dart';
import 'package:meritendance/routing/app_router.dart';
import 'package:meritendance/screens/auth/login_screen.dart';
import 'package:meritendance/screens/faculty/faculty_dashboard_screen.dart';
import 'package:meritendance/state/auth_provider.dart';

void main() {
  testWidgets(
      'logout from the dashboard menu clears the session and lands on Login',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AuthProvider auth = AuthProvider(
      MockAuthRepository(latency: Duration.zero),
      MockStudentRepository(latency: Duration.zero),
      MockFacultyRepository(latency: Duration.zero),
    );
    // testWidgets runs in fake async: repo timers only fire when the test
    // clock is pumped, so drive the login through a pump.
    final Future<void> login =
        auth.login(usernameOrEmail: 'faculty', password: 'Faculty@123');
    await tester.pump(const Duration(milliseconds: 100));
    await login;
    expect(auth.status, AuthStatus.authenticated);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          routes: <String, WidgetBuilder>{
            AppRoutes.login: (_) => const LoginScreen(),
          },
          home: const FacultyDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the hamburger menu and pick Logout.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(ListTile),
      matching: find.text('Logout'),
    ));
    await tester.pumpAndSettle();

    // Confirm the logout dialog.
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    // Login screen is shown, session state is cleared.
    expect(find.text('Email / Username'), findsOneWidget);
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.user, isNull);

    // A fresh session restore finds nothing (browser refresh stays logged out).
    await auth.restoreSession();
    expect(auth.status, AuthStatus.unauthenticated);
  });

  testWidgets('logout from the dashboard action card works too',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AuthProvider auth = AuthProvider(
      MockAuthRepository(latency: Duration.zero),
      MockStudentRepository(latency: Duration.zero),
      MockFacultyRepository(latency: Duration.zero),
    );
    // Fake-async safe login (see note in the first test).
    final Future<void> login =
        auth.login(usernameOrEmail: 'faculty', password: 'Faculty@123');
    await tester.pump(const Duration(milliseconds: 100));
    await login;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          routes: <String, WidgetBuilder>{
            AppRoutes.login: (_) => const LoginScreen(),
          },
          home: const FacultyDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The dashboard action card labelled Logout (not the menu entry).
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Email / Username'), findsOneWidget);
    expect(auth.status, AuthStatus.unauthenticated);
  });
}