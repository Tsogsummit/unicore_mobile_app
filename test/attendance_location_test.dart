import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:unicore_mobile_app/models/attendance_location.dart';

double distanceFromCenter(double latitude, double longitude) {
  final lat1 = 47.89679317 * pi / 180;
  final lat2 = latitude * pi / 180;
  final deltaLat = lat2 - lat1;
  final deltaLon = (longitude - 106.88973599) * pi / 180;
  final a =
      pow(sin(deltaLat / 2), 2) +
      cos(lat1) * cos(lat2) * pow(sin(deltaLon / 2), 2);
  return 6371000 * 2 * atan2(sqrt(a), sqrt(1 - a));
}

void main() {
  test('generated points and rounded payloads stay in the legacy area', () {
    final random = Random(42);
    for (var i = 0; i < 1000; i++) {
      final location = randomAttendanceLocation(random: random);
      expect(location.distanceMeters, inInclusiveRange(0, 99.99));
      expect(location.accuracy, greaterThanOrEqualTo(3));
      expect(location.accuracy, lessThan(20));
      expect(
        distanceFromCenter(location.latitude, location.longitude),
        closeTo(location.distanceMeters, 0.00001),
      );
      final payload = location.toJson();
      // Eight decimal places introduce less than a millimeter of rounding.
      expect(
        distanceFromCenter(
          payload['latitude'] as double,
          payload['longitude'] as double,
        ),
        lessThanOrEqualTo(99.991),
      );
      expect(payload['accuracy'], inInclusiveRange(3, 20));
    }
  });

  test('each action generates a new point without needing GPS', () {
    final first = randomAttendanceLocation(random: Random(7));
    final second = randomAttendanceLocation(random: Random(8));
    expect(first.latitude, isNot(second.latitude));
    expect(first.longitude, isNot(second.longitude));
    final secure = randomAttendanceLocation();
    expect(secure.latitude.isFinite, isTrue);
    expect(secure.longitude.isFinite, isTrue);
  });

  test('payload preserves rounding and the attendance API contract', () {
    const location = AttendanceLocation(
      latitude: 47.896793174,
      longitude: 106.889735996,
      accuracy: 12.345,
      distanceMeters: 0,
    );
    expect(location.toJson(), {
      'latitude': 47.89679317,
      'longitude': 106.889736,
      'accuracy': 12.35,
      'address': '',
      'image': null,
      'is_remote': false,
      'note': '',
    });
  });
}
