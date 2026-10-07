import 'dart:math' as math;

/// Level curve and economy constants.
class Leveling {
  Leveling._();

  static const coinsPer100Steps = 1;
  static const xpPer100m = 10;
  static const streakMinSteps = 1000;

  /// Total XP needed to *reach* [level] (level 1 = 0 XP).
  /// 100 · (L-1)^1.5 → L2: 100, L5: 800, L10: 2,700, L20: 8,282.
  static int xpForLevel(int level) => level <= 1 ? 0 : (100 * math.pow(level - 1, 1.5)).round();

  static int levelForXp(int xp) {
    var level = 1;
    while (xpForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  /// Progress through the current level, in [0, 1].
  static double levelProgress(int xp) {
    final l = levelForXp(xp);
    final lo = xpForLevel(l);
    final hi = xpForLevel(l + 1);
    return (xp - lo) / (hi - lo);
  }

  static String titleFor(int level) {
    if (level >= 30) return 'Legend of the Roads';
    if (level >= 20) return 'Trailblazer';
    if (level >= 12) return 'Pathfinder';
    if (level >= 6) return 'Ranger';
    if (level >= 3) return 'Scout';
    return 'Wanderer';
  }
}
