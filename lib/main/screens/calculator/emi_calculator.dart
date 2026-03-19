import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Performs integer power for doubles: returns a^b for non-negative integer b.
///
/// Declared in `package:arthaksh/screens/emi_calculator.dart`.
/// Used within the EMI calculation to avoid precision/overhead of generic pow.
double powi(double a, int b) {
  if (b < 0) {
    // Handle negative exponent by reciprocal; caller typically uses non-negative b.
    if (a == 0) return double.infinity;
    return 1.0 / powi(a, -b);
  }
  double result = 1.0;
  double base = a;
  int exp = b;
  // Fast exponentiation (exponentiation by squaring)
  while (exp > 0) {
    if ((exp & 1) == 1) result *= base;
    base *= base;
    exp >>= 1;
  }
  return result;
}

class EMICalculatorScreen extends StatefulWidget {
  const EMICalculatorScreen({super.key});

  @override
  State<EMICalculatorScreen> createState() => _EMICalculatorScreenState();
}

class _EMICalculatorScreenState extends State<EMICalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();

  final _nf = NumberFormat.decimalPattern();

  double? _emi;
  double? _totalInterest;
  double? _totalPayment;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > 1e12) return 'Must be ≤ ${_nf.format(1e12)}';
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
    if (x > 50) return 'Must be ≤ 50 years';
    return null;
  }

  bool _valid() {
    return _vMoney(_amountCtrl.text) == null &&
        _vRate(_rateCtrl.text) == null &&
        _vYears(_yearsCtrl.text) == null;
  }

  void _resetAll() {
    _amountCtrl.clear();
    _rateCtrl.clear();
    _yearsCtrl.clear();
    _emi = null;
    _totalInterest = null;
    _totalPayment = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final P = double.parse(_amountCtrl.text.replaceAll(',', ''));
    final annual = double.parse(_rateCtrl.text.replaceAll(',', ''));
    final years = double.parse(_yearsCtrl.text.replaceAll(',', ''));
    final n = (years * 12).round();
    final r = (annual / 12) / 100.0; // monthly interest rate

    double emi;
    if (r == 0) {
      emi = P / n;
    } else {
      final factor = powi(1 + r, n);
      emi = P * r * factor / (factor - 1);
    }
    final totalPayment = emi * n;
    final totalInterest = totalPayment - P;

    setState(() {
      _emi = emi;
      _totalPayment = totalPayment;
      _totalInterest = totalInterest;
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
            color: isDark
                ? const Color(0xFFE11D48).withValues(alpha: 0.25)
                : cs.primary.withValues(alpha: 0.25),
            width: 0.8),
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
                  color: isDark ? const Color(0xFFE11D48) : cs.primary,
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
                  color: isDark ? const Color(0xFFE11D48) : cs.primary,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rose red theme for EMI calculator
    final base = Theme.of(context);
    const seed = Color(0xFFE11D48); // Rose red
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
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            _resetAll();
          },
          child: Scaffold(
            appBar: AppBar(
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('EMI Calculator'),
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
                    tooltip: 'EMI explained',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFAD1457),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: ctx,
                        isScrollControlled: false,
                        showDragHandle: true,
                        backgroundColor: const Color(0xFFAD1457),
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
                                      Text('What is EMI? ',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          )),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'EMI (Equated Monthly Installment) is a fixed monthly payment you make to repay a loan. It includes both principal and interest, spread evenly over the loan tenure.',
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
                                    '• EMI = fixed monthly outflow\n• Interest component is higher in early months\n• EMI depends on amount, interest rate, and tenure\n• Prepayment can reduce total interest',
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
                  // Input card (match SIP positions)
                  Builder(builder: (_) {
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
                                  controller: _amountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Loan Amount',
                                    hintText: 'e.g. 500000',
                                    prefixText: '₹ ',
                                    prefixIcon:
                                        const Icon(Icons.payments_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: 'Clear',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                              width: 32, height: 32),
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _amountCtrl.clear();
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
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Annual Interest Rate',
                                    hintText: 'e.g. 9',
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
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Tenure',
                                    hintText: 'e.g. 5',
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

                  // Calculate button outside the card (like SIP)
                  SizedBox(height: gap + 4),
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFAD1457),
                              const Color(0xFF880E4F),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor:
                                const Color(0xFFAD1457).withValues(alpha: 0.35),
                          ),
                          onPressed: _valid()
                              ? () {
                                  HapticFeedback.selectionClick();
                                  _calc();
                                }
                              : null,
                          child: const Text('Calculate EMI'),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_emi != null)
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
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(12)),
                                color: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                border: Border.all(
                                    color: isDark
                                        ? const Color(0xFFE11D48)
                                            .withValues(alpha: 0.25)
                                        : cs.primary.withValues(alpha: 0.25),
                                    width: 0.8),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Reuse Lumpsum-like KPI sizing
                                  final kpiWidth = 148.0;
                                  final kpiHeight = 80.0;

                                  final emiStr =
                                      '₹ ${_nf.format(double.parse((_emi ?? 0).toStringAsFixed(2)))}';
                                  final interestStr =
                                      '₹ ${_nf.format(double.parse((_totalInterest ?? 0).toStringAsFixed(2)))}';
                                  final paymentStr =
                                      '₹ ${_nf.format(double.parse((_totalPayment ?? 0).toStringAsFixed(2)))}';

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'EMI',
                                            value: emiStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Interest',
                                            value: interestStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Payment',
                                            value: paymentStr,
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
