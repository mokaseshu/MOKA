import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'progress_ring.dart';

/// Quest row with a progress ring, rewards and an optional action.
class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.useMiles,
    this.locked = false,
    this.actionLabel,
    this.onAction,
  });

  final Quest quest;
  final bool useMiles;
  final bool locked;
  final String? actionLabel;
  final VoidCallback? onAction;

  String _progressText() {
    switch (quest.type) {
      case QuestType.walkDistance:
      case QuestType.runDistance:
      case QuestType.reachDestination:
        return '${Fmt.distance(quest.progress, miles: useMiles)} / ${Fmt.distance(quest.target, miles: useMiles)}';
      case QuestType.takeSteps:
        return '${Fmt.count(quest.progress)} / ${Fmt.count(quest.target)} steps';
      case QuestType.captureTerritory:
        return '${quest.progress.round()} / ${quest.target.round()} captured';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final done = quest.isDone;
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ProgressRing(
                value: done ? 1 : quest.fraction,
                size: 58,
                colors: done ? const [AppColors.xp, AppColors.teal] : const [AppColors.teal, AppColors.violet],
                child: Text(locked ? '🔒' : (done ? '✅' : quest.emoji), style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(quest.description, style: t.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip('🪙 ${quest.rewardCoins}', AppColors.gold),
                        _chip('✨ ${quest.rewardXp} XP', AppColors.xp),
                        if (!done) Text(_progressText(), style: t.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && !locked && !done) ...[
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  );
}
