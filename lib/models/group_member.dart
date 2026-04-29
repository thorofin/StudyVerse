enum MemberRole { admin, student }
class GroupMember {
  final String     groupId;
  final String     userId;
  final MemberRole role; // admin = créateur, student = rejoint via code

  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'userId':  userId,
    'role':    role.name, // 'admin' ou 'student'
  };

  factory GroupMember.fromMap(Map<String, dynamic> m) => GroupMember(
    groupId: m['groupId'] as String,
    userId:  m['userId']  as String,
    role:    m['role'] == 'admin'
        ? MemberRole.admin
        : MemberRole.student,
  );
}

