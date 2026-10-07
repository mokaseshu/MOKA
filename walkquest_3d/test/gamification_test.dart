import 'package:flutter_test/flutter_test.dart';
import 'package:walkquest_3d/models/activity_mode.dart';
import 'package:walkquest_3d/models/quest.dart';
import 'package:walkquest_3d/models/user_profile.dart';
import 'package:walkquest_3d/models/walk_session.dart';
import 'package:walkquest_3d/services/gamification_service.dart';
import 'package:walkquest_3d/services/quest_service.dart';
import 'package:walkquest_3d/services/step_counter_service.dart';
import 'package:walkquest_3d/utils/leveling.dart';

void main() {
  final now = DateTime(2026, 10, 7, 18);

  WalkSession session({
    double distanceM = 2000,
    int steps = 2857,
    ActivityMode mode = ActivityMode.walking,
    Duration time = const Duration(minutes: 24),
    String? questId,
    bool reached = false,
  }) => WalkSession(
    id: 's1',
    mode: mode,
    startedAt: now.subtract(time),
    endedAt: now,
    activeDuration: time,
    distanceM: distanceM,
    steps: steps,
    kcal: 100,
    questId: questId,
    reachedDestination: reached,
  );

  const profile = UserProfile(uid: 'u1', displayName: 'Tester', friendCode: 'ABC123');

  test('level curve', () {
    expect(Leveling.levelForXp(0), 1);
    expect(Leveling.levelForXp(99), 1);
    expect(Leveling.levelForXp(100), 2);
    expect(Leveling.levelForXp(2700), 10);
    expect(Leveling.levelProgress(50), closeTo(0.5, 1e-9));
  });

  test('coins per 100 steps', () {
    expect(GamificationService.coinsForSteps(99), 0);
    expect(GamificationService.coinsForSteps(1650), 16);
    expect(GamificationService.coinsForSteps(1650, multiplier: 2), 32);
  });

  test('xp: distance + speed bonus + destination bonus', () {
    expect(GamificationService.xpForSession(session()), 200); // 5 km/h → no bonus
    final run = session(mode: ActivityMode.running, time: const Duration(minutes: 12)); // 10 km/h
    expect(GamificationService.xpForSession(run), 250);
    expect(GamificationService.xpForSession(session(reached: true)), 250);
  });

  test('applySession updates profile, quests and achievements', () {
    final quests = [
      const Quest(
        id: 'q_steps',
        title: 'Steps',
        description: '',
        emoji: '👣',
        type: QuestType.takeSteps,
        category: QuestCategory.daily,
        target: 2000,
        rewardCoins: 20,
        rewardXp: 50,
      ),
      const Quest(
        id: 'q_run',
        title: 'Run',
        description: '',
        emoji: '⚡',
        type: QuestType.runDistance,
        category: QuestCategory.daily,
        target: 1000,
        rewardCoins: 50,
        rewardXp: 100,
      ),
    ];
    final out = GamificationService.applySession(
      profile: profile,
      session: session(),
      history: const [],
      quests: quests,
      now: now,
    );
    final r = out.rewards;
    expect(r.stepCoins, 28);
    expect(r.completedQuests.map((q) => q.id), ['q_steps']);
    expect(out.quests.firstWhere((q) => q.id == 'q_run').progress, 0); // walking doesn't count
    expect(r.newAchievements.map((a) => a.id), containsAll(['first_steps', 'first_quest']));
    expect(out.profile.coins, r.totalCoins);
    expect(out.profile.xp, 200 + 50);
    expect(out.profile.weeklySteps, 2857);
    expect(out.profile.weekId, '2026-W41');
    expect(out.profile.stepsOn(now), 2857);
    expect(out.session.coinsEarned, r.totalCoins);
  });

  test('power-ups are consumed once', () {
    final p = profile.copyWith(powerUps: {'pu_double_coins': 1, 'pu_xp_boost': 1});
    final out = GamificationService.applySession(
      profile: p,
      session: session(),
      history: const [],
      quests: const [],
      now: now,
    );
    expect(out.rewards.doubleCoinsUsed, isTrue);
    expect(out.rewards.stepCoins, 56);
    expect(out.rewards.xp, 300);
    expect(out.profile.powerUps, isEmpty);
  });

  test('destination quest completes only when reached', () {
    const q = Quest(
      id: 'dest',
      title: 'Go',
      description: '',
      emoji: '📍',
      type: QuestType.reachDestination,
      category: QuestCategory.custom,
      target: 1500,
      rewardCoins: 40,
      rewardXp: 80,
      status: QuestStatus.active,
    );
    final miss = GamificationService.applySession(
      profile: profile,
      session: session(questId: 'dest'),
      history: const [],
      quests: [q],
      now: now,
    );
    expect(miss.rewards.completedQuests, isEmpty);
    final hit = GamificationService.applySession(
      profile: profile,
      session: session(questId: 'dest', reached: true),
      history: const [],
      quests: [q],
      now: now,
    );
    expect(hit.rewards.questCoins, 40);
  });

  test('streak counts consecutive 1k-step days', () {
    final p = profile.copyWith(
      dailySteps: {'2026-10-07': 3000, '2026-10-06': 1200, '2026-10-05': 5000, '2026-10-03': 9000},
    );
    expect(p.streakDays(now), 3);
    // Today not walked yet: streak still alive from yesterday.
    expect(p.streakDays(DateTime(2026, 10, 8, 9)), 3);
  });

  test('iso week ids', () {
    expect(GamificationService.isoWeekId(DateTime(2026, 1, 1)), '2026-W01');
    expect(GamificationService.isoWeekId(DateTime(2027, 1, 1)), '2026-W53');
  });

  test('daily quests are deterministic per day and reroll changes them', () {
    final a = QuestService.dailyQuests(now);
    final b = QuestService.dailyQuests(now);
    expect(a.map((q) => q.id), b.map((q) => q.id));
    expect(a, hasLength(3));
    final c = QuestService.dailyQuests(now, reroll: 1);
    expect(c.map((q) => q.id).toSet().intersection(a.map((q) => q.id).toSet()), isEmpty);
  });

  test('step counter accumulates deltas, skips pauses and resets', () {
    final s = StepCounterService();
    s.onRawCount(10000); // baseline
    s.onRawCount(10050);
    expect(s.currentSteps, 50);
    s.pause();
    s.onRawCount(10100);
    s.resume();
    s.onRawCount(10130);
    expect(s.currentSteps, 80);
    s.onRawCount(5); // reboot reset
    s.onRawCount(25);
    expect(s.currentSteps, 100);
  });
}
