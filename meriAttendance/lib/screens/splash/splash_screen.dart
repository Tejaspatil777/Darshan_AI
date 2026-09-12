import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/progress_dots.dart';
import '../../routing/app_router.dart';
import '../../state/auth_provider.dart';

/// Splash: brand lockup + saved-session check, then role-based routing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Give the brand moment to breathe (and the session check to finish).
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    final AuthProvider auth = context.read<AuthProvider>();
    int tries = 0;
    while (auth.status == AuthStatus.loading && tries < 30) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      tries++;
    }
    if (!mounted) return;
    final String route = switch (auth.status) {
      AuthStatus.authenticated =>
        auth.isFaculty ? AppRoutes.facultyDashboard : AppRoutes.studentDashboard,
      AuthStatus.firstLoginRequired => AppRoutes.firstLogin,
      _ => AppRoutes.login,
    };
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: const BrandLogo(markSize: 88),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: SizedBox(
                width: 60,
                child: ProgressDots(total: 2, completed: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
