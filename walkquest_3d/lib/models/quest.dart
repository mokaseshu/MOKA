import 'lat_lng.dart';

enum QuestType {
  /// Reach a specific destination (map-selected or a story landmark).
  reachDestination,

  /// Cover a distance (any mode) within the quest window.
  walkDistance,

  /// Cover a distance in running mode.
  runDistance,

  /// Take a number of steps.
  takeSteps,

  /// Close a loop around an area to capture it as territory.
  captureTerritory,
}

enum QuestCategory { daily, story, custom }

enum QuestStatus { available, active, completed, claimed }

class Quest {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final QuestType type;
  final QuestCategory category;

  /// Meters for distance quests, steps for step quests, count for others.
  final double target;
  final double progress;
  final int rewardCoins;
  final int rewardXp;
  final QuestStatus status;
  final DateTime? expiresAt;

  /// For story quests: the straight-line distance at which the landmark is
  /// spawned from the player. For destination quests: the destination.
  final LatLng? destination;
  final String? landmarkName;

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.type,
    required this.category,
    required this.target,
    this.progress = 0,
    required this.rewardCoins,
    required this.rewardXp,
    this.status = QuestStatus.available,
    this.expiresAt,
    this.destination,
    this.landmarkName,
  });

  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0, 1);
  bool get isDone => status == QuestStatus.completed || status == QuestStatus.claimed;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!) && !isDone;

  Quest copyWith({double? progress, QuestStatus? status, LatLng? destination}) => Quest(
    id: id,
    title: title,
    description: description,
    emoji: emoji,
    type: type,
    category: category,
    target: target,
    progress: progress ?? this.progress,
    rewardCoins: rewardCoins,
    rewardXp: rewardXp,
    status: status ?? this.status,
    expiresAt: expiresAt,
    destination: destination ?? this.destination,
    landmarkName: landmarkName,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'emoji': emoji,
    'type': type.name,
    'category': category.name,
    'target': target,
    'progress': progress,
    'rewardCoins': rewardCoins,
    'rewardXp': rewardXp,
    'status': status.name,
    'expiresAt': expiresAt?.toIso8601String(),
    'destination': destination?.toJson(),
    'landmarkName': landmarkName,
  };

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    emoji: j['emoji'] as String? ?? '⭐',
    type: QuestType.values.byName(j['type'] as String),
    category: QuestCategory.values.byName(j['category'] as String),
    target: (j['target'] as num).toDouble(),
    progress: (j['progress'] as num?)?.toDouble() ?? 0,
    rewardCoins: (j['rewardCoins'] as num).toInt(),
    rewardXp: (j['rewardXp'] as num).toInt(),
    status: QuestStatus.values.byName(j['status'] as String),
    expiresAt: j['expiresAt'] == null ? null : DateTime.parse(j['expiresAt'] as String),
    destination: j['destination'] == null ? null : LatLng.fromJson(Map<String, dynamic>.from(j['destination'] as Map)),
    landmarkName: j['landmarkName'] as String?,
  );
}
