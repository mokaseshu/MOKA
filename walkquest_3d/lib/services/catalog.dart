import 'dart:math' as math;

import '../models/achievement.dart';
import '../models/activity_mode.dart';
import '../models/shop_item.dart';
import '../models/user_profile.dart';

/// Static game content: shop items and achievement rules.
class Catalog {
  Catalog._();

  // Khronos sample models, mirrored by jsDelivr at a pinned commit.
  // Drop your own .glb into assets/models/ and use `asset://assets/models/x.glb`.
  static const _gltf =
      'https://cdn.jsdelivr.net/gh/KhronosGroup/glTF-Sample-Models@d7a3cc8e51d7c573771ae77a57f16b0662a905c6/2.0';

  static const skins = <ShopItem>[
    ShopItem(
      id: 'skin_explorer',
      name: 'Explorer',
      description: 'The classic adventurer. Free for every hero.',
      emoji: '🧭',
      type: ShopItemType.skin,
      price: 0,
      color: 0xFF7C4DFF,
      modelUri: '$_gltf/CesiumMan/glTF-Binary/CesiumMan.glb',
      modelScale: 3,
    ),
    ShopItem(
      id: 'skin_fox',
      name: 'Fox Ranger',
      description: 'Swift and cunning. +style on every trail.',
      emoji: '🦊',
      type: ShopItemType.skin,
      price: 400,
      color: 0xFFFF6D3A,
      modelUri: '$_gltf/Fox/glTF-Binary/Fox.glb',
      modelScale: 0.03,
    ),
    ShopItem(
      id: 'skin_duck',
      name: 'Duck Knight',
      description: 'Quack first, ask questions later.',
      emoji: '🦆',
      type: ShopItemType.skin,
      price: 250,
      color: 0xFFFFC233,
      modelUri: '$_gltf/Duck/glTF-Binary/Duck.glb',
      modelScale: 2.5,
    ),
    ShopItem(
      id: 'skin_mech',
      name: 'Stride Mech',
      description: 'A walking machine for walking machines.',
      emoji: '🤖',
      type: ShopItemType.skin,
      price: 900,
      color: 0xFF3DA9FF,
      modelUri: '$_gltf/BrainStem/glTF-Binary/BrainStem.glb',
      modelScale: 2.5,
    ),
  ];

  static const trails = <ShopItem>[
    ShopItem(
      id: 'trail_violet',
      name: 'Arcane Violet',
      description: 'Default route glow.',
      emoji: '💜',
      type: ShopItemType.trail,
      price: 0,
      color: 0xFF7C4DFF,
    ),
    ShopItem(
      id: 'trail_teal',
      name: 'Aurora Teal',
      description: 'Cool northern lights.',
      emoji: '🩵',
      type: ShopItemType.trail,
      price: 120,
      color: 0xFF00E5C3,
    ),
    ShopItem(
      id: 'trail_sunset',
      name: 'Dragonfire',
      description: 'Leave a blazing path.',
      emoji: '🔥',
      type: ShopItemType.trail,
      price: 200,
      color: 0xFFFF6D3A,
    ),
    ShopItem(
      id: 'trail_gold',
      name: 'Royal Gold',
      description: 'For true champions.',
      emoji: '👑',
      type: ShopItemType.trail,
      price: 500,
      color: 0xFFFFC233,
    ),
    ShopItem(
      id: 'trail_pink',
      name: 'Neon Bloom',
      description: 'Light up the night.',
      emoji: '🌸',
      type: ShopItemType.trail,
      price: 300,
      color: 0xFFFF4FA3,
    ),
  ];

  static const powerUps = <ShopItem>[
    ShopItem(
      id: 'pu_double_coins',
      name: 'Double Coins',
      description: '2× coins on your next quest.',
      emoji: '🪙',
      type: ShopItemType.powerUp,
      price: 150,
      color: 0xFFFFC233,
    ),
    ShopItem(
      id: 'pu_xp_boost',
      name: 'XP Boost',
      description: '+50% XP on your next quest.',
      emoji: '⚡',
      type: ShopItemType.powerUp,
      price: 120,
      color: 0xFF8BE04E,
    ),
    ShopItem(
      id: 'pu_reroll',
      name: 'Quest Reroll',
      description: 'Instantly swap today\'s daily quests.',
      emoji: '🎲',
      type: ShopItemType.powerUp,
      price: 60,
      color: 0xFF3DA9FF,
    ),
  ];

  static List<ShopItem> get all => [...skins, ...trails, ...powerUps];

  static ShopItem item(String id) => all.firstWhere((i) => i.id == id, orElse: () => skins.first);

  static ShopItem skin(String id) => skins.firstWhere((i) => i.id == id, orElse: () => skins.first);

  static ShopItem trail(String id) => trails.firstWhere((i) => i.id == id, orElse: () => trails.first);

  // -------------------------------------------------------------- Achievements

  static double _ratio(num v, num target) => math.min(1, v / target).toDouble();

  static final achievements = <Achievement>[
    Achievement(
      id: 'first_steps',
      title: 'First Steps',
      description: 'Complete your first walk or run.',
      emoji: '👣',
      rewardCoins: 25,
      progress: (c) => c.history.isEmpty ? 0 : 1,
    ),
    Achievement(
      id: 'first_quest',
      title: 'Questbound',
      description: 'Complete your first quest.',
      emoji: '📜',
      rewardCoins: 50,
      progress: (c) => _ratio(c.profile.questsCompleted, 1),
    ),
    Achievement(
      id: 'day_10k',
      title: '10K Day',
      description: 'Walk 10,000 steps in a single day.',
      emoji: '🔟',
      rewardCoins: 150,
      progress: (c) => _ratio(c.profile.dailySteps.values.fold<int>(0, math.max), 10000),
    ),
    Achievement(
      id: 'run_5k',
      title: '5K Runner',
      description: 'Run 5 km in one session.',
      emoji: '🏃',
      rewardCoins: 200,
      progress: (c) => _ratio(
        c.history.where((s) => s.mode == ActivityMode.running).fold<double>(0, (m, s) => math.max(m, s.distanceM)),
        5000,
      ),
    ),
    Achievement(
      id: 'streak_7',
      title: 'Unstoppable',
      description: 'Keep a 7-day walking streak.',
      emoji: '🔥',
      rewardCoins: 250,
      progress: (c) => _ratio(c.profile.streakDays(DateTime.now()), 7),
    ),
    Achievement(
      id: 'marathon',
      title: 'Marathoner',
      description: 'Cover 42.2 km in total.',
      emoji: '🏅',
      rewardCoins: 300,
      progress: (c) => _ratio(c.profile.lifetimeDistanceM, 42195),
    ),
    Achievement(
      id: 'century',
      title: 'Century Club',
      description: 'Cover 100 km in total.',
      emoji: '💯',
      rewardCoins: 600,
      progress: (c) => _ratio(c.profile.lifetimeDistanceM, 100000),
    ),
    Achievement(
      id: 'first_territory',
      title: 'Landlord',
      description: 'Capture your first territory.',
      emoji: '🏰',
      rewardCoins: 100,
      progress: (c) => _ratio(c.territoriesCaptured, 1),
    ),
    Achievement(
      id: 'territory_10',
      title: 'Warlord',
      description: 'Hold 10 territories.',
      emoji: '🗺️',
      rewardCoins: 500,
      progress: (c) => _ratio(c.territoriesCaptured, 10),
    ),
    Achievement(
      id: 'level_10',
      title: 'Seasoned Ranger',
      description: 'Reach level 10.',
      emoji: '⭐',
      rewardCoins: 300,
      progress: (c) => _ratio(c.profile.level, 10),
    ),
    Achievement(
      id: 'steps_100k',
      title: 'Hundred Thousand',
      description: 'Take 100,000 lifetime steps.',
      emoji: '🦶',
      rewardCoins: 400,
      progress: (c) => _ratio(c.profile.lifetimeSteps, 100000),
    ),
  ];

  static int unlockedCount(UserProfile p) => achievements.where((a) => p.unlockedAchievements.contains(a.id)).length;
}
