import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DiscountCalculatorScreen extends StatefulWidget {
  const DiscountCalculatorScreen({super.key});

  @override
  State<DiscountCalculatorScreen> createState() =>
      _DiscountCalculatorScreenState();
}

class _DiscountCalculatorScreenState extends State<DiscountCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '10');
  final _extraCtrl = TextEditingController(); // optional additional discount

  final _nf = NumberFormat.decimalPattern();

  double? _discountAmount;
  double? _finalPrice;
  double? _totalDiscountPct;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _priceCtrl.clear();
    _discountCtrl.text = '10';
    _extraCtrl.clear();
    _discountAmount = _finalPrice = _totalDiscountPct = null;
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
    if (v == null || v.trim().isEmpty) return null; // optional for extra
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x < 0) return 'Must be ≥ 0';
    if (x > 100) return 'Must be ≤ 100%';
    return null;
  }

  bool _valid() =>
      _vMoney(_priceCtrl.text) == null &&
      _vRate(_discountCtrl.text) == null &&
      _vRate(_extraCtrl.text) == null;

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final price = double.parse(_priceCtrl.text.replaceAll(',', ''));
    final d1 = double.tryParse(_discountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final d2 = double.tryParse(_extraCtrl.text.replaceAll(',', '')) ?? 0.0;

    // Apply discounts sequentially: price -> d1% -> d2%
    final afterD1 = price * (1 - d1 / 100.0);
    final finalPrice = afterD1 * (1 - d2 / 100.0);
    final discountAmount = price - finalPrice;
    // Effective combined discount percentage
    final totalPct = price == 0 ? 0.0 : (discountAmount / price) * 100.0;

    setState(() {
      _discountAmount = discountAmount;
      _finalPrice = finalPrice;
      _totalDiscountPct = totalPct;
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
    // Amber theme (0xFFD97706) to align with Business & Tax category
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
              title: const Text('Discount Calculator'),
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
                    tooltip: 'Discount explained',
                    style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706)),
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
                              children: const [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('How discounts are applied',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Primary discount is applied first, then optional extra discount is applied on the reduced price. This yields an effective combined discount. You can enter any custom rate.',
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
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input card (SIP-like positioning)
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
                                TextFormField(
                                  controller: _priceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Original Price',
                                    hintText: 'e.g. 1000',
                                    prefixText: '₹ ',
                                    prefixIcon:
                                        const Icon(Icons.shopping_bag_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: 'Clear',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                              width: 32, height: 32),
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _priceCtrl.clear();
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  validator: _vMoney,
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _discountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Discount %',
                                    hintText: 'e.g. 10',
                                    suffixText: '%',
                                    prefixIcon:
                                        const Icon(Icons.local_offer_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: 'Clear',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                              width: 32, height: 32),
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _discountCtrl.clear();
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  validator: _vRate,
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _extraCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Extra Discount % (optional)',
                                    hintText: 'e.g. 5',
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
                                        _extraCtrl.clear();
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  validator: _vRate,
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

                  if (_finalPrice != null)
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
                            // Full-width KPI panel (same pattern as other calculators)
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
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final kpiWidth = 148.0;
                                  final kpiHeight = 80.0;

                                  final discountStr =
                                      '₹ ${_nf.format(double.parse((_discountAmount ?? 0).toStringAsFixed(2)))}';
                                  final priceStr =
                                      '₹ ${_nf.format(double.parse((_finalPrice ?? 0).toStringAsFixed(2)))}';
                                  final totalPctStr =
                                      '${(_totalDiscountPct ?? 0).toStringAsFixed(2)} %';

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Discount Amount',
                                            value: discountStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Final Price',
                                            value: priceStr,
                                            valueLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: kpiWidth,
                                          height: kpiHeight,
                                          child: statCard(
                                            title: 'Total Discount',
                                            value: totalPctStr,
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
