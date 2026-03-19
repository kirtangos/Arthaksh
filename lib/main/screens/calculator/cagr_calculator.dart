import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class CagrCalculatorScreen extends StatefulWidget {
  const CagrCalculatorScreen({super.key});

  @override
  State<CagrCalculatorScreen> createState() => _CagrCalculatorScreenState();
}

class _CagrCalculatorScreenState extends State<CagrCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _beginCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();

  final _nf = NumberFormat.decimalPattern();
  final _pf = NumberFormat.decimalPercentPattern(decimalDigits: 2);

  double? _cagr; // as fraction e.g. 0.1245
  double? _growthPct; // as fraction
  double? _delta; // end - begin

  @override
  void dispose() {
    _beginCtrl.dispose();
    _endCtrl.dispose();
    _yearsCtrl.dispose();
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

  String? _vYears(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > 200) return 'Unrealistic';
    return null;
  }

  void _resetAll() {
    _beginCtrl.clear();
    _endCtrl.clear();
    _yearsCtrl.clear();
    _cagr = null;
    _growthPct = null;
    _delta = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final begin = double.parse(_beginCtrl.text.replaceAll(',', ''));
    final end = double.parse(_endCtrl.text.replaceAll(',', ''));
    final years = double.parse(_yearsCtrl.text.replaceAll(',', ''));
    if (begin <= 0 || years <= 0) return;
    // CAGR formula: (end / begin)^(1/years) - 1
    final ratio = end / begin;
    final cagr = ratio <= 0 ? 0.0 : (math.pow(ratio, 1.0 / years) - 1.0);
    final growth = ratio - 1.0;
    setState(() {
      _cagr = cagr;
      _growthPct = growth;
      _delta = end - begin;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
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

        InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
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
            _resetAll();
          },
          child: Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0F2F1),
            appBar: AppBar(
              backgroundColor:
                  isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0F2F1),
              title: const Text('Compound Annual Growth Rate'),
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
                      tooltip: 'What is CAGR?',
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
                                        Text(
                                          'What is CAGR?',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'CAGR (Compound Annual Growth Rate) is the smoothed annual rate at which an investment grows from its beginning value to its ending value over a period. It ignores interim volatility and represents steady growth.',
                                      style: TextStyle(
                                          color: Colors.white, height: 1.35),
                                    ),
                                    SizedBox(height: 10),
                                    Text('Formula:',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 6),
                                    Text(
                                      'CAGR = (Ending / Beginning)^(1 / Years) − 1',
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
                  // Input card (matches lumpsum calculator)
                  DecoratedBox(
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
                                controller: _beginCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]'))
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Beginning Value',
                                  prefixText: '₹ ',
                                  hintText: 'e.g. 100000',
                                  prefixIcon: const Icon(
                                      Icons.play_circle_fill_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: 'Clear',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                        width: 32, height: 32),
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _beginCtrl.clear();
                                      setState(() {});
                                    },
                                  ),
                                ),
                                validator: _vMoney,
                                onChanged: (_) => setState(() {}),
                              ),
                              SizedBox(height: gap),
                              TextFormField(
                                controller: _endCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]'))
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Ending Value',
                                  prefixText: '₹ ',
                                  hintText: 'e.g. 180000',
                                  prefixIcon:
                                      const Icon(Icons.stop_circle_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: 'Clear',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                        width: 32, height: 32),
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _endCtrl.clear();
                                      setState(() {});
                                    },
                                  ),
                                ),
                                validator: _vMoney,
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
                                  prefixIcon:
                                      const Icon(Icons.calendar_month_rounded),
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Calculate button outside input card
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
                          child: const Text('Calculate'),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_cagr != null)
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

                                  final cagrStr = _pf.format(_cagr);
                                  final growthStr = _pf.format(_growthPct);
                                  final deltaStr =
                                      '₹ ${_nf.format(double.parse((_delta ?? 0).toStringAsFixed(2)))}';

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'CAGR',
                                            value: cagrStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Growth',
                                            value: growthStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Value Change',
                                            value: deltaStr,
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
