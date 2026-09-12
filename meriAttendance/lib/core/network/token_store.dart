import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT access + refresh tokens locally.
///
/// SECURITY (task rule 26): tokens are never logged, never printed, and are
/// only sent to the configured Spring Boot backend as `Authorization: Bearer`.
class TokenStore {
  static const String _kAccess = 'darshan.auth.access_token';
  static const String _kRefresh = 'darshan.auth.refresh_token';

  String? accessToken;
  String? refreshToken;

  /// Loads persisted tokens (call once during app bootstrap).
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_kAccess);
    refreshToken = prefs.getString(_kRefresh);
  }

  /// Saves a fresh token pair (login / refresh / first-login responses).
  Future<void> save({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    if (accessToken == null) {
      await prefs.remove(_kAccess);
    } else {
      await prefs.setString(_kAccess, accessToken);
    }
    if (refreshToken == null) {
      await prefs.remove(_kRefresh);
    } else {
      await prefs.setString(_kRefresh, refreshToken);
    }
  }

  /// Removes the revoked refresh token (e.g. after PUT /api/auth/password,
  /// which revokes every session server-side) while keeping the still-valid
  /// access token for the current screen flow.
  Future<void> clearRefreshToken() => save(
        accessToken: accessToken,
        refreshToken: null,
      );

  /// Clears everything (logout / refresh failure -> back to Login).
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }
}
