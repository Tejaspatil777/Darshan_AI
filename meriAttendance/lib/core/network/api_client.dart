import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../data/repositories/repositories.dart';
import 'api_config.dart';
import 'token_store.dart';

/// Thrown for every non-2xx response / transport failure. Carries the backend
/// error envelope's stable `code` and the HTTP status so callers can react
/// (e.g. 409 session-immutable) without parsing human-readable text.
class ApiError extends AppException {
  ApiError(this.status, this.code, String message) : super(message);

  final int status;
  final String? code;

  factory ApiError.fromEnvelope(Map<String, dynamic> envelope) {
    final int status = (envelope['status'] as num?)?.toInt() ?? 500;
    final String? code = envelope['code'] as String?;
    final String message = (envelope['message'] as String?) ??
        (envelope['description'] as String?) ??
        'The request could not be completed.';
    return ApiError(status, code, message);
  }
}

/// HTTP client for the Darshan Spring Boot API.
///
/// Contract highlights (verified from backend source):
/// - `/api/auth/login` and `/api/auth/refresh` are public: NO Authorization
///   header is ever attached to them.
/// - Every other request carries `Authorization: Bearer <accessToken>`.
/// - On 401 the client refreshes the token pair ONCE (rotating refresh: the
///   presented token is revoked server-side) and retries the original request
///   with the `X-DarshanAI-Retry: 1` marker, which the backend CORS
///   configuration pre-approves.
/// - If the refresh fails, the TokenStore is cleared and [onSessionExpired]
///   fires so the app returns to the Login screen (no refresh loops).
/// - Auth/enroll/session endpoints return RAW DTOs; logout and password
///   change return the uniform `ApiResponse` envelope. Both are handled.
class ApiClient {
  ApiClient(
    this._tokens, {
    String? baseUrl,
    http.Client? inner,
  })  : baseUrl = normalizeBaseUrl(baseUrl ?? kDarshanApiUrl),
        _inner = inner ?? http.Client();

  static const String retryHeader = 'X-DarshanAI-Retry';

  final TokenStore _tokens;
  final String baseUrl;
  final http.Client _inner;

  /// Invoked after a failed refresh: the store is already cleared, the app
  /// must drop in-memory auth state and return to the Login screen.
  void Function()? onSessionExpired;

  static const Duration _defaultTimeout = Duration(seconds: 60);
  static const Duration _uploadTimeout = Duration(minutes: 3);

  // ------------------------------------------------------------------ verbs

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) =>
      _jsonCall(
        (headers) =>
            _inner.get(_uri(path, query), headers: headers).timeout(_defaultTimeout),
        auth: auth,
        path: path,
      );

  /// Fetches raw bytes (e.g. GET /api/crops/{faceId} -> image/jpeg).
  Future<List<int>> getBytes(String path, {bool auth = true}) async {
    final http.Response response = await _withAuth(
      (headers, retried) =>
          _inner.get(_uri(path), headers: headers).timeout(_defaultTimeout),
      auth: auth,
      path: path,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw _errorFor(response, path);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    bool auth = true,
    Duration? timeout,
  }) =>
      _jsonCall(
        (headers) => _inner
            .post(_uri(path),
                headers: headers,
                body: body == null ? null : jsonEncode(body))
            .timeout(timeout ?? _defaultTimeout),
        auth: auth,
        path: path,
      );

  Future<dynamic> put(
    String path, {
    Object? body,
    bool auth = true,
  }) =>
      _jsonCall(
        (headers) => _inner
            .put(_uri(path),
                headers: headers,
                body: body == null ? null : jsonEncode(body))
            .timeout(_defaultTimeout),
        auth: auth,
        path: path,
      );

  Future<dynamic> patch(
    String path, {
    Object? body,
    bool auth = true,
  }) =>
      _jsonCall(
        (headers) => _inner
            .patch(_uri(path),
                headers: headers,
                body: body == null ? null : jsonEncode(body))
            .timeout(_defaultTimeout),
        auth: auth,
        path: path,
      );

  // --------------------------------------------------------------- internals

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<dynamic> _jsonCall(
    Future<http.Response> Function(Map<String, String> headers) attempt, {
    required bool auth,
    required String path,
  }) async {
    final http.Response response = await _withAuth(
      (headers, retried) => attempt(headers),
      auth: auth,
      path: path,
    );
    return _handleResponse(response, path);
  }

  /// Runs [attempt], transparently performing one refresh+retry on 401.
  Future<http.Response> _withAuth(
    Future<http.Response> Function(Map<String, String> headers, bool retried)
        attempt, {
    required bool auth,
    required String path,
  }) async {
    Map<String, String> headers({bool retried = false}) => <String, String>{
          'Accept': 'application/json',
          // JSON bodies (login, first-login, logout, password, enrollment,
          // resolveUnknown, confirm) must declare their media type explicitly.
          // Dart's http package otherwise defaults to text/plain;charset=utf-8,
          // which Spring rejects for @RequestBody -> misleading 500s.
          'Content-Type': 'application/json',
          if (retried) retryHeader: '1',
          if (auth && _tokens.accessToken != null)
            'Authorization': 'Bearer ${_tokens.accessToken}',
        };

    http.Response response = await _guard(attempt(headers(), false), path);

    if (response.statusCode == 401 && auth) {
      final bool refreshed = await refreshTokens();
      if (refreshed) {
        response = await _guard(attempt(headers(retried: true), true), path);
      }
    }
    return response;
  }

  /// Multipart POST (attendance session creation -> HTTP 202).
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String> fields = const <String, String>{},
    required List<http.MultipartFile> files,
  }) async {
    Future<http.Response> build(bool retried) async {
      final http.MultipartRequest request =
          http.MultipartRequest('POST', _uri(path))
            ..fields.addAll(fields)
            ..files.addAll(files)
            ..headers.addAll(<String, String>{
              'Accept': 'application/json',
              if (retried) retryHeader: '1',
              if (_tokens.accessToken != null)
                'Authorization': 'Bearer ${_tokens.accessToken}',
            });
      final http.StreamedResponse streamed =
          await _inner.send(request).timeout(_uploadTimeout);
      return http.Response.fromStream(streamed);
    }

    http.Response response = await _guard(build(false), path);
    if (response.statusCode == 401) {
      final bool refreshed = await refreshTokens();
      if (refreshed) {
        response = await _guard(build(true), path);
      }
    }
    return _handleResponse(response, path);
  }

  /// POST /api/auth/refresh (no Authorization header). Rotating refresh:
  /// on success the NEW pair replaces the stored one.
  Future<bool> refreshTokens() async {
    final String? refresh = _tokens.refreshToken;
    if (refresh == null) {
      await _expireSession();
      return false;
    }
    try {
      final http.Response response = await _inner
          .post(
            _uri('/api/auth/refresh'),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{'refreshToken': refresh}),
          )
          .timeout(_defaultTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = _decode(response.body);
        if (data is Map<String, dynamic> && data['accessToken'] is String) {
          await _tokens.save(
            accessToken: data['accessToken'] as String,
            refreshToken: data['refreshToken'] as String?,
          );
          return true;
        }
      }
    } on TimeoutException {
      // Cannot recover the session right now.
    } on SocketException {
      // Cannot reach the server.
    } catch (_) {
      // Any other refresh failure ends the session.
    }
    await _expireSession();
    return false;
  }

  Future<void> _expireSession() async {
    await _tokens.clear();
    onSessionExpired?.call();
  }

  Future<http.Response> _guard(
    Future<http.Response> future,
    String path,
  ) async {
    try {
      return await future;
    } on TimeoutException {
      throw ApiError(
          0,
          'TIMEOUT',
          'The server took too long to respond ($path).\n'
          'Check your internet, then make sure this PC: WiFi is on and the '
          'phone is on the SAME network. No reply means the request never '
          'reached the server - rebuild the app with '
          '--dart-define=DARSHAN_API_URL=http://<PC-current-IPv4>:8000 and '
          'verify http://<PC-IPv4>:8000/actuator/health opens on the phone.');
    } on SocketException {
      throw ApiError(
          0,
          'CONNECTION_FAILED',
          'Cannot reach the DarshanAI server ($baseUrl). Check that it is '
          'running on this PC and that DARSHAN_API_URL (built into the app) '
          'points to the PC\'s current LAN IPv4.');
    } on http.ClientException {
      throw ApiError(0, 'CONNECTION_FAILED',
          'Cannot reach the DarshanAI server ($baseUrl). Please try again.');
    }
  }

  dynamic _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// 2xx: unwraps the `ApiResponse` envelope when present, otherwise returns
  /// the raw DTO. Non-2xx: throws [ApiError] built from the error envelope.
  dynamic _handleResponse(http.Response response, String path) {
    final dynamic json = _decode(response.body);
    final bool isEnvelope =
        json is Map<String, dynamic> && json.containsKey('success');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (isEnvelope) {
        if (json['success'] == true) return json['data'];
        throw ApiError.fromEnvelope(json);
      }
      return json;
    }

    if (isEnvelope && json['success'] == false) {
      throw ApiError.fromEnvelope(json);
    }
    throw _errorFor(response, path);
  }

  ApiError _errorFor(http.Response response, String path) {
    final String fallback = switch (response.statusCode) {
      400 => 'The request was not valid. Please check your input.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested item was not found.',
      409 => 'This action conflicts with the current state. Please try again.',
      422 => 'Some of the submitted data was rejected. Please review and retry.',
      500 => 'An unexpected server error occurred. Please try again.',
      502 =>
        'The AI service is currently unavailable. Please try again shortly.',
      504 => 'An external service timed out. Please try again shortly.',
      _ =>
        'The request failed (HTTP ${response.statusCode}). Please try again.',
    };
    final dynamic json = _decode(response.body);
    if (json is Map<String, dynamic>) {
      return ApiError.fromEnvelope(<String, dynamic>{
        'status': response.statusCode,
        ...json,
      });
    }
    return ApiError(response.statusCode, null, fallback);
  }
}
