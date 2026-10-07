import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/lat_lng.dart';
import '../models/shop_item.dart';
import '../models/territory.dart';
import '../utils/geo_utils.dart';

enum CameraMode { follow, topDown, cinematic }

/// Owns every WalkQuest layer on a [MapboxMap] and the camera choreography.
///
/// Layer stack (bottom → top), all on top of the Mapbox Standard style which
/// already provides 3D buildings, extruded landmarks and dynamic lighting:
///   territories (fill-extrusion) → walked trail → route casing → route line
///   (progress gradient) → direction arrows → destination glow + 3D beacon →
///   avatar halo → 3D avatar model.
class MapLayerController {
  MapLayerController(this.map);

  final MapboxMap map;

  static const _routeSrc = 'wq-route-src';
  static const _trailSrc = 'wq-trail-src';
  static const _destSrc = 'wq-dest-src';
  static const _beaconSrc = 'wq-beacon-src';
  static const _avatarSrc = 'wq-avatar-src';
  static const _terrSrc = 'wq-territory-src';
  static const _demSrc = 'wq-dem';
  static const _avatarModelId = 'wq-avatar-model';

  static const _emptyFc = '{"type":"FeatureCollection","features":[]}';

  int _routeColor = 0xFF7C4DFF;
  double _progress = 0;
  double _avatarModelScale = 1;
  String? _avatarModelUri;
  bool _avatarModelReady = false;
  int _cameraGen = 0;
  double _orbitBearing = 0;
  Timer? _revealTimer;

  // ------------------------------------------------------------------- Setup

  Future<void> init({required bool dark, required bool terrain, required int routeColor, ShopItem? skin}) async {
    _routeColor = routeColor;
    await setDark(dark);
    if (terrain) await _enableTerrain();

    await map.addSource(GeoJsonSource(id: _terrSrc, data: _emptyFc));
    await map.addSource(GeoJsonSource(id: _trailSrc, data: _emptyFc));
    await map.addSource(GeoJsonSource(id: _routeSrc, data: _emptyFc, lineMetrics: true));
    await map.addSource(GeoJsonSource(id: _destSrc, data: _emptyFc));
    await map.addSource(GeoJsonSource(id: _beaconSrc, data: _emptyFc));
    await map.addSource(GeoJsonSource(id: _avatarSrc, data: _emptyFc));

    await map.addLayer(
      FillExtrusionLayer(
        id: 'wq-territory-ext',
        sourceId: _terrSrc,
        fillExtrusionColor: routeColor,
        fillExtrusionOpacity: 0.35,
        fillExtrusionHeight: 14,
        fillExtrusionBase: 0,
      ),
    );
    await map.addLayer(
      LineLayer(
        id: 'wq-territory-edge',
        sourceId: _terrSrc,
        lineColor: routeColor,
        lineWidth: 3,
        lineEmissiveStrength: 1,
      ),
    );
    await map.addLayer(
      LineLayer(
        id: 'wq-trail',
        sourceId: _trailSrc,
        lineColor: 0xFFFFC233,
        lineWidth: 4,
        lineOpacity: 0.9,
        lineDasharray: [1.5, 1.2],
        lineCap: LineCap.ROUND,
        lineEmissiveStrength: 1,
      ),
    );
    await map.addLayer(
      LineLayer(
        id: 'wq-route-casing',
        sourceId: _routeSrc,
        lineColor: 0xFFFFFFFF,
        lineWidth: 13,
        lineOpacity: 0.85,
        lineBlur: 1.5,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineEmissiveStrength: 1,
      ),
    );
    await map.addLayer(
      LineLayer(
        id: 'wq-route-line',
        sourceId: _routeSrc,
        lineWidth: 8,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineEmissiveStrength: 1,
        lineGradientExpression: _progressGradient(0),
      ),
    );
    // Direction chevrons rendered as text glyphs placed along the line, so no
    // sprite image is required.
    await map.addLayer(
      SymbolLayer(
        id: 'wq-route-arrows',
        sourceId: _routeSrc,
        symbolPlacement: SymbolPlacement.LINE,
        symbolSpacing: 70,
        textField: '>',
        textSize: 18,
        textColor: 0xFFFFFFFF,
        textHaloColor: routeColor,
        textHaloWidth: 1.5,
        textKeepUpright: false,
        textAllowOverlap: true,
        textRotationAlignment: TextRotationAlignment.MAP,
        textPitchAlignment: TextPitchAlignment.MAP,
        textEmissiveStrength: 1,
      ),
    );
    await map.addLayer(
      CircleLayer(
        id: 'wq-dest-glow',
        sourceId: _destSrc,
        circleRadius: 22,
        circleColor: 0xFFFF6D3A,
        circleOpacity: 0.35,
        circleBlur: 0.7,
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circleEmissiveStrength: 1,
      ),
    );
    await map.addLayer(
      FillExtrusionLayer(
        id: 'wq-dest-beacon',
        sourceId: _beaconSrc,
        fillExtrusionColor: 0xFFFF6D3A,
        fillExtrusionHeight: 45,
        fillExtrusionOpacity: 0.85,
        fillExtrusionEmissiveStrength: 1,
      ),
    );
    await map.addLayer(
      CircleLayer(
        id: 'wq-avatar-halo',
        sourceId: _avatarSrc,
        circleRadius: 14,
        circleColor: routeColor,
        circleOpacity: 0.45,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 3,
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circleEmissiveStrength: 1,
      ),
    );
    if (skin != null) await setAvatarSkin(skin);
  }

  Future<void> setDark(bool dark) async {
    try {
      await map.setStyleImportConfigProperty('basemap', 'lightPreset', dark ? 'night' : 'day');
    } catch (_) {
      // Non-Standard styles have no light presets.
    }
  }

  Future<void> setTerrain(bool enabled) async {
    if (enabled) return _enableTerrain();
    try {
      await map.removeStyleTerrain();
    } catch (_) {}
  }

  /// Re-tints every trail-colored layer (after equipping a new trail).
  Future<void> setRouteColor(int argb) async {
    _routeColor = argb;
    final css = _rgba(argb);
    await map.setStyleLayerProperty('wq-route-line', 'line-gradient', _progressGradient(_progress));
    await map.setStyleLayerProperty('wq-route-arrows', 'text-halo-color', css);
    await map.setStyleLayerProperty('wq-avatar-halo', 'circle-color', css);
    await map.setStyleLayerProperty('wq-territory-ext', 'fill-extrusion-color', css);
    await map.setStyleLayerProperty('wq-territory-edge', 'line-color', css);
  }

  Future<void> _enableTerrain() async {
    try {
      if (!await map.styleSourceExists(_demSrc)) {
        await map.addStyleSource(
          _demSrc,
          json.encode({
            'type': 'raster-dem',
            'url': 'mapbox://mapbox.mapbox-terrain-dem-v1',
            'tileSize': 514,
            'maxzoom': 14,
          }),
        );
      }
      await map.setStyleTerrain(json.encode({'source': _demSrc, 'exaggeration': 1.4}));
    } catch (_) {}
  }

  /// Loads the skin's glTF model as the 3D avatar.
  Future<void> setAvatarSkin(ShopItem skin) async {
    final uri = skin.modelUri;
    if (uri == null || uri == _avatarModelUri) return;
    try {
      if (await map.styleLayerExists('wq-avatar')) await map.removeStyleLayer('wq-avatar');
      if (_avatarModelReady) await map.removeStyleModel(_avatarModelId);
      final resolved = uri.startsWith('asset://') ? await MapboxMapsOptions.getFlutterAssetPath(uri) ?? uri : uri;
      await map.addStyleModel(_avatarModelId, resolved);
      await map.addLayer(
        ModelLayer(id: 'wq-avatar', sourceId: _avatarSrc)
          ..modelId = _avatarModelId
          ..modelScale = [skin.modelScale, skin.modelScale, skin.modelScale]
          ..modelRotation = [0, 0, 0]
          ..modelType = ModelType.COMMON_3D
          ..modelEmissiveStrength = 0.6,
      );
      _avatarModelUri = uri;
      _avatarModelScale = skin.modelScale;
      _avatarModelReady = true;
    } catch (_) {
      // Model failed to load (offline / unsupported): the halo still marks the avatar.
      _avatarModelReady = false;
    }
  }

  double get avatarModelScale => _avatarModelScale;

  // ------------------------------------------------------------------- Data

  Future<void> _set(String sourceId, Object geojson) async {
    final src = await map.getSource(sourceId);
    if (src is GeoJsonSource) await src.updateGeoJSON(json.encode(geojson));
  }

  static Map<String, dynamic> _line(List<LatLng> pts) => {
    'type': 'Feature',
    'properties': <String, dynamic>{},
    'geometry': {
      'type': 'LineString',
      'coordinates': [for (final p in pts) p.toLngLat()],
    },
  };

  static Map<String, dynamic> _point(LatLng p, [Map<String, dynamic>? props]) => {
    'type': 'Feature',
    'properties': props ?? <String, dynamic>{},
    'geometry': {'type': 'Point', 'coordinates': p.toLngLat()},
  };

  static Map<String, dynamic> _polygon(List<LatLng> ring) => {
    'type': 'Feature',
    'properties': <String, dynamic>{},
    'geometry': {
      'type': 'Polygon',
      'coordinates': [
        [
          for (final p in [...ring, ring.first]) p.toLngLat(),
        ],
      ],
    },
  };

  List<Object> _rgba(int argb, [double? alpha]) => [
    'rgba',
    (argb >> 16) & 0xFF,
    (argb >> 8) & 0xFF,
    argb & 0xFF,
    alpha ?? ((argb >> 24) & 0xFF) / 255,
  ];

  /// Walked part of the route turns gold; the rest glows in the trail color.
  List<Object> _progressGradient(double p) => [
    'step',
    ['line-progress'],
    _rgba(0xFFFFC233),
    math.max(0.0001, math.min(1, p)),
    _rgba(_routeColor),
  ];

  /// Draws the route with an animated "growing" reveal.
  Future<void> setRoute(List<LatLng> route, {bool animate = true}) async {
    _revealTimer?.cancel();
    _progress = 0;
    await map.setStyleLayerProperty('wq-route-line', 'line-gradient', _progressGradient(0));
    if (!animate || route.length < 2) {
      await _set(_routeSrc, _line(route));
      return;
    }
    // line-trim-offset hides [start, end] of the line (by line-progress).
    await map.setStyleLayerProperty('wq-route-line', 'line-trim-offset', [0.0, 1.0]);
    await map.setStyleLayerProperty('wq-route-casing', 'line-trim-offset', [0.0, 1.0]);
    await _set(_routeSrc, _line(route));
    const frames = 45;
    var i = 0;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 33), (t) {
      i++;
      final v = math.min(1.0, i / frames);
      final eased = 1 - math.pow(1 - v, 3).toDouble();
      final trim = eased >= 1 ? [0.0, 0.0] : [eased, 1.0];
      map.setStyleLayerProperty('wq-route-line', 'line-trim-offset', trim);
      map.setStyleLayerProperty('wq-route-casing', 'line-trim-offset', trim);
      if (v >= 1) t.cancel();
    });
  }

  Future<void> clearRoute() async {
    _revealTimer?.cancel();
    await _set(_routeSrc, jsonDecode(_emptyFc) as Object);
    await _set(_destSrc, jsonDecode(_emptyFc) as Object);
    await _set(_beaconSrc, jsonDecode(_emptyFc) as Object);
  }

  /// Colors the traveled fraction of the route.
  Future<void> setProgress(double fraction) async {
    if ((fraction - _progress).abs() < 0.002) return;
    _progress = fraction;
    await map.setStyleLayerProperty('wq-route-line', 'line-gradient', _progressGradient(fraction));
  }

  /// Destination marker + a 3D extruded hexagonal beacon.
  Future<void> setDestination(LatLng p) async {
    await _set(_destSrc, _point(p));
    final hex = [for (var a = 0; a < 360; a += 60) GeoUtils.destinationPoint(p, 7, a.toDouble())];
    await _set(_beaconSrc, _polygon(hex));
  }

  Future<void> setTrail(List<LatLng> path) async {
    if (path.length < 2) return;
    // Keep updates cheap on long sessions.
    final pts = path.length > 800 ? GeoUtils.simplify(path, 3) : path;
    await _set(_trailSrc, _line(pts));
  }

  Future<void> setTerritories(List<Territory> list) async {
    await _set(_terrSrc, {
      'type': 'FeatureCollection',
      'features': [for (final t in list) _polygon(t.polygon)],
    });
  }

  Future<void> setAvatar(LatLng p, double bearing) async {
    await _set(_avatarSrc, _point(p));
    if (_avatarModelReady) {
      await map.setStyleLayerProperty('wq-avatar', 'model-rotation', [0.0, 0.0, bearing]);
    }
  }

  Future<void> showUserPuck(bool show) => map.location.updateSettings(
    LocationComponentSettings(enabled: show, pulsingEnabled: show, puckBearingEnabled: show),
  );

  // ----------------------------------------------------------------- Camera

  static Point _pt(LatLng p) => Point(coordinates: Position(p.lng, p.lat));

  void cancelCamera() => _cameraGen++;

  Future<void> flyTo(LatLng p, {double zoom = 16.5, double pitch = 60, double? bearing, int ms = 1500}) {
    _cameraGen++;
    return map.flyTo(
      CameraOptions(center: _pt(p), zoom: zoom, pitch: pitch, bearing: bearing),
      MapAnimationOptions(duration: ms),
    );
  }

  Future<void> fitRoute(List<LatLng> route, {double bottomInset = 320}) async {
    if (route.length < 2) return;
    _cameraGen++;
    final cam = await map.cameraForCoordinates(
      [for (final p in route) _pt(p)],
      MbxEdgeInsets(top: 140, left: 50, bottom: bottomInset, right: 50),
      GeoUtils.bearing(route.first, route.last),
      55,
    );
    await map.flyTo(cam, MapAnimationOptions(duration: 1600));
  }

  /// Cinematic fly-over along the route, then back to an overview.
  Future<void> flyOver(List<LatLng> route, {double bottomInset = 320}) async {
    if (route.length < 2) return;
    final gen = ++_cameraGen;
    final cum = GeoUtils.cumulative(route);
    const stops = 7;
    for (var i = 0; i <= stops; i++) {
      if (gen != _cameraGen) return;
      final along = cum.last * i / stops;
      final p = GeoUtils.pointAlong(route, along, cum);
      final ahead = GeoUtils.pointAlong(route, math.min(cum.last, along + 150), cum);
      final b = i == stops ? GeoUtils.bearing(route.first, route.last) : GeoUtils.bearing(p, ahead);
      await map.flyTo(
        CameraOptions(center: _pt(p), zoom: 17.2, pitch: 72, bearing: b),
        MapAnimationOptions(duration: 1700),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1650));
    }
    if (gen != _cameraGen) return;
    await fitRoute(route, bottomInset: bottomInset);
  }

  /// Per-update camera for the active quest.
  Future<void> followAvatar(LatLng p, double bearing, CameraMode mode) {
    switch (mode) {
      case CameraMode.follow:
        return map.easeTo(
          CameraOptions(center: _pt(p), zoom: 17.6, pitch: 65, bearing: bearing),
          MapAnimationOptions(duration: 900),
        );
      case CameraMode.topDown:
        return map.easeTo(
          CameraOptions(center: _pt(p), zoom: 16.2, pitch: 0, bearing: 0),
          MapAnimationOptions(duration: 900),
        );
      case CameraMode.cinematic:
        _orbitBearing = (_orbitBearing + 6) % 360;
        return map.easeTo(
          CameraOptions(center: _pt(p), zoom: 18.2, pitch: 75, bearing: bearing + 40 + _orbitBearing),
          MapAnimationOptions(duration: 1000),
        );
    }
  }

  void dispose() {
    _revealTimer?.cancel();
    _cameraGen++;
  }
}
