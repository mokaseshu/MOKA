/// Build-time configuration passed with `--dart-define`.
///
///   flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxx
class Env {
  Env._();

  static const mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static bool get hasMapboxToken => mapboxAccessToken.isNotEmpty;
}
