import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:meritendance/core/network/api_client.dart';
import 'package:meritendance/core/network/token_store.dart';

/// Regression tests for the HTTP wiring. In particular: JSON bodies must be
/// sent with an explicit `Content-Type: application/json` header. Dart's http
/// package otherwise defaults to `text/plain;charset=utf-8`, which the Spring
/// Boot backend rejects for @RequestBody DTOs (misleading 500 / 415).
void main() {
  group('ApiClient request headers', () {
    test('login sends Content-Type: application/json', () async {
      String? sentContentType;
      final http.Client inner = MockClient((http.Request request) async {
        sentContentType = request.headers['content-type'];
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'status': 200,
            'code': 'OK',
            'data': <String, dynamic>{
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'role': 'STUDENT',
              'userId': 'u-1',
              'username': 'tejas@demo.edu',
              'passwordChangeRequired': false,
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      final ApiClient client = ApiClient(TokenStore(), inner: inner);
      final dynamic data = await client.post(
        '/api/auth/login',
        auth: false,
        body: <String, String>{
          'username': 'tejas@demo.edu',
          'password': 'secret',
        },
      );

      // The whole point: no text/plain fallback, or Spring answers 415/500.
      expect(sentContentType, 'application/json');
      // The uniform ApiResponse envelope is unwrapped to the auth DTO.
      expect(data['accessToken'], 'access-token');
    });
  });
}