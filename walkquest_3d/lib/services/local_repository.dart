import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quest.dart';
import '../models/social.dart';
import '../models/territory.dart';
import '../models/user_profile.dart';
import '../models/walk_session.dart';
import 'gamification_service.dart';
import 'repository.dart';

/// Offline repository backed by SharedPreferences. Social features are
/// simulated with a few rival "bots" so the leaderboard is playable solo.
class LocalRepository implements GameRepository {
  LocalRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool get isOnline => false;

  String _k(String uid, String what) => 'wq_${uid}_$what';

  List<Map<String, dynamic>> _list(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (json.decode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _putList(String key, List<Map<String, dynamic>> v) => _prefs.setString(key, json.encode(v));

  @override
  Future<UserProfile?> loadProfile(String uid) async {
    final raw = _prefs.getString(_k(uid, 'profile'));
    return raw == null ? null : UserProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveProfile(UserProfile p) => _prefs.setString(_k(p.uid, 'profile'), json.encode(p.toJson()));

  @override
  Future<List<WalkSession>> loadSessions(String uid) async =>
      _list(_k(uid, 'sessions')).map(WalkSession.fromJson).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<void> saveSession(String uid, WalkSession s) async {
    final list = _list(_k(uid, 'sessions'))..removeWhere((e) => e['id'] == s.id);
    list.add(s.toJson());
    await _putList(_k(uid, 'sessions'), list);
  }

  @override
  Future<List<Quest>> loadQuests(String uid) async => _list(_k(uid, 'quests')).map(Quest.fromJson).toList();

  @override
  Future<void> saveQuests(String uid, List<Quest> quests) =>
      _putList(_k(uid, 'quests'), quests.map((q) => q.toJson()).toList());

  @override
  Future<List<Territory>> loadTerritories(String uid) async =>
      _list(_k(uid, 'territories')).map(Territory.fromJson).toList();

  @override
  Future<void> saveTerritory(String uid, Territory t) async {
    final list = _list(_k(uid, 'territories'))..add(t.toJson());
    await _putList(_k(uid, 'territories'), list);
  }

  // ------------------------------------------------------------------ Social

  static const _bots = [
    ('bot_ava', 'Ava Stride', '🦄', 9),
    ('bot_kai', 'Kai Runner', '🐺', 14),
    ('bot_mio', 'Mio Trek', '🐼', 6),
    ('bot_leo', 'Leo Dash', '🦁', 11),
  ];

  /// Bots walk a believable amount that grows through the week.
  int _botSteps(String id, DateTime now) {
    final week = GamificationService.isoWeekId(now);
    final rnd = math.Random(id.hashCode ^ week.hashCode);
    final perDay = 4000 + rnd.nextInt(9000);
    final dayOfWeek = now.weekday; // 1..7
    final partial = (now.hour / 24);
    return (perDay * (dayOfWeek - 1 + partial)).round();
  }

  @override
  Future<List<FriendEntry>> friends(UserProfile me) async {
    final now = DateTime.now();
    final added = (_prefs.getStringList(_k(me.uid, 'friends')) ?? [])
        .map((e) => json.decode(e) as Map<String, dynamic>)
        .map(
          (j) => FriendEntry(
            uid: j['uid'] as String,
            displayName: j['name'] as String,
            avatarEmoji: j['emoji'] as String,
            weeklySteps: _botSteps(j['uid'] as String, now),
            level: j['level'] as int,
          ),
        );
    return [
      for (final b in _bots)
        FriendEntry(uid: b.$1, displayName: b.$2, avatarEmoji: b.$3, weeklySteps: _botSteps(b.$1, now), level: b.$4),
      ...added,
    ];
  }

  @override
  Future<FriendEntry?> addFriendByCode(UserProfile me, String code) async {
    final c = code.trim().toUpperCase();
    if (c.length < 4 || c == me.friendCode) return null;
    final entry = {
      'uid': 'local_$c',
      'name': 'Walker $c',
      'emoji': ['🐯', '🐸', '🦉', '🐙'][c.codeUnitAt(0) % 4],
      'level': 1 + c.codeUnitAt(c.length - 1) % 12,
    };
    final list = _prefs.getStringList(_k(me.uid, 'friends')) ?? [];
    if (list.any((e) => e.contains('"local_$c"'))) return null;
    list.add(json.encode(entry));
    await _prefs.setStringList(_k(me.uid, 'friends'), list);
    return FriendEntry(
      uid: entry['uid'] as String,
      displayName: entry['name'] as String,
      avatarEmoji: entry['emoji'] as String,
      weeklySteps: 0,
      level: entry['level'] as int,
    );
  }

  @override
  Future<List<Guild>> guilds(UserProfile me) async {
    final list = _list(_k(me.uid, 'guilds'));
    return [
      for (final j in list)
        Guild.fromJson(j['id'] as String, j).let(
          (g) => Guild(
            id: g.id,
            name: g.name,
            emoji: g.emoji,
            memberUids: g.memberUids,
            goalSteps: g.goalSteps,
            // Guild progress = my weekly steps + simulated members.
            progressSteps: me.weeklySteps + (g.memberUids.length - 1) * _botSteps(g.id, DateTime.now()) ~/ 2,
          ),
        ),
    ];
  }

  @override
  Future<Guild> createGuild(UserProfile me, String name, String emoji, int goalSteps) async {
    final id = 'guild_${DateTime.now().millisecondsSinceEpoch}';
    final g = Guild(
      id: id,
      name: name,
      emoji: emoji,
      memberUids: [me.uid, 'bot_ava', 'bot_mio'],
      goalSteps: goalSteps,
      progressSteps: 0,
    );
    final list = _list(_k(me.uid, 'guilds'))..add({'id': id, ...g.toJson()});
    await _putList(_k(me.uid, 'guilds'), list);
    return g;
  }

  @override
  Future<Guild?> joinGuild(UserProfile me, String guildId) async => null;

  @override
  Future<List<Challenge>> challenges(UserProfile me) async =>
      _list(_k(me.uid, 'challenges')).map((j) => Challenge.fromJson(j['id'] as String, j)).toList();

  @override
  Future<void> sendChallenge(Challenge c) async {
    final list = _list(_k(c.fromUid, 'challenges'))..add({'id': c.id, ...c.toJson()});
    await _putList(_k(c.fromUid, 'challenges'), list);
  }

  @override
  Future<void> updateChallenge(String id, ChallengeStatus status) async {}
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
