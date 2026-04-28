// type + AI metadata. Fully backward-compatible with Firestore.

enum ResourceType { url, pdf }

class Resource {
  final String id;       // Firestore doc ID
  final String groupId;  // FK → Group (team's schema)
  final String title;    // display name
  final String url;      // URL or Firebase Storage download URL

  // ── Hirri additions (optional, backward-compatible) ──────
  final ResourceType type;
  final int?         sizeBytes;
  final String?      extractedText;

  const Resource({
    required this.id,
    required this.groupId,
    required this.title,
    required this.url,
    this.type = ResourceType.url,
    this.sizeBytes,
    this.extractedText,
  });

  bool isUrl() {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  bool get isPdf => type == ResourceType.pdf;

  String get displaySize {
    if (sizeBytes == null) return '';
    if (sizeBytes! < 1024) return '${sizeBytes}B';
    if (sizeBytes! < 1024 * 1024) return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() => {
    'id':            id,
    'groupId':       groupId,
    'title':         title,
    'url':           url,
    'type':          type.name,
    'sizeBytes':     sizeBytes,
    'extractedText': extractedText,
  };

  factory Resource.fromMap(Map<String, dynamic> m) => Resource(
    id:      m['id']      as String,
    groupId: m['groupId'] as String,
    title:   m['title']   as String,
    url:     m['url']     as String,
    type: ResourceType.values.firstWhere(
          (e) => e.name == (m['type'] as String? ?? 'url'),
      orElse: () => ResourceType.url,
    ),
    sizeBytes:     m['sizeBytes']     as int?,
    extractedText: m['extractedText'] as String?,
  );

  Resource copyWith({String? extractedText, int? sizeBytes}) => Resource(
    id:            id,
    groupId:       groupId,
    title:         title,
    url:           url,
    type:          type,
    sizeBytes:     sizeBytes     ?? this.sizeBytes,
    extractedText: extractedText ?? this.extractedText,
  );
}

// AIChatMessage — local only, not stored in Firestore
class AIChatMessage {
  final String   id;
  final String   content;
  final bool     isUser;
  final DateTime timestamp;
  final bool     isLoading;

  const AIChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });

  AIChatMessage copyWith({String? content, bool? isLoading}) => AIChatMessage(
    id:        id,
    content:   content   ?? this.content,
    isUser:    isUser,
    timestamp: timestamp,
    isLoading: isLoading ?? this.isLoading,
  );
}