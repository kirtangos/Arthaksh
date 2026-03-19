import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class GoalSeekerScreen extends StatefulWidget {
  const GoalSeekerScreen({super.key});

  @override
  State<GoalSeekerScreen> createState() => _GoalSeekerScreenState();
}

class _GoalSeekerScreenState extends State<GoalSeekerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();

  final _nf = NumberFormat.decimalPattern();

  double? _monthlyInvestment;
  double? _totalInvested;
  double? _estimatedReturns;

  @override
  void dispose() {
    _targetCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _targetCtrl.clear();
    _rateCtrl.clear();
    _yearsCtrl.clear();
    _monthlyInvestment = _totalInvested = _estimatedReturns = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > 1e13) return 'Must be ≤ ${_nf.format(1e13)}';
    return null;
  }

  String? _vRate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x < 0) return 'Must be ≥ 0';
    if (x > 100) return 'Must be ≤ 100%';
    return null;
  }

  String? _vYears(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > 60) return 'Must be ≤ 60 years';
    return null;
  }

  bool _valid() =>
      _vMoney(_targetCtrl.text) == null &&
      _vRate(_rateCtrl.text) == null &&
      _vYears(_yearsCtrl.text) == null;

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final fv = double.parse(_targetCtrl.text.replaceAll(',', ''));
    final annual = double.parse(_rateCtrl.text.replaceAll(',', '')) / 100.0;
    final years = double.parse(_yearsCtrl.text.replaceAll(',', ''));

    final r = annual / 12.0;
    final n = (years * 12).round();

    double pow(double a, int n) {
      double res = 1;
      for (int i = 0; i < n; i++) {
        res *= a;
      }
      return res;
    }

    // SIP future value: FV = M * [((1+r)^n - 1) / r] * (1+r)
    // => M = FV / (A * (1+r))
    final f = pow(1 + r, n);
    final annuity = (f - 1) / (r == 0 ? 1 : r); // handle r=0 gracefully
    final denom = annuity * (1 + r);
    final m = r == 0 ? fv / n : fv / denom;

    final totalInvested = m * n;
    final estReturns = fv - totalInvested;

    setState(() {
      _monthlyInvestment = m;
      _totalInvested = totalInvested;
      _estimatedReturns = estReturns;
    });
    HapticFeedback.selectionClick();
  }

  Widget statCard({
    required String title,
    required String value,
    int valueLines = 1,
  }) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
    final isDark = base.brightness == Brightness.dark;
    final themed = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: cs.primary,
      brightness: base.brightness,
    );

    return Container(
      constraints: const BoxConstraints.expand(),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Line 1: Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: themed.textTheme.labelMedium?.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF7C3AED),
                  fontWeight: FontWeight.w700),
            ),
          ),
          // Line 2: Number
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              value,
              maxLines: valueLines,
              overflow: TextOverflow.ellipsis,
              style: themed.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF7C3AED), fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Purple theme to distinguish Goal Seeker
    final base = Theme.of(context);
    const seed = Color(0xFF7C3AED); // purple
    final themed = base.brightness == Brightness.dark
        ? ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            brightness: Brightness.dark)
        : ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            brightness: Brightness.light);

    final gap = 16.0;

    return Theme(
      data: themed,
      child: Builder(builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            // Always reset inputs/results when leaving this screen.
            _resetAll();
          },
          child: Scaffold(
            appBar: AppBar(
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Goal Seeker'),
              leading: BackButton(
                onPressed: () {
                  _resetAll();
                  Navigator.of(ctx).pop();
                },
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    tooltip: 'Goal Seeker explained',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: ctx,
                        isScrollControlled: false,
                        showDragHandle: true,
                        backgroundColor: const Color(0xFF6D28D9),
                        builder: (bctx) {
                          return SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('What does Goal Seeker do?',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          )),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Given a target amount, expected return rate and tenure, Goal Seeker computes the monthly investment required (like SIP) to reach your goal.',
                                    style: TextStyle(
                                        color: Colors.white, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.info_outline_rounded,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input card with purple tinted gradient, similar placement to SIP
                  Builder(builder: (ctx) {
                    final cs = Theme.of(ctx).colorScheme;
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    final inputDecorationTheme = InputDecorationTheme(
                      filled: true,
                      fillColor:
                          cs.surfaceContainerHighest.withValues(alpha: 0.18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: cs.primary, width: 1.8),
                      ),
                      prefixIconColor: cs.primary,
                      labelStyle:
                          TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                      hintStyle:
                          TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                    );
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(14)),
                        color: isDark ? cs.surfaceContainer : null,
                        gradient: !isDark
                            ? LinearGradient(colors: [
                                const Color(0xFF7C3AED).withValues(alpha: 0.10),
                                cs.surface.withValues(alpha: 0.50),
                              ])
                            : null,
                        border: Border.all(
                          color: isDark
                              ? cs.outline.withValues(alpha: 0.2)
                              : cs.outlineVariant.withValues(alpha: 0.5),
                          width: isDark ? 0.5 : 1.0,
                        ),
                        boxShadow: isDark
                            ? [
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
                                  color: cs.shadow.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Theme(
                          data: Theme.of(ctx).copyWith(
                              inputDecorationTheme: inputDecorationTheme),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _targetCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Target Amount',
                                    hintText: 'e.g. 1000000',
                                    prefixText: '₹ ',
                                    prefixIcon: Icon(Icons.flag_circle_rounded),
                                  ),
                                  validator: _vMoney,
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _rateCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Expected Annual Return',
                                    hintText: 'e.g. 12',
                                    suffixText: '%',
                                    prefixIcon: Icon(Icons.percent_rounded),
                                  ),
                                  validator: _vRate,
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _yearsCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Tenure',
                                    hintText: 'e.g. 10',
                                    suffixText: 'years',
                                    prefixIcon:
                                        Icon(Icons.calendar_month_rounded),
                                  ),
                                  validator: _vYears,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  SizedBox(height: gap + 4),
                  // Calculate button outside input card
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9),
                        ),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor:
                                const Color(0xFF6D28D9).withValues(alpha: 0.35),
                          ),
                          onPressed: _valid() ? _calculate : null,
                          child: const Text('Calculate'),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_monthlyInvestment != null)
                    Card(
                      elevation: 0,
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Theme.of(ctx).colorScheme.surfaceContainerHigh
                          : Theme.of(ctx)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: Theme.of(ctx).brightness == Brightness.dark
                                ? Theme.of(ctx)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.2)
                                : Theme.of(ctx).colorScheme.outlineVariant,
                            width: Theme.of(ctx).brightness == Brightness.dark
                                ? 0.5
                                : 1.0),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                      ),
                      shadowColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Results',
                                style: Theme.of(ctx).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            // Full-width KPI panel (same pattern as lumpsum)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(12)),
                                color: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                border: Border.all(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.25),
                                    width: 0.8),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final kpiWidth = 148.0;
                                  final kpiHeight = 80.0;

                                  final monthlyStr =
                                      '₹ ${_nf.format(double.parse((_monthlyInvestment ?? 0).toStringAsFixed(2)))}';
                                  final investedStr =
                                      '₹ ${_nf.format(double.parse((_totalInvested ?? 0).toStringAsFixed(2)))}';
                                  final returnsStr =
                                      '₹ ${_nf.format(double.parse((_estimatedReturns ?? 0).toStringAsFixed(2)))}';

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Monthly Investment',
                                            value: monthlyStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Invested',
                                            value: investedStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Estimated Returns',
                                            value: returnsStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
