import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:unicore_mobile_app/models/attendance_location.dart';
import 'package:unicore_mobile_app/services/unicore_api.dart';

class FakeApi extends UnicoreApi {
  final calls = <Map<String, dynamic>>[];
  bool matchDevice = true;
  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    calls.add({'path': path, 'token': token, 'body': body});
    if (path == '/auth/login')
      return {
        'data': {'token': 'login-token'},
      };
    if (path == '/auth/select-tenant')
      return {
        'data': {'token': 'tenant-token'},
      };
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    if (path == '/attendance/device')
      return {
        'device': {
          'status': 'approved',
          'platform': 'ios',
          'device_uid_masked': 'ABCD••••1234',
        },
      };
    return {
      'data': matchDevice
          ? [
              {'device_name': 'mobile-ios-ABCD-example-1234', 'name': 'iPhone'},
            ]
          : [],
    };
  }
}

void main() {
  test(
    'login selects tenant, accepts rotated token, and retrieves UID',
    () async {
      final api = FakeApi();
      expect(await api.login('example', 'not-real'), 'tenant-token');
      expect(api.calls[1]['body'], {'tenant_id': 'tenant_65'});
      expect(api.approvedDevice?['device_id'], 'ABCD-example-1234');
    },
  );
  test('check-in and checkout have server-compatible bodies', () async {
    final api = FakeApi();
    for (final type in ['check-in', 'check-out']) {
      await api.attendance(type, 'token', randomAttendanceLocation());
      final body = api.calls.last['body'] as Map;
      expect(api.calls.last['path'], '/attendance/$type');
      expect(body['device_id'], 'ABCD-example-1234');
      expect(body['address'], '');
      expect(body['image'], isNull);
      expect(body['is_remote'], false);
      expect(body['note'], '');
      expect(body['accuracy'], inInclusiveRange(3, 20));
      expect(body.containsKey('rule_id'), type == 'check-in');
      expect(body.containsKey('device_name'), type == 'check-in');
      expect(body.containsKey('location_name'), false);
    }
  });
  test('missing approved UID blocks attendance POST', () async {
    final api = FakeApi()..matchDevice = false;
    await expectLater(
      api.attendance('check-in', 'token', randomAttendanceLocation()),
      throwsFormatException,
    );
    expect(api.calls, isEmpty);
  });
  test(
    'missing UID does not invalidate login, but exposes lookup error',
    () async {
      final api = FakeApi()..matchDevice = false;
      expect(await api.login('example', 'not-real'), 'tenant-token');
      expect(api.approvedDevice, isNull);
      expect(api.deviceError, isNotNull);
    },
  );
  test('serialized coordinates remain within office 100 m radius', () {
    for (var i = 0; i < 10000; i++) {
      final body = randomAttendanceLocation().toJson();
      final lat1 = 47.89679317 * pi / 180;
      final lat2 = (body['latitude'] as double) * pi / 180;
      final dl = ((body['longitude'] as double) - 106.88973599) * pi / 180;
      final h =
          pow(sin((lat2 - lat1) / 2), 2) +
          cos(lat1) * cos(lat2) * pow(sin(dl / 2), 2);
      expect(6371000 * 2 * asin(sqrt(h)), lessThanOrEqualTo(100));
      expect(body['accuracy'], inInclusiveRange(3, 20));
    }
  });
}
