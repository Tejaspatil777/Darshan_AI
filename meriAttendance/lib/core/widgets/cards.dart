import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Base card: white surface, thin light border, 12px radius, subtle tap.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.color,
    this.borderColor,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? AppRadius.cardBox;
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Dashboard row card: leading outline icon, label, trailing chevron.
class DashboardActionCard extends StatelessWidget {
  const DashboardActionCard({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.textPrimary),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: AppTypography.heading)),
          trailing ??
              const Icon(Icons.chevron_right,
                  size: 22, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// Selection row: leading icon, small label, selected value, chevron.
/// [locked] renders a read-only tile (grey fill, lock icon, no chevron).
class SelectionTile extends StatelessWidget {
  const SelectionTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.locked = false,
    this.placeholder = 'Select',
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool locked;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: locked ? null : onTap,
      color: locked ? AppColors.surfaceAlt : AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Icon(
            locked ? Icons.lock_outline : icon,
            size: 22,
            color: locked ? AppColors.textTertiary : AppColors.textSecondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.helper),
                const SizedBox(height: 2),
                Text(
                  value ?? placeholder,
                  style: value == null
                      ? AppTypography.bodySecondary
                      : AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!locked)
            const Icon(Icons.chevron_right,
                size: 22, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
