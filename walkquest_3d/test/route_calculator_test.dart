import 'package:flutter_test/flutter_test.dart';
import 'package:walkquest_3d/models/activity_mode.dart';
import 'package:walkquest_3d/models/app_settings.dart';
import 'package:walkquest_3d/services/route_calculator.dart';
import 'package:walkquest_3d/utils/formatters.dart';

void main() {
  const settings = AppSettings(); // 70 kg, 5 / 10 km/h, 0.7 / 1.0 m strides

  test('spec example: ~1.17 km route', () {
    const d = 1167.0;
    final walk = RouteCalculator.estimate(distanceM: d, mode: ActivityMode.walking, settings: settings);
    final run = RouteCalculator.estimate(distanceM: d, mode: ActivityMode.running, settings: settings);

    expect(Fmt.duration(walk.duration), '14 min');
    expect(Fmt.duration(run.duration), '7 min');
    expect(walk.steps, 1667); // 1167 / 0.7
    expect(Fmt.approx(walk.steps), '~1,700');
    expect(run.steps, 1167); // 1167 / 1.0
    // MET 3.38 × 70 kg × 0.233 h ≈ 55 kcal
    expect(walk.kcal, closeTo(55, 3));
  });

  test('time = distance / speed', () {
    final e = RouteCalculator.estimate(distanceM: 5000, mode: ActivityMode.walking, settings: settings);
    expect(e.duration, const Duration(hours: 1));
  });

  test('MET from ACSM equations matches compendium ballpark', () {
    expect(RouteCalculator.met(ActivityMode.walking, 5), closeTo(3.4, 0.1));
    expect(RouteCalculator.met(ActivityMode.running, 10), closeTo(10.5, 0.1));
    // Climbing costs more.
    expect(
      RouteCalculator.met(ActivityMode.walking, 5, grade: 0.05),
      greaterThan(RouteCalculator.met(ActivityMode.walking, 5)),
    );
  });

  test('calories = MET × weight × hours', () {
    final e = RouteCalculator.estimate(distanceM: 10000, mode: ActivityMode.running, settings: settings);
    expect(e.kcal, closeTo(e.met * 70 * 1, 0.001));
  });

  test('settings changes flow through', () {
    final s = settings.copyWith(walkingStrideM: 0.8, weightKg: 90);
    final e = RouteCalculator.estimate(distanceM: 800, mode: ActivityMode.walking, settings: s);
    expect(e.steps, 1000);
    final base = RouteCalculator.estimate(distanceM: 800, mode: ActivityMode.walking, settings: settings);
    expect(e.kcal, closeTo(base.kcal * 90 / 70, 0.01));
  });

  test('tracked kcal treats slow "running" as walking', () {
    final slow = RouteCalculator.kcalFor(
      mode: ActivityMode.running,
      distanceM: 1000,
      movingTime: const Duration(minutes: 12),
      weightKg: 70,
    );
    final walk = RouteCalculator.kcalFor(
      mode: ActivityMode.walking,
      distanceM: 1000,
      movingTime: const Duration(minutes: 12),
      weightKg: 70,
    );
    expect(slow, walk);
  });
}
