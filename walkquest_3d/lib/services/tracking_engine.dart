import 'dart:math' as math;

import '../models/activity_mode.dart';
import '../models/app_settings.dart';
import '../models/lat_lng.dart';
import '../utils/geo_utils.dart';
import '../utils/leveling.dart';
import 'location_service.dart';
import 'route_calculator.dart';
import 'territory_service.dart';

/// Things worth telling the player about (voice cues, pop-ups).
sealed class TrackingEvent {
  const TrackingEvent();
}

class StepsMilestone extends TrackingEvent {
  final int steps;
  final double remainingM;
  const StepsMilestone(this.steps, this.remainingM);
}

class DistanceMilestone extends TrackingEvent {
  final int km;
  final double remainingM;
  const DistanceMilestone(this.km, this.remainingM);
}

class HalfwayReached extends TrackingEvent {
  const HalfwayReached();
}

class WentOffRoute extends TrackingEvent {
  const WentOffRoute();
}

class BackOnRoute extends TrackingEvent {
  const BackOnRoute();
}

class DestinationReached extends TrackingEvent {
  const DestinationReached();
}

class LoopClosed extends TrackingEvent {
  final List<LatLng> ring;
  const LoopClosed(this.ring);
}

class VehicleSuspected extends TrackingEvent {
  const VehicleSuspected();
}

/// Immutable view of the live session for the UI.
class TrackingSnapshot {
  final double distanceM;
  final int steps;
  final bool stepsFromSensor;
  final Duration movingTime;
  final double kcal;
  final int coins;
  final double currentSpeedKmh;

  /// Route-relative numbers (0 / null when there is no planned route).
  final double routeFraction;
  final double remainingM;
  final Duration remainingTime;
  final int remainingSteps;
  final bool offRoute;
  final bool arrived;

  final LatLng? avatarPosition;
  final double avatarBearing;

  const TrackingSnapshot({
    this.distanceM = 0,
    this.steps = 0,
    this.stepsFromSensor = false,
    this.movingTime = Duration.zero,
    this.kcal = 0,
    this.coins = 0,
    this.currentSpeedKmh = 0,
    this.routeFraction = 0,
    this.remainingM = 0,
    this.remainingTime = Duration.zero,
    this.remainingSteps = 0,
    this.offRoute = false,
    this.arrived = false,
    this.avatarPosition,
    this.avatarBearing = 0,
  });
}

/// Pure session logic: GPS filtering, distance/time accumulation, route
/// snapping & progress, milestones, arrival and loop (territory) detection.
///
/// No plugins or timers — feed it fixes and step counts, read [snapshot].
class TrackingEngine {
  TrackingEngine({required this.mode, required this.settings, List<LatLng>? route, this.coinMultiplier = 1})
    : route = route ?? const [],
      _routeCum = route == null || route.isEmpty ? const [] : GeoUtils.cumulative(route);

  final ActivityMode mode;
  final AppSettings settings;
  final List<LatLng> route;
  final List<double> _routeCum;
  final int coinMultiplier;

  // Tunables
  static const maxAccuracyM = 35.0;
  static const maxHumanSpeedMps = 8.5; // ~30 km/h, faster = vehicle
  static const offRouteM = 45.0;
  static const arrivalRadiusM = 25.0;
  static const stepsCueEvery = 500;

  final List<LatLng> path = [];
  GpsFix? _lastFix;
  double _distanceM = 0;
  Duration _moving = Duration.zero;
  int _sensorSteps = 0;
  bool _sensorActive = false;
  double _speedKmh = 0;
  double _alongM = 0;
  bool _offRoute = false;
  bool _arrived = false;
  bool _paused = false;
  bool _halfwayAnnounced = false;
  int _lastStepsCue = 0;
  int _lastKmCue = 0;
  int _loopSearchFrom = 0;
  LatLng? _avatar;
  double _bearing = 0;

  bool get hasRoute => route.length >= 2;
  double get routeLengthM => _routeCum.isEmpty ? 0 : _routeCum.last;
  bool get paused => _paused;

  void pause() => _paused = true;

  void resume() {
    _paused = false;
    // Don't bridge the gap with a straight line: next fix starts fresh.
    _lastFix = null;
  }

  int get steps => _sensorActive ? _sensorSteps : RouteCalculator.stepsFor(_distanceM, settings.strideFor(mode));

  /// Feed the session-relative pedometer count.
  void setSensorSteps(int steps) {
    _sensorActive = true;
    _sensorSteps = steps;
  }

  /// Processes one GPS fix and returns any events it triggered.
  List<TrackingEvent> addFix(GpsFix fix) {
    final events = <TrackingEvent>[];
    if (_paused || _arrived) return events;
    if (fix.accuracyM > maxAccuracyM && path.isNotEmpty) return events;

    final prev = _lastFix;
    if (prev == null) {
      _accept(fix);
      _updateRoute(fix.position, events);
      return events;
    }

    final d = GeoUtils.distanceM(prev.position, fix.position);
    final dt = fix.timestamp.difference(prev.timestamp);
    final secs = dt.inMilliseconds / 1000;

    // Ignore jitter smaller than the fix uncertainty.
    if (d < math.max(3.0, fix.accuracyM * 0.5)) {
      if (secs > 10) _speedKmh = 0;
      return events;
    }
    if (secs > 0 && d / secs > maxHumanSpeedMps) {
      _lastFix = fix; // resync, but don't count the distance
      events.add(const VehicleSuspected());
      return events;
    }

    _distanceM += d;
    // Count time as "moving" only for plausible gaps (no long stalls).
    if (secs > 0 && secs < 30) _moving += dt;
    _speedKmh = secs > 0 ? (d / secs) * 3.6 : _speedKmh;
    if (!hasRoute) _bearing = GeoUtils.bearing(prev.position, fix.position);
    _accept(fix);

    _updateRoute(fix.position, events);
    _milestones(events);
    _checkLoop(events);
    return events;
  }

  void _accept(GpsFix fix) {
    _lastFix = fix;
    path.add(fix.position);
    _avatar = fix.position;
  }

  void _updateRoute(LatLng p, List<TrackingEvent> events) {
    if (!hasRoute) return;
    final snap = GeoUtils.snapToPath(p, route, cumulativeM: _routeCum, minAlongM: math.max(0, _alongM - 30));
    final wasOff = _offRoute;
    _offRoute = snap.offRouteM > offRouteM;
    if (!_offRoute) {
      _alongM = math.max(_alongM, snap.alongM);
      _avatar = GeoUtils.pointAlong(route, _alongM, _routeCum);
      _bearing = GeoUtils.bearingAlong(route, _alongM, _routeCum);
    }
    if (_offRoute && !wasOff) events.add(const WentOffRoute());
    if (!_offRoute && wasOff) events.add(const BackOnRoute());

    if (!_halfwayAnnounced && _alongM >= routeLengthM / 2 && routeLengthM > 300) {
      _halfwayAnnounced = true;
      events.add(const HalfwayReached());
    }
    final toDest = GeoUtils.distanceM(p, route.last);
    if (toDest <= arrivalRadiusM || routeLengthM - _alongM <= arrivalRadiusM * 0.8) {
      _arrived = true;
      _alongM = routeLengthM;
      _avatar = route.last;
      events.add(const DestinationReached());
    }
  }

  void _milestones(List<TrackingEvent> events) {
    final cue = (steps ~/ stepsCueEvery) * stepsCueEvery;
    if (cue > _lastStepsCue) {
      _lastStepsCue = cue;
      events.add(StepsMilestone(cue, remainingM));
    }
    final km = (_distanceM / 1000).floor();
    if (km > _lastKmCue) {
      _lastKmCue = km;
      events.add(DistanceMilestone(km, remainingM));
    }
  }

  void _checkLoop(List<TrackingEvent> events) {
    final start = TerritoryService.findLoopStart(path, searchFrom: _loopSearchFrom);
    if (start != null) {
      events.add(LoopClosed(path.sublist(start)));
      _loopSearchFrom = path.length - 1; // loops can't overlap
    }
  }

  double get remainingM => hasRoute ? math.max(0, routeLengthM - _alongM) : 0;

  TrackingSnapshot get snapshot {
    final remaining = remainingM;
    final speed = settings.speedKmhFor(mode);
    return TrackingSnapshot(
      distanceM: _distanceM,
      steps: steps,
      stepsFromSensor: _sensorActive,
      movingTime: _moving,
      kcal: RouteCalculator.kcalFor(
        mode: mode,
        distanceM: _distanceM,
        movingTime: _moving,
        weightKg: settings.weightKg,
      ),
      coins: (steps ~/ 100) * Leveling.coinsPer100Steps * coinMultiplier,
      currentSpeedKmh: _speedKmh,
      routeFraction: hasRoute && routeLengthM > 0 ? (_alongM / routeLengthM).clamp(0, 1) : 0,
      remainingM: remaining,
      remainingTime: Duration(seconds: speed <= 0 ? 0 : (remaining / 1000 / speed * 3600).round()),
      remainingSteps: RouteCalculator.stepsFor(remaining, settings.strideFor(mode)),
      offRoute: _offRoute,
      arrived: _arrived,
      avatarPosition: _avatar,
      avatarBearing: _bearing,
    );
  }
}
