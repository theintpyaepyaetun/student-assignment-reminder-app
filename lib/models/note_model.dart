class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final bool isPinned;
  final String? color;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.isPinned = false,
    this.color,
  });

  // Convert Note to Firestore JSON
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'tags': tags,
      'isPinned': isPinned,
      'color': color,
    };
  }

  // Create Note from Firestore document
  factory Note.fromMap(Map<String, dynamic> map, String id) {
    return Note(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      tags: List<String>.from(map['tags'] as List<dynamic>? ?? []),
      isPinned: map['isPinned'] as bool? ?? false,
      color: map['color'] as String?,
    );
  }

  // Create a copy with modified fields
  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPinned,
    String? color,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      color: color ?? this.color,
    );
  }

  @override
  String toString() => 'Note(id: $id, userId: $userId, title: $title)';
}
