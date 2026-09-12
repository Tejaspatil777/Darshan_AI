import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/progress.dart';
import '../../data/models/user.dart';
import '../../routing/app_router.dart';
import '../../state/auth_provider.dart';
import '../../state/enrollment_provider.dart';

/// Face enrollment wizard: 4 profile-review steps (data from GET /api/users/me
/// via AuthProvider.studentProfile), then guided capture.
class EnrollmentStepsScreen extends StatefulWidget {
  const EnrollmentStepsScreen({super.key});

  @override
  State<EnrollmentStepsScreen> createState() => _EnrollmentStepsScreenState();
}

class _EnrollmentStepsScreenState extends State<EnrollmentStepsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EnrollmentProvider>().refreshEnrolled();
      }
    });
  }

  static const List<String> _stepLabels = <String>[
    'Personal Details',
    'Academic Details',
    'Contact Details',
    'Review & Submit',
  ];

  @override
  Widget build(BuildContext context) {
    final EnrollmentProvider provider = context.watch<EnrollmentProvider>();
    final Student? student = context.watch<AuthProvider>().studentProfile;
    final bool enrolled = provider.enrolled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Face Enrollment'),
      body: SafeArea(
        child: Column(
          children: [
            if (enrolled)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AppCard(
                  color: AppColors.successSoft,
                  borderColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined,
                          size: 20, color: AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your face is already enrolled. '
                          'You can re-capture if needed.',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: StepTimeline(
                        numbered: true,
                        itemGap: 26,
                        steps: List<TimelineStep>.generate(
                          4,
                          (int i) => TimelineStep(
                            _stepLabels[i],
                            i < provider.wizardStep
                                ? TimelineStepState.done
                                : i == provider.wizardStep
                                    ? TimelineStepState.active
                                    : TimelineStepState.pending,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: _stepContent(provider.wizardStep, student)),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 8, 20, AppSpacing.bottomCta),
              child: PrimaryButton(
                label: provider.wizardStep < 3
                    ? 'Next'
                    : (enrolled ? 'Re-capture Face' : 'Start Face Capture'),
                onPressed: () {
                  if (provider.wizardStep < 3) {
                    provider.nextWizardStep();
                  } else {
                    Navigator.of(context).pushNamed(AppRoutes.faceCapture);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent(int step, Student? s) {
    final List<(String, String)> rows = switch (step) {
      0 => [
          ('Full name', s?.name ?? '-'),
          ('Student ID', s?.id ?? '-'),
          ('Date of birth', _formatDob(s)),
        ],
      1 => [
          ('Department', s?.department ?? '-'),
          ('Semester', s?.semester ?? '-'),
          ('Section', s?.section ?? '-'),
          ('Roll no.', s?.rollNo ?? '-'),
        ],
      2 => [
          ('Email', s?.email ?? '-'),
          ('Phone', s?.phone ?? '-'),
          ('Address', s?.address ?? '-'),
        ],
      _ => [
          ('Name', s?.name ?? '-'),
          ('Student ID', s?.id ?? '-'),
          ('Department', s?.department ?? '-'),
          ('Semester', s?.semester ?? '-'),
          ('Section', s?.section ?? '-'),
        ],
    };

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rows[i].$1, style: AppTypography.caption),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    textAlign: TextAlign.end,
                    style: AppTypography.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (i != rows.length - 1) const Divider(),
        ],
        if (step == 3) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Next, you will capture 7 guided face photos.',
                  style: AppTypography.helper,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDob(Student? s) {
    if (s == null || s.dateOfBirth == null) return '-';
    final DateTime dob = s.dateOfBirth!;
    return '${dob.day.toString().padLeft(2, '0')} '
        '${_months[dob.month - 1]} ${dob.year}';
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
