import 'package:cloud_firestore/cloud_firestore.dart';

// timestamp = epoch Unix en millisecondes (INTEGER)
class Message {
  final String id;        // TEXT PK
  final String groupId;   // TEXT FK → Group
  final String userId;    // TEXT FK → User
  final String text;      // TEXT NOT NULL
  final int    timestamp; // INTEGER NOT NULL — epoch Unix ms

  const Message({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.text,
    required this.timestamp,
  });

  // Retourne l'heure formatée HH:mm
  String getFormattedTime() {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  // Retourne la date complète formatée
  String getFormattedDate() {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  Map<String, dynamic> toMap() => {
    'id':        id,
    'groupId':   groupId,
    'userId':    userId,
    'text':      text,
    'timestamp': timestamp,
  };

  factory Message.fromMap(Map<String, dynamic> m) => Message(
    id: m['id'] as String,
    groupId: m['groupId'] as String,
    userId: m['userId'] as String,
    text: m['text'] as String,
    timestamp: _parseTimestamp(m['timestamp']),
  );

  static int _parseTimestamp(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is Timestamp) return raw.millisecondsSinceEpoch;
    if (raw is DateTime) return raw.millisecondsSinceEpoch;
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
    throw FormatException('Invalid message timestamp: $raw');
  }
}