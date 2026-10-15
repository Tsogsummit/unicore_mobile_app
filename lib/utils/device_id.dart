import 'package:device_info_plus/device_info_plus.dart';

/// Device UID.
///
/// Үндсэн утгаар энэ утасны жинхэнэ `identifierForVendor`-г ашиглана.
/// Шаардлагатай бол build хийх үед `--dart-define=DEVICE_ID=...` -ээр
/// дарж өөрчилж болно.
const _configuredDeviceId = String.fromEnvironment(
  'DEVICE_ID',
  defaultValue: '',
);

Future<String?> getDeviceId() async {
  if (_configuredDeviceId.isNotEmpty) {
    return _configuredDeviceId;
  }

  final info = await DeviceInfoPlugin().iosInfo;
  return info.identifierForVendor;
}
