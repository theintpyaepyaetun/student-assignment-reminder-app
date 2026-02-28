import 'package:flutter/foundation.dart';
import 'package:student_assignment_reminder_app/models/task_model.dart';
import 'package:student_assignment_reminder_app/services/task_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();

  List<Task> _allTasks = [];
  List<Task> _incompleteTasks = [];
  Map<String, int> _taskStats = {'total': 0, 'completed': 0, 'pending': 0};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Task> get allTasks => _allTasks;
  List<Task> get incompleteTasks => _incompleteTasks;
  Map<String, int> get taskStats => _taskStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ============ CREATE ============

  Future<String?> createTask({
    required String title,
    required String description,
    required DateTime dueDate,
    String? category,
    int? priority,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final taskId = await _taskService.createTask(
        title: title,
        description: description,
        dueDate: dueDate,
        category: category,
        priority: priority,
      );

      // Refresh tasks
      await refreshAllTasks();
      return taskId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ READ ============

  Future<void> refreshAllTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allTasks = await _taskService.getAllTasks();
      _incompleteTasks = await _taskService.getIncompleteTasks();
      _taskStats = await _taskService.getTaskStats();
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> loadTaskStats() async {
    try {
      _taskStats = await _taskService.getTaskStats();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<List<Task>> getTasksByCategory(String category) async {
    try {
      return await _taskService.getTasksByCategory(category);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<Task>> getHighPriorityTasks() async {
    try {
      return await _taskService.getHighPriorityTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // ============ UPDATE ============

  Future<void> updateTask(String taskId, Task task) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _taskService.updateTask(taskId, task);
      await refreshAllTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeTask(String taskId) async {
    try {
      await _taskService.completeTask(taskId);
      await refreshAllTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> incompleteTask(String taskId) async {
    try {
      await _taskService.incompleteTask(taskId);
      await refreshAllTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============ DELETE ============

  Future<void> deleteTask(String taskId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _taskService.deleteTask(taskId);
      await refreshAllTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCompletedTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _taskService.deleteCompletedTasks();
      await refreshAllTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMultipleTasks(List<String> taskIds) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _taskService.deleteMultipleTasks(taskIds);
      await refreshAllTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ BATCH OPERATIONS ============

  Future<void> completeMultipleTasks(List<String> taskIds) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _taskService.completeMultipleTasks(taskIds);
      await refreshAllTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
