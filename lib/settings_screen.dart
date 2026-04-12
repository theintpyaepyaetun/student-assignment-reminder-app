import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_assignment_reminder_app/services/firestore_service.dart';
import 'package:student_assignment_reminder_app/services/assignment_notification_service.dart';
import 'package:student_assignment_reminder_app/models/user_profile_model.dart';
import 'package:student_assignment_reminder_app/providers/auth_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();
  late TextEditingController _nameController;
  bool _isUploadingPhoto = false;
  double _uploadProgress = 0;
  Uint8List? _localProfileImageBytes;
  Uint8List? _cachedProfileImageBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    unawaited(_loadCachedProfilePhoto());
    unawaited(_enforceMandatoryNotifications());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedProfilePhoto() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final base64Photo = prefs.getString('cached_profile_photo_$uid');
    if (base64Photo == null || base64Photo.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _cachedProfileImageBytes = base64Decode(base64Photo);
    });
  }

  Future<void> _cacheProfilePhoto(Uint8List imageBytes) async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_profile_photo_$uid',
      base64Encode(imageBytes),
    );
  }

  String _storageErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'permission-denied':
        return 'Upload blocked by Firebase Storage rules. Please allow authenticated users to write profile photos.';
      case 'object-not-found':
        return 'Storage path not found. Please retry upload.';
      case 'canceled':
        return 'Upload canceled.';
      case 'quota-exceeded':
        return 'Storage quota exceeded for this Firebase project.';
      case 'retry-limit-exceeded':
        return 'Upload timed out. Please check connection and retry.';
      default:
        return 'Storage error (${e.code}): ${e.message ?? 'Unknown error'}';
    }
  }

  Future<void> _syncExistingRemindersForCurrentUser() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('assignments')
        .where('userId', isEqualTo: userId)
        .where('completed', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString();
      if (title.isEmpty) continue;

      final rawDeadline = data['deadline'];
      if (rawDeadline is Timestamp) {
        await AssignmentNotificationService.instance
            .scheduleOneDayBeforeDeadlineFromDate(
              assignmentId: doc.id,
              title: title,
              deadlineDate: rawDeadline.toDate(),
            );
        continue;
      }

      if (rawDeadline is DateTime) {
        await AssignmentNotificationService.instance
            .scheduleOneDayBeforeDeadlineFromDate(
              assignmentId: doc.id,
              title: title,
              deadlineDate: rawDeadline,
            );
        continue;
      }

      final deadlineText = (rawDeadline ?? '').toString();
      if (deadlineText.isEmpty) continue;

      await AssignmentNotificationService.instance.scheduleOneDayBeforeDeadline(
        assignmentId: doc.id,
        title: title,
        deadlineText: deadlineText,
      );
    }
  }

  Future<void> _enforceMandatoryNotifications({
    bool interactive = false,
  }) async {
    try {
      await _firestoreService.updatePreference('notifications', true);
    } catch (_) {}

    try {
      await AssignmentNotificationService.instance.setDeadlineReminderEnabled(
        true,
      );
      await _syncExistingRemindersForCurrentUser();

      if (interactive) {
        final notificationsAllowed = await AssignmentNotificationService
            .instance
            .ensureAndroidNotificationPermission(requestIfNeeded: true);
        final exactAlarmAllowed = await AssignmentNotificationService.instance
            .ensureAndroidExactAlarmPermission(requestIfNeeded: true);
        final batteryOptimizationIgnored = await AssignmentNotificationService
            .instance
            .isIgnoringBatteryOptimizations();

        if (!mounted) return;

        if (!notificationsAllowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission is off. Enable it for reminders.',
              ),
            ),
          );
        }

        if (!exactAlarmAllowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Exact alarm permission is off. Future reminders may be delayed.',
              ),
            ),
          );
        }

        if (!batteryOptimizationIgnored) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Disable Battery Optimization'),
                content: const Text(
                  'Battery optimization can delay reminders on some devices. '
                  'Allow this app to ignore battery optimization for reliable alerts.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Not now'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await AssignmentNotificationService.instance
                          .promptDisableBatteryOptimizations();
                    },
                    child: const Text('Open settings'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to enforce mandatory notifications: $e');
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user logged in'),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
      return;
    }

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 35,
        maxWidth: 480,
        maxHeight: 480,
      );

      if (pickedImage == null) return;

      final rawFileSize = await pickedImage.length();
      const maxOriginalFileSize = 3 * 1024 * 1024;
      if (rawFileSize > maxOriginalFileSize) {
        throw Exception(
          'Selected image is too large. Please pick an image under 3 MB.',
        );
      }

      if (mounted) {
        setState(() {
          _isUploadingPhoto = true;
          _uploadProgress = 0;
        });
      }

      final imageBytes = await pickedImage.readAsBytes();
      if (mounted) {
        setState(() {
          _localProfileImageBytes = imageBytes;
          _cachedProfileImageBytes = imageBytes;
        });
      }
      await _cacheProfilePhoto(imageBytes);

      const maxImageSize = 1 * 1024 * 1024;
      if (imageBytes.lengthInBytes > maxImageSize) {
        throw Exception(
          'Optimized image is still too large. Please choose a smaller photo.',
        );
      }

      final photoRef = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('${currentUser.uid}.jpg');

      final uploadTask = photoRef.putData(
        imageBytes,
        SettableMetadata(contentType: pickedImage.mimeType ?? 'image/jpeg'),
      );

      final progressSub = uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        if (snapshot.totalBytes <= 0) return;

        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      final finishedWithinFiveSeconds = await Future.any<bool>([
        uploadTask.then((_) => true),
        Future.delayed(const Duration(seconds: 5), () => false),
      ]);

      if (!finishedWithinFiveSeconds) {
        await progressSub.cancel();

        unawaited(
          uploadTask
              .then((_) async {
                final photoUrl = await photoRef.getDownloadURL();
                await _firestoreService.updateUserProfile(photoUrl: photoUrl);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photo synced successfully.'),
                    backgroundColor: Color(0xFF00C851),
                  ),
                );
              })
              .catchError((e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Photo sync failed: $e'),
                    backgroundColor: const Color(0xFFEF5350),
                  ),
                );
              }),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo changed. Syncing in background...'),
            backgroundColor: Color(0xFF667EEA),
          ),
        );
        return;
      }

      await progressSub.cancel();

      final photoUrl = await photoRef.getDownloadURL();
      await _firestoreService.updateUserProfile(photoUrl: photoUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully!'),
          backgroundColor: Color(0xFF00C851),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        '❌ Profile photo upload FirebaseException: ${e.code} ${e.message}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_storageErrorMessage(e)),
          backgroundColor: const Color(0xFFEF5350),
        ),
      );
    } catch (e) {
      debugPrint('❌ Profile photo upload error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload photo: $e'),
          backgroundColor: const Color(0xFFEF5350),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _showEditProfileDialog(UserProfile? userProfile) {
    _nameController.text = userProfile?.username ?? '';

    showDialog(
      context: context,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            title: const Text(
              "Edit Profile",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name Field
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF667EEA),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _firestoreService.updateUserProfile(
                      username: _nameController.text,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: Color(0xFF00C851),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating profile: $e'),
                          backgroundColor: const Color(0xFFEF5350),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  "Save",
                  style: TextStyle(
                    color: Color(0xFF667EEA),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void logout() {
    showDialog(
      context: context,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            title: const Text(
              "Logout?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            content: Text(
              "Are you sure you want to logout from your account?",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Color(0xFFEF5350),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          StreamBuilder<UserProfile?>(
            stream: _firestoreService.streamCurrentUserProfile(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final userProfile = snapshot.data;
              final username =
                  userProfile?.username ??
                  currentUser?.displayName ??
                  'Student User';
              final email =
                  userProfile?.email ??
                  currentUser?.email ??
                  'student@university.edu';

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
                children: [
                  Card(
                    color: Colors.white.withOpacity(0.14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: ClipOval(
                              child: _localProfileImageBytes != null
                                  ? Image.memory(
                                      _localProfileImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : _cachedProfileImageBytes != null
                                  ? Image.memory(
                                      _cachedProfileImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : userProfile?.photoUrl != null
                                  ? Image.network(
                                      '${userProfile!.photoUrl!}?v=${userProfile.updatedAt.millisecondsSinceEpoch}',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.person,
                                              size: 40,
                                              color: Colors.white.withOpacity(
                                                0.85,
                                              ),
                                            );
                                          },
                                    )
                                  : Container(
                                      color: Colors.white.withOpacity(0.2),
                                      child: Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                  onPressed: _isUploadingPhoto
                                      ? null
                                      : _uploadProfilePhoto,
                                  icon: _isUploadingPhoto
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.photo_camera_outlined),
                                  label: Text(
                                    _isUploadingPhoto
                                        ? 'Uploading ${(_uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                                        : 'Upload Photo',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(
                                      0.2,
                                    ),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _showEditProfileDialog(userProfile),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white.withOpacity(0.14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      title: const Text(
                        'Notifications',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Required for assignment reminders',
                        style: TextStyle(color: Colors.white.withOpacity(0.75)),
                      ),
                      trailing: const Chip(label: Text('ON')),
                      onTap: () async {
                        await _enforceMandatoryNotifications(interactive: true);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notifications are enabled for reminders.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.white.withOpacity(0.14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      title: const Text(
                        'App Version',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '1.0.0',
                        style: TextStyle(color: Colors.white.withOpacity(0.75)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF5350),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
