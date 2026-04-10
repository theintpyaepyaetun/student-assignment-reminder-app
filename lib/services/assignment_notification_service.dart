import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AssignmentNotificationService {
  AssignmentNotificationService._();

  static final AssignmentNotificationService instance =
      AssignmentNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const _deadlineNotificationsEnabledKey =
      'deadline_notifications_enabled';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<bool> isDeadlineReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deadlineNotificationsEnabledKey) ?? true;
  }

  Future<void> setDeadlineReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deadlineNotificationsEnabledKey, enabled);

    if (!enabled) {
      await cancelAllReminders();
    }
  }

  Future<void> cancelAllReminders() async {
    await initialize();
    await _notificationsPlugin.cancelAll();
  }

  int _notificationIdFor(String assignmentId) {
    var hash = 0;
    for (final codeUnit in assignmentId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  String _dueReminderBody(String assignmentTitle, DateTime deadlineDate) {
    final normalizedTitle = assignmentTitle.trim();
    return "Your '$normalizedTitle' will be due tomorrow";
  }

  DateTime? _parseDeadline(String deadlineText) {
    final trimmed = deadlineText.trim();
    if (trimmed.isEmpty) return null;

    final isoParsed = DateTime.tryParse(trimmed);
    if (isoParsed != null) return isoParsed;

    final parts = trimmed.replaceAll(',', '').split(RegExp(r'\s+'));
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

  DateTime? _parseDeadlineDynamic(dynamic rawDeadline) {
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

    return _parseDeadline(text);
  }

  Future<void> scheduleOneDayBeforeDeadlineFromDate({
    required String assignmentId,
    required String title,
    required DateTime deadlineDate,
  }) async {
    await initialize();

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Deadline reminders disabled - skipping schedule');
      return;
    }

    final localDeadline = deadlineDate.toLocal();
    final reminderTime = localDeadline.subtract(const Duration(days: 1));

    if (!reminderTime.isAfter(DateTime.now())) {
      debugPrint(
        'ℹ️ Reminder time already passed for assignment: $assignmentId',
      );
      return;
    }

    final notificationId = _notificationIdFor(assignmentId);

    const androidDetails = AndroidNotificationDetails(
      'assignment_deadline_channel',
      'Assignment Deadlines',
      channelDescription:
          'Reminds students about upcoming assignment deadlines',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Assignment Reminder',
      _dueReminderBody(title, localDeadline),
      tz.TZDateTime.from(reminderTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: assignmentId,
    );

    debugPrint(
      '🔔 Scheduled reminder for assignment $assignmentId at $reminderTime',
    );
  }

  Future<void> syncCurrentUserAssignmentReminders() async {
    await initialize();

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Deadline reminders disabled - skipping sync');
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('ℹ️ No authenticated user - skipping reminder sync');
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('assignments')
        .where('userId', isEqualTo: userId)
        .where('completed', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString();
      if (title.isEmpty) continue;

      final parsedDeadline = _parseDeadlineDynamic(data['deadline']);
      if (parsedDeadline == null) continue;

      await scheduleOneDayBeforeDeadlineFromDate(
        assignmentId: doc.id,
        title: title,
        deadlineDate: parsedDeadline,
      );
    }

    debugPrint('✅ Synced assignment reminders for user: $userId');
  }

  Future<void> scheduleOneDayBeforeDeadline({
    required String assignmentId,
    required String title,
    required String deadlineText,
  }) async {
    await initialize();

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Deadline reminders disabled - skipping schedule');
      return;
    }

    final deadlineDate = _parseDeadline(deadlineText);
    if (deadlineDate == null) {
      debugPrint('⚠️ Could not parse deadline for notification: $deadlineText');
      return;
    }

    await scheduleOneDayBeforeDeadlineFromDate(
      assignmentId: assignmentId,
      title: title,
      deadlineDate: deadlineDate,
    );
  }

  Future<bool> sendInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Notifications disabled - skipping instant notification');
      return false;
    }

    final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;

    const androidDetails = AndroidNotificationDetails(
      'assignment_deadline_channel',
      'Assignment Deadlines',
      channelDescription:
          'Reminds students about upcoming assignment deadlines',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );

    debugPrint('🔔 Instant notification sent: $title');
    return true;
  }

  Future<void> cancelReminder(String assignmentId) async {
    await initialize();
    await _notificationsPlugin.cancel(_notificationIdFor(assignmentId));
  }

  /// Show a local notification immediately (used for FCM messages in foreground)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required String assignmentId,
  }) async {
    await initialize();

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Notifications disabled - skipping local notification');
      return;
    }

    final notificationId = _notificationIdFor(assignmentId);

    const androidDetails = AndroidNotificationDetails(
      'assignment_deadline_channel',
      'Assignment Deadlines',
      channelDescription:
          'Reminds students about upcoming assignment deadlines',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: assignmentId,
    );

    debugPrint('🔔 Local notification shown: $title');
  }
}
