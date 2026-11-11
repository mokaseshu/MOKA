import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_mode.dart';
import '../models/walk_session.dart';
import '../services/mapbox_api_service.dart';
import '../state/game_controller.dart';
import '../state/settings_controller.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/stat_tile.dart';
import 'session_detail_screen.dart';

enum _Range { week, month }

/// Weekly/monthly charts, personal records and history.
class StatsHistoryScreen extends StatefulWidget {
  const StatsHistoryScreen({super.key});

  @override
  State<StatsHistoryScreen> createState() => _StatsHistoryScreenState();
}

class _StatsHistoryScreenState extends State<StatsHistoryScreen> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final miles = context.watch<SettingsController>().value.useMiles;
    final p = game.me;
    final sessions = game.sessions;
    final t = Theme.of(context).textTheme;

    final days = _range == _Range.week ? 7 : 30;
    final today = DateTime.now();
    final bars = [
      for (var i = days - 1; i >= 0; i--)
        (day: today.subtract(Duration(days: i)), steps: p.stepsOn(today.subtract(Duration(days: i)))),
    ];
    final total = bars.fold<int>(0, (s, b) => s + b.steps);
    final maxY = math.max(10000, bars.map((b) => b.steps).fold<int>(0, math.max)) * 1.15;

    WalkSession? best(double Function(WalkSession) by, [bool Function(WalkSession)? where]) {
      final list = sessions.where(where ?? (_) => true).toList();
      if (list.isEmpty) return null;
      return list.reduce((a, b) => by(a) >= by(b) ? a : b);
    }

    final longest = best((s) => s.distanceM);
    final mostSteps = best((s) => s.steps.toDouble());
    final fastestRun = best((s) => s.avgSpeedKmh, (s) => s.mode == ActivityMode.running && s.distanceM > 500);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats & History')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StatRow(
                children: [
                  StatTile(emoji: '👣', value: Fmt.count(p.lifetimeSteps), label: 'lifetime steps'),
                  StatTile(
                    emoji: '📏',
                    value: Fmt.distance(p.lifetimeDistanceM, miles: miles),
                    label: 'distance',
                  ),
                  StatTile(emoji: '🔥', value: Fmt.count(p.lifetimeKcal), label: 'kcal'),
                  StatTile(emoji: '⚡', value: '${p.streakDays(today)}d', label: 'streak'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${Fmt.count(total)} steps',
                          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      SegmentedButton<_Range>(
                        segments: const [
                          ButtonSegment(value: _Range.week, label: Text('Week')),
                          ButtonSegment(value: _Range.month, label: Text('Month')),
                        ],
                        selected: {_range},
                        onSelectionChanged: (s) => setState(() => _range = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: 10000,
                              color: AppColors.gold.withValues(alpha: 0.6),
                              strokeWidth: 1.5,
                              dashArray: [6, 4],
                            ),
                          ],
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                                if (_range == _Range.month && i % 5 != 4) return const SizedBox.shrink();
                                final d = bars[i].day;
                                return Text(
                                  _range == _Range.week ? Fmt.weekday(d) : '${d.day}',
                                  style: const TextStyle(fontSize: 11),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < bars.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: bars[i].steps.toDouble(),
                                  width: _range == _Range.week ? 22 : 7,
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    colors: bars[i].steps >= 10000
                                        ? const [AppColors.gold, AppColors.sunset]
                                        : const [AppColors.teal, AppColors.violet],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Personal records', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              _Record('🛣️', 'Longest', longest == null ? '--' : Fmt.distance(longest.distanceM, miles: miles)),
              const SizedBox(width: 10),
              _Record('👣', 'Most steps', mostSteps == null ? '--' : Fmt.count(mostSteps.steps)),
              const SizedBox(width: 10),
              _Record('⚡', 'Fastest run', fastestRun == null ? '--' : Fmt.pace(fastestRun.paceMinPerKm, miles: miles)),
            ],
          ),
          const SizedBox(height: 20),
          Text('History', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No adventures yet. Your first quest awaits! 🗺️', textAlign: TextAlign.center),
            ),
          for (final s in sessions) _SessionTile(session: s, miles: miles),
        ],
      ),
    );
  }
}

class _Record extends StatelessWidget {
  const _Record(this.emoji, this.label, this.value);
  final String emoji, label, value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: StatTile(emoji: emoji, value: value, label: label),
      ),
    ),
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.miles});
  final WalkSession session;
  final bool miles;

  @override
  Widget build(BuildContext context) {
    final api = context.read<MapboxApiService>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = api.staticRouteImageUrl(session.path, width: 160, height: 160, dark: dark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session))),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: url.isEmpty
                    ? Center(child: Text(session.mode.emoji, style: const TextStyle(fontSize: 32)))
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Center(child: Text(session.mode.emoji, style: const TextStyle(fontSize: 32))),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.destinationName ?? '${session.mode.label} adventure',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(Fmt.dateTime(session.startedAt), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '${Fmt.distance(session.distanceM, miles: miles)} · ${Fmt.duration(session.activeDuration)} · '
                      '${Fmt.count(session.steps)} steps',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('+${session.coinsEarned} 🪙', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
