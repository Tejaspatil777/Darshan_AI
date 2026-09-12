import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/helpers.dart';
import '../../data/repositories/repositories.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/buttons.dart';
import '../../routing/app_router.dart';
import '../../state/auth_provider.dart';

/// Login screen: username/email + password, and first-login redirect handling.
/// Authentication always goes through POST /api/auth/login; the role comes
/// from the backend.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final String id = _email.text.trim();
    final String pass = _password.text;
    if (id.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter your email/username and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final AuthProvider auth = context.read<AuthProvider>();
    try {
      await auth.login(usernameOrEmail: id, password: pass);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppException ? e.message : friendlyError(e);
      });
      return;
    }
    if (!mounted) return;
    if (auth.status == AuthStatus.firstLoginRequired) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.firstLogin, (_) => false);
      return;
    }
    _goHome();
  }

  void _goHome() {
    final AuthProvider auth = context.read<AuthProvider>();
    Navigator.of(context).pushNamedAndRemoveUntil(
      auth.isFaculty ? AppRoutes.facultyDashboard : AppRoutes.studentDashboard,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Center(
                        child: BrandLogo(markSize: 64, showTagline: false),
                      ),
                      const SizedBox(height: 32),
                      AppTextField(
                        controller: _email,
                        hint: 'Email / Username',
                        prefixIcon: Icons.mail_outline,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _password,
                        hint: 'Password',
                        prefixIcon: Icons.lock_outline,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => showForgotPasswordSheet(context),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Login',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
