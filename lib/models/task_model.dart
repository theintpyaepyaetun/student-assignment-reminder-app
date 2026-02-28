class Task {
  final String id;
  final String userId;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime dueDate;
  final String? category;
  final int? priority; // 1 = Low, 2 = Medium, 3 = High

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.isCompleted = false,
    required this.createdAt,
    required this.dueDate,
    this.category,
    this.priority,
  });

  // Convert Task to Firestore JSON
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'dueDate': dueDate,
      'category': category,
      'priority': priority,
      'updatedAt': DateTime.now(),
    };
  }

  // Create Task from Firestore document
  factory Task.fromMap(Map<String, dynamic> map, String id) {
    // Handle both 'dueDate' and 'deadline' field names
    final dueDateField = map['dueDate'] ?? map['deadline'];

    return Task(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isCompleted: (map['isCompleted'] ?? map['completed'] ?? false) as bool,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      dueDate: (dueDateField as dynamic)?.toDate() ?? DateTime.now(),
      category: map['category'] as String?,
      priority: map['priority'] as int?,
    );
  }

  // Create a copy with modified fields
  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    String? category,
    int? priority,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      priority: priority ?? this.priority,
    );
  }

  @override
  String toString() =>
      'Task(id: $id, userId: $userId, title: $title, isCompleted: $isCompleted)';
}
