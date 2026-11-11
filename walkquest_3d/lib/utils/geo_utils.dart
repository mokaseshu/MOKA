import 'dart:math' as math;

import '../models/lat_lng.dart';

/// Result of projecting a point onto a polyline.
class RouteSnap {
  /// Closest point on the polyline.
  final LatLng point;

  /// Distance along the polyline from its start to [point], meters.
  final double alongM;

  /// Distance from the input point to [point], meters.
  final double offRouteM;

  /// Index of the segment start vertex.
  final int segmentIndex;

  const RouteSnap(this.point, this.alongM, this.offRouteM, this.segmentIndex);
}

/// Spherical/planar helpers. Accurate to well under 1% at walking scale.
class GeoUtils {
  GeoUtils._();

  static const earthRadiusM = 6371008.8;

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;

  static double distanceM(LatLng a, LatLng b) {
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Initial bearing a→b in degrees [0, 360).
  static double bearing(LatLng a, LatLng b) {
    final y = math.sin(_rad(b.lng - a.lng)) * math.cos(_rad(b.lat));
    final x =
        math.cos(_rad(a.lat)) * math.sin(_rad(b.lat)) -
        math.sin(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.cos(_rad(b.lng - a.lng));
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  /// Point at [distanceM] from [origin] along [bearingDeg].
  static LatLng destinationPoint(LatLng origin, double distanceM, double bearingDeg) {
    final d = distanceM / earthRadiusM;
    final b = _rad(bearingDeg);
    final lat1 = _rad(origin.lat);
    final lng1 = _rad(origin.lng);
    final lat2 = math.asin(math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(b));
    final lng2 =
        lng1 + math.atan2(math.sin(b) * math.sin(d) * math.cos(lat1), math.cos(d) - math.sin(lat1) * math.sin(lat2));
    return LatLng(_deg(lat2), (_deg(lng2) + 540) % 360 - 180);
  }

  static double pathLengthM(List<LatLng> path) {
    double total = 0;
    for (var i = 1; i < path.length; i++) {
      total += distanceM(path[i - 1], path[i]);
    }
    return total;
  }

  /// Cumulative distance at each vertex (first = 0).
  static List<double> cumulative(List<LatLng> path) {
    final out = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      out[i] = out[i - 1] + distanceM(path[i - 1], path[i]);
    }
    return out;
  }

  static LatLng lerp(LatLng a, LatLng b, double t) => LatLng(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);

  /// Point located [alongM] meters along [path]; clamps to the ends.
  static LatLng pointAlong(List<LatLng> path, double alongM, [List<double>? cumulativeM]) {
    if (path.isEmpty) throw ArgumentError('empty path');
    if (path.length == 1 || alongM <= 0) return path.first;
    final cum = cumulativeM ?? cumulative(path);
    if (alongM >= cum.last) return path.last;
    var lo = 0, hi = cum.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (cum[mid] <= alongM) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final seg = cum[hi] - cum[lo];
    return lerp(path[lo], path[hi], seg == 0 ? 0 : (alongM - cum[lo]) / seg);
  }

  /// Heading of the path at [alongM].
  static double bearingAlong(List<LatLng> path, double alongM, [List<double>? cumulativeM]) {
    if (path.length < 2) return 0;
    final a = pointAlong(path, math.max(0, alongM - 5), cumulativeM);
    final b = pointAlong(path, alongM + 5, cumulativeM);
    return bearing(a, b);
  }

  /// Projects [p] onto [path] using a local equirectangular frame.
  ///
  /// [minAlongM] lets a tracker ignore earlier parts of the route so the
  /// snap cannot jump backwards across switchbacks or out-and-back legs.
  static RouteSnap snapToPath(LatLng p, List<LatLng> path, {List<double>? cumulativeM, double minAlongM = 0}) {
    final cum = cumulativeM ?? cumulative(path);
    if (path.length == 1) {
      return RouteSnap(path.first, 0, distanceM(p, path.first), 0);
    }
    final cosLat = math.cos(_rad(p.lat));
    double bestD = double.infinity;
    RouteSnap? best;
    for (var i = 0; i < path.length - 1; i++) {
      if (cum[i + 1] < minAlongM) continue;
      final a = path[i], b = path[i + 1];
      // Local planar coords in meters relative to p.
      final ax = _rad(a.lng - p.lng) * cosLat * earthRadiusM;
      final ay = _rad(a.lat - p.lat) * earthRadiusM;
      final bx = _rad(b.lng - p.lng) * cosLat * earthRadiusM;
      final by = _rad(b.lat - p.lat) * earthRadiusM;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      final d = math.sqrt(cx * cx + cy * cy);
      if (d < bestD) {
        bestD = d;
        final along = cum[i] + (cum[i + 1] - cum[i]) * t;
        best = RouteSnap(lerp(a, b, t), along, d, i);
      }
    }
    return best ?? RouteSnap(path.last, cum.last, distanceM(p, path.last), path.length - 2);
  }

  /// Area of a simple polygon in m² (local planar approximation).
  static double polygonAreaM2(List<LatLng> ring) {
    if (ring.length < 3) return 0;
    final lat0 = ring.map((p) => p.lat).reduce((a, b) => a + b) / ring.length;
    final k = math.cos(_rad(lat0));
    double sum = 0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      final ax = _rad(a.lng) * k * earthRadiusM, ay = _rad(a.lat) * earthRadiusM;
      final bx = _rad(b.lng) * k * earthRadiusM, by = _rad(b.lat) * earthRadiusM;
      sum += ax * by - bx * ay;
    }
    return sum.abs() / 2;
  }

  static bool pointInPolygon(LatLng p, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.lat > p.lat) != (b.lat > p.lat) && p.lng < (b.lng - a.lng) * (p.lat - a.lat) / (b.lat - a.lat) + a.lng) {
        inside = !inside;
      }
    }
    return inside;
  }

  static LatLng centroid(List<LatLng> pts) => LatLng(
    pts.map((p) => p.lat).reduce((a, b) => a + b) / pts.length,
    pts.map((p) => p.lng).reduce((a, b) => a + b) / pts.length,
  );

  /// Douglas–Peucker simplification with tolerance in meters.
  static List<LatLng> simplify(List<LatLng> pts, double toleranceM) {
    if (pts.length < 3) return List.of(pts);
    final keep = List<bool>.filled(pts.length, false);
    keep[0] = keep[pts.length - 1] = true;
    final stack = <List<int>>[
      [0, pts.length - 1],
    ];
    while (stack.isNotEmpty) {
      final r = stack.removeLast();
      final s = r[0], e = r[1];
      double maxD = 0;
      var idx = -1;
      for (var i = s + 1; i < e; i++) {
        final d = snapToPath(pts[i], [pts[s], pts[e]]).offRouteM;
        if (d > maxD) {
          maxD = d;
          idx = i;
        }
      }
      if (idx != -1 && maxD > toleranceM) {
        keep[idx] = true;
        stack
          ..add([s, idx])
          ..add([idx, e]);
      }
    }
    return [
      for (var i = 0; i < pts.length; i++)
        if (keep[i]) pts[i],
    ];
  }

  /// Evenly spaced samples along a path (inclusive of both ends).
  static List<LatLng> sampleEvenly(List<LatLng> path, int count) {
    if (path.isEmpty) return const [];
    if (count <= 1) return [path.first];
    final cum = cumulative(path);
    return [for (var i = 0; i < count; i++) pointAlong(path, cum.last * i / (count - 1), cum)];
  }

  /// Google encoded polyline (precision 5), used by the Static Images API.
  static String encodePolyline(List<LatLng> pts) {
    final sb = StringBuffer();
    var prevLat = 0, prevLng = 0;
    void enc(int v) {
      var s = v < 0 ? ~(v << 1) : (v << 1);
      while (s >= 0x20) {
        sb.writeCharCode((0x20 | (s & 0x1f)) + 63);
        s >>= 5;
      }
      sb.writeCharCode(s + 63);
    }

    for (final p in pts) {
      final lat = (p.lat * 1e5).round();
      final lng = (p.lng * 1e5).round();
      enc(lat - prevLat);
      enc(lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return sb.toString();
  }

  /// Trims [meters] off both ends of a path (privacy zone).
  static List<LatLng> trimEnds(List<LatLng> path, double meters) {
    if (path.length < 2) return path;
    final cum = cumulative(path);
    if (cum.last <= meters * 2) return const [];
    final out = <LatLng>[pointAlong(path, meters, cum)];
    for (var i = 0; i < path.length; i++) {
      if (cum[i] > meters && cum[i] < cum.last - meters) out.add(path[i]);
    }
    out.add(pointAlong(path, cum.last - meters, cum));
    return out;
  }
}
