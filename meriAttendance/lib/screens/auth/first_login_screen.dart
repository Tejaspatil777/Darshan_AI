import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/helpers.dart';
import '../../data/repositories/repositories.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../routing/app_router.dart';
import '../../state/auth_provider.dart';

/// First login / forced "Create New Password" screen.
/// After success the user goes straight to the dashboard (fresh session,
/// no re-login), matching the documented token flow.
class FirstLoginScreen extends StatefulWidget {
  const FirstLoginScreen({super.key});

  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> {
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _hasUppercase(String v) => v.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String v) => v.contains(RegExp(r'[a-z]'));
  bool _hasDigit(String v) => v.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String v) => v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]]'));

  bool _ruleValid(bool Function(String) rule) => rule(_new.text);

  bool get _allRulesValid =>
      _new.text.length >= 8 &&
      _hasUppercase(_new.text) &&
      _hasLowercase(_new.text) &&
      _hasDigit(_new.text) &&
      _hasSpecial(_new.text);

  bool get _passwordsMatch =>
      _confirm.text.isNotEmpty && _new.text == _confirm.text;

  bool get _canSubmit => _allRulesValid && _passwordsMatch && !_loading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().completeFirstLogin(_new.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppException ? e.message : friendlyError(e);
      });
      return;
    }
    if (!mounted) return;
    final AuthProvider auth = context.read<AuthProvider>();
    Navigator.of(context).pushNamedAndRemoveUntil(
      auth.isFaculty ? AppRoutes.facultyDashboard : AppRoutes.studentDashboard,
      (Route<dynamic> r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Create New Password'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              AppTextField(
                controller: _new,
                hint: 'New Password',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _confirm,
                hint: 'Confirm Password',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (!_passwordsMatch && _confirm.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Passwords do not match.',
                  style: TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 20),
              _ruleRow('Minimum 8 characters', _new.text.length >= 8),
              _ruleRow('At least one uppercase letter', _ruleValid(_hasUppercase)),
              _ruleRow('At least one lowercase letter', _ruleValid(_hasLowercase)),
              _ruleRow('At least one number', _ruleValid(_hasDigit)),
              _ruleRow('At least one special character', _ruleValid(_hasSpecial)),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Update Password',
                loading: _loading,
                onPressed: _canSubmit ? _submit : null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleRow(String label, bool valid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 20,
            color: valid ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: valid
                ? AppTypography.caption
                    .copyWith(color: AppColors.textPrimary)
                : AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
