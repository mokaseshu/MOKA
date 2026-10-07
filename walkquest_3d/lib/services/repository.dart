import '../models/quest.dart';
import '../models/social.dart';
import '../models/territory.dart';
import '../models/user_profile.dart';
import '../models/walk_session.dart';

/// Storage + social backend. Implemented by [FirestoreRepository] (online)
/// and [LocalRepository] (offline / no Firebase configured).
abstract class GameRepository {
  bool get isOnline;

  Future<UserProfile?> loadProfile(String uid);
  Future<void> saveProfile(UserProfile profile);

  Future<List<WalkSession>> loadSessions(String uid);
  Future<void> saveSession(String uid, WalkSession session);

  Future<List<Quest>> loadQuests(String uid);
  Future<void> saveQuests(String uid, List<Quest> quests);

  Future<List<Territory>> loadTerritories(String uid);
  Future<void> saveTerritory(String uid, Territory territory);

  // Social
  Future<List<FriendEntry>> friends(UserProfile me);
  Future<FriendEntry?> addFriendByCode(UserProfile me, String code);
  Future<List<Guild>> guilds(UserProfile me);
  Future<Guild> createGuild(UserProfile me, String name, String emoji, int goalSteps);
  Future<Guild?> joinGuild(UserProfile me, String guildId);
  Future<List<Challenge>> challenges(UserProfile me);
  Future<void> sendChallenge(Challenge challenge);
  Future<void> updateChallenge(String id, ChallengeStatus status);
}
