import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Requests runtime notification permissions on Android/iOS.
Future<void> requestPermissions(
  FlutterLocalNotificationsPlugin plugin,
  TargetPlatform platform,
) async {
  if (platform == TargetPlatform.android) {
    final androidImpl = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  } else if (platform == TargetPlatform.iOS) {
    final iosImpl =
        plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
