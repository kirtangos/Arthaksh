import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class LoanComparisonScreen extends StatefulWidget {
  const LoanComparisonScreen({super.key});

  @override
  State<LoanComparisonScreen> createState() => _LoanComparisonScreenState();
}

class _LoanComparisonScreenState extends State<LoanComparisonScreen> {
  final _formKey = GlobalKey<FormState>();
  // Scenario A
  final _amountA = TextEditingController();
  final _rateA = TextEditingController();
  final _yearsA = TextEditingController();
  // Scenario B
  final _amountB = TextEditingController();
  final _rateB = TextEditingController();
  final _yearsB = TextEditingController();

  final _nf = NumberFormat.decimalPattern();

  // Results
  double? _emiA, _totalIntA, _totalPayA;
  double? _emiB, _totalIntB, _totalPayB;
  String? _recommended; // 'A' or 'B'
  String? _reason;

  @override
  void dispose() {
    _amountA.dispose();
    _rateA.dispose();
    _yearsA.dispose();
    _amountB.dispose();
    _rateB.dispose();
    _yearsB.dispose();
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
    return _vMoney(_amountA.text) == null &&
        _vRate(_rateA.text) == null &&
        _vYears(_yearsA.text) == null &&
        _vMoney(_amountB.text) == null &&
        _vRate(_rateB.text) == null &&
        _vYears(_yearsB.text) == null;
  }

  void _resetAll() {
    _amountA.clear();
    _rateA.clear();
    _yearsA.clear();
    _amountB.clear();
    _rateB.clear();
    _yearsB.clear();
    _emiA = _totalIntA = _totalPayA = null;
    _emiB = _totalIntB = _totalPayB = null;
    _recommended = null;
    _reason = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  double _computeEmi(double principal, double annual, int months) {
    final r = (annual / 12) / 100.0;
    if (r == 0) return principal / months;
    double pow(double a, int n) {
      double res = 1;
      for (int i = 0; i < n; i++) {
        res *= a;
      }
      return res;
    }

    final f = pow(1 + r, months);
    return principal * r * f / (f - 1);
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final principalA = double.parse(_amountA.text.replaceAll(',', ''));
    final rA = double.parse(_rateA.text.replaceAll(',', ''));
    final yA = double.parse(_yearsA.text.replaceAll(',', ''));
    final nA = (yA * 12).round();
    final emiA = _computeEmi(principalA, rA, nA);
    final totalPayA = emiA * nA;
    final totalIntA = totalPayA - principalA;

    final principalB = double.parse(_amountB.text.replaceAll(',', ''));
    final rB = double.parse(_rateB.text.replaceAll(',', ''));
    final yB = double.parse(_yearsB.text.replaceAll(',', ''));
    final nB = (yB * 12).round();
    final emiB = _computeEmi(principalB, rB, nB);
    final totalPayB = emiB * nB;
    final totalIntB = totalPayB - principalB;

    // Recommendation: Prefer lower total payment; tie-breaker lower EMI
    String rec;
    String reason;
    if (totalPayA < totalPayB) {
      rec = 'A';
      reason = 'Lower total payment';
    } else if (totalPayB < totalPayA) {
      rec = 'B';
      reason = 'Lower total payment';
    } else if (emiA < emiB) {
      rec = 'A';
      reason = 'Lower EMI';
    } else if (emiB < emiA) {
      rec = 'B';
      reason = 'Lower EMI';
    } else {
      rec = 'A';
      reason = 'Both similar';
    }

    setState(() {
      _emiA = emiA;
      _totalPayA = totalPayA;
      _totalIntA = totalIntA;
      _emiB = emiB;
      _totalPayB = totalPayB;
      _totalIntB = totalIntB;
      _recommended = rec;
      _reason = reason;
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
    // Rosy red theme
    final base = Theme.of(context);
    const seed = Color(0xFFE11D48);
    final themed = base.brightness == Brightness.dark
        ? ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            brightness: Brightness.dark)
        : ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            brightness: Brightness.light);

    final isNarrow = MediaQuery.of(context).size.width < 500;
    final gap = isNarrow ? 16.0 : 12.0;

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
              title: const Text('Loan Comparison'),
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
                    tooltip: 'Loan comparison explained',
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
                                      Text('How to compare loans?',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          )),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Compare total payment and EMI for both loans. Lower total payment generally means cheaper loan. If total payment ties, prefer lower EMI for cash flow ease.',
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
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Scenario A',
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _amountA,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Loan Amount (A)',
                                    hintText: 'e.g. 500000',
                                    prefixText: '₹ ',
                                    prefixIcon: Icon(Icons.payments_rounded),
                                  ),
                                  validator: _vMoney,
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _rateA,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Annual Interest Rate (A)',
                                    hintText: 'e.g. 9',
                                    suffixText: '%',
                                    prefixIcon: Icon(Icons.percent_rounded),
                                  ),
                                  validator: _vRate,
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _yearsA,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Tenure (A)',
                                    hintText: 'e.g. 5',
                                    suffixText: 'years',
                                    prefixIcon:
                                        Icon(Icons.calendar_month_rounded),
                                  ),
                                  validator: _vYears,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const Divider(height: 24),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Scenario B',
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _amountB,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Loan Amount (B)',
                                    hintText: 'e.g. 500000',
                                    prefixText: '₹ ',
                                    prefixIcon: Icon(Icons.payments_rounded),
                                  ),
                                  validator: _vMoney,
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _rateB,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Annual Interest Rate (B)',
                                    hintText: 'e.g. 9',
                                    suffixText: '%',
                                    prefixIcon: Icon(Icons.percent_rounded),
                                  ),
                                  validator: _vRate,
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _yearsB,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Tenure (B)',
                                    hintText: 'e.g. 5',
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
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFAD1457),
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
                          child: const Text('Calculate Comparison'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_emiA != null && _emiB != null)
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
                            const SizedBox(height: 10),
                            Text('Scenario A',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            // Full-width KPI panel (same pattern as EMI)
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
                                  final kpiWidth = 148.0;
                                  final kpiHeight = 80.0;

                                  final emiAStr =
                                      '₹ ${_nf.format(double.parse((_emiA ?? 0).toStringAsFixed(2)))}';
                                  final interestAStr =
                                      '₹ ${_nf.format(double.parse((_totalIntA ?? 0).toStringAsFixed(2)))}';
                                  final paymentAStr =
                                      '₹ ${_nf.format(double.parse((_totalPayA ?? 0).toStringAsFixed(2)))}';

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'EMI',
                                            value: emiAStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Interest',
                                            value: interestAStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Payment',
                                            value: paymentAStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Divider(height: 20),
                            Text('Scenario B',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            // Full-width KPI panel (same pattern as EMI)
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
                                  final kpiWidth = 148.0;
                                  final kpiHeight = 80.0;

                                  final emiBStr =
                                      '₹ ${_nf.format(double.parse((_emiB ?? 0).toStringAsFixed(2)))}';
                                  final interestBStr =
                                      '₹ ${_nf.format(double.parse((_totalIntB ?? 0).toStringAsFixed(2)))}';
                                  final paymentBStr =
                                      '₹ ${_nf.format(double.parse((_totalPayB ?? 0).toStringAsFixed(2)))}';

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'EMI',
                                            value: emiBStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Interest',
                                            value: interestBStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Payment',
                                            value: paymentBStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Divider(height: 20),
                            Text('Recommended',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Builder(builder: (_) {
                              final cs = Theme.of(ctx).colorScheme;
                              final rec = _recommended;
                              final reason = _reason ?? '';
                              if (rec == null) return const SizedBox.shrink();
                              final label =
                                  rec == 'A' ? 'Scenario A' : 'Scenario B';
                              final icon = rec == 'A'
                                  ? Icons.thumb_up_alt_rounded
                                  : Icons.recommend_rounded;
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(10)),
                                  color: cs.primary.withValues(alpha: 0.10),
                                  border: Border.all(
                                      color:
                                          cs.primary.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, color: cs.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(label,
                                              style: Theme.of(ctx)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: cs.primary)),
                                          const SizedBox(height: 2),
                                          Text(reason,
                                              style: Theme.of(ctx)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: cs.onSurface
                                                          .withValues(
                                                              alpha: 0.8))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
