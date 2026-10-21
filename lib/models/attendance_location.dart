import 'dart:math';

/// A generated point (with its offset from the office center) used when
/// submitting an attendance check-in / check-out.
class AttendanceLocation {
  const AttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.distanceMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double distanceMeters;

  Map<String, Object?> toJson() {
    return {
      'latitude': double.parse(latitude.toStringAsFixed(8)),
      'longitude': double.parse(longitude.toStringAsFixed(8)),
      'accuracy': double.parse(accuracy.toStringAsFixed(2)),
      'address': '',
      'image': null,
      'is_remote': false,
      'note': '',
    };
  }
}

/// Center of the generated attendance area, not the device's GPS position.
const _centerLatitude = 47.89679317;
const _centerLongitude = 106.88973599;
const _maxDistanceMeters = 99.99;
const _earthRadiusMeters = 6371000.0;

/// Restores the legacy mobile behavior: an area-uniform random point within
/// 99.99 m of the center, with generated accuracy in [3, 20) m. No GPS is read.
/// [random] can be supplied for deterministic tests; production uses secure RNG.
AttendanceLocation randomAttendanceLocation({Random? random}) {
  final rng = random ?? Random.secure();
  final distance = _maxDistanceMeters * sqrt(rng.nextDouble());
  final bearing = 2 * pi * rng.nextDouble();
  final centerLatRad = _centerLatitude * pi / 180;
  final angular = distance / _earthRadiusMeters;
  final lon1 = _centerLongitude * pi / 180;
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
    accuracy: 3 + rng.nextDouble() * 17,
    distanceMeters: distance,
  );
}
