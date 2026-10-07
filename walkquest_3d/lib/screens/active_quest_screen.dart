import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_mode.dart';
import '../models/lat_lng.dart';
import '../services/map_layer_controller.dart';
import '../state/game_controller.dart';
import '../state/settings_controller.dart';
import '../state/tracking_controller.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/game_button.dart';
import '../widgets/progress_ring.dart';
import '../widgets/quest_map_view.dart';
import '../widgets/reward_popup.dart';
import '../widgets/stat_tile.dart';
import 'session_detail_screen.dart';

/// Live tracking: 3D avatar moving along the route, progress & stats.
class ActiveQuestScreen extends StatefulWidget {
  const ActiveQuestScreen({super.key});

  @override
  State<ActiveQuestScreen> createState() => _ActiveQuestScreenState();
}

class _ActiveQuestScreenState extends State<ActiveQuestScreen> {
  MapLayerController? _layers;
  CameraMode _camera = CameraMode.follow;
  LatLng? _lastAvatar;
  int _lastPathLen = 0;
  int _lastTerritories = 0;
  bool _finishing = false;
  late final TrackingController _tracking = context.read<TrackingController>();

  @override
  void initState() {
    super.initState();
    _tracking.addListener(_onTick);
  }

  @override
  void dispose() {
    _tracking.removeListener(_onTick);
    super.dispose();
  }

  void _onReady(MapLayerController layers) {
    _layers = layers;
    final plan = _tracking.plan;
    if (plan != null) {
      layers.setRoute(plan.geometry, animate: false);
      layers.setDestination(plan.destination.location);
    }
    layers.setTerritories(context.read<GameController>().territories);
    final start = _tracking.snapshot.avatarPosition ?? plan?.origin;
    if (start != null) {
      layers.setAvatar(start, _tracking.snapshot.avatarBearing);
      layers.followAvatar(start, _tracking.snapshot.avatarBearing, _camera);
    }
  }

  /// Pushes engine state to the map; only does map work when something moved.
  void _onTick() {
    if (!_tracking.isActive) return;
    final s = _tracking.snapshot;
    final layers = _layers;
    if (layers != null && s.avatarPosition != null && s.avatarPosition != _lastAvatar) {
      _lastAvatar = s.avatarPosition;
      layers.setAvatar(s.avatarPosition!, s.avatarBearing);
      layers.setProgress(s.routeFraction);
      layers.followAvatar(s.avatarPosition!, s.avatarBearing, _camera);
    }
    if (layers != null && _tracking.path.length != _lastPathLen) {
      _lastPathLen = _tracking.path.length;
      layers.setTrail(_tracking.path);
    }
    if (layers != null && _tracking.captured.length != _lastTerritories) {
      _lastTerritories = _tracking.captured.length;
      layers.setTerritories([...context.read<GameController>().territories, ..._tracking.captured]);
    }
    if (s.arrived && !_finishing) _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final game = context.read<GameController>();
    final settings = context.read<SettingsController>().value;
    final captured = List.of(_tracking.captured);
    final session = await _tracking.finish();
    if (!mounted) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quest ended — too short to record.')));
      Navigator.of(context).pop();
      return;
    }
    final rewards = await game.recordSession(
      session,
      captured: captured,
      saveRoute: settings.saveRouteHistory,
      writeToHealth: settings.healthSync,
    );
    if (!mounted) return;
    await showRewardPopup(
      context,
      rewards,
      title: session.reachedDestination ? 'Quest Complete!' : 'Adventure Logged!',
    );
    if (!mounted) return;
    final saved = game.sessions.first;
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: saved)));
  }

  Future<void> _confirmEnd() async {
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End quest?'),
        content: const Text('Your progress so far will be saved and rewarded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End quest')),
        ],
      ),
    );
    if (end == true) await _finish();
  }

  void _showArInfo() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '🥽 AR Trail View\n\nAR mode is enabled in Settings. The camera-overlay view '
          '(ARCore / ARKit via the ar_flutter_plugin or a Unity ARFoundation module) is '
          'on the roadmap — see README › Roadmap. The 3D map view keeps tracking meanwhile.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingController>();
    final settings = context.watch<SettingsController>().value;
    final game = context.read<GameController>();
    final s = tracking.snapshot;
    final miles = settings.useMiles;
    final hasRoute = tracking.plan != null;
    final top = MediaQuery.of(context).padding.top;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: QuestMapView(
                initialCenter: s.avatarPosition ?? tracking.plan?.origin ?? const LatLng(37.7793, -122.4193),
                dark: dark,
                terrain: settings.terrain3d,
                routeColor: game.trailColor,
                skin: game.skin,
                showUserPuck: false,
                onReady: _onReady,
              ),
            ),
            // Top: quest title + progress
            Positioned(
              top: top + 10,
              left: 14,
              right: 14,
              child: GlassPanel(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(tracking.quest?.emoji ?? '🏁', style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tracking.quest?.title ?? 'Free Roam — capture territory',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        if (tracking.simulated) const Chip(label: Text('DEMO'), visualDensity: VisualDensity.compact),
                        if (settings.arMode)
                          IconButton(
                            onPressed: _showArInfo,
                            icon: const Icon(Icons.view_in_ar_rounded),
                            tooltip: 'AR view',
                          ),
                      ],
                    ),
                    if (hasRoute) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: s.routeFraction),
                          duration: const Duration(milliseconds: 600),
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 12,
                            color: AppColors.gold,
                            backgroundColor: AppColors.violet.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${(s.routeFraction * 100).round()}% complete',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          if (s.offRoute)
                            const Text(
                              '⚠️ Off route',
                              style: TextStyle(color: AppColors.sunset, fontWeight: FontWeight.w800),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Event banner
            if (tracking.banner != null)
              Positioned(
                top: top + (hasRoute ? 130 : 84),
                left: 30,
                right: 30,
                child: _Banner(text: tracking.banner!),
              ),
            // Camera modes
            Positioned(
              right: 14,
              top: top + (hasRoute ? 190 : 140),
              child: GlassPanel(
                padding: const EdgeInsets.all(4),
                radius: 18,
                child: Column(
                  children: [
                    for (final m in CameraMode.values)
                      IconButton(
                        isSelected: _camera == m,
                        tooltip: m.name,
                        color: _camera == m ? AppColors.violet : null,
                        onPressed: () {
                          setState(() => _camera = m);
                          final p = tracking.snapshot.avatarPosition;
                          if (p != null) _layers?.followAvatar(p, tracking.snapshot.avatarBearing, m);
                        },
                        icon: Icon(switch (m) {
                          CameraMode.follow => Icons.navigation_rounded,
                          CameraMode.topDown => Icons.map_rounded,
                          CameraMode.cinematic => Icons.videocam_rounded,
                        }),
                      ),
                  ],
                ),
              ),
            ),
            // Bottom stats
            Positioned(
              left: 12,
              right: 12,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: GlassPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ProgressRing(
                          value: hasRoute ? s.routeFraction : (s.steps % 1000) / 1000,
                          size: 92,
                          stroke: 9,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Fmt.count(s.steps),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                              Text(s.stepsFromSensor ? 'steps' : 'steps*', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Fmt.clock(tracking.elapsed),
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                '${tracking.mode.emoji} ${tracking.mode.label} · '
                                '${s.currentSpeedKmh.toStringAsFixed(1)} km/h',
                              ),
                              if (tracking.isPaused) const Text('⏸ Paused', style: TextStyle(color: AppColors.sunset)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StatRow(
                      children: hasRoute
                          ? [
                              StatTile(
                                emoji: '📏',
                                value: Fmt.distance(s.remainingM, miles: miles),
                                label: 'to go',
                              ),
                              StatTile(emoji: '🕒', value: Fmt.duration(s.remainingTime), label: 'remaining'),
                              StatTile(emoji: '👣', value: Fmt.approx(s.remainingSteps), label: 'steps left'),
                              StatTile(emoji: '🔥', value: s.kcal.round().toString(), label: 'kcal'),
                              StatTile(emoji: '🪙', value: '+${s.coins}', label: 'coins'),
                            ]
                          : [
                              StatTile(
                                emoji: '📏',
                                value: Fmt.distance(s.distanceM, miles: miles),
                                label: 'walked',
                              ),
                              StatTile(emoji: '🔥', value: s.kcal.round().toString(), label: 'kcal'),
                              StatTile(emoji: '🪙', value: '+${s.coins}', label: 'coins'),
                              StatTile(emoji: '🏰', value: '${tracking.captured.length}', label: 'captured'),
                            ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: tracking.isPaused ? tracking.resume : tracking.pause,
                            icon: Icon(tracking.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                            label: Text(tracking.isPaused ? 'Resume' : 'Pause'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GameButton(
                            label: 'Finish',
                            icon: Icons.flag_rounded,
                            height: 54,
                            gradient: AppColors.gradientReward,
                            busy: _finishing,
                            onPressed: _confirmEnd,
                          ),
                        ),
                      ],
                    ),
                    if (!s.stepsFromSensor && tracking.mode == ActivityMode.walking && !tracking.simulated)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '* estimated from distance until the pedometer reports',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(text),
    tween: Tween(begin: 0.6, end: 1),
    duration: const Duration(milliseconds: 500),
    curve: Curves.elasticOut,
    builder: (_, v, child) => Transform.scale(scale: v, child: child),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.5), blurRadius: 18)],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
  );
}
