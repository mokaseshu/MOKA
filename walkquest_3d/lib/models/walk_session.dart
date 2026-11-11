import 'activity_mode.dart';
import 'lat_lng.dart';

/// One completed (or abandoned) walk/run.
class WalkSession {
  final String id;
  final ActivityMode mode;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Moving time, excluding pauses.
  final Duration activeDuration;
  final double distanceM;
  final int steps;
  final double kcal;
  final int coinsEarned;
  final int xpEarned;
  final List<LatLng> path;
  final String? destinationName;
  final String? questId;
  final bool reachedDestination;

  const WalkSession({
    required this.id,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.activeDuration,
    required this.distanceM,
    required this.steps,
    required this.kcal,
    this.coinsEarned = 0,
    this.xpEarned = 0,
    this.path = const [],
    this.destinationName,
    this.questId,
    this.reachedDestination = false,
  });

  double get avgSpeedKmh => activeDuration.inSeconds == 0 ? 0 : (distanceM / 1000) / (activeDuration.inSeconds / 3600);

  /// Minutes per km.
  double get paceMinPerKm => distanceM < 1 ? 0 : (activeDuration.inSeconds / 60) / (distanceM / 1000);

  WalkSession copyWith({int? coinsEarned, int? xpEarned, List<LatLng>? path}) => WalkSession(
    id: id,
    mode: mode,
    startedAt: startedAt,
    endedAt: endedAt,
    activeDuration: activeDuration,
    distanceM: distanceM,
    steps: steps,
    kcal: kcal,
    coinsEarned: coinsEarned ?? this.coinsEarned,
    xpEarned: xpEarned ?? this.xpEarned,
    path: path ?? this.path,
    destinationName: destinationName,
    questId: questId,
    reachedDestination: reachedDestination,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode.name,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'activeSeconds': activeDuration.inSeconds,
    'distanceM': distanceM,
    'steps': steps,
    'kcal': kcal,
    'coinsEarned': coinsEarned,
    'xpEarned': xpEarned,
    // Flat [lng,lat,lng,lat,...] keeps Firestore docs small (no nested arrays allowed).
    'path': [for (final p in path) ...p.toLngLat()],
    'destinationName': destinationName,
    'questId': questId,
    'reachedDestination': reachedDestination,
  };

  factory WalkSession.fromJson(Map<String, dynamic> j) {
    final flat = (j['path'] as List? ?? const []).cast<num>();
    return WalkSession(
      id: j['id'] as String,
      mode: ActivityMode.fromName(j['mode'] as String?),
      startedAt: DateTime.parse(j['startedAt'] as String),
      endedAt: DateTime.parse(j['endedAt'] as String),
      activeDuration: Duration(seconds: (j['activeSeconds'] as num).toInt()),
      distanceM: (j['distanceM'] as num).toDouble(),
      steps: (j['steps'] as num).toInt(),
      kcal: (j['kcal'] as num).toDouble(),
      coinsEarned: (j['coinsEarned'] as num?)?.toInt() ?? 0,
      xpEarned: (j['xpEarned'] as num?)?.toInt() ?? 0,
      path: [for (var i = 0; i + 1 < flat.length; i += 2) LatLng(flat[i + 1].toDouble(), flat[i].toDouble())],
      destinationName: j['destinationName'] as String?,
      questId: j['questId'] as String?,
      reachedDestination: j['reachedDestination'] as bool? ?? false,
    );
  }
}
