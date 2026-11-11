import 'package:flutter/foundation.dart';

import '../models/lat_lng.dart';
import '../models/quest.dart';
import '../models/route_plan.dart';
import '../models/shop_item.dart';
import '../models/social.dart';
import '../models/territory.dart';
import '../models/user_profile.dart';
import '../models/walk_session.dart';
import '../services/auth_service.dart';
import '../services/catalog.dart';
import '../services/gamification_service.dart';
import '../services/health_service.dart';
import '../services/quest_service.dart';
import '../services/repository.dart';

/// Owns the player's progression: profile, history, quests, territories,
/// shop and social data.
class GameController extends ChangeNotifier {
  GameController({required this.repo, required this.auth, HealthService? health}) : _health = health ?? HealthService();

  final GameRepository repo;
  final AuthService auth;
  final HealthService _health;

  UserProfile? _profile;
  List<WalkSession> _sessions = [];
  List<Quest> _quests = [];
  List<Territory> _territories = [];
  List<FriendEntry> _friends = [];
  List<Guild> _guilds = [];
  List<Challenge> _challenges = [];
  int _rerolls = 0;
  bool _loading = false;

  UserProfile? get profile => _profile;
  UserProfile get me => _profile!;
  bool get isSignedIn => _profile != null;
  bool get loading => _loading;
  List<WalkSession> get sessions => _sessions;
  List<Territory> get territories => _territories;
  List<FriendEntry> get friends => _friends;
  List<Guild> get guilds => _guilds;
  List<Challenge> get challenges => _challenges;

  List<Quest> get dailyQuests => _quests.where((q) => q.category == QuestCategory.daily && !q.isExpired).toList();
  List<Quest> get storyQuests => _quests.where((q) => q.category == QuestCategory.story).toList();
  List<Quest> get customQuests => _quests.where((q) => q.category == QuestCategory.custom).toList();

  /// Story chapters unlock in order.
  bool isStoryUnlocked(Quest q) {
    final i = storyQuests.indexWhere((s) => s.id == q.id);
    return i <= 0 || storyQuests[i - 1].isDone;
  }

  // ------------------------------------------------------------------ Session

  Future<void> signIn(String uid, {String? displayName}) async {
    _loading = true;
    notifyListeners();
    try {
      var p = await repo.loadProfile(uid);
      p ??= UserProfile(uid: uid, displayName: displayName ?? 'Adventurer', friendCode: AuthService.newFriendCode());
      // Weekly leaderboard rollover.
      final week = GamificationService.isoWeekId(DateTime.now());
      if (p.weekId != week) p = p.copyWith(weekId: week, weeklySteps: 0);
      _profile = p;
      await repo.saveProfile(p);

      _sessions = await repo.loadSessions(uid);
      _territories = await repo.loadTerritories(uid);
      _quests = await repo.loadQuests(uid);
      await _refreshQuests();
    } finally {
      _loading = false;
      notifyListeners();
    }
    refreshSocial();
  }

  Future<void> signOut() async {
    await auth.signOut();
    _profile = null;
    _sessions = [];
    _quests = [];
    _territories = [];
    notifyListeners();
  }

  Future<void> _refreshQuests() async {
    final today = DateTime.now();
    // Drop expired/finished dailies from previous days; keep today's set.
    _quests.removeWhere((q) => q.category == QuestCategory.daily && q.isExpired);
    _quests.removeWhere(
      (q) =>
          q.category == QuestCategory.daily &&
          q.expiresAt != null &&
          q.expiresAt!.isBefore(DateTime(today.year, today.month, today.day)),
    );
    if (dailyQuests.isEmpty) {
      _quests.addAll(QuestService.dailyQuests(today, reroll: _rerolls));
    }
    for (final s in QuestService.storyQuests) {
      if (!_quests.any((q) => q.id == s.id)) _quests.add(s);
    }
    // Keep only the 10 most recent finished destination quests.
    final doneCustom = customQuests.where((q) => q.isDone).toList()..sort((a, b) => b.id.compareTo(a.id));
    final stale = doneCustom.skip(10).map((q) => q.id).toSet();
    _quests.removeWhere((q) => stale.contains(q.id));
    await repo.saveQuests(me.uid, _quests);
  }

  /// Pulls today's total steps from HealthKit/Health Connect so steps walked
  /// outside the app still count toward streaks and daily achievements.
  Future<void> syncHealthSteps() async {
    if (_profile == null) return;
    if (!await _health.authorize()) return;
    final steps = await _health.stepsToday();
    if (steps == null) return;
    final key = UserProfile.dayKey(DateTime.now());
    if (steps > me.stepsOn(DateTime.now())) {
      _profile = me.copyWith(dailySteps: {...me.dailySteps, key: steps});
      await repo.saveProfile(me);
      notifyListeners();
    }
  }

  /// Records a finished walk and returns what it earned.
  Future<RewardSummary> recordSession(
    WalkSession session, {
    List<Territory> captured = const [],
    bool saveRoute = true,
    bool writeToHealth = false,
  }) async {
    for (final t in captured) {
      _territories.add(t);
      await repo.saveTerritory(me.uid, t);
    }
    final outcome = GamificationService.applySession(
      profile: me,
      session: session,
      history: _sessions,
      quests: _quests,
      territoriesCapturedThisSession: captured.length,
      territoriesTotal: _territories.length,
    );
    _profile = outcome.profile;
    _quests = outcome.quests;
    final stored = saveRoute ? outcome.session : outcome.session.copyWith(path: const []);
    _sessions = [stored, ..._sessions];
    notifyListeners();

    await repo.saveProfile(me);
    await repo.saveSession(me.uid, stored);
    await repo.saveQuests(me.uid, _quests);
    if (writeToHealth) await _health.writeSession(session);
    return outcome.rewards;
  }

  // ------------------------------------------------------------------- Quests

  /// Spawns the story landmark near the player and marks the quest active.
  Future<Quest> beginStoryQuest(Quest q, LatLng origin) async {
    final started = q.copyWith(
      status: QuestStatus.active,
      destination: q.destination ?? QuestService.spawnLandmark(origin, q),
    );
    _replaceQuest(started);
    await repo.saveQuests(me.uid, _quests);
    return started;
  }

  Future<Quest> addDestinationQuest(RoutePlan plan) async {
    final q = QuestService.destinationQuest(plan);
    _quests.add(q);
    notifyListeners();
    await repo.saveQuests(me.uid, _quests);
    return q;
  }

  void _replaceQuest(Quest q) {
    final i = _quests.indexWhere((x) => x.id == q.id);
    if (i >= 0) {
      _quests[i] = q;
    } else {
      _quests.add(q);
    }
    notifyListeners();
  }

  // --------------------------------------------------------------------- Shop

  bool owns(ShopItem item) => item.type != ShopItemType.powerUp && me.ownedItems.contains(item.id);

  int powerUpCharges(String id) => me.powerUps[id] ?? 0;

  /// Returns false if the player can't afford it or already owns it.
  Future<bool> buy(ShopItem item) async {
    if (me.coins < item.price || owns(item)) return false;
    var p = me.copyWith(coins: me.coins - item.price);
    if (item.type == ShopItemType.powerUp) {
      if (item.id == 'pu_reroll') {
        _rerolls++;
        _quests.removeWhere((q) => q.category == QuestCategory.daily && !q.isDone);
        _quests.addAll(QuestService.dailyQuests(DateTime.now(), reroll: _rerolls));
        await repo.saveQuests(me.uid, _quests);
      } else {
        p = p.copyWith(powerUps: {...p.powerUps, item.id: (p.powerUps[item.id] ?? 0) + 1});
      }
    } else {
      p = p.copyWith(ownedItems: {...p.ownedItems, item.id});
    }
    _profile = p;
    notifyListeners();
    await repo.saveProfile(p);
    return true;
  }

  Future<void> equip(ShopItem item) async {
    if (!owns(item)) return;
    final avatar = switch (item.type) {
      ShopItemType.skin => me.avatar.copyWith(skinId: item.id, emoji: item.emoji),
      ShopItemType.trail => me.avatar.copyWith(trailId: item.id),
      ShopItemType.powerUp => me.avatar,
    };
    _profile = me.copyWith(avatar: avatar);
    notifyListeners();
    await repo.saveProfile(me);
  }

  Future<void> rename(String name) async {
    if (name.trim().isEmpty) return;
    _profile = me.copyWith(displayName: name.trim());
    notifyListeners();
    await repo.saveProfile(me);
  }

  int get trailColor => Catalog.trail(me.avatar.trailId).color;
  ShopItem get skin => Catalog.skin(me.avatar.skinId);

  // ------------------------------------------------------------------- Social

  Future<void> refreshSocial() async {
    if (_profile == null) return;
    try {
      _friends = await repo.friends(me);
      _guilds = await repo.guilds(me);
      _challenges = await repo.challenges(me);
      notifyListeners();
    } catch (e) {
      debugPrint('social refresh failed: $e');
    }
  }

  /// Friends + me, sorted by weekly steps.
  List<FriendEntry> get leaderboard {
    if (_profile == null) return const [];
    final rows = [
      ..._friends,
      FriendEntry(
        uid: me.uid,
        displayName: me.displayName,
        avatarEmoji: me.avatar.emoji,
        weeklySteps: me.weeklySteps,
        level: me.level,
        isMe: true,
      ),
    ]..sort((a, b) => b.weeklySteps.compareTo(a.weeklySteps));
    return rows;
  }

  Future<FriendEntry?> addFriend(String code) async {
    final f = await repo.addFriendByCode(me, code);
    if (f != null) await refreshSocial();
    return f;
  }

  Future<void> createGuild(String name, String emoji, int goalSteps) async {
    await repo.createGuild(me, name, emoji, goalSteps);
    await refreshSocial();
  }

  Future<bool> joinGuild(String id) async {
    final g = await repo.joinGuild(me, id);
    await refreshSocial();
    return g != null;
  }

  Future<void> challenge(FriendEntry friend, int targetSteps) async {
    await repo.sendChallenge(
      Challenge(
        id: 'ch_${DateTime.now().millisecondsSinceEpoch}',
        fromUid: me.uid,
        fromName: me.displayName,
        toUid: friend.uid,
        toName: friend.displayName,
        description: 'First to $targetSteps steps this week wins!',
        targetSteps: targetSteps,
        status: ChallengeStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    await refreshSocial();
  }
}
