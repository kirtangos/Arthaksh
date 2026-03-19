import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import '../main/firebase_options.dart';
import 'package:arthaksh/services/facts_service.dart';
import 'package:arthaksh/notifications/notification_service.dart';
import 'package:arthaksh/services/reminder_service.dart';
import 'package:arthaksh/providers/category_label_provider.dart';
import '../main/core/auth_service.dart';
import '../main/core/app_widget.dart';

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure global logging handler
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint(
        '[${record.level.name}] ${record.loggerName}: ${record.message}');
    if (record.error != null) {
      debugPrint('  error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('  stack: ${record.stackTrace}');
    }
  });

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Clear fact history on app start (for testing)
  final factsService = FactsService();
  await factsService.clearFactHistory();

  // Initialize notification services
  await NotificationService.instance.init();

  // Initialize ReminderService to handle past-due reminders
  final reminderService = ReminderService();
  await reminderService.initialize();

  // TODO: WorkManager removed due to compatibility issues
  // Background processing will only work when app is open
  debugPrint(
      'WorkManager disabled - scheduled expenses process only when app is open');

  // Schedule the daily 9:00 AM reminder
  await NotificationService.instance.scheduleDaily0900Reminder();

  // Ensure persistent auth on web builds
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  // Wait for initial auth state restoration
  try {
    await FirebaseAuth.instance.authStateChanges().first;
  } catch (_) {
    // ignore; proceed to app
  }

  // Initialize auth service
  await AuthService.initialize();

  // Initialize local notifications again (redundant but safe)
  await NotificationService.instance.init();
  await NotificationService.instance.scheduleDaily0900Reminder();
}

Future<void> main() async {
  await initializeApp();

  runApp(ChangeNotifierProvider(
    create: (_) => CategoryLabelProvider()..initialize(),
    child: const AppWidget(),
  ));
}
