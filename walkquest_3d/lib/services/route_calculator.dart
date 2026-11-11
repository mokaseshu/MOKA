import '../models/activity_mode.dart';
import '../models/app_settings.dart';
import '../models/route_plan.dart';

/// Pure route-statistics math.
///
///   time     = distance / speed
///   steps    = distance (m) / stride length (m)
///   calories = MET × weight (kg) × time (h)
///
/// MET is derived from speed (and optionally grade) with the ACSM metabolic
/// equations, so a user who changes their speed in Settings gets consistent
/// calories:
///   walking VO2 = 0.1·v + 1.8·v·grade + 3.5   (ml/kg/min, v in m/min)
///   running VO2 = 0.2·v + 0.9·v·grade + 3.5
///   MET = VO2 / 3.5
/// At the defaults this gives ~3.4 MET walking (5 km/h) and ~10.5 MET
/// running (10 km/h), in line with the Compendium of Physical Activities.
class RouteCalculator {
  RouteCalculator._();

  static double met(ActivityMode mode, double speedKmh, {double grade = 0}) {
    final v = speedKmh * 1000 / 60; // m/min
    final g = grade.clamp(0.0, 0.25);
    final vo2 = mode == ActivityMode.walking ? 0.1 * v + 1.8 * v * g + 3.5 : 0.2 * v + 0.9 * v * g + 3.5;
    return vo2 / 3.5;
  }

  static RouteEstimate estimate({
    required double distanceM,
    required ActivityMode mode,
    required AppSettings settings,
    double elevationGainM = 0,
  }) {
    final speed = settings.speedKmhFor(mode);
    final hours = speed <= 0 ? 0.0 : (distanceM / 1000) / speed;
    // Average grade over the route (only climbing costs extra energy here).
    final grade = distanceM <= 0 ? 0.0 : elevationGainM / distanceM;
    final m = met(mode, speed, grade: grade);
    return RouteEstimate(
      mode: mode,
      distanceM: distanceM,
      duration: Duration(seconds: (hours * 3600).round()),
      steps: stepsFor(distanceM, settings.strideFor(mode)),
      kcal: m * settings.weightKg * hours,
      met: m,
    );
  }

  static int stepsFor(double distanceM, double strideM) => strideM <= 0 ? 0 : (distanceM / strideM).round();

  /// Calories for an actual (tracked) effort.
  static double kcalFor({
    required ActivityMode mode,
    required double distanceM,
    required Duration movingTime,
    required double weightKg,
  }) {
    final hours = movingTime.inMilliseconds / 3600000;
    if (hours <= 0 || distanceM <= 0) return 0;
    final speedKmh = (distanceM / 1000) / hours;
    // A "running" session done at a walking pace burns walking calories.
    final effectiveMode = speedKmh < 6.5 ? ActivityMode.walking : mode;
    return met(effectiveMode, speedKmh.clamp(2.0, 20.0)) * weightKg * hours;
  }
}
