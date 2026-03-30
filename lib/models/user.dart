class User {
  final String id;
  final String name;
  final String email;

  const User({
    required this.id,
    required this.name,
    required this.email,
  });

  Map<String, dynamic> toMap() => {
        'id':    id,
        'name':  name,
        'email': email,
      };

  factory User.fromMap(Map<String, dynamic> m) => User(
        id:    m['id']    as String,
        name:  m['name']  as String,
        email: m['email'] as String? ?? '',
      );

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}