import 'lat_lng.dart';

/// A map zone claimed by walking a closed loop around it.
class Territory {
  final String id;
  final String name;
  final List<LatLng> polygon;
  final double areaM2;
  final DateTime capturedAt;
  final String ownerUid;

  const Territory({
    required this.id,
    required this.name,
    required this.polygon,
    required this.areaM2,
    required this.capturedAt,
    required this.ownerUid,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'polygon': [for (final p in polygon) ...p.toLngLat()],
    'areaM2': areaM2,
    'capturedAt': capturedAt.toIso8601String(),
    'ownerUid': ownerUid,
  };

  factory Territory.fromJson(Map<String, dynamic> j) {
    final flat = (j['polygon'] as List).cast<num>();
    return Territory(
      id: j['id'] as String,
      name: j['name'] as String,
      polygon: [for (var i = 0; i + 1 < flat.length; i += 2) LatLng(flat[i + 1].toDouble(), flat[i].toDouble())],
      areaM2: (j['areaM2'] as num).toDouble(),
      capturedAt: DateTime.parse(j['capturedAt'] as String),
      ownerUid: j['ownerUid'] as String,
    );
  }
}
