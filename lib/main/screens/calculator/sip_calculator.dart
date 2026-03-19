import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../ui/noise_decoration.dart';

class SIPCalculatorScreen extends StatefulWidget {
  const SIPCalculatorScreen({super.key});

  @override
  State<SIPCalculatorScreen> createState() => _SIPCalculatorScreenState();
}

class _SIPCalculatorScreenState extends State<SIPCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _monthlyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _monthlyFocus = FocusNode();
  final _nf = NumberFormat.decimalPattern();

  double? _maturity;
  double? _invested;
  double? _gains;
  int? _months;
  double? _annualRate;
  List<double> _seriesInvested = const [];
  List<double> _seriesValue = const [];
  List<_YearRow> _yearly = const [];
  List<double> _seriesInvestedYr = const [];
  List<double> _seriesValueYr = const [];
  List<_MonthRow> _monthly = const [];
  bool _chartYearly = false; // false=Monthly, true=Yearly
  bool _tableYearly = true; // default Yearly
  // Confidence band series (low/high) for monthly and yearly
  List<double> _seriesLow = const [];
  List<double> _seriesHigh = const [];
  List<double> _seriesLowYr = const [];
  List<double> _seriesHighYr = const [];

  static const double _maxMonthly = 1e9; // generous cap
  static const double _maxRate = 100.0;
  static const int _maxYears = 60;

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > _maxMonthly) return 'Must be ≤ ${_nf.format(_maxMonthly)}';
    return null;
  }

  Widget _legendSIP(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Widget _kpiChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? cs.outline.withValues(alpha: 0.2) : cs.outlineVariant,
          width: isDark ? 0.5 : 1.0,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: isDark
            ? cs.surfaceContainer
            : cs.surfaceContainerHighest.withValues(alpha: 0.25),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF00897b) : cs.primary)),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => _copyToClipboard(context, label, value),
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: 'Copy',
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
                color: isDark ? const Color(0xFF00897b) : cs.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _vRate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x < 0) return 'Must be ≥ 0';
    if (x > _maxRate) return 'Must be ≤ ${_maxRate.toStringAsFixed(0)}%';
    return null;
  }

  String? _vYears(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    if (x > _maxYears) return 'Must be ≤ ${_maxYears.toStringAsFixed(0)} years';
    return null;
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final P = double.parse(_monthlyCtrl.text.replaceAll(',', ''));
    final annual = double.parse(_rateCtrl.text.replaceAll(',', ''));
    final years = double.parse(_yearsCtrl.text.replaceAll(',', ''));
    final n = (years * 12).round();
    final r = (annual / 12) / 100.0;
    double fv;
    if (r == 0) {
      fv = P * n;
    } else {
      final factor = _pow(1 + r, n);
      fv = P * ((factor - 1) / r) * (1 + r);
    }

    // Build monthly series for chart and yearly breakdown
    final investedSeries = <double>[];
    final valueSeries = <double>[];
    final yearly = <_YearRow>[];
    final monthly = <_MonthRow>[];
    double bal = 0;
    double investedCum = 0;
    double yearStartBal = 0;
    double yearContrib = 0;
    double yearInterest = 0;
    for (int m = 1; m <= n; m++) {
      // monthly compounding: interest on current balance, then add contribution at month end
      final startBal = bal;
      final interest = r == 0 ? 0.0 : startBal * r;
      bal += interest;
      bal += P;
      investedCum += P;
      investedSeries.add(investedCum);
      valueSeries.add(bal);
      monthly.add(_MonthRow(
        month: m,
        startBalance: startBal,
        contribution: P,
        interest: interest,
        endBalance: bal,
      ));
      yearContrib += P;
      yearInterest += interest;
      final endOfYear = (m % 12 == 0) || (m == n);
      if (endOfYear) {
        final yearIndex = ((m - 1) ~/ 12) + 1;
        yearly.add(_YearRow(
          year: yearIndex,
          startBalance: yearStartBal,
          contribution: yearContrib,
          interest: yearInterest,
          endBalance: bal,
        ));
        yearStartBal = bal;
        yearContrib = 0;
        yearInterest = 0;
      }
    }

    // Confidence band: simulate with annual ±2% points (clamped to [0, 100])
    double clampRate(double a) => a.clamp(0, 100);
    final annualLow = clampRate(annual - 2);
    final annualHigh = clampRate(annual + 2);
    List<double> simulateValues(double annualAssumed) {
      final rr = (annualAssumed / 12) / 100.0;
      double bb = 0;
      final out = <double>[];
      for (int m = 1; m <= n; m++) {
        final interest = rr == 0 ? 0.0 : bb * rr;
        bb += interest;
        bb += P;
        out.add(bb);
      }
      return out;
    }

    final valueSeriesLow = simulateValues(annualLow);
    final valueSeriesHigh = simulateValues(annualHigh);

    // Build yearly chart series from yearly rows
    final investedYr = <double>[];
    final valueYr = <double>[];
    final valueLowYr = <double>[];
    final valueHighYr = <double>[];
    double cumInvYr = 0;
    for (final y in yearly) {
      cumInvYr += y.contribution;
      investedYr.add(cumInvYr);
      valueYr.add(y.endBalance);
    }
    // derive yearly low/high by sampling month 12,24,... or last
    for (int i = 11; i < valueSeriesLow.length; i += 12) {
      valueLowYr.add(valueSeriesLow[i]);
      valueHighYr.add(valueSeriesHigh[i]);
    }
    if (valueSeriesLow.isNotEmpty && (valueSeriesLow.length % 12 != 0)) {
      // ensure last sample if tenure not exact years
      valueLowYr.add(valueSeriesLow.last);
      valueHighYr.add(valueSeriesHigh.last);
    }

    setState(() {
      _maturity = fv;
      _invested = P * n;
      _gains = _maturity! - _invested!;
      _months = n;
      _annualRate = annual;
      _seriesInvested = investedSeries;
      _seriesValue = valueSeries;
      _yearly = yearly;
      _seriesInvestedYr = investedYr;
      _seriesValueYr = valueYr;
      _monthly = monthly;
      _seriesLow = valueSeriesLow;
      _seriesHigh = valueSeriesHigh;
      _seriesLowYr = valueLowYr;
      _seriesHighYr = valueHighYr;
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

  bool _valid() {
    if (_vMoney(_monthlyCtrl.text) != null) return false;
    if (_vRate(_rateCtrl.text) != null) return false;
    if (_vYears(_yearsCtrl.text) != null) return false;
    return true;
  }

  void _resetAll() {
    // Clear inputs
    _monthlyCtrl.clear();
    _rateCtrl.clear();
    _yearsCtrl.clear();
    // Clear computed values and series
    _maturity = null;
    _invested = null;
    _gains = null;
    _months = null;
    _annualRate = null;
    _seriesInvested = const [];
    _seriesValue = const [];
    _yearly = const [];
    _seriesInvestedYr = const [];
    _seriesValueYr = const [];
    _monthly = const [];
    _seriesLow = const [];
    _seriesHigh = const [];
    _seriesLowYr = const [];
    _seriesHighYr = const [];
    // Reset form and unfocus
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    // Also clear persisted SIP values so returning starts fresh
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('sip_monthly');
      prefs.remove('sip_rate');
      prefs.remove('sip_years');
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _monthlyFocus.addListener(() {
      if (!_monthlyFocus.hasFocus) {
        final raw = _monthlyCtrl.text.replaceAll(',', '').trim();
        if (raw.isEmpty) return;
        final v = double.tryParse(raw);
        if (v == null) return;
        final formatted = _nf.format(double.parse(v.toStringAsFixed(2)));
        if (_monthlyCtrl.text != formatted) {
          _monthlyCtrl.text = formatted;
          _monthlyCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _monthlyCtrl.text.length),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    // Ensure persisted SIP values are cleared when leaving this screen
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('sip_monthly');
      prefs.remove('sip_rate');
      prefs.remove('sip_years');
    });
    _monthlyFocus.dispose();
    _monthlyCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Local theme for SIP derived from the app's existing color scheme
    final base = Theme.of(context);
    final seed = base.colorScheme.primary;
    final themed = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: base.brightness,
    );

    final isNarrow = MediaQuery.of(context).size.width < 500;
    final gap = isNarrow ? 16.0 : 12.0;

    return Theme(
      data: themed,
      child: Builder(builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              _resetAll();
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFE0F2F1),
            appBar: AppBar(
              backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFE0F2F1),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('SIP Calculator'),
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
                      tooltip: 'SIP explained',
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
                                      Text('What is SIP?',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'A Systematic Investment Plan (SIP) lets you invest a fixed amount at regular intervals into a mutual fund. It averages out purchase cost, builds discipline, and helps compound returns over time.',
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
                                    '• Invest small amounts periodically\n• Benefit from rupee-cost averaging\n• Power of compounding over long term\n• Flexible amount and tenure',
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
            body: Container(
              decoration: Theme.of(ctx).brightness == Brightness.dark
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
                    // Local input decoration theme to match unified style
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Builder(builder: (_) {
                            final inputDecorationTheme = InputDecorationTheme(
                              filled: true,
                              fillColor: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.18),
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
                                borderSide:
                                    BorderSide(color: cs.primary, width: 1.8),
                              ),
                              prefixIconColor: cs.primary,
                              labelStyle: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.8)),
                              hintStyle: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.6)),
                            );
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(14)),
                                color:
                                    Theme.of(ctx).brightness == Brightness.dark
                                        ? const Color(0xFF1E1E1E)
                                        : null,
                                gradient:
                                    Theme.of(ctx).brightness == Brightness.light
                                        ? LinearGradient(colors: [
                                            cs.primary.withValues(alpha: 0.10),
                                            cs.surface.withValues(alpha: 0.50),
                                          ])
                                        : null,
                                border: Border.all(
                                    color: Theme.of(ctx).brightness ==
                                            Brightness.dark
                                        ? cs.outline.withValues(alpha: 0.2)
                                        : cs.outlineVariant
                                            .withValues(alpha: 0.5),
                                    width: Theme.of(ctx).brightness ==
                                            Brightness.dark
                                        ? 0.5
                                        : 1.0),
                                boxShadow: Theme.of(ctx).brightness ==
                                        Brightness.dark
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
                                          color:
                                              cs.shadow.withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Theme(
                                data: Theme.of(ctx).copyWith(
                                    inputDecorationTheme: inputDecorationTheme),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _monthlyCtrl,
                                      focusNode: _monthlyFocus,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textInputAction: TextInputAction.next,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.,]'))
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Monthly Investment',
                                        hintText: 'e.g. 5000',
                                        prefixText: '₹ ',
                                        prefixIcon: const Icon(
                                            Icons.ssid_chart_rounded),
                                        suffixIcon: IconButton(
                                          tooltip: 'Clear',
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                  width: 32, height: 32),
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _monthlyCtrl.clear();
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      validator: _vMoney,
                                      onChanged: (_) => setState(() {}),
                                      onFieldSubmitted: (_) => _calc(),
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
                                        labelText: 'Expected Annual Return',
                                        hintText: 'e.g. 12',
                                        suffixText: '%',
                                        prefixIcon:
                                            const Icon(Icons.percent_rounded),
                                        suffixIcon: IconButton(
                                          tooltip: 'Clear',
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                  width: 32, height: 32),
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _rateCtrl.clear();
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      validator: _vRate,
                                      onChanged: (_) => setState(() {}),
                                      onFieldSubmitted: (_) => _calc(),
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
                                        hintText: 'e.g. 10',
                                        suffixText: 'years',
                                        prefixIcon: const Icon(
                                            Icons.calendar_month_rounded),
                                        suffixIcon: IconButton(
                                          tooltip: 'Clear',
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                  width: 32, height: 32),
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _yearsCtrl.clear();
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      validator: _vYears,
                                      onChanged: (_) => setState(() {}),
                                      onFieldSubmitted: (_) => _calc(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          SizedBox(height: gap + 4),
                          SizedBox(
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(20)),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    cs.primary,
                                    cs.primaryContainer
                                  ]),
                                ),
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shadowColor:
                                        cs.primary.withValues(alpha: 0.35),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  onPressed: _valid()
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          _calc();
                                        }
                                      : null,
                                  child: const Text('Calculate SIP'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_maturity != null)
                      Card(
                        elevation: 0,
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? cs.surfaceContainerHigh
                            : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? cs.outline.withValues(alpha: 0.2)
                                  : cs.outlineVariant,
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
                              // Full-width KPI panel with teal shading
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  gradient: LinearGradient(colors: [
                                    cs.primary.withValues(alpha: 0.12),
                                    cs.surfaceContainerHigh
                                        .withValues(alpha: 0.28),
                                  ]),
                                  border: Border.all(
                                      color: cs.primary.withValues(alpha: 0.25),
                                      width: 0.8),
                                ),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _kpiChip(
                                        ctx,
                                        'Maturity',
                                        _nf.format(double.parse(
                                            _maturity!.toStringAsFixed(2)))),
                                    _kpiChip(
                                        ctx,
                                        'Invested',
                                        _nf.format(double.parse(
                                            _invested!.toStringAsFixed(2)))),
                                    _kpiChip(
                                        ctx,
                                        'Gains',
                                        _nf.format(double.parse(
                                            _gains!.toStringAsFixed(2))))
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Builder(builder: (_) {
                                final invested = _invested ?? 0;
                                final gains = _gains ?? 0;
                                final total = (invested + gains) == 0
                                    ? 1.0
                                    : (invested + gains);
                                final invRatio =
                                    (invested / total).clamp(0.0, 1.0);
                                final gainRatio =
                                    (gains / total).clamp(0.0, 1.0);
                                final invFlex =
                                    (invRatio * 1000).round().clamp(1, 1000);
                                final gainFlex =
                                    (gainRatio * 1000).round().clamp(1, 1000);
                                final cs2 = Theme.of(ctx).colorScheme;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(8)),
                                      child: Stack(
                                        children: [
                                          Row(children: [
                                            Expanded(
                                                flex: invFlex,
                                                child: Container(
                                                    height: 20,
                                                    color: cs2.primary
                                                        .withValues(
                                                            alpha: 0.85))),
                                            Expanded(
                                                flex: gainFlex,
                                                child: Container(
                                                    height: 20,
                                                    color: cs2.tertiary
                                                        .withValues(
                                                            alpha: 0.85))),
                                          ]),
                                          Row(children: [
                                            Expanded(
                                              flex: invFlex,
                                              child: SizedBox(
                                                height: 20,
                                                child: Center(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      '${(invRatio * 100).toStringAsFixed(0)}%',
                                                      style: TextStyle(
                                                          color: cs2.onPrimary,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: gainFlex,
                                              child: SizedBox(
                                                height: 20,
                                                child: Center(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      '${(gainRatio * 100).toStringAsFixed(0)}%',
                                                      style: TextStyle(
                                                          color: cs2.onTertiary,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _legendSIP(cs2.primary, 'Invested'),
                                        _legendSIP(cs2.tertiary, 'Gains'),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                              const SizedBox(height: 8),
                              if (_months != null && _annualRate != null)
                                Text(
                                    'Computed at ${_annualRate!.toStringAsFixed(2)}% for $_months months',
                                    style: Theme.of(ctx).textTheme.bodySmall),
                              const SizedBox(height: 16),
                              if (_seriesValue.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Projected Growth',
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 180,
                                      width: double.infinity,
                                      child: _GrowthChart(
                                        invested: _chartYearly
                                            ? _seriesInvestedYr
                                            : _seriesInvested,
                                        value: _chartYearly
                                            ? _seriesValueYr
                                            : _seriesValue,
                                        bandLow: _chartYearly
                                            ? _seriesLowYr
                                            : _seriesLow,
                                        bandHigh: _chartYearly
                                            ? _seriesHighYr
                                            : _seriesHigh,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SegmentedButton<bool>(
                                            segments: const [
                                              ButtonSegment(
                                                  value: false,
                                                  label: Text('Monthly')),
                                              ButtonSegment(
                                                  value: true,
                                                  label: Text('Yearly')),
                                            ],
                                            selected: {_chartYearly},
                                            onSelectionChanged: (s) => setState(
                                                () => _chartYearly = s.first),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text('Confidence band (±2%)',
                                            style: Theme.of(ctx)
                                                .textTheme
                                                .bodySmall),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SegmentedButton<bool>(
                                            segments: const [
                                              ButtonSegment(
                                                  value: true,
                                                  label: Text('Yearly')),
                                              ButtonSegment(
                                                  value: false,
                                                  label: Text('Monthly')),
                                            ],
                                            selected: {_tableYearly},
                                            onSelectionChanged: (s) => setState(
                                                () => _tableYearly = s.first),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                        'Based on your inputs, not actual market data',
                                        style:
                                            Theme.of(ctx).textTheme.bodySmall),
                                    const SizedBox(height: 8),
                                    _tableYearly
                                        ? _YearlyTable(rows: _yearly, nf: _nf)
                                        : _MonthlyTable(
                                            rows: _monthly, nf: _nf),
                                  ],
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

class _MonthRow {
  final int month; // 1-based overall month
  final double startBalance;
  final double contribution;
  final double interest;
  final double endBalance;
  _MonthRow(
      {required this.month,
      required this.startBalance,
      required this.contribution,
      required this.interest,
      required this.endBalance});
}

class _MonthlyTable extends StatelessWidget {
  final List<_MonthRow> rows;
  final NumberFormat nf;
  const _MonthlyTable({required this.rows, required this.nf});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.labelLarge;
    final valueStyle =
        TextStyle(fontWeight: FontWeight.w700, color: cs.primary);
    // Paginate a little by showing up to first 240 months
    final capped = rows.length > 240 ? rows.take(240).toList() : rows;
    return SizedBox(
      height: 300,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: [
                DataColumn(label: Text('Month', style: headerStyle)),
                DataColumn(label: Text('Start', style: headerStyle)),
                DataColumn(label: Text('Contribution', style: headerStyle)),
                DataColumn(label: Text('Interest', style: headerStyle)),
                DataColumn(label: Text('End', style: headerStyle)),
              ],
              rows: capped.map((r) {
                return DataRow(cells: [
                  DataCell(Text('${r.month}', style: headerStyle)),
                  DataCell(Text(
                      nf.format(
                          double.parse(r.startBalance.toStringAsFixed(2))),
                      style: headerStyle)),
                  DataCell(Text(
                      nf.format(
                          double.parse(r.contribution.toStringAsFixed(2))),
                      style: valueStyle)),
                  DataCell(Text(
                      nf.format(double.parse(r.interest.toStringAsFixed(2))),
                      style: valueStyle)),
                  DataCell(Text(
                      nf.format(double.parse(r.endBalance.toStringAsFixed(2))),
                      style: headerStyle)),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowthChart extends StatelessWidget {
  final List<double> invested;
  final List<double> value;
  final List<double>? bandLow;
  final List<double>? bandHigh;
  const _GrowthChart(
      {required this.invested,
      required this.value,
      this.bandLow,
      this.bandHigh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _GrowthPainter(
        invested: invested,
        value: value,
        bandLow: bandLow,
        bandHigh: bandHigh,
        lineInvested: cs.tertiary,
        lineValue: cs.primary,
        fillValue: cs.primary.withValues(alpha: 0.18),
        grid:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  final List<double> invested;
  final List<double> value;
  final List<double>? bandLow;
  final List<double>? bandHigh;
  final Color lineInvested;
  final Color lineValue;
  final Color fillValue;
  final Color grid;

  _GrowthPainter({
    required this.invested,
    required this.value,
    this.bandLow,
    this.bandHigh,
    required this.lineInvested,
    required this.lineValue,
    required this.fillValue,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (value.isEmpty) return;
    const padding = 12.0;
    final plot = Rect.fromLTWH(
        padding, padding, size.width - 2 * padding, size.height - 2 * padding);
    final maxY = value.fold<double>(0, (p, e) => e > p ? e : p);
    final count = value.length;
    double xOf(int i) =>
        count == 1 ? plot.left : plot.left + (i / (count - 1)) * plot.width;
    double yOf(double y) =>
        plot.bottom - (y / (maxY == 0 ? 1 : maxY)) * plot.height;

    // grid (horizontal 4 lines)
    final gridPaint = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final yy = plot.top + (g / 4) * plot.height;
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), gridPaint);
    }

    // optional confidence band (draw before area/lines)
    if (bandLow != null &&
        bandHigh != null &&
        bandLow!.length == value.length &&
        bandHigh!.length == value.length) {
      final bandPath = Path()..moveTo(xOf(0), yOf(bandLow![0]));
      for (int i = 1; i < count; i++) {
        bandPath.lineTo(xOf(i), yOf(bandLow![i]));
      }
      for (int i = count - 1; i >= 0; i--) {
        bandPath.lineTo(xOf(i), yOf(bandHigh![i]));
      }
      bandPath.close();
      final bandPaint = Paint()
        ..color = lineValue.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(bandPath, bandPaint);
    }

    // value area
    final areaPath = Path()..moveTo(plot.left, plot.bottom);
    for (int i = 0; i < count; i++) {
      areaPath.lineTo(xOf(i), yOf(value[i]));
    }
    areaPath.lineTo(plot.right, plot.bottom);
    areaPath.close();
    canvas.drawPath(
        areaPath,
        Paint()
          ..color = fillValue
          ..style = PaintingStyle.fill);

    // value line
    final valuePath = Path()..moveTo(xOf(0), yOf(value[0]));
    for (int i = 1; i < count; i++) {
      valuePath.lineTo(xOf(i), yOf(value[i]));
    }
    canvas.drawPath(
        valuePath,
        Paint()
          ..color = lineValue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2);

    // invested line
    if (invested.length == count) {
      final invPath = Path()..moveTo(xOf(0), yOf(invested[0]));
      for (int i = 1; i < count; i++) {
        invPath.lineTo(xOf(i), yOf(invested[i]));
      }
      canvas.drawPath(
          invPath,
          Paint()
            ..color = lineInvested
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter oldDelegate) {
    return oldDelegate.invested != invested ||
        oldDelegate.value != value ||
        oldDelegate.lineInvested != lineInvested ||
        oldDelegate.lineValue != lineValue ||
        oldDelegate.fillValue != fillValue;
  }
}

class _YearRow {
  final int year;
  final double startBalance;
  final double contribution;
  final double interest;
  final double endBalance;
  _YearRow(
      {required this.year,
      required this.startBalance,
      required this.contribution,
      required this.interest,
      required this.endBalance});
}

class _YearlyTable extends StatelessWidget {
  final List<_YearRow> rows;
  final NumberFormat nf;
  const _YearlyTable({required this.rows, required this.nf});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.labelLarge;
    final valueStyle =
        TextStyle(fontWeight: FontWeight.w700, color: cs.primary);
    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text('Year', style: headerStyle)),
            DataColumn(label: Text('Start', style: headerStyle)),
            DataColumn(label: Text('Contribution', style: headerStyle)),
            DataColumn(label: Text('Interest', style: headerStyle)),
            DataColumn(label: Text('End', style: headerStyle)),
          ],
          rows: rows.map((r) {
            return DataRow(cells: [
              DataCell(Text('${r.year}')),
              DataCell(Text(
                  nf.format(double.parse(r.startBalance.toStringAsFixed(2))))),
              DataCell(Text(
                  nf.format(double.parse(r.contribution.toStringAsFixed(2))),
                  style: valueStyle)),
              DataCell(Text(
                  nf.format(double.parse(r.interest.toStringAsFixed(2))),
                  style: valueStyle)),
              DataCell(Text(
                  nf.format(double.parse(r.endBalance.toStringAsFixed(2))))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
