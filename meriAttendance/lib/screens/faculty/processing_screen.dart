import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/progress.dart';
import '../../data/models/attendance.dart' show SessionStatus;
import '../../routing/app_router.dart';
import '../../state/attendance_provider.dart';

/// Processing screen: shows the real backend session state while the async
/// worker runs (Spring Boot -> Python AI). The timeline reflects only real
/// progress: photos uploaded (HTTP 202) -> backend PROCESSING -> REVIEW.
/// On FAILED / timeout an honest error state with retry is shown.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  bool _started = false;
  bool _navigated = false;

  static const List<String> _stepLabels = <String>[
    'Uploading photos',
    'Detecting faces',
    'Matching with students',
    'Finalizing results',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_started) {
        _started = true;
        context.read<AttendanceProvider>().runProcessing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceProvider p = context.watch<AttendanceProvider>();

    if (p.status == SessionStatus.review && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context)
              .pushReplacementNamed(AppRoutes.review);
        }
      });
    }

    final int step = p.processingStep;
    final bool failed = p.status == SessionStatus.failed;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Processing'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Processing attendance', style: AppTypography.heading),
              const SizedBox(height: 4),
              Text(
                failed
                    ? 'The attendance session could not be processed.'
                    : 'Your photos are being analyzed. This will only take a moment.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 28),
              StepTimeline(
                itemGap: 26,
                steps: List<TimelineStep>.generate(
                  _stepLabels.length,
                  (int i) {
                    if (failed && i > 1) {
                      return TimelineStep(
                          _stepLabels[i], TimelineStepState.pending);
                    }
                    return TimelineStep(
                      _stepLabels[i],
                      i < step
                          ? TimelineStepState.done
                          : i == step
                              ? TimelineStepState.active
                              : TimelineStepState.pending,
                    );
                  },
                ),
              ),
              const Spacer(),
              if (failed) ...[
                Text(
                  p.errorMessage ?? 'Something went wrong. Please try again.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Try Again',
                  onPressed: p.session == null
                      ? null
                      : () => p.resumeProcessing(),
                ),
              ] else if (step >= _stepLabels.length)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('Preparing review...',
                        style: AppTypography.caption),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

