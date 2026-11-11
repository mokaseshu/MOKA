import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/walk_session.dart';
import '../services/mapbox_api_service.dart';
import '../state/settings_controller.dart';
import '../utils/formatters.dart';
import '../widgets/stat_tile.dart';

/// One walk/run: route map, stats, share.
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});

  final WalkSession session;

  String _shareText(bool miles) =>
      '${session.mode.emoji} I just completed a WalkQuest '
      '${session.destinationName == null ? '${session.mode.verb} adventure' : 'journey to ${session.destinationName}'}: '
      '${Fmt.distance(session.distanceM, miles: miles)} in ${Fmt.duration(session.activeDuration)}, '
      '${Fmt.count(session.steps)} steps, ${session.kcal.round()} kcal! 🗺️ #WalkQuest3D';

  @override
  Widget build(BuildContext context) {
    final miles = context.watch<SettingsController>().value.useMiles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = context.read<MapboxApiService>().staticRouteImageUrl(session.path, dark: dark);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(session.destinationName ?? '${session.mode.label} adventure'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText(miles))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 2,
              child: url.isEmpty
                  ? Container(
                      color: Theme.of(context).cardTheme.color,
                      alignment: Alignment.center,
                      child: const Text('Route not saved (privacy settings)'),
                    )
                  : Image.network(url, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(Fmt.dateTime(session.startedAt), style: t.bodySmall),
          if (session.reachedDestination)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('🏁 Destination reached', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  StatRow(
                    children: [
                      StatTile(
                        emoji: '📏',
                        value: Fmt.distance(session.distanceM, miles: miles),
                        label: 'distance',
                      ),
                      StatTile(emoji: '🕒', value: Fmt.clock(session.activeDuration), label: 'moving time'),
                      StatTile(emoji: '👣', value: Fmt.count(session.steps), label: 'steps'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  StatRow(
                    children: [
                      StatTile(emoji: '🔥', value: '${session.kcal.round()}', label: 'kcal'),
                      StatTile(
                        emoji: '⚡',
                        value: Fmt.pace(session.paceMinPerKm, miles: miles),
                        label: 'avg pace',
                      ),
                      StatTile(emoji: '🪙', value: '+${session.coinsEarned}', label: 'coins'),
                      StatTile(emoji: '✨', value: '+${session.xpEarned}', label: 'XP'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
