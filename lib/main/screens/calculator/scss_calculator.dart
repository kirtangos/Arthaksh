import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ScssCalculatorScreen extends StatefulWidget {
  const ScssCalculatorScreen({super.key});

  @override
  State<ScssCalculatorScreen> createState() => _ScssCalculatorScreenState();
}

class _ScssCalculatorScreenState extends State<ScssCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _depositCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '8.2');
  final _yearsCtrl = TextEditingController(text: '5');

  final _nfMoney = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  double? _maturity;
  double? _interest;
  bool _isHovering = false;

  @override
  void dispose() {
    _depositCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _depositCtrl.clear();
    _rateCtrl.clear();
    _yearsCtrl.clear();
    _maturity = null;
    _interest = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final P = double.parse(_depositCtrl.text.replaceAll(',', ''));
    final r =
        double.parse(_rateCtrl.text.replaceAll(',', '')) / 100.0; // annual
    final n = double.parse(_yearsCtrl.text.replaceAll(',', ''));

    // Assume annual compounding for simplicity
    double fv;
    if (r == 0) {
      fv = P;
    } else {
      fv = P * pow(1 + r, n);
    }

    setState(() {
      _maturity = fv;
      _interest = fv - P;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    // Teal theme like SIP
    final base = Theme.of(context);
    const seed = Color(0xFF0D9488);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: themed,
      child: Builder(builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

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
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
              title: const Text('Senior Citizen Savings Scheme'),
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
                      tooltip: 'SCSS explained',
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
                                      Text('What is SCSS?',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Senior Citizen Savings Scheme offers regular income and is backed by Government of India. Interest is paid quarterly; we approximate annual compounding for simplicity.',
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
                                    '• Tenure typically 5 years (extendable)\n• Section 80C benefits\n• Premature closure rules apply',
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
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input card (matches lumpsum in light mode with hover)
                  MouseRegion(
                    onEnter: (_) => setState(() => _isHovering = true),
                    onExit: (_) => setState(() => _isHovering = false),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(14)),
                        color: isDark ? cs.surfaceContainer : null,
                        gradient: !isDark
                            ? LinearGradient(colors: [
                                cs.primary.withValues(
                                    alpha: _isHovering ? 0.15 : 0.10),
                                cs.surface.withValues(
                                    alpha: _isHovering ? 0.55 : 0.50),
                              ])
                            : null,
                        border: Border.all(
                          color: isDark
                              ? cs.outline
                                  .withValues(alpha: _isHovering ? 0.3 : 0.2)
                              : cs.outlineVariant
                                  .withValues(alpha: _isHovering ? 0.7 : 0.5),
                          width: isDark ? 0.5 : 1.0,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: cs.shadow.withValues(
                                      alpha: _isHovering ? 0.12 : 0.08),
                                  blurRadius: _isHovering ? 10 : 8,
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
                                  controller: _depositCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Deposit Amount',
                                    hintText: 'e.g. 100000',
                                    prefixText: '₹ ',
                                    prefixIcon: const Icon(
                                        Icons.account_balance_wallet_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: 'Clear',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                              width: 32, height: 32),
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _depositCtrl.clear();
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
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
                                    hintText: 'e.g. 8.2',
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
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Calculate button outside the card
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
                          onPressed: _calc,
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
                            // Full-width KPI panel with teal shading
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(12)),
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

                                  final maturityStr = _nfMoney.format(
                                      double.parse(
                                          _maturity!.toStringAsFixed(2)));
                                  final interestStr = _nfMoney.format(
                                      double.parse(
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
