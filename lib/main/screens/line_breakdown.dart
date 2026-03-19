import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/ui/theme_extensions.dart';

class LineBreakdownScreen extends StatefulWidget {
  const LineBreakdownScreen({super.key});

  @override
  State<LineBreakdownScreen> createState() => _LineBreakdownScreenState();
}

class _LineBreakdownScreenState extends State<LineBreakdownScreen> {
  static const _intervals = <String, Duration>{
    'Last 7 days': Duration(days: 7),
    'Last 30 days': Duration(days: 30),
    'Last 90 days': Duration(days: 90),
    'This month': Duration(days: -1), // special handling
  };

  String _selectedInterval = 'Last 30 days';
  String _selectedType = 'All'; // All | Expense | Income | Transfer

  DateTimeRange _computeRange() {
    final now = DateTime.now();
    if (_selectedInterval == 'This month') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1);
      return DateTimeRange(start: start, end: end);
    }
    final dur = _intervals[_selectedInterval] ?? const Duration(days: 30);
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
        appBar: AppBar(title: const Text('Line Breakdown')),
        body: const Center(child: Text('Please log in to view breakdown.')),
      );
    }

    final range = _computeRange();

    Query<Map<String, dynamic>> base = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses');

    // For aggregation we don't need orderBy; we'll group client-side.
    if (_selectedInterval != 'All time') {
      base = base
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
          .where('date', isLessThan: Timestamp.fromDate(range.end));
    }

    final days = <DateTime>[];
    for (var d = range.start;
        d.isBefore(range.end);
        d = d.add(const Duration(days: 1))) {
      days.add(DateTime(d.year, d.month, d.day));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Line Breakdown'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
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
                const SizedBox(width: 12),
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
            const SizedBox(height: 12),
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
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Failed to load data\n${snapshot.error}', textAlign: TextAlign.center),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  // Prepare maps: date -> amount per type
                  final byDay = <DateTime, Map<String, double>>{};
                  for (final dt in days) {
                    byDay[dt] = {'Expense': 0.0, 'Income': 0.0, 'Transfer': 0.0};
                  }

                  for (final d in docs) {
                    final data = d.data();
                    final ts = data['date'];
                    DateTime? day;
                    if (ts is Timestamp) {
                      final t = ts.toDate();
                      day = DateTime(t.year, t.month, t.day);
                    }
                    if (day == null) continue;
                    final type = (data['type'] ?? '').toString();
                    final amt = (data['amount'] is num)
                        ? (data['amount'] as num).toDouble()
                        : 0.0;
                    if (!byDay.containsKey(day)) continue;
                    if (type == 'Expense' || type == 'Income' || type == 'Transfer') {
                      byDay[day]![type] = (byDay[day]![type] ?? 0) + amt;
                    }
                  }

                  // Build spots sequence by index
                  final spotsExp = <FlSpot>[];
                  final spotsInc = <FlSpot>[];
                  final spotsTrn = <FlSpot>[];

                  for (var i = 0; i < days.length; i++) {
                    final day = days[i];
                    final map = byDay[day]!;
                    spotsExp.add(FlSpot(i.toDouble(), map['Expense'] ?? 0));
                    spotsInc.add(FlSpot(i.toDouble(), map['Income'] ?? 0));
                    spotsTrn.add(FlSpot(i.toDouble(), map['Transfer'] ?? 0));
                  }

                  final showExp = _selectedType == 'All' || _selectedType == 'Expense';
                  final showInc = _selectedType == 'All' || _selectedType == 'Income';
                  final showTrn = _selectedType == 'All' || _selectedType == 'Transfer';

                  // Compute totals for legend/list like the pie screen
                  final totalExp = spotsExp.fold<double>(0, (p, e) => p + e.y);
                  final totalInc = spotsInc.fold<double>(0, (p, e) => p + e.y);
                  final totalTrn = spotsTrn.fold<double>(0, (p, e) => p + e.y);
                  final grand = totalExp + totalInc + totalTrn;

                  if (grand == 0) {
                    final fmt = DateFormat.yMMMd();
                    return Center(
                      child: Text(
                        'No data for $_selectedType in $_selectedInterval\n${fmt.format(range.start)} - ${fmt.format(range.end.subtract(const Duration(days: 1)))}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Y-axis label
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Center(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    _selectedType == 'Expense'
                                        ? 'Amount Spent'
                                        : _selectedType == 'Income'
                                            ? 'Amount Received'
                                            : _selectedType == 'Transfer'
                                                ? 'Amount Transferred'
                                                : 'Amount (₹)',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: LineChart(
                                LineChartData(
                                  minX: 0,
                                  maxX: (days.length - 1).toDouble(),
                                  minY: 0,
                                  clipData: const FlClipData(
                                    top: false,
                                    bottom: false,
                                    left: false,
                                    right: false,
                                  ),
                                  lineTouchData: LineTouchData(
                                    enabled: true,
                                    handleBuiltInTouches: true,
                                    touchTooltipData: LineTouchTooltipData(
                                      fitInsideHorizontally: true,
                                      fitInsideVertically: true,
                                      getTooltipItems: (items) {
                                        final fmtCur = NumberFormat.compactCurrency(symbol: '₹');
                                        return items.where((ts) {
                                          // Ignore shadow lines (opacity < 0.8)
                                          final op = ts.bar.color?.a ?? 1;
                                          return op > 0.8;
                                        }).map((ts) {
                                          if (days.isEmpty) return LineTooltipItem('', const TextStyle());
                                          final idx = ts.x.round().clamp(0, days.length - 1);
                                          final dayStr = DateFormat('MMM d').format(days[idx]);
                                          return LineTooltipItem('$dayStr\n${fmtCur.format(ts.y)}', theme.textTheme.labelLarge ?? const TextStyle());
                                        }).toList();
                                      },
                                    ),
                                    touchSpotThreshold: 16,
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: _horizontalInterval([spotsExp, spotsInc, spotsTrn]),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 48,
                                        interval: _horizontalInterval([spotsExp, spotsInc, spotsTrn]),
                                        getTitlesWidget: (value, meta) {
                                          final s = NumberFormat.compactCurrency(symbol: '₹').format(value);
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Text(
                                              s,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: cs.onSurface.withValues(alpha: 0.7),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 22,
                                        interval: (days.length / 6).clamp(1, 6).toDouble(),
                                        getTitlesWidget: (value, meta) {
                                          final i = value.round();
                                          if (i < 0 || i >= days.length) return const SizedBox.shrink();
                                          final s = DateFormat('d MMM').format(days[i]);
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(s, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    if (showExp) ...[
                                      LineChartBarData(
                                        spots: spotsExp,
                                        isCurved: true,
                                        preventCurveOverShooting: true,
                                        curveSmoothness: 0.05,
                                        color: cs.primary.withValues(alpha: 0.22),
                                        barWidth: 7,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                      ),
                                      LineChartBarData(
                                        spots: spotsExp,
                                        isCurved: true,
                                        preventCurveOverShooting: true,
                                        curveSmoothness: 0.05,
                                        color: cs.primary,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                      ),
                                    ],
                                    if (showInc) ...[
                                      LineChartBarData(
                                        spots: spotsInc,
                                        isCurved: true,
                                        preventCurveOverShooting: true,
                                        curveSmoothness: 0.05,
                                        color: (Theme.of(context).extension<SuccessColors>()?.success ?? Theme.of(context).colorScheme.tertiary).withValues(alpha: 0.22),
                                        barWidth: 7,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                      ),
                                      LineChartBarData(
                                        spots: spotsInc,
                                        isCurved: true,
                                        preventCurveOverShooting: true,
                                        curveSmoothness: 0.05,
                                        color: Theme.of(context).extension<SuccessColors>()?.success ?? Theme.of(context).colorScheme.tertiary,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                      ),
                                    ],
                                    if (showTrn) ...[
                                      LineChartBarData(
                                        spots: spotsTrn,
                                        isCurved: true,
                                        preventCurveOverShooting: true,
                                        curveSmoothness: 0.05,
                                        color: cs.secondary.withValues(alpha: 0.22),
                                        barWidth: 7,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                      ),
                                      LineChartBarData(
                                        spots: spotsTrn,
                                        isCurved: true,
                                        preventCurveOverShooting: true,
                                        curveSmoothness: 0.05,
                                        color: cs.secondary,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: 3,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            late final String label;
                            late final Color color;
                            late final double value;
                            if (index == 0) {
                              label = 'Expense'; color = cs.primary; value = totalExp;
                            } else if (index == 1) {
                              label = 'Income'; color = Theme.of(context).extension<SuccessColors>()?.success ?? cs.tertiary; value = totalInc;
                            } else {
                              label = 'Transfer'; color = cs.secondary; value = totalTrn;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  ),
                                  Text(
                                    NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(value),
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _horizontalInterval(List<List<FlSpot>> series) {
    final maxVal = series
        .expand((e) => e)
        .fold<double>(0, (p, c) => c.y > p ? c.y : p);
    return (maxVal / 4).clamp(1, 100000).toDouble();
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
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
