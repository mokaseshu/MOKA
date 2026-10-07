import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/activity_mode.dart';
import '../models/lat_lng.dart';
import '../models/route_plan.dart';
import '../utils/env.dart';
import '../utils/geo_utils.dart';

class MapboxApiException implements Exception {
  final String message;
  MapboxApiException(this.message);
  @override
  String toString() => message;
}

/// Thin client for the Mapbox web APIs: Directions, Geocoding v6,
/// Tilequery (elevation) and Static Images.
class MapboxApiService {
  MapboxApiService({http.Client? client, String? accessToken})
    : _client = client ?? http.Client(),
      _token = accessToken ?? Env.mapboxAccessToken;

  final http.Client _client;
  final String _token;

  static const _host = 'api.mapbox.com';

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    if (_token.isEmpty) {
      throw MapboxApiException('Missing MAPBOX_ACCESS_TOKEN. Run with --dart-define=MAPBOX_ACCESS_TOKEN=pk.…');
    }
    final uri = Uri.https(_host, path, {...query, 'access_token': _token});
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw MapboxApiException('Mapbox ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------- Directions

  /// Fetches a walking route. Running uses the same geometry (Mapbox has no
  /// running profile); speed/stride differences are applied by RouteCalculator.
  Future<RoutePlan> directions({
    required LatLng origin,
    required PlaceResult destination,
    ActivityMode mode = ActivityMode.walking,
  }) async {
    final coords = '${origin.lng},${origin.lat};${destination.location.lng},${destination.location.lat}';
    final body = await _get('/directions/v5/mapbox/${mode.mapboxProfile}/$coords', {
      'geometries': 'geojson',
      'overview': 'full',
      'steps': 'true',
      'walkway_bias': '0.5',
    });
    final routes = (body['routes'] as List?) ?? const [];
    if (routes.isEmpty) {
      throw MapboxApiException(body['message'] as String? ?? 'No walkable route found');
    }
    final r = routes.first as Map<String, dynamic>;
    final geometry = [for (final c in (r['geometry']['coordinates'] as List)) LatLng.fromLngLat(c as List)];
    final steps = <RouteStep>[];
    for (final leg in (r['legs'] as List)) {
      for (final s in (leg['steps'] as List)) {
        final m = s['maneuver'] as Map<String, dynamic>;
        steps.add(
          RouteStep(
            instruction: m['instruction'] as String? ?? '',
            distanceM: (s['distance'] as num).toDouble(),
            location: LatLng.fromLngLat(m['location'] as List),
          ),
        );
      }
    }
    return RoutePlan(
      origin: origin,
      destination: destination,
      geometry: geometry,
      distanceM: (r['distance'] as num).toDouble(),
      steps: steps,
    );
  }

  // ----------------------------------------------------------------- Geocoding

  Future<List<PlaceResult>> search(String query, {LatLng? proximity}) async {
    if (query.trim().length < 2) return const [];
    final body = await _get('/search/geocode/v6/forward', {
      'q': query,
      'limit': '8',
      'autocomplete': 'true',
      if (proximity != null) 'proximity': '${proximity.lng},${proximity.lat}',
    });
    return _parseFeatures(body);
  }

  Future<PlaceResult?> reverse(LatLng p) async {
    try {
      final body = await _get('/search/geocode/v6/reverse', {
        'longitude': '${p.lng}',
        'latitude': '${p.lat}',
        'limit': '1',
      });
      final list = _parseFeatures(body);
      if (list.isEmpty) return null;
      // Keep the exact tapped point as the destination.
      return PlaceResult(name: list.first.name, address: list.first.address, location: p);
    } catch (_) {
      return null;
    }
  }

  List<PlaceResult> _parseFeatures(Map<String, dynamic> body) => [
    for (final f in (body['features'] as List? ?? const []))
      PlaceResult(
        name: (f['properties']['name'] as String?) ?? 'Unnamed place',
        address: (f['properties']['full_address'] ?? f['properties']['place_formatted']) as String?,
        location: LatLng.fromLngLat(f['geometry']['coordinates'] as List),
      ),
  ];

  // ----------------------------------------------------------------- Elevation

  /// Samples elevation along [path] using the Tilequery API on the
  /// `mapbox-terrain-v2` contour layer (the highest contour under each point).
  /// Returns an empty list if lookups fail.
  Future<List<double>> elevationProfile(List<LatLng> path, {int samples = 24}) async {
    final pts = GeoUtils.sampleEvenly(path, math.min(samples, math.max(2, path.length)));
    try {
      final results = await Future.wait(
        pts.map((p) async {
          final body = await _get('/v4/mapbox.mapbox-terrain-v2/tilequery/${p.lng},${p.lat}.json', {
            'layers': 'contour',
            'limit': '50',
          });
          double? best;
          for (final f in (body['features'] as List? ?? const [])) {
            final ele = (f['properties']['ele'] as num?)?.toDouble();
            if (ele != null && (best == null || ele > best)) best = ele;
          }
          return best;
        }),
      );
      if (results.every((e) => e == null)) return const [];
      // Fill gaps with the previous known value.
      double last = results.firstWhere((e) => e != null)!;
      return [for (final e in results) last = e ?? last];
    } catch (_) {
      return const [];
    }
  }

  // ------------------------------------------------------------- Static images

  /// URL for a route thumbnail with the path overlaid (used in History).
  String staticRouteImageUrl(
    List<LatLng> path, {
    int width = 600,
    int height = 300,
    bool dark = false,
    String colorHex = '7c4dff',
  }) {
    if (path.length < 2) return '';
    var pts = GeoUtils.simplify(path, 8);
    // Keep the URL under Mapbox's 8,192 char limit.
    var tol = 8.0;
    while (GeoUtils.encodePolyline(pts).length > 6000 && tol < 500) {
      tol *= 2;
      pts = GeoUtils.simplify(path, tol);
    }
    final poly = Uri.encodeComponent(GeoUtils.encodePolyline(pts));
    final style = dark ? 'mapbox/dark-v11' : 'mapbox/outdoors-v12';
    return 'https://$_host/styles/v1/$style/static/'
        'path-5+$colorHex-0.9($poly)/auto/${width}x$height@2x'
        '?padding=30&access_token=$_token';
  }
}
