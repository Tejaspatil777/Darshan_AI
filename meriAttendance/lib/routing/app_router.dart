import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/auth/first_login_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/faculty/attendance_setup_screen.dart';
import '../screens/faculty/faculty_dashboard_screen.dart';
import '../screens/faculty/photo_capture_screen.dart';
import '../screens/faculty/processing_screen.dart';
import '../screens/faculty/review_attendance_screen.dart';
import '../screens/faculty/session_complete_screen.dart';
import '../screens/profile/change_password_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/student/enrollment_complete_screen.dart';
import '../screens/student/enrollment_steps_screen.dart';
import '../screens/student/face_capture_screen.dart';
import '../screens/student/student_dashboard_screen.dart';
import '../state/auth_provider.dart';
import '../data/models/user.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String firstLogin = '/first-login';

  static const String studentDashboard = '/student';
  static const String enrollment = '/student/enrollment';
  static const String faceCapture = '/student/enrollment/capture';
  static const String enrollmentComplete = '/student/enrollment/complete';

  static const String facultyDashboard = '/faculty';
  static const String attendanceSetup = '/faculty/attendance/setup';
  static const String photoCapture = '/faculty/attendance/capture';
  static const String processing = '/faculty/attendance/processing';
  static const String review = '/faculty/attendance/review';
  static const String sessionComplete = '/faculty/attendance/complete';

  static const String profile = '/profile';
  static const String changePassword = '/profile/change-password';
}

/// Named-route navigation with role guards:
/// - unauthenticated users are sent to Login
/// - students can never reach faculty screens (and vice versa)
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _page(const SplashScreen(), settings);

      case AppRoutes.login:
        return _page(const LoginScreen(), settings);

      case AppRoutes.firstLogin:
        return _page(const FirstLoginScreen(), settings);

      // --- Student flow ---------------------------------------------------
      case AppRoutes.studentDashboard:
        return _guarded(settings, const StudentDashboardScreen(),
            role: UserRole.student);
      case AppRoutes.enrollment:
        return _guarded(settings, const EnrollmentStepsScreen(),
            role: UserRole.student);
      case AppRoutes.faceCapture:
        return _guarded(settings, const FaceCaptureScreen(),
            role: UserRole.student);
      case AppRoutes.enrollmentComplete:
        return _guarded(settings, const EnrollmentCompleteScreen(),
            role: UserRole.student);

      // --- Faculty flow ---------------------------------------------------
      case AppRoutes.facultyDashboard:
        return _guarded(settings, const FacultyDashboardScreen(),
            role: UserRole.faculty);
      case AppRoutes.attendanceSetup:
        return _guarded(settings, const AttendanceSetupScreen(),
            role: UserRole.faculty);
      case AppRoutes.photoCapture:
        return _guarded(settings, const PhotoCaptureScreen(),
            role: UserRole.faculty);
      case AppRoutes.processing:
        return _guarded(settings, const ProcessingScreen(),
            role: UserRole.faculty);
      case AppRoutes.review:
        return _guarded(settings, const ReviewAttendanceScreen(),
            role: UserRole.faculty);
      case AppRoutes.sessionComplete:
        return _guarded(settings, const SessionCompleteScreen(),
            role: UserRole.faculty);

      // --- Shared ----------------------------------------------------------
      case AppRoutes.profile:
        return _guarded(settings, const ProfileScreen());
      case AppRoutes.changePassword:
        return _guarded(settings, const ChangePasswordScreen());

      default:
        return _page(const SplashScreen(), settings);
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget page, RouteSettings settings) {
    return MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
  }

  /// Wraps a route with auth + role guards.
  static MaterialPageRoute<dynamic> _guarded(
    RouteSettings settings,
    Widget page, {
    UserRole? role,
  }) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (BuildContext context) {
        final AuthProvider auth = context.read<AuthProvider>();
        final user = auth.user;
        if (user == null) {
          return const LoginScreen();
        }
        if (role != null && user.role != role) {
          return user.role == UserRole.student
              ? const StudentDashboardScreen()
              : const FacultyDashboardScreen();
        }
        return page;
      },
    );
  }
}
