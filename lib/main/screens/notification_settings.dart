import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../notifications/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  _NotificationSettingsScreenState createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _dailyReminderEnabled = false;
  final NotificationService _notificationService = NotificationService.instance;
  final String _dailyReminderKey = 'daily_reminder_enabled';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('is_first_time') ?? true;

    if (isFirstTime) {
      // First time user - enable daily reminder by default
      await prefs.setBool(_dailyReminderKey, true);
      await prefs.setBool('is_first_time', false);
      await _notificationService.scheduleDailyExpenseReminder();

      if (!mounted) return;
    }

    if (mounted) {
      setState(() {
        _dailyReminderEnabled = prefs.getBool(_dailyReminderKey) ?? false;
      });
    }
  }

  Future<void> _toggleDailyReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyReminderKey, value);

    if (value) {
      await _notificationService.scheduleDailyExpenseReminder();
    } else {
      await _notificationService.cancelDailyExpenseReminder();
    }

    if (!mounted) return;
    setState(() {
      _dailyReminderEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? cs.surface
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reminders Section
              _buildSectionHeader(theme, 'Reminders'),
              _buildSettingCard(
                context,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Daily Expense Reminder',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Get a daily reminder to log your expenses at 11:45 PM',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      value: _dailyReminderEnabled,
                      onChanged: _toggleDailyReminder,
                      activeColor: cs.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    // Test notification button is now in the Test Notifications section below
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Test Notifications Section
              _buildSectionHeader(theme, 'Test Notifications'),
              _buildSettingCard(
                context,
                child: Column(
                  children: [
                    // Schedule Test for 9:00 AM
                    _buildActionButton(
                      context: context,
                      icon: Icons.schedule_rounded,
                      label: 'Schedule for 9:00 AM',
                      description: 'Schedule the daily reminder for 9:00 AM',
                      onTap: () async {
                        await _notificationService.scheduleDaily0900Reminder();
                        if (!mounted) return;
                        if (context.mounted) {
                          _showSnackBar(
                            context,
                            '✅ Daily reminder scheduled for 9:00 AM',
                          );
                        }
                      },
                    ),
                    _buildActionButton(
                      context: context,
                      icon: Icons.list_alt_rounded,
                      label: 'Show Pending Notifications',
                      description: 'Debug: View scheduled notifications',
                      onTap: () async {
                        final pending = await _notificationService
                            .getPendingNotifications();
                        if (!mounted) return;
                        if (context.mounted) {
                          _showSnackBar(
                            context,
                            'Pending notifications: ${pending.length}',
                          );
                        }
                      },
                      isDebug: true,
                    ),
                  ],
                ),
              ),

              // Help Text
              Padding(
                padding:
                    const EdgeInsets.only(top: 16.0, left: 8.0, right: 8.0),
                child: Text(
                  'Make sure notifications are enabled in your device settings for this app to receive reminders.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    bool isDebug = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDebug
                      ? (cs.tertiaryContainer)
                      : (cs.primaryContainer.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDebug ? cs.onTertiaryContainer : cs.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDebug ? cs.tertiary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDebug
                            ? cs.onTertiaryContainer.withValues(alpha: 0.8)
                            : theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.iconTheme.color?.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
