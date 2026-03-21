// dateISO = ISO 8601, ex: 2026-03-15T14:00
// contrainte : date future
class Meeting {
  final String id;      // TEXT PK
  final String groupId; // TEXT FK → Group
  final String dateISO; // TEXT NOT NULL — format ISO 8601
  final String topic;   // TEXT NOT NULL

  const Meeting({
    required this.id,
    required this.groupId,
    required this.dateISO,
    required this.topic,
  });

  // Retourne true si la réunion est dans le futur
  bool isFuture() {
    return DateTime.parse(dateISO).isAfter(DateTime.now());
  }

  // Retourne la date formatée dd/MM/yyyy HH:mm
  String getFormattedDate() {
    final dt = DateTime.parse(dateISO);
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() => {
    'id':      id,
    'groupId': groupId,
    'dateISO': dateISO,
    'topic':   topic,
  };

  factory Meeting.fromMap(Map<String, dynamic> m) => Meeting(
    id:      m['id']      as String,
    groupId: m['groupId'] as String,
    dateISO: m['dateISO'] as String,
    topic:   m['topic']   as String,
  );
}