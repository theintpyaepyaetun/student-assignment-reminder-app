import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:student_assignment_reminder_app/models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ============ CREATE ============

  /// Create a new task for the current user
  /// Returns the task ID if successful
  Future<String> createTask({
    required String title,
    required String description,
    required DateTime dueDate,
    String? category,
    int? priority,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final taskRef = await _firestore.collection('assignments').add({
        'userId': userId,
        'title': title,
        'description': description,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'deadline': dueDate,
        'category': category,
        'priority': priority,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Task created: ${taskRef.id}');
      return taskRef.id;
    } catch (e) {
      debugPrint('❌ Error creating task: $e');
      rethrow;
    }
  }

  // ============ READ ============

  /// Get a single task by ID (with permission check)
  Future<Task?> getTaskById(String taskId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final doc = await _firestore.collection('assignments').doc(taskId).get();

      if (!doc.exists) {
        debugPrint('⚠️ Task not found: $taskId');
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Security check: Verify user owns this task
      if (data['userId'] != userId) {
        throw Exception('Permission denied: Task does not belong to this user');
      }

      return Task.fromMap(data, doc.id);
    } catch (e) {
      debugPrint('❌ Error getting task: $e');
      rethrow;
    }
  }

  /// Get all tasks for the current user
  Future<List<Task>> getAllTasks() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('assignments')
          .where('userId', isEqualTo: userId)
          .get();

      final tasks = snapshot.docs.map((doc) {
        return Task.fromMap(doc.data(), doc.id);
      }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      debugPrint('✅ Retrieved ${tasks.length} tasks');
      return tasks;
    } catch (e) {
      debugPrint('❌ Error getting tasks: $e');
      rethrow;
    }
  }

  /// Get tasks by category
  Future<List<Task>> getTasksByCategory(String category) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('assignments')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: category)
          .get();

      final tasks = snapshot.docs.map((doc) {
        return Task.fromMap(doc.data(), doc.id);
      }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      return tasks;
    } catch (e) {
      debugPrint('❌ Error getting tasks by category: $e');
      rethrow;
    }
  }

  /// Get incomplete tasks
  Future<List<Task>> getIncompleteTasks() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('assignments')
          .where('userId', isEqualTo: userId)
          .where('completed', isEqualTo: false)
          .get();

      final tasks = snapshot.docs.map((doc) {
        return Task.fromMap(doc.data(), doc.id);
      }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      return tasks;
    } catch (e) {
      debugPrint('❌ Error getting incomplete tasks: $e');
      rethrow;
    }
  }

  /// Get completed tasks
  Future<List<Task>> getCompletedTasks() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('assignments')
          .where('userId', isEqualTo: userId)
          .where('completed', isEqualTo: true)
          .get();

      final tasks = snapshot.docs.map((doc) {
        return Task.fromMap(doc.data(), doc.id);
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return tasks;
    } catch (e) {
      debugPrint('❌ Error getting completed tasks: $e');
      rethrow;
    }
  }

  /// Stream all tasks for the current user (real-time updates)
  Stream<List<Task>> streamAllTasks() {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      return _firestore
          .collection('assignments')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
            final tasks = snapshot.docs.map((doc) {
              return Task.fromMap(doc.data(), doc.id);
            }).toList();

            tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            return tasks;
          });
    } catch (e) {
      debugPrint('❌ Error streaming tasks: $e');
      rethrow;
    }
  }

  /// Stream incomplete tasks (real-time updates)
  Stream<List<Task>> streamIncompleteTasks() {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      return _firestore
          .collection('assignments')
          .where('userId', isEqualTo: userId)
          .where('completed', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            final tasks = snapshot.docs.map((doc) {
              return Task.fromMap(doc.data(), doc.id);
            }).toList();

            tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            return tasks;
          });
    } catch (e) {
      debugPrint('❌ Error streaming incomplete tasks: $e');
      rethrow;
    }
  }

  // ============ UPDATE ============

  /// Update a task
  Future<void> updateTask(String taskId, Task task) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      if (task.userId != userId) {
        throw Exception(
          'Permission denied: Cannot update task of another user',
        );
      }

      await _firestore.collection('assignments').doc(taskId).update({
        'title': task.title,
        'description': task.description,
        'completed': task.isCompleted,
        'deadline': task.dueDate,
        'category': task.category,
        'priority': task.priority,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Task updated: $taskId');
    } catch (e) {
      debugPrint('❌ Error updating task: $e');
      rethrow;
    }
  }

  /// Mark a task as completed
  Future<void> completeTask(String taskId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      final task = await getTaskById(taskId);
      if (task == null || task.userId != userId) {
        throw Exception('Permission denied');
      }

      await _firestore.collection('assignments').doc(taskId).update({
        'completed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Task completed: $taskId');
    } catch (e) {
      debugPrint('❌ Error completing task: $e');
      rethrow;
    }
  }

  /// Mark a task as incomplete
  Future<void> incompleteTask(String taskId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      final task = await getTaskById(taskId);
      if (task == null || task.userId != userId) {
        throw Exception('Permission denied');
      }

      await _firestore.collection('assignments').doc(taskId).update({
        'completed': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Task marked incomplete: $taskId');
    } catch (e) {
      debugPrint('❌ Error marking task incomplete: $e');
      rethrow;
    }
  }

  // ============ DELETE ============

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      final task = await getTaskById(taskId);
      if (task == null || task.userId != userId) {
        throw Exception(
          'Permission denied: Cannot delete task of another user',
        );
      }

      await _firestore.collection('assignments').doc(taskId).delete();

      debugPrint('✅ Task deleted: $taskId');
    } catch (e) {
      debugPrint('❌ Error deleting task: $e');
      rethrow;
    }
  }

  /// Delete all completed tasks for the current user
  Future<void> deleteCompletedTasks() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('assignments')
          .where('userId', isEqualTo: userId)
          .where('completed', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('✅ All completed tasks deleted');
    } catch (e) {
      debugPrint('❌ Error deleting completed tasks: $e');
      rethrow;
    }
  }

  // ============ BATCH OPERATIONS ============

  /// Batch delete multiple tasks
  Future<void> deleteMultipleTasks(List<String> taskIds) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final batch = _firestore.batch();

      for (var taskId in taskIds) {
        final task = await getTaskById(taskId);
        if (task != null && task.userId == userId) {
          batch.delete(_firestore.collection('assignments').doc(taskId));
        }
      }

      await batch.commit();
      debugPrint('✅ ${taskIds.length} tasks deleted');
    } catch (e) {
      debugPrint('❌ Error batch deleting tasks: $e');
      rethrow;
    }
  }

  /// Batch mark tasks as completed
  Future<void> completeMultipleTasks(List<String> taskIds) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final batch = _firestore.batch();

      for (var taskId in taskIds) {
        final task = await getTaskById(taskId);
        if (task != null && task.userId == userId) {
          batch.update(_firestore.collection('assignments').doc(taskId), {
            'completed': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      debugPrint('✅ ${taskIds.length} tasks marked completed');
    } catch (e) {
      debugPrint('❌ Error batch completing tasks: $e');
      rethrow;
    }
  }

  // ============ STATISTICS ============

  /// Get task statistics for the current user
  Future<Map<String, int>> getTaskStats() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final allTasks = await getAllTasks();

      final total = allTasks.length;
      final completed = allTasks.where((task) => task.isCompleted).length;
      final pending = total - completed;

      return {'total': total, 'completed': completed, 'pending': pending};
    } catch (e) {
      debugPrint('❌ Error getting task stats: $e');
      rethrow;
    }
  }

  /// Get high priority incomplete tasks
  Future<List<Task>> getHighPriorityTasks() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final tasks = await getAllTasks();

      return tasks
          .where((task) => !task.isCompleted && (task.priority ?? 0) >= 3)
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } catch (e) {
      debugPrint('❌ Error getting high priority tasks: $e');
      rethrow;
    }
  }
}
