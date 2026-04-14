import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint('🔔 Background notification tapped. payload=${response.payload}');
}

class AssignmentNotificationService {
  AssignmentNotificationService._();

  static final AssignmentNotificationService instance =
      AssignmentNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const _deadlineNotificationsEnabledKey =
      'deadline_notifications_enabled';
  static const _deadlineChannelId = 'assignment_deadline_channel_v2';
  static const _deadlineChannelName = 'Assignment Deadlines';
  static const _deadlineChannelDescription =
      'Reminds students about upcoming assignment deadlines';
  static const _oneDayReminderSuffix = 'oneday';
  static const _dueTimeReminderSuffix = 'duetime';

  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingNotificationAssignmentId;
  final StreamController<String> _assignmentTapController =
      StreamController<String>.broadcast();
  bool get _supportsLocalNotifications => !kIsWeb;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Stream<String> get assignmentTapStream => _assignmentTapController.stream;

  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  String? consumePendingAssignmentId() {
    final value = _pendingNotificationAssignmentId;
    _pendingNotificationAssignmentId = null;
    return value;
  }

  String _buildReminderPayload(String assignmentId, String taskName) {
    return jsonEncode({
      'type': 'assignment_reminder',
      'assignmentId': assignmentId,
      'taskName': taskName,
    });
  }

  String? _extractAssignmentIdFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final assignmentId = decoded['assignmentId']?.toString();
        if (assignmentId != null && assignmentId.isNotEmpty) {
          return assignmentId;
        }
      }
    } catch (_) {}

    if (payload.contains('|')) {
      final firstPart = payload.split('|').first.trim();
      if (firstPart.isNotEmpty) return firstPart;
    }

    return payload.trim();
  }

  void _navigateToHomeWithAssignment(String assignmentId) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pendingNotificationAssignmentId = assignmentId;
      return;
    }

    navigator.pushNamed('/home', arguments: {'assignmentId': assignmentId});
  }

  void _handleNotificationTapPayload(String? payload) {
    final assignmentId = _extractAssignmentIdFromPayload(payload);
    if (assignmentId == null || assignmentId.isEmpty) return;

    final hasListeners = _assignmentTapController.hasListener;
    _assignmentTapController.add(assignmentId);

    if (!hasListeners) {
      _navigateToHomeWithAssignment(assignmentId);
    }
  }

  Future<void> configureLocalTimezone() async {
    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
      debugPrint('🌍 Timezone configured: $timezoneName');
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint('⚠️ Failed to detect local timezone, falling back to UTC: $e');
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    if (!_supportsLocalNotifications) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      'ic_stat_notification',
    );
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTapPayload(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    final launchDetails = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchPayload != null && launchPayload.isNotEmpty) {
      _handleNotificationTapPayload(launchPayload);
    }

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _deadlineChannelId,
        _deadlineChannelName,
        description: _deadlineChannelDescription,
        importance: Importance.max,
      ),
    );

    await configureLocalTimezone();
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    await requestRequiredPermissions();

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.requestNotificationsPermission();
    await ensureAndroidExactAlarmPermission(requestIfNeeded: true);

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

  Future<bool> requestRequiredPermissions() async {
    var notificationGranted = true;
    var exactAlarmGranted = true;

    if (_isAndroid) {
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        notificationGranted =
            (await Permission.notification.request()).isGranted;
      }

      final exactStatus = await Permission.scheduleExactAlarm.status;
      if (!exactStatus.isGranted) {
        exactAlarmGranted =
            (await Permission.scheduleExactAlarm.request()).isGranted;
      }
    }

    if (_isIOS) {
      final iosStatus = await Permission.notification.status;
      if (!iosStatus.isGranted) {
        notificationGranted =
            (await Permission.notification.request()).isGranted;
      }
    }

    debugPrint(
      '🔐 Permissions -> notification: $notificationGranted, scheduleExactAlarm: $exactAlarmGranted',
    );
    return notificationGranted && exactAlarmGranted;
  }

  Future<bool> ensureAndroidNotificationPermission({
    bool requestIfNeeded = true,
  }) async {
    if (!_isAndroid) return true;

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation == null) return true;

    try {
      final enabled = await androidImplementation.areNotificationsEnabled();
      if (enabled ?? true) return true;

      if (!requestIfNeeded) return false;

      await androidImplementation.requestNotificationsPermission();
      final updatedEnabled = await androidImplementation
          .areNotificationsEnabled();
      return updatedEnabled ?? false;
    } catch (e) {
      debugPrint('⚠️ Notification permission check/request failed: $e');
      return false;
    }
  }

  Future<bool> ensureAndroidExactAlarmPermission({
    bool requestIfNeeded = true,
  }) async {
    if (!_isAndroid) return true;

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation == null) return true;

    try {
      final canScheduleExact =
          await androidImplementation.canScheduleExactNotifications() ?? true;
      if (canScheduleExact) return true;

      if (!requestIfNeeded) return false;

      await androidImplementation.requestExactAlarmsPermission();

      final updatedCanScheduleExact =
          await androidImplementation.canScheduleExactNotifications() ?? false;
      return updatedCanScheduleExact;
    } on PlatformException catch (e) {
      debugPrint('⚠️ Exact alarm check/request failed: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('⚠️ Exact alarm check/request failed: $e');
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return true;

    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('⚠️ Battery optimization status check failed: $e');
      return false;
    }
  }

  Future<bool> promptDisableBatteryOptimizations() async {
    if (!_isAndroid) return true;

    final alreadyIgnored = await isIgnoringBatteryOptimizations();
    if (alreadyIgnored) return true;

    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (status.isGranted) return true;
    } catch (e) {
      debugPrint('⚠️ Could not request battery optimization exemption: $e');
    }

    await openAppSettings();
    return false;
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
    if (!_supportsLocalNotifications) return;
    await _notificationsPlugin.cancelAll();
  }

  int _notificationIdFor(String assignmentId) {
    return _notificationIdForType(assignmentId, _oneDayReminderSuffix);
  }

  int _notificationIdForType(String assignmentId, String typeSuffix) {
    var hash = 0;
    final value = '$assignmentId|$typeSuffix';
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  int _legacyNotificationIdFor(String assignmentId) {
    var hash = 0;
    for (final codeUnit in assignmentId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  String _dueReminderBody(String assignmentTitle, DateTime deadlineDate) {
    final normalizedTitle = assignmentTitle.trim();
    return "Don't forget! Your $normalizedTitle assignment is due tomorrow.";
  }

  Future<void> _scheduleZoned(
    int notificationId,
    String title,
    String body,
    DateTime when,
    NotificationDetails details,
    String payload, {
    bool preferExact = true,
  }) async {
    if (!_supportsLocalNotifications) return;

    final now = DateTime.now();
    final localWhen = when.toLocal();
    if (!localWhen.isAfter(now)) {
      debugPrint(
        'ℹ️ Scheduled time is not in the future, skipping: $localWhen',
      );
      return;
    }

    final scheduledAt = tz.TZDateTime.from(localWhen, tz.local);
    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledAt,
        details,
        androidScheduleMode: preferExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint(
        '⚠️ Exact alarm scheduling unavailable, falling back to inexact: $e',
      );
      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledAt,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (fallbackError) {
        debugPrint('⚠️ Inexact alarm scheduling failed: $fallbackError');
      }
    }
  }

  DateTime? _computeOneDayReminderDate(DateTime deadlineDate) {
    final localDeadline = deadlineDate.toLocal();
    final now = DateTime.now();

    if (!localDeadline.isAfter(now)) {
      return null;
    }

    final scheduledDate = localDeadline.subtract(const Duration(days: 1));
    if (!scheduledDate.isAfter(now)) {
      return null;
    }

    return scheduledDate;
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
    await scheduleAssignmentReminder(
      deadlineDate,
      title,
      assignmentId: assignmentId,
    );
  }

  /// Schedule a local notification at the exact due date/time.
  ///
  /// This works offline because scheduling happens on-device.
  Future<bool> scheduleNotificationAtDueDate({
    required String assignmentId,
    required String title,
    required DateTime dueDate,
    String? body,
  }) async {
    await initialize();

    if (!_supportsLocalNotifications) {
      return false;
    }

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Deadline reminders disabled - skipping due-date schedule');
      return false;
    }

    final permissionsGranted = await requestRequiredPermissions();
    if (!permissionsGranted) {
      debugPrint(
        '⚠️ Required notification/exact alarm permissions missing. Due-date reminder cannot be scheduled.',
      );
      return false;
    }

    final exactAlarmAllowed = await ensureAndroidExactAlarmPermission(
      requestIfNeeded: true,
    );

    final localDueDate = dueDate.toLocal();
    if (!localDueDate.isAfter(DateTime.now())) {
      debugPrint(
        'ℹ️ Due date is not in the future, skipping due-date reminder for: $assignmentId',
      );
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      _deadlineChannelId,
      _deadlineChannelName,
      channelDescription: _deadlineChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = _buildReminderPayload(assignmentId, title);
    await _scheduleZoned(
      _notificationIdForType(assignmentId, _dueTimeReminderSuffix),
      title,
      body ?? 'Your assignment is due now.',
      localDueDate,
      details,
      payload,
      preferExact: exactAlarmAllowed,
    );

    return true;
  }

  Future<bool> scheduleAssignmentReminder(
    DateTime dueDate,
    String taskName, {
    String? assignmentId,
  }) async {
    await initialize();

    if (!_supportsLocalNotifications) {
      return false;
    }

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Deadline reminders disabled - skipping schedule');
      return false;
    }

    final permissionsGranted = await requestRequiredPermissions();
    if (!permissionsGranted) {
      debugPrint(
        '⚠️ Required notification/exact alarm permissions missing. Reminder cannot be scheduled.',
      );
      return false;
    }

    final localDeadline = dueDate.toLocal();
    final reminderTime = _computeOneDayReminderDate(localDeadline);

    if (reminderTime == null) {
      debugPrint(
        'ℹ️ (dueDate - 1 day) is in the past. Skipping reminder for: ${assignmentId ?? taskName}',
      );
      return false;
    }

    final exactAlarmAllowed = await ensureAndroidExactAlarmPermission(
      requestIfNeeded: true,
    );

    if (_isAndroid && !(await isIgnoringBatteryOptimizations())) {
      debugPrint(
        '⚠️ Battery optimization is enabled. Reminder delivery may be delayed on some devices.',
      );
    }

    const androidDetails = AndroidNotificationDetails(
      _deadlineChannelId,
      _deadlineChannelName,
      channelDescription: _deadlineChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _scheduleZoned(
      _notificationIdForType(assignmentId ?? taskName, _oneDayReminderSuffix),
      'Assignment Reminder',
      _dueReminderBody(taskName, localDeadline),
      reminderTime,
      details,
      _buildReminderPayload(assignmentId ?? taskName, taskName),
      preferExact: exactAlarmAllowed,
    );

    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      debugPrint(
        '🔔 Scheduled one-day reminder for assignment ${assignmentId ?? taskName} at $reminderTime | pending=${pending.length}',
      );
    } catch (e) {
      debugPrint(
        '⚠️ Reminder scheduled but pending request count unavailable on this platform: $e',
      );
    }
    return true;
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

    if (!_supportsLocalNotifications) {
      return false;
    }

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Notifications disabled - skipping instant notification');
      return false;
    }

    final notificationAllowed = await ensureAndroidNotificationPermission(
      requestIfNeeded: true,
    );
    if (!notificationAllowed) {
      debugPrint('⚠️ Android notification permission is disabled.');
      return false;
    }

    final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;

    const androidDetails = AndroidNotificationDetails(
      _deadlineChannelId,
      _deadlineChannelName,
      channelDescription: _deadlineChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
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
    if (!_supportsLocalNotifications) return;
    await _notificationsPlugin.cancel(
      _notificationIdForType(assignmentId, _oneDayReminderSuffix),
    );
    await _notificationsPlugin.cancel(
      _notificationIdForType(assignmentId, _dueTimeReminderSuffix),
    );
    await _notificationsPlugin.cancel(_legacyNotificationIdFor(assignmentId));
  }

  /// Show a local notification immediately (used for FCM messages in foreground)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required String assignmentId,
  }) async {
    await initialize();

    if (!_supportsLocalNotifications) return;

    final isEnabled = await isDeadlineReminderEnabled();
    if (!isEnabled) {
      debugPrint('ℹ️ Notifications disabled - skipping local notification');
      return;
    }

    final notificationId = _notificationIdFor(assignmentId);

    const androidDetails = AndroidNotificationDetails(
      _deadlineChannelId,
      _deadlineChannelName,
      channelDescription: _deadlineChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
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
