import 'dart:math' as math;

import '../models/lat_lng.dart';
import '../models/territory.dart';
import '../utils/geo_utils.dart';

/// Detects closed loops in a walked path; the enclosed area becomes territory.
class TerritoryService {
  TerritoryService._();

  /// The loop must close within this distance of an earlier point.
  static const closeRadiusM = 25.0;
  static const minLoopLengthM = 400.0;
  static const minAreaM2 = 2000.0;

  static const _names = [
    "Dragon's Lair",
    'Moonwell Grove',
    'Ember Keep',
    'Crystal Quarter',
    'Whispering Commons',
    'Thunder Plaza',
    'Golden Meadow',
    'Shadowfen',
    'Starfall Square',
    'Ironbark Hollow',
    'Sapphire Bay',
    'Wyvern Ridge',
  ];

  /// Checks whether the newest point of [path] closes a loop that starts at or
  /// after [searchFrom]. Returns the loop's start index, or null.
  static int? findLoopStart(List<LatLng> path, {int searchFrom = 0}) {
    if (path.length < 4) return null;
    final last = path.last;
    final cum = GeoUtils.cumulative(path);
    // Walk back until we're far enough along the path to form a real loop.
    for (var i = path.length - 2; i >= searchFrom; i--) {
      if (cum.last - cum[i] < minLoopLengthM) continue;
      if (GeoUtils.distanceM(path[i], last) <= closeRadiusM) {
        final ring = path.sublist(i, path.length);
        if (GeoUtils.polygonAreaM2(ring) >= minAreaM2) return i;
      }
    }
    return null;
  }

  static Territory build({required List<LatLng> ring, required String ownerUid, DateTime? now}) {
    final simplified = GeoUtils.simplify(ring, 5);
    final c = GeoUtils.centroid(simplified);
    final seed = (c.lat * 1e4).round() ^ (c.lng * 1e4).round();
    final name = _names[seed.abs() % _names.length];
    final t = now ?? DateTime.now();
    return Territory(
      id: 'ter_${t.millisecondsSinceEpoch}_${math.Random().nextInt(9999)}',
      name: name,
      polygon: simplified,
      areaM2: GeoUtils.polygonAreaM2(simplified),
      capturedAt: t,
      ownerUid: ownerUid,
    );
  }
}
