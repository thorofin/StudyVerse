import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/message.dart';
import '../models/resource.dart';
import '../models/meeting.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

static Future<Database> _initDB() async {
  final path = join(await getDatabasesPath(), 'studyverse.db');
  return openDatabase(
    path,
    version: 4,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE users (
          id       TEXT PRIMARY KEY,
          name     TEXT NOT NULL,
          email    TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE groups (
          id      TEXT PRIMARY KEY,
          name    TEXT NOT NULL,
          code    TEXT NOT NULL UNIQUE,
          adminId TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE group_members (
          groupId TEXT NOT NULL,
          userId  TEXT NOT NULL,
          role    TEXT NOT NULL DEFAULT 'student',
          PRIMARY KEY (groupId, userId)
        )
      ''');
      await db.execute('''
        CREATE TABLE messages (
          id        TEXT    PRIMARY KEY,
          groupId   TEXT    NOT NULL,
          userId    TEXT    NOT NULL,
          text      TEXT    NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE resources (
          id      TEXT PRIMARY KEY,
          groupId TEXT NOT NULL,
          title   TEXT NOT NULL,
          url     TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE meetings (
          id      TEXT PRIMARY KEY,
          groupId TEXT NOT NULL,
          dateISO TEXT NOT NULL,
          topic   TEXT NOT NULL
        )
      ''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 4) {
        try {
          await db.execute(
            'ALTER TABLE users ADD COLUMN email TEXT NOT NULL DEFAULT ""',
          );
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE users ADD COLUMN password TEXT NOT NULL DEFAULT ""',
          );
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE group_members ADD COLUMN role TEXT NOT NULL DEFAULT "student"',
          );
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE groups ADD COLUMN adminId TEXT NOT NULL DEFAULT ""',
          );
        } catch (_) {}
      }
    },
  );
}
  // ── UserDao ───────────────────────────────────────────────

static Future<void> insertUser(User u, {String password = ''}) async {
  final db = await database;
  await db.insert(
    'users',
    {
      'id':       u.id,
      'name':     u.name,
      'email':    u.email,
      'password': password,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

  static Future<User?> getUserById(String id) async {
    final db   = await database;
    final maps = await db.query('users',
        where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : User.fromMap(maps.first);
  }
  // Chercher un utilisateur par son nom
  static Future<User?> findUserByName(String name) async {
    final db   = await database;
    final maps = await db.query(
      'users',
      where:     'name = ?',
      whereArgs: [name.trim()],
    );
    return maps.isEmpty ? null : User.fromMap(maps.first);
  }
static Future<User?> findUserByEmail(String email) async {
  final db   = await database;
  final maps = await db.query(
    'users',
    where:     'email = ?',
    whereArgs: [email.trim().toLowerCase()],
  );
  return maps.isEmpty ? null : User.fromMap(maps.first);
}

static Future<User?> loginUser(String email, String password) async {
  final db   = await database;
  final maps = await db.query(
    'users',
    where:     'email = ? AND password = ?',
    whereArgs: [email.trim().toLowerCase(), password],
  );
  return maps.isEmpty ? null : User.fromMap(maps.first);
}

static Future<bool> emailExists(String email) async {
  final db   = await database;
  final maps = await db.query(
    'users',
    where:     'email = ?',
    whereArgs: [email.trim().toLowerCase()],
  );
  return maps.isNotEmpty;
}
  // ── GroupDao ──────────────────────────────────────────────

  static Future<void> insert(Group group) async {
    final db = await database;
    await db.insert('groups', group.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Group>> getAll() async {
    final db   = await database;
    final maps = await db.query('groups');
    return maps.map(Group.fromMap).toList();
  }

  static Future<Group?> findByCode(String code) async {
    final db   = await database;
    final maps = await db.query('groups',
        where: 'code = ?', whereArgs: [code]);
    return maps.isEmpty ? null : Group.fromMap(maps.first);
  }

  static Future<void> deleteGroup(String groupId) async {
    final db = await database;
    await db.delete('group_members',
        where: 'groupId = ?', whereArgs: [groupId]);
    await db.delete('groups',
        where: 'id = ?', whereArgs: [groupId]);
  }

  // ── GroupMemberDao ────────────────────────────────────────

  static Future<void> insertMember(GroupMember member) async {
    final db = await database;
    await db.insert('group_members', member.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<List<Group>> getGroupsByUser(String userId) async {
    final db   = await database;
    final maps = await db.rawQuery('''
      SELECT g.* FROM groups g
      INNER JOIN group_members gm ON g.id = gm.groupId
      WHERE gm.userId = ?
    ''', [userId]);
    return maps.map(Group.fromMap).toList();
  }

  static Future<List<User>> getUsersByGroup(String groupId) async {
    final db   = await database;
    final maps = await db.rawQuery('''
      SELECT u.*, gm.role FROM users u
      INNER JOIN group_members gm ON u.id = gm.userId
      WHERE gm.groupId = ?
      ORDER BY gm.role DESC
    ''', [groupId]);
    return maps.map(User.fromMap).toList();
  }

  static Future<List<GroupMember>> getMembersByGroup(String groupId) async {
    final db   = await database;
    final maps = await db.query('group_members',
        where: 'groupId = ?', whereArgs: [groupId]);
    return maps.map(GroupMember.fromMap).toList();
  }

  static Future<MemberRole?> getUserRole(
      String groupId, String userId) async {
    final db   = await database;
    final maps = await db.query(
      'group_members',
      where:     'groupId = ? AND userId = ?',
      whereArgs: [groupId, userId],
    );
    if (maps.isEmpty) return null;
    return maps.first['role'] == 'admin'
        ? MemberRole.admin
        : MemberRole.student;
  }

  static Future<void> removeMember(
      String groupId, String userId) async {
    final db = await database;
    await db.delete(
      'group_members',
      where:     'groupId = ? AND userId = ?',
      whereArgs: [groupId, userId],
    );
  }

  // ── MessageDao ────────────────────────────────────────────

  static Future<void> insertMessage(Message m) async {
    final db = await database;
    await db.insert('messages', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Message>> getByGroup(String groupId) async {
    final db   = await database;
    final maps = await db.query('messages',
        where:   'groupId = ?',
        whereArgs: [groupId],
        orderBy: 'timestamp ASC');
    return maps.map(Message.fromMap).toList();
  }

  static Future<void> deleteAllMessages(String groupId) async {
    final db = await database;
    await db.delete('messages',
        where: 'groupId = ?', whereArgs: [groupId]);
  }

  // ── ResourceDao ───────────────────────────────────────────

  static Future<void> insertResource(Resource r) async {
    final db = await database;
    await db.insert('resources', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Resource>> getResources(String groupId) async {
    final db   = await database;
    final maps = await db.query('resources',
        where: 'groupId = ?', whereArgs: [groupId]);
    return maps.map(Resource.fromMap).toList();
  }

  static Future<void> deleteResource(String id) async {
    final db = await database;
    await db.delete('resources', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateResource(Resource r) async {
    final db = await database;
    await db.update('resources', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  // ── MeetingDao ────────────────────────────────────────────

  static Future<void> insertMeeting(Meeting m) async {
    final db = await database;
    await db.insert('meetings', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Meeting>> getMeetings(String groupId) async {
    final db   = await database;
    final maps = await db.query('meetings',
        where:   'groupId = ?',
        whereArgs: [groupId],
        orderBy: 'dateISO ASC');
    return maps.map(Meeting.fromMap).toList();
  }

  static Future<void> deleteMeeting(String id) async {
    final db = await database;
    await db.delete('meetings', where: 'id = ?', whereArgs: [id]);
  }
}