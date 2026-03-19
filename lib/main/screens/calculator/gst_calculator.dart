import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class GstCalculatorScreen extends StatefulWidget {
  const GstCalculatorScreen({super.key});

  @override
  State<GstCalculatorScreen> createState() => _GstCalculatorScreenState();
}

class _GstCalculatorScreenState extends State<GstCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '18');
  bool _isInclusive = false; // false => add GST, true => remove GST

  final _nf = NumberFormat.decimalPattern();

  double? _gstAmount;
  double? _baseAmount;
  double? _finalAmount;
  double? _cgst;
  double? _sgst;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _amountCtrl.clear();
    _rateCtrl.text = '18';
    _isInclusive = false;
    _gstAmount = _baseAmount = _finalAmount = null;
    _cgst = _sgst = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x < 0) return 'Must be ≥ 0';
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

  bool _valid() =>
      _vMoney(_amountCtrl.text) == null && _vRate(_rateCtrl.text) == null;

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
    final ratePct = double.parse(_rateCtrl.text.replaceAll(',', ''));
    final rate = ratePct / 100.0;

    if (_isInclusive) {
      // amount includes GST; extract base and tax
      final base = amount / (1 + rate);
      final gst = amount - base;
      setState(() {
        _baseAmount = base;
        _gstAmount = gst;
        _finalAmount = amount;
        if ({5, 12, 18, 28}.contains(ratePct.round())) {
          _cgst = gst / 2;
          _sgst = gst / 2;
        } else {
          _cgst = _sgst = null;
        }
      });
    } else {
      // add GST to base amount
      final gst = amount * rate;
      final total = amount + gst;
      setState(() {
        _baseAmount = amount;
        _gstAmount = gst;
        _finalAmount = total;
        if ({5, 12, 18, 28}.contains(ratePct.round())) {
          _cgst = gst / 2;
          _sgst = gst / 2;
        } else {
          _cgst = _sgst = null;
        }
      });
    }
    HapticFeedback.selectionClick();
  }

  Widget statCard({
    required String title,
    required String value,
    int valueLines = 1,
  }) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
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
        border:
            Border.all(color: cs.primary.withValues(alpha: 0.25), width: 0.8),
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
              style: themed.textTheme.labelMedium
                  ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
          // Line 2: Number
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              value,
              maxLines: valueLines,
              overflow: TextOverflow.ellipsis,
              style: themed.textTheme.titleMedium
                  ?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Amber theme per request (0xFFD97706)
    final base = Theme.of(context);
    const seed = Color(0xFFD97706);
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
              title: const Text('GST Calculator'),
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
                    tooltip: 'GST explained',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: ctx,
                        showDragHandle: true,
                        backgroundColor: const Color(0xFFD97706),
                        builder: (_) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('GST, CGST & SGST',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '• GST: Goods & Services Tax applied to most goods/services.\n'
                                  '• CGST/SGST: For intra-state supply, GST is split equally between Central (CGST) and State (SGST).\n'
                                  '• IGST: For inter-state supply, a single IGST is applied (not split).',
                                  style: TextStyle(
                                      color: Colors.white, height: 1.35),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
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
                  // Input card (SIP-like placement)
                  Builder(builder: (_) {
                    final cs = Theme.of(_).colorScheme;
                    final isDark = Theme.of(_).brightness == Brightness.dark;
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _amountCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.next,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[0-9.,]'))
                                        ],
                                        decoration: InputDecoration(
                                          labelText: 'Amount',
                                          hintText: 'e.g. 1000',
                                          prefixText: '₹ ',
                                          prefixIcon: const Icon(
                                              Icons.payments_rounded),
                                          suffixIcon: IconButton(
                                            tooltip: 'Clear',
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                    width: 32, height: 32),
                                            icon: const Icon(Icons.clear,
                                                size: 18),
                                            onPressed: () {
                                              _amountCtrl.clear();
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                        validator: _vMoney,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _rateCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.done,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[0-9.]'))
                                        ],
                                        decoration: InputDecoration(
                                          labelText: 'GST Rate',
                                          hintText: 'e.g. 18',
                                          suffixText: '%',
                                          prefixIcon:
                                              Icon(Icons.percent_rounded),
                                          suffixIcon: IconButton(
                                            tooltip: 'Clear',
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                    width: 32, height: 32),
                                            icon: const Icon(Icons.clear,
                                                size: 18),
                                            onPressed: () {
                                              _rateCtrl.clear();
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                        validator: _vRate,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Switch(
                                      value: _isInclusive,
                                      onChanged: (v) =>
                                          setState(() => _isInclusive = v),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_isInclusive
                                        ? 'Amount includes GST'
                                        : 'Add GST to amount'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  SizedBox(height: gap + 4),
                  // Calculate button outside card, amber gradient
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                        ),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor:
                                const Color(0xFFD97706).withValues(alpha: 0.35),
                          ),
                          onPressed: _valid() ? _calculate : null,
                          child: const Text('Calculate'),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_gstAmount != null)
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
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(12)),
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                border: Border.all(
                                    color: Theme.of(ctx).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFFD97706)
                                            .withValues(alpha: 0.25)
                                        : Theme.of(ctx)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.25),
                                    width: 0.8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final kpiWidth = 148.0;
                                      final kpiHeight = 80.0;

                                      final gstStr =
                                          '₹ ${_nf.format(double.parse((_gstAmount ?? 0).toStringAsFixed(2)))}';
                                      final baseStr =
                                          '₹ ${_nf.format(double.parse((_baseAmount ?? 0).toStringAsFixed(2)))}';
                                      final finalStr =
                                          '₹ ${_nf.format(double.parse((_finalAmount ?? 0).toStringAsFixed(2)))}';

                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: kpiWidth,
                                              height: kpiHeight,
                                              child: statCard(
                                                title: 'GST Amount',
                                                value: gstStr,
                                                valueLines: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: kpiWidth,
                                              height: kpiHeight,
                                              child: statCard(
                                                title: _isInclusive
                                                    ? 'Base (excl. GST)'
                                                    : 'Base Amount',
                                                value: baseStr,
                                                valueLines: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: kpiWidth,
                                              height: kpiHeight,
                                              child: statCard(
                                                title: _isInclusive
                                                    ? 'Final (incl. GST)'
                                                    : 'Final Amount',
                                                value: finalStr,
                                                valueLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  if (_cgst != null && _sgst != null) ...[
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final kpiWidth = 148.0;
                                        final kpiHeight = 80.0;

                                        final cgstStr =
                                            '₹ ${_nf.format(double.parse((_cgst ?? 0).toStringAsFixed(2)))}';
                                        final sgstStr =
                                            '₹ ${_nf.format(double.parse((_sgst ?? 0).toStringAsFixed(2)))}';

                                        return SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: kpiWidth,
                                                height: kpiHeight,
                                                child: statCard(
                                                  title: 'CGST',
                                                  value: cgstStr,
                                                  valueLines: 1,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              SizedBox(
                                                width: kpiWidth,
                                                height: kpiHeight,
                                                child: statCard(
                                                  title: 'SGST',
                                                  value: sgstStr,
                                                  valueLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ]
                                ],
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
