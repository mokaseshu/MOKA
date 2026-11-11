import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_mode.dart';
import '../models/lat_lng.dart';
import '../models/quest.dart';
import '../models/route_plan.dart';
import '../services/location_service.dart';
import '../services/map_layer_controller.dart';
import '../services/mapbox_api_service.dart';
import '../state/game_controller.dart';
import '../state/settings_controller.dart';
import '../state/tracking_controller.dart';
import '../utils/app_theme.dart';
import '../widgets/quest_map_view.dart';
import '../widgets/route_preview_panel.dart';
import '../widgets/stat_tile.dart';
import '../widgets/xp_bar.dart';
import 'active_quest_screen.dart';
import 'destination_search_screen.dart';

/// Main screen: live 3D map, destination search/tap, route preview.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  static const _fallbackCenter = LatLng(37.7793, -122.4193); // San Francisco

  final _location = LocationService();
  MapLayerController? _layers;
  LatLng? _me;
  RoutePlan? _plan;
  Quest? _pendingQuest;
  ActivityMode _mode = ActivityMode.walking;
  bool _routing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final LocationAccess access;
    try {
      access = await _location.ensurePermission();
    } catch (e) {
      if (mounted) setState(() => _error = 'Location unavailable on this device.');
      return;
    }
    if (access != LocationAccess.granted) {
      if (mounted) {
        setState(
          () => _error = access == LocationAccess.serviceDisabled
              ? 'Location services are off.'
              : 'Location permission needed for live position.',
        );
      }
      return;
    }
    final p = await _location.currentPosition();
    if (p == null || !mounted) return;
    setState(() {
      _me = p;
      _error = null;
    });
    if (_plan == null) await _layers?.flyTo(p, zoom: 16.5, pitch: 60);
  }

  LatLng get _origin => _me ?? _fallbackCenter;

  void _onMapReady(MapLayerController layers) {
    _layers = layers;
    layers.setTerritories(context.read<GameController>().territories);
    if (_me != null) layers.flyTo(_me!, ms: 2200);
  }

  Future<void> _onMapTap(LatLng p) async {
    if (_routing || context.read<TrackingController>().isActive) return;
    final api = context.read<MapboxApiService>();
    final place = await api.reverse(p) ?? PlaceResult(name: 'Dropped pin', location: p);
    _pendingQuest = null;
    await _planRoute(place);
  }

  Future<void> _openSearch() async {
    final place = await Navigator.of(
      context,
    ).push<PlaceResult>(MaterialPageRoute(builder: (_) => DestinationSearchScreen(proximity: _origin)));
    if (place != null) {
      _pendingQuest = null;
      await _planRoute(place);
    }
  }

  /// Called from the Quest Board for story quests.
  Future<void> planStoryQuest(Quest quest) async {
    final game = context.read<GameController>();
    final started = await game.beginStoryQuest(quest, _origin);
    _pendingQuest = started;
    await _planRoute(
      PlaceResult(name: started.landmarkName ?? started.title, address: started.title, location: started.destination!),
    );
  }

  Future<void> _planRoute(PlaceResult place) async {
    final api = context.read<MapboxApiService>();
    setState(() {
      _routing = true;
      _error = null;
    });
    try {
      final plan = await api.directions(origin: _origin, destination: place);
      if (!mounted) return;
      setState(() => _plan = plan);
      await _layers?.setRoute(plan.geometry);
      await _layers?.setDestination(place.location);
      await _layers?.fitRoute(plan.geometry, bottomInset: _panelInset);
      // Elevation is a nice-to-have; fill it in when it arrives.
      api.elevationProfile(plan.geometry).then((profile) {
        if (mounted && _plan == plan && profile.isNotEmpty) {
          setState(() => _plan = plan.withElevation(profile));
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  double get _panelInset => MediaQuery.of(context).size.height * 0.45;

  Future<void> _clearRoute() async {
    _layers?.cancelCamera();
    setState(() {
      _plan = null;
      _pendingQuest = null;
    });
    await _layers?.clearRoute();
    if (_me != null) await _layers?.flyTo(_me!);
  }

  Future<void> _startQuest() async {
    final plan = _plan;
    if (plan == null) return;
    final game = context.read<GameController>();
    final quest = _pendingQuest ?? await game.addDestinationQuest(plan);
    await _launch(plan: plan, quest: quest);
  }

  Future<void> _startFreeRoam() => _launch();

  Future<void> _launch({RoutePlan? plan, Quest? quest}) async {
    final game = context.read<GameController>();
    final settings = context.read<SettingsController>().value;
    final tracking = context.read<TrackingController>();
    _layers?.cancelCamera();
    final err = await tracking.start(
      mode: _mode,
      settings: settings,
      ownerUid: game.me.uid,
      plan: plan,
      quest: quest,
      coinMultiplier: game.powerUpCharges('pu_double_coins') > 0 ? 2 : 1,
      freeRoamOrigin: _origin,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActiveQuestScreen()));
    if (!mounted) return;
    // Back from the quest: reset preview and show any new territory.
    await _clearRoute();
    await _layers?.setTerritories(game.territories);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    final game = context.watch<GameController>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        Positioned.fill(
          child: QuestMapView(
            initialCenter: _origin,
            dark: dark,
            terrain: settings.terrain3d,
            routeColor: game.trailColor,
            skin: game.skin,
            onReady: _onMapReady,
            onTap: _onMapTap,
          ),
        ),
        // HUD + search
        Positioned(
          top: top + 10,
          left: 14,
          right: 14,
          child: Column(
            children: [
              GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Text(game.me.avatar.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(child: XpBar(xp: game.me.xp, compact: true)),
                    const SizedBox(width: 10),
                    CoinPill(coins: game.me.coins),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _openSearch,
                child: GlassPanel(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.violet),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Where to, adventurer?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_routing)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Material(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(_error!, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Side buttons
        Positioned(
          right: 14,
          bottom: _plan == null ? 110 : _panelInset + 10,
          child: Column(
            children: [
              _RoundButton(icon: Icons.my_location_rounded, tooltip: 'My location', onTap: _locate),
              if (_plan == null) ...[
                const SizedBox(height: 10),
                _RoundButton(
                  icon: Icons.flag_circle_rounded,
                  tooltip: 'Free roam: walk a loop to capture territory',
                  color: AppColors.sunset,
                  onTap: _startFreeRoam,
                ),
              ],
            ],
          ),
        ),
        // Bottom: preview or hint
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, a) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: _plan == null
                ? GlassPanel(
                    key: const ValueKey('hint'),
                    radius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Text('👆', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            settings.demoMode
                                ? 'Demo mode on — tap the map to pick a quest destination.'
                                : 'Tap the map or search to choose your quest destination.',
                          ),
                        ),
                      ],
                    ),
                  )
                : RoutePreviewPanel(
                    key: const ValueKey('preview'),
                    plan: _plan!,
                    settings: settings,
                    mode: _mode,
                    onModeChanged: (m) => setState(() => _mode = m),
                    onStart: _startQuest,
                    onFlyOver: () => _layers?.flyOver(_plan!.geometry, bottomInset: _panelInset),
                    onClose: _clearRoute,
                  ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.tooltip, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: Material(
      color: color ?? Theme.of(context).cardTheme.color,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Icon(icon, color: color == null ? AppColors.violet : Colors.white),
        ),
      ),
    ),
  );
}
