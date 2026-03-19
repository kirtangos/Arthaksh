import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/noise_decoration.dart';

class AccountDrawer extends StatelessWidget {
  const AccountDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      width: 280, // Make drawer thinner
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
      child: Container(
        decoration: isDark
            ? const NoiseDecoration(
                color: Color(0xFF00897b),
                opacity: 0.02,
              )
            : null,
        child: Column(
          children: [
            // Revamped header with modern design
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF00897b).withValues(alpha: 0.9),
                          const Color(0xFF00564d).withValues(alpha: 0.8),
                        ]
                      : [
                          cs.primary,
                          cs.primary.withValues(alpha: 0.8),
                        ],
                ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0A1416).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced avatar with modern design
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00897b)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white,
                      child: Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0].toUpperCase()
                            : user?.email?.isNotEmpty == true
                                ? user!.email![0].toUpperCase()
                                : 'U',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF00897b) : cs.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Enhanced user info
                  Text(
                    user?.displayName ?? 'User',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Section divider
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  Colors.transparent,
                                  cs.outline.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ]
                              : [
                                  Colors.transparent,
                                  cs.outline.withValues(alpha: 0.2),
                                  Colors.transparent,
                                ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'MENU',
                      style: TextStyle(
                        color: isDark
                            ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                            : cs.onSurfaceVariant.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  Colors.transparent,
                                  cs.outline.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ]
                              : [
                                  Colors.transparent,
                                  cs.outline.withValues(alpha: 0.2),
                                  Colors.transparent,
                                ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Enhanced menu items with modern design
            _buildMenuTile(
              context,
              icon: user?.emailVerified == true
                  ? Icons.verified_user_rounded
                  : Icons.email_rounded,
              title: user?.emailVerified == true
                  ? 'Email Verified'
                  : 'Verify Email',
              subtitle: user?.emailVerified == false
                  ? 'Tap to resend verification email'
                  : null,
              iconColor: user?.emailVerified == true
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF00897b),
              onTap: () {
                if (user?.emailVerified == false) {
                  user?.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Verification email sent!'),
                      backgroundColor: isDark
                          ? const Color(0xFF00897b).withValues(alpha: 0.9)
                          : cs.primary,
                    ),
                  );
                }
                Navigator.pop(context);
              },
              isDark: isDark,
              cs: cs,
            ),
            _buildMenuTile(
              context,
              icon: Icons.settings_rounded,
              title: 'Settings',
              iconColor: const Color(0xFF00897b),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
              isDark: isDark,
              cs: cs,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            // Logout section - only show when user is logged in
            if (user != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 2), // Match shorter button style
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF4A1F1F).withValues(alpha: 0.3)
                      : cs.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(
                          color: const Color(0xFFE57373).withValues(alpha: 0.3),
                          width: 0.5,
                        )
                      : null,
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF4A1F1F).withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4), // Further reduced padding
                  leading: Container(
                    padding: const EdgeInsets.all(6), // Smaller icon container
                    decoration: BoxDecoration(
                      color: const Color(0xFFE57373).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: isDark
                          ? const Color(0xFFE57373)
                          : Colors.red.withValues(alpha: 0.8),
                      size: 18, // Smaller icon
                    ),
                  ),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFE57373)
                          : Colors.red.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 14, // Smaller font
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method for building modern menu tiles
  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDark,
    required ColorScheme cs,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 2), // Increased horizontal margin to make buttons shorter
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainer : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: isDark
            ? Border.all(
                color: cs.outline.withValues(alpha: 0.2),
                width: 0.5,
              )
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF0A1416).withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4), // Further reduced padding
        leading: Container(
          padding: const EdgeInsets.all(6), // Smaller icon container
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18, // Smaller icon
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? cs.onSurface : cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14, // Smaller
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: isDark
                      ? cs.onSurfaceVariant.withValues(alpha: 0.8)
                      : cs.onSurfaceVariant,
                  fontSize: 11, // Smaller subtitle
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
