import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../notifications/notification_service.dart';
import '../../services/settings_service.dart';
import '../../ui/app_theme.dart';
import '../../ui/noise_decoration.dart';
import 'currency_converter_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _showFacts = true;
  bool _darkTheme = false;
  String _selectedCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkNotificationStatus();
  }

  Future<void> _loadSettings() async {
    final showFacts = await SettingsService.getShowFacts();
    final selectedCurrency = await SettingsService.getSelectedCurrency();
    final darkTheme = await SettingsService.getDarkTheme();
    if (mounted) {
      setState(() {
        _showFacts = showFacts;
        _selectedCurrency = selectedCurrency;
        _darkTheme = darkTheme;
      });
    }
  }

  // Logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                // After logout, you might want to navigate to login screen
                // Navigator.pushReplacementNamed(context, '/login');
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  // Modern section header with enhanced styling
  Widget _buildSectionHeader(String title, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark
              ? theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.95) // Brightened for readability
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
          letterSpacing: 1.2, // Increased letter spacing
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  // Modern card with enhanced separation and subtle glow
  Widget _buildSettingCard(BuildContext context,
      {required Widget child, bool hasActiveElement = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 4), // Increased vertical separation
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh // Layer 3 depth
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isDark
            ? Border.all(
                color: theme.colorScheme.outline
                    .withValues(alpha: 0.2), // Subtle border only
                width: 0.5,
              )
            : null,
        boxShadow: isDark
            ? [
                // Enhanced layered shadows with teal glow for active elements
                if (hasActiveElement) ...[
                  // Subtle teal glow
                  BoxShadow(
                    color: const Color(0xFF00897b).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                    spreadRadius: 0.5,
                  ),
                ],
                // Base shadows
                BoxShadow(
                  color: const Color(0xFF0A1416)
                      .withValues(alpha: 0.4), // Increased shadow intensity
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : [
                // Light theme enhanced shadow
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }

  // Modern setting tile with smooth interaction
  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? iconBackground,
    bool showDivider = true,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(10), // Reduced from 12 proportionally
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10), // Reduced from 16,12 proportionally
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 36, // Reduced from 40 proportionally
                    height: 36, // Reduced from 40 proportionally
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? Colors.red.withValues(alpha: 0.15)
                          : (iconBackground ??
                              (isDark
                                  ? colorScheme.primaryContainer
                                      .withValues(alpha: 0.4)
                                  : const Color(0xFF00897b)
                                      .withValues(alpha: 0.1))),
                      borderRadius: BorderRadius.circular(10),
                      border: isDark && !isDestructive
                          ? Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                              width: 0.5,
                            )
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 20, // Changed from 18
                      color: isDestructive
                          ? Colors.red
                          : (iconColor ??
                              (isDark
                                  ? colorScheme.onPrimaryContainer
                                  : const Color(0xFF00897b))),
                    ),
                  ),
                  const SizedBox(width: 16), // Changed from 12

                  // Title and subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            // Reduced from bodyLarge
                            color: isDestructive
                                ? Colors.red
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 14, // Reduced proportionally
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(
                              height: 1), // Reduced from 2 proportionally
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDestructive
                                  ? Colors.red.withValues(alpha: 0.8)
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 11, // Reduced proportionally
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Trailing widget or chevron
                  if (trailing != null)
                    trailing
                  else if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18, // Reduced from 20 proportionally
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Divider
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(
                left: 60, right: 12), // Reduced from 72,16 proportionally
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }

  Future<void> _toggleShowFacts(bool value) async {
    await SettingsService.setShowFacts(value);
    if (mounted) {
      setState(() {
        _showFacts = value;
      });
    }
  }

  Future<void> _toggleDarkTheme(bool value) async {
    final themeCtrl = AppThemeController.instance;
    await themeCtrl.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
    if (mounted) {
      setState(() {
        _darkTheme = value;
      });
    }
  }

  Future<void> _selectCurrency() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Currency'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: SettingsService.majorCurrencies.length,
              itemBuilder: (BuildContext context, int index) {
                final currency = SettingsService.majorCurrencies[index];
                return ListTile(
                  title: Text(currency['name']!),
                  leading: Text(currency['code']!,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.of(context).pop(currency['code']),
                  selected: _selectedCurrency == currency['code'],
                  selectedColor: Theme.of(context).colorScheme.primary,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected != null && selected != _selectedCurrency) {
      await SettingsService.setSelectedCurrency(selected);
      if (mounted) {
        setState(() {
          _selectedCurrency = selected;
        });
      }
    }
  }

  Future<void> _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationsEnabled = status.isGranted;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Request notification permission
      final status = await Permission.notification.request();
      setState(() {
        _notificationsEnabled = status.isGranted;
      });

      if (status.isGranted) {
        // Initialize notifications if permission granted
        await NotificationService.instance.init();
      }
    } else {
      // If user turns off notifications, we can't revoke the permission,
      // but we can stop showing them
      setState(() {
        _notificationsEnabled = false;
      });
      // Optionally, you might want to cancel all scheduled notifications here
      // await NotificationService.instance.cancelAllNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        centerTitle: false,
      ),
      body: Container(
        decoration: isDark
            ? const NoiseDecoration(
                color: Color(0xFF00897b),
                opacity: 0.02,
              )
            : null,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              sliver: SliverToBoxAdapter(
                child: _buildSectionHeader('Account', context),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingCard(
                context,
                child: _buildSettingTile(
                  context: context,
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                  trailing: Switch.adaptive(
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeColor: theme.colorScheme.primary,
                  ),
                  showDivider: false,
                ),
              ),
            ),

            // Preferences Section
            SliverPadding(
              padding: const EdgeInsets.only(
                  top: 20, bottom: 6), // Reduced from 24,8 proportionally
              sliver: SliverToBoxAdapter(
                child: _buildSectionHeader('Preferences', context),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingCard(
                context,
                hasActiveElement: true, // This card has active switches
                child: Column(
                  children: [
                    _buildSettingTile(
                      context: context,
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Theme',
                      subtitle: 'Use dark theme across the app',
                      trailing: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow:
                              _darkTheme && theme.brightness == Brightness.dark
                                  ? [
                                      // Subtle teal glow for ON switches in dark theme
                                      BoxShadow(
                                        color: const Color(0xFF00897b)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 0),
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                        ),
                        child: Switch.adaptive(
                          value: _darkTheme,
                          onChanged: _toggleDarkTheme,
                          activeColor: theme.brightness == Brightness.dark
                              ? const Color(0xFF00897b)
                              : const Color(0xFF00897b),
                          activeTrackColor: theme.brightness == Brightness.dark
                              ? const Color(0xFF00897b).withValues(alpha: 0.3)
                              : null,
                        ),
                      ),
                    ),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.emoji_objects_outlined,
                      title: 'Show Financial Facts',
                      subtitle: 'Show interesting financial facts and tips',
                      trailing: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow:
                              _showFacts && theme.brightness == Brightness.dark
                                  ? [
                                      // Subtle teal glow for ON switches in dark theme
                                      BoxShadow(
                                        color: const Color(0xFF00897b)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 0),
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                        ),
                        child: Switch.adaptive(
                          value: _showFacts,
                          onChanged: _toggleShowFacts,
                          activeColor: theme.brightness == Brightness.dark
                              ? const Color(0xFF00897b)
                              : const Color(0xFF00897b),
                          activeTrackColor: theme.brightness == Brightness.dark
                              ? const Color(0xFF00897b).withValues(alpha: 0.3)
                              : null,
                        ),
                      ),
                    ),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.language_outlined,
                      title: 'Language',
                      subtitle: 'Change app language',
                      onTap: () {
                        // TODO: Implement language settings
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Language settings coming soon')),
                        );
                      },
                    ),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.currency_exchange_outlined,
                      title: 'Currency',
                      subtitle:
                          '${SettingsService.majorCurrencies.firstWhere((c) => c['code'] == _selectedCurrency)['name']} ($_selectedCurrency)',
                      onTap: _selectCurrency,
                    ),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.swap_horiz_outlined,
                      title: 'Currency Converter',
                      subtitle: 'Convert between different currencies',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const CurrencyConverterScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Support Section
            SliverPadding(
              padding: const EdgeInsets.only(
                  top: 20, bottom: 6), // Reduced from 24,8 proportionally
              sliver: SliverToBoxAdapter(
                child: _buildSectionHeader('Support', context),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingCard(
                context,
                child: Column(
                  children: [
                    _buildSettingTile(
                      context: context,
                      icon: Icons.help_outline_rounded,
                      title: 'Help Center',
                      subtitle: 'Find answers to common questions',
                      onTap: () {
                        // TODO: Open help center
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Help center coming soon')),
                        );
                      },
                    ),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.email_outlined,
                      title: 'Contact Us',
                      subtitle: 'Get in touch with our support team',
                      onTap: () {
                        // TODO: Open contact form
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Contact form coming soon')),
                        );
                      },
                    ),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Learn how we handle your data',
                      onTap: () {
                        // TODO: Open privacy policy
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Privacy policy coming soon')),
                        );
                      },
                    ),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'App version and information',
                      onTap: () {
                        // TODO: Open about screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('About screen coming soon')),
                        );
                      },
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),

            // Logout Button (only show if user is logged in)
            if (FirebaseAuth.instance.currentUser != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 12), // Reduced from 24,16 proportionally
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => _showLogoutConfirmation(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.brightness == Brightness.dark
                            ? const Color(0xFF4A1F1F).withValues(
                                alpha: 0.6) // Dark red with teal hint
                            : Colors.red.shade50,
                        foregroundColor: theme.brightness == Brightness.dark
                            ? const Color(
                                0xFFE57373) // Muted red for dark theme
                            : Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: theme.brightness == Brightness.dark
                              ? BorderSide(
                                  color: const Color(0xFF4A1F1F)
                                      .withValues(alpha: 0.3),
                                  width: 0.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                      child: const Text('Log Out',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),

            // App Version
            SliverPadding(
              padding: const EdgeInsets.only(
                  bottom: 20, top: 6), // Reduced from 24,8 proportionally
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    'Arthaksh v1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 11, // Reduced proportionally
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
