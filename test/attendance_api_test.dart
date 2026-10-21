import 'dart:convert';
import 'dart:math';
import 'package:unicore_mobile_app/services/device_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unicore_mobile_app/models/attendance_location.dart';
import 'package:unicore_mobile_app/services/session_store.dart';
import 'package:unicore_mobile_app/services/unicore_api.dart';

class MemoryStore implements SessionStore {
  final data = <String, String>{};
  bool failReads = false, failWrites = false;
  @override
  Future<String?> read(String key) async {
    if (failReads) throw Exception('Keychain unavailable');
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw Exception('Keychain unavailable');
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

class Fixture {
  final store = MemoryStore();
  final calls = <http.Request>[];
  int logins = 0,
      failure = 0,
      lookupStatus = 200,
      recoveries = 0,
      recoveryStatus = 200;
  String serverUid = uid;
  bool approved = true, missing = false, alwaysFail = false;
  static const uid = 'ABCD0000-1111-2222-3333-000000001234';
  UnicoreApi api() => UnicoreApi(
    store: store,
    auditEnabled: false,
    clientFactory: () => MockClient((req) async {
      calls.add(req);
      final path = req.url.path.replaceFirst('/api/mobile', '');
      Object data = {'success': true};
      int status = 200;
      if (path == '/api/device/resolve') {
        final recovering = jsonDecode(req.body)['recover_token'] == true;
        if (recovering) recoveries++;
        status = recovering ? recoveryStatus : (missing ? 422 : lookupStatus);
        data = status == 200
            ? {
                'success': true,
                'device_uid': serverUid,
                'platform': 'ios',
                'source': 'server',
                if (recovering) 'token': 'recovered-$recoveries',
                'lookup_token': 'test-lookup-token-01234567890123456789',
              }
            : {
                'success': false,
                'stage': 'Төхөөрөмжийн жагсаалтаас бүтэн ID хайж байна…',
                'message': 'Device lookup failed',
              };
      } else if (path == '/auth/login') {
        logins++;
        data = {
          'data': {'token': 'login-$logins'},
        };
      } else if (path == '/auth/select-tenant') {
        data = {
          'data': {'token': 'selected-$logins'},
        };
      } else if (path == '/attendance/device') {
        data = {
          'device': {
            'status': approved ? 'approved' : 'pending',
            'platform': 'ios',
            'is_current_device': approved,
            'device_uid_masked': 'ABCD••••1234',
          },
        };
      } else if (path == '/devices') {
        data = {
          'data': missing
              ? []
              : [
                  {'device_name': 'mobile-ios-$uid'},
                ],
        };
      } else if (failure != 0) {
        status = failure;
        data = {'message': 'denied'};
        if (!alwaysFail) failure = 0;
      }
      return http.Response(
        jsonEncode(data),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

const location = AttendanceLocation(
  latitude: 47.9,
  longitude: 106.9,
  accuracy: 12,
  distanceMeters: 50,
);
void main() {
  test(
    'server UID is used for bound login; token restored across restart',
    () async {
      final f = Fixture();
      final api = f.api();
      final token = await api.login('User@Example.test', 'test-only');
      expect(f.logins, 1);
      expect(token, 'selected-1');
      final login = f.calls
          .where((r) => r.url.path.endsWith('/auth/login'))
          .last;
      expect(jsonDecode(login.body)['device_uid'], Fixture.uid);
      expect(login.headers['X-Device-Id'], Fixture.uid);
      expect(login.headers['X-App-Platform'], 'ios');
      expect(f.store.data.values.join(), isNot(contains('test-only')));
      final restored = f.api();
      expect(await restored.restoreSession(), token);
      expect(restored.account, 'user@example.test');
      await restored.getJson('/attendance/status', token: token);
      expect(f.logins, 1);
    },
  );
  test(
    '401 refreshes once; old caller token uses replacement; 403 never logs in',
    () async {
      final f = Fixture();
      final api = f.api();
      final t = await api.login('user', 'test');
      f.failure = 401;
      await api.getJson('/attendance/status', token: t);
      expect(f.logins, 2);
      expect(api.currentToken, 'selected-2');
      await api.getJson('/attendance/status', token: t);
      expect(f.calls.last.headers['Authorization'], 'Bearer selected-2');
      f.failure = 403;
      await expectLater(
        api.getJson('/attendance/status', token: t),
        throwsA(isA<ApiException>()),
      );
      expect(f.logins, 2);
      f.failure = 401;
      f.alwaysFail = true;
      await expectLater(
        api.getJson('/attendance/status', token: t),
        throwsA(isA<ApiException>()),
      );
      expect(f.logins, 3);
    },
  );
  test(
    'restored 401 recovers through server without password or login',
    () async {
      final f = Fixture();
      await f.api().login('user', 'test');
      final api = f.api();
      final t = await api.restoreSession();
      f.failure = 401;
      await api.getJson('/attendance/status', token: t);
      expect(api.currentToken, 'recovered-1');
      expect(f.logins, 1);
      expect(f.recoveries, 1);
      final request = f.calls.firstWhere(
        (r) =>
            r.url.path == '/api/device/resolve' &&
            jsonDecode(r.body)['recover_token'] == true,
      );
      final body = jsonDecode(request.body);
      expect(body.containsKey('password'), isFalse);
      expect(body['rejected_token'], 'selected-1');
      expect(await f.api().restoreSession(), 'recovered-1');
    },
  );
  test(
    'invalid recovery session requires login, network failure preserves session',
    () async {
      final f = Fixture();
      await f.api().login('user', 'test');
      final api = f.api();
      final t = await api.restoreSession();
      f.failure = 401;
      f.recoveryStatus = 503;
      await expectLater(
        api.getJson('/attendance/status', token: t),
        throwsA(isA<DeviceLookupException>()),
      );
      expect(api.currentToken, t);
      expect(await f.api().restoreSession(), t);
      f.failure = 401;
      f.recoveryStatus = 401;
      await expectLater(
        api.getJson('/attendance/status', token: t),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(api.currentToken, isNull);
      expect(await f.api().restoreSession(), isNull);
    },
  );
  test(
    'server recovery retries upstream exactly once and does not refresh 403',
    () async {
      final f = Fixture();
      await f.api().login('user', 'test');
      final api = f.api();
      final t = await api.restoreSession();
      f.failure = 403;
      await expectLater(
        api.getJson('/attendance/status', token: t),
        throwsA(isA<ApiException>()),
      );
      expect(f.recoveries, 0);
      f.failure = 401;
      f.alwaysFail = true;
      await expectLater(
        api.getJson('/attendance/status', token: t),
        throwsA(isA<ApiException>()),
      );
      expect(f.recoveries, 1);
      expect(f.logins, 1);
    },
  );
  test(
    'check-in and check-out preserve generated location and approved device',
    () async {
      final f = Fixture();
      final a = f.api();
      final t = await a.login('user', 'test');
      for (final type in ['check-in', 'check-out']) {
        final generated = randomAttendanceLocation(
          random: Random(type == 'check-in' ? 7 : 8),
        );
        await a.attendance(type, t, generated);
        final req = f.calls.last;
        final body = jsonDecode(req.body);
        expect(req.url.path.endsWith(type), isTrue);
        expect(body['device_id'], Fixture.uid);
        expect(req.headers['X-Device-Id'], Fixture.uid);
        for (final entry in generated.toJson().entries) {
          expect(body[entry.key], entry.value);
        }
        expect(body['device_name'], 'ios');
        expect(body['rule_id'], 5);
      }
      f.approved = false;
      final before = f.calls.length;
      await expectLater(
        a.attendance('check-out', t, location),
        throwsFormatException,
      );
      expect(
        f.calls.length,
        before + 2,
      ); // Server lookup and device check only; no attendance POST.
    },
  );
  test(
    'logout/login reuses the saved token without another upstream login',
    () async {
      final f = Fixture();
      final a = f.api();
      final first = await a.login('user', 'test');
      await a.logout();
      expect(await f.api().restoreSession(), isNull);
      final second = await f.api().login('user', 'test');
      expect(second, first);
      expect(f.logins, 1);
    },
  );
  test(
    'missing UID blocks bound login and account sessions stay isolated',
    () async {
      final f = Fixture()..missing = true;
      await expectLater(
        f.api().login('unknown', 'test'),
        throwsA(isA<DeviceLookupException>()),
      );
      expect(f.logins, 0);
      f.missing = false;
      final a = f.api();
      await a.login('first', 'test');
      final before = f.logins;
      await a.login('second', 'test');
      expect(f.logins, before + 1);
      await a.login('first', 'test');
      expect(f.logins, before + 1);
    },
  );
  test('unreadable or unwritable Keychain does not block login', () async {
    final f = Fixture();
    f.store.failReads = true;
    f.store.failWrites = true;
    expect(await f.api().restoreSession(), isNull);
    expect(await f.api().login('user', 'test'), 'selected-1');
    f.store.failReads = f.store.failWrites = false;
    expect(await f.api().login('user', 'test'), 'selected-2');
  });
  test('malformed or wrongly typed cache is discarded on login', () async {
    final f = Fixture();
    final api = f.api();
    await api.login('user', 'test');
    final key = f.store.data.keys.firstWhere((k) => k.contains('session'));
    for (final bad in ['{not json', '{"uid": 42, "token": []}', '[]']) {
      f.store.data[key] = bad;
      expect(await f.api().login('user', 'test'), startsWith('selected-'));
      expect(jsonDecode(f.store.data[key]!)['uid'], f.serverUid);
    }
  });
  test('changed server UID replaces cached UID and cached token', () async {
    final f = Fixture();
    final api = f.api();
    await api.login('user', 'test');
    f.serverUid = 'D824C39C-ECEA-4CA3-86E2-135021441BF0';
    await api.login('user', 'test');
    expect(f.logins, 2);
    final request = f.calls.lastWhere(
      (r) => r.url.path.endsWith('/auth/login'),
    );
    expect(jsonDecode(request.body)['device_uid'], f.serverUid);
  });
  test('server failure does not fall back to stale cached UID', () async {
    final f = Fixture();
    final api = f.api();
    await api.login('user', 'test');
    f.lookupStatus = 503;
    final before = f.logins;
    await expectLater(
      api.login('user', 'test'),
      throwsA(
        isA<DeviceLookupException>().having(
          (e) => e.stage,
          'stage',
          contains('бүтэн ID'),
        ),
      ),
    );
    expect(f.logins, before);
    expect(f.calls.last.url.path, '/api/device/resolve');
  });
  test('server failure blocks attendance before any Unicore POST', () async {
    final f = Fixture();
    final api = f.api();
    final token = await api.login('user', 'test');
    f.lookupStatus = 503;
    final before = f.calls.length;
    await expectLater(
      api.attendance('check-in', token, location),
      throwsA(isA<DeviceLookupException>()),
    );
    expect(f.calls.length, before + 1);
    expect(f.calls.last.url.path, '/api/device/resolve');
    expect(jsonDecode(f.calls.last.body).containsKey('password'), isFalse);
  });
  test(
    'restart recovers a new device mapping through authenticated server session',
    () async {
      final f = Fixture();
      await f.api().login('user', 'test');
      f.serverUid = 'NEW-SERVER-ID';
      expect(await f.api().restoreSession(), 'recovered-1');
      expect(f.recoveries, 1);
      expect(f.logins, 1);
      expect(f.calls.last.url.path, '/api/device/resolve');
    },
  );
}
