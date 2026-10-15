import 'dart:convert';
import 'package:unicore_mobile_app/services/device_resolver.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:unicore_mobile_app/models/attendance_location.dart';
import 'package:unicore_mobile_app/services/session_store.dart';

class ApiException implements Exception {
  const ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class UnicoreApi {
  UnicoreApi({
    SessionStore? store,
    http.Client Function()? clientFactory,
    this.auditEnabled = true,
  }) : _store = store ?? SecureSessionStore(),
       _clientFactory = clientFactory;
  static const baseUrl = 'https://unicore.systems/api/mobile';
  static const tenantId = 'tenant_65';
  static const auditServerUrl = 'https://13.214.2.6/api/logs';
  final bool auditEnabled;
  final SessionStore _store;
  final http.Client Function()? _clientFactory;
  String? _account, _password, _token, _uid, _lookupToken;
  String _platform = 'ios';
  String? _passwordSalt, _passwordDigest;
  Future<String>? _refreshing;
  Map<String, String>? approvedDevice;
  String? deviceError;
  String? get currentToken => _token;
  String? get account => _account;
  String _key(String account) =>
      'unicore.session.v2.$tenantId.${Uri.encodeComponent(account)}';

  Future<void> _save() async {
    await _store.write(
      _key(_account!),
      jsonEncode({
        'uid': _uid,
        'lookup_token': _lookupToken,
        'platform': _platform,
        'token': _token,
        'password_salt': _passwordSalt,
        'password_digest': _passwordDigest,
      }),
    );
    await _store.write('unicore.active.v2', _account!);
  }

  Future<void> _load(String account) async {
    _account = account;
    _uid = null;
    _lookupToken = null;
    _token = null;
    _platform = 'ios';
    _passwordSalt = _passwordDigest = null;
    approvedDevice = null;
    deviceError = null;
    final raw = await _store.read(_key(account));
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _uid = data['uid'] as String?;
        _lookupToken = data['lookup_token'] as String?;
        _token = data['token'] as String?;
        _passwordSalt = data['password_salt'] as String?;
        _passwordDigest = data['password_digest'] as String?;
        _platform = data['platform'] as String? ?? 'ios';
        if (_uid != null) {
          approvedDevice = {'device_id': _uid!, 'device_name': _platform};
        }
      } on FormatException {
        await _store.delete(_key(account));
      }
    }
  }

  Future<String?> restoreSession() async {
    final account = await _store.read('unicore.active.v2');
    if (account == null) return null;
    _password = null;
    await _load(account);
    if (_token != null) await ensureServerDevice();
    return _token;
  }

  Future<void> logout({bool invalidateToken = false}) async {
    if (invalidateToken && _account != null) {
      _token = null;
      await _save();
    }
    await _store.delete('unicore.active.v2');
    _account = _password = _token = _uid = null;
    _passwordSalt = _passwordDigest = null;
    approvedDevice = null;
  }

  Future<String> _digestPassword(String password, String salt) async {
    final key =
        await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 210000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(password)),
          nonce: base64Decode(salt),
        );
    return base64Encode(await key.extractBytes());
  }

  Future<void> _rememberPasswordProof(String password) async {
    _passwordSalt = base64Encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    _passwordDigest = await _digestPassword(password, _passwordSalt!);
  }

  String _extract(Map<String, dynamic> data, [String? fallback]) {
    final nested = data['data'];
    final token =
        (nested is Map ? nested['token'] ?? nested['access_token'] : null) ??
        data['token'] ??
        data['access_token'] ??
        fallback;
    if (token is! String || token.isEmpty) {
      throw const FormatException('Нэвтрэх токен олдсонгүй.');
    }
    return token;
  }

  Future<String> _authenticate() async {
    if (_account == null || _password == null) {
      throw const ApiException(
        401,
        'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү.',
      );
    }
    final login = await _raw(
      '/auth/login',
      body: {
        'login': _account,
        'password': _password,
        if (_uid != null) ...{
          'device_uid': _uid,
          'device_name': 'mobile-$_platform-$_uid',
          'device_type': _platform,
          'platform': _platform,
        },
      },
    );
    final token = _extract(login);
    final selected = await _raw(
      '/auth/select-tenant',
      token: token,
      body: {'tenant_id': tenantId},
    );
    return _extract(selected, token);
  }

  Future<String> login(
    String login,
    String password, {
    void Function(String)? onProgress,
  }) async {
    var stage = 'Хадгалсан нэвтрэлтийг шалгаж байна…';
    void report(String value) {
      stage = value;
      onProgress?.call(value);
    }

    try {
      report(stage);
      await _load(login.trim().toLowerCase());
      _password = password;
      // Always consult the server on explicit login so a corrected mapping wins
      // over the phone's old cached UID. Never silently use stale data on error.
      final device = await DeviceResolver(
        () => _newClient(requestTimeout: const Duration(seconds: 130)),
      ).resolve(_account!, password, report);
      _lookupToken = device['lookup_token'] as String?;
      final resolvedUid = device['device_uid'] as String;
      final resolvedPlatform = device['platform'] as String;
      if (_uid != resolvedUid || _platform != resolvedPlatform) _token = null;
      _uid = resolvedUid;
      _platform = resolvedPlatform;
      approvedDevice = {'device_id': _uid!, 'device_name': _platform};
      final proofMatches =
          _passwordSalt != null &&
          _passwordDigest != null &&
          await _digestPassword(password, _passwordSalt!) == _passwordDigest;
      if (_token != null && proofMatches) {
        report('Хадгалсан нэвтрэх эрхийг шалгаж байна…');
        await getJson('/attendance/status', token: _token);
      } else {
        _token = null;
        report('Төхөөрөмжөөр нэвтэрч байна…');
        _token = await _authenticate();
      }
      report('Нэвтрэлтийг утсанд хадгалж байна…');
      await _rememberPasswordProof(password);
      await _save();
      return _token!;
    } on DeviceLookupException {
      rethrow;
    } on TimeoutException {
      throw DeviceLookupException(
        stage,
        'Хүлээх хугацаа дууслаа. Дахин оролдоно уу.',
      );
    } catch (error) {
      throw DeviceLookupException(
        stage,
        error is ApiException || error is FormatException
            ? error.toString()
            : 'Холболт эсвэл хадгалалт амжилтгүй. Дахин оролдоно уу.',
      );
    }
  }

  /// Checks the authoritative mapping on launch/resume and before attendance.
  /// A server failure blocks the action; an old local UID is never a fallback.
  Future<void> ensureServerDevice({void Function(String)? onProgress}) async {
    if (_account == null || _lookupToken == null) {
      throw const ApiException(
        401,
        'Сервертэй дахин холбохын тулд нэвтэрнэ үү.',
      );
    }
    final device = await DeviceResolver(
      () => _newClient(requestTimeout: const Duration(seconds: 130)),
    ).resolve(_account!, null, onProgress ?? (_) {}, lookupToken: _lookupToken);
    final uid = device['device_uid'] as String;
    final platform = device['platform'] as String;
    if (_uid != uid || _platform != platform) {
      _uid = uid;
      _platform = platform;
      _token = null;
      approvedDevice = {'device_id': uid, 'device_name': platform};
      await _save();
      onProgress?.call('Шинэ төхөөрөмжөөр нэвтэрч байна…');
      _token = _password == null
          ? await _recoverFromServer()
          : await _authenticate();
      await _save();
    }
  }

  Future<Map<String, String>> resolveApprovedDevice(String token) async {
    final response = await _raw('/attendance/device', token: token);
    final records = await _raw('/devices', token: token);
    final bindings = response['devices'] as List? ?? [response['device'] ?? {}];
    final matches = <String, String>{};
    for (final binding in bindings) {
      if (binding['status'] != 'approved') continue;
      final platform = binding['platform'];
      if (platform != 'ios' && platform != 'android') continue;
      final masked = (binding['device_uid_masked'] as String? ?? '')
          .toLowerCase();
      final parts = masked.split(RegExp(r'[•*…]+'));
      for (final record in records['data'] as List? ?? []) {
        final match = RegExp(
          r'^mobile-([^-]+)-(.+)$',
        ).firstMatch(record['device_name'] as String? ?? '');
        if (match == null || match[1] != platform) continue;
        final uid = match[2]!;
        if (uid.toLowerCase() == masked ||
            (parts.length == 2 &&
                parts.every((p) => p.isNotEmpty) &&
                uid.toLowerCase().startsWith(parts[0]) &&
                uid.toLowerCase().endsWith(parts[1]))) {
          matches[uid.toUpperCase()] = platform;
        }
      }
    }
    if (matches.length != 1) {
      deviceError =
          'Approved төхөөрөмжийн бүтэн UID-г нэг утгаар олсонгүй. Бүртгэлтэй утасны Unicore аппд нэвтэрч дахин оролдоно уу.';
      throw FormatException(deviceError!);
    }
    return {
      'device_id': matches.keys.single,
      'device_name': matches.values.single,
      'platform': matches.values.single,
    };
  }

  Future<void> attendance(
    String type,
    String token,
    AttendanceLocation location, {
    void Function(String)? onProgress,
  }) async {
    if (type != 'check-in' && type != 'check-out') {
      throw ArgumentError.value(type);
    }
    await ensureServerDevice(onProgress: onProgress);
    onProgress?.call('Төхөөрөмжийн зөвшөөрлийг шалгаж байна…');
    if (_uid == null) {
      throw const FormatException('Төхөөрөмжийн UID олдсонгүй.');
    }
    final response = await getJson('/attendance/device', token: token);
    final bindings = response['devices'] as List? ?? [response['device'] ?? {}];
    if (!bindings.any(
      (b) =>
          b['status'] == 'approved' &&
          b['is_current_device'] == true &&
          b['platform'] == _platform,
    )) {
      throw const FormatException('Одоогийн төхөөрөмж approved биш байна.');
    }
    onProgress?.call('Ирцийн хүсэлт илгээж байна…');
    await postJson(
      '/attendance/$type',
      token: token,
      body: {
        ...location.toJson(),
        'device_id': _uid,
        'device_name': _platform,
        'rule_id': 5,
      },
    );
  }

  http.Client _newClient({
    Duration requestTimeout = const Duration(seconds: 20),
  }) {
    if (_clientFactory != null) return _clientFactory();
    if (!Platform.isIOS && !Platform.isMacOS) return http.Client();
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..timeoutIntervalForRequest = requestTimeout;
    return CupertinoClient.fromSessionConfiguration(config);
  }

  Future<Map<String, dynamic>> _raw(
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    final client = _newClient();
    final started = Stopwatch()..start();
    int? status;
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Tenant-Id': tenantId,
        'X-App-Platform': _platform,
        'X-App-Version': '1.2.21+245',
        'X-Device-Id': ?_uid,
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final uri = Uri.parse('$baseUrl$path');
      final response =
          await (body == null
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 25));
      status = response.statusCode;
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] == false) {
        throw ApiException(
          response.statusCode,
          data['message']?.toString() ?? 'HTTP ${response.statusCode}',
        );
      }
      return data;
    } finally {
      client.close();
      if (auditEnabled) {
        unawaited(
          _auditRequest(
            path,
            body == null ? 'GET' : 'POST',
            status,
            started.elapsedMilliseconds,
          ),
        );
      }
    }
  }

  Future<void> _auditRequest(
    String path,
    String method,
    int? status,
    int duration,
  ) async {
    final account = _account;
    if (account == null) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.postUrl(Uri.parse(auditServerUrl));
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({
            'user_email': account,
            'action_type': 'api-request',
            'endpoint': path,
            'method': method,
            'http_status': status,
            'duration_ms': duration,
            'success': status != null && status >= 200 && status < 300,
            'location_name': '$method $path → ${status ?? "network error"}',
            'device_info': 'unicore_mobile_app v4.0.0',
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      await response.drain<void>();
    } catch (_) {
      /* Audit transport must never replay an attendance request. */
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _recoverFromServer({String? rejectedToken}) async {
    if (_account == null || _lookupToken == null) {
      throw const ApiException(401, 'Дахин нэвтэрнэ үү.');
    }
    try {
      final result =
          await DeviceResolver(
            () => _newClient(requestTimeout: const Duration(seconds: 130)),
          ).resolve(
            _account!,
            null,
            (_) {},
            lookupToken: _lookupToken,
            recoverToken: true,
            rejectedToken: rejectedToken,
          );
      if (result['device_uid'] != _uid || result['platform'] != _platform) {
        throw const ApiException(
          409,
          'Төхөөрөмжийн мэдээлэл өөрчлөгдлөө. Дахин оролдоно уу.',
        );
      }
      final token = result['token'];
      if (token is! String || token.isEmpty) {
        throw const ApiException(502, 'Токен сэргээх хариу дутуу байна.');
      }
      return token;
    } on DeviceLookupException catch (error) {
      if (error.status == 401) {
        await logout(invalidateToken: true);
        throw ApiException(401, error.message);
      }
      rethrow;
    }
  }

  Future<String> _refresh() async {
    if (_refreshing != null) return _refreshing!;
    final work = () async {
      _token = _password == null
          ? await _recoverFromServer(rejectedToken: _token)
          : await _authenticate();
      await _save();
      return _token!;
    }();
    _refreshing = work;
    try {
      return await work;
    } finally {
      _refreshing = null;
    }
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    final actual = token == null ? null : (_token ?? token);
    try {
      return await _raw(path, token: actual, body: body);
    } on ApiException catch (error) {
      if (error.status != 401 || actual == null) rethrow;
      final fresh = _token != null && _token != actual
          ? _token!
          : await _refresh();
      return _raw(
        path,
        token: fresh,
        body: body,
      ); // Exactly one retry, only after HTTP 401.
    }
  }

  Future<Map<String, dynamic>> getJson(String path, {String? token}) =>
      _request(path, token: token);
  Future<Map<String, dynamic>> postJson(
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) => _request(path, token: token, body: body ?? {});

  /// Posts attendance telemetry to [auditServerUrl] and returns the HTTP
  /// status code. Throws if the connection fails.
  Future<int> sendAuditTelemetry({
    required String type,
    required String email,
    required AttendanceLocation location,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final request = await client.postUrl(Uri.parse(auditServerUrl));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    final body = {
      'user_email': email,
      'login_username': email,
      'action_type': type,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'location_name': 'Tselmeg Digital International School',
      'distance_meters': location.distanceMeters,
      'timestamp': DateTime.now().toIso8601String(),
      'device_info': 'unicore_mobile_app v4.0.0',
    };

    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    return response.statusCode;
  }
}
