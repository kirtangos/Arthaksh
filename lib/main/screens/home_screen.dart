import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/account_drawer.dart';
import 'calculations_screen.dart';
import 'expense_tracker_screen.dart';
import 'loan_planner/loan_planner.dart';
import 'glossary_list.dart';
import 'goal_planner/goal_planner.dart';
import '../auth_choice_sheet.dart';
import '../../widgets/fact_popup.dart';
import '../../ui/noise_decoration.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _factPopupShown = false;

  @override
  void initState() {
    super.initState();
    // Show fact popup after the first frame is rendered (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_factPopupShown) {
        _factPopupShown = true;
        FactPopup.show(context, onDismissed: () {
          // Optional: Handle popup dismissal if needed
        });
      }
    });
  }

  Future<void> _ensureAuthOrPrompt(
      BuildContext context, VoidCallback onAuthed) async {
    if (FirebaseAuth.instance.currentUser == null) {
      // Prompt for auth
      await showAuthChoiceSheet(context);
      // Auto-continue if user authenticated after sheet
      if (FirebaseAuth.instance.currentUser != null) {
        onAuthed();
      }
    } else {
      onAuthed();
    }
  }

  void _goToCalculations() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CalculationsScreen(),
      ),
    );
  }

  void _goToExpenseTracker() {
    _ensureAuthOrPrompt(context, () {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ExpenseTrackerScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      drawer: const AccountDrawer(),
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          // Refresh Firebase user to reflect emailVerified/displayName changes
          FirebaseAuth.instance.currentUser?.reload().then((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      },
      body: Container(
        decoration: isDark
            ? const NoiseDecoration(
                color: Color(0xFF00897b),
                opacity: 0.02,
              )
            : null,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero card with refined dark theme
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(16)),
                        color: isDark
                            ? cs.surfaceContainerHigh // Layer 3 depth
                            : cs.surface,
                        gradient: isDark
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF00897b)
                                      .withValues(alpha: 0.1),
                                  const Color(0xFF00564d)
                                      .withValues(alpha: 0.08),
                                ],
                              )
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  cs.primary.withValues(alpha: 0.14),
                                  cs.secondary.withValues(alpha: 0.14),
                                ],
                              ),
                        border: isDark
                            ? Border.all(
                                color: cs.outline.withValues(alpha: 0.2),
                                width: 0.5,
                              )
                            : Border.all(
                                color: cs.primary.withValues(alpha: 0.28),
                                width: 1,
                              ),
                        boxShadow: isDark
                            ? [
                                // Enhanced layered shadows for hero card
                                BoxShadow(
                                  color: const Color(0xFF0A1416)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF1A1A1A)
                                      .withValues(alpha: 0.6),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: cs.shadow.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded,
                                  color: isDark
                                      ? const Color(0xFF00897b)
                                      : cs.primary),
                              const SizedBox(width: 8),
                              // Clean, bold branding title (no gradients)
                              Text(
                                'Arthaksh',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Plan loans, track expenses, and run beautiful financial calculations — all in one cohesive experience.',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.85),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Primary action cards
                    LayoutBuilder(builder: (context, c) {
                      final isWide = c.maxWidth >= 640;
                      Widget actionCard({
                        required Color accent,
                        required IconData icon,
                        required String title,
                        required String subtitle,
                        required VoidCallback onTap,
                      }) {
                        return InkWell(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(16)),
                          onTap: onTap,
                          overlayColor:
                              WidgetStateProperty.resolveWith((states) {
                            final a = accent;
                            if (states.contains(WidgetState.pressed)) {
                              return a.withValues(alpha: 0.10);
                            }
                            if (states.contains(WidgetState.hovered)) {
                              return a.withValues(alpha: 0.06);
                            }
                            if (states.contains(WidgetState.focused)) {
                              return a.withValues(alpha: 0.08);
                            }
                            return a.withValues(alpha: 0.04);
                          }),
                          splashFactory: InkRipple.splashFactory,
                          child: Container(
                            padding: const EdgeInsets.all(
                                12), // Reduced from 16 for more compact design
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                  Radius.circular(
                                      12)), // Reduced from 16 for more compact
                              color: isDark
                                  ? cs.surfaceContainer // Layer 2 depth
                                  : cs.surface,
                              gradient: isDark
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        accent.withValues(alpha: 0.12),
                                        cs.surfaceContainer
                                            .withValues(alpha: 0.8),
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        accent.withValues(alpha: 0.16),
                                        cs.surface.withValues(alpha: 0.92),
                                      ],
                                    ),
                              border: isDark
                                  ? Border.all(
                                      color: cs.outline.withValues(alpha: 0.2),
                                      width: 0.5,
                                    )
                                  : Border.all(
                                      color: cs.outlineVariant
                                          .withValues(alpha: 0.55),
                                    ),
                              boxShadow: isDark
                                  ? [
                                      // Enhanced layered shadows for action cards
                                      BoxShadow(
                                        color: const Color(0xFF0A1416)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF1A1A1A)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 1,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.03),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36, // Reduced from 44 for more compact
                                  height:
                                      36, // Reduced from 44 for more compact
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent.withValues(alpha: 0.22),
                                    border: Border.all(
                                        color: accent.withValues(alpha: 0.38)),
                                  ),
                                  child: Icon(icon,
                                      color: accent,
                                      size:
                                          18), // Reduced icon size from default
                                ),
                                const SizedBox(width: 10), // Reduced from 12
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall // Reduced from titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: accent,
                                                  fontSize:
                                                      14)), // Reduced font size
                                      const SizedBox(
                                          height: 1), // Reduced from 2
                                      Text(subtitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.75),
                                                  fontSize:
                                                      11)), // Reduced font size
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_rounded,
                                    color: accent,
                                    size: 16), // Reduced icon size
                              ],
                            ),
                          ),
                        );
                      }

                      final left = actionCard(
                        accent: Theme.of(context).colorScheme.primary,
                        icon: Icons.calculate_rounded,
                        title: 'Calculations',
                        subtitle: 'All financial calculators',
                        onTap: _goToCalculations,
                      );
                      final right = actionCard(
                        accent: Theme.of(context).colorScheme.primary,
                        icon: Icons.receipt_long_rounded,
                        title: 'Track Expense',
                        subtitle: 'Log and analyze spending',
                        onTap: _goToExpenseTracker,
                      );
                      final loanPlanner = actionCard(
                        accent: Theme.of(context).colorScheme.primary,
                        icon: Icons.request_quote_rounded,
                        title: 'Loan Planner',
                        subtitle: 'Plan and manage loans',
                        onTap: () {
                          _ensureAuthOrPrompt(context, () {
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LoanPlannerScreen(),
                                ),
                              );
                            }
                          });
                        },
                      );
                      final learn = actionCard(
                        accent: Theme.of(context).colorScheme.primary,
                        icon: Icons.lightbulb_rounded,
                        title: 'Learn',
                        subtitle: 'Finance tips and guides',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GlossaryListScreen(),
                            ),
                          );
                        },
                      );
                      final goalPlanner = actionCard(
                        accent: Theme.of(context).colorScheme.primary,
                        icon: Icons.flag_rounded,
                        title: 'Goal Planner',
                        subtitle: 'Plan and track goals',
                        onTap: () {
                          _ensureAuthOrPrompt(context, () {
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const GoalPlannerScreen(),
                                ),
                              );
                            }
                          });
                        },
                      );

                      if (isWide) {
                        return Column(
                          children: [
                            Row(children: [
                              Expanded(child: left),
                              const SizedBox(width: 12), // Reduced from 16
                              Expanded(child: right)
                            ]),
                            const SizedBox(height: 10), // Reduced from 12
                            Row(children: [
                              Expanded(child: loanPlanner),
                              const SizedBox(width: 12), // Reduced from 16
                              Expanded(child: goalPlanner),
                            ]),
                            const SizedBox(height: 10), // Reduced from 12
                            Row(children: [
                              Expanded(child: learn),
                              const SizedBox(width: 12), // Reduced from 16
                              const Expanded(child: SizedBox()),
                            ]),
                          ],
                        );
                      }
                      return Column(children: [
                        left,
                        const SizedBox(height: 10), // Reduced from 12
                        right,
                        const SizedBox(height: 10), // Reduced from 12
                        loanPlanner,
                        const SizedBox(height: 10), // Reduced from 12
                        goalPlanner,
                        const SizedBox(height: 10), // Reduced from 12
                        learn,
                      ]);
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
