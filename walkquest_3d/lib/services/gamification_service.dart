import 'dart:math' as math;

import '../models/achievement.dart';
import '../models/activity_mode.dart';
import '../models/quest.dart';
import '../models/user_profile.dart';
import '../models/walk_session.dart';
import '../utils/leveling.dart';
import 'catalog.dart';

/// Everything a finished session earned, for the reward pop-up.
class RewardSummary {
  final int stepCoins;
  final int questCoins;
  final int achievementCoins;
  final int xp;
  final int levelBefore;
  final int levelAfter;
  final List<Achievement> newAchievements;
  final List<Quest> completedQuests;
  final int territoriesCaptured;
  final bool doubleCoinsUsed;

  const RewardSummary({
    this.stepCoins = 0,
    this.questCoins = 0,
    this.achievementCoins = 0,
    this.xp = 0,
    this.levelBefore = 1,
    this.levelAfter = 1,
    this.newAchievements = const [],
    this.completedQuests = const [],
    this.territoriesCaptured = 0,
    this.doubleCoinsUsed = false,
  });

  int get totalCoins => stepCoins + questCoins + achievementCoins;
  bool get leveledUp => levelAfter > levelBefore;
}

class SessionOutcome {
  final UserProfile profile;
  final WalkSession session;
  final List<Quest> quests;
  final RewardSummary rewards;

  const SessionOutcome(this.profile, this.session, this.quests, this.rewards);
}

/// Pure reward rules: coins, XP, levels, quest progress, achievements.
class GamificationService {
  GamificationService._();

  static const doubleCoinsId = 'pu_double_coins';
  static const xpBoostId = 'pu_xp_boost';

  /// 1 coin per 100 steps (×2 with Double Coins).
  static int coinsForSteps(int steps, {int multiplier = 1}) => (steps ~/ 100) * Leveling.coinsPer100Steps * multiplier;

  /// XP for distance, speed and reaching a destination.
  ///  * 10 XP per 100 m
  ///  * speed bonus: +25% for a running pace (≥ 8 km/h), +10% for a brisk
  ///    walk (≥ 5.5 km/h)
  ///  * +50 XP for reaching the selected destination
  static int xpForSession(WalkSession s) {
    final base = (s.distanceM / 100).floor() * Leveling.xpPer100m;
    final v = s.avgSpeedKmh;
    final speedBonus = v >= 8 ? 0.25 : (v >= 5.5 ? 0.10 : 0.0);
    return (base * (1 + speedBonus)).round() + (s.reachedDestination ? 50 : 0);
  }

  /// ISO-8601 week id, e.g. `2026-W41`.
  static String isoWeekId(DateTime d) {
    final date = DateTime.utc(d.year, d.month, d.day);
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime.utc(thursday.year, 1, 1);
    final week = (thursday.difference(firstThursday).inDays ~/ 7) + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// Applies a finished session to the profile and quests.
  static SessionOutcome applySession({
    required UserProfile profile,
    required WalkSession session,
    required List<WalkSession> history,
    required List<Quest> quests,
    int territoriesCapturedThisSession = 0,
    int territoriesTotal = 0,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final levelBefore = profile.level;

    // Power-ups (one charge each per session).
    final powerUps = Map<String, int>.from(profile.powerUps);
    final doubleCoins = (powerUps[doubleCoinsId] ?? 0) > 0;
    final xpBoost = (powerUps[xpBoostId] ?? 0) > 0;
    if (doubleCoins) powerUps[doubleCoinsId] = powerUps[doubleCoinsId]! - 1;
    if (xpBoost) powerUps[xpBoostId] = powerUps[xpBoostId]! - 1;
    powerUps.removeWhere((_, v) => v <= 0);

    final stepCoins = coinsForSteps(session.steps, multiplier: doubleCoins ? 2 : 1);
    var xp = (xpForSession(session) * (xpBoost ? 1.5 : 1)).round();

    // Quests.
    var questCoins = 0;
    final completed = <Quest>[];
    final updatedQuests = <Quest>[];
    for (final q in quests) {
      if (q.isDone || q.isExpired) {
        updatedQuests.add(q);
        continue;
      }
      final add = switch (q.type) {
        QuestType.walkDistance => session.distanceM,
        QuestType.runDistance => session.mode == ActivityMode.running ? session.distanceM : 0.0,
        QuestType.takeSteps => session.steps.toDouble(),
        QuestType.captureTerritory => territoriesCapturedThisSession.toDouble(),
        QuestType.reachDestination => session.questId == q.id && session.reachedDestination ? q.target : 0.0,
      };
      var nq = q.copyWith(progress: math.min(q.target, q.progress + add));
      if (nq.progress >= nq.target) {
        nq = nq.copyWith(status: QuestStatus.claimed);
        questCoins += q.rewardCoins;
        xp += q.rewardXp;
        completed.add(nq);
      } else if (add > 0 && q.status == QuestStatus.available) {
        nq = nq.copyWith(status: QuestStatus.active);
      }
      updatedQuests.add(nq);
    }

    // Daily / weekly step counters.
    final dayKey = UserProfile.dayKey(session.startedAt);
    final daily = Map<String, int>.from(profile.dailySteps);
    daily[dayKey] = (daily[dayKey] ?? 0) + session.steps;
    if (daily.length > 60) {
      final keys = daily.keys.toList()..sort();
      for (final k in keys.take(daily.length - 60)) {
        daily.remove(k);
      }
    }
    final week = isoWeekId(t);
    final weekly = (profile.weekId == week ? profile.weeklySteps : 0) + session.steps;

    var updated = profile.copyWith(
      coins: profile.coins + stepCoins + questCoins,
      xp: profile.xp + xp,
      lifetimeSteps: profile.lifetimeSteps + session.steps,
      lifetimeDistanceM: profile.lifetimeDistanceM + session.distanceM,
      lifetimeKcal: profile.lifetimeKcal + session.kcal,
      questsCompleted: profile.questsCompleted + completed.length,
      dailySteps: daily,
      weekId: week,
      weeklySteps: weekly,
      powerUps: powerUps,
    );

    // Achievements, evaluated on the updated state.
    final ctx = AchievementContext(
      profile: updated,
      latestSession: session,
      history: [...history, session],
      territoriesCaptured: territoriesTotal,
    );
    final unlocked = <Achievement>[];
    for (final a in Catalog.achievements) {
      if (updated.unlockedAchievements.contains(a.id)) continue;
      if (a.progress(ctx) >= 1) unlocked.add(a);
    }
    final achievementCoins = unlocked.fold<int>(0, (s, a) => s + a.rewardCoins);
    updated = updated.copyWith(
      coins: updated.coins + achievementCoins,
      unlockedAchievements: {...updated.unlockedAchievements, ...unlocked.map((a) => a.id)},
    );

    return SessionOutcome(
      updated,
      session.copyWith(coinsEarned: stepCoins + questCoins + achievementCoins, xpEarned: xp),
      updatedQuests,
      RewardSummary(
        stepCoins: stepCoins,
        questCoins: questCoins,
        achievementCoins: achievementCoins,
        xp: xp,
        levelBefore: levelBefore,
        levelAfter: updated.level,
        newAchievements: unlocked,
        completedQuests: completed,
        territoriesCaptured: territoriesCapturedThisSession,
        doubleCoinsUsed: doubleCoins,
      ),
    );
  }
}
