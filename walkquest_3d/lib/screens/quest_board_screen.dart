import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quest.dart';
import '../state/game_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/quest_card.dart';

/// Daily quests, the story campaign and destination quest log.
class QuestBoardScreen extends StatelessWidget {
  const QuestBoardScreen({super.key, required this.onStartQuest});

  final void Function(Quest quest) onStartQuest;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final miles = context.watch<SettingsController>().value.useMiles;
    final now = DateTime.now();
    final reset = DateTime(now.year, now.month, now.day + 1).difference(now);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quest Board'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Daily'),
              Tab(text: 'Story'),
              Tab(text: 'Journeys'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'New quests in ${reset.inHours}h ${reset.inMinutes % 60}m · progress counts from every walk',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final q in game.dailyQuests) ...[QuestCard(quest: q, useMiles: miles), const SizedBox(height: 12)],
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final q in game.storyQuests) ...[
                  QuestCard(
                    quest: q,
                    useMiles: miles,
                    locked: !game.isStoryUnlocked(q),
                    actionLabel: q.status == QuestStatus.active ? 'Resume' : 'Start',
                    onAction: () => onStartQuest(q),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
            game.customQuests.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        '📍\n\nPick any destination on the map to start a journey quest.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final q in game.customQuests.reversed) ...[
                        QuestCard(quest: q, useMiles: miles),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
