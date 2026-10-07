import 'user_profile.dart';
import 'walk_session.dart';

/// Inputs an achievement rule can look at: the profile *after* the latest
/// session has been applied, plus that session and the full history.
class AchievementContext {
  final UserProfile profile;
  final WalkSession? latestSession;
  final List<WalkSession> history;
  final int territoriesCaptured;

  const AchievementContext({
    required this.profile,
    required this.history,
    this.latestSession,
    this.territoriesCaptured = 0,
  });
}

/// A static achievement definition. Unlocked ids are stored on the profile.
class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int rewardCoins;

  /// Returns progress in [0, 1]; 1 means unlocked.
  final double Function(AchievementContext ctx) progress;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.rewardCoins,
    required this.progress,
  });
}
