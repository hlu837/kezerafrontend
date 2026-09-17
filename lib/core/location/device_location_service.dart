import 'package:geolocator/geolocator.dart';

/// Why a location fetch failed — the two call sites (onboarding's
/// silent best-effort capture, and the nearby-experts map's explicit
/// "use my location" button) each want to react differently: the
/// former just falls back to skipping location silently, the latter
/// shows the person something actionable ("turn on location services",
/// "allow location access in Settings").
enum DeviceLocationFailure {
  /// Location services are off at the OS level (airplane mode-ish,
  /// unrelated to this app's permission).
  servicesDisabled,

  /// The person denied the permission prompt (recoverable — asking
  /// again may work).
  permissionDenied,

  /// The person denied it and checked "don't ask again" / denied it
  /// from Settings — only fixable by the person manually re-enabling
  /// it in the OS settings app.
  permissionDeniedForever,

  /// Permission was granted but the actual GPS fix failed or timed out.
  positionUnavailable,
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.reason);
  final DeviceLocationFailure reason;
}

/// Thin wrapper around `package:geolocator` so every call site shares
/// the same permission-request + fetch flow instead of each screen
/// re-implementing the "check service enabled -> check permission ->
/// request permission -> get position" dance individually.
class DeviceLocationService {
  const DeviceLocationService();

  /// Requests (if needed) and returns the device's current GPS fix as
  /// (latitude, longitude). Throws [DeviceLocationException] with a
  /// [DeviceLocationFailure] describing why on any failure — callers
  /// decide for themselves whether that should be silent (onboarding)
  /// or surfaced (the map screen's explicit button).
  Future<({double latitude, double longitude})> getCurrentLatLng() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      throw const DeviceLocationException(
        DeviceLocationFailure.servicesDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      throw const DeviceLocationException(
        DeviceLocationFailure.positionUnavailable,
      );
    }
  }
}
