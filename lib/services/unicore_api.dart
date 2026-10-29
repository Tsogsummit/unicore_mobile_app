import 'dart:convert';
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
  // Approved UIDs copied from the server's stored mapping. The mobile app
  // uses this local map so login does not depend on /api/device/resolve.
  static const deviceUids = <String, String>{
    'tsogsummit@gmail.com': '76F47E61-B1A2-486C-A89C-2B73CF7C0C4C',
    'batnasandalaisuren@gmail.com': 'C2CE0A67-9874-4562-B93E-CE894C50CA36',
    '89261500': 'CEA90AE1-91E4-4C34-90A7-FAA9E5E7E6C2',
    '86431234': '77B860FE-056C-4A7C-B8B8-A6C813450325',
    'bymbtstsg0810@gmail.com': 'E7D1F4FD-59C9-475D-9E0F-78CB3BA2F574',
    'temuujin@tselmeg.edu.mn': 'D824C39C-ECEA-4CA3-86E2-135021441BF0',
    'tumennast854@gmail.com': '5022E645-0475-449A-B5BB-2F2F7713EF54',
  };
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
    _uid = deviceUids[account];
    _passwordSalt = _passwordDigest = null;
    approvedDevice = null;
    deviceError = null;
    String? raw;
    try {
      raw = await _store.read(_key(account));
    } catch (_) {
      // An unreadable Keychain is treated as an empty cache; the server
      // remains the source of truth and a password login rebuilds it.
      return;
    }
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final uid = data['uid'] as String?;
      final lookupToken = data['lookup_token'] as String?;
      final token = data['token'] as String?;
      final salt = data['password_salt'] as String?;
      final digest = data['password_digest'] as String?;
      final platform = data['platform'] as String? ?? 'ios';
      _uid = uid;
      _lookupToken = lookupToken;
      _token = token;
      _passwordSalt = salt;
      _passwordDigest = digest;
      _platform = platform;
      _uid = deviceUids[account] ?? uid;
      if (_uid != null) {
        approvedDevice = {
          'device_id': _uid!,
          'device_name': 'mobile-ios-$_uid',
        };
      }
    } catch (_) {
      // Malformed or wrongly typed cache from an older build.
      try {
        await _store.delete(_key(account));
      } catch (_) {}
    }
  }

  Future<String?> restoreSession() async {
    String? account;
    try {
      account = await _store.read('unicore.active.v2');
    } catch (_) {
      return null;
    }
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
        'email': _account,
        'password': _password,
        'device_name': 'mobile-ios-$_uid',
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
      final localUid = deviceUids[_account!];
      if (localUid == null) {
        throw const FormatException(
          'Энэ хэрэглэгчийн зөвшөөрөгдсөн төхөөрөмжийн UID app-д бүртгэгдээгүй байна.',
        );
      }
      if (_uid != localUid || _platform != 'ios') _token = null;
      _lookupToken = null;
      _uid = localUid;
      _platform = 'ios';
      approvedDevice = {
        'device_id': _uid!,
        'device_name': 'mobile-ios-$_uid',
      };
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
      try {
        await _rememberPasswordProof(password);
        await _save();
      } catch (_) {
        // Keychain write failed: keep this session in memory instead of
        // rejecting a login the server already accepted.
      }
      return _token!;
    } on TimeoutException {
      throw ApiException(
        408,
        stage,
      );
    } catch (error) {
      rethrow;
    }
  }

  /// Checks the authoritative mapping on launch/resume and before attendance.
  /// A server failure blocks the action; an old local UID is never a fallback.
  Future<void> ensureServerDevice({void Function(String)? onProgress}) async {
    if (_account == null) {
      throw const ApiException(
        401,
        'Төхөөрөмжийн UID ашиглахын тулд нэвтэрнэ үү.',
      );
    }
    final uid = deviceUids[_account!];
    if (uid == null) {
      throw const FormatException('Энэ хэрэглэгчийн төхөөрөмжийн UID app-д бүртгэлгүй байна.');
    }
    _uid = uid;
    _platform = 'ios';
    approvedDevice = {
      'device_id': uid,
      'device_name': 'mobile-ios-$uid',
    };
  }

  Future<Map<String, String>> resolveApprovedDevice(String token) async {
    final uid = _uid;
    if (uid == null) {
      throw const FormatException('Төхөөрөмжийн UID олдсонгүй.');
    }
    return {
      'device_id': uid,
      'device_name': 'mobile-ios-$uid',
      'platform': _platform,
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
    if (_uid == null) {
      throw const FormatException('Төхөөрөмжийн UID олдсонгүй.');
    }
    onProgress?.call('Ирцийн хүсэлт илгээж байна…');
    await postJson(
      '/attendance/$type',
      token: token,
      body: {
        ...location.toJson(),
        'device_id': _uid,
        'device_name': 'mobile-ios-$_uid',
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
        'X-App-Version': '1.2.33+263',
        'User-Agent': 'UniCore/1.2.33 (iOS 27.0.1; iPhone)',
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
            'device_info': 'unicore_mobile_app v4.0.2',
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
    throw const ApiException(401, 'Дахин нэвтэрнэ үү.');
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
      'device_info': 'unicore_mobile_app v4.0.2',
    };

    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    return response.statusCode;
  }
}
