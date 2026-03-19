// Dart core and Flutter imports
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

// Flutter packages
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// External packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Local imports
import 'notification_channels.dart' as nch;

// Helper to format time based on system locale
String _formatTime(DateTime time) {
  return DateFormat.jm().format(time);
}

/// Supported repeat frequencies for scheduled notifications.
enum NotificationFrequency {
  oneTime,
  daily,
  weekly,
  monthly,
}

// Background alarm manager removed. Background auto-add when the app is closed
// is currently disabled to avoid incompatible plugin issues.

class NotificationService {
  // List of engaging notification messages to encourage expense tracking
  static final List<Map<String, String>> _notificationMessages = [
    {
      'title': '💸 Money Matters!',
      'body':
          'Track today\'s expenses in 30 secs & stay in control of your budget! 🚀'
    },
    {
      'title': '💰 Smart Spender Alert',
      'body':
          'Your future self will thank you for tracking today! Tap to log expenses now! ✨'
    },
    {
      'title': '📊 Financial Health Check',
      'body':
          '2 minutes now = Better financial future! Log your daily expenses. 💪'
    },
    {
      'title': '💡 Pro Tip!',
      'body':
          'People who track expenses save 20% more. Tap to log today\'s spending! 📈'
    },
    {
      'title': '🎯 Stay On Budget',
      'body':
          'Quick! Log today\'s expenses before you forget. Your budget will thank you! 💰'
    },
    {
      'title': '🏆 Daily Win!',
      'body':
          'Track today\'s expenses and keep your financial goals on track! Tap to start. 🚀'
    },
    {
      'title': '💎 Be a Money Master',
      'body':
          'Great financial habits start with tracking. Log today\'s expenses now! ✨'
    },
    {
      'title': '🔔 Don\'t Let Money Slip Away!',
      'body':
          '1 minute now = More money in your pocket later. Track your spending today! 💵'
    },
    {
      'title': '📱 Your Phone Knows...',
      'body':
          'You\'re one tap away from better money habits. Log those expenses now! 💳'
    },
    {
      'title': '⏰ Time to Face the Numbers!',
      'body':
          'The first step to saving more is knowing where your money goes. Track it now! 📝'
    },
    {
      'title': '🎉 Financial Freedom Starts Here',
      'body':
          'Small actions lead to big results. Take 60 seconds to log today\'s expenses! 💫'
    },
    {
      'title': '🧠 Mind Your Money',
      'body':
          'The best time to track expenses was earlier. The second best time is NOW! ⏱️'
    },
  ];

  // Get a random notification message
  Map<String, String> get _randomNotificationMessage {
    final random = Random();
    return _notificationMessages[random.nextInt(_notificationMessages.length)];
  }

  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Timer? _runner;

  Future<void> init() async {
    if (_initialized) return;
    // On web, local notifications plugin isn't supported. No-op safely.
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    // Initialize timezone database (required for zoned scheduling)
    tz.initializeTimeZones();
    // Note: Without a native timezone plugin, tz.local may default to UTC on some devices.
    // Scheduling APIs below still work, but fire in that timezone. Add flutter_native_timezone
    // if you need precise local-zone scheduling and then set tz.setLocalLocation(...).

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        await _handleNotificationResponse(response.payload);
      },
    );

    // Channels (Android)
    await _ensureDefaultAndroidChannel();

    // Request runtime permissions if needed
    final hasPermission = await checkNotificationPermission();
    if (!hasPermission) {
      await requestPermissions();
    }

    _initialized = true;

    // Start lightweight foreground runner to auto-add at due time while app is open
    _runner ??= Timer.periodic(const Duration(minutes: 1), (_) {
      _processDueSchedules();
    });
  }

  /// Schedule a background auto-add (Android via Workmanager). iOS/web: no-op.
  Future<void> scheduleBackgroundAutoAdd({
    required DateTime when,
    required Map<String, dynamic> payload,
  }) async {
    // No-op for now; background alarms disabled. Foreground runner still processes due schedules.
    debugPrint(
        '[NotificationService] scheduleBackgroundAutoAdd skipped (background alarms disabled).');
  }

  static const MethodChannel _platform =
      MethodChannel('com.arthaksh.app/notifications');

  /// Checks if notification permissions are granted
  Future<bool> checkNotificationPermission() async {
    if (kIsWeb) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        return status.isGranted;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, we'll just try to request permissions and see if they're granted
        final granted = await _requestIosPermissions();
        return granted;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return false;
    }
  }

  /// Helper method to request iOS permissions
  Future<bool> _requestIosPermissions() async {
    try {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } catch (e) {
      debugPrint('Error requesting iOS permissions: $e');
      return false;
    }
  }

  /// Requests notification permissions on Android/iOS.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android, check for exact alarm permission
        bool hasPermission = false;
        try {
          hasPermission =
              await _platform.invokeMethod('checkExactAlarmPermission');
          if (!hasPermission) {
            hasPermission =
                await _platform.invokeMethod('requestExactAlarmPermission');
          }
        } catch (e) {
          debugPrint('Error with exact alarm permission: $e');
        }

        // Also request standard notification permission
        final status = await Permission.notification.request();
        return status.isGranted && hasPermission;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, request permissions through the plugin
        return await _requestIosPermissions();
      }

      return false;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  Future<void> _ensureDefaultAndroidChannel() async {
    await nch.ensureDefaultAndroidChannel(_plugin);
  }

  /// Schedules a daily reminder notification at 9:00 PM (configurable helper used)
  Future<void> scheduleDailyExpenseReminder() async {
    try {
      if (kIsWeb) {
        debugPrint('Notifications not supported on web');
        return;
      }

      debugPrint('Scheduling daily expense reminder...');

      // Ensure channel is set up
      await _ensureDefaultAndroidChannel();

      // Check if we have permission first
      final hasPermission = await checkNotificationPermission();
      if (!hasPermission) {
        debugPrint('Notification permission not granted, requesting...');
        final granted = await requestPermissions();
        if (!granted) {
          debugPrint('User denied notification permission');
          return;
        }
      }

      // Cancel any existing daily reminder
      await _plugin.cancel(nch.NotificationChannels.dailyReminderId);

      // Schedule new daily reminder at 9:00 PM
      final ok = await scheduleDailyAt(hour: 21, minute: 0);
      debugPrint('Daily reminder scheduled result: $ok');

      if (ok) {
        final formattedTime = _formatTime(DateTime(0, 0, 0, 21, 0));
        debugPrint('Successfully scheduled daily reminder at $formattedTime');
      } else {
        debugPrint('Failed to schedule daily reminder');
      }
    } catch (e, stackTrace) {
      debugPrint('Error scheduling daily reminder: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Cancels the daily expense reminder notification
  Future<void> cancelDailyExpenseReminder() async {
    await _plugin.cancel(nch.NotificationChannels.dailyReminderId);
  }

  /// Schedules a daily reminder notification at 9:00 PM
  Future<bool> scheduleDaily0900Reminder() async {
    try {
      if (kIsWeb) {
        debugPrint('Notifications not supported on web');
        return false;
      }

      debugPrint('Scheduling daily 9:00 PM reminder...');

      // Ensure the notification channel is set up
      await _ensureDefaultAndroidChannel();

      // Check notification permission
      final hasPermission = await checkNotificationPermission();
      if (!hasPermission) {
        debugPrint('Notification permission not granted, requesting...');
        final granted = await requestPermissions();
        if (!granted) {
          debugPrint('User denied notification permission');
          return false;
        }
      }

      // Cancel any existing 9:00 PM notification
      await _plugin.cancel(nch.NotificationChannels.dailyReminderId);

      // Schedule the new notification for 9:00 PM
      final now = DateTime.now();
      var scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);

      // If the time has already passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final androidDetails = AndroidNotificationDetails(
        nch.NotificationChannels.dailyReminderChannelId,
        nch.NotificationChannels.dailyReminderChannelName,
        channelDescription:
            'Daily reminder at ${_formatTime(DateTime(0, 0, 0, 21, 0))}',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        autoCancel: true,
        color: const Color(0xFF0D9488),
        colorized: true,
        enableLights: true,
        ledColor: const Color(0xFF0D9488),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final message = _randomNotificationMessage;

      await _plugin.zonedSchedule(
        nch.NotificationChannels.dailyReminderId,
        message['title']!,
        message['body']!,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_reminder_2100',
      );

      final formattedTime = _formatTime(DateTime(0, 0, 0, 21, 0));
      debugPrint('Successfully scheduled daily reminder at $formattedTime');
      return true;
    } catch (e, stackTrace) {
      final formattedTime = _formatTime(DateTime(0, 0, 0, 21, 0));
      debugPrint('Error scheduling $formattedTime reminder: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Returns a list of all pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint(
          '[NOTIFICATION ERROR] Error getting pending notifications: $e');
      return [];
    }
  }

  /// Schedules a notification for a scheduled expense
  Future<void> scheduleExpenseNotification({
    required String expenseId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? payload,
  }) async {
    try {
      if (kIsWeb) return; // Not supported on web

      // Request notification permissions if not already granted
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        debugPrint('Notification permission not granted');
        return;
      }

      // Create a unique ID for this notification
      final id = expenseId.hashCode;

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        nch.NotificationChannels.scheduledExpenseChannelId,
        nch.NotificationChannels.scheduledExpenseChannelName,
        channelDescription:
            nch.NotificationChannels.scheduledExpenseChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        color: const Color(0xFF4CAF50),
        styleInformation: BigTextStyleInformation(''),
      );

      // iOS notification details
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Convert to local timezone
      final tz.TZDateTime scheduledTZ =
          tz.TZDateTime.from(scheduledTime, tz.local);

      // If the time has already passed, don't schedule
      if (scheduledTZ.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint('Scheduled time has already passed');
        return;
      }

      // Schedule the notification
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({
          'type': 'scheduled_expense',
          'expenseId': expenseId,
          ...?payload,
        }),
      );

      debugPrint(
          'Scheduled expense notification for ${scheduledTime.toString()}');
    } catch (e, stackTrace) {
      debugPrint('Error scheduling expense notification: $e\n$stackTrace');
      // Try to schedule with inexact timing if exact fails
      try {
        await _plugin.zonedSchedule(
          expenseId.hashCode,
          title,
          body,
          tz.TZDateTime.from(scheduledTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'scheduled_expense_channel',
              'Scheduled Expenses',
              channelDescription: 'Notifications for scheduled expenses',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: jsonEncode({
            'type': 'scheduled_expense',
            'expenseId': expenseId,
            ...?payload,
          }),
        );
      } catch (e) {
        debugPrint('Fallback scheduling also failed: $e');
      }
    }
  }

  Future<void> _processDueSchedules() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final now = DateTime.now();
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('autoAdd', isEqualTo: true)
          .where('status', isEqualTo: 'scheduled')
          .where('nextRun', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .limit(10)
          .get();
      for (final d in qs.docs) {
        final data = d.data();
        final payload = (data['payload'] as Map<String, dynamic>?);
        if (payload == null) continue;
        await processAutoAddPayload(payload);

        // Compute next run
        final freqRaw = (data['frequency'] as String?) ?? 'One-time';
        final freq = freqRaw.toLowerCase();
        final nextRunTs = data['nextRun'];
        DateTime nextRun = now.add(const Duration(minutes: 1));
        if (nextRunTs is Timestamp) nextRun = nextRunTs.toDate();

        DateTime roll(DateTime from) {
          switch (freq) {
            case 'daily':
              return from.add(const Duration(days: 1));
            case 'weekly':
              return from.add(const Duration(days: 7));
            case 'monthly':
              final y = from.year;
              final m = from.month;
              final dDay = from.day;
              final ny = m == 12 ? y + 1 : y;
              final nm = m == 12 ? 1 : m + 1;
              final lastDay = DateTime(ny, nm + 1, 0).day;
              final day = dDay <= lastDay ? dDay : lastDay;
              return DateTime(ny, nm, day, from.hour, from.minute);
            default:
              return from; // one-time or unknown
          }
        }

        if (freq == 'one-time' || freq == 'one time') {
          await d.reference.update({
            'status': 'completed',
            'isActive': false,
            'processedAt': FieldValue.serverTimestamp(),
            'lastProcessed': FieldValue.serverTimestamp(),
            'nextRun': null,
            'occurrenceCount': FieldValue.increment(1),
          });
        } else {
          DateTime candidate = roll(nextRun);
          while (!candidate.isAfter(now)) {
            candidate = roll(candidate);
          }
          await d.reference.update({
            'nextRun': Timestamp.fromDate(candidate),
            'processedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] _processDueSchedules error: $e');
    }
  }

  Future<void> showNow({
    int id = 0,
    String? title,
    String? body,
  }) async {
    if (kIsWeb) return; // not supported on web
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'default_channel',
        'General',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  Future<void> scheduleIn({
    required Duration delay,
    int id = 1,
    String? title,
    String? body,
    bool exact = true,
  }) async {
    if (kIsWeb) return; // not supported on web
    final when = tz.TZDateTime.now(tz.local).add(delay);
    final details = NotificationDetails(
      android: AndroidNotificationDetails('default_channel', 'General'),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Schedule a notification at a specific time. If [repeatDaily] is true,
  /// it will repeat everyday at the specified time.
  ///
  /// Prefer using [frequency] for new code to support daily/weekly/monthly.
  /// [repeatDaily] is kept for backward compatibility.
  /// If [frequency] is [NotificationFrequency.oneTime] and [repeatDaily] is true,
  /// daily will be used.
  ///
  /// The first trigger uses the provided [when] (in local timezone). If a
  /// repeating frequency is used, subsequent triggers are controlled by
  /// matchDateTimeComponents.
  Future<bool> scheduleAt({
    required DateTime when,
    int id = 2,
    String? title,
    String? body,
    bool repeatDaily = false,
    NotificationFrequency frequency = NotificationFrequency.oneTime,
    bool exact = true,
    String? payload,
    NotificationDetails? details,
  }) async {
    if (kIsWeb) {
      debugPrint('[DEBUG] Web platform does not support scheduling');
      return false;
    }

    final tzWhen = tz.TZDateTime.from(when, tz.local);
    final NotificationDetails kDetails = details ??
        const NotificationDetails(
          android: AndroidNotificationDetails('default_channel', 'General'),
          iOS: DarwinNotificationDetails(),
        );

    debugPrint('[DEBUG] Scheduling notification:');
    debugPrint('  - ID: $id');
    debugPrint('  - When: $when (TZ: $tzWhen)');
    debugPrint('  - Title: $title');
    debugPrint('  - Body: $body');
    debugPrint('  - Exact: $exact');
    debugPrint('  - Payload: $payload');

    // Back-compat: upgrade frequency if repeatDaily=true
    if (frequency == NotificationFrequency.oneTime && repeatDaily) {
      frequency = NotificationFrequency.daily;
      debugPrint('  - Repeating: daily (repeatDaily=true)');
    } else {
      debugPrint('  - Frequency: ${frequency.toString().split('.').last}');
    }

    DateTimeComponents? components;
    switch (frequency) {
      case NotificationFrequency.oneTime:
        components = null;
        break;
      case NotificationFrequency.daily:
        components = DateTimeComponents.time;
        debugPrint('  - Will repeat daily at: ${when.hour}:${when.minute}');
        break;
      case NotificationFrequency.weekly:
        components = DateTimeComponents.dayOfWeekAndTime;
        debugPrint(
            '  - Will repeat weekly on ${when.weekday} at ${when.hour}:${when.minute}');
        break;
      case NotificationFrequency.monthly:
        components = DateTimeComponents.dayOfMonthAndTime;
        debugPrint(
            '  - Will repeat monthly on day ${when.day} at ${when.hour}:${when.minute}');
        break;
    }

    // Try exact scheduling first (best UX). If it fails (e.g., exact alarms not allowed),
    // fall back to inexact scheduling so the reminder still fires.
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        kDetails,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: components,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Exact schedule failed: $e');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzWhen,
          kDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: components,
          payload: payload,
        );
        debugPrint(
            '[NotificationService] Fallback to inexact schedule succeeded.');
        return true;
      } catch (e2) {
        debugPrint('[NotificationService] Inexact schedule failed: $e2');
        return false;
      }
    }
  }

  /// Helper to schedule a repeating daily notification at [hour]:[minute] (24-hour format)
  ///
  /// Set [exact] to true for precise timing (requires special permissions on Android 12+).
  /// If exact scheduling fails, it will automatically fall back to inexact scheduling.
  Future<bool> scheduleDailyAt({
    required int hour,
    required int minute,
    int id = nch.NotificationChannels.dailyReminderId,
    String title = 'Time to Track Your Expenses',
    String body =
        "Don't forget to log today's expenses 📒 (Scheduled for 9:00 PM)",
    bool exact = true,
  }) async {
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        nch.NotificationChannels.dailyReminderChannelId,
        nch.NotificationChannels.dailyReminderChannelName,
        channelDescription: 'Daily reminders to log expenses',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    return scheduleAt(
      when: when,
      id: id,
      title: title,
      body: body,
      frequency: NotificationFrequency.daily,
      exact: exact,
      payload: 'daily_reminder',
      details: details,
    );
  }

  /// Debug helper: schedule a test notification at 00:45
  Future<bool> scheduleDailyInMinutes(int minutes) async {
    try {
      final now = DateTime.now();
      // Set the target time to 00:45
      var when = DateTime(now.year, now.month, now.day, 0, 45);

      // If the time has already passed today, schedule for tomorrow
      if (when.isBefore(now)) {
        when = when.add(const Duration(days: 1));
      }

      debugPrint('[DEBUG] Current time: $now');
      debugPrint('[DEBUG] Scheduling test notification for: $when');

      // Schedule an immediate notification first to test
      final androidDetails = AndroidNotificationDetails(
        nch.NotificationChannels.dailyReminderChannelId,
        nch.NotificationChannels.dailyReminderChannelName,
        channelDescription: 'Test notification',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // 1. First test immediate notification
      await _plugin.show(
        9999, // High ID to avoid conflicts
        'Test Notification',
        'This is a test notification to verify the channel works',
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
      debugPrint('[DEBUG] Sent test notification');

      // 2. Try exact scheduling first
      bool result = await scheduleDailyAt(
        hour: when.hour,
        minute: when.minute,
        exact: true, // Try exact first
      );

      // 3. If exact scheduling failed, try inexact as fallback
      if (!result) {
        debugPrint('[DEBUG] Exact scheduling failed, trying inexact...');
        result = await scheduleDailyAt(
          hour: when.hour,
          minute: when.minute,
          exact: false, // Fallback to inexact
        );
        if (result) {
          debugPrint('[DEBUG] Inexact scheduling succeeded');
        }
      } else {
        debugPrint('[DEBUG] Exact scheduling succeeded');
      }

      // 4. Log all pending notifications
      if (!kIsWeb) {
        final pending = await _plugin.pendingNotificationRequests();
        debugPrint('[DEBUG] Pending notifications: ${pending.length}');
        for (final p in pending) {
          debugPrint(
              '  - ID: ${p.id}, Title: ${p.title}, Scheduled: ${p.payload}');
        }
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('[ERROR] Error in scheduleDailyInMinutes: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Public processor to perform the auto-add given a payload map.
  Future<void> processAutoAddPayload(Map<String, dynamic> map) async {
    try {
      // Check if this is an auto-add notification
      final bool auto = map['autoAdd'] == true || map['autoAdd'] == 'true';

      // Get the transaction type and ensure it's lowercase for consistency
      final String type = ((map['type'] as String?) ?? 'expense').toLowerCase();

      // For expense notifications, we want to process them even if autoAdd is false
      if (!auto && type != 'expense') return;

      // Ensure user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping auto-add');
        return;
      }

      // Prepare transaction data with proper defaults
      final String category = (map['category'] as String?)?.trim() ?? 'General';
      final String method = (map['method'] as String?)?.trim() ??
          (map['paymentMethod'] as String?)?.trim() ??
          'Cash';
      final String notes = (map['notes'] as String?)?.trim() ?? '';
      final String payeeItem =
          ((map['payeeItem'] ?? map['payee']) as String?)?.trim() ?? '';
      final String label = (map['label'] as String?)?.trim() ?? '';

      // Parse amount safely
      double? amount;
      final dynamic amountValue = map['amount'];
      if (amountValue is num) {
        amount = amountValue.toDouble();
      } else if (amountValue is String) {
        amount =
            double.tryParse(amountValue.replaceAll(RegExp(r'[^\d.-]'), ''));
      }

      // If amount is still null and this is an expense, log and return
      if (amount == null && type == 'expense') {
        debugPrint('Invalid amount for expense: ${map['amount']}');
        return;
      }

      // Prepare the transaction data
      final data = <String, dynamic>{
        if (amount != null) 'amount': amount,
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(DateTime.now()),
        'label': label,
        'notes': notes,
        'payeeItem': payeeItem,
        'type': type, // Store the type in lowercase for consistency
        'paymentMethod': method,
        'source': map['source'] ?? 'notification',
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .add(data);

      // Update schedule if this came from a scheduled expense
      final String? scheduleId = map['scheduleId'] as String?;
      if (scheduleId != null && scheduleId.isNotEmpty) {
        final scheduleRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('schedules')
            .doc(scheduleId);

        // Get the schedule to determine frequency
        final scheduleDoc = await scheduleRef.get();
        if (scheduleDoc.exists) {
          final scheduleData = scheduleDoc.data() as Map<String, dynamic>;
          final frequency = scheduleData['frequency'] as String? ?? 'one-time';

          if (frequency == 'one-time') {
            // Mark one-time schedule as inactive
            await scheduleRef.update({
              'isActive': false,
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
            });
          } else {
            // Update recurring schedule's next run time
            final now = DateTime.now();
            DateTime nextRun = _calculateNextRun(now, frequency);

            await scheduleRef.update({
              'nextRun': Timestamp.fromDate(nextRun),
              'occurrenceCount': FieldValue.increment(1),
              'lastProcessed': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // If this auto-add originated from Loan Planner, also record the installment
      final String? source = (map['source'] as String?);
      final String? loanId = (map['loanId'] as String?);
      if (source == 'loan' && loanId != null && loanId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('loans')
            .doc(loanId)
            .collection('installments')
            .add(<String, dynamic>{
          if (amount != null) 'amount': amount,
          'date': Timestamp.fromDate(DateTime.now()),
          'paymentType': 'Regular EMI',
          'createdAt': FieldValue.serverTimestamp(),
          'source': 'autoAdd',
        });
      }
    } catch (e) {
      debugPrint('[NotificationService] processAutoAddPayload error: $e');
    }
  }

// Helper function to calculate next run time for recurring schedules
  DateTime _calculateNextRun(DateTime from, String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly':
        DateTime nextMonth = DateTime(from.year, from.month + 1, from.day);
        // Handle cases where the day doesn't exist in the next month
        if (nextMonth.day != from.day) {
          nextMonth = DateTime(from.year, from.month + 2, 0);
        }
        return nextMonth;
      case 'yearly':
        return DateTime(from.year + 1, from.month, from.day);
      default:
        return from.add(const Duration(days: 1));
    }
  }

  Future<void> _handleNotificationResponse(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;

      // Handle auto-add income action
      if (map['action']?['type'] == 'auto_add_income') {
        final payload = map['action']?['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          // Add the income transaction
          await processAutoAddPayload(payload);

          // Show a confirmation
          await showNow(
            title: '✅ Income Added',
            body: 'Your income has been recorded successfully!',
          );
          return;
        }
      }
      // Handle auto-add expense action
      else if (map['action']?['type'] == 'auto_add_expense') {
        final payload = map['action']?['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          // Add the expense transaction
          await processAutoAddPayload(payload);

          // Show a confirmation
          await showNow(
            title: '✅ Expense Recorded',
            body: 'Your expense has been recorded successfully!',
          );
          return;
        }
      }
      // Handle auto-add transfer action
      else if (map['action']?['type'] == 'auto_add_transfer') {
        final payload = map['action']?['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          // Add the transfer transaction
          await processAutoAddPayload(payload);

          // Show a confirmation
          await showNow(
            title: '✅ Transfer Completed',
            body: 'Your transfer has been processed successfully!',
          );
          return;
        }
      }

      // Default handling for other notification types (legacy)
      await processAutoAddPayload(map);
    } catch (e) {
      debugPrint('Error handling notification response: $e');
      // Show error to user
      await showNow(
        title: '⚠️ Error',
        body: 'Failed to process notification. Please try again.',
      );
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Returns all pending scheduled notifications (platform allows retrieving
  /// id/title/body/payload, but not the exact scheduled time).
  Future<List<PendingNotificationRequest>> pendingRequests() async {
    if (kIsWeb) return <PendingNotificationRequest>[];
    return _plugin.pendingNotificationRequests();
  }
}
