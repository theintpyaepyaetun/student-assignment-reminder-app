import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:student_assignment_reminder_app/models/note_model.dart';

class NoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ============ CREATE ============

  Future<String> createNote({
    required String title,
    required String content,
    List<String>? tags,
    String? color,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final noteRef = await _firestore.collection('notes').add({
        'userId': userId,
        'title': title,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'tags': tags ?? [],
        'isPinned': false,
        'color': color,
      });

      debugPrint('✅ Note created: ${noteRef.id}');
      return noteRef.id;
    } catch (e) {
      debugPrint('❌ Error creating note: $e');
      rethrow;
    }
  }

  // ============ READ ============

  Future<Note?> getNoteById(String noteId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final doc = await _firestore.collection('notes').doc(noteId).get();

      if (!doc.exists) {
        debugPrint('⚠️ Note not found: $noteId');
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Security check: Verify user owns this note
      if (data['userId'] != userId) {
        throw Exception('Permission denied: Note does not belong to this user');
      }

      return Note.fromMap(data, doc.id);
    } catch (e) {
      debugPrint('❌ Error getting note: $e');
      rethrow;
    }
  }

  Future<List<Note>> getAllNotes() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .orderBy('isPinned', descending: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Note.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting notes: $e');
      rethrow;
    }
  }

  Future<List<Note>> getPinnedNotes() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .where('isPinned', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Note.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting pinned notes: $e');
      rethrow;
    }
  }

  Future<List<Note>> getNotesByTag(String tag) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .where('tags', arrayContains: tag)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Note.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting notes by tag: $e');
      rethrow;
    }
  }

  Stream<List<Note>> streamAllNotes() {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      return _firestore
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .orderBy('isPinned', descending: true)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return Note.fromMap(doc.data(), doc.id);
            }).toList();
          });
    } catch (e) {
      debugPrint('❌ Error streaming notes: $e');
      rethrow;
    }
  }

  // ============ UPDATE ============

  Future<void> updateNote(String noteId, Note note) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      if (note.userId != userId) {
        throw Exception(
          'Permission denied: Cannot update note of another user',
        );
      }

      await _firestore.collection('notes').doc(noteId).update({
        'title': note.title,
        'content': note.content,
        'tags': note.tags,
        'color': note.color,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Note updated: $noteId');
    } catch (e) {
      debugPrint('❌ Error updating note: $e');
      rethrow;
    }
  }

  Future<void> togglePinNote(String noteId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final note = await getNoteById(noteId);
      if (note == null || note.userId != userId) {
        throw Exception('Permission denied');
      }

      await _firestore.collection('notes').doc(noteId).update({
        'isPinned': !note.isPinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Note pinned toggled: $noteId');
    } catch (e) {
      debugPrint('❌ Error toggling pin: $e');
      rethrow;
    }
  }

  Future<void> addTagToNote(String noteId, String tag) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final note = await getNoteById(noteId);
      if (note == null || note.userId != userId) {
        throw Exception('Permission denied');
      }

      final updatedTags = [...note.tags, tag].toSet().toList();

      await _firestore.collection('notes').doc(noteId).update({
        'tags': updatedTags,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Tag added to note: $noteId');
    } catch (e) {
      debugPrint('❌ Error adding tag: $e');
      rethrow;
    }
  }

  Future<void> removeTagFromNote(String noteId, String tag) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final note = await getNoteById(noteId);
      if (note == null || note.userId != userId) {
        throw Exception('Permission denied');
      }

      final updatedTags = note.tags.where((t) => t != tag).toList();

      await _firestore.collection('notes').doc(noteId).update({
        'tags': updatedTags,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Tag removed from note: $noteId');
    } catch (e) {
      debugPrint('❌ Error removing tag: $e');
      rethrow;
    }
  }

  // ============ DELETE ============

  Future<void> deleteNote(String noteId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final note = await getNoteById(noteId);
      if (note == null || note.userId != userId) {
        throw Exception(
          'Permission denied: Cannot delete note of another user',
        );
      }

      await _firestore.collection('notes').doc(noteId).delete();

      debugPrint('✅ Note deleted: $noteId');
    } catch (e) {
      debugPrint('❌ Error deleting note: $e');
      rethrow;
    }
  }

  Future<void> deleteMultipleNotes(List<String> noteIds) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final batch = _firestore.batch();

      for (var noteId in noteIds) {
        final note = await getNoteById(noteId);
        if (note != null && note.userId == userId) {
          batch.delete(_firestore.collection('notes').doc(noteId));
        }
      }

      await batch.commit();
      debugPrint('✅ ${noteIds.length} notes deleted');
    } catch (e) {
      debugPrint('❌ Error batch deleting notes: $e');
      rethrow;
    }
  }
}
