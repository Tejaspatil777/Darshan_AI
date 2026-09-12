import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/list_items.dart';
import '../../routing/app_router.dart';
import '../../state/auth_provider.dart';
import '../../state/enrollment_provider.dart';
import '../common/role_dashboard.dart';

/// Student home: Face Enrollment / Profile / Logout.
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EnrollmentProvider>().refreshEnrolled();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final EnrollmentProvider enrollment = context.watch<EnrollmentProvider>();
    final String name = auth.studentProfile?.name ?? 'Student';

    return RoleDashboard(
      userName: name,
      actions: [
        DashboardAction(
          Icons.face_outlined,
          'Face Enrollment',
          () => Navigator.of(context).pushNamed(AppRoutes.enrollment),
          trailing: enrollment.enrolled
              ? const StatusPill(
                  label: 'Enrolled',
                  color: AppColors.success,
                  background: AppColors.successSoft,
                )
              : null,
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
