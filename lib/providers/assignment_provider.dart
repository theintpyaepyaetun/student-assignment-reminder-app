import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:student_assignment_reminder_app/models/assignment_model.dart';
import 'package:student_assignment_reminder_app/services/firebase_service.dart';

class AssignmentProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<Assignment> _assignments = [];
  bool _isLoading = false;
  String? _error;

  AssignmentProvider() {
    _setupRealtimeListener();
  }

  List<Assignment> get assignments => _assignments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setupRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firebaseService.getAssignmentsStream(user.uid).listen((event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map?;
          final assignments = <Assignment>[];

          if (data != null) {
            data.forEach((key, value) {
              if (value is Map) {
                try {
                  assignments.add(
                    Assignment(
                      id: key,
                      title: value['title'] ?? '',
                      description: value['description'] ?? '',
                      dueDate: value['dueDate'] ?? '',
                      priority: value['priority'] ?? 'medium',
                      status: value['status'] ?? 'pending',
                      createdAt:
                          value['createdAt'] ??
                          DateTime.now().toIso8601String(),
                      completed: value['completed'] ?? false,
                    ),
                  );
                } catch (e) {
                  print('Error parsing assignment: $e');
                }
              }
            });
          }

          _assignments = assignments;
          _error = null;
          notifyListeners();
        }
      });
    }
  }

  Future<void> loadAssignments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final assignmentsData = await _firebaseService.getAssignments(user.uid);
        _assignments = assignmentsData
            .map(
              (data) => Assignment(
                id: data['id'] ?? '',
                title: data['title'] ?? '',
                description: data['description'] ?? '',
                dueDate: data['dueDate'] ?? '',
                priority: data['priority'] ?? 'medium',
                status: data['status'] ?? 'pending',
                createdAt:
                    data['createdAt'] ?? DateTime.now().toIso8601String(),
                completed: data['completed'] ?? false,
              ),
            )
            .toList();
      }
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        notifyListeners();
        return false;
      }

      final assignmentId = DateTime.now().millisecondsSinceEpoch.toString();
      final assignmentData = {
        'title': title,
        'description': description,
        'dueDate': dueDate,
        'priority': priority,
        'status': 'pending',
        'completed': false,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _firebaseService.saveAssignment(
        userId: user.uid,
        assignmentId: assignmentId,
        assignmentData: assignmentData,
      );

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
    bool? completed,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        notifyListeners();
        return false;
      }

      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (dueDate != null) updates['dueDate'] = dueDate;
      if (priority != null) updates['priority'] = priority;
      if (status != null) updates['status'] = status;
      if (completed != null) updates['completed'] = completed;

      await _firebaseService.updateAssignment(
        userId: user.uid,
        assignmentId: id,
        updates: updates,
      );

      return true;
    } catch (e) {
      _error = 'Failed to update assignment: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAssignment(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        notifyListeners();
        return false;
      }

      await _firebaseService.deleteAssignment(
        userId: user.uid,
        assignmentId: id,
      );

      return true;
    } catch (e) {
      _error = 'Failed to delete assignment: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  List<Assignment> get completedAssignments =>
      _assignments.where((a) => a.completed).toList();

  List<Assignment> get pendingAssignments =>
      _assignments.where((a) => !a.completed && !a.isOverdue).toList();

  List<Assignment> get overdueAssignments =>
      _assignments.where((a) => a.isOverdue).toList();
}
