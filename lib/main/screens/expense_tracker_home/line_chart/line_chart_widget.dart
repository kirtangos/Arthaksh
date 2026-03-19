import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arthaksh/services/currency_service.dart';
import 'package:arthaksh/services/settings_service.dart';
import 'line_chart_analysis_screen.dart';
import 'dart:math' as math;
import 'dart:async';

class LineChartWidget extends StatefulWidget {
  const LineChartWidget({super.key});

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  List<FlSpot> _chartData = [];
  bool _isLoading = true;
  String _currentCurrency = 'USD';
  double _maxExpense = 0;
  Timer? _refreshTimer;
  StreamSubscription<QuerySnapshot>? _expensesSubscription;

  @override
  void initState() {
    super.initState();
    _setupAutomaticRefresh();
    _loadData();
  }

  void _setupAutomaticRefresh() {
    // Set up periodic timer for date changes (every minute)
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadData();
      }
    });

    // Set up real-time expense data listener for last 7 days
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final now = DateTime.now();
      final startDate = DateTime(
          now.year, now.month, now.day - 6); // 7 days ago (including today)

      _expensesSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .snapshots()
          .listen((_) {
        if (mounted) {
          _loadData();
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _expensesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final currency = await SettingsService.getSelectedCurrency();
      if (mounted) {
        setState(() {
          _currentCurrency = currency;
        });
      }

      // Ensure currency cache is initialized for conversions
      await CurrencyService.ensureCacheInitialized();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get last 7 days data
      final now = DateTime.now();
      final startDate = DateTime(
          now.year, now.month, now.day - 6); // 7 days ago (including today)
      final endDate =
          DateTime(now.year, now.month, now.day + 1, 0, 0, -1); // End of today

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date')
          .get();

      if (mounted) {
        _processChartData(snap.docs);
      }
    } catch (e) {
      debugPrint('Error loading line chart data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _processChartData(List<QueryDocumentSnapshot> docs) {
    final Map<DateTime, double> dailyExpenses = {};
    final now = DateTime.now();

    // Initialize all days with 0
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      dailyExpenses[date] = 0.0;
    }

    // Sum expenses by day (filtering for expenses only in memory)
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = (data['type'] as String?)?.toLowerCase().trim() ?? 'expense';

      // Only consider expense transactions
      if (type != 'expense') continue;

      final date = (data['date'] as Timestamp).toDate();
      final dateKey = DateTime(date.year, date.month, date.day);
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final currency = data['currency'] as String? ?? 'INR';

      // Convert to current currency
      final convertedAmount =
          CurrencyService.convertAmountSync(amount, currency, _currentCurrency);

      if (dailyExpenses.containsKey(dateKey)) {
        dailyExpenses[dateKey] =
            (dailyExpenses[dateKey] ?? 0.0) + convertedAmount;
      }
    }

    // Create chart data points
    final List<FlSpot> spots = [];
    double maxExpense = 0;

    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day - (6 - i));
      final expense = dailyExpenses[date] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), expense));
      maxExpense = maxExpense < expense ? expense : maxExpense;
    }

    if (mounted) {
      setState(() {
        _chartData = spots;
        _maxExpense = maxExpense;
        _isLoading = false;
      });
    }
  }

  String _getDayLabel(int index) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day - (6 - index));

    if (index == 6) {
      return 'Today';
    } else if (index == 5) {
      return 'Yesterday';
    } else {
      return DateFormat('EEE').format(date);
    }
  }

  double _calculateYAxisInterval() {
    if (_maxExpense <= 0) return 5;

    // Calculate interval based on actual data range for better scaling
    final range = _maxExpense;

    // Special handling for INR currency (more appropriate intervals)
    if (_currentCurrency == 'INR') {
      if (range <= 100) return 25; // 0, 25, 50, 75, 100
      if (range <= 250) return 50; // 0, 50, 100, 150, 200, 250
      if (range <= 500) return 100; // 0, 100, 200, 300, 400, 500
      if (range <= 1000) return 200; // 0, 200, 400, 600, 800, 1000
      if (range <= 2500) return 500; // 0, 500, 1000, 1500, 2000, 2500
      if (range <= 5000) return 1000; // 0, 1000, 2000, 3000, 4000, 5000
      if (range <= 10000) return 2000; // 0, 2000, 4000, 6000, 8000, 10000
      if (range <= 25000) return 5000; // 0, 5000, 10000, 15000, 20000, 25000
      if (range <= 50000) return 10000; // 0, 10000, 20000, 30000, 40000, 50000
    }

    // Use very fine-grained intervals for other currencies
    if (range <= 10) return 2; // 0, 2, 4, 6, 8, 10
    if (range <= 20) return 4; // 0, 4, 8, 12, 16, 20
    if (range <= 30) return 5; // 0, 5, 10, 15, 20, 25, 30
    if (range <= 50) return 10; // 0, 10, 20, 30, 40, 50
    if (range <= 75) return 15; // 0, 15, 30, 45, 60, 75
    if (range <= 100) return 20; // 0, 20, 40, 60, 80, 100
    if (range <= 150) return 25; // 0, 25, 50, 75, 100, 125, 150
    if (range <= 200) return 25; // 0, 25, 50, 75, 100, 125, 150, 175, 200
    if (range <= 300) return 50; // 0, 50, 100, 150, 200, 250, 300
    if (range <= 500)
      return 50; // 0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500
    if (range <= 750) return 100; // 0, 100, 200, 300, 400, 500, 600, 700, 750
    if (range <= 1000)
      return 100; // 0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000
    if (range <= 1500) return 200; // 0, 200, 400, 600, 800, 1000, 1200, 1400
    if (range <= 2000)
      return 200; // 0, 200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000
    if (range <= 3000) return 500; // 0, 500, 1000, 1500, 2000, 2500, 3000
    if (range <= 5000)
      return 500; // 0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000
    if (range <= 7500)
      return 1000; // 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 7500
    if (range <= 10000)
      return 1000; // 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000
    if (range <= 15000)
      return 2000; // 0, 2000, 4000, 6000, 8000, 10000, 12000, 14000
    if (range <= 20000)
      return 2000; // 0, 2000, 4000, 6000, 8000, 10000, 12000, 14000, 16000, 18000, 20000
    if (range <= 30000)
      return 5000; // 0, 5000, 10000, 15000, 20000, 25000, 30000
    if (range <= 50000)
      return 5000; // 0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000, 50000

    // For larger values, use appropriate intervals
    final roughInterval = range / 6; // Show about 6 grid lines for more detail
    final magnitude = math.pow(10, roughInterval.toString().length - 1);
    return (roughInterval / magnitude).ceil() * magnitude.toDouble();
  }

  String _formatYAxisValue(double value) {
    if (value == 0) return '0';

    // Format based on magnitude
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toInt().toString();
    }
  }

  Widget _buildChart() {
    if (_chartData.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No expense data available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'for this month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optimized header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        size: 16,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'This Month',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _navigateToAnalysis(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cs.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Optimized chart container
            GestureDetector(
              onTap: () => _navigateToAnalysis(),
              child: Container(
                height: 200, // Optimized height
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: cs.outline.withOpacity(0.1),
                  ),
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval:
                          _calculateYAxisInterval(), // Use same interval as labels
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[300],
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < 7) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  _getDayLabel(index),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle
                                            .italic, // ✅ Added italic style
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 70,
                          interval:
                              _calculateYAxisInterval(), // Calculate proper interval
                          getTitlesWidget: (value, meta) {
                            return Text(
                              CurrencyService.getCurrencySymbol(
                                      _currentCurrency) +
                                  _formatYAxisValue(value),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    // Snap maxY to the next multiple of the interval to avoid duplicate top labels
                    maxY: () {
                      final interval = _calculateYAxisInterval();
                      if (interval <= 0) {
                        return _maxExpense == 0 ? 1.0 : _maxExpense;
                      }
                      final rawMax = _maxExpense * 1.2;
                      final steps = (rawMax / interval).ceil();
                      return (steps * interval).toDouble();
                    }(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _chartData,
                        isCurved:
                            true, // Changed back to true for smoother lines
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withOpacity(0.8),
                            cs.primary.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: _chartData.length <=
                              7, // Only show dots for 7 days
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3,
                              color: cs.primary,
                              strokeWidth: 1.5,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              cs.primary.withOpacity(0.2),
                              cs.primary.withOpacity(0.05),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Colors.black87,
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(8),
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            final index = spot.x.toInt();
                            final dayLabel = _getDayLabel(index);
                            final amount = CurrencyService.getCurrencySymbol(
                                    _currentCurrency) +
                                spot.y.toStringAsFixed(0);

                            return LineTooltipItem(
                              '$dayLabel\n$amount',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAnalysis() {
    if (_chartData.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LineChartAnalysisScreen(
            chartData: _chartData,
            currentCurrency: _currentCurrency,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      color: cs.surface,
      child: _isLoading
          ? const SizedBox(
              height: 380, // Adjusted height for title + chart
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _buildChart(),
    );
  }
}
