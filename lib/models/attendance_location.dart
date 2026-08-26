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

  Map<String, Object> toJson() {
    return {
      'latitude': double.parse(latitude.toStringAsFixed(6)),
      'longitude': double.parse(longitude.toStringAsFixed(6)),
      'location_name': 'Tselmeg Digital International School',
    };
  }
}

/// Returns a random point uniformly distributed within [maxDistanceMeters]
/// of the office center.
AttendanceLocation randomAttendanceLocation() {
  const centerLatitude = 47.896883;
  const centerLongitude = 106.889669;
  const maxDistanceMeters = 200.0;
  const earthRadiusMeters = 6371000.0;

  final random = Random.secure();
  final distance = maxDistanceMeters * sqrt(random.nextDouble());
  final bearing = 2 * pi * random.nextDouble();
  final centerLatRad = centerLatitude * pi / 180;

  final deltaLat = (distance * cos(bearing)) / earthRadiusMeters;
  final deltaLon = (distance * sin(bearing)) / (earthRadiusMeters * cos(centerLatRad));

  return AttendanceLocation(
    latitude: centerLatitude + deltaLat * 180 / pi,
    longitude: centerLongitude + deltaLon * 180 / pi,
    distanceMeters: distance,
  );
}
