import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/helpers.dart';
import '../../routing/app_router.dart';
import '../../state/auth_provider.dart';
import '../common/role_dashboard.dart';

/// Faculty home: Take Attendance / Profile / Logout.
class FacultyDashboardScreen extends StatelessWidget {
  const FacultyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String name = auth.facultyProfile?.name ?? 'Faculty';

    return RoleDashboard(
      userName: name,
      actions: [
        DashboardAction(
          Icons.photo_camera_outlined,
          'Take Attendance',
          () => Navigator.of(context).pushNamed(AppRoutes.attendanceSetup),
        ),
        DashboardAction(
          Icons.person_outline,
          'Profile',
          () => Navigator.of(context).pushNamed(AppRoutes.profile),
        ),
        DashboardAction(
          Icons.logout_outlined,
          'Logout',
          () async {
            final bool confirmed = await confirmLogout(context);
            if (!confirmed || !context.mounted) return;
            await context.read<AuthProvider>().logout();
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login, (Route<dynamic> r) => false);
          },
        ),
      ],
    );
  }
}
