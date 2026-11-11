import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/activity_mode.dart';
import '../models/app_settings.dart';
import '../models/lat_lng.dart';
import '../models/quest.dart';
import '../models/route_plan.dart';
import '../models/territory.dart';
import '../models/walk_session.dart';
import '../services/location_service.dart';
import '../services/step_counter_service.dart';
import '../services/territory_service.dart';
import '../services/tracking_engine.dart';
import '../services/voice_service.dart';
import '../utils/formatters.dart';
import '../utils/geo_utils.dart';

/// Drives a live quest: wires GPS + pedometer (or the demo simulator) into a
/// [TrackingEngine], speaks voice cues and exposes state to the UI.
class TrackingController extends ChangeNotifier {
  TrackingController({LocationService? location, StepCounterService? steps, VoiceService? voice})
    : _location = location ?? LocationService(),
      _steps = steps ?? StepCounterService(),
      _voice = voice ?? VoiceService();

  final LocationService _location;
  final StepCounterService _steps;
  final VoiceService _voice;

  TrackingEngine? _engine;
  StreamSubscription<GpsFix>? _gpsSub;
  StreamSubscription<int>? _stepSub;
  Timer? _ticker;
  Timer? _simTimer;

  ActivityMode mode = ActivityMode.walking;
  RoutePlan? plan;
  Quest? quest;
  late AppSettings _settings;
  String _ownerUid = '';
  DateTime? _startedAt;
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;
  final List<Territory> captured = [];

  /// Short-lived banner text for the latest event ("Halfway there!").
  String? banner;
  DateTime? _bannerAt;

  bool get isActive => _engine != null;
  bool get isPaused => _engine?.paused ?? false;
  TrackingSnapshot get snapshot => _engine?.snapshot ?? const TrackingSnapshot();
  List<LatLng> get path => _engine?.path ?? const [];
  bool get simulated => _settings.demoMode;

  Duration get elapsed {
    final s = _startedAt;
    if (s == null) return Duration.zero;
    final end = _pausedAt ?? DateTime.now();
    return end.difference(s) - _pausedTotal;
  }

  /// Starts tracking. Returns an error message if permissions are missing.
  Future<String?> start({
    required ActivityMode mode,
    required AppSettings settings,
    required String ownerUid,
    RoutePlan? plan,
    Quest? quest,
    int coinMultiplier = 1,
    LatLng? freeRoamOrigin,
  }) async {
    await _teardown();
    this.mode = mode;
    this.plan = plan;
    this.quest = quest;
    _settings = settings;
    _ownerUid = ownerUid;
    _voice.enabled = settings.voiceCues;
    captured.clear();
    _pausedTotal = Duration.zero;
    _pausedAt = null;
    banner = null;

    _engine = TrackingEngine(mode: mode, settings: settings, route: plan?.geometry, coinMultiplier: coinMultiplier);

    if (settings.demoMode) {
      _startSimulation(freeRoamOrigin ?? plan?.origin);
    } else {
      final access = await _location.ensurePermission();
      if (access != LocationAccess.granted) {
        _engine = null;
        return access == LocationAccess.serviceDisabled
            ? 'Turn on location services to start a quest.'
            : 'WalkQuest needs location access to track your quest.';
      }
      _gpsSub = _location.trackingStream().listen(_onFix);
      if (await _steps.ensurePermission()) {
        await _steps.start();
        _stepSub = _steps.sessionSteps.listen((s) {
          _engine?.setSensorSteps(s);
          notifyListeners();
        });
      }
    }

    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (banner != null && DateTime.now().difference(_bannerAt!) > const Duration(seconds: 5)) {
        banner = null;
      }
      notifyListeners();
    });
    final dest = plan?.destination.name;
    _voice.say(
      dest == null
          ? 'Free roam started. Walk a loop to capture territory!'
          : 'Quest started. ${mode == ActivityMode.walking ? 'Walk' : 'Run'} to $dest. '
                '${_distanceWords(plan!.distanceM)} to go.',
    );
    notifyListeners();
    return null;
  }

  void _onFix(GpsFix fix) {
    final engine = _engine;
    if (engine == null) return;
    for (final e in engine.addFix(fix)) {
      _handle(e);
    }
    notifyListeners();
  }

  void _handle(TrackingEvent e) {
    final remaining = snapshot.remainingM;
    final hasRoute = plan != null;
    switch (e) {
      case StepsMilestone(:final steps):
        _say(
          'You have walked ${Fmt.count(steps)} steps. '
          '${hasRoute ? '${_distanceWords(remaining)} to go!' : 'Keep going!'}',
        );
      case DistanceMilestone(:final km):
        _say('$km ${km == 1 ? 'kilometer' : 'kilometers'} done.', show: false);
      case HalfwayReached():
        _say('Halfway there! ${_distanceWords(remaining)} to go.');
      case WentOffRoute():
        _say("You're off route. Head back to the glowing path.");
      case BackOnRoute():
        _flash('Back on route ✨');
      case DestinationReached():
        _say('Quest complete! You reached ${plan?.destination.name ?? 'your destination'}.');
      case LoopClosed(:final ring):
        final t = TerritoryService.build(ring: ring, ownerUid: _ownerUid);
        captured.add(t);
        _say('Territory captured: ${t.name}!');
      case VehicleSuspected():
        _flash('Moving too fast — distance paused 🚗');
    }
  }

  void _say(String text, {bool show = true}) {
    if (show) _flash(text);
    _voice.say(text);
  }

  void _flash(String text) {
    banner = text;
    _bannerAt = DateTime.now();
  }

  String _distanceWords(double m) {
    if (_settings.useMiles) {
      final mi = m / Fmt.metersPerMile;
      return mi >= 0.95 ? '${mi.toStringAsFixed(1)} miles' : '${(m * 1.09361).round()} yards';
    }
    return m >= 950 ? '${(m / 1000).toStringAsFixed(1)} kilometers' : '${(m / 10).round() * 10} meters';
  }

  // ------------------------------------------------------------- Simulation

  /// Demo mode: walks the route (or a square loop for free roam) at 4× the
  /// configured speed so features can be tried indoors / in a simulator.
  void _startSimulation(LatLng? origin) {
    final start = origin ?? const LatLng(37.7793, -122.4193);
    final route =
        plan?.geometry ??
        [
          start,
          GeoUtils.destinationPoint(start, 160, 0),
          GeoUtils.destinationPoint(GeoUtils.destinationPoint(start, 160, 0), 160, 90),
          GeoUtils.destinationPoint(start, 160, 90),
          GeoUtils.destinationPoint(start, 5, 200),
        ];
    final cum = GeoUtils.cumulative(route);
    final speedMps = _settings.speedKmhFor(mode) / 3.6 * 4;
    final rnd = math.Random();
    var along = 0.0;
    var simTime = DateTime.now();
    var stepsSoFar = 0.0;
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isPaused) return;
      along += speedMps;
      simTime = simTime.add(const Duration(seconds: 4)); // 4× time to match 4× speed
      final p = GeoUtils.pointAlong(route, math.min(along, cum.last), cum);
      final jitter = GeoUtils.destinationPoint(p, rnd.nextDouble() * 2, rnd.nextDouble() * 360);
      stepsSoFar += speedMps / _settings.strideFor(mode) * (0.95 + rnd.nextDouble() * 0.1);
      _engine?.setSensorSteps(stepsSoFar.round());
      _onFix(GpsFix(position: jitter, accuracyM: 5, speedMps: speedMps / 4, heading: 0, timestamp: simTime));
      if (along >= cum.last + 20) _simTimer?.cancel();
    });
  }

  // ---------------------------------------------------------------- Control

  void pause() {
    if (_engine == null || isPaused) return;
    _engine!.pause();
    _steps.pause();
    _pausedAt = DateTime.now();
    _voice.say('Quest paused.');
    notifyListeners();
  }

  void resume() {
    if (_engine == null || !isPaused) return;
    _engine!.resume();
    _steps.resume();
    if (_pausedAt != null) _pausedTotal += DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    _voice.say('Quest resumed.');
    notifyListeners();
  }

  /// Ends the session and returns the record (null if nothing was tracked).
  Future<WalkSession?> finish() async {
    final engine = _engine;
    if (engine == null) return null;
    final s = engine.snapshot;
    final now = DateTime.now();
    final session = WalkSession(
      id: 'ses_${now.millisecondsSinceEpoch}',
      mode: mode,
      startedAt: _startedAt ?? now,
      endedAt: now,
      // Prefer GPS moving time; fall back to wall-clock minus pauses.
      activeDuration: s.movingTime > Duration.zero ? s.movingTime : elapsed,
      distanceM: s.distanceM,
      steps: s.steps,
      kcal: s.kcal,
      path: _settings.hideRouteEndpoints ? GeoUtils.trimEnds(engine.path, 100) : List.of(engine.path),
      destinationName: plan?.destination.name,
      questId: quest?.id,
      reachedDestination: s.arrived,
    );
    await _teardown();
    notifyListeners();
    return session.distanceM < 10 && session.steps < 20 ? null : session;
  }

  Future<void> cancel() async {
    await _teardown();
    notifyListeners();
  }

  Future<void> _teardown() async {
    await _gpsSub?.cancel();
    await _stepSub?.cancel();
    await _steps.stop();
    _ticker?.cancel();
    _simTimer?.cancel();
    _gpsSub = null;
    _stepSub = null;
    _ticker = null;
    _simTimer = null;
    _engine = null;
    _startedAt = null;
  }

  @override
  void dispose() {
    _teardown();
    _steps.dispose();
    _voice.stop();
    super.dispose();
  }
}
