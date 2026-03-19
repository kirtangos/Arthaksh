import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

Future<void> showAuthChoiceSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)), // Reduced from 16 proportionally
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16), // Reduced from 20,8,20,20 proportionally
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.person_rounded, color: cs.primary, size: 18), // Reduced from default proportionally
                  const SizedBox(width: 6), // Reduced from 8 proportionally
                  Text(
                    'Welcome to Arthaksh',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith( // Reduced from titleLarge
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          fontSize: 18, // Reduced proportionally
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8), // Reduced from 10 proportionally
              Text(
                'Log in or create an account to continue.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith( // Reduced from bodyMedium
                      color: cs.onSurface.withValues(alpha: 0.8),
                      fontSize: 12, // Reduced proportionally
                    ),
              ),
              const SizedBox(height: 12), // Reduced from 16 proportionally
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Log in'),
                    ),
                  ),
                  const SizedBox(width: 10), // Reduced from 12 proportionally
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Register'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
