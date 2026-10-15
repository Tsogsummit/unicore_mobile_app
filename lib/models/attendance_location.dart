import 'package:geolocator/geolocator.dart';

/// A GPS point (with its distance from the office center) used when
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

/// Office center, used only to report how far the device currently is.
const _centerLatitude = 47.89679317;
const _centerLongitude = 106.88973599;

/// Reads the device's **real** GPS position and returns it. Requests location
/// permission if needed and throws a descriptive error when location is
/// unavailable or denied.
Future<AttendanceLocation> currentAttendanceLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationServiceException(
      'Байршлын үйлчилгээ унтраалттай байна.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const LocationServiceException(
      'Байршлын зөвшөөрөл олгогдоогүй байна.',
    );
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      timeLimit: Duration(seconds: 25),
    ),
  );

  final distance = Geolocator.distanceBetween(
    _centerLatitude,
    _centerLongitude,
    position.latitude,
    position.longitude,
  );

  return AttendanceLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
    distanceMeters: distance,
  );
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
