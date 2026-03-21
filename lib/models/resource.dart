class Resource {
  final String id;      // TEXT PK
  final String groupId; // TEXT FK → Group
  final String title;   // TEXT NOT NULL
  final String url;     // TEXT NOT NULL

  const Resource({
    required this.id,
    required this.groupId,
    required this.title,
    required this.url,
  });

  // Vérifie si c'est une URL valide
  bool isUrl() {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  Map<String, dynamic> toMap() => {
    'id':      id,
    'groupId': groupId,
    'title':   title,
    'url':     url,
  };

  factory Resource.fromMap(Map<String, dynamic> m) => Resource(
    id:      m['id']      as String,
    groupId: m['groupId'] as String,
    title:   m['title']   as String,
    url:     m['url']     as String,
  );
}