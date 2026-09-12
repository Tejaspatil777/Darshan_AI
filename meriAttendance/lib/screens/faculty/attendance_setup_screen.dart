import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../routing/app_router.dart';
import '../../state/attendance_provider.dart';

/// Take Attendance setup. Department is locked from the faculty account.
/// Start time is intentionally absent — it is stamped automatically when
/// the first classroom photo is captured.
class AttendanceSetupScreen extends StatefulWidget {
  const AttendanceSetupScreen({super.key});

  @override
  State<AttendanceSetupScreen> createState() => _AttendanceSetupScreenState();
}

class _AttendanceSetupScreenState extends State<AttendanceSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AttendanceProvider>().initSetup();
    });
  }

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Future<void> _pickOption(
    String title,
    List<String> options,
    String? current,
    ValueChanged<String> onSelected,
  ) async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.heading),
              const SizedBox(height: 8),
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No options available yet. Check the Date — or '
                          'ask the admin to schedule this lecture.',
                          style: AppTypography.helper,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final String option in options)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            current == option
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: current == option
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                          title: Text(option, style: AppTypography.body),
                          onTap: () => Navigator.of(context).pop(option),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      onSelected(result);
    }
  }

  Future<void> _pickDate() async {
    final AttendanceProvider p = context.read<AttendanceProvider>();
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: p.date ?? now,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      await p.setDate(picked);
    }
  }

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final AttendanceProvider p = context.watch<AttendanceProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Take Attendance'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => p.loadLectures(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SelectionTile(
                        icon: Icons.domain_outlined,
                        label: 'Department',
                        value: p.department,
                        locked: true,
                      ),
                      const SizedBox(height: 12),
                      SelectionTile(
                        icon: Icons.account_tree_outlined,
                        label: 'Branch',
                        value: p.branch,
                        onTap: () => _pickOption(
                          'Branch',
                          p.department == null
                              ? const <String>[]
                              : <String>[p.department!],
                          p.branch,
                          p.selectBranch,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectionTile(
                        icon: Icons.menu_book_outlined,
                        label: 'Subject',
                        value: p.subject,
                        onTap: () => _pickOption(
                          'Subject',
                          p.subjectOptions,
                          p.subject,
                          p.selectSubject,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectionTile(
                        icon: Icons.school_outlined,
                        label: 'Class / Semester',
                        value: p.className,
                        onTap: () => _pickOption(
                          'Class / Semester',
                          p.subject == null
                              ? p.allClassOptions
                              : p.classOptions,
                          p.className,
                          p.pickClass,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectionTile(
                        icon: Icons.videocam_outlined,
                        label: 'Lecture / Lab',
                        value: p.mode,
                        onTap: () => _pickOption(
                          'Lecture / Lab',
                          const ['Lecture', 'Lab'],
                          p.mode,
                          p.selectMode,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectionTile(
                        icon: Icons.meeting_room_outlined,
                        label: 'Room / Lab',
                        value: p.room,
                        onTap: () => _pickOption(
                          'Room / Lab',
                          p.className == null
                              ? p.allRoomOptions
                              : p.roomOptions,
                          p.room,
                          p.pickRoom,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectionTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: p.date == null ? null : _fmtDate(p.date!),
                        onTap: _pickDate,
                        placeholder: 'Select date',
                      ),
                      if (p.lecturesError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          p.lecturesError!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Attendance start time is captured automatically '
                              'from your first classroom photo.',
                              style: AppTypography.helper,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                AppSpacing.bottomCta,
              ),
              child: PrimaryButton(
                label: 'Next',
                onPressed: p.setupComplete
                    ? () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.photoCapture)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
