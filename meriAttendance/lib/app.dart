import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/network/token_store.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/api/attendance_api_repository.dart';
import 'data/repositories/api/auth_api_repository.dart';
import 'data/repositories/api/enrollment_api_repository.dart';
import 'data/repositories/api/profile_api_repositories.dart';
import 'data/repositories/repositories.dart';
import 'routing/app_router.dart';
import 'state/attendance_provider.dart';
import 'state/auth_provider.dart';
import 'state/enrollment_provider.dart';

/// Meritendance (Darshan) — Face Attendance for Campus.
///
/// The active runtime path uses the REAL Spring Boot API repositories
/// (DarshanApi*). The demo repositories under data/repositories/mock/ are
/// kept ONLY for offline tests — they are never wired into the app.
class MeritendanceApp extends StatelessWidget {
  const MeritendanceApp({super.key, required this.tokenStore});

  final TokenStore tokenStore;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --- Network + real API repositories (active runtime path) ---------
        Provider<TokenStore>.value(value: tokenStore),
        Provider<ApiClient>(
          create: (BuildContext ctx) =>
              ApiClient(ctx.read<TokenStore>()),
        ),
        Provider<AuthRepository>(
          create: (BuildContext ctx) =>
              AuthApiRepository(ctx.read<ApiClient>(), ctx.read<TokenStore>()),
        ),
        Provider<StudentRepository>(
          create: (BuildContext ctx) =>
              StudentApiRepository(ctx.read<ApiClient>()),
        ),
        Provider<FacultyRepository>(
          create: (BuildContext ctx) =>
              FacultyApiRepository(ctx.read<ApiClient>()),
        ),
        Provider<EnrollmentRepository>(
          create: (BuildContext ctx) =>
              EnrollmentApiRepository(ctx.read<ApiClient>()),
        ),
        Provider<AttendanceRepository>(
          create: (BuildContext ctx) =>
              AttendanceApiRepository(ctx.read<ApiClient>()),
        ),
        // State.
        ChangeNotifierProvider(
          create: (BuildContext ctx) => AuthProvider(
            ctx.read<AuthRepository>(),
            ctx.read<StudentRepository>(),
            ctx.read<FacultyRepository>(),
            ctx.read<ApiClient>(),
          )..restoreSession(),
        ),
        ChangeNotifierProvider(
          create: (BuildContext ctx) => EnrollmentProvider(
            ctx.read<EnrollmentRepository>(),
            ctx.read<AuthProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (BuildContext ctx) => AttendanceProvider(
            ctx.read<AttendanceRepository>(),
            ctx.read<AuthProvider>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'DarshanAI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
        // Keeps the phone-style UI centered and at a fixed phone width on
        // wide surfaces (web desktop, tablets) while remaining full-width
        // on actual phones.
        builder: (BuildContext context, Widget? child) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ColoredBox(
                color: AppColors.background,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

