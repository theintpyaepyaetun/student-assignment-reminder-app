import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_assignment_reminder_app/providers/task_provider.dart';
import 'package:student_assignment_reminder_app/models/task_model.dart';

/// Complete CRUD Demo Screen
/// Demonstrates all Create, Read, Update, Delete operations with user-specific data
class CRUDDemoScreen extends StatefulWidget {
  const CRUDDemoScreen({Key? key}) : super(key: key);

  @override
  State<CRUDDemoScreen> createState() => _CRUDDemoScreenState();
}

class _CRUDDemoScreenState extends State<CRUDDemoScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: 7));

    // Load all tasks when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().refreshAllTasks();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ============ CREATE ============
  void _createTask() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    final taskId = await context.read<TaskProvider>().createTask(
      title: _titleController.text,
      description: _descriptionController.text,
      dueDate: _selectedDate,
      category: 'General',
      priority: 2,
    );

    if (taskId != null) {
      _titleController.clear();
      _descriptionController.clear();
      _selectedDate = DateTime.now().add(const Duration(days: 7));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Task created: $taskId')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Failed to create task')));
    }
  }

  // ============ READ ============
  void _readAllTasks() {
    context.read<TaskProvider>().refreshAllTasks();
  }

  void _readIncompleteTasks() {
    // This is already in TaskProvider
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📖 Reading incomplete tasks...')),
    );
  }

  // ============ UPDATE ============
  void _updateTask(Task task) {
    final updatedTask = task.copyWith(
      title: '${task.title} [UPDATED]',
      isCompleted: !task.isCompleted,
    );

    context.read<TaskProvider>().updateTask(task.id, updatedTask);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ Task updated')));
  }

  // ============ DELETE ============
  void _deleteTask(String taskId) {
    context.read<TaskProvider>().deleteTask(taskId);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ Task deleted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User-Specific CRUD Demo'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============ CREATE SECTION ============
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📝 CREATE - Add New Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: 'Task title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              hintText: 'Task description',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Due: ${_selectedDate.toString().split(' ')[0]}',
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );
                                  if (date != null) {
                                    setState(() => _selectedDate = date);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: const Text('Change'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: taskProvider.isLoading
                                ? null
                                : _createTask,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ============ READ SECTION ============
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📖 READ - View All Tasks',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _readAllTasks,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh All'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _readIncompleteTasks,
                                icon: const Icon(Icons.filter_alt),
                                label: const Text('Incomplete'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Total Tasks: ${taskProvider.allTasks.length}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Completed: ${taskProvider.taskStats['completed'] ?? 0}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Pending: ${taskProvider.taskStats['pending'] ?? 0}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ============ TASKS LIST (with UPDATE & DELETE) ============
                  const Text(
                    '✏️ UPDATE & 🗑️ DELETE - Task Management',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (taskProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (taskProvider.allTasks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: const [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No tasks yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: taskProvider.allTasks.length,
                      itemBuilder: (context, index) {
                        final task = taskProvider.allTasks[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              task.title,
                              style: TextStyle(
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(task.description),
                                const SizedBox(height: 4),
                                Text(
                                  'Due: ${task.dueDate.toString().split(' ')[0]}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Category: ${task.category ?? 'N/A'} | Priority: ${task.priority ?? 0}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Text('✏️ Update'),
                                  onTap: () {
                                    _updateTask(task);
                                  },
                                ),
                                PopupMenuItem(
                                  child: const Text('🗑️ Delete'),
                                  onTap: () {
                                    _deleteTask(task.id);
                                  },
                                ),
                              ],
                            ),
                            leading: Checkbox(
                              value: task.isCompleted,
                              onChanged: (value) => _updateTask(task),
                            ),
                          ),
                        );
                      },
                    ),

                  if (taskProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '❌ Error: ${taskProvider.error}',
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
