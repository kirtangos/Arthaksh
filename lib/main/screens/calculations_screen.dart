import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ui/noise_decoration.dart';
import 'package:arthaksh/main/screens/calculator/emi_calculator.dart';
import 'package:arthaksh/main/screens/calculator/sip_calculator.dart';
import 'package:arthaksh/main/screens/calculator/lumpsum_calculator.dart';
import 'package:arthaksh/main/screens/calculator/loan_comparison.dart';
import 'package:arthaksh/main/screens/calculator/goal_seeker.dart';
import 'package:arthaksh/main/screens/calculator/fd_calculator.dart';
import 'package:arthaksh/main/screens/calculator/rd_calculator.dart';
import 'package:arthaksh/main/screens/calculator/ppf_calculator.dart';
import 'package:arthaksh/main/screens/calculator/wealth_doubling_v2.dart';
import 'package:arthaksh/main/screens/calculator/scss_calculator.dart';
import 'package:arthaksh/main/screens/calculator/cagr_calculator.dart';
import 'package:arthaksh/main/screens/calculator/gst_calculator.dart';
import 'package:arthaksh/main/screens/calculator/discount_calculator.dart';

class CalculationsScreen extends StatefulWidget {
  const CalculationsScreen({super.key});

  @override
  State<CalculationsScreen> createState() => _CalculationsScreenState();
}

class _CalculationsScreenState extends State<CalculationsScreen> {
  String _query = '';

  void _open(BuildContext context, String title) {
    Widget screen;
    if (title == 'EMI Calculator') {
      screen = const EMICalculatorScreen();
    } else if (title == 'SIP Calculator') {
      screen = const SIPCalculatorScreen();
    } else if (title == 'Lumpsum Investment Calculator') {
      screen = const LumpsumCalculatorScreen();
    } else if (title == 'Loan Comparison') {
      screen = const LoanComparisonScreen();
    } else if (title == 'Goal Seeker') {
      screen = const GoalSeekerScreen();
    } else if (title == 'FD Calculator') {
      screen = const FDCalculatorScreen();
    } else if (title == 'RD Calculator') {
      screen = const RDCalculatorScreen();
    } else if (title == 'PPF Calculator') {
      screen = const PpfCalculatorScreen();
    } else if (title == 'Wealth Doubling Calculator') {
      screen = const WealthDoublingV2Screen();
    } else if (title == 'Senior Citizen Savings Scheme') {
      screen = const ScssCalculatorScreen();
    } else if (title == 'Compound Annual Growth Rate') {
      screen = const CagrCalculatorScreen();
    } else if (title == 'GST Calculator') {
      screen = const GstCalculatorScreen();
    } else if (title == 'Discount Calculator') {
      screen = const DiscountCalculatorScreen();
    } else {
      screen = CalculatorPlaceholderScreen(title: title);
    }
    final baseTheme = Theme.of(context);
    final cs = baseTheme.colorScheme;
    // Ensure all calculator pages inherit high-contrast text and consistent AppBar styling
    final wrapped = Theme(
      data: baseTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme)
            .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface),
        appBarTheme: baseTheme.appBarTheme.copyWith(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          elevation: 0,
        ),
      ),
      child: screen,
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => wrapped));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Single accent color for icons/text via cs.primary; neutral/darker backgrounds
    final inv = [
      // Use distinct, semantically meaningful icons per calculator
      _CalcItem('SIP Calculator',
          Icons.auto_graph_rounded), // automatic recurring growth
      _CalcItem('Lumpsum Investment Calculator',
          Icons.timeline_rounded), // single curve timeline
      _CalcItem('Wealth Doubling Calculator',
          Icons.double_arrow_rounded), // emphasis on doubling
      _CalcItem('PPF Calculator', Icons.account_balance_rounded),
      _CalcItem('Senior Citizen Savings Scheme', Icons.elderly_rounded),
      _CalcItem(
          'Compound Annual Growth Rate', Icons.stacked_line_chart_rounded),
      _CalcItem('RD Calculator', Icons.schedule_rounded), // periodic schedule
      _CalcItem('FD Calculator', Icons.savings_rounded),
    ];
    final loan = [
      _CalcItem('EMI Calculator', Icons.payments_rounded),
      _CalcItem('Loan Comparison', Icons.compare_arrows_rounded),
    ];
    final planning = [
      _CalcItem('Goal Seeker', Icons.flag_circle_rounded),
    ];
    final business = [
      _CalcItem('GST Calculator', Icons.receipt_long_rounded),
      _CalcItem('Discount Calculator', Icons.local_offer_rounded),
    ];

    // Flattened list for search
    final all = [...inv, ...loan, ...planning, ...business];
    final filtered = all
        .where((e) => e.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    Widget buildSection(String title, List<_CalcItem> items, Color accent) {
      if (items.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(title,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth < 420) {
                crossAxisCount = 1; // compact phones
              } else if (constraints.maxWidth < 600) {
                crossAxisCount = 2;
              } else if (constraints.maxWidth < 900) {
                crossAxisCount = 3;
              } else {
                crossAxisCount = 4;
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 128, // compact height without overflow
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final it = items[index];
                  return _CalcCard(
                    title: it.title,
                    icon: it.icon,
                    accent: accent,
                    onTap: () => _open(context, it.title),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
        foregroundColor: cs.onSurface,
        title: const Text('Calculations'),
      ),
      body: Container(
        decoration: isDark
            ? const NoiseDecoration(
                color: Color(0xFF00897b),
                opacity: 0.02,
              )
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    cs.surface.withValues(alpha: 0.95),
                  ],
                ),
              ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('All Calculators',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  )),
              const SizedBox(height: 6),
              Text('Organized by category. Tap to begin.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.75),
                  )),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search calculators...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.primary),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              if (_query.isNotEmpty) ...[
                Text('Results',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(height: 8),
                buildSection('', filtered, cs.primary),
              ] else ...[
                // Category accent colors (accents only) with teal framing globally
                // Investment Calculators — Emerald Green (#059669)
                buildSection('Investment', inv, const Color(0xFF059669)),
                // Loan Calculators — Deep Red (#B91C1C)
                buildSection('Loan', loan, const Color(0xFFB91C1C)),
                // Financial Planning — Indigo (#4338CA)
                buildSection(
                    'Financial Planning', planning, const Color(0xFF4338CA)),
                // Business & Tax — Amber/Gold (#D97706)
                buildSection(
                    'Business & Tax', business, const Color(0xFFD97706)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalcItem {
  final String title;
  final IconData icon;
  const _CalcItem(this.title, this.icon);
}

class _CalcCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _CalcCard(
      {required this.title,
      required this.icon,
      required this.accent,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Unify menu card visual with input containers: surface + accent gradient, outlineVariant border
    final accentLight = accent.withValues(alpha: isDark ? 0.12 : 0.18);
    final surfaceBlend = isDark
        ? cs.surfaceContainer // Layer 2 depth
        : cs.surface.withValues(alpha: 0.94);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // Single consistent background with subtle border
            color: surfaceBlend,
            border: isDark
                ? Border.all(
                    color: cs.outline.withValues(alpha: 0.2), width: 0.5)
                : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: isDark
                ? [
                    // Enhanced layered shadows for calculator cards
                    BoxShadow(
                      color: const Color(0xFF0A1416).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: const Color(0xFF1A1A1A).withValues(alpha: 0.5),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [
                    BoxShadow(
                      color:
                          Color(0x14000000), // very light shadow for elevation
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // Very subtle section-tinted gradient overlay for differentiation
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentLight,
                          surfaceBlend,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? accent.withValues(alpha: 0.9) : accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: accent.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.arrow_forward_rounded,
                            size: 18,
                            color:
                                accent.withValues(alpha: isDark ? 0.9 : 1.0)),
                        const SizedBox(width: 6),
                        Text('Open',
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: accent.withValues(
                                    alpha: isDark ? 0.9 : 1.0),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              // Small colored tag for category (top-right)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 26,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalculatorPlaceholderScreen extends StatelessWidget {
  final String title;
  const CalculatorPlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            '$title screen coming soon',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
