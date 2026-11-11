import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quest.dart';
import '../models/social.dart';
import '../models/territory.dart';
import '../models/user_profile.dart';
import '../models/walk_session.dart';
import 'repository.dart';

/// Firestore layout (see docs/FIREBASE_SETUP.md):
///
///   users/{uid}                      UserProfile
///   users/{uid}/sessions/{id}        WalkSession
///   users/{uid}/quests/{id}          Quest
///   users/{uid}/territories/{id}     Territory
///   users/{uid}/friends/{friendUid}  {since}
///   friendCodes/{code}               {uid}
///   guilds/{id}                      Guild
///   challenges/{id}                  Challenge
class FirestoreRepository implements GameRepository {
  FirestoreRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  bool get isOnline => true;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  @override
  Future<UserProfile?> loadProfile(String uid) async {
    final snap = await _user(uid).get();
    return snap.exists ? UserProfile.fromJson(snap.data()!) : null;
  }

  @override
  Future<void> saveProfile(UserProfile p) async {
    final batch = _db.batch()
      ..set(_user(p.uid), p.toJson(), SetOptions(merge: true))
      ..set(_db.collection('friendCodes').doc(p.friendCode), {'uid': p.uid});
    await batch.commit();
  }

  @override
  Future<List<WalkSession>> loadSessions(String uid) async {
    final q = await _user(uid).collection('sessions').orderBy('startedAt', descending: true).limit(200).get();
    return q.docs.map((d) => WalkSession.fromJson(d.data())).toList();
  }

  @override
  Future<void> saveSession(String uid, WalkSession s) => _user(uid).collection('sessions').doc(s.id).set(s.toJson());

  @override
  Future<List<Quest>> loadQuests(String uid) async {
    final q = await _user(uid).collection('quests').get();
    return q.docs.map((d) => Quest.fromJson(d.data())).toList();
  }

  @override
  Future<void> saveQuests(String uid, List<Quest> quests) async {
    final col = _user(uid).collection('quests');
    final existing = await col.get();
    final keep = quests.map((q) => q.id).toSet();
    final batch = _db.batch();
    for (final d in existing.docs) {
      if (!keep.contains(d.id)) batch.delete(d.reference);
    }
    for (final q in quests) {
      batch.set(col.doc(q.id), q.toJson());
    }
    await batch.commit();
  }

  @override
  Future<List<Territory>> loadTerritories(String uid) async {
    final q = await _user(uid).collection('territories').get();
    return q.docs.map((d) => Territory.fromJson(d.data())).toList();
  }

  @override
  Future<void> saveTerritory(String uid, Territory t) => _user(uid).collection('territories').doc(t.id).set(t.toJson());

  // ------------------------------------------------------------------ Social

  FriendEntry _entry(Map<String, dynamic> j, {bool isMe = false}) => FriendEntry(
    uid: j['uid'] as String,
    displayName: j['displayName'] as String? ?? 'Adventurer',
    avatarEmoji: (j['avatar'] as Map?)?['emoji'] as String? ?? '🧭',
    weeklySteps: (j['weeklySteps'] as num?)?.toInt() ?? 0,
    level: (j['level'] as num?)?.toInt() ?? 1,
    isMe: isMe,
  );

  @override
  Future<List<FriendEntry>> friends(UserProfile me) async {
    final ids = (await _user(me.uid).collection('friends').get()).docs.map((d) => d.id).toList();
    final out = <FriendEntry>[];
    // whereIn accepts at most 30 values per query.
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final q = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      out.addAll(q.docs.map((d) => _entry(d.data())));
    }
    return out;
  }

  @override
  Future<FriendEntry?> addFriendByCode(UserProfile me, String code) async {
    final c = code.trim().toUpperCase();
    final codeDoc = await _db.collection('friendCodes').doc(c).get();
    final uid = codeDoc.data()?['uid'] as String?;
    if (uid == null || uid == me.uid) return null;
    final now = DateTime.now().toIso8601String();
    // Friendship is mutual; rules allow writing your own uid into someone's list.
    final batch = _db.batch()
      ..set(_user(me.uid).collection('friends').doc(uid), {'since': now})
      ..set(_user(uid).collection('friends').doc(me.uid), {'since': now});
    await batch.commit();
    final snap = await _user(uid).get();
    return snap.exists ? _entry(snap.data()!) : null;
  }

  @override
  Future<List<Guild>> guilds(UserProfile me) async {
    final q = await _db.collection('guilds').where('memberUids', arrayContains: me.uid).get();
    return q.docs.map((d) => Guild.fromJson(d.id, d.data())).toList();
  }

  @override
  Future<Guild> createGuild(UserProfile me, String name, String emoji, int goalSteps) async {
    final ref = _db.collection('guilds').doc();
    final g = Guild(id: ref.id, name: name, emoji: emoji, memberUids: [me.uid], goalSteps: goalSteps, progressSteps: 0);
    await ref.set({...g.toJson(), 'ownerUid': me.uid, 'createdAt': FieldValue.serverTimestamp()});
    return g;
  }

  @override
  Future<Guild?> joinGuild(UserProfile me, String guildId) async {
    final ref = _db.collection('guilds').doc(guildId.trim());
    final snap = await ref.get();
    if (!snap.exists) return null;
    await ref.update({
      'memberUids': FieldValue.arrayUnion([me.uid]),
    });
    return Guild.fromJson(ref.id, (await ref.get()).data()!);
  }

  @override
  Future<List<Challenge>> challenges(UserProfile me) async {
    final sent = await _db.collection('challenges').where('fromUid', isEqualTo: me.uid).get();
    final got = await _db.collection('challenges').where('toUid', isEqualTo: me.uid).get();
    return [...sent.docs, ...got.docs].map((d) => Challenge.fromJson(d.id, d.data())).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> sendChallenge(Challenge c) => _db.collection('challenges').add(c.toJson());

  @override
  Future<void> updateChallenge(String id, ChallengeStatus status) =>
      _db.collection('challenges').doc(id).update({'status': status.name});
}
