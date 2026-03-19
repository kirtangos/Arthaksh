import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class FDCalculatorScreen extends StatefulWidget {
  const FDCalculatorScreen({super.key});

  @override
  State<FDCalculatorScreen> createState() => _FDCalculatorScreenState();
}

class _FDCalculatorScreenState extends State<FDCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  // Scenario B controllers
  final _principalCtrlB = TextEditingController();
  final _rateCtrlB = TextEditingController();
  final _yearsCtrlB = TextEditingController();

  final _nfMoney = NumberFormat.decimalPattern();
  final _nfPct = NumberFormat.decimalPercentPattern(decimalDigits: 2);

  double? _maturity; // final amount
  double? _interest; // interest earned
  // Scenario B results
  double? _maturityB;
  double? _interestB;

  bool _compare = false;
  String? _recommended; // 'A' or 'B'
  String? _recommendReason;

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    _principalCtrlB.dispose();
    _rateCtrlB.dispose();
    _yearsCtrlB.dispose();
    super.dispose();
  }

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > 1e12) return 'Too large';
    return null;
  }

  String? _vRate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x < 0) return 'Must be >= 0';
    if (x > 100) return 'Must be <= 100%';
    return null;
  }

  String? _vYears(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > 100) return 'Must be <= 100 years';
    return null;
  }

  void _resetAll() {
    _principalCtrl.clear();
    _rateCtrl.clear();
    _yearsCtrl.clear();
    _maturity = null;
    _interest = null;
    _principalCtrlB.clear();
    _rateCtrlB.clear();
    _yearsCtrlB.clear();
    _maturityB = null;
    _interestB = null;
    _compare = false;
    _recommended = null;
    _recommendReason = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final P = double.parse(_principalCtrl.text.replaceAll(',', ''));
    final annual = double.parse(_rateCtrl.text.replaceAll(',', '')) / 100.0;
    final years = double.parse(_yearsCtrl.text.replaceAll(',', ''));

    // Scenario A: annual compounding
    final A = P * math.pow(1 + annual, years).toDouble();

    // Optional Scenario B
    double? bMaturity;
    double? bInterest;
    if (_compare) {
      // Validate B inputs using same validators
      if (_vMoney(_principalCtrlB.text) != null ||
          _vRate(_rateCtrlB.text) != null ||
          _vYears(_yearsCtrlB.text) != null) {
        _formKey.currentState!.validate();
        return;
      }
      final principalB = double.parse(_principalCtrlB.text.replaceAll(',', ''));
      final annualB = double.parse(_rateCtrlB.text.replaceAll(',', '')) / 100.0;
      final yearsB = double.parse(_yearsCtrlB.text.replaceAll(',', ''));
      bMaturity = principalB * math.pow(1 + annualB, yearsB).toDouble();
      bInterest = bMaturity - principalB;
    }

    // Recommendation
    String? rec;
    String? reason;
    if (_compare && bMaturity != null && bInterest != null) {
      final effA = (A - P) / P; // interest/deposited
      final effB = (bInterest) /
          (double.parse(_principalCtrlB.text.replaceAll(',', '')));
      if (effB > effA) {
        rec = 'B';
        reason = 'Higher efficiency';
      } else if (effA > effB) {
        rec = 'A';
        reason = 'Higher efficiency';
      } else {
        // tie-breaker: higher maturity
        if (bMaturity > A) {
          rec = 'B';
          reason = 'Higher maturity';
        } else if (A > bMaturity) {
          rec = 'A';
          reason = 'Higher maturity';
        } else {
          rec = 'A';
          reason = 'Both similar';
        }
      }
    }

    setState(() {
      _maturity = A;
      _interest = A - P;
      _maturityB = bMaturity;
      _interestB = bInterest;
      _recommended = rec;
      _recommendReason = reason;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    // Teal theme like SIP
    final base = Theme.of(context);
    const seed = Color(0xFF0D9488); // Standard app teal
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
            backgroundColor:
                isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0F2F1),
            appBar: AppBar(
              backgroundColor:
                  isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0F2F1),
              title: const Text('FD Calculator'),
              leading: BackButton(
                onPressed: () {
                  _resetAll();
                  Navigator.of(ctx).pop();
                },
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Builder(builder: (ctx) {
                    final cs = Theme.of(ctx).colorScheme;
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    return IconButton(
                      tooltip: 'FD explained',
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
                          builder: (_) {
                            return SafeArea(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded,
                                            color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('What is a Fixed Deposit?',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'A Fixed Deposit (FD) grows your lump-sum at a fixed annual rate. This calculator assumes annual compounding for simplicity.',
                                      style: TextStyle(
                                          color: Colors.white, height: 1.35),
                                    ),
                                    SizedBox(height: 10),
                                    Text('Formula:',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 6),
                                    Text('Maturity = Principal × (1 + r)^Years',
                                        style: TextStyle(
                                            color: Colors.white, height: 1.35)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.info_outline_rounded,
                          color: Colors.white),
                    );
                  }),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input card matching SIP, with Compare toggle
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
                            color:
                                isDark ? const Color(0xFF00897b) : cs.primary,
                            width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                            color:
                                isDark ? const Color(0xFF00897b) : cs.primary,
                            width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                            color:
                                isDark ? const Color(0xFF00897b) : cs.primary,
                            width: 1.8),
                      ),
                      prefixIconColor:
                          isDark ? const Color(0xFF00897b) : cs.primary,
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
                                  controller: _principalCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Principal',
                                    hintText: 'e.g. 100000',
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
                                        _principalCtrl.clear();
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
                                    hintText: 'e.g. 7',
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
                                SizedBox(height: gap),
                                SwitchListTile.adaptive(
                                  value: _compare,
                                  onChanged: (v) {
                                    setState(() {
                                      _compare = v;
                                      if (!v) {
                                        _principalCtrlB.clear();
                                        _rateCtrlB.clear();
                                        _yearsCtrlB.clear();
                                        _maturityB = null;
                                        _interestB = null;
                                        _recommended = null;
                                        _recommendReason = null;
                                      }
                                    });
                                  },
                                  title: const Text('Compare another FD'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                if (_compare) ...[
                                  const SizedBox(height: 8),
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
                                    controller: _principalCtrlB,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.,]'))
                                    ],
                                    decoration: const InputDecoration(
                                        labelText: 'Principal (B)',
                                        hintText: 'e.g. 100000',
                                        prefixText: '₹ ',
                                        prefixIcon:
                                            Icon(Icons.savings_rounded)),
                                    validator: _vMoney,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  SizedBox(height: gap),
                                  TextFormField(
                                    controller: _rateCtrlB,
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
                                        hintText: 'e.g. 7',
                                        suffixText: '%',
                                        prefixIcon:
                                            Icon(Icons.percent_rounded)),
                                    validator: _vRate,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  SizedBox(height: gap),
                                  TextFormField(
                                    controller: _yearsCtrlB,
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
                                            Icon(Icons.calendar_month_rounded)),
                                    validator: _vYears,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Calculate button outside card
                  SizedBox(height: gap + 4),
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
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
                            shadowColor:
                                const Color(0xFF00897b).withValues(alpha: 0.35),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _formKey.currentState?.validate() == true
                              ? _calc
                              : null,
                          child: const Text('Calculate FD'),
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
                            const SizedBox(height: 10),
                            Text('Scenario A',
                                style: themed.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            _kpiRow(ctx, [
                              _kpi(ctx, 'Maturity',
                                  '\u20b9 ${_nfMoney.format(double.parse((_maturity ?? 0).toStringAsFixed(2)))}'),
                              _kpi(ctx, 'Deposited',
                                  '\u20b9 ${_nfMoney.format(double.tryParse(_principalCtrl.text.replaceAll(',', '')) ?? 0)}'),
                              _kpi(ctx, 'Interest',
                                  '\u20b9 ${_nfMoney.format(double.parse((_interest ?? 0).toStringAsFixed(2)))}'),
                            ]),
                            if (_compare && _maturityB != null) ...[
                              const Divider(height: 20),
                              Text('Scenario B',
                                  style: themed.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              _kpiRow(ctx, [
                                _kpi(ctx, 'Maturity',
                                    '\u20b9 ${_nfMoney.format(double.parse((_maturityB ?? 0).toStringAsFixed(2)))}'),
                                _kpi(ctx, 'Deposited',
                                    '\u20b9 ${_nfMoney.format(double.tryParse(_principalCtrlB.text.replaceAll(',', '')) ?? 0)}'),
                                _kpi(ctx, 'Interest',
                                    '\u20b9 ${_nfMoney.format(double.parse((_interestB ?? 0).toStringAsFixed(2)))}'),
                              ]),
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
                                final reason = _recommendReason ?? '';
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

  Widget _kpi(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themed = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: cs.primary,
      brightness: Theme.of(context).brightness,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: themed.textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.white : cs.primary,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value,
              style: themed.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
        ],
      ),
    );
  }

  Widget _kpiRow(BuildContext context, List<Widget> items) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(child: items[i]),
          if (i != items.length - 1) const SizedBox(width: 12),
        ]
      ],
    );
  }
}
