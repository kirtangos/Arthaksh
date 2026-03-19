import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../ui/noise_decoration.dart';

enum Compounding { yearly, halfYearly, quarterly, monthly }

int _periodsPerYear(Compounding c) {
  switch (c) {
    case Compounding.yearly:
      return 1;
    case Compounding.halfYearly:
      return 2;
    case Compounding.quarterly:
      return 4;
    case Compounding.monthly:
      return 12;
  }
}

String _compLabel(Compounding c) {
  switch (c) {
    case Compounding.yearly:
      return 'yearly';
    case Compounding.halfYearly:
      return 'half-yearly';
    case Compounding.quarterly:
      return 'quarterly';
    case Compounding.monthly:
      return 'monthly';
  }
}

class LumpsumCalculatorScreen extends StatefulWidget {
  const LumpsumCalculatorScreen({super.key});

  @override
  State<LumpsumCalculatorScreen> createState() =>
      _LumpsumCalculatorScreenState();
}

class _LumpsumCalculatorScreenState extends State<LumpsumCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _nf = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  double? _maturity;
  double? _gains;
  Compounding _comp = Compounding.monthly;

  // Use app-wide theme colors; no per-screen custom palette

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _amountCtrl.clear();
    _rateCtrl.clear();
    _yearsCtrl.clear();
    _maturity = null;
    _gains = null;
    _comp = Compounding.monthly;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  String? _vAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || x <= 0) return 'Enter a valid amount';
    if (x > 1e12) return 'Too large';
    return null;
  }

  String _gainPctString(double invested) {
    if (!invested.isFinite || invested <= 0) return '+0.00%';
    final pct = (((_gains ?? 0) / invested) * 100).clamp(-1.0e9, 1.0e9);
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(2)}%';
  }

  String? _vRate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v);
    if (x == null || x < 0 || x > 100) return '0 - 100%';
    return null;
  }

  String? _vYears(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = int.tryParse(v);
    if (x == null || x <= 0 || x > 100) return '1 - 100 years';
    return null;
  }

  // _kpiChip removed: replaced by responsive stat cards grid in results section.

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final P = double.parse(_amountCtrl.text.replaceAll(',', ''));
    final annual = double.parse(_rateCtrl.text);
    final years = int.parse(_yearsCtrl.text);
    final m = _periodsPerYear(_comp);
    final r = (annual / m) / 100.0;
    final n = years * m;
    final fv = P * pow(1 + r, n);
    setState(() {
      _maturity = fv;
      _gains = fv - P;
    });
    HapticFeedback.selectionClick();
  }

  bool _canCalculate() {
    final a = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    final r = double.tryParse(_rateCtrl.text);
    final y = int.tryParse(_yearsCtrl.text);
    if (a == null || !a.isFinite || a <= 0 || a > 1e12) return false;
    if (r == null || !r.isFinite || r < 0 || r > 100) return false;
    if (y == null || y <= 0 || y > 100) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Local theme derived from the app's existing color scheme
    final base = Theme.of(context);
    final seed = base.colorScheme.primary;
    final themed = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: base.brightness,
    );

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Hardcoded minimal KPI card size (two-line rectangle)
    const double kpiWidth = 116;
    const double kpiHeight = 72;

    final formCard = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        color: isDark ? cs.surfaceContainer : null,
        gradient: !isDark
            ? LinearGradient(colors: [
                cs.primary.withValues(alpha: 0.10),
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
                  color: cs.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (ctx) {
                final cs = Theme.of(ctx).colorScheme;
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                final inputDecorationTheme = InputDecorationTheme(
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                        color: isDark ? const Color(0xFF00897b) : cs.primary,
                        width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                        color: isDark ? const Color(0xFF00897b) : cs.primary,
                        width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                        color: isDark ? const Color(0xFF00897b) : cs.primary,
                        width: 1.8),
                  ),
                  prefixIconColor:
                      isDark ? const Color(0xFF00897b) : cs.primary,
                  labelStyle:
                      TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                  hintStyle:
                      TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                );
                return Theme(
                  data: Theme.of(ctx)
                      .copyWith(inputDecorationTheme: inputDecorationTheme),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        ],
                        decoration: InputDecoration(
                          labelText: 'Investment Amount',
                          hintText: 'e.g. 100000',
                          prefixText: '₹ ',
                          prefixIcon:
                              const Icon(Icons.stacked_line_chart_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Clear',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                                width: 32, height: 32),
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _amountCtrl.clear();
                              setState(() {});
                            },
                          ),
                        ),
                        validator: _vAmount,
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (_) => _calculate(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        decoration: InputDecoration(
                          labelText: 'Expected Annual Return',
                          hintText: 'e.g. 12',
                          suffixText: '%',
                          prefixIcon: const Icon(Icons.percent_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Clear',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                                width: 32, height: 32),
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _rateCtrl.clear();
                              setState(() {});
                            },
                          ),
                        ),
                        validator: _vRate,
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (_) => _calculate(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _yearsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        decoration: InputDecoration(
                          labelText: 'Tenure',
                          hintText: 'e.g. 10',
                          suffixText: 'years',
                          prefixIcon: const Icon(Icons.calendar_month_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Clear',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                                width: 32, height: 32),
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _yearsCtrl.clear();
                              setState(() {});
                            },
                          ),
                        ),
                        validator: _vYears,
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (_) => _calculate(),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Text('Compounding Frequency',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<Compounding>(
                segments: const [
                  ButtonSegment(
                      value: Compounding.yearly, label: Text('Yearly')),
                  ButtonSegment(
                      value: Compounding.halfYearly,
                      label: Text('Half-Yearly')),
                  ButtonSegment(
                      value: Compounding.quarterly, label: Text('Quarterly')),
                  ButtonSegment(
                      value: Compounding.monthly, label: Text('Monthly')),
                ],
                selected: {_comp},
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 6)),
                  minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                  shape: const WidgetStatePropertyAll(StadiumBorder()),
                  textStyle: WidgetStatePropertyAll(TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    final cs = Theme.of(context).colorScheme;
                    return states.contains(WidgetState.selected)
                        ? cs.secondaryContainer
                        : null;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    final cs = Theme.of(context).colorScheme;
                    return states.contains(WidgetState.selected)
                        ? cs.onSecondaryContainer
                        : null;
                  }),
                  side: WidgetStateProperty.resolveWith((states) {
                    final cs = Theme.of(context).colorScheme;
                    return BorderSide(
                      color: states.contains(WidgetState.selected)
                          ? cs.secondary
                          : Theme.of(context).dividerColor,
                    );
                  }),
                ),
                onSelectionChanged: (s) {
                  // Update compounding and auto-recalculate if we already have inputs/results
                  setState(() => _comp = s.first);
                  if (_canCalculate() &&
                      (_maturity != null || _amountCtrl.text.isNotEmpty)) {
                    _calculate();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    // Calculate button moved outside the input card

    final resultsCard = _maturity == null
        ? const SizedBox.shrink()
        : Card(
            elevation: 0,
            color: isDark
                ? cs.surfaceContainerHigh
                : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: isDark
                      ? cs.outline.withValues(alpha: 0.2)
                      : cs.outlineVariant,
                  width: isDark ? 0.5 : 1.0),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            shadowColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Results',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  // Full-width KPI panel with teal shading
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      gradient: LinearGradient(colors: [
                        cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        cs.surfaceContainerHigh.withValues(alpha: 0.5),
                      ]),
                      border: Border.all(
                          color: cs.primary.withValues(alpha: 0.25),
                          width: 0.8),
                    ),
                    child: Builder(builder: (context) {
                      final cs = Theme.of(context).colorScheme;
                      final invested = double.tryParse(
                              _amountCtrl.text.replaceAll(',', '')) ??
                          0;
                      final gains = _gains ?? 0;
                      final maturity = _maturity ?? 0;

                      Widget statCard({
                        required String title,
                        required String value,
                        required IconData icon,
                        int valueLines = 1,
                      }) {
                        return Container(
                          constraints: const BoxConstraints.expand(),
                          padding: EdgeInsets.zero,
                          decoration: BoxDecoration(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(12)),
                            gradient: LinearGradient(colors: [
                              cs.surfaceContainerHighest.withValues(alpha: 0.2),
                              cs.surfaceContainerHigh.withValues(alpha: 0.3),
                            ]),
                            border: Border.all(
                                color: cs.primary.withValues(alpha: 0.25),
                                width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Line 1: Title
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: themed.textTheme.labelMedium?.copyWith(
                                      color: isDark ? Colors.white : cs.primary,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              // Line 2: Number
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  value,
                                  maxLines: valueLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: themed.textTheme.titleMedium?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: kpiWidth,
                              height: kpiHeight,
                              child: statCard(
                                title: 'Maturity Value',
                                value: _nf.format(
                                    double.parse(maturity.toStringAsFixed(2))),
                                icon: Icons.savings_rounded,
                                valueLines: 1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 148, // wider only for Wealth Gain
                              height: kpiHeight,
                              child: statCard(
                                title: 'Wealth Gain',
                                value:
                                    '${_nf.format(double.parse(gains.toStringAsFixed(2)))}\n(${_gainPctString(invested)})',
                                icon: Icons.trending_up_rounded,
                                valueLines: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: kpiWidth,
                              height: kpiHeight,
                              child: statCard(
                                title: 'Total Invested',
                                value: _nf.format(invested),
                                icon: Icons.account_balance_rounded,
                                valueLines: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Computed with ${_compLabel(_comp)} compounding at ${_rateCtrl.text}% for ${_yearsCtrl.text} years',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );

    return Theme(
      data: themed,
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _resetAll();
          }
        },
        child: Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0F2F1),
          appBar: AppBar(
            backgroundColor:
                isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0F2F1),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _resetAll();
                Navigator.of(context).pop();
              },
            ),
            title: const Text('Lumpsum Calculator'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Builder(builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return IconButton(
                    tooltip: 'Lumpsum explained',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? const Color(0xFF00897b) : cs.primary,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: ctx,
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor:
                            isDark ? const Color(0xFF00897b) : cs.primary,
                        builder: (_) => SafeArea(
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
                                    Text('What is a Lumpsum Investment?',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'A lumpsum is a one-time investment made at the start. The final value depends on the annual return rate, compounding frequency, and time invested.',
                                  style: TextStyle(
                                      color: Colors.white, height: 1.35),
                                ),
                                SizedBox(height: 10),
                                Text('Formula (compounded):',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(height: 6),
                                Text(
                                  'FV = P × (1 + r/n)^(n×t)\n• P: initial amount\n• r: annual rate\n• n: compounding periods/year\n• t: years',
                                  style: TextStyle(
                                      color: Colors.white, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline_rounded,
                        color: Colors.white),
                  );
                }),
              ),
            ],
          ),
          body: Container(
            decoration: isDark
                ? const NoiseDecoration(
                    color: Color(0xFF00897b),
                    opacity: 0.02,
                  )
                : null,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      formCard,
                      const SizedBox(height: 16),
                      Builder(builder: (context) {
                        final enabled = _canCalculate();
                        return SizedBox(
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(20)),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  const Color(0xFF00897b),
                                  const Color(0xFF00695C)
                                ]),
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: const Color(0xFF00897b)
                                      .withValues(alpha: 0.35),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: enabled ? _calculate : null,
                                child: const Text('Calculate Lumpsum'),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      resultsCard,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
