import 'package:health/health.dart';

import '../models/activity_mode.dart';
import '../models/walk_session.dart';

/// Optional HealthKit (iOS) / Health Connect (Android) sync.
///
/// Reads the day's total steps (so steps walked outside the app still count
/// toward streaks) and writes finished quests back as workouts.
class HealthService {
  final Health _health = Health();
  bool _configured = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];

  Future<bool> authorize() async {
    try {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      return await _health.requestAuthorization(
        _types,
        permissions: const [
          HealthDataAccess.READ,
          HealthDataAccess.READ_WRITE,
          HealthDataAccess.READ_WRITE,
          HealthDataAccess.READ_WRITE,
        ],
      );
    } catch (_) {
      return false;
    }
  }

  Future<int?> stepsToday() async {
    try {
      final now = DateTime.now();
      return await _health.getTotalStepsInInterval(DateTime(now.year, now.month, now.day), now);
    } catch (_) {
      return null;
    }
  }

  Future<bool> writeSession(WalkSession s) async {
    try {
      return await _health.writeWorkoutData(
        activityType: s.mode == ActivityMode.running
            ? HealthWorkoutActivityType.RUNNING
            : HealthWorkoutActivityType.WALKING,
        start: s.startedAt,
        end: s.endedAt,
        totalDistance: s.distanceM.round(),
        totalEnergyBurned: s.kcal.round(),
        title: s.destinationName == null ? 'WalkQuest ${s.mode.label}' : 'WalkQuest: ${s.destinationName}',
      );
    } catch (_) {
      return false;
    }
  }
}
