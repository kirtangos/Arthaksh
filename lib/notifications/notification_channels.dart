import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification channel IDs and names
class NotificationChannels {
  // Daily reminder notification channel
  static const String dailyReminderChannelId = 'daily_reminder_channel';
  static const String dailyReminderChannelName = 'Daily Reminders';
  static const int dailyReminderId = 1001; // Unique ID for the daily reminder notification
  
  // 1:55 AM daily notification channel
  static const String daily0155ChannelId = 'daily_0155_channel';
  static const String daily0155ChannelName = 'Daily 1:55 AM Reminder';
  static const int daily0155Id = 1002; // Unique ID for the 1:55 AM notification
  
  // Reminder notification channel
  static const String reminderChannelId = 'reminder_channel';
  static const String reminderChannelName = 'Payment Reminders';
  static const String reminderChannelDescription = 'Notifications for upcoming and due payments';
  
  // Test notification channel
  static const String testChannelId = 'test_channel';
  static const String testChannelName = 'Test Notifications';
  static const int testNotificationId = 9999;
  
  // Scheduled expense notification channel
  static const String scheduledExpenseChannelId = 'scheduled_expense_channel';
  static const String scheduledExpenseChannelName = 'Scheduled Expenses';
  static const String scheduledExpenseChannelDesc = 'Notifications for scheduled expenses';
  static const int scheduledExpenseId = 1003;
  
  // Ensure the reminder channel is created
  static Future<void> ensureReminderChannel(FlutterLocalNotificationsPlugin plugin) async {
    final androidChannel = AndroidNotificationChannel(
      reminderChannelId,
      reminderChannelName,
      description: reminderChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }
}

// Creates and ensures the default Android notification channels exist.
Future<void> ensureDefaultAndroidChannel(
  FlutterLocalNotificationsPlugin plugin,
) async {
  final androidImpl = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  
  if (androidImpl == null) return;
  
  // Create default channel
  await androidImpl.createNotificationChannel(
    const AndroidNotificationChannel(
      'default_channel',
      'General',
      description: 'General notifications',
      importance: Importance.high,
      enableVibration: true,
      showBadge: true,
    ),
  );
  
  // Create daily reminder channel
  await androidImpl.createNotificationChannel(
    const AndroidNotificationChannel(
      NotificationChannels.dailyReminderChannelId,
      NotificationChannels.dailyReminderChannelName,
      description: 'Daily reminders to log expenses',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    ),
  );
  
  // Create test notification channel
  await androidImpl.createNotificationChannel(
    const AndroidNotificationChannel(
      NotificationChannels.testChannelId,
      NotificationChannels.testChannelName,
      description: 'Test notifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: false,
      sound: RawResourceAndroidNotificationSound('notification'),
    ),
  );
  
  // Create 1:55 AM daily notification channel
  await androidImpl.createNotificationChannel(
    const AndroidNotificationChannel(
      NotificationChannels.daily0155ChannelId,
      NotificationChannels.daily0155ChannelName,
      description: 'Daily reminder at 1:55 AM',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    ),
  );
}
