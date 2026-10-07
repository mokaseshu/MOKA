/// Walking or running. Mapbox Directions has no "running" profile, so both
/// modes route over the `walking` profile and differ in speed, stride and MET.
enum ActivityMode {
  walking,
  running;

  String get label => this == walking ? 'Walking' : 'Running';
  String get verb => this == walking ? 'walking' : 'running';
  String get emoji => this == walking ? '🚶' : '🏃';

  /// Mapbox Directions profile used to fetch the geometry.
  String get mapboxProfile => 'walking';

  static ActivityMode fromName(String? name) =>
      ActivityMode.values.firstWhere((m) => m.name == name, orElse: () => ActivityMode.walking);
}
