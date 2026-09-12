import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../data/models/user.dart';
import '../data/repositories/repositories.dart';

enum AuthStatus { loading, unauthenticated, firstLoginRequired, authenticated }

/// Holds authentication/session state and the signed-in user's profile.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo, this._studentRepo, this._facultyRepo,
      [ApiClient? apiClient]) {
    // When the refresh flow fails (expired/revoked session), the API client
    // clears the TokenStore and tells us to drop all in-memory auth state.
    apiClient?.onSessionExpired = _onSessionExpired;
  }

  final AuthRepository _repo;
  final StudentRepository _studentRepo;
  final FacultyRepository _facultyRepo;

  AuthStatus status = AuthStatus.loading;
  AppUser? user;
  Student? studentProfile;
  Faculty? facultyProfile;

  bool get isStudent => user?.role == UserRole.student;
  bool get isFaculty => user?.role == UserRole.faculty;

  void _onSessionExpired() {
    user = null;
    studentProfile = null;
    facultyProfile = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      final AppUser? restored = await _repo.restoreSession();
      if (restored == null) {
        user = null;
        status = AuthStatus.unauthenticated;
      } else {
        user = restored;
        if (restored.forcePasswordChange) {
          status = AuthStatus.firstLoginRequired;
        } else {
          await _loadProfile();
          status = AuthStatus.authenticated;
        }
      }
    } catch (_) {
      user = null;
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final AppUser u = await _repo.login(
      username: usernameOrEmail,
      password: password,
    );
    if (u.forcePasswordChange) {
      user = u;
      status = AuthStatus.firstLoginRequired;
      notifyListeners();
      return;
    }
    await _finishLogin(u);
  }

  /// POST /api/auth/first-login using the JWT from login. The backend
  /// returns a fresh token pair, so the user continues straight into the app.
  Future<void> completeFirstLogin(String newPassword) async {
    final AppUser u = await _repo.completeFirstLogin(newPassword: newPassword);
    await _finishLogin(u);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> _finishLogin(AppUser u) async {
    user = u;
    await _loadProfile();
    await _repo.saveSession(u);
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final AppUser current = user!;
    if (current.role == UserRole.student) {
      studentProfile = await _studentRepo.getStudentProfile(current.id);
    } else {
      facultyProfile = await _facultyRepo.getFacultyProfile(current.id);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    user = null;
    studentProfile = null;
    facultyProfile = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

