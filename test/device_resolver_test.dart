import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unicore_mobile_app/services/device_resolver.dart';

void main() {
  test('slow lookup polls stage and reports bounded timeout', () async {
    final stages = <String>[];
    final resolver = DeviceResolver(
      () => MockClient((r) async {
        if (r.method == 'GET') {
          return http.Response(
            jsonEncode({
              'messages': ['Unicore төхөөрөмж хайж байна…'],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return Completer<http.Response>().future;
      }),
      timeout: const Duration(milliseconds: 200),
      pollInterval: const Duration(milliseconds: 10),
    );
    await expectLater(
      resolver.resolve('user', 'secret', stages.add),
      throwsA(
        isA<DeviceLookupException>().having(
          (e) => e.stage,
          'stage',
          'Unicore төхөөрөмж хайж байна…',
        ),
      ),
    );
    expect(stages.last, 'Unicore төхөөрөмж хайж байна…');
  });

  test('invalid response does not become a device ID', () async {
    final resolver = DeviceResolver(
      () => MockClient(
        (_) async => http.Response('<html>bad gateway</html>', 502),
      ),
    );
    await expectLater(
      resolver.resolve('user', 'secret', (_) {}),
      throwsA(isA<DeviceLookupException>()),
    );
  });

  test('successful lookup stops polling and returns source', () async {
    final resolver = DeviceResolver(
      () => MockClient((r) async {
        expect(r.url.scheme, 'https');
        expect(jsonDecode(r.body)['login'], 'user');
        return http.Response(
          jsonEncode({
            'success': true,
            'device_uid': 'D824-ID-1BF0',
            'platform': 'ios',
            'source': 'server',
          }),
          200,
        );
      }),
    );
    final stages = <String>[];
    final result = await resolver.resolve('user', 'secret', stages.add);
    expect(result['device_uid'], 'D824-ID-1BF0');
    expect(stages.last, contains('хадгалсан ID'));
  });
}
