/// Meritendance design tokens: colors, spacing, radii and typography.
/// Single source of truth — screens must use these, not raw values.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFF43F5E);
  static const Color primaryPressed = Color(0xFFE11D48);
  static const Color primarySoft = Color(0xFFFFE4E9);

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9FAFB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFD1D5DB);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color disabled = Color(0xFFE5E7EB);
  static const Color disabledText = Color(0xFF9CA3AF);

  // Demo camera placeholder tones
  static const Color cameraBg = Color(0xFFE9ECEF);
  static const Color avatarBg = Color(0xFFE9ECEF);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Standard horizontal screen padding.
  static const double screenH = xl;

  /// Bottom padding above the nav area for primary CTAs.
  static const double bottomCta = xxl;
}

class AppRadius {
  AppRadius._();

  static const double card = 12;
  static const double button = 10;
  static const double input = 10;
  static const double thumb = 8;
  static const double sheet = 20;
  static const double preview = 20;

  static BorderRadius get cardBox => BorderRadius.circular(card);
  static BorderRadius get buttonBox => BorderRadius.circular(button);
  static BorderRadius get inputBox => BorderRadius.circular(input);
  static BorderRadius get thumbBox => BorderRadius.circular(thumb);
  static BorderRadius get previewBox => BorderRadius.circular(preview);
  static BorderRadius get sheetBox =>
      BorderRadius.vertical(top: Radius.circular(sheet));
}

class AppTypography {
  AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle helper = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.textTertiary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}
