import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_assignment_screen.dart';
import 'settings_screen.dart';
import 'detail_screen.dart';
import 'providers/assignment_provider.dart';
import 'providers/auth_provider.dart';
import 'services/firebase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> assignments = [
    {
      "title": "Math Homework",
      "deadline": "Feb 25",
      "completed": false,
      "description": "Complete exercises 1-50 from Chapter 5",
      "priority": "high",
    },
    {
      "title": "English Essay",
      "deadline": "Mar 1",
      "completed": true,
      "description": "Write a 2000-word essay on Shakespeare's influence",
      "priority": "medium",
    },
    {
      "title": "Mobile App Project",
      "deadline": "Mar 10",
      "completed": false,
      "description": "Build a Flutter app following the design requirements",
      "priority": "high",
    },
    {
      "title": "History Presentation",
      "deadline": "Feb 28",
      "completed": false,
      "description": "Prepare 15-20 slides about the Industrial Revolution",
      "priority": "medium",
    },
  ];

  void addAssignment(Map<String, dynamic> assignment) {
    // Save to Firestore first to get document ID
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        debugPrint('📝 Saving assignment to Firestore for user: $userId');

        // Add userId and timestamps
        final assignmentData = {
          ...assignment,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Save to Firestore 'assignments' collection
        FirebaseFirestore.instance
            .collection('assignments')
            .add(assignmentData)
            .then((docRef) {
              debugPrint(
                '✅ Assignment created in Firestore with ID: ${docRef.id}',
              );
              // Update local state with the document ID
              setState(() {
                assignment['id'] = docRef.id;
                assignments.add(assignment);
              });
            })
            .catchError((e) {
              debugPrint('❌ Error saving to Firestore: $e');
              // Still add to local state even if Firebase fails
              setState(() {
                assignments.add(assignment);
              });
            });
      } else {
        debugPrint('⚠️ No user authenticated - assignment NOT saved');
        setState(() {
          assignments.add(assignment);
        });
      }
    } catch (e) {
      debugPrint('❌ Firestore save error: $e');
      setState(() {
        assignments.add(assignment);
      });
    }
  }

  void updateAssignment(int index, Map<String, dynamic> assignment) {
    setState(() {
      assignments[index] = assignment;
    });

    // Update in Firestore
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final docId = assignment['id'];

      if (userId != null && docId != null) {
        debugPrint('✏️ Updating assignment in Firestore: $docId');

        final assignmentData = {
          ...assignment,
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        // Remove the 'id' field from the data being saved
        assignmentData.remove('id');

        FirebaseFirestore.instance
            .collection('assignments')
            .doc(docId)
            .update(assignmentData)
            .then((_) {
              debugPrint('✅ Assignment updated in Firestore: $docId');
            })
            .catchError((e) {
              debugPrint('❌ Error updating in Firestore: $e');
            });
      } else {
        debugPrint(
          '⚠️ No document ID found - assignment not synced to Firestore',
        );
      }
    } catch (e) {
      debugPrint('❌ Firestore update error: $e');
    }
  }

  void deleteAssignment(int index) {
    // Delete from Firestore
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final docId = assignments[index]['id'];

      if (userId != null && docId != null) {
        debugPrint('🗑️ Deleting assignment from Firestore: $docId');

        FirebaseFirestore.instance
            .collection('assignments')
            .doc(docId)
            .delete()
            .then((_) {
              debugPrint('✅ Assignment deleted from Firestore: $docId');
            })
            .catchError((e) {
              debugPrint('❌ Error deleting from Firestore: $e');
            });
      } else {
        debugPrint(
          '⚠️ No document ID found - assignment not deleted from Firestore',
        );
      }
    } catch (e) {
      debugPrint('❌ Firestore delete error: $e');
    }

    // Remove from local state
    setState(() {
      assignments.removeAt(index);
    });
  }

  void toggleComplete(int index) {
    setState(() {
      assignments[index]["completed"] = !assignments[index]["completed"];
    });

    // Update completion status in Firestore
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final docId = assignments[index]['id'];
      final completed = assignments[index]["completed"];

      if (userId != null && docId != null) {
        debugPrint('✓ Updating completion status in Firestore: $docId');

        FirebaseFirestore.instance
            .collection('assignments')
            .doc(docId)
            .update({
              'completed': completed,
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .then((_) {
              debugPrint('✅ Completion status updated in Firestore: $docId');
            })
            .catchError((e) {
              debugPrint('❌ Error updating completion in Firestore: $e');
            });
      }
    } catch (e) {
      debugPrint('❌ Firestore completion update error: $e');
    }
  }

  int get completedCount => assignments.where((a) => a["completed"]).length;
  int get pendingCount => assignments.where((a) => !a["completed"]).length;
  int get overdueCount => 1; // Mock value for demonstration

  @override
  void initState() {
    super.initState();
    // Load assignments from backend after first frame to safely access context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AssignmentProvider>().loadAssignments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Assignments",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, size: 24),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Content
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 120),

                // Demo mode banner
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isDemoMode) {
                      return Container(
                        width: double.infinity,
                        color: Colors.yellow.withOpacity(0.9),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: const Text(
                          'Demo mode active – no Firebase configuration found',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Status Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildStatusChip(
                        label: "Completed",
                        count: completedCount,
                        icon: Icons.check_circle,
                        color: const Color(0xFF00C851),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusChip(
                        label: "Pending",
                        count: pendingCount,
                        icon: Icons.pending_actions,
                        color: const Color(0xFFFF9100),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusChip(
                        label: "Overdue",
                        count: overdueCount,
                        icon: Icons.warning,
                        color: const Color(0xFFEF5350),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Assignments List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: assignments.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: assignments.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildAssignmentCard(
                                context,
                                index,
                                assignments[index],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AssignmentScreen()),
          );

          if (result != null) {
            addAssignment(result);
          }
        },
        backgroundColor: Colors.white.withOpacity(0.25),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Icon(Icons.add, color: Colors.white.withOpacity(0.9), size: 28),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 6),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(
    BuildContext context,
    int index,
    Map<String, dynamic> assignment,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(
                  assignment: assignment,
                  index: index,
                  onUpdate: updateAssignment,
                  onDelete: deleteAssignment,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () => toggleComplete(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                      color: assignment["completed"]
                          ? const Color(0xFF00C851)
                          : Colors.transparent,
                    ),
                    child: assignment["completed"]
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment["title"],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: assignment["completed"]
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Due: ${assignment['deadline']}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Priority Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: assignment["priority"] == "high"
                        ? const Color(0xFFEF5350).withOpacity(0.3)
                        : const Color(0xFFFF9100).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: assignment["priority"] == "high"
                          ? const Color(0xFFEF5350).withOpacity(0.5)
                          : const Color(0xFFFF9100).withOpacity(0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    assignment["priority"] == "high" ? "High" : "Medium",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No Assignments Yet",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the + button to add your first assignment",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
