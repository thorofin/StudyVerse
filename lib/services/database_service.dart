import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/message.dart';
import '../models/resource.dart';
import '../models/meeting.dart';

class DatabaseService {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _users =>
      _fs.collection('users');
  static CollectionReference<Map<String, dynamic>> get _groups =>
      _fs.collection('groups');
  static CollectionReference<Map<String, dynamic>> get _groupMembers =>
      _fs.collection('group_members');
  static CollectionReference<Map<String, dynamic>> get _messages =>
      _fs.collection('messages');
  static CollectionReference<Map<String, dynamic>> get _resources =>
      _fs.collection('resources');
  static CollectionReference<Map<String, dynamic>> get _meetings =>
      _fs.collection('meetings');
  static CollectionReference<Map<String, dynamic>> get _typingStatus =>
      _fs.collection('typing_status');

  static String _memberDocId(String groupId, String userId) =>
      '${groupId}_$userId';

  static String _typingDocId(String groupId, String userId) =>
      '${groupId}_$userId';

  static Future<void> _deleteByQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    final snap = await query.get();
    if (snap.docs.isEmpty) return;

    final batch = _fs.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── UserDao ───────────────────────────────────────────────

  static Future<void> insertUser(User u, {String password = ''}) async {
    await _users.doc(u.id).set(
      {
        ...u.toMap(),
        'email': u.email.trim().toLowerCase(),
        'password': password,
      },
      SetOptions(merge: true),
    );
  }

  static Future<User?> getUserById(String id) async {
    final doc = await _users.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return User.fromMap(doc.data()!);
  }

  // Chercher un utilisateur par son nom
  static Future<User?> findUserByName(String name) async {
    final snap = await _users.where('name', isEqualTo: name.trim()).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return User.fromMap(snap.docs.first.data());
  }
  static Future<User?> findUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final snap = await _users.where('email', isEqualTo: normalized).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return User.fromMap(snap.docs.first.data());
  }

  static Future<User?> loginUser(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final snap = await _users
        .where('email', isEqualTo: normalized)
        .where('password', isEqualTo: password)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return User.fromMap(snap.docs.first.data());
  }

  static Future<bool> emailExists(String email) async {
    final normalized = email.trim().toLowerCase();
    final snap = await _users.where('email', isEqualTo: normalized).limit(1).get();
    return snap.docs.isNotEmpty;
  }
  // ── GroupDao ──────────────────────────────────────────────

  static Future<void> insert(Group group) async {
    await _groups.doc(group.id).set(group.toMap(), SetOptions(merge: true));
  }

  static Future<List<Group>> getAll() async {
    final snap = await _groups.get();
    return snap.docs.map((d) => Group.fromMap(d.data())).toList();
  }

  static Future<Group?> findByCode(String code) async {
    final snap = await _groups.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Group.fromMap(snap.docs.first.data());
  }

  static Future<void> deleteGroup(String groupId) async {
    await _deleteByQuery(_groupMembers.where('groupId', isEqualTo: groupId));
    await _deleteByQuery(_messages.where('groupId', isEqualTo: groupId));
    await _deleteByQuery(_resources.where('groupId', isEqualTo: groupId));
    await _deleteByQuery(_meetings.where('groupId', isEqualTo: groupId));
    await _deleteByQuery(_typingStatus.where('groupId', isEqualTo: groupId));
    await _groups.doc(groupId).delete();
  }

  // ── GroupMemberDao ────────────────────────────────────────

  static Future<void> insertMember(GroupMember member) async {
    await _groupMembers
        .doc(_memberDocId(member.groupId, member.userId))
        .set(member.toMap(), SetOptions(merge: true));
  }

  static Future<List<Group>> getGroupsByUser(String userId) async {
    final membershipSnap = await _groupMembers.where('userId', isEqualTo: userId).get();
    if (membershipSnap.docs.isEmpty) return [];

    final groupIds = membershipSnap.docs
        .map((d) => d.data()['groupId'] as String)
        .toSet()
        .toList();

    final groups = <Group>[];
    for (final gid in groupIds) {
      final g = await _groups.doc(gid).get();
      if (g.exists && g.data() != null) {
        groups.add(Group.fromMap(g.data()!));
      }
    }
    return groups;
  }

  static Future<List<User>> getUsersByGroup(String groupId) async {
    final members = await getMembersByGroup(groupId);
    if (members.isEmpty) return [];

    final users = <User>[];
    for (final m in members) {
      final u = await getUserById(m.userId);
      if (u != null) {
        users.add(u);
      } else {
        users.add(User(id: m.userId, name: 'Membre', email: ''));
      }
    }

    users.sort((a, b) {
      final roleA = members.firstWhere((m) => m.userId == a.id).role;
      final roleB = members.firstWhere((m) => m.userId == b.id).role;
      if (roleA == roleB) return a.name.compareTo(b.name);
      return roleA == MemberRole.admin ? -1 : 1;
    });
    return users;
  }

  static Future<List<GroupMember>> getMembersByGroup(String groupId) async {
    final snap = await _groupMembers.where('groupId', isEqualTo: groupId).get();
    final members = snap.docs.map((d) => GroupMember.fromMap(d.data())).toList();
    members.sort((a, b) {
      if (a.role == b.role) return a.userId.compareTo(b.userId);
      return a.role == MemberRole.admin ? -1 : 1;
    });
    return members;
  }

  static Stream<List<GroupMember>> watchMembersByGroup(String groupId) {
    return _groupMembers
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snap) {
      final members = snap.docs.map((d) => GroupMember.fromMap(d.data())).toList();
      members.sort((a, b) {
        if (a.role == b.role) return a.userId.compareTo(b.userId);
        return a.role == MemberRole.admin ? -1 : 1;
      });
      return members;
    });
  }

  static Stream<List<User>> watchUsersByGroup(String groupId) {
    return watchMembersByGroup(groupId).asyncMap((members) async {
      if (members.isEmpty) return <User>[];

      final users = <User>[];
      for (final m in members) {
        final u = await getUserById(m.userId);
        if (u != null) users.add(u);
      }

      users.sort((a, b) {
        final roleA = members.firstWhere((m) => m.userId == a.id).role;
        final roleB = members.firstWhere((m) => m.userId == b.id).role;
        if (roleA == roleB) return a.name.compareTo(b.name);
        return roleA == MemberRole.admin ? -1 : 1;
      });

      return users;
    });
  }

  static Future<MemberRole?> getUserRole(
      String groupId, String userId) async {
    final doc = await _groupMembers.doc(_memberDocId(groupId, userId)).get();
    if (!doc.exists || doc.data() == null) return null;
    return GroupMember.fromMap(doc.data()!).role;
  }

  static Future<void> removeMember(
      String groupId, String userId) async {
    await _groupMembers.doc(_memberDocId(groupId, userId)).delete();
    await _typingStatus.doc(_typingDocId(groupId, userId)).delete();
  }

  // ── MessageDao ────────────────────────────────────────────

  static Future<void> insertMessage(Message m) async {
    await _messages.doc(m.id).set(m.toMap(), SetOptions(merge: true));
  }

  static Future<List<Message>> getByGroup(String groupId) async {
    final snap = await _messages
        .where('groupId', isEqualTo: groupId)
        .orderBy('timestamp', descending: false)
        .get();
    final messages = <Message>[];
    for (final d in snap.docs) {
      try {
        messages.add(Message.fromMap(d.data()));
      } catch (_) {
        // Ignore malformed legacy message docs instead of breaking chat rendering.
      }
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  static Stream<List<Message>> watchMessagesByGroup(String groupId) {
    return _messages
        .where('groupId', isEqualTo: groupId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) {
      final messages = <Message>[];
      for (final d in snap.docs) {
        try {
          messages.add(Message.fromMap(d.data()));
        } catch (_) {
          // Ignore malformed legacy message docs instead of breaking chat rendering.
        }
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  static Future<void> deleteAllMessages(String groupId) async {
    await _deleteByQuery(_messages.where('groupId', isEqualTo: groupId));
  }

  // ── ResourceDao ───────────────────────────────────────────

  static Future<void> insertResource(Resource r) async {
    await _resources.doc(r.id).set(r.toMap(), SetOptions(merge: true));
  }

  static Future<List<Resource>> getResources(String groupId) async {
    final snap = await _resources.where('groupId', isEqualTo: groupId).get();
    return snap.docs.map((d) => Resource.fromMap(d.data())).toList();
  }

  static Future<void> deleteResource(String id) async {
    await _resources.doc(id).delete();
  }

  static Future<void> updateResource(Resource r) async {
    await _resources.doc(r.id).set(r.toMap(), SetOptions(merge: true));
  }

  // ── MeetingDao ────────────────────────────────────────────

  static Future<void> insertMeeting(Meeting m) async {
    await _meetings.doc(m.id).set(m.toMap(), SetOptions(merge: true));
  }

  static Future<List<Meeting>> getMeetings(String groupId) async {
    final snap = await _meetings
        .where('groupId', isEqualTo: groupId)
        .orderBy('dateISO', descending: false)
        .get();
    return snap.docs.map((d) => Meeting.fromMap(d.data())).toList();
  }

  static Future<void> deleteMeeting(String id) async {
    await _meetings.doc(id).delete();
  }

  // ── TypingStatusDao ──────────────────────────────────────

  static Future<void> setTypingStatus({
    required String groupId,
    required String userId,
    required bool isTyping,
  }) async {
    await _typingStatus.doc(_typingDocId(groupId, userId)).set(
      {
        'groupId': groupId,
        'userId': userId,
        'isTyping': isTyping,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      SetOptions(merge: true),
    );
  }

  static Future<List<String>> getTypingUserIds({
    required String groupId,
    required String excludeUserId,
    int staleAfterMs = 5000,
  }) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - staleAfterMs;

    // Firestore does not support "!=" with another where efficiently for this pattern,
    // so we fetch active typing docs then filter locally.
    final snap = await _typingStatus
        .where('groupId', isEqualTo: groupId)
        .where('isTyping', isEqualTo: true)
        .where('updatedAt', isGreaterThanOrEqualTo: cutoff)
        .get();

    return snap.docs
        .map((d) => d.data()['userId'] as String)
        .where((id) => id != excludeUserId)
        .toList();
  }

  static Stream<List<String>> watchTypingUserIds({
    required String groupId,
    required String excludeUserId,
    int staleAfterMs = 5000,
  }) {
    return _typingStatus
        .where('groupId', isEqualTo: groupId)
        .where('isTyping', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final cutoff = DateTime.now().millisecondsSinceEpoch - staleAfterMs;
      return snap.docs
          .where((d) {
            final updatedAt = d.data()['updatedAt'] as int? ?? 0;
            return updatedAt >= cutoff;
          })
          .map((d) => d.data()['userId'] as String)
          .where((id) => id != excludeUserId)
          .toList();
    });
  }

  static Future<void> clearTypingStatus({
    required String groupId,
    required String userId,
  }) async {
    await _typingStatus.doc(_typingDocId(groupId, userId)).delete();
  }
}