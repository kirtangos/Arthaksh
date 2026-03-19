import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class RDCalculatorScreen extends StatefulWidget {
  const RDCalculatorScreen({super.key});

  @override
  State<RDCalculatorScreen> createState() => _RDCalculatorScreenState();
}

class _RDCalculatorScreenState extends State<RDCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _monthlyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  // Scenario B (for comparison)
  final _monthlyCtrlB = TextEditingController();
  final _rateCtrlB = TextEditingController();
  final _yearsCtrlB = TextEditingController();

  final _nf = NumberFormat.decimalPattern();

  double? _maturity;
  double? _deposit;
  double? _interest;
  // Scenario B results
  double? _maturityB;
  double? _depositB;
  double? _interestB;

  bool _compare = false;
  String? _recommended; // 'A' or 'B'
  String? _recommendReason;

  @override
  void dispose() {
    _monthlyCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    _monthlyCtrlB.dispose();
    _rateCtrlB.dispose();
    _yearsCtrlB.dispose();
    super.dispose();
  }

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > 1e9) return 'Too large';
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
    if (x > 60) return 'Must be <= 60 years';
    return null;
  }

  void _resetAll() {
    _monthlyCtrl.clear();
    _rateCtrl.clear();
    _yearsCtrl.clear();
    _maturity = null;
    _deposit = null;
    _interest = null;
    _monthlyCtrlB.clear();
    _rateCtrlB.clear();
    _yearsCtrlB.clear();
    _maturityB = null;
    _depositB = null;
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
    // Scenario A
    final P = double.parse(_monthlyCtrl.text.replaceAll(',', ''));
    final annual = double.parse(_rateCtrl.text.replaceAll(',', ''));
    final years = double.parse(_yearsCtrl.text.replaceAll(',', ''));
    final n = (years * 12).round();
    final r = (annual / 12.0) / 100.0; // monthly rate

    double fvA;
    if (r == 0) {
      fvA = P * n;
    } else {
      final factor = _pow(1 + r, n);
      fvA = P * ((factor - 1) / r) * (1 + r); // annuity due
    }

    double? fvB;
    double? depB;
    double? intB;
    if (_compare) {
      // Validate B inline using same validators
      if (_vMoney(_monthlyCtrlB.text) != null ||
          _vRate(_rateCtrlB.text) != null ||
          _vYears(_yearsCtrlB.text) != null) {
        // Trigger validators visually
        _formKey.currentState!.validate();
        return;
      }
      final p2 = double.parse(_monthlyCtrlB.text.replaceAll(',', ''));
      final annual2 = double.parse(_rateCtrlB.text.replaceAll(',', ''));
      final years2 = double.parse(_yearsCtrlB.text.replaceAll(',', ''));
      final n2 = (years2 * 12).round();
      final r2 = (annual2 / 12.0) / 100.0;
      if (r2 == 0) {
        fvB = p2 * n2;
      } else {
        final factor2 = _pow(1 + r2, n2);
        fvB = p2 * ((factor2 - 1) / r2) * (1 + r2);
      }
      depB = p2 * n2;
      intB = (fvB) - (depB);
    }

    // Compute recommendation if both scenarios are present
    String? rec;
    String? reason;
    if (_compare && fvB != null && depB != null && intB != null) {
      final effA = (_interest ?? (fvA - (P * n))) / (_deposit ?? (P * n));
      final effB = (intB) / (depB);
      if (effA.isFinite && effB.isFinite) {
        if (effB > effA) {
          rec = 'B';
          reason = 'Higher efficiency';
        } else if (effA > effB) {
          rec = 'A';
          reason = 'Higher efficiency';
        } else {
          // tie-breaker: higher maturity
          if ((fvB) > fvA) {
            rec = 'B';
            reason = 'Higher maturity';
          } else if (fvA > (fvB)) {
            rec = 'A';
            reason = 'Higher maturity';
          } else {
            rec = 'A';
            reason = 'Both similar';
          }
        }
      }
    }

    setState(() {
      _maturity = fvA;
      _deposit = P * n;
      _interest = _maturity! - _deposit!;
      _maturityB = fvB;
      _depositB = depB;
      _interestB = intB;
      _recommended = rec;
      _recommendReason = reason;
    });
    HapticFeedback.selectionClick();
  }

  double _pow(double a, int n) {
    double res = 1;
    for (int i = 0; i < n; i++) {
      res *= a;
    }
    return res;
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
              title: const Text('RD Calculator'),
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
                      tooltip: 'RD explained',
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
                          builder: (bctx) {
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
                                        Text('What is RD? ',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            )),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'A Recurring Deposit lets you deposit a fixed amount every month and earn interest compounded monthly. It is similar in math to SIP with fixed contributions.',
                                      style: TextStyle(
                                          color: Colors.white, height: 1.35),
                                    ),
                                    SizedBox(height: 10),
                                    Text('Formula idea:',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 6),
                                    Text(
                                        'Future Value = P * ((1 + r)^n - 1) / r * (1 + r)',
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
                  // Input card (match SIP look)
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
                                  controller: _monthlyCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Monthly Deposit',
                                    hintText: 'e.g. 5000',
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
                                        _monthlyCtrl.clear();
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
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Compare another RD'),
                                  value: _compare,
                                  onChanged: (v) {
                                    setState(() {
                                      _compare = v;
                                      if (!v) {
                                        _monthlyCtrlB.clear();
                                        _rateCtrlB.clear();
                                        _yearsCtrlB.clear();
                                        _maturityB = null;
                                        _depositB = null;
                                        _interestB = null;
                                      }
                                    });
                                  },
                                ),
                                if (_compare) ...[
                                  SizedBox(height: gap),
                                  TextFormField(
                                    controller: _monthlyCtrlB,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.,]'))
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Monthly Deposit (B)',
                                      hintText: 'e.g. 6000',
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
                                          _monthlyCtrlB.clear();
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    validator: _compare ? _vMoney : null,
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
                                    decoration: InputDecoration(
                                      labelText: 'Annual Interest Rate (B)',
                                      hintText: 'e.g. 7.5',
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
                                          _rateCtrlB.clear();
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    validator: _compare ? _vRate : null,
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
                                    decoration: InputDecoration(
                                      labelText: 'Tenure (B)',
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
                                          _yearsCtrlB.clear();
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    validator: _compare ? _vYears : null,
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
                          child: const Text('Calculate RD'),
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
                                  '₹ ${_nf.format(double.parse((_maturity ?? 0).toStringAsFixed(2)))}'),
                              _kpi(ctx, 'Deposited',
                                  '₹ ${_nf.format(double.parse((_deposit ?? 0).toStringAsFixed(2)))}'),
                              _kpi(ctx, 'Interest',
                                  '₹ ${_nf.format(double.parse((_interest ?? 0).toStringAsFixed(2)))}'),
                            ]),
                            if (_compare && _maturityB != null) ...[
                              const Divider(height: 20),
                              Text('Scenario B',
                                  style: themed.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              _kpiRow(ctx, [
                                _kpi(ctx, 'Maturity',
                                    '₹ ${_nf.format(double.parse((_maturityB ?? 0).toStringAsFixed(2)))}'),
                                _kpi(ctx, 'Deposited',
                                    '₹ ${_nf.format(double.parse((_depositB ?? 0).toStringAsFixed(2)))}'),
                                _kpi(ctx, 'Interest',
                                    '₹ ${_nf.format(double.parse((_interestB ?? 0).toStringAsFixed(2)))}'),
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
    // Force items into a single line evenly spaced
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
