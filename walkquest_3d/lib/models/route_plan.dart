import 'activity_mode.dart';
import 'lat_lng.dart';

/// A place returned by geocoding search or a map tap.
class PlaceResult {
  final String name;
  final String? address;
  final LatLng location;

  const PlaceResult({required this.name, this.address, required this.location});
}

/// One turn-by-turn instruction from Mapbox Directions.
class RouteStep {
  final String instruction;
  final double distanceM;
  final LatLng location;

  const RouteStep({required this.instruction, required this.distanceM, required this.location});
}

/// A routed path to a destination, independent of walking/running mode.
class RoutePlan {
  final LatLng origin;
  final PlaceResult destination;
  final List<LatLng> geometry;
  final double distanceM;
  final List<RouteStep> steps;

  /// Elevation samples (meters) evenly spaced along [geometry]. May be empty
  /// when the elevation lookup fails.
  final List<double> elevationProfile;

  const RoutePlan({
    required this.origin,
    required this.destination,
    required this.geometry,
    required this.distanceM,
    this.steps = const [],
    this.elevationProfile = const [],
  });

  double get elevationGainM {
    double gain = 0;
    for (var i = 1; i < elevationProfile.length; i++) {
      final d = elevationProfile[i] - elevationProfile[i - 1];
      if (d > 0) gain += d;
    }
    return gain;
  }

  RoutePlan withElevation(List<double> profile) => RoutePlan(
    origin: origin,
    destination: destination,
    geometry: geometry,
    distanceM: distanceM,
    steps: steps,
    elevationProfile: profile,
  );
}

/// Mode-specific numbers derived from a distance (see RouteCalculator).
class RouteEstimate {
  final ActivityMode mode;
  final double distanceM;
  final Duration duration;
  final int steps;
  final double kcal;
  final double met;

  const RouteEstimate({
    required this.mode,
    required this.distanceM,
    required this.duration,
    required this.steps,
    required this.kcal,
    required this.met,
  });
}
