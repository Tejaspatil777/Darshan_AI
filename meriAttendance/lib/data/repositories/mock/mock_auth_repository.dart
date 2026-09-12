import 'package:shared_preferences/shared_preferences.dart';

import '../repositories.dart';
import '../../models/user.dart';
import 'demo_data.dart';

/// Demo auth repository. Simulates the Spring Boot auth endpoints with local
/// state + SharedPreferences so the flow is fully testable offline.
///
/// Replace with a real API implementation later — screens never touch this
/// class directly, only [AuthRepository].
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 800)});

  final Duration latency;

  /// Accounts keyed by email (usernames are mapped in [_resolve]).
  final Map<String, _DemoAccount> _accounts = <String, _DemoAccount>{
    DemoData.demoStudentEmail: _DemoAccount(
      id: DemoData.demoStudent.id,
      email: DemoData.demoStudentEmail,
      password: DemoData.demoStudentPassword,
      role: UserRole.student,
      forcePasswordChange: true,
    ),
    DemoData.demoFacultyEmail: _DemoAccount(
      id: DemoData.demoFaculty.id,
      email: DemoData.demoFacultyEmail,
      password: DemoData.demoFacultyPassword,
      role: UserRole.faculty,
      forcePasswordChange: false,
    ),
  };

  static const Map<String, String> _usernames = <String, String>{
    '21bcs001': DemoData.demoStudentEmail,
    'student': DemoData.demoStudentEmail,
    'faccs012': DemoData.demoFacultyEmail,
    'faculty': DemoData.demoFacultyEmail,
  };

  Future<void> _wait() => Future<void>.delayed(latency);

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  _DemoAccount _resolve(String usernameOrEmail) {
    final String key = usernameOrEmail.trim().toLowerCase();
    final String email = _usernames[key] ?? key;
    final _DemoAccount? account = _accounts[email];
    if (account == null) {
      throw AppException('No account found for this email or username.');
    }
    return account;
  }

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    await _wait();
    final _DemoAccount account = _resolve(username);
    if (password != account.password) {
      throw AppException('Incorrect password. Please try again.');
    }
    return account.toUser();
  }

  @override
  Future<AppUser> completeFirstLogin({required String newPassword}) async {
    await _wait();
    // Demo: the current session user (in the real flow the JWT identifies
    // the user for POST /api/auth/first-login).
    final SharedPreferences prefs = await _prefs;
    final String? sessionEmail = prefs.getString(_kSessionEmail);
    _DemoAccount? account;
    for (final _DemoAccount a in _accounts.values) {
      if (a.email == sessionEmail) {
        account = a;
        break;
      }
    }
    account ??= _accounts.values.first;
    account
      ..password = newPassword
      ..forcePasswordChange = false;
    return account.toUser();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _wait();
    // Target the account that owns the current demo session.
    final SharedPreferences prefs = await _prefs;
    final String? sessionEmail = prefs.getString(_kSessionEmail);
    _DemoAccount? account;
    for (final _DemoAccount a in _accounts.values) {
      if (a.email == sessionEmail) {
        account = a;
        break;
      }
    }
    account ??= _accounts.values.first;
    if (currentPassword != account.password) {
      throw AppException('The current password is incorrect.');
    }
    account.password = newPassword;
  }

  @override
  Future<void> logout() async {
    await _wait();
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_kSessionEmail);
  }

  @override
  Future<AppUser?> restoreSession() async {
    final SharedPreferences prefs = await _prefs;
    final String? email = prefs.getString(_kSessionEmail);
    if (email == null) return null;
    final _DemoAccount? account = _accounts[email];
    if (account == null) return null;
    return account.toUser(forcePasswordChange: false);
  }

  /// Persists the demo session (token store equivalent).
  @override
  Future<void> saveSession(AppUser user) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_kSessionEmail, user.email ?? user.username);
  }

  static const String _kSessionEmail = 'demo.session.email';
}

class _DemoAccount {
  _DemoAccount({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
    required this.forcePasswordChange,
  });

  final String id;
  final String email;
  final UserRole role;
  String password;
  bool forcePasswordChange;

  AppUser toUser({bool? forcePasswordChange}) => AppUser(
        id: id,
        username: email,
        email: email,
        role: role,
        forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
      );
}
