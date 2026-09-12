import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cards.dart';

/// Profile info row: leading icon, small label, value.
class ProfileInfoTile extends StatelessWidget {
  const ProfileInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.helper),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Roster/review row: avatar placeholder, name, subtitle, trailing status.
class StudentListTile extends StatelessWidget {
  const StudentListTile({
    super.key,
    required this.name,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
    this.highlighted = false,
  });

  final String name;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: highlighted ? AppColors.primary : AppColors.border,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          leading ?? const AvatarPlaceholder(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.helper),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Circular grey avatar placeholder with a person outline icon.
class AvatarPlaceholder extends StatelessWidget {
  const AvatarPlaceholder({super.key, this.size = 40, this.icon});

  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.avatarBg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? Icons.person_outline,
        size: size * 0.58,
        color: AppColors.textTertiary,
      ),
    );
  }
}

/// Small rounded status pill (e.g. "Enrolled", "Student").
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.background = AppColors.primarySoft,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.helper.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
