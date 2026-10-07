import 'package:flutter_test/flutter_test.dart';
import 'package:walkquest_3d/models/lat_lng.dart';
import 'package:walkquest_3d/utils/geo_utils.dart';

void main() {
  const a = LatLng(48.8584, 2.2945); // Eiffel Tower
  const b = LatLng(48.8606, 2.3376); // Louvre

  test('haversine distance', () {
    expect(GeoUtils.distanceM(a, b), closeTo(3170, 30));
  });

  test('destinationPoint round-trips with distance & bearing', () {
    final p = GeoUtils.destinationPoint(a, 1000, 45);
    expect(GeoUtils.distanceM(a, p), closeTo(1000, 0.5));
    expect(GeoUtils.bearing(a, p), closeTo(45, 0.1));
  });

  test('pointAlong & snapToPath agree', () {
    final path = [a, GeoUtils.destinationPoint(a, 500, 90), GeoUtils.destinationPoint(a, 500, 90)];
    final mid = GeoUtils.pointAlong(path, 250);
    final snap = GeoUtils.snapToPath(GeoUtils.destinationPoint(mid, 20, 0), path);
    expect(snap.alongM, closeTo(250, 1));
    expect(snap.offRouteM, closeTo(20, 0.5));
  });

  test('snapToPath respects minAlongM on out-and-back routes', () {
    final far = GeoUtils.destinationPoint(a, 400, 90);
    final path = [a, far, GeoUtils.destinationPoint(a, 1, 180)]; // out and back
    final probe = GeoUtils.destinationPoint(a, 100, 90);
    expect(GeoUtils.snapToPath(probe, path).alongM, closeTo(100, 1));
    expect(GeoUtils.snapToPath(probe, path, minAlongM: 450).alongM, closeTo(700, 2));
  });

  test('polygon area of a 100 m square', () {
    final p1 = a;
    final p2 = GeoUtils.destinationPoint(p1, 100, 0);
    final p3 = GeoUtils.destinationPoint(p2, 100, 90);
    final p4 = GeoUtils.destinationPoint(p1, 100, 90);
    expect(GeoUtils.polygonAreaM2([p1, p2, p3, p4]), closeTo(10000, 50));
    expect(GeoUtils.pointInPolygon(GeoUtils.centroid([p1, p2, p3, p4]), [p1, p2, p3, p4]), isTrue);
  });

  test('encodePolyline matches the Google reference example', () {
    final pts = [const LatLng(38.5, -120.2), const LatLng(40.7, -120.95), const LatLng(43.252, -126.453)];
    expect(GeoUtils.encodePolyline(pts), '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
  });

  test('simplify keeps endpoints and drops collinear points', () {
    final line = [for (var i = 0; i <= 10; i++) GeoUtils.destinationPoint(a, i * 10.0, 90)];
    final s = GeoUtils.simplify(line, 1);
    expect(s.length, 2);
    expect(s.first, line.first);
    expect(s.last, line.last);
  });

  test('trimEnds removes privacy zone', () {
    final line = [for (var i = 0; i <= 10; i++) GeoUtils.destinationPoint(a, i * 100.0, 90)];
    final t = GeoUtils.trimEnds(line, 100);
    expect(GeoUtils.pathLengthM(t), closeTo(800, 1));
    expect(GeoUtils.trimEnds(line.sublist(0, 2), 100), isEmpty);
  });
}
