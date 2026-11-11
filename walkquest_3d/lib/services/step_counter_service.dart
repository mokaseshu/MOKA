import 'dart:async';
import 'dart:io' show Platform;

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Session-relative step counting on top of the device pedometer
/// (Android TYPE_STEP_COUNTER sensor / iOS CMPedometer).
///
/// The platform stream reports a cumulative count (since boot on Android),
/// so we accumulate deltas between events: steps during a pause are skipped
/// and a counter reset (reboot) never produces negative steps.
class StepCounterService {
  StreamSubscription<StepCount>? _sub;
  int? _lastRaw;
  int _counted = 0;
  bool _paused = false;
  bool _available = false;

  final _controller = StreamController<int>.broadcast();

  /// Steps counted in the current session (excluding paused periods).
  Stream<int> get sessionSteps => _controller.stream;
  int get currentSteps => _counted;

  /// Whether the hardware pedometer delivered at least one event. When false,
  /// callers should fall back to distance / stride estimation.
  bool get isAvailable => _available;

  Future<bool> ensurePermission() async {
    if (Platform.isAndroid) {
      return (await Permission.activityRecognition.request()).isGranted;
    }
    if (Platform.isIOS) {
      // CMPedometer shows the Motion & Fitness prompt on first use.
      return !(await Permission.sensors.request()).isPermanentlyDenied;
    }
    return false;
  }

  Future<void> start() async {
    await stop();
    _lastRaw = null;
    _counted = 0;
    _paused = false;
    _available = false;
    _sub = Pedometer.stepCountStream.listen((event) => onRawCount(event.steps), onError: (_) => _available = false);
  }

  /// Visible for testing: feed a raw cumulative count.
  void onRawCount(int raw) {
    _available = true;
    final last = _lastRaw;
    _lastRaw = raw;
    if (last == null) return; // first event is the baseline
    final delta = raw - last;
    if (delta <= 0 || _paused) return;
    _counted += delta;
    if (!_controller.isClosed) _controller.add(_counted);
  }

  void pause() => _paused = true;
  void resume() => _paused = false;

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
