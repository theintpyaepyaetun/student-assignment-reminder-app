import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:student_assignment_reminder_app/models/assignment_model.dart';
import 'package:student_assignment_reminder_app/models/user_model.dart';
import 'package:student_assignment_reminder_app/config/api_config.dart';
import 'token_storage_service.dart';

class ApiService {
  final TokenStorageService tokenStorage;

  ApiService({required this.tokenStorage});

  String get baseUrl => ApiConfig.baseUrl;

  // Auth Endpoints
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await tokenStorage.saveToken(data['token']);
        await tokenStorage.saveUserInfo(email, name);
        return {'success': true, 'message': data['message']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await tokenStorage.saveToken(data['token']);
        await tokenStorage.saveUserInfo(email, data['name']);
        return {
          'success': true,
          'message': data['message'],
          'user': User.fromJson(data['user'] ?? {'email': email, 'name': data['name']})
        };
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Assignment Endpoints
  Future<List<Assignment>> getAssignments() async {
    try {
      final token = await tokenStorage.getToken();
      if (token == null) {
        throw Exception('No auth token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/assignments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Assignment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load assignments');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Assignment> getAssignment(String id) async {
    try {
      final token = await tokenStorage.getToken();
      if (token == null) {
        throw Exception('No auth token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/assignments/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Assignment.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load assignment');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Assignment> createAssignment({
    required String title,
    required String description,
    required String dueDate,
    required String priority,
  }) async {
    try {
      final token = await tokenStorage.getToken();
      if (token == null) {
        throw Exception('No auth token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/assignments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'due_date': dueDate,
          'priority': priority,
        }),
      );

      if (response.statusCode == 201) {
        return Assignment.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create assignment');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> updateAssignment({
    required String id,
    String? title,
    String? description,
    String? dueDate,
    String? priority,
    String? status,
  }) async {
    try {
      final token = await tokenStorage.getToken();
      if (token == null) {
        throw Exception('No auth token found');
      }

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (dueDate != null) body['due_date'] = dueDate;
      if (priority != null) body['priority'] = priority;
      if (status != null) body['status'] = status;

      final response = await http.put(
        Uri.parse('$baseUrl/assignments/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update assignment');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> deleteAssignment(String id) async {
    try {
      final token = await tokenStorage.getToken();
      if (token == null) {
        throw Exception('No auth token found');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/assignments/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete assignment');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // User Endpoints
  Future<User> getUserProfile() async {
    try {
      final token = await tokenStorage.getToken();
      if (token == null) {
        throw Exception('No auth token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> logout() async {
    await tokenStorage.clear();
  }
}
