import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum TimelineStepState { pending, active, done }

class TimelineStep {
  const TimelineStep(this.label, this.state);
  final String label;
  final TimelineStepState state;
}

/// Vertical progress timeline.
///
/// [numbered] renders numbered circles (enrollment wizard); otherwise
/// it renders check/pulse/hollow circles (processing screen).
class StepTimeline extends StatelessWidget {
  const StepTimeline({
    super.key,
    required this.steps,
    this.numbered = false,
    this.itemGap = 18,
  });

  final List<TimelineStep> steps;
  final bool numbered;
  final double itemGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Row(
            children: [
              _circle(steps[i], i),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    steps[i].label,
                    style: steps[i].state == TimelineStepState.done
                        ? AppTypography.body
                        : AppTypography.bodySecondary,
                  ),
                ),
              ),
            ],
          ),
          if (i != steps.length - 1)
            Container(
              margin: const EdgeInsets.only(left: 13),
              width: 2,
              height: itemGap,
              color: steps[i].state == TimelineStepState.done
                  ? AppColors.primary
                  : AppColors.border,
            ),
        ],
      ],
    );
  }

  Widget _circle(TimelineStep step, int index) {
    final BoxDecoration decoration;
    final Widget? child;
    switch (step.state) {
      case TimelineStepState.done:
        decoration = const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        );
        child = const Icon(Icons.check, size: 16, color: Colors.white);
        break;
      case TimelineStepState.active:
        decoration = BoxDecoration(
          color: numbered ? AppColors.primary : AppColors.primarySoft,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        );
        child = numbered
            ? Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              )
            : const _PulsingDot();
        break;
      case TimelineStepState.pending:
        decoration = BoxDecoration(
          color: AppColors.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderStrong, width: 1.5),
        );
        child = numbered
            ? Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              )
            : null;
        break;
    }
    return Container(
      width: 28,
      height: 28,
      decoration: decoration,
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
