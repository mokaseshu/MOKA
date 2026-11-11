import '../utils/leveling.dart';

/// Which skin/trail the avatar has equipped.
class AvatarConfig {
  final String skinId;
  final String trailId;
  final String emoji;

  const AvatarConfig({this.skinId = 'skin_explorer', this.trailId = 'trail_violet', this.emoji = '🧭'});

  AvatarConfig copyWith({String? skinId, String? trailId, String? emoji}) =>
      AvatarConfig(skinId: skinId ?? this.skinId, trailId: trailId ?? this.trailId, emoji: emoji ?? this.emoji);

  Map<String, dynamic> toJson() => {'skinId': skinId, 'trailId': trailId, 'emoji': emoji};

  factory AvatarConfig.fromJson(Map<String, dynamic>? j) => j == null
      ? const AvatarConfig()
      : AvatarConfig(
          skinId: j['skinId'] as String? ?? 'skin_explorer',
          trailId: j['trailId'] as String? ?? 'trail_violet',
          emoji: j['emoji'] as String? ?? '🧭',
        );
}

/// The player's persistent RPG state.
class UserProfile {
  final String uid;
  final String displayName;
  final String friendCode;
  final AvatarConfig avatar;

  final int coins;
  final int xp;

  final int lifetimeSteps;
  final double lifetimeDistanceM;
  final double lifetimeKcal;
  final int questsCompleted;

  /// Steps per local day, keyed `yyyy-MM-dd`. Trimmed to the last 60 days.
  final Map<String, int> dailySteps;

  /// ISO week id (`2026-W41`) the [weeklySteps] counter belongs to.
  final String weekId;
  final int weeklySteps;

  final Set<String> ownedItems;
  final Set<String> unlockedAchievements;

  /// Power-up id -> remaining charges (one charge per session).
  final Map<String, int> powerUps;

  final List<String> guildIds;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.friendCode,
    this.avatar = const AvatarConfig(),
    this.coins = 0,
    this.xp = 0,
    this.lifetimeSteps = 0,
    this.lifetimeDistanceM = 0,
    this.lifetimeKcal = 0,
    this.questsCompleted = 0,
    this.dailySteps = const {},
    this.weekId = '',
    this.weeklySteps = 0,
    this.ownedItems = const {'skin_explorer', 'trail_violet'},
    this.unlockedAchievements = const {},
    this.powerUps = const {},
    this.guildIds = const [],
  });

  int get level => Leveling.levelForXp(xp);

  /// Consecutive days (ending today or yesterday) with >= 1,000 steps.
  int streakDays(DateTime today) {
    var day = DateTime(today.year, today.month, today.day);
    if ((dailySteps[dayKey(day)] ?? 0) < Leveling.streakMinSteps) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while ((dailySteps[dayKey(day)] ?? 0) >= Leveling.streakMinSteps) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int stepsOn(DateTime day) => dailySteps[dayKey(day)] ?? 0;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  UserProfile copyWith({
    String? displayName,
    AvatarConfig? avatar,
    int? coins,
    int? xp,
    int? lifetimeSteps,
    double? lifetimeDistanceM,
    double? lifetimeKcal,
    int? questsCompleted,
    Map<String, int>? dailySteps,
    String? weekId,
    int? weeklySteps,
    Set<String>? ownedItems,
    Set<String>? unlockedAchievements,
    Map<String, int>? powerUps,
    List<String>? guildIds,
  }) => UserProfile(
    uid: uid,
    displayName: displayName ?? this.displayName,
    friendCode: friendCode,
    avatar: avatar ?? this.avatar,
    coins: coins ?? this.coins,
    xp: xp ?? this.xp,
    lifetimeSteps: lifetimeSteps ?? this.lifetimeSteps,
    lifetimeDistanceM: lifetimeDistanceM ?? this.lifetimeDistanceM,
    lifetimeKcal: lifetimeKcal ?? this.lifetimeKcal,
    questsCompleted: questsCompleted ?? this.questsCompleted,
    dailySteps: dailySteps ?? this.dailySteps,
    weekId: weekId ?? this.weekId,
    weeklySteps: weeklySteps ?? this.weeklySteps,
    ownedItems: ownedItems ?? this.ownedItems,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    powerUps: powerUps ?? this.powerUps,
    guildIds: guildIds ?? this.guildIds,
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'friendCode': friendCode,
    'avatar': avatar.toJson(),
    'coins': coins,
    'xp': xp,
    'level': level,
    'lifetimeSteps': lifetimeSteps,
    'lifetimeDistanceM': lifetimeDistanceM,
    'lifetimeKcal': lifetimeKcal,
    'questsCompleted': questsCompleted,
    'dailySteps': dailySteps,
    'weekId': weekId,
    'weeklySteps': weeklySteps,
    'ownedItems': ownedItems.toList(),
    'unlockedAchievements': unlockedAchievements.toList(),
    'powerUps': powerUps,
    'guildIds': guildIds,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    uid: j['uid'] as String,
    displayName: j['displayName'] as String? ?? 'Adventurer',
    friendCode: j['friendCode'] as String? ?? '',
    avatar: AvatarConfig.fromJson((j['avatar'] as Map?)?.cast<String, dynamic>()),
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    lifetimeSteps: (j['lifetimeSteps'] as num?)?.toInt() ?? 0,
    lifetimeDistanceM: (j['lifetimeDistanceM'] as num?)?.toDouble() ?? 0,
    lifetimeKcal: (j['lifetimeKcal'] as num?)?.toDouble() ?? 0,
    questsCompleted: (j['questsCompleted'] as num?)?.toInt() ?? 0,
    dailySteps: ((j['dailySteps'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
    weekId: j['weekId'] as String? ?? '',
    weeklySteps: (j['weeklySteps'] as num?)?.toInt() ?? 0,
    ownedItems: ((j['ownedItems'] as List?) ?? const ['skin_explorer', 'trail_violet']).cast<String>().toSet(),
    unlockedAchievements: ((j['unlockedAchievements'] as List?) ?? const []).cast<String>().toSet(),
    powerUps: ((j['powerUps'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
    guildIds: ((j['guildIds'] as List?) ?? const []).cast<String>(),
  );
}
