import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = AppThemeController.instance;

    final colors = <Color>[
      const Color(0xFF0D9488), // teal
      const Color(0xFF2563EB), // blue
      const Color(0xFF9333EA), // purple
      const Color(0xFFEA580C), // orange
      const Color(0xFF16A34A), // green
      const Color(0xFFE11D48), // rose
    ];

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        title: const Text('Theme Settings'),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Accent color section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accent color',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<Color>(
                            valueListenable: themeCtrl.seedColor,
                            builder: (context, seed, _) {
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final c in colors)
                                    _AccentDot(
                                      color: c,
                                      selected: c.toARGB32() == seed.toARGB32(),
                                      onTap: () =>
                                          themeCtrl.seedColor.value = c,
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _AccentDot(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color:
                selected ? Colors.black.withValues(alpha: 0.45) : borderColor,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
      ),
    );
  }
}
