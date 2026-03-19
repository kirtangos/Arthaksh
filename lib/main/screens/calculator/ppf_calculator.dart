import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../ui/noise_decoration.dart';

class PpfCalculatorScreen extends StatefulWidget {
  const PpfCalculatorScreen({super.key});

  @override
  State<PpfCalculatorScreen> createState() => _PpfCalculatorScreenState();
}

class _PpfCalculatorScreenState extends State<PpfCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _annualCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '7.1');
  final _yearsCtrl = TextEditingController(text: '15');

  final _nf = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  double? _maturity;
  double? _invested;
  double? _interest;

  @override
  void dispose() {
    _annualCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  // Validators
  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite || x <= 0) return 'Enter a valid amount';
    if (x > 150000) return 'Max ₹ 1,50,000 per financial year (PPF limit)';
    return null;
  }

  String? _vRate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite || x < 0 || x > 100) return '0 - 100%';
    return null;
  }

  String? _vYears(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite || x <= 0 || x > 50) return '1 - 50 years';
    return null;
  }

  bool _valid() {
    if (_vMoney(_annualCtrl.text) != null) return false;
    if (_vRate(_rateCtrl.text) != null) return false;
    if (_vYears(_yearsCtrl.text) != null) return false;
    return true;
  }

  void _resetAll() {
    _annualCtrl.clear();
    _rateCtrl.clear();
    _yearsCtrl.clear();
    _maturity = null;
    _invested = null;
    _interest = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final A = double.parse(_annualCtrl.text.replaceAll(',', ''));
    final r =
        double.parse(_rateCtrl.text.replaceAll(',', '')) / 100.0; // annual rate
    final n = double.parse(_yearsCtrl.text.replaceAll(',', ''));

    double fv;
    if (r == 0) {
      fv = A * n;
    } else {
      // End-of-year contribution with yearly compounding; multiply by (1+r) for B.O.Y.
      final f = pow(1 + r, n);
      fv = A * ((f - 1) / r) * (1 + r);
    }

    setState(() {
      _maturity = fv;
      _invested = A * n;
      _interest = fv - (A * n);
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final seed = base.colorScheme.primary;
    final themed = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: base.brightness,
    );
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isNarrow = MediaQuery.of(context).size.width < 500;
    final gap = isNarrow ? 16.0 : 12.0;

    return Theme(
      data: themed,
      child: Builder(builder: (ctx) {
        // Local input decoration theme like SIP
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
          prefixIconColor: isDark ? const Color(0xFF00897b) : cs.primary,
          labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
          hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
        );

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
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              gradient: LinearGradient(colors: [
                cs.surfaceContainerHighest.withValues(alpha: 0.2),
                cs.surfaceContainerHigh.withValues(alpha: 0.3),
              ]),
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.25), width: 0.8),
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
                        color: isDark ? Colors.white : cs.primary,
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
                        color: cs.primary, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
        }

        return PopScope(
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
              title: const Text('PPF Calculator'),
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
                    tooltip: 'PPF explained',
                    style: IconButton.styleFrom(
                        backgroundColor:
                            isDark ? const Color(0xFF00897b) : cs.primary),
                    onPressed: () {
                      showModalBottomSheet(
                        context: ctx,
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor:
                            isDark ? const Color(0xFF00897b) : cs.primary,
                        builder: (_) {
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
                                      Text('What is PPF?',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Public Provident Fund is a government-backed scheme with a 15-year lock-in. Interest is compounded yearly and rates are notified quarterly.',
                                    style: TextStyle(
                                        color: Colors.white, height: 1.35),
                                  ),
                                  SizedBox(height: 10),
                                  Text('Key points:',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(height: 6),
                                  Text(
                                    '• Tax benefits under Sec 80C\n• Tax-free maturity\n• Partial withdrawals and loan facilities as per rules',
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
            body: Container(
              decoration: isDark
                  ? const NoiseDecoration(
                      color: Color(0xFF00897b),
                      opacity: 0.02,
                    )
                  : null,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Input card (matches lumpsum calculator)
                    Builder(builder: (_) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(14)),
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
                                    controller: _annualCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.,]'))
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Yearly Contribution',
                                      prefixText: '₹ ',
                                      prefixIcon:
                                          const Icon(Icons.savings_rounded),
                                      suffixIcon: IconButton(
                                        tooltip: 'Clear',
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                                width: 32, height: 32),
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _annualCtrl.clear();
                                          setState(() {});
                                        },
                                      ),
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.]'))
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Annual Interest Rate',
                                      suffixText: '%',
                                      prefixIcon:
                                          const Icon(Icons.percent_rounded),
                                      suffixIcon: IconButton(
                                        tooltip: 'Clear',
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints.tightFor(
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
                                  ),
                                  SizedBox(height: gap),
                                  TextFormField(
                                    controller: _yearsCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.]'))
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Time Horizon',
                                      suffixText: 'years',
                                      prefixIcon: const Icon(
                                          Icons.calendar_month_rounded),
                                      suffixIcon: IconButton(
                                        tooltip: 'Clear',
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints.tightFor(
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Calculate button outside the card
                    SizedBox(height: gap + 4),
                    SizedBox(
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _valid() ? _calc : null,
                            child: const Text('Calculate'),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_maturity != null)
                      Card(
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
                              // Full-width KPI panel (same pattern as Lumpsum)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  gradient: LinearGradient(colors: [
                                    cs.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    cs.surfaceContainerHigh
                                        .withValues(alpha: 0.5),
                                  ]),
                                  border: Border.all(
                                      color: cs.primary.withValues(alpha: 0.25),
                                      width: 0.8),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Reuse Lumpsum-like KPI sizing
                                    final kpiWidth = 148.0;
                                    final kpiHeight = 80.0;

                                    final maturityStr = _nf.format(double.parse(
                                        _maturity!.toStringAsFixed(2)));
                                    final investedStr = _nf.format(double.parse(
                                        _invested!.toStringAsFixed(2)));
                                    final interestStr = _nf.format(double.parse(
                                        _interest!.toStringAsFixed(2)));

                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: kpiWidth,
                                            height: kpiHeight,
                                            child: statCard(
                                              title: 'Maturity Amount',
                                              value: maturityStr,
                                              icon: Icons.savings_rounded,
                                              valueLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: kpiWidth,
                                            height: kpiHeight,
                                            child: statCard(
                                              title: 'Total Contribution',
                                              value: investedStr,
                                              icon:
                                                  Icons.account_balance_wallet,
                                              valueLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: kpiWidth,
                                            height: kpiHeight,
                                            child: statCard(
                                              title: 'Interest Earned',
                                              value: interestStr,
                                              icon: Icons.trending_up_rounded,
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
          ),
        );
      }),
    );
  }
}
