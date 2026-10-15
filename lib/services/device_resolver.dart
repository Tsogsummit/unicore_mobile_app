import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class DeviceLookupException implements Exception {
  const DeviceLookupException(this.stage, this.message, {this.status});
  final int? status;
  final String stage;
  final String message;
  @override
  String toString() => '$stage\n$message';
}

/// Reads the authenticated server mapping; the server discovers and saves a
/// missing mapping. Credentials are only sent over verified HTTPS.
class DeviceResolver {
  DeviceResolver(
    this.newClient, {
    this.timeout = const Duration(seconds: 130),
    this.pollInterval = const Duration(seconds: 1),
  });
  final Duration timeout;
  final Duration pollInterval;
  final http.Client Function() newClient;
  static const origin = 'https://13.214.2.6';

  Future<Map<String, dynamic>> resolve(
    String account,
    String? password,
    void Function(String) report, {
    String? lookupToken,
  }) async {
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final progressId =
        '${id.substring(0, 8)}-${id.substring(8, 12)}-${id.substring(12, 16)}-${id.substring(16, 20)}-${id.substring(20)}';
    final client = newClient();
    final pollClient = newClient();
    var stage = 'Серверээс төхөөрөмжийн ID авч байна…';
    var stopped = false, polling = false;
    void update(String value) {
      stage = value;
      report(value);
    }

    update(stage);
    Future<void> poll() async {
      if (stopped || polling) return;
      polling = true;
      try {
        final r = await pollClient
            .get(Uri.parse('$origin/api/session/progress?id=$progressId'))
            .timeout(const Duration(seconds: 4));
        if (!stopped && r.statusCode == 200) {
          final messages = jsonDecode(r.body)['messages'];
          if (messages is List &&
              messages.isNotEmpty &&
              messages.last is String &&
              messages.last != stage) {
            update(messages.last as String);
          }
        }
      } catch (_) {
        /* The main request determines success or failure. */
      } finally {
        polling = false;
      }
    }

    final timer = Timer.periodic(pollInterval, (_) => unawaited(poll()));
    try {
      final r = await client
          .post(
            Uri.parse('$origin/api/device/resolve'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'login': account,
              if (lookupToken == null) 'password': password,
              'lookup_token': ?lookupToken,
              'client': 'mobile',
              'progress_id': progressId,
            }),
          )
          .timeout(timeout);
      final data = jsonDecode(r.body);
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (r.statusCode != 200 || data['success'] != true) {
        throw DeviceLookupException(
          data['stage'] as String? ?? stage,
          data['message'] as String? ??
              'Серверийн хүсэлт амжилтгүй (${r.statusCode}).',
          status: r.statusCode,
        );
      }
      final uid = data['device_uid'];
      if (uid is! String ||
          uid.trim().isEmpty ||
          !['ios', 'android'].contains(data['platform'])) {
        throw const FormatException();
      }
      stopped = true;
      update(
        data['source'] == 'server'
            ? 'Серверт хадгалсан ID олдлоо.'
            : 'Unicore-оос ID олдож, серверт хадгалагдлаа.',
      );
      return data;
    } on DeviceLookupException {
      rethrow;
    } on TimeoutException {
      throw DeviceLookupException(
        stage,
        'Хүлээх хугацаа дууслаа. Холболтоо шалгаад дахин оролдоно уу.',
      );
    } on FormatException {
      throw DeviceLookupException(
        stage,
        'Серверээс буруу хэлбэртэй хариу ирлээ.',
      );
    } catch (_) {
      throw DeviceLookupException(
        stage,
        'Сервертэй холбогдож чадсангүй. Интернэт холболтоо шалгана уу.',
      );
    } finally {
      stopped = true;
      timer.cancel();
      client.close();
      pollClient.close();
    }
  }
}
