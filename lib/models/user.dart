class User {
  final String id;   // TEXT PK
  final String name; // TEXT NOT NULL

  const User({required this.id, required this.name});

  Map<String, dynamic> toMap() => {
    'id':   id,
    'name': name,
  };

  factory User.fromMap(Map<String, dynamic> m) => User(
    id:   m['id']   as String,
    name: m['name'] as String,
  );

  @override
  String toString() => 'User(id: $id, name: $name)';
}