import 'package:flutter_test/flutter_test.dart';
import 'package:walkquest_3d/models/activity_mode.dart';
import 'package:walkquest_3d/models/app_settings.dart';
import 'package:walkquest_3d/models/lat_lng.dart';
import 'package:walkquest_3d/services/location_service.dart';
import 'package:walkquest_3d/services/tracking_engine.dart';
import 'package:walkquest_3d/utils/geo_utils.dart';

void main() {
  const origin = LatLng(51.5007, -0.1246);
  final t0 = DateTime(2026, 10, 7, 8);

  GpsFix fix(LatLng p, int sec, {double acc = 5}) => GpsFix(
    position: p,
    accuracyM: acc,
    speedMps: 1.4,
    heading: 0,
    timestamp: t0.add(Duration(seconds: sec)),
  );

  /// Straight 1 km route due east.
  final route = [origin, GeoUtils.destinationPoint(origin, 1000, 90)];

  test('walks a route to arrival with milestones', () {
    final e = TrackingEngine(mode: ActivityMode.walking, settings: const AppSettings(), route: route);
    final events = <TrackingEvent>[];
    // 1.4 m/s, a fix every 5 s → 7 m per fix.
    for (var i = 0; i <= 150; i++) {
      events.addAll(e.addFix(fix(GeoUtils.destinationPoint(origin, i * 7.0, 90), i * 5)));
      if (e.snapshot.arrived) break;
    }
    final s = e.snapshot;
    expect(s.arrived, isTrue);
    expect(s.routeFraction, 1);
    expect(s.distanceM, closeTo(980, 30));
    expect(s.steps, closeTo(1400, 50)); // distance / 0.7 m stride (no sensor)
    expect(events.whereType<HalfwayReached>(), hasLength(1));
    expect(events.whereType<StepsMilestone>().map((m) => m.steps), containsAllInOrder([500, 1000]));
    expect(events.whereType<DestinationReached>(), hasLength(1));
    expect(s.movingTime.inSeconds, closeTo(700, 30));
    expect(s.kcal, greaterThan(30));
  });

  test('ignores GPS jitter and inaccurate fixes', () {
    final e = TrackingEngine(mode: ActivityMode.walking, settings: const AppSettings(), route: route);
    e.addFix(fix(origin, 0));
    for (var i = 1; i < 20; i++) {
      e.addFix(fix(GeoUtils.destinationPoint(origin, 1.5, i * 37.0), i)); // ±1.5 m wobble
    }
    e.addFix(fix(GeoUtils.destinationPoint(origin, 200, 0), 25, acc: 80)); // bad fix
    expect(e.snapshot.distanceM, 0);
  });

  test('flags vehicle speeds and does not count them', () {
    final e = TrackingEngine(mode: ActivityMode.running, settings: const AppSettings(), route: route);
    e.addFix(fix(origin, 0));
    final ev = e.addFix(fix(GeoUtils.destinationPoint(origin, 300, 90), 10)); // 30 m/s
    expect(ev.whereType<VehicleSuspected>(), isNotEmpty);
    expect(e.snapshot.distanceM, 0);
  });

  test('detects going off route and coming back', () {
    final e = TrackingEngine(mode: ActivityMode.walking, settings: const AppSettings(), route: route);
    e.addFix(fix(origin, 0));
    final off = e.addFix(fix(GeoUtils.destinationPoint(GeoUtils.destinationPoint(origin, 50, 90), 80, 0), 60));
    expect(off.whereType<WentOffRoute>(), isNotEmpty);
    expect(e.snapshot.offRoute, isTrue);
    final back = e.addFix(fix(GeoUtils.destinationPoint(origin, 100, 90), 120));
    expect(back.whereType<BackOnRoute>(), isNotEmpty);
  });

  test('sensor steps override stride estimates and drive coins', () {
    final e = TrackingEngine(mode: ActivityMode.walking, settings: const AppSettings(), coinMultiplier: 2);
    e.setSensorSteps(1234);
    expect(e.snapshot.steps, 1234);
    expect(e.snapshot.coins, 24); // 12 × 2
  });

  test('free roam loop closes into territory', () {
    final e = TrackingEngine(mode: ActivityMode.walking, settings: const AppSettings());
    final corners = [
      origin,
      GeoUtils.destinationPoint(origin, 150, 0),
      GeoUtils.destinationPoint(GeoUtils.destinationPoint(origin, 150, 0), 150, 90),
      GeoUtils.destinationPoint(origin, 150, 90),
      origin,
    ];
    final events = <TrackingEvent>[];
    var sec = 0;
    for (var c = 0; c < corners.length - 1; c++) {
      for (var i = 0; i < 15; i++) {
        final p = GeoUtils.lerp(corners[c], corners[c + 1], i / 15);
        events.addAll(e.addFix(fix(p, sec += 7)));
      }
    }
    events.addAll(e.addFix(fix(origin, sec += 7)));
    final loops = events.whereType<LoopClosed>().toList();
    expect(loops, hasLength(1));
    expect(GeoUtils.polygonAreaM2(loops.first.ring), closeTo(22500, 1500));
  });

  test('pause discards movement until resumed', () {
    final e = TrackingEngine(mode: ActivityMode.walking, settings: const AppSettings(), route: route);
    e.addFix(fix(origin, 0));
    e.pause();
    e.addFix(fix(GeoUtils.destinationPoint(origin, 100, 90), 60));
    e.resume();
    e.addFix(fix(GeoUtils.destinationPoint(origin, 110, 90), 70)); // re-anchor
    e.addFix(fix(GeoUtils.destinationPoint(origin, 120, 90), 77));
    expect(e.snapshot.distanceM, closeTo(10, 1));
  });
}
