/// A friend / leaderboard row (public subset of another user's profile).
class FriendEntry {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final int weeklySteps;
  final int level;
  final bool isMe;

  const FriendEntry({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.weeklySteps,
    required this.level,
    this.isMe = false,
  });
}

class Guild {
  final String id;
  final String name;
  final String emoji;
  final List<String> memberUids;
  final int goalSteps;
  final int progressSteps;

  const Guild({
    required this.id,
    required this.name,
    required this.emoji,
    required this.memberUids,
    required this.goalSteps,
    required this.progressSteps,
  });

  double get fraction => goalSteps == 0 ? 0 : (progressSteps / goalSteps).clamp(0, 1).toDouble();

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'memberUids': memberUids,
    'goalSteps': goalSteps,
    'progressSteps': progressSteps,
  };

  factory Guild.fromJson(String id, Map<String, dynamic> j) => Guild(
    id: id,
    name: j['name'] as String,
    emoji: j['emoji'] as String? ?? '🛡️',
    memberUids: (j['memberUids'] as List? ?? const []).cast<String>(),
    goalSteps: (j['goalSteps'] as num?)?.toInt() ?? 0,
    progressSteps: (j['progressSteps'] as num?)?.toInt() ?? 0,
  );
}

enum ChallengeStatus { pending, accepted, completed, declined }

/// "Beat my 5 km" style head-to-head challenge.
class Challenge {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String description;
  final int targetSteps;
  final ChallengeStatus status;
  final DateTime createdAt;

  const Challenge({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.description,
    required this.targetSteps,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'fromUid': fromUid,
    'fromName': fromName,
    'toUid': toUid,
    'toName': toName,
    'description': description,
    'targetSteps': targetSteps,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Challenge.fromJson(String id, Map<String, dynamic> j) => Challenge(
    id: id,
    fromUid: j['fromUid'] as String,
    fromName: j['fromName'] as String? ?? '',
    toUid: j['toUid'] as String,
    toName: j['toName'] as String? ?? '',
    description: j['description'] as String? ?? '',
    targetSteps: (j['targetSteps'] as num?)?.toInt() ?? 0,
    status: ChallengeStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
