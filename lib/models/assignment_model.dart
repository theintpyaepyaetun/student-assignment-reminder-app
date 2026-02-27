class Assignment {
  final String id;
  final String title;
  final String description;
  final String dueDate;
  final String priority;
  final String status;
  final String createdAt;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.createdAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      dueDate: json['due_date'] as String,
      priority: json['priority'] as String? ?? 'MEDIUM',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate,
      'priority': priority,
      'status': status,
      'created_at': createdAt,
    };
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isOverdue => status == 'OVERDUE';
  bool get isHighPriority => priority == 'HIGH';
  bool get isMediumPriority => priority == 'MEDIUM';
  bool get isLowPriority => priority == 'LOW';

  @override
  String toString() => 'Assignment(id: $id, title: $title, status: $status)';
}
