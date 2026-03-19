import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../ui/noise_decoration.dart';

class WealthDoublingV2Screen extends StatefulWidget {
  const WealthDoublingV2Screen({super.key});

  @override
  State<WealthDoublingV2Screen> createState() => _WealthDoublingV2ScreenState();
}

class _WealthDoublingV2ScreenState extends State<WealthDoublingV2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _rateCtrl = TextEditingController(text: '12');

  double? _yearsToDouble; // Rule of 72 output

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _rateCtrl.clear();
    _yearsToDouble = null;
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  String? _vRate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v);
    if (x == null || !x.isFinite || x <= 0 || x > 100) return '0 - 100%';
    return null;
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final r = double.parse(_rateCtrl.text);
    setState(() {
      _yearsToDouble = 72.0 / r; // Rule of 72
    });
    HapticFeedback.selectionClick();
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

    // Results KPI uses full-width panel; no fixed tile sizes needed

    final inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF00897b) : cs.primary, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF00897b) : cs.primary, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF00897b) : cs.primary, width: 1.8),
      ),
      prefixIconColor: isDark ? const Color(0xFF00897b) : cs.primary,
      labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
      hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
    );

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
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Theme(
            data: themed.copyWith(inputDecorationTheme: inputDecorationTheme),
            child: Column(
              children: [
                TextFormField(
                  controller: _rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  validator: _vRate,
                  decoration: InputDecoration(
                    labelText: 'Expected Annual Return',
                    hintText: 'e.g. 12',
                    suffixText: '%',
                    prefixIcon: const Icon(Icons.percent_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Clear',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 32),
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _rateCtrl.clear();
                        setState(() {});
                      },
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _calc(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final resultsCard = _yearsToDouble == null
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Results',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  // Full-width KPI panel
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 80),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Line 1: Title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            'Doubling Time',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: themed.textTheme.labelMedium?.copyWith(
                              color: isDark ? Colors.white : cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // Line 2: Number
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '${_yearsToDouble!.toStringAsFixed(2)} years',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: themed.textTheme.titleMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

    return Theme(
      data: themed,
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          _resetAll();
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
            title: const Text('Wealth Doubling'),
            leading: BackButton(
              onPressed: () {
                _resetAll();
                Navigator.of(context).maybePop();
              },
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  tooltip: 'Rule of 72 explained',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        isDark ? const Color(0xFF00897b) : cs.primary,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
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
                                  Text('What is the Rule of 72?',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'The Rule of 72 estimates how long an investment takes to double at a given annual rate.',
                                style: TextStyle(
                                    color: Colors.white, height: 1.35),
                              ),
                              SizedBox(height: 10),
                              Text('Formulas:',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 6),
                              Text(
                                '• Years to double ≈ 72 ÷ r\n• Required rate ≈ 72 ÷ years',
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    formCard,
                    const SizedBox(height: 16),
                    // Calculate button kept outside the input card
                    Builder(builder: (context) {
                      final enabled = _vRate(_rateCtrl.text) == null;
                      return SizedBox(
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(20)),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [cs.primary, cs.primaryContainer]),
                            ),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: cs.primary.withValues(alpha: 0.35),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: enabled ? _calc : null,
                              child: const Text('Calculate'),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    resultsCard,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
