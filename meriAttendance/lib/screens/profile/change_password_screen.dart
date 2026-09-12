import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../data/repositories/repositories.dart';
import '../../state/auth_provider.dart';

/// Change password for the signed-in user (student or faculty).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _hasUppercase(String v) => v.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String v) => v.contains(RegExp(r'[a-z]'));
  bool _hasDigit(String v) => v.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String v) =>
      v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]]'));

  bool get _newValid =>
      _new.text.length >= 8 &&
      _hasUppercase(_new.text) &&
      _hasLowercase(_new.text) &&
      _hasDigit(_new.text) &&
      _hasSpecial(_new.text);

  bool get _canSubmit =>
      _current.text.isNotEmpty &&
      _newValid &&
      _confirm.text == _new.text &&
      !_loading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppException ? e.message : friendlyError(e);
      });
      return;
    }
    if (!mounted) return;
    showSnack(context, 'Password updated successfully.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Change Password'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              AppTextField(
                controller: _current,
                hint: 'Current Password',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
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
                hint: 'Confirm New Password',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_confirm.text.isNotEmpty && _confirm.text != _new.text)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('Passwords do not match.',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.error)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.error)),
                ),
              const SizedBox(height: 20),
              _rule('Minimum 8 characters', _new.text.length >= 8),
              _rule('At least one uppercase letter', _hasUppercase(_new.text)),
              _rule('At least one lowercase letter', _hasLowercase(_new.text)),
              _rule('At least one number', _hasDigit(_new.text)),
              _rule('At least one special character', _hasSpecial(_new.text)),
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

  Widget _rule(String label, bool valid) {
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
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}
