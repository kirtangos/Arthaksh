import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/ui/app_input.dart';
import 'package:arthaksh/ui/theme_extensions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arthaksh/services/settings_service.dart';
import 'package:arthaksh/services/currency_service.dart';

class SpendingBreakdownScreen extends StatefulWidget {
  const SpendingBreakdownScreen({super.key});

  @override
  State<SpendingBreakdownScreen> createState() =>
      _SpendingBreakdownScreenState();
}

class _SpendingBreakdownScreenState extends State<SpendingBreakdownScreen> {
  // Time intervals
  static const _intervals = <String, Duration>{
    'All time': Duration(days: 0), // special: no date filter
    'Last 7 days': Duration(days: 7),
    'Last 30 days': Duration(days: 30),
    'Last 90 days': Duration(days: 90),
    'This month': Duration(days: -1), // special handling
  };

  String _selectedInterval = 'This month';
  String _selectedType = 'All'; // All | Expense | Income | Transfer

  // Compare feature
  bool _compare = false;
  String _compareInterval = 'Last 30 days';

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  DateTimeRange _computeRange() {
    final now = DateTime.now();
    if (_selectedInterval == 'This month') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1);
      return DateTimeRange(start: start, end: end);
    }
    if (_selectedInterval == 'All time') {
      // Return a very wide range; query builder will ignore date filters for this option
      final start = DateTime(1970);
      final end = DateTime(now.year, now.month, now.day + 1);
      return DateTimeRange(start: start, end: end);
    }
    final dur = _intervals[_selectedInterval] ?? const Duration(days: 30);
    final end = DateTime(now.year, now.month, now.day + 1); // exclusive end
    final start = end.subtract(dur);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _computeRangeFor(String interval) {
    final now = DateTime.now();
    if (interval == 'This month') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1);
      return DateTimeRange(start: start, end: end);
    }
    if (interval == 'All time') {
      final start = DateTime(1970);
      final end = DateTime(now.year, now.month, now.day + 1);
      return DateTimeRange(start: start, end: end);
    }
    final dur = _intervals[interval] ?? const Duration(days: 30);
    final end = DateTime(now.year, now.month, now.day + 1);
    final start = end.subtract(dur);
    return DateTimeRange(start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Breakdown')),
        body: const Center(child: Text('Please log in to view breakdown.')),
      );
    }

    final range = _computeRange();

    Query<Map<String, dynamic>> base = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses');

    if (_selectedInterval != 'All time') {
      base = base
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
          .where('date', isLessThan: Timestamp.fromDate(range.end));
    }

    // Do NOT filter by 'type' on the server to avoid composite index requirements.
    // We'll filter client-side in aggregation below.
    // Avoid composite index requirement: no explicit orderBy needed for aggregation

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Breakdown'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10), // Reduced from 12 proportionally
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters row
            Row(
              children: [
                Expanded(
                  child: _Dropdown<String>(
                    label: 'Time Interval',
                    value: _selectedInterval,
                    items: _intervals.keys.toList(),
                    onChanged: (v) => setState(() => _selectedInterval = v!),
                  ),
                ),
                const SizedBox(width: 10), // Reduced from 12 proportionally
                Expanded(
                  child: _Dropdown<String>(
                    label: 'Type',
                    value: _selectedType,
                    items: const ['All', 'Expense', 'Income', 'Transfer'],
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Reduced from 10 proportionally
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: _compare,
                        onChanged: (v) => setState(() => _compare = v),
                        thumbColor: WidgetStatePropertyAll(cs.primary),
                      ),
                      const SizedBox(width: 4), // Reduced from 6 proportionally
                      Text('Compare',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12)), // Reduced proportionally
                    ],
                  ),
                ),
                if (_compare) ...[
                  Expanded(
                    child: _Dropdown<String>(
                      label: 'Compare With',
                      value: _compareInterval,
                      items: _intervals.keys.toList(),
                      onChanged: (v) => setState(() => _compareInterval = v!),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10), // Reduced from 12 proportionally
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: base.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(
                            12.0), // Reduced from 16.0 proportionally
                        child: Text(
                          'Failed to load breakdown\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12), // Reduced proportionally
                        ),
                      ),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    final fmt = DateFormat.yMMMd();
                    return Center(
                      child: Text(
                        'No data for $_selectedType in $_selectedInterval\n${fmt.format(range.start)} - ${fmt.format(range.end.subtract(const Duration(days: 1)))}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 12), // Reduced proportionally
                      ),
                    );
                  }

                  // Aggregate by category
                  final Map<String, double> byCat = {};
                  for (final d in docs) {
                    final data = d.data();
                    // Client-side type filter to avoid composite index
                    if (_selectedType != 'All') {
                      final dt = (data['type'] ?? '').toString();
                      if (dt != _selectedType) continue;
                    }
                    var cat = (data['category'] ?? '').toString().trim();
                    if (cat.isEmpty) cat = 'Uncategorized';
                    final amt = (data['amount'] is num)
                        ? (data['amount'] as num).toDouble()
                        : 0.0;
                    byCat[cat] = (byCat[cat] ?? 0) + amt;
                  }
                  final entries = byCat.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  // Color palette
                  final palette = <Color>[
                    cs.primary,
                    cs.secondary,
                    cs.tertiary,
                    cs.error,
                    cs.primaryContainer,
                    cs.secondaryContainer,
                    cs.tertiaryContainer,
                    cs.surfaceTint,
                  ];

                  final total = entries.fold<double>(0, (p, e) => p + e.value);
                  final sections = <PieChartSectionData>[];
                  for (var i = 0; i < entries.length; i++) {
                    final e = entries[i];
                    final pct = total == 0 ? 0.0 : (e.value / total * 100);
                    sections.add(
                      PieChartSectionData(
                        value: e.value,
                        color: palette[i % palette.length],
                        title: pct >= 7 ? '${pct.toStringAsFixed(0)}%' : '',
                        titleStyle: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10, // Reduced proportionally
                        ),
                        radius: 46, // Reduced from 52 proportionally
                        borderSide: BorderSide(
                            color: cs.onSurface.withValues(alpha: 0.08),
                            width: 1.0), // Reduced width proportionally
                      ),
                    );
                  }

                  final chart = Column(
                    children: [
                      SizedBox(
                        height: 200, // Reduced from 220 proportionally
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            sectionsSpace:
                                1.2, // Reduced from 1.5 proportionally
                            centerSpaceRadius:
                                32, // Reduced from 36 proportionally
                          ),
                        ),
                      ),
                      const SizedBox(
                          height: 6), // Reduced from 8 proportionally
                      Expanded(
                        child: ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final e = entries[index];
                            final color = palette[index % palette.length];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical:
                                      8), // Reduced from 12,10 proportionally
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(
                                    8), // Reduced from 10 proportionally
                                border: Border.all(
                                    color: cs.outlineVariant
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10, // Reduced from 12 proportionally
                                    height:
                                        10, // Reduced from 12 proportionally
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(
                                      width:
                                          8), // Reduced from 10 proportionally
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: theme.textTheme
                                          .bodySmall // Reduced from bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize:
                                                  12), // Reduced proportionally
                                    ),
                                  ),
                                  Text(
                                      NumberFormat.currency(
                                              symbol: '₹', decimalDigits: 2)
                                          .format(e.value),
                                      style: theme.textTheme
                                          .bodySmall // Reduced from bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize:
                                                  12)), // Reduced proportionally
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );

                  // Compose comparison and insights panels
                  final children = <Widget>[
                    Expanded(child: chart),
                    const SizedBox(height: 6), // Reduced from 8 proportionally
                    // Reactive Budget section (reads and writes Firestore)
                    _BudgetSection(
                      uid: user.uid,
                      monthKey: _monthKey(DateTime.now()),
                      total: total,
                    ),
                    const SizedBox(height: 6), // Reduced from 8 proportionally
                    _InsightsCard(entries: entries, total: total),
                  ];

                  if (_compare) {
                    final cmpRange = _computeRangeFor(_compareInterval);
                    Query<Map<String, dynamic>> cmp = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('expenses');
                    if (_compareInterval != 'All time') {
                      cmp = cmp
                          .where('date',
                              isGreaterThanOrEqualTo:
                                  Timestamp.fromDate(cmpRange.start))
                          .where('date',
                              isLessThan: Timestamp.fromDate(cmpRange.end));
                    }
                    // One-shot fetch for comparison
                    return Column(children: [
                      Expanded(child: chart),
                      const SizedBox(
                          height: 6), // Reduced from 8 proportionally
                      FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        future: cmp.get(),
                        builder: (context, snap2) {
                          if (snap2.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical:
                                      10), // Reduced from 12 proportionally
                              child: LinearProgressIndicator(),
                            );
                          }
                          final docs2 = snap2.data?.docs ?? [];
                          final Map<String, double> byCat2 = {};
                          for (final d in docs2) {
                            final data = d.data();
                            if (_selectedType != 'All') {
                              final dt = (data['type'] ?? '').toString();
                              if (dt != _selectedType) continue;
                            }
                            var cat =
                                (data['category'] ?? '').toString().trim();
                            if (cat.isEmpty) cat = 'Uncategorized';
                            final amt = (data['amount'] is num)
                                ? (data['amount'] as num).toDouble()
                                : 0.0;
                            byCat2[cat] = (byCat2[cat] ?? 0) + amt;
                          }
                          final entries2 = byCat2.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value));
                          final total2 =
                              entries2.fold<double>(0, (p, e) => p + e.value);
                          return _CompareCard(
                            currentTotal: total,
                            previousTotal: total2,
                            currentTop: entries.take(5).toList(),
                            previousMap: byCat2,
                          );
                        },
                      ),
                      const SizedBox(
                          height: 6), // Reduced from 8 proportionally
                      _BudgetSection(
                          uid: user.uid,
                          monthKey: _monthKey(DateTime.now()),
                          total: total),
                      const SizedBox(
                          height: 6), // Reduced from 8 proportionally
                      _InsightsCard(entries: entries, total: total),
                    ]);
                  }

                  return Column(children: children);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetSection extends StatefulWidget {
  final String uid;
  final String monthKey;
  final double total;
  const _BudgetSection(
      {required this.uid, required this.monthKey, required this.total});

  @override
  State<_BudgetSection> createState() => _BudgetSectionState();
}

class _BudgetSectionState extends State<_BudgetSection> {
  double? _localAmount; // fallback when Firestore read fails

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('budgets')
        .doc(widget.monthKey);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final streamedAmount = data == null
            ? null
            : (data['amount'] is num
                ? (data['amount'] as num).toDouble()
                : (data['overall'] is num
                    ? (data['overall'] as num).toDouble()
                    : null));

        final effectiveAmount = streamedAmount ?? _localAmount;

        // Debug message only if we have no amount to show
        Widget debugMessage = const SizedBox.shrink();
        if (snap.hasError && effectiveAmount == null) {
          debugMessage = Text('Error loading budget: ${snap.error}',
              style: const TextStyle(color: Colors.red));
        } else if (!snap.hasError && !snap.hasData && effectiveAmount == null) {
          debugMessage = const Text('No budget set for this month.',
              style: TextStyle(color: Colors.orange));
        } else if (snap.hasData &&
            streamedAmount == null &&
            effectiveAmount == null) {
          debugMessage = const Text(
              'Budget doc found, but field "amount" missing or not a number.',
              style: TextStyle(color: Colors.orange));
        }

        Future<void> save(double? val) async {
          setState(() => _localAmount = val);
          if (val == null) {
            try {
              await ref.delete();
            } catch (_) {}
          } else {
            try {
              await ref.set(
                  {'amount': val, 'setUp': FieldValue.serverTimestamp()},
                  SetOptions(merge: true));
            } catch (_) {
              // ignore write errors; UI still shows local bar
            }
          }
        }

        final hasBudget = effectiveAmount != null && effectiveAmount > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasBudget) ...[
              _BudgetBar(total: widget.total, budget: effectiveAmount),
              const SizedBox(height: 12), // Reduced from 16 proportionally
            ] else ...[
              const Text(
                'Set up a budget',
                style: TextStyle(
                  fontSize: 14, // Reduced from 16 proportionally
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12), // Reduced from 16 proportionally
            ],
            if (effectiveAmount == null) debugMessage,
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_outlined),
                label: Text(
                    effectiveAmount == null ? 'Set Budget' : 'Edit Budget'),
                onPressed: () async {
                  final controller = TextEditingController(
                    text: effectiveAmount?.toStringAsFixed(2) ?? '',
                  );
                  final val = await showDialog<double?>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Monthly Budget',
                            style: TextStyle(
                                fontSize:
                                    18)), // Reduced from default proportionally
                        content: Padding(
                          padding: const EdgeInsets.only(
                              top: 16), // Reduced from default proportionally
                          child: AppInput(
                            controller: controller,
                            label: 'Budget Amount',
                            prefixText: '₹ ',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20,
                            12), // Reduced from default proportionally
                        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12,
                            12), // Reduced from default proportionally
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, double.nan),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    fontSize: 14)), // Reduced proportionally
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, -1.0),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('Remove',
                                style: TextStyle(
                                    fontSize: 14)), // Reduced proportionally
                          ),
                          FilledButton(
                            onPressed: () {
                              // Sanitize input: keep digits and dot only
                              final raw = controller.text.trim();
                              final sanitized =
                                  raw.replaceAll(RegExp(r'[^0-9\.]'), '');
                              final v = double.tryParse(sanitized);
                              Navigator.pop(ctx, v);
                            },
                            child: const Text('Save',
                                style: TextStyle(
                                    fontSize: 14)), // Reduced proportionally
                          ),
                        ],
                      );
                    },
                  );
                  if (!mounted) return;

                  if (val == -1.0) {
                    // Explicit remove
                    await save(null);
                  } else if (val == null || val.isNaN) {
                    // Invalid or cancelled; do nothing but inform if invalid
                    if (val == null && mounted) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a valid budget amount.')),
                        );
                      }
                    }
                  } else {
                    await save(val);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  const _Dropdown(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: cs.surface.withValues(alpha: 0.4),
        border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8), // Reduced from 10 proportionally
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4), // Reduced from 12,6 proportionally
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(e.toString()),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  final double total;
  final double budget;
  const _BudgetBar({required this.total, required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = budget <= 0 ? 0.0 : (total / budget).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10), // Reduced from 12 proportionally
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.4),
        borderRadius:
            BorderRadius.circular(8), // Reduced from 10 proportionally
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 16), // Reduced from 18 proportionally
              const SizedBox(width: 4), // Reduced from 6 proportionally
              Text('Budget Progress',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12)), // Reduced proportionally
              const Spacer(),
              Text(
                '${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(total)} / ${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(budget)}',
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11), // Reduced proportionally
              ),
            ],
          ),
          const SizedBox(height: 6), // Reduced from 8 proportionally
          ClipRRect(
            borderRadius:
                BorderRadius.circular(6), // Reduced from 8 proportionally
            child: LinearProgressIndicator(
              minHeight: 8, // Reduced from 10 proportionally
              value: pct,
              backgroundColor:
                  cs.surfaceContainerHighest.withValues(alpha: 0.5),
              color: pct >= 1.0 ? cs.error : cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  final double currentTotal;
  final double previousTotal;
  final List<MapEntry<String, double>> currentTop;
  final Map<String, double> previousMap;
  const _CompareCard({
    required this.currentTotal,
    required this.previousTotal,
    required this.currentTop,
    required this.previousMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final delta = currentTotal - previousTotal;
    final pct = previousTotal == 0 ? null : (delta / previousTotal * 100);
    final isUp = (pct ?? (delta > 0 ? 1 : -1)) >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10), // Reduced from 12 proportionally
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.4),
        borderRadius:
            BorderRadius.circular(8), // Reduced from 10 proportionally
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_outlined,
                  size: 16), // Reduced from 18 proportionally
              const SizedBox(width: 4), // Reduced from 6 proportionally
              Text('Comparison',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12)), // Reduced proportionally
              const Spacer(),
              Text(
                '${NumberFormat.compactCurrency(symbol: '₹').format(currentTotal)} vs ${NumberFormat.compactCurrency(symbol: '₹').format(previousTotal)}',
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11), // Reduced proportionally
              ),
            ],
          ),
          const SizedBox(height: 6), // Reduced from 8 proportionally
          Row(
            children: [
              Icon(
                isUp
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isUp
                    ? (Theme.of(context).extension<SuccessColors>()?.success ??
                        Theme.of(context).colorScheme.tertiary)
                    : cs.error,
                size: 14, // Reduced proportionally
              ),
              const SizedBox(width: 4), // Reduced from 6 proportionally
              Text(
                pct == null
                    ? NumberFormat.compactCurrency(symbol: '₹').format(delta)
                    : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)} ( ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% )',
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11), // Reduced proportionally
              ),
            ],
          ),
          const SizedBox(height: 6), // Reduced from 8 proportionally
          // Category deltas for top 3
          ...currentTop.take(3).map((e) {
            final prev = previousMap[e.key] ?? 0.0;
            final d = e.value - prev;
            final up = d >= 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                      child: Text(e.key,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11))), // Reduced proportionally
                  Icon(
                    up ? Icons.north_east : Icons.south_east,
                    size: 14, // Reduced from 16 proportionally
                    color: up
                        ? (Theme.of(context)
                                .extension<SuccessColors>()
                                ?.success ??
                            Theme.of(context).colorScheme.tertiary)
                        : cs.error,
                  ),
                  const SizedBox(width: 4), // Reduced from 6 proportionally
                  Text(
                      '${up ? '+' : ''}${NumberFormat.compactCurrency(symbol: '₹').format(d)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11)), // Reduced proportionally
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatefulWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  const _InsightsCard({required this.entries, required this.total});

  @override
  State<_InsightsCard> createState() => _InsightsCardState();
}

class _InsightsCardState extends State<_InsightsCard> {
  String _selectedCurrency = 'INR';
  double? _convertedTotal;
  Map<String, double?> _convertedEntries = {};

  @override
  void initState() {
    super.initState();
    _loadCurrencySettings();
  }

  @override
  void didUpdateWidget(_InsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload currency settings if the data changed significantly
    if (oldWidget.total != widget.total ||
        oldWidget.entries.length != widget.entries.length) {
      _loadCurrencySettings();
    }
  }

  Future<void> _loadCurrencySettings() async {
    try {
      final currency = await SettingsService.getSelectedCurrency();
      if (mounted) {
        setState(() {
          _selectedCurrency = currency;
        });
        _convertAmounts();
      }
    } catch (e) {
      print('Error loading currency settings: $e');
      // Fallback to INR
      if (mounted) {
        setState(() {
          _selectedCurrency = 'INR';
        });
      }
    }
  }

  Future<void> _convertAmounts() async {
    if (_selectedCurrency == 'INR') {
      // No conversion needed for INR
      if (mounted) {
        setState(() {
          _convertedTotal = widget.total;
          _convertedEntries = Map.fromEntries(
              widget.entries.map((entry) => MapEntry(entry.key, entry.value)));
        });
      }
      return;
    }

    try {
      // Ensure currency cache is initialized for conversions
      await CurrencyService.ensureCacheInitialized();

      // Convert total amount using CurrencyService
      final convertedTotal = await CurrencyService.convertAmount(
          widget.total, 'INR', _selectedCurrency);

      // Convert individual entries using CurrencyService
      final convertedEntries = <String, double?>{};
      for (final entry in widget.entries) {
        final convertedAmount = await CurrencyService.convertAmount(
            entry.value, 'INR', _selectedCurrency);
        convertedEntries[entry.key] = convertedAmount;
      }

      if (mounted) {
        setState(() {
          _convertedTotal = convertedTotal;
          _convertedEntries = convertedEntries;
        });
      }
    } catch (e) {
      print('Error converting currency: $e');
      // Fallback to original amounts
      if (mounted) {
        setState(() {
          _convertedTotal = widget.total;
          _convertedEntries = Map.fromEntries(
              widget.entries.map((entry) => MapEntry(entry.key, entry.value)));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final top = widget.entries.first;
    final topValue = _convertedEntries[top.key] ?? top.value;
    final currentTotal = _convertedTotal ?? widget.total;

    final topShare = currentTotal == 0 ? 0.0 : (topValue / currentTotal * 100);
    final top3Sum = widget.entries
        .take(3)
        .map((e) => _convertedEntries[e.key] ?? e.value)
        .fold<double>(0, (p, e) => p + e);
    final top3Share = currentTotal == 0 ? 0.0 : (top3Sum / currentTotal * 100);
    final cats = widget.entries.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10), // Reduced from 12 proportionally
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.4),
        borderRadius:
            BorderRadius.circular(8), // Reduced from 10 proportionally
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined,
                  size: 16), // Reduced from 18 proportionally
              const SizedBox(width: 4), // Reduced from 6 proportionally
              Text('Insights',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12)), // Reduced proportionally
            ],
          ),
          const SizedBox(height: 6), // Reduced from 8 proportionally
          _InsightRow(
              label: 'Top category',
              value:
                  '${top.key}  ·  ${NumberFormat.currency(symbol: _getCurrencySymbol(_selectedCurrency), decimalDigits: 0).format(topValue)} ( ${topShare.toStringAsFixed(1)}% )'),
          _InsightRow(
              label: 'Top 3 share',
              value: '${top3Share.toStringAsFixed(1)}% of spend'),
          _InsightRow(label: 'Categories used', value: cats.toString()),
        ],
      ),
    );
  }

  String _getCurrencySymbol(String currencyCode) {
    const currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CHF': 'CHF',
      'CAD': 'C\$',
      'AUD': 'A\$',
      'CNY': '¥',
      'INR': '₹',
      'KRW': '₩',
      'BRL': 'R\$',
      'MXN': '\$',
      'RUB': '₽',
      'ZAR': 'R',
      'SGD': 'S\$',
    };
    return currencySymbols[currencyCode] ?? currencyCode;
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  const _InsightRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 1), // Reduced from 2 proportionally
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11))), // Reduced proportionally
          Text(value,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11)), // Reduced proportionally
        ],
      ),
    );
  }
}
