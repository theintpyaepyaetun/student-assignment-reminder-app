import 'package:flutter/material.dart';
import 'package:student_assignment_reminder_app/models/assignment_model.dart';
import 'package:student_assignment_reminder_app/services/api_service.dart';
import 'package:student_assignment_reminder_app/services/token_storage_service.dart';

class AssignmentProvider extends ChangeNotifier {
  late ApiService _apiService;
  List<Assignment> _assignments = [];
  bool _isLoading = false;
  String? _error;

  AssignmentProvider() {
    _apiService = ApiService(tokenStorage: TokenStorageService());
  }

  List<Assignment> get assignments => _assignments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAssignments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _assignments = await _apiService.getAssignments();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load assignments: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAssignment({
    required String title,
    required String description,
    required String dueDate,
    required String priority,
  }) async {
    try {
      final assignment = await _apiService.createAssignment(
        title: title,
        description: description,
        dueDate: dueDate,
        priority: priority,
      );
      _assignments.add(assignment);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to create assignment: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAssignment({
    required String id,
    String? title,
    String? description,
    String? dueDate,
    String? priority,
    String? status,
  }) async {
    try {
      await _apiService.updateAssignment(
        id: id,
        title: title,
        description: description,
        dueDate: dueDate,
        priority: priority,
        status: status,
      );

      // Update locally
      final index = _assignments.indexWhere((a) => a.id == id);
      if (index != -1) {
        final assignment = _assignments[index];
        _assignments[index] = Assignment(
          id: assignment.id,
          title: title ?? assignment.title,
          description: description ?? assignment.description,
          dueDate: dueDate ?? assignment.dueDate,
          priority: priority ?? assignment.priority,
          status: status ?? assignment.status,
          createdAt: assignment.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update assignment: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAssignment(String id) async {
    try {
      await _apiService.deleteAssignment(id);
      _assignments.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete assignment: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  List<Assignment> get completedAssignments =>
      _assignments.where((a) => a.isCompleted).toList();

  List<Assignment> get pendingAssignments =>
      _assignments.where((a) => !a.isCompleted && !a.isOverdue).toList();

  List<Assignment> get overdueAssignments =>
      _assignments.where((a) => a.isOverdue).toList();
}
