import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import '../models/lat_lng.dart';

/// A filtered GPS fix.
class GpsFix {
  final LatLng position;
  final double accuracyM;
  final double speedMps;
  final double heading;
  final DateTime timestamp;

  const GpsFix({
    required this.position,
    required this.accuracyM,
    required this.speedMps,
    required this.heading,
    required this.timestamp,
  });
}

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// GPS access via geolocator, configured for fitness tracking with
/// background updates (Android foreground service / iOS background mode).
class LocationService {
  Future<LocationAccess> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    switch (p) {
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationAccess.granted;
    }
  }

  Future<LatLng?> currentPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Continuous, high-accuracy stream for an active quest.
  Stream<GpsFix> trackingStream() {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'WalkQuest 3D',
          notificationText: 'Quest in progress — tracking your route',
          enableWakeLock: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
    }
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => GpsFix(
        position: LatLng(p.latitude, p.longitude),
        accuracyM: p.accuracy,
        speedMps: p.speed < 0 ? 0 : p.speed,
        heading: p.heading,
        timestamp: p.timestamp,
      ),
    );
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}
