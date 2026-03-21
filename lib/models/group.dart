class Group {
  final String id;
  final String name;
  final String code;
  final String adminId; // ID du créateur (admin)

  const Group({
    required this.id,
    required this.name,
    required this.code,
    required this.adminId,
  });

  static String generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng   = DateTime.now().microsecondsSinceEpoch;
    return List.generate(6, (i) => chars[(rng ~/ (i + 1)) % chars.length])
        .join();
  }

  Map<String, dynamic> toMap() => {
    'id':      id,
    'name':    name,
    'code':    code,
    'adminId': adminId,
  };

  factory Group.fromMap(Map<String, dynamic> m) => Group(
    id:      m['id']      as String,
    name:    m['name']    as String,
    code:    m['code']    as String,
    adminId: m['adminId'] as String? ?? '',
  );

  @override
  String toString() => 'Group(id: $id, name: $name, code: $code)';
}