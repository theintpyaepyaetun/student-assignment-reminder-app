import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_assignment_screen.dart';
import 'archive_screen.dart';
import 'settings_screen.dart';
import 'detail_screen.dart';
import 'providers/auth_provider.dart';
import 'services/assignment_notification_service.dart';

class HomeScreen extends StatefulWidget {
  final String? initialAssignmentId;

  const HomeScreen({super.key, this.initialAssignmentId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> assignments = [];
  bool _handledInitialAssignment = false;

  bool get _showEmptyStatePreview {
    return kDebugMode &&
        Uri.base.queryParameters['preview']?.toLowerCase() == 'empty';
  }

  Future<void> _openAddAssignmentScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AssignmentScreen()),
    );

    if (result != null) {
      addAssignment(result);
    }
  }

  double _contentTopPadding(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.padding.top + kToolbarHeight + 18;
  }

  Future<int> _clearAllCompletedAssignments() async {
    final completedAssignments = assignments
        .where((a) => a['completed'] == true)
        .toList(growable: false);
    if (completedAssignments.isEmpty) return 0;

    var removedCount = 0;
    for (final assignment in completedAssignments) {
      try {
        await AssignmentNotificationService.instance.cancelReminder(
          _assignmentNotificationKey(assignment),
        );
      } catch (_) {}

      final docId = assignment['id']?.toString();
      if (docId == null || docId.isEmpty) continue;

      try {
        await FirebaseFirestore.instance
            .collection('assignments')
            .doc(docId)
            .delete();
        removedCount += 1;
      } catch (e) {
        debugPrint('❌ Failed to delete archived assignment $docId: $e');
      }
    }

    if (!mounted) return removedCount;

    setState(() {
      assignments.removeWhere((a) => a['completed'] == true);
    });

    return removedCount;
  }

  void _openArchiveScreen() {
    final archivedAssignments = assignments
        .where((a) => a['completed'] == true)
        .map((a) => Map<String, dynamic>.from(a))
        .toList(growable: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveScreen(
          archivedAssignments: archivedAssignments,
          onClearAllHistory: _clearAllCompletedAssignments,
        ),
      ),
    );
  }

  void _openAssignmentDetailById(String assignmentId) {
    final index = assignments.indexWhere(
      (assignment) => assignment['id']?.toString() == assignmentId,
    );

    if (index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment from notification was not found.'),
        ),
      );
      return;
    }

    final assignment = assignments[index];
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
  }

  void _openInitialAssignmentIfNeeded() {
    if (_handledInitialAssignment) return;

    final assignmentId = widget.initialAssignmentId;
    if (assignmentId == null || assignmentId.isEmpty) return;

    _handledInitialAssignment = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openAssignmentDetailById(assignmentId);
    });
  }

  String _assignmentNotificationKey(Map<String, dynamic> assignment) {
    final id = assignment['id']?.toString();
    if (id != null && id.isNotEmpty) return id;

    final title = assignment['title']?.toString() ?? 'assignment';
    final deadline = assignment['deadline']?.toString() ?? '';
    return '$title|$deadline';
  }

  Future<void> _scheduleReminderForAssignment(
    Map<String, dynamic> assignment,
  ) async {
    final isCompleted = assignment['completed'] == true;
    if (isCompleted) {
      await AssignmentNotificationService.instance.cancelReminder(
        _assignmentNotificationKey(assignment),
      );
      return;
    }

    final title = assignment['title']?.toString() ?? '';
    if (title.isEmpty) return;

    final parsedDeadline = _parseDeadlineValue(assignment['deadline']);
    if (parsedDeadline == null) return;

    await AssignmentNotificationService.instance
        .scheduleOneDayBeforeDeadlineFromDate(
          assignmentId: _assignmentNotificationKey(assignment),
          title: title,
          deadlineDate: parsedDeadline,
        );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

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

              _scheduleReminderForAssignment(assignment);
            })
            .catchError((e) {
              debugPrint('❌ Error saving to Firestore: $e');
              // Still add to local state even if Firebase fails
              setState(() {
                assignments.add(assignment);
              });

              _scheduleReminderForAssignment(assignment);
            });
      } else {
        debugPrint('⚠️ No user authenticated - assignment NOT saved');
        setState(() {
          assignments.add(assignment);
        });

        _scheduleReminderForAssignment(assignment);
      }
    } catch (e) {
      debugPrint('❌ Firestore save error: $e');
      setState(() {
        assignments.add(assignment);
      });

      _scheduleReminderForAssignment(assignment);
    }
  }

  void updateAssignment(int index, Map<String, dynamic> assignment) {
    final oldAssignment = assignments[index];

    setState(() {
      assignments[index] = assignment;
    });

    final oldKey = _assignmentNotificationKey(oldAssignment);
    final newKey = _assignmentNotificationKey(assignment);

    if (oldKey != newKey) {
      AssignmentNotificationService.instance.cancelReminder(oldKey);
    }

    _scheduleReminderForAssignment(assignment);

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
    final assignment = assignments[index];
    AssignmentNotificationService.instance.cancelReminder(
      _assignmentNotificationKey(assignment),
    );

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

    _scheduleReminderForAssignment(assignments[index]);

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
  bool _isAssignmentOverdue(Map<String, dynamic> assignment) {
    if (assignment["completed"] == true) return false;

    final deadline = _parseDeadlineValue(assignment["deadline"]);
    if (deadline == null) return false;

    return deadline.isBefore(DateTime.now());
  }

  int? _daysUntilAssignmentDeadline(Map<String, dynamic> assignment) {
    final deadline = _parseDeadlineValue(assignment["deadline"]);
    if (deadline == null) return null;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    return deadlineDay.difference(todayStart).inDays;
  }

  int get pendingCount => assignments
      .where(
        (assignment) =>
            !assignment["completed"] && !_isAssignmentOverdue(assignment),
      )
      .length;

  DateTime? _parseDeadlineValue(dynamic rawDeadline) {
    if (rawDeadline == null) return null;

    if (rawDeadline is Timestamp) {
      return rawDeadline.toDate();
    }

    if (rawDeadline is DateTime) {
      return rawDeadline;
    }

    final text = rawDeadline.toString().trim();
    if (text.isEmpty) return null;

    final isoParsed = DateTime.tryParse(text);
    if (isoParsed != null) return isoParsed;

    final cleaned = text.replaceAll(',', '');
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length < 3) return null;

    const monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    final month = monthMap[parts[0].toLowerCase()];
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (month == null || day == null || year == null) return null;

    if (parts.length >= 5) {
      final timeParts = parts[3].split(':');
      final rawHour = int.tryParse(timeParts.first);
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;
      final meridiem = parts[4].toUpperCase();

      if (rawHour != null && minute != null) {
        var hour24 = rawHour % 12;
        if (meridiem == 'PM') {
          hour24 += 12;
        }
        return DateTime(year, month, day, hour24, minute);
      }
    }

    return DateTime(year, month, day, 23, 59);
  }

  String _formatDeadlineForDisplay(dynamic rawDeadline) {
    final deadline = _parseDeadlineValue(rawDeadline);
    if (deadline == null) {
      return (rawDeadline ?? '').toString();
    }

    final hour24 = deadline.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = deadline.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';

    return '${_monthName(deadline.month)} ${deadline.day}, ${deadline.year} $hour12:$minute $period';
  }

  int get overdueCount {
    return assignments.where(_isAssignmentOverdue).length;
  }

  @override
  void initState() {
    super.initState();
    // Schedule opening initial assignment if provided via notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openInitialAssignmentIfNeeded();
    });
  }

  Stream<List<Map<String, dynamic>>> _getAssignmentsStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('assignments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final rawDeadline = data['deadline'];
            final rawPriority = data['priority'];

            String priorityDisplay;
            if (rawPriority is int) {
              if (rawPriority >= 3) {
                priorityDisplay = 'high';
              } else if (rawPriority <= 1) {
                priorityDisplay = 'low';
              } else {
                priorityDisplay = 'medium';
              }
            } else {
              priorityDisplay = (rawPriority ?? 'medium')
                  .toString()
                  .toLowerCase();
            }

            return <String, dynamic>{
              'id': doc.id,
              'title': data['title'] ?? '',
              'deadline': rawDeadline,
              'description': data['description'] ?? '',
              'completed': data['completed'] ?? false,
              'priority': priorityDisplay,
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
              'userId': data['userId'],
            };
          }).toList();
        })
        .handleError((e) {
          debugPrint('❌ Error streaming assignments: $e');
          return [];
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            icon: const Icon(Icons.folder_outlined, size: 26),
            onPressed: _openArchiveScreen,
            tooltip: 'Archive',
          ),
        ),
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
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getAssignmentsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading assignments: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              final streamAssignments = snapshot.data ?? [];
              final hasIncompleteAssignments = streamAssignments.any(
                (a) => a['completed'] != true,
              );
              final shouldShowEmptyState =
                  !hasIncompleteAssignments || _showEmptyStatePreview;

              // Update local state with stream data for use in other methods
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && assignments != streamAssignments) {
                  setState(() {
                    assignments = streamAssignments;
                  });

                  // Schedule reminders for all loaded assignments
                  for (final assignment in streamAssignments) {
                    _scheduleReminderForAssignment(assignment);
                  }
                }
              });

              return SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final contentMaxWidth = availableWidth;
                      final horizontalPadding = availableWidth >= 900
                          ? 32.0
                          : 16.0;

                      return ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentMaxWidth),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: Column(
                            children: [
                              SizedBox(height: _contentTopPadding(context)),

                              // Demo mode banner
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  if (auth.isDemoMode) {
                                    return Container(
                                      width: double.infinity,
                                      color: Colors.yellow.withValues(
                                        alpha: 0.9,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: const Text(
                                        'Demo mode active – no Firebase configuration found',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),

                              if (shouldShowEmptyState) ...[
                                _buildAllCaughtUpBanner(),
                                const SizedBox(height: 14),
                              ],

                              // Status Chips (responsive)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;

                                  final spacing = width < 420 ? 8.0 : 12.0;
                                  final perChipWidth =
                                      (width - spacing * 2) / 3;
                                  final compact = perChipWidth < 150;
                                  final ultraCompact = perChipWidth < 120;

                                  final completedChip = _buildStatusChip(
                                    label: "Completed",
                                    count: streamAssignments
                                        .where((a) => a["completed"])
                                        .length,
                                    icon: Icons.check_circle,
                                    color: const Color(0xFF00C851),
                                    compact: compact,
                                    ultraCompact: ultraCompact,
                                  );
                                  final pendingChip = _buildStatusChip(
                                    label: "Pending",
                                    count: streamAssignments
                                        .where(
                                          (a) =>
                                              !a["completed"] &&
                                              !_isAssignmentOverdue(a),
                                        )
                                        .length,
                                    icon: Icons.pending_actions,
                                    color: const Color(0xFFFF9100),
                                    compact: compact,
                                    ultraCompact: ultraCompact,
                                  );
                                  final overdueChip = _buildStatusChip(
                                    label: "Overdue",
                                    count: streamAssignments
                                        .where(_isAssignmentOverdue)
                                        .length,
                                    icon: Icons.error_outline_rounded,
                                    color: const Color(0xFFEF5350),
                                    compact: compact,
                                    ultraCompact: ultraCompact,
                                  );

                                  return Row(
                                    children: [
                                      completedChip,
                                      SizedBox(width: spacing),
                                      pendingChip,
                                      SizedBox(width: spacing),
                                      overdueChip,
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 26),

                              if (shouldShowEmptyState)
                                _buildEmptyAssignmentsState()
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: streamAssignments.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _buildAssignmentCard(
                                        context,
                                        index,
                                        streamAssignments[index],
                                      ),
                                    );
                                  },
                                ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddAssignmentScreen,
        backgroundColor: Colors.white.withValues(alpha: 0.25),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.add,
          color: Colors.white.withValues(alpha: 0.9),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildAllCaughtUpBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'All Caught Up! 🥳',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Good job! You have no assignments due for the next\n'
                'few days. Take a break!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAssignmentsState() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final maxCardWidth = width < 420 ? width : 520.0;

          return Column(
            children: [
              const SizedBox(height: 8),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.4,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildEmptyIllustrationCard(),
                            const SizedBox(height: 26),
                            const Text(
                              "You're all done! There are no\nassignments to show.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Check back later or add a new task using the +\nbutton.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyIllustrationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tag_faces_outlined,
                  size: 42,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMiniIconTile(Icons.menu_book_rounded),
                  const SizedBox(width: 16),
                  _buildMiniIconTile(Icons.coffee_rounded),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: 108,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniIconTile(IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.75),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    bool expand = true,
    bool compact = false,
    bool ultraCompact = false,
  }) {
    final padding = ultraCompact
        ? const EdgeInsets.symmetric(vertical: 10, horizontal: 8)
        : compact
        ? const EdgeInsets.symmetric(vertical: 12, horizontal: 10)
        : const EdgeInsets.symmetric(vertical: 16, horizontal: 12);
    final iconSize = ultraCompact
        ? 20.0
        : compact
        ? 22.0
        : 24.0;
    final countStyle = TextStyle(
      color: Colors.white,
      fontSize: ultraCompact
          ? 16
          : compact
          ? 18
          : 20,
      fontWeight: FontWeight.w700,
    );
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: ultraCompact
          ? 10
          : compact
          ? 11
          : 13,
      fontWeight: FontWeight.w500,
    );

    final chip = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: iconSize),
              SizedBox(
                height: ultraCompact
                    ? 4
                    : compact
                    ? 6
                    : 8,
              ),
              Text('$count', style: countStyle),
              SizedBox(
                height: ultraCompact
                    ? 2
                    : compact
                    ? 2
                    : 4,
              ),
              Text(
                label,
                style: labelStyle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    if (!expand) return chip;
    return Expanded(child: chip);
  }

  Widget _buildAssignmentCard(
    BuildContext context,
    int index,
    Map<String, dynamic> assignment,
  ) {
    final isCompleted = assignment["completed"] == true;
    final isOverdue = _isAssignmentOverdue(assignment);
    final daysUntilDeadline = _daysUntilAssignmentDeadline(assignment);
    final isDueToday = !isOverdue && daysUntilDeadline == 0;
    final isDueTomorrow = !isOverdue && daysUntilDeadline == 1;

    final dueStatusIcon = isOverdue
        ? Icons.error_outline_rounded
        : isDueToday
        ? Icons.timer_outlined
        : isDueTomorrow
        ? Icons.calendar_month_outlined
        : Icons.calendar_month_outlined;

    final priorityValue = (assignment["priority"] ?? "medium")
        .toString()
        .toLowerCase();
    final isHighPriority = priorityValue == "high";
    final isLowPriority = priorityValue == "low";

    final priorityLabel = isHighPriority
        ? "High Priority"
        : isLowPriority
        ? "Low Priority"
        : "Medium Priority";

    final priorityBaseColor = isHighPriority
        ? const Color(0xFFEF5350)
        : isLowPriority
        ? const Color(0xFF00C851)
        : const Color(0xFFFF9100);

    final cardTintGradient = LinearGradient(
      colors: [
        priorityBaseColor.withValues(alpha: 0.18),
        const Color(0xFF764BA2).withValues(alpha: 0.16),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    int resolveCurrentIndex() {
      final assignmentId = assignment['id']?.toString();
      if (assignmentId != null && assignmentId.isNotEmpty) {
        final matched = assignments.indexWhere(
          (item) => item['id']?.toString() == assignmentId,
        );
        if (matched >= 0) return matched;
      }

      if (index >= 0 && index < assignments.length) return index;
      return -1;
    }

    Widget buildSwipeActionBackground({required bool isDeleteAction}) {
      final baseColor = isDeleteAction
          ? const Color(0xFFEF5350)
          : const Color(0xFF00C851);
      final icon = isDeleteAction ? Icons.delete_outline : Icons.check_circle;
      final label = isDeleteAction ? 'Delete' : 'Mark as Done';

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  baseColor.withValues(alpha: 0.45),
                  baseColor.withValues(alpha: 0.7),
                ],
                begin: isDeleteAction
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                end: isDeleteAction
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Align(
              alignment: isDeleteAction
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDeleteAction) ...[
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(icon, color: Colors.white, size: 30),
                  if (!isDeleteAction) ...[
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Dismissible(
      key: ValueKey(
        assignment['id'] ??
            '${assignment['title']}_${assignment['deadline']}_$index',
      ),
      direction: DismissDirection.horizontal,
      background: buildSwipeActionBackground(isDeleteAction: false),
      secondaryBackground: buildSwipeActionBackground(isDeleteAction: true),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final currentIndex = resolveCurrentIndex();
          if (currentIndex >= 0 && !assignments[currentIndex]["completed"]) {
            toggleComplete(currentIndex);
          }
          return false;
        }

        return direction == DismissDirection.endToStart;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          final currentIndex = resolveCurrentIndex();
          if (currentIndex >= 0) {
            deleteAssignment(currentIndex);
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: GestureDetector(
            onTap: () {
              final currentIndex = resolveCurrentIndex();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailScreen(
                    assignment: assignment,
                    index: currentIndex >= 0 ? currentIndex : index,
                    onUpdate: updateAssignment,
                    onDelete: deleteAssignment,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: cardTintGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: () {
                      final currentIndex = resolveCurrentIndex();
                      if (currentIndex >= 0) {
                        toggleComplete(currentIndex);
                      }
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        color: assignment["completed"]
                            ? const Color(0xFF00C851)
                            : Colors.transparent,
                      ),
                      child: assignment["completed"]
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
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
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    dueStatusIcon,
                                    size: 12,
                                    color: isCompleted
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : isOverdue
                                        ? const Color(0xFFEF5350)
                                        : Colors.white.withValues(alpha: 0.75),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "Due: ${_formatDeadlineForDisplay(assignment['deadline'])}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isCompleted
                                            ? Colors.white.withValues(
                                                alpha: 0.6,
                                              )
                                            : isOverdue
                                            ? const Color(0xFFC0C0D8)
                                            : Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: priorityBaseColor.withValues(
                                  alpha: 0.28,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: priorityBaseColor.withValues(
                                    alpha: 0.55,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flag_rounded,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      priorityLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isOverdue)
                          _buildDuePill(
                            icon: Icons.error_outline_rounded,
                            label: 'Overdue',
                            color: const Color(0xFF9E9E9E),
                          )
                        else if (isDueToday)
                          _buildDuePill(
                            icon: Icons.timer_outlined,
                            label: 'Due Today',
                            color: const Color(0xFFEF5350),
                          )
                        else if (isDueTomorrow)
                          _buildDuePill(
                            icon: Icons.calendar_month_outlined,
                            label: 'Due Tomorrow',
                            color: const Color(0xFFFFC107),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuePill({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.42), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.92)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
