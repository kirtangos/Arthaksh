import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arthaksh/services/facts_service.dart';
import 'package:logging/logging.dart';

class FactPopup extends StatefulWidget {
  final VoidCallback? onDismissed;
  final Duration displayDuration;

  const FactPopup({
    super.key,
    this.onDismissed,
    this.displayDuration = const Duration(seconds: 10),
  });

  static final _logger = Logger('FactPopup');

  static Future<bool> shouldShowFacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('show_facts') ?? true; // Default to true if not set
    } catch (e) {
      _logger.warning('Error reading facts setting', e);
      return true; // Default to showing facts if there's an error
    }
  }

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDismissed,
    Duration displayDuration = const Duration(seconds: 10),
  }) async {
    // Check if facts should be shown
    final shouldShow = await shouldShowFacts();
    if (!shouldShow) {
      onDismissed?.call();
      return;
    }

    // Prevent multiple popups from being shown simultaneously
    try {
      // Dismiss any existing fact popup first
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

      // Get the screen size
      final mediaQuery = MediaQuery.of(context);

      // Show the popup as an overlay
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        routeSettings: const RouteSettings(name: 'fact_popup'),
        builder: (BuildContext context) {
          return PopScope(
            canPop: true,
            onPopInvoked: (didPop) {
              if (didPop) {
                onDismissed?.call();
              }
            },
            child: Stack(
              children: [
                // Semi-transparent background
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onDismissed?.call();
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                // Position the popup at the bottom
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24 + mediaQuery.viewInsets.bottom, // Account for keyboard
                  child: FactPopup(
                    onDismissed: onDismissed,
                    displayDuration: displayDuration,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      // If there's an error showing the popup, just log the error
      // This prevents crashes when the popup is dismissed while being shown
      _logger.warning('Error showing fact popup', e);
    }
  }

  @override
  State<FactPopup> createState() => _FactPopupState();
}

class _FactPopupState extends State<FactPopup> {
  late Future<Fact?> _factFuture;
  Timer? _dismissTimer;
  Timer? _animationDismissTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the next fact in sequence when the widget is shown
    _factFuture = factsService.getNextFact();
    _startDismissTimer();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationDismissTimer?.cancel();
    _factFuture = Future.value(null); // Clear the future to prevent memory leaks
    super.dispose();
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(widget.displayDuration, () {
      if (mounted) {
        // Cancel the animation timer to prevent double dismissal
        _animationDismissTimer?.cancel();
        Navigator.of(context).pop();
        widget.onDismissed?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12), // Increased from 8 for more curves
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), // Increased from 8 for more curves
                topRight: Radius.circular(12), // Increased from 8 for more curves
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 14, // Further reduced from 16
                ),
                const SizedBox(width: 4), // Further reduced from 6
                Text(
                  'Did You Know?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Further reduced from 14
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onDismissed?.call();
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 16, // Further reduced from 18
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(10), // Further reduced from 12
            child: FutureBuilder<Fact?>(
              future: _factFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    heightFactor: 1.2, // Further reduced from 1.5
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final fact = snapshot.data;
                
                if (fact == null || (fact.text.isEmpty && fact.description.isEmpty)) {
                  // Don't show popup if no facts available (e.g., already shown this session)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      widget.onDismissed?.call();
                    }
                  });
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category chip
                    if (fact.category != null && fact.category!.isNotEmpty) 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0), // Further reduced from 8.0
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, // Further reduced from 8
                            vertical: 2, // Further reduced from 4
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8), // Increased from 6 for more curves
                          ),
                          child: Text(
                            fact.category!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 10, // Further reduced from 11
                            ),
                          ),
                        ),
                      ),
                    
                    // Fact text
                    if (fact.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0), // Further reduced from 6.0
                        child: Text(
                          fact.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13, // Further reduced from 14
                            height: 1.2, // Further reduced from 1.3
                          ),
                        ),
                      ),
                    
                    // Description (if available)
                    if (fact.description.isNotEmpty && fact.description != fact.text)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0), // Further reduced from 6.0
                        child: Text(
                          fact.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 11, // Further reduced from 12
                            height: 1.2, // Further reduced from 1.3
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Progress indicator at the bottom
          const SizedBox(height: 8), // Further reduced from 12
          TweenAnimationBuilder<Duration>(
            duration: widget.displayDuration,
            tween: Tween(
              begin: widget.displayDuration,
              end: Duration.zero,
            ),
            onEnd: () {
              if (mounted) {
                // Cancel the main timer to prevent double dismissal
                _dismissTimer?.cancel();
                Navigator.of(context).pop();
                widget.onDismissed?.call();
              }
            },
            builder: (_, Duration value, __) {
              final progress = value.inMilliseconds / widget.displayDuration.inMilliseconds;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10), // Reduced from 12
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2), // Increased from 1 for more curves
                  child: LinearProgressIndicator(
                    value: 1 - progress, // Invert the progress to show countdown
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                    minHeight: 2, // Further reduced from 3
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8), // Further reduced from 12, added bottom padding
        ],
      ),
    );
  }
}
