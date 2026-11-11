/// Plain geographic coordinate used across the app.
///
/// Kept independent of the Mapbox/turf `Position` and Firestore `GeoPoint`
/// types so models and pure logic stay testable without plugins.
class LatLng {
  final double lat;
  final double lng;

  const LatLng(this.lat, this.lng);

  /// GeoJSON order: [lng, lat].
  List<double> toLngLat() => [lng, lat];

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory LatLng.fromJson(Map<String, dynamic> json) =>
      LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble());

  factory LatLng.fromLngLat(List<dynamic> c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());

  @override
  bool operator ==(Object other) => other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})';
}
