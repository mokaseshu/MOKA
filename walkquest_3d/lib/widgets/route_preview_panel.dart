import 'package:flutter/material.dart';

import '../models/activity_mode.dart';
import '../models/app_settings.dart';
import '../models/route_plan.dart';
import '../services/route_calculator.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'elevation_chart.dart';
import 'game_button.dart';
import 'stat_tile.dart';

/// Bottom panel showing route stats for both modes, with fly-over and start.
class RoutePreviewPanel extends StatelessWidget {
  const RoutePreviewPanel({
    super.key,
    required this.plan,
    required this.settings,
    required this.mode,
    required this.onModeChanged,
    required this.onStart,
    required this.onFlyOver,
    required this.onClose,
  });

  final RoutePlan plan;
  final AppSettings settings;
  final ActivityMode mode;
  final ValueChanged<ActivityMode> onModeChanged;
  final VoidCallback onStart;
  final VoidCallback onFlyOver;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gain = plan.elevationGainM;
    RouteEstimate est(ActivityMode m) =>
        RouteCalculator.estimate(distanceM: plan.distanceM, mode: m, settings: settings, elevationGainM: gain);
    final walk = est(ActivityMode.walking);
    final run = est(ActivityMode.running);
    final sel = mode == ActivityMode.walking ? walk : run;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.destination.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (plan.destination.address != null)
                      Text(plan.destination.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 6),
          // "🕒 14 min walking / 7 min running"
          Text(
            '🕒 ${Fmt.duration(walk.duration)} walking / ${Fmt.duration(run.duration)} running',
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeCard(estimate: walk, selected: mode == ActivityMode.walking, onTap: onModeChanged),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeCard(estimate: run, selected: mode == ActivityMode.running, onTap: onModeChanged),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StatRow(
            children: [
              StatTile(
                emoji: '📏',
                value: Fmt.distance(plan.distanceM, miles: settings.useMiles),
                label: 'distance',
              ),
              StatTile(emoji: '👣', value: Fmt.approx(sel.steps), label: 'steps'),
              StatTile(emoji: '🔥', value: '${Fmt.approx(sel.kcal)} kcal', label: 'calories'),
              StatTile(emoji: '⛰️', value: plan.elevationProfile.isEmpty ? '--' : '+${gain.round()} m', label: 'climb'),
            ],
          ),
          if (plan.elevationProfile.length > 1) ...[
            const SizedBox(height: 10),
            ElevationChart(profile: plan.elevationProfile, height: 48),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onFlyOver,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.flight_takeoff_rounded),
                label: const Text('Fly-over'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GameButton(
                  label: 'Start Quest',
                  icon: mode == ActivityMode.walking ? Icons.directions_walk_rounded : Icons.directions_run_rounded,
                  gradient: AppColors.gradientGo,
                  onPressed: onStart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.estimate, required this.selected, required this.onTap});

  final RouteEstimate estimate;
  final bool selected;
  final ValueChanged<ActivityMode> onTap;

  @override
  Widget build(BuildContext context) {
    final c = estimate.mode == ActivityMode.walking ? AppColors.teal : AppColors.sunset;
    return GestureDetector(
      onTap: () => onTap(estimate.mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? c : c.withValues(alpha: 0.25), width: 2),
        ),
        child: Row(
          children: [
            Text(estimate.mode.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(estimate.mode.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    Fmt.duration(estimate.duration),
                    style: TextStyle(color: c, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
