import 'dart:math';

/// A GPS point (with its offset from the office center) used when
/// submitting an attendance check-in / check-out.
class AttendanceLocation {
  const AttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  final double latitude;
  final double longitude;
  final double distanceMeters;

  Map<String, Object?> toJson() {
    return {
      'latitude': double.parse(latitude.toStringAsFixed(8)),
      'longitude': double.parse(longitude.toStringAsFixed(8)),
      'accuracy': double.parse(
        (3 + Random.secure().nextDouble() * 17).toStringAsFixed(2),
      ),
      'address': '',
      'image': null,
      'is_remote': false,
      'note': '',
    };
  }
}

/// Returns a random point uniformly distributed within [maxDistanceMeters]
/// of the office center.
AttendanceLocation randomAttendanceLocation() {
  const centerLatitude = 47.89679317;
  const centerLongitude = 106.88973599;
  const maxDistanceMeters = 99.99;
  const earthRadiusMeters = 6371000.0;

  final random = Random.secure();
  final distance = maxDistanceMeters * sqrt(random.nextDouble());
  final bearing = 2 * pi * random.nextDouble();
  final centerLatRad = centerLatitude * pi / 180;

  final angular = distance / earthRadiusMeters;
  final lon1 = centerLongitude * pi / 180;
  final lat2 = asin(
    sin(centerLatRad) * cos(angular) +
        cos(centerLatRad) * sin(angular) * cos(bearing),
  );
  final lon2 =
      lon1 +
      atan2(
        sin(bearing) * sin(angular) * cos(centerLatRad),
        cos(angular) - sin(centerLatRad) * sin(lat2),
      );
  return AttendanceLocation(
    latitude: lat2 * 180 / pi,
    longitude: lon2 * 180 / pi,
    distanceMeters: distance,
  );
}
