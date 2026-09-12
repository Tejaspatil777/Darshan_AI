import '../../models/user.dart';
import '../repositories.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_store.dart';

/// Real authentication repository backed by the Spring Boot API.
///
/// - login ......... POST /api/auth/login   {username, password}  (no Bearer)
/// - first-login ... POST /api/auth/first-login {newPassword} (Bearer from
///                   login; backend returns a FRESH token pair)
/// - password ...... PUT  /api/auth/password (Bearer; revokes all sessions)
/// - logout ........ POST /api/auth/logout {refreshToken} (Bearer)
/// - restore ....... GET  /api/users/me (Bearer, with transparent refresh)
///
/// The role ALWAYS comes from the backend (AuthResponse.role).
/// Tokens are persisted in [TokenStore]; nothing is ever logged.
class AuthApiRepository implements AuthRepository {
  AuthApiRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  // ------------------------------------------------------------- login

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final dynamic data = await _client.post(
      '/api/auth/login',
      auth: false, // login must never carry an Authorization header
      body: <String, String>{
        'username': username.trim(),
        'password': password,
      },
    );
    _assertAuthResponse(data);
    await _tokens.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String?,
    );
    return _userFromAuth(data);
  }

  // -------------------------------------------------------- first login

  @override
  Future<AppUser> completeFirstLogin({required String newPassword}) async {
    // Uses the authenticated JWT returned by login — the backend identifies
    // the user from the token, so no ID/email re-entry happens here.
    final dynamic data = await _client.post(
      '/api/auth/first-login',
      body: <String, String>{'newPassword': newPassword},
    );
    _assertAuthResponse(data);
    // Fresh token pair: store it and continue straight into the app.
    await _tokens.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String?,
    );
    return _userFromAuth(data);
  }

  // ---------------------------------------------------- change password

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.put(
      '/api/auth/password',
      body: <String, String>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    // The backend revokes every refresh token for the user on success.
    // The still-valid access token keeps this session alive; the next
    // refresh attempt will direct the user back to Login.
    await _tokens.clearRefreshToken();
  }

  // ------------------------------------------------------------- logout

  @override
  Future<void> logout() async {
    final String? refresh = _tokens.refreshToken;
    try {
      if (refresh != null) {
        await _client.post(
          '/api/auth/logout',
          body: <String, String>{'refreshToken': refresh},
        );
      }
    } on AppException {
      // Logout must always succeed locally, even if the server already
      // revoked the token or is unreachable.
    } finally {
      await _tokens.clear();
    }
  }

  // ------------------------------------------------------------ session

  @override
  Future<void> saveSession(AppUser user) async {
    // Tokens are already persisted by login/first-login; nothing else to do.
  }

  @override
  Future<AppUser?> restoreSession() async {
    if (_tokens.accessToken == null && _tokens.refreshToken == null) {
      return null;
    }
    try {
      final dynamic me = await _client.get('/api/users/me');
      if (me is! Map<String, dynamic>) return null;
      final String? userId = _string(me['userId']);
      if (userId == null) return null;
      return AppUser(
        id: userId,
        username: _string(me['username']) ?? '',
        email: _string(me['email']),
        role: userRoleFromApi(_string(me['role'])),
        forcePasswordChange: me['passwordChangeRequired'] == true,
      );
    } on AppException {
      // Invalid/expired session (refresh already handled by the client).
      await _tokens.clear();
      return null;
    }
  }

  // ------------------------------------------------------------ helpers

  AppUser _userFromAuth(Map<String, dynamic> data) {
    return AppUser(
      id: _string(data['userId']) ?? '',
      username: _string(data['username']) ?? '',
      role: userRoleFromApi(_string(data['role'])),
      forcePasswordChange: data['passwordChangeRequired'] == true,
    );
  }

  void _assertAuthResponse(dynamic data) {
    if (data is! Map<String, dynamic> || data['accessToken'] is! String) {
      throw AppException('The server returned an unexpected response.');
    }
  }

  String? _string(dynamic value) =>
      value is String && value.isNotEmpty ? value : null;
}
