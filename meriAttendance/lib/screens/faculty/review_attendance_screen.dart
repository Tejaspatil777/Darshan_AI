import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/capture_widgets.dart';
import '../../core/widgets/list_items.dart';
import '../../core/widgets/states.dart';
import '../../data/models/attendance.dart';
import '../../data/models/user.dart';
import '../../routing/app_router.dart';
import '../../state/attendance_provider.dart';

/// Review Attendance: Present / Unknown / Not Seen tabs, search, unknown-face
/// identification and final confirmation (blocked while unknowns remain).
class ReviewAttendanceScreen extends StatefulWidget {
  const ReviewAttendanceScreen({super.key});

  @override
  State<ReviewAttendanceScreen> createState() => _ReviewAttendanceScreenState();
}

class _ReviewAttendanceScreenState extends State<ReviewAttendanceScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesQuery(String name, String id) {
    final String q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || id.toLowerCase().contains(q);
  }

  Future<void> _confirm() async {
    final AttendanceProvider p = context.read<AttendanceProvider>();
    if (!p.canConfirm) return;
    try {
      await p.confirm();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.sessionComplete);
  }

  /// Faculty authority: manually mark a not-seen student present.
  void _markPresent(Student s) {
    try {
      context.read<AttendanceProvider>().markPresentManually(s.id);
      showSnack(context, '${s.name} marked present.');
    } catch (e) {
      showSnack(context, friendlyError(e), error: true);
    }
  }

  /// Faculty authority: mark a present student absent.
  void _markAbsent(Student s) {
    try {
      context.read<AttendanceProvider>().markAbsentManually(s.id);
      showSnack(context, '${s.name} marked absent.');
    } catch (e) {
      showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceProvider p = context.watch<AttendanceProvider>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppHeader(
          title: 'Review Attendance',
          bottom: TabBar(
            tabs: [
              Tab(text: 'Present (${p.present.length})'),
              Tab(text: 'Unknown (${p.unknownRemaining})'),
              Tab(text: 'Not Seen (${p.notSeen.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: AppTextField(
                controller: _search,
                hint: 'Search students',
                prefixIcon: Icons.search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPresent(p),
                  _buildUnknown(p),
                  _buildNotSeen(p),
                ],
              ),
            ),
            _buildBottomBar(context, p),
          ],
        ),
      ),
    );
  }

  Widget _buildPresent(AttendanceProvider p) {
    if (p.present.isEmpty) {
      return const EmptyState(
        icon: Icons.group_outlined,
        title: 'No students yet',
        message: 'Identified students will appear here.',
      );
    }
    final List<Student> items = p.present
        .where((s) => _matchesQuery(s.name, s.id))
        .toList();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Tap the icon to mark a student absent.',
                style: AppTypography.helper),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int i) {
              final Student s = items[i];
              final bool aiMatch = p.matches.containsKey(s.id);
              return StudentListTile(
                name: s.name,
                subtitle: aiMatch
                    ? '${s.id} · AI match ${p.matchPercentFor(s)?.toStringAsFixed(0) ?? 0}%'
                    : '${s.id} · Marked by faculty',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GreenCheck(),
                    const SizedBox(width: 2),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Mark absent',
                      icon: const Icon(Icons.person_remove_outlined,
                          size: 20, color: AppColors.error),
                      onPressed: () => _markAbsent(s),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnknown(AttendanceProvider p) {
    if (p.unknownFaces.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'No unknown faces',
        message: 'All detected faces were identified.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: p.unknownFaces.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int i) {
        final UnknownFace f = p.unknownFaces[i];
        final Student? resolved = p.resolvedStudentOf(f);
        // The backend does not provide a detection timestamp; show the
        // source photo index instead of inventing one.
        final String time = f.capturedAt != null
            ? '${f.capturedAt!.hour.toString().padLeft(2, '0')}:'
                '${f.capturedAt!.minute.toString().padLeft(2, '0')}'
            : (f.photoIdx != null ? 'Photo ${f.photoIdx! + 1}' : 'Classroom photo');
        if (f.resolved && resolved != null) {
          return StudentListTile(
            leading: const AvatarPlaceholder(
                icon: Icons.person_search_outlined),
            name: 'Unknown face ${i + 1}',
            subtitle: 'Detected at $time · ${resolved.name}',
            trailing: const _GreenCheck(),
          );
        }
        return StudentListTile(
          leading: const AvatarPlaceholder(
              icon: Icons.person_search_outlined),
          name: 'Unknown face ${i + 1}',
          subtitle: 'Detected at $time',
          onTap: () => _identifySheet(context, f),
          trailing: TextButton(
            onPressed: () => _identifySheet(context, f),
            child: const Text('Identify'),
          ),
        );
      },
    );
  }

  Widget _buildNotSeen(AttendanceProvider p) {
    if (p.notSeen.isEmpty) {
      return const EmptyState(
        icon: Icons.group_off_outlined,
        title: 'Everyone was detected',
        message: 'All roster students were seen in the photos.',
      );
    }
    final List<Student> items = p.notSeen
        .where((s) => _matchesQuery(s.name, s.id))
        .toList();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Missed in the photos? Mark a student present.',
                style: AppTypography.helper),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int i) {
              final Student s = items[i];
              return StudentListTile(
                name: s.name,
                subtitle: s.id,
                onTap: () => _markPresent(s),
                trailing: TextButton(
                  onPressed: () => _markPresent(s),
                  child: const Text('Mark Present'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, AttendanceProvider p) {
    final int remaining = p.unknownRemaining;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, AppSpacing.bottomCta),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (remaining > 0) ...[
            Text(
              'Resolve $remaining unknown face${remaining == 1 ? '' : 's'} '
              'before confirming.',
              style: AppTypography.caption.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: 8),
          ],
          PrimaryButton(
            label: 'Confirm Attendance',
            loading: p.confirming,
            onPressed: p.canConfirm ? _confirm : null,
          ),
        ],
      ),
    );
  }

  /// Unknown-face identification flow: face crop preview -> search the class
  /// roster -> Mark Present -> back to review.
  void _identifySheet(BuildContext context, UnknownFace face) {
    String query = '';
    Student? selected;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final AttendanceProvider p = context.read<AttendanceProvider>();
        final Set<String> presentIds =
            p.present.map((Student s) => s.id).toSet();
        final List<Student> candidates = p.roster
            .where((Student s) =>
                !presentIds.contains(s.id) &&
                (query.isEmpty ||
                    s.name.toLowerCase().contains(query) ||
                    s.id.toLowerCase().contains(query)))
            .toList();

        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
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
                      const FaceCropPreview(size: 90),
                      const SizedBox(height: 10),
                      Text('Unknown face', style: AppTypography.heading),
                      Text('Select the matching student from the roster',
                          style: AppTypography.caption),
                      const SizedBox(height: 16),
                      AppTextField(
                        hint: 'Search students',
                        prefixIcon: Icons.search,
                        onChanged: (v) =>
                            setSheetState(() => query = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: candidates.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No matching students found.',
                                  style: AppTypography.caption,
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: candidates.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (BuildContext ctx, int i) {
                                  final Student s = candidates[i];
                                  return StudentListTile(
                                    name: s.name,
                                    subtitle: s.id,
                                    highlighted: selected?.id == s.id,
                                    onTap: () =>
                                        setSheetState(() => selected = s),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Mark Present',
                        onPressed: selected == null
                            ? null
                            : () {
                                try {
                                  p.resolveUnknown(face.id, selected!.id);
                                  Navigator.of(sheetContext).pop();
                                  showSnack(context,
                                      '${selected!.name} marked present.');
                                } catch (e) {
                                  showSnack(context, friendlyError(e),
                                      error: true);
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GreenCheck extends StatelessWidget {
  const _GreenCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 16, color: Colors.white),
    );
  }
}
