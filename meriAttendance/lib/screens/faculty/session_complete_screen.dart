import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/buttons.dart';
import '../../routing/app_router.dart';

/// Attendance submitted successfully.
class SessionCompleteScreen extends StatelessWidget {
  const SessionCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Session Complete', showBack: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SuccessState(
                    title: 'Attendance submitted successfully',
                    message: 'The attendance for this session has been '
                        'recorded and locked.',
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Go to Home',
                onPressed: () =>
                    Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.facultyDashboard,
                  (Route<dynamic> r) => false,
                ),
              ),
              const SizedBox(height: AppSpacing.bottomCta),
            ],
          ),
        ),
      ),
    );
  }
}
