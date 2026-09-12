import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enrollment.dart';
import '../../routing/app_router.dart';
import '../../state/enrollment_provider.dart';

/// Enrollment success confirmation, shown after the captures were submitted
/// from the capture screen. The student continues to their profile, where
/// the face enrollment shows as Completed.
class EnrollmentCompleteScreen extends StatelessWidget {
  const EnrollmentCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Enrollment Complete', showBack: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const SuccessState(
                        title: 'Face enrollment successful',
                        message: 'Your face is enrolled. You can now mark '
                            'attendance in your classes.',
                      ),
                      const SizedBox(height: 24),
                      const _CaptureSummary(),
                    ],
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Go to Profile',
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.profile,
                  (Route<dynamic> route) =>
                      route.settings.name == AppRoutes.studentDashboard,
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

/// What was captured: Straight x3, Left x2, Right x2.
class _CaptureSummary extends StatelessWidget {
  const _CaptureSummary();

  @override
  Widget build(BuildContext context) {
    final Map<EnrollmentPose, int> counts = <EnrollmentPose, int>{};
    for (final EnrollmentPose pose in EnrollmentProvider.poseSequence) {
      counts[pose] = (counts[pose] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Captured photos', style: AppTypography.caption),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final EnrollmentPose pose in EnrollmentPose.values) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 20, color: AppColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('${pose.label} face',
                            style: AppTypography.body),
                      ),
                      Text('x${counts[pose]}', style: AppTypography.heading),
                    ],
                  ),
                ),
                if (pose != EnrollmentPose.values.last) const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
