import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/lat_lng.dart';
import '../models/shop_item.dart';
import '../services/map_layer_controller.dart';
import '../utils/env.dart';

/// Full-bleed 3D Mapbox map (Standard style: 3D buildings, landmarks,
/// terrain, day/night lighting) with WalkQuest layers attached.
class QuestMapView extends StatefulWidget {
  const QuestMapView({
    super.key,
    required this.initialCenter,
    required this.dark,
    required this.terrain,
    required this.routeColor,
    required this.onReady,
    this.skin,
    this.onTap,
    this.showUserPuck = true,
  });

  /// Only read on first build; move the camera via [MapLayerController].
  final LatLng initialCenter;
  final bool dark;
  final bool terrain;
  final int routeColor;
  final ShopItem? skin;
  final bool showUserPuck;
  final void Function(MapLayerController controller) onReady;
  final void Function(LatLng point)? onTap;

  @override
  State<QuestMapView> createState() => _QuestMapViewState();
}

class _QuestMapViewState extends State<QuestMapView> {
  MapboxMap? _map;
  MapLayerController? _layers;

  // Frozen on first build: ViewportState compares by value, so a changing
  // center would re-apply the camera on every rebuild and fight the
  // controller's flyTo/easeTo animations.
  late final LatLng _initialCenter = widget.initialCenter;

  @override
  void didUpdateWidget(covariant QuestMapView old) {
    super.didUpdateWidget(old);
    if (old.dark != widget.dark) _layers?.setDark(widget.dark);
    if (old.terrain != widget.terrain) _layers?.setTerrain(widget.terrain);
    if (old.routeColor != widget.routeColor) _layers?.setRouteColor(widget.routeColor);
    if (old.skin?.id != widget.skin?.id && widget.skin != null) {
      _layers?.setAvatarSkin(widget.skin!);
    }
  }

  @override
  void dispose() {
    _layers?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap map) {
    _map = map;
    map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    map.compass.updateSettings(CompassSettings(position: OrnamentPosition.TOP_RIGHT, marginTop: 120));
    map.location.updateSettings(
      LocationComponentSettings(enabled: widget.showUserPuck, pulsingEnabled: true, puckBearingEnabled: true),
    );
    map.addInteraction(
      TapInteraction.onMap((ctx) {
        final c = ctx.point.coordinates;
        widget.onTap?.call(LatLng(c.lat.toDouble(), c.lng.toDouble()));
      }),
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null || _layers != null) return;
    final layers = MapLayerController(map);
    await layers.init(dark: widget.dark, terrain: widget.terrain, routeColor: widget.routeColor, skin: widget.skin);
    _layers = layers;
    if (mounted) widget.onReady(layers);
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.hasMapboxToken) return const _MissingTokenPlaceholder();
    final c = _initialCenter;
    return MapWidget(
      key: const ValueKey('quest-map'),
      styleUri: MapboxStyles.STANDARD,
      viewport: CameraViewportState(
        center: Point(coordinates: Position(c.lng, c.lat)),
        zoom: 16,
        pitch: 60,
        bearing: 0,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}

class _MissingTokenPlaceholder extends StatelessWidget {
  const _MissingTokenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B1446), Color(0xFF0E3B4A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: const Text(
        '🗺️\n\nMapbox token missing\n\nRun with\n--dart-define=MAPBOX_ACCESS_TOKEN=pk.…\n\n'
        'Everything else (quests, tracking in demo mode, stats) still works.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
      ),
    );
  }
}
