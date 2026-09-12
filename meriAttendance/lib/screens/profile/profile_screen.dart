import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/list_items.dart';
import '../../routing/app_router.dart';
import '../../state/auth_provider.dart';
import '../../state/enrollment_provider.dart';
import '../../data/models/user.dart';

/// Role-aware profile: avatar, name, ID, role pill, info rows,
/// Change Password and Logout. Admin-controlled data stays read-only.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Keep the face-enrollment status fresh when opening the profile.
        context.read<EnrollmentProvider>().refreshEnrolled();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final EnrollmentProvider enrollment = context.watch<EnrollmentProvider>();
    final bool isStudent = auth.isStudent;

    final String name = isStudent
        ? (auth.studentProfile?.name ?? 'Student')
        : (auth.facultyProfile?.name ?? 'Faculty');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Profile'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const AvatarPlaceholder(size: 88),
              const SizedBox(height: 12),
              Text(name, style: AppTypography.heading.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              //Text(id, style: AppTypography.caption),
             // const SizedBox(height: 10),
              StatusPill(label: isStudent ? 'Student' : 'Faculty'),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: isStudent
                      ? _studentRows(auth, enrollment.enrolled)
                      : _facultyRows(auth),
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.changePassword),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                child: _row(Icons.lock_outline, 'Change Password'),
              ),
              const SizedBox(height: 12),
              AppCard(
                onTap: () => _logout(context),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                child: _row(Icons.logout_outlined, 'Logout'),
              ),
              const SizedBox(height: AppSpacing.bottomCta),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 24, color: AppColors.textPrimary),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: AppTypography.heading)),
        const Icon(Icons.chevron_right,
            size: 22, color: AppColors.textTertiary),
      ],
    );
  }

  List<Widget> _studentRows(AuthProvider auth, bool enrolled) {
    final Student? s = auth.studentProfile;
    final bool faceDone = enrolled || (s?.faceEnrolled ?? false);
    return [
      ProfileInfoTile(
          icon: Icons.mail_outline, label: 'Email', value: s?.email ?? '-'),
      const Divider(indent: 48),
      ProfileInfoTile(
          icon: Icons.phone_outlined, label: 'Phone', value: s?.phone ?? '-'),
      const Divider(indent: 48),
      ProfileInfoTile(
          icon: Icons.cake_outlined,
          label: 'Date of Birth',
          value: _dob(s)),
      const Divider(indent: 48),
      ProfileInfoTile(
          icon: Icons.account_balance_outlined,
          label: 'Department',
          value: s?.department ?? '-'),
      const Divider(indent: 48),
      ProfileInfoTile(
          icon: Icons.school_outlined,
          label: 'Semester',
          value: s?.semester ?? '-'),
      const Divider(indent: 48),
      ProfileInfoTile(
          icon: Icons.badge_outlined,
          label: 'Student ID',
          value: s?.id ?? '-'),
      const Divider(indent: 48),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.face_outlined,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            const Expanded(
                child: Text('Face Enrollment', style: AppTypography.body)),
            StatusPill(
              label: faceDone ? 'Completed' : 'Not enrolled',
              color: faceDone ? AppColors.success : AppColors.textSecondary,
              background:
                  faceDone ? AppColors.successSoft : AppColors.surfaceAlt,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _facultyRows(AuthProvider auth) {
    final Faculty? f = auth.facultyProfile;
    return [
      ProfileInfoTile(
          icon: Icons.mail_outline, label: 'Email', value: f?.email ?? '-'),
      const Divider(indent: 48),
      ProfileInfoTile(
          icon: Icons.phone_outlined, label: 'Phone', value: f?.phone ?? '-'),
      const Divider(indent: 48),
      ProfileInfoTile(
          icon: Icons.account_balance_outlined,
          label: 'Department',
          value: f?.department ?? '-'),
      const Divider(indent: 48),
      ProfileInfoTile(
          icon: Icons.badge_outlined,
          label: 'Faculty ID',
          value: f?.id ?? '-'),
    ];
  }

  String _dob(Student? s) {
    if (s == null) return '-';
    final DateTime? dob = s.dateOfBirth;
    if (dob == null) return '-';
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dob.day.toString().padLeft(2, '0')} '
        '${months[dob.month - 1]} ${dob.year}';
  }

  Future<void> _logout(BuildContext context) async {
    final bool confirmed = await confirmLogout(context);
    if (!confirmed || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (Route<dynamic> r) => false);
  }
}
