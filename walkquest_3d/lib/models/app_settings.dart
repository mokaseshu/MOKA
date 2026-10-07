import 'package:flutter/material.dart';

import 'activity_mode.dart';

/// User-tunable settings. Persisted locally (SharedPreferences).
class AppSettings {
  final bool useMiles;
  final double walkingStrideM;
  final double runningStrideM;
  final double weightKg;
  final double walkingSpeedKmh;
  final double runningSpeedKmh;
  final bool arMode;
  final bool voiceCues;
  final ThemeMode themeMode;
  final bool terrain3d;

  // Privacy
  final bool shareLocationWithFriends;
  final bool hideRouteEndpoints;
  final bool saveRouteHistory;

  // Integrations / dev
  final bool healthSync;
  final bool demoMode;

  const AppSettings({
    this.useMiles = false,
    this.walkingStrideM = 0.7,
    this.runningStrideM = 1.0,
    this.weightKg = 70,
    this.walkingSpeedKmh = 5,
    this.runningSpeedKmh = 10,
    this.arMode = false,
    this.voiceCues = true,
    this.themeMode = ThemeMode.system,
    this.terrain3d = true,
    this.shareLocationWithFriends = false,
    this.hideRouteEndpoints = true,
    this.saveRouteHistory = true,
    this.healthSync = false,
    this.demoMode = false,
  });

  double strideFor(ActivityMode m) => m == ActivityMode.walking ? walkingStrideM : runningStrideM;

  double speedKmhFor(ActivityMode m) => m == ActivityMode.walking ? walkingSpeedKmh : runningSpeedKmh;

  AppSettings copyWith({
    bool? useMiles,
    double? walkingStrideM,
    double? runningStrideM,
    double? weightKg,
    double? walkingSpeedKmh,
    double? runningSpeedKmh,
    bool? arMode,
    bool? voiceCues,
    ThemeMode? themeMode,
    bool? terrain3d,
    bool? shareLocationWithFriends,
    bool? hideRouteEndpoints,
    bool? saveRouteHistory,
    bool? healthSync,
    bool? demoMode,
  }) => AppSettings(
    useMiles: useMiles ?? this.useMiles,
    walkingStrideM: walkingStrideM ?? this.walkingStrideM,
    runningStrideM: runningStrideM ?? this.runningStrideM,
    weightKg: weightKg ?? this.weightKg,
    walkingSpeedKmh: walkingSpeedKmh ?? this.walkingSpeedKmh,
    runningSpeedKmh: runningSpeedKmh ?? this.runningSpeedKmh,
    arMode: arMode ?? this.arMode,
    voiceCues: voiceCues ?? this.voiceCues,
    themeMode: themeMode ?? this.themeMode,
    terrain3d: terrain3d ?? this.terrain3d,
    shareLocationWithFriends: shareLocationWithFriends ?? this.shareLocationWithFriends,
    hideRouteEndpoints: hideRouteEndpoints ?? this.hideRouteEndpoints,
    saveRouteHistory: saveRouteHistory ?? this.saveRouteHistory,
    healthSync: healthSync ?? this.healthSync,
    demoMode: demoMode ?? this.demoMode,
  );

  Map<String, dynamic> toJson() => {
    'useMiles': useMiles,
    'walkingStrideM': walkingStrideM,
    'runningStrideM': runningStrideM,
    'weightKg': weightKg,
    'walkingSpeedKmh': walkingSpeedKmh,
    'runningSpeedKmh': runningSpeedKmh,
    'arMode': arMode,
    'voiceCues': voiceCues,
    'themeMode': themeMode.name,
    'terrain3d': terrain3d,
    'shareLocationWithFriends': shareLocationWithFriends,
    'hideRouteEndpoints': hideRouteEndpoints,
    'saveRouteHistory': saveRouteHistory,
    'healthSync': healthSync,
    'demoMode': demoMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    double n(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    bool b(String k, bool def) => j[k] as bool? ?? def;
    return AppSettings(
      useMiles: b('useMiles', d.useMiles),
      walkingStrideM: n('walkingStrideM', d.walkingStrideM),
      runningStrideM: n('runningStrideM', d.runningStrideM),
      weightKg: n('weightKg', d.weightKg),
      walkingSpeedKmh: n('walkingSpeedKmh', d.walkingSpeedKmh),
      runningSpeedKmh: n('runningSpeedKmh', d.runningSpeedKmh),
      arMode: b('arMode', d.arMode),
      voiceCues: b('voiceCues', d.voiceCues),
      themeMode: ThemeMode.values.firstWhere((t) => t.name == j['themeMode'], orElse: () => d.themeMode),
      terrain3d: b('terrain3d', d.terrain3d),
      shareLocationWithFriends: b('shareLocationWithFriends', d.shareLocationWithFriends),
      hideRouteEndpoints: b('hideRouteEndpoints', d.hideRouteEndpoints),
      saveRouteHistory: b('saveRouteHistory', d.saveRouteHistory),
      healthSync: b('healthSync', d.healthSync),
      demoMode: b('demoMode', d.demoMode),
    );
  }
}
