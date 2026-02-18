import 'package:flutter/material.dart';

class AssignmentCard extends StatelessWidget {
  final String title;
  final String dueDate;
  final bool isCompleted;

  const AssignmentCard({
    super.key,
    required this.title,
    required this.dueDate,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: ListTile(
        title: Text(title),
        subtitle: Text("Due: $dueDate"),
        trailing: Icon(
          isCompleted ? Icons.check_circle : Icons.access_time,
          color: isCompleted ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
