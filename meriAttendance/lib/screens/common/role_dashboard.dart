import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/list_items.dart';
import '../../routing/app_router.dart';
import '../../state/auth_provider.dart';

/// One dashboard action entry.
class DashboardAction {
  const DashboardAction(this.icon, this.label, this.onTap, {this.trailing});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
}

/// Shared dashboard layout for both roles:
/// menu + avatar row, "Welcome / `name`", then clean action cards.
class RoleDashboard extends StatelessWidget {
  const RoleDashboard({
    super.key,
    required this.userName,
    required this.actions,
  });

  final String userName;
  final List<DashboardAction> actions;

  void _openMenu(BuildContext context) {
    // IMPORTANT: the sheet's own context dies when the sheet is popped, so all
    // post-pop actions must use the page [context] captured here.
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed(AppRoutes.profile);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.logout_outlined, color: AppColors.error),
                title: const Text('Logout',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _logout(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final bool confirmed = await confirmLogout(context);
    if (!confirmed || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (Route<dynamic> r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _openMenu(context),
                    icon: const Icon(Icons.menu, size: 26),
                  ),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.profile),
                    child: const AvatarPlaceholder(size: 40),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Welcome',
                  style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              Text(userName, style: AppTypography.display),
              const SizedBox(height: AppSpacing.xxl),
              for (int i = 0; i < actions.length; i++) ...[
                DashboardActionCard(
                  icon: actions[i].icon,
                  label: actions[i].label,
                  onTap: actions[i].onTap,
                  trailing: actions[i].trailing,
                ),
                if (i != actions.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
