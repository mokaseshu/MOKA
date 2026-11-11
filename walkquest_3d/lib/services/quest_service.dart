import 'dart:math' as math;

import '../models/lat_lng.dart';
import '../models/quest.dart';
import '../models/route_plan.dart';
import '../utils/geo_utils.dart';

/// Generates daily, story and destination quests.
class QuestService {
  QuestService._();

  /// Three daily quests, deterministic per date (+ reroll count).
  static List<Quest> dailyQuests(DateTime day, {int reroll = 0}) {
    final d = DateTime(day.year, day.month, day.day);
    final seed = d.year * 10000 + d.month * 100 + d.day + reroll * 7919;
    final rnd = math.Random(seed);
    final expires = d.add(const Duration(days: 1));
    final key = '${d.year}${d.month}${d.day}_$reroll';

    final walkKm = [1.5, 2.0, 2.5, 3.0, 4.0][rnd.nextInt(5)];
    final steps = [3000, 4000, 5000, 6000, 8000][rnd.nextInt(5)];
    final runKm = [1.0, 1.5, 2.0, 3.0][rnd.nextInt(4)];

    final pool = <Quest>[
      Quest(
        id: 'daily_walk_$key',
        title: 'Wanderlust',
        description: 'Walk ${walkKm.toStringAsFixed(1)} km today.',
        emoji: '🥾',
        type: QuestType.walkDistance,
        category: QuestCategory.daily,
        target: walkKm * 1000,
        rewardCoins: (walkKm * 30).round(),
        rewardXp: (walkKm * 60).round(),
        expiresAt: expires,
      ),
      Quest(
        id: 'daily_steps_$key',
        title: 'Step Hoard',
        description: 'Collect $steps steps.',
        emoji: '👣',
        type: QuestType.takeSteps,
        category: QuestCategory.daily,
        target: steps.toDouble(),
        rewardCoins: steps ~/ 100,
        rewardXp: steps ~/ 40,
        expiresAt: expires,
      ),
      Quest(
        id: 'daily_run_$key',
        title: 'Swift Courier',
        description: 'Run ${runKm.toStringAsFixed(1)} km in Running mode.',
        emoji: '⚡',
        type: QuestType.runDistance,
        category: QuestCategory.daily,
        target: runKm * 1000,
        rewardCoins: (runKm * 50).round(),
        rewardXp: (runKm * 100).round(),
        expiresAt: expires,
      ),
      Quest(
        id: 'daily_territory_$key',
        title: 'Border Patrol',
        description: 'Walk a loop around a block to capture a territory.',
        emoji: '🏰',
        type: QuestType.captureTerritory,
        category: QuestCategory.daily,
        target: 1,
        rewardCoins: 80,
        rewardXp: 150,
        expiresAt: expires,
      ),
    ]..shuffle(rnd);
    return pool.take(3).toList();
  }

  /// The story campaign. Landmarks spawn relative to the player on start.
  static const List<Quest> storyQuests = [
    Quest(
      id: 'story_1_dragon',
      title: "Capture the Dragon's Lair",
      description: "Walk 2 km to capture the Dragon's Lair before nightfall.",
      emoji: '🐉',
      type: QuestType.reachDestination,
      category: QuestCategory.story,
      target: 2000,
      rewardCoins: 120,
      rewardXp: 250,
      landmarkName: "Dragon's Lair",
    ),
    Quest(
      id: 'story_2_woods',
      title: 'The Whispering Woods',
      description: 'A voice calls from 1 km away. Answer it.',
      emoji: '🌲',
      type: QuestType.reachDestination,
      category: QuestCategory.story,
      target: 1000,
      rewardCoins: 60,
      rewardXp: 120,
      landmarkName: 'Whispering Woods',
    ),
    Quest(
      id: 'story_3_spire',
      title: 'Crystal Spire',
      description: 'Climb toward the Crystal Spire, 3 km out.',
      emoji: '💎',
      type: QuestType.reachDestination,
      category: QuestCategory.story,
      target: 3000,
      rewardCoins: 200,
      rewardXp: 400,
      landmarkName: 'Crystal Spire',
    ),
    Quest(
      id: 'story_4_ember',
      title: 'Siege of Ember Keep',
      description: 'Run or walk 5 km to lay siege to Ember Keep.',
      emoji: '🏯',
      type: QuestType.reachDestination,
      category: QuestCategory.story,
      target: 5000,
      rewardCoins: 350,
      rewardXp: 700,
      landmarkName: 'Ember Keep',
    ),
  ];

  /// Places a story landmark so the *walking* route is roughly [Quest.target]
  /// long: street networks add ~30% over the straight line.
  static LatLng spawnLandmark(LatLng origin, Quest quest, {math.Random? rnd}) {
    final r = rnd ?? math.Random();
    return GeoUtils.destinationPoint(origin, quest.target * 0.75, r.nextDouble() * 360);
  }

  /// A one-off quest for a map-selected destination.
  static Quest destinationQuest(RoutePlan plan) {
    final km = plan.distanceM / 1000;
    return Quest(
      id: 'dest_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Journey to ${plan.destination.name}',
      description: 'Reach ${plan.destination.name} (${km.toStringAsFixed(1)} km).',
      emoji: '📍',
      type: QuestType.reachDestination,
      category: QuestCategory.custom,
      target: plan.distanceM,
      rewardCoins: math.max(10, (km * 25).round()),
      rewardXp: math.max(20, (km * 50).round()),
      status: QuestStatus.active,
      destination: plan.destination.location,
      landmarkName: plan.destination.name,
    );
  }
}
