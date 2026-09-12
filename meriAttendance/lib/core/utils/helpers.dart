import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../widgets/buttons.dart';

/// Confirms logout with a dialog. Returns true when the user confirms.
Future<bool> confirmLogout(BuildContext context) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        'You will need to sign in again to use DarshanAI.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Friendly "forgot password" sheet (admin-managed in the real flow).
void showForgotPasswordSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forgot password?', style: AppTypography.heading),
            const SizedBox(height: 8),
            Text(
              'Password resets are handled by your college administrator. '
              'Please contact the admin office to reset your password.',
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a friendly floating snackbar.
void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.textPrimary,
    ),
  );
}

/// Maps any exception to a human-friendly message (never raw API errors).
String friendlyError(Object error) => 'Something went wrong. Please try again.';
