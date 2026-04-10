import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'firestore_service.dart';
import 'assignment_notification_service.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();

  factory FirebaseMessagingService() {
    return _instance;
  }

  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirestoreService _firestoreService = FirestoreService();

  /// Initialize Firebase Messaging and set up handlers
  Future<void> initialize() async {
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }

    try {
      // Request user permission for notifications
      await _requestUserPermission();

      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }
      await _persistTokenForCurrentUser(token);

      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        if (kDebugMode) {
          print('FCM Token refreshed: $newToken');
        }
        await _persistTokenForCurrentUser(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages when app is terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Set foreground notification presentation options for iOS
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      if (kDebugMode) {
        print('Firebase Messaging initialization warning: $error');
      }
      if (!kIsWeb) {
        rethrow;
      }
    }
  }

  /// Request notification permissions from user
  Future<void> _requestUserPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('User notification settings: ${settings.authorizationStatus}');
    }
  }

  /// Handle messages received in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Foreground message received:');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
    }

    // Show local notification when message arrives in foreground
    await AssignmentNotificationService.instance.showLocalNotification(
      title: message.notification?.title ?? 'Reminder',
      body: message.notification?.body ?? 'New notification',
      assignmentId: message.data['assignmentId'] ?? 'fcm_notification',
    );
  }

  /// Handle when user taps on notification that opened the app
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Message opened app:');
      print('Title: ${message.notification?.title}');
      print('Data: ${message.data}');
    }

    // Navigate to relevant screen based on message data
    // Example: if message contains assignmentId, navigate to detail screen
    _handleNotificationTap(message.data);
  }

  /// Handle navigation based on notification data
  void _handleNotificationTap(Map<String, dynamic> data) {
    final assignmentId = data['assignmentId'];
    if (assignmentId != null) {
      if (kDebugMode) {
        print('Navigating to assignment: $assignmentId');
      }
      // You can implement navigation here by using a global navigation key
      // or by emitting an event through a provider/state management
    }
  }

  /// Show a local notification (useful for foreground messages)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? assignmentId,
  }) async {
    await AssignmentNotificationService.instance.showLocalNotification(
      title: title,
      body: body,
      assignmentId: assignmentId ?? 'fcm_notification',
    );
  }

  /// Get current FCM token
  Future<String?> getFCMToken() async {
    if (kIsWeb) return null;
    return await _firebaseMessaging.getToken();
  }

  /// Ensure current token is stored for the currently signed-in user
  Future<void> syncTokenForCurrentUser() async {
    if (kIsWeb) return;

    try {
      final token = await _firebaseMessaging.getToken();
      await _persistTokenForCurrentUser(token);
    } catch (e) {
      if (kDebugMode) {
        print('Skipping FCM token sync: $e');
      }
    }
  }

  Future<void> _persistTokenForCurrentUser(String? token) async {
    if (token == null || token.isEmpty) return;

    final uid = _firestoreService.currentUserId;
    if (uid == null) {
      if (kDebugMode) {
        print('No signed-in user yet; skipped FCM token persistence');
      }
      return;
    }

    try {
      await _firestoreService.saveFcmToken(uid: uid, token: token);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to persist FCM token: $e');
      }
    }
  }

  /// Delete FCM token (useful for logout)
  Future<void> deleteFCMToken() async {
    if (kIsWeb) return;
    await _firebaseMessaging.deleteToken();
  }

  /// Remove token from Firestore and invalidate local token on logout
  Future<void> clearTokenForCurrentUser({String? uid}) async {
    try {
      await _firestoreService.removeFcmToken(uid: uid);
    } catch (_) {}
    await deleteFCMToken();
  }
}

/// Top-level function to handle background messages
/// Must be a top-level function, not a method
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    print('Background message received:');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
  }
  // You can process the message here or show a local notification
}
