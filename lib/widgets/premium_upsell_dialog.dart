import 'package:flutter/material.dart';

class PremiumUpsellDialog extends StatelessWidget {
  final String featureName;
  final String description;
  final VoidCallback? onUpgrade;
  final VoidCallback? onLater;

  const PremiumUpsellDialog({
    super.key,
    required this.featureName,
    required this.description,
    this.onUpgrade,
    this.onLater,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String featureName,
    required String description,
    VoidCallback? onUpgrade,
    VoidCallback? onLater,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumUpsellDialog(
        featureName: featureName,
        description: description,
        onUpgrade: onUpgrade,
        onLater: onLater,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                    (colorScheme.onSurface.r * 255.0).round() & 0xff,
                    (colorScheme.onSurface.g * 255.0).round() & 0xff,
                    (colorScheme.onSurface.b * 255.0).round() & 0xff,
                    0.2,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title with medal icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(
                      (colorScheme.primary.r * 255.0).round() & 0xff,
                      (colorScheme.primary.g * 255.0).round() & 0xff,
                      (colorScheme.primary.b * 255.0).round() & 0xff,
                      0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Premium Feature',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),

            // Action buttons row (Maybe Later | Upgrade)
            Row(
              children: [
                // Maybe Later - outlined pill
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                      onLater?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: Color.fromRGBO(
                          (colorScheme.outline.r * 255.0).round() & 0xff,
                          (colorScheme.outline.g * 255.0).round() & 0xff,
                          (colorScheme.outline.b * 255.0).round() & 0xff,
                          0.4,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      foregroundColor: colorScheme.primary,
                      backgroundColor: Colors.white,
                    ),
                    child: const Text('Maybe Later'),
                  ),
                ),
                const SizedBox(width: 12),
                // Upgrade - outlined with teal star icon
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, true);
                      onUpgrade?.call();
                    },
                    icon: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    label: const Text('Upgrade'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: Color.fromRGBO(
                          (colorScheme.primary.r * 255.0).round() & 0xff,
                          (colorScheme.primary.g * 255.0).round() & 0xff,
                          (colorScheme.primary.b * 255.0).round() & 0xff,
                          0.25,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      foregroundColor: colorScheme.primary,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            // Minimal bottom padding
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
