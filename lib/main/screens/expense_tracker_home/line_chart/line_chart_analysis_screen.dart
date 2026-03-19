import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/services/currency_service.dart';
import 'package:arthaksh/services/settings_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LineChartAnalysisScreen extends StatefulWidget {
  final List<FlSpot> chartData;
  final String currentCurrency;

  const LineChartAnalysisScreen({
    super.key,
    required this.chartData,
    required this.currentCurrency,
  });

  @override
  State<LineChartAnalysisScreen> createState() =>
      _LineChartAnalysisScreenState();
}

class _LineChartAnalysisScreenState extends State<LineChartAnalysisScreen> {
  String _currentCurrency = 'USD';
  String _transactionType = 'Expense';
  List<FlSpot> _filteredChartData = [];
  bool _isLoading = false;
  String _topCategory = 'None';
  double _weekdayTotal = 0;
  double _weekendTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrencyAndRates();
    _filteredChartData = widget.chartData;
    // Load filtered data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFilteredData();
    });
  }

  Future<void> _loadCurrencyAndRates() async {
    final currency = await SettingsService.getSelectedCurrency();

    // Check if selected currency is supported, fallback to USD if not
    final supportedCurrencies = CurrencyService.getAllSupportedCurrencies();
    final supportedCurrency = supportedCurrencies.containsKey(currency)
        ? currency
        : 'USD'; // Default fallback

    if (currency != supportedCurrency) {
      print(
          'CurrencyService: Selected currency $currency not supported, using $supportedCurrency');
    }

    setState(() {
      _currentCurrency = supportedCurrency;
    });

    // Ensure currency cache is initialized for conversions
    await CurrencyService.ensureCacheInitialized();
  }

  // Convert amount from original currency to current currency
  double _convertAmount(double amount, String originalCurrency) {
    if (originalCurrency == _currentCurrency) return amount;

    // Check if target currency is supported
    final supportedCurrencies = CurrencyService.getAllSupportedCurrencies();
    if (!supportedCurrencies.containsKey(_currentCurrency)) {
      print(
          'CurrencyService: Target currency $_currentCurrency not supported, using original');
      return amount; // Return original amount if target currency not supported
    }

    // Use CurrencyService for synchronous conversion (already returns precise values)
    try {
      return CurrencyService.convertAmountSync(
          amount, originalCurrency, _currentCurrency);
    } catch (e) {
      print('CurrencyService: Conversion failed $e, using original amount');
      return amount; // Fallback to original amount if conversion fails
    }
  }

  // Get date range for filtering (fixed 7 days)
  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    // Fixed 7 days range
    final startDate = now.subtract(const Duration(days: 7));
    final endDate = now;
    return DateTimeRange(start: startDate, end: endDate);
  }

  // Load filtered data from Firestore
  Future<void> _loadFilteredData() async {
    print('DEBUG: Starting _loadFilteredData');
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG: No user logged in');
        return;
      }
      print('DEBUG: User logged in: ${user.uid}');

      final dateRange = _getDateRange();
      print('DEBUG: Date range: ${dateRange.start} to ${dateRange.end}');

      final transactions = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('date', isLessThan: Timestamp.fromDate(dateRange.end))
          .orderBy('date', descending: false)
          .get();

      print('DEBUG: Found ${transactions.docs.length} transactions');

      // Map the human-readable dropdown label to the stored Firestore value
      String selectedTypeKey;
      switch (_transactionType) {
        case 'Expense':
          selectedTypeKey = 'expense';
          break;
        case 'Income':
          selectedTypeKey = 'income';
          break;
        case 'Transfers':
          selectedTypeKey = 'transfer';
          break;
        default:
          selectedTypeKey = 'expense'; // fallback to expense
      }
      print('DEBUG: Looking for transactions with type: $selectedTypeKey');

      Map<String, double> dailyAmounts = {};
      Map<String, double> categoryAmounts = {};
      double weekdayTotal = 0;
      double weekendTotal = 0;
      int transactionCount = 0;

      for (var doc in transactions.docs) {
        final data = doc.data();
        final type = (data['type'] as String? ?? '').toLowerCase();
        print('DEBUG: Transaction type: $type');

        // Apply type filter (always applied now since All is removed)
        if (type != selectedTypeKey) {
          print('DEBUG: Skipping transaction - type mismatch');
          continue;
        }

        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final transactionCurrency = (data['currency'] ?? 'INR') as String;
        final category = (data['category'] ?? 'Uncategorized') as String;
        final date = (data['date'] as Timestamp).toDate();
        final dayKey = DateFormat('yyyy-MM-dd').format(date);

        print(
            'DEBUG: Including transaction: $amount $transactionCurrency on $date');

        // Convert amount to current currency before adding to daily totals
        final convertedAmount = _convertAmount(amount, transactionCurrency);
        dailyAmounts[dayKey] = (dailyAmounts[dayKey] ?? 0) + convertedAmount;
        categoryAmounts[category] =
            (categoryAmounts[category] ?? 0) + convertedAmount;
        transactionCount++;

        // Separate weekday vs weekend
        if (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          weekendTotal += convertedAmount;
        } else {
          weekdayTotal += convertedAmount;
        }
      }

      print('DEBUG: Total transactions after filtering: $transactionCount');
      print('DEBUG: Daily amounts entries: ${dailyAmounts.length}');

      // Convert to FlSpot list
      final spots = <FlSpot>[];
      final startDate = dateRange.start;
      final totalDays = dateRange.duration.inDays + 1;

      for (int i = 0; i < totalDays; i++) {
        final currentDate = startDate.add(Duration(days: i));
        final dayKey = DateFormat('yyyy-MM-dd').format(currentDate);
        final amount = dailyAmounts[dayKey] ?? 0.0;

        spots.add(FlSpot(i.toDouble(), amount));
      }

      print('DEBUG: Created ${spots.length} chart spots');

      // Calculate additional insights
      final topCategory = categoryAmounts.entries.isEmpty
          ? 'None'
          : categoryAmounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;

      setState(() {
        _filteredChartData = spots;
        _topCategory = topCategory;
        _weekdayTotal = weekdayTotal;
        _weekendTotal = weekendTotal;
        _isLoading = false;
      });

      print('DEBUG: State updated with ${spots.length} spots');
      print('DEBUG: Top category: $topCategory');

      // Load previous period data for trend comparison
      await _loadPreviousPeriodData();
    } catch (e) {
      print('DEBUG: Error loading filtered data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load previous period data for trend comparison
  Future<void> _loadPreviousPeriodData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Previous period data loading placeholder
      // Trend analysis removed - keeping method for potential future use
    } catch (e) {
      print('Error loading previous period data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Data is already converted to current currency during loading
    final convertedChartData = _filteredChartData;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Expense Analysis'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (convertedChartData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Expense Analysis'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expense data available',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'for the selected filters',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final total =
        convertedChartData.fold<double>(0.0, (sum, spot) => sum + spot.y);
    final avg = total / convertedChartData.length;

    FlSpot? maxSpot;
    for (final spot in convertedChartData) {
      if (maxSpot == null || spot.y > maxSpot.y) {
        maxSpot = spot;
      }
    }

    final symbol = CurrencyService.getCurrencySymbol(_currentCurrency);

    return _buildAnalysisContent(
        context, convertedChartData, total, avg, maxSpot, symbol);
  }

  Widget _buildAnalysisContent(
      BuildContext context,
      List<FlSpot> convertedChartData,
      double total,
      double avg,
      FlSpot? maxSpot,
      String symbol) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Expense Analysis'),
        backgroundColor: cs.surface,
        elevation: 0,
        foregroundColor: cs.onSurface,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Expense Analysis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 16),

            // Filter Dropdowns
            _buildDropdown(
              context,
              'Transaction Type',
              _transactionType,
              ['Expense', 'Income', 'Transfers'],
              (value) {
                setState(() {
                  _transactionType = value!;
                });
                _loadFilteredData();
              },
            ),
            const SizedBox(height: 16),

            // Optimized chart with better sizing
            Container(
              height: 240, // Reduced from 280 for better balance
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calculateYAxisInterval(),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize:
                            50, // Increased from 30 to prevent text cutoff
                        interval: _calculateBottomLabelInterval(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          final dayLabel = _getDayLabel(index);

                          // Debug logging to verify labels
                          print('Day label for index $index: $dayLabel');

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Transform.rotate(
                              angle: -45 * 3.14159 / 180,
                              child: Text(
                                dayLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize: 11, // Increased from 10
                                      fontWeight: FontWeight
                                          .w600, // Increased from w400
                                      fontStyle: FontStyle
                                          .italic, // ✅ Added italic style
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 70,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            CurrencyService.getCurrencySymbol(
                                    _currentCurrency) +
                                _formatYAxisValue(value),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                          );
                        },
                        interval: _calculateYAxisInterval(),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: convertedChartData.isEmpty
                      ? 6
                      : convertedChartData.length.toDouble() - 1,
                  minY: 0,
                  maxY: _calculateMaxY(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: convertedChartData,
                      isCurved: false,
                      gradient: LinearGradient(
                        colors: [
                          cs.primary.withOpacity(0.8),
                          cs.primary.withOpacity(0.4),
                        ],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: convertedChartData.length <=
                            30, // Only show dots for smaller datasets
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
                      tooltipRoundedRadius: 6,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final index = spot.x.toInt();
                          final dayLabel = _getDayLabel(index);
                          final amount = '$symbol${spot.y.toStringAsFixed(0)}';

                          return LineTooltipItem(
                            '$dayLabel\n$amount',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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

            const SizedBox(height: 16),

            // Compact analytics cards with better spacing
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildAnalyticsCard(
                    context,
                    'Total',
                    '$symbol${total.toStringAsFixed(0)}',
                    Icons.trending_up,
                    cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildAnalyticsCard(
                    context,
                    'Daily Avg',
                    '$symbol${avg.toStringAsFixed(0)}',
                    Icons.bar_chart,
                    cs.tertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Highest day card - optimized height
            _buildAnalyticsCard(
              context,
              'Highest Day',
              maxSpot != null
                  ? '${_getDayLabel(maxSpot.x.toInt())}: $symbol${maxSpot.y.toStringAsFixed(0)}'
                  : '-',
              Icons.calendar_today,
              cs.secondary,
              isFullWidth: true,
            ),

            const SizedBox(height: 16),

            // Insights Section with compact layout
            Row(
              children: [
                Text(
                  'Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    color: cs.outline.withOpacity(0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Compact insights grid
            Column(
              children: [
                // First row of insights
                Row(
                  children: [
                    Expanded(
                      child: _buildInsightCard(
                        context,
                        'Spending Streak',
                        _getSpendingStreakText(),
                        Icons.local_fire_department_outlined,
                        _getSpendingStreakColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInsightCard(
                        context,
                        'Budget Health',
                        _getBudgetHealthText(total),
                        Icons.account_balance_wallet_outlined,
                        _getBudgetHealthColor(total),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Second row of insights
                Row(
                  children: [
                    Expanded(
                      child: _buildInsightCard(
                        context,
                        'Spending Forecast',
                        _getSpendingForecastText(),
                        Icons.trending_up_outlined,
                        cs.tertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInsightCard(
                        context,
                        'Top Category',
                        _getTopCategoryText(),
                        Icons.category_outlined,
                        cs.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Third row - Weekday vs Weekend (full width)
                _buildInsightCard(
                  context,
                  'Weekday vs Weekend',
                  _getWeekdayWeekendText(),
                  Icons.calendar_today_outlined,
                  cs.primary,
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isFullWidth = false,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(8), // Reduced from 10
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 12, // Reduced from 14
                color: color,
              ),
              const SizedBox(width: 4), // Reduced from 5
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                      fontSize: 10, // Reduced from 11
                    ),
              ),
            ],
          ),
          const SizedBox(height: 2), // Reduced from 3
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13, // Reduced from 14
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8), // Reduced from 10
        border: Border.all(
          color: cs.outline.withOpacity(0.15), // Reduced opacity
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02), // Subtle shadow
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8), // Reduced from 12
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4), // Reduced from 6
            decoration: BoxDecoration(
              color: color.withOpacity(0.08), // Reduced opacity
              borderRadius: BorderRadius.circular(4), // Reduced from 6
            ),
            child: Icon(
              icon,
              size: 16, // Reduced from 18
              color: color,
            ),
          ),
          const SizedBox(width: 8), // Reduced from 10
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.6), // Reduced opacity
                        fontWeight: FontWeight.w500,
                        fontSize: 10, // Reduced from 11
                      ),
                ),
                const SizedBox(height: 1), // Reduced from 1
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        // Changed from titleMedium
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                        fontSize: 12, // Reduced from 13
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSpendingStreakText() {
    if (_filteredChartData.isEmpty) return 'No data';

    int currentStreak = 0;
    int maxStreak = 0;

    // Count consecutive days with spending
    for (int i = _filteredChartData.length - 1; i >= 0; i--) {
      if (_filteredChartData[i].y > 0) {
        currentStreak++;
      } else {
        break;
      }
    }

    // Find maximum streak
    int tempStreak = 0;
    for (final spot in _filteredChartData) {
      if (spot.y > 0) {
        tempStreak++;
        maxStreak = maxStreak > tempStreak ? maxStreak : tempStreak;
      } else {
        tempStreak = 0;
      }
    }

    if (currentStreak >= 5) return '$currentStreak days 🔥';
    if (currentStreak >= 3) return '$currentStreak days';
    return 'None';
  }

  Color _getSpendingStreakColor() {
    final cs = Theme.of(context).colorScheme;
    if (_filteredChartData.isEmpty) return cs.onSurface.withOpacity(0.6);

    int currentStreak = 0;
    for (int i = _filteredChartData.length - 1; i >= 0; i--) {
      if (_filteredChartData[i].y > 0) {
        currentStreak++;
      } else {
        break;
      }
    }

    if (currentStreak >= 5) return Colors.red; // Hot streak
    if (currentStreak >= 3) return Colors.orange; // Warm streak
    return cs.onSurface.withOpacity(0.6); // Cold
  }

  String _getBudgetHealthText(double total) {
    // Simple budget calculation (assuming weekly budget of 1000 currency units)
    const weeklyBudget = 1000.0;
    final budgetUsed = (total / weeklyBudget * 100).round();

    if (total == 0) return 'No spending';
    if (budgetUsed <= 50) return 'Good (${budgetUsed}%)';
    if (budgetUsed <= 80) return 'Warning (${budgetUsed}%)';
    return 'Over budget (${budgetUsed}%)';
  }

  Color _getBudgetHealthColor(double total) {
    final cs = Theme.of(context).colorScheme;
    const weeklyBudget = 1000.0;
    final budgetUsed = total / weeklyBudget;

    if (total == 0) return cs.primary; // Green for no spending
    if (budgetUsed <= 0.5) return cs.primary; // Green
    if (budgetUsed <= 0.8) return Colors.orange; // Orange
    return cs.error; // Red
  }

  String _getTopCategoryText() {
    if (_topCategory == 'None') return 'No categories';

    // Calculate top category percentage
    double topCategoryTotal = 0;
    for (final spot in _filteredChartData) {
      topCategoryTotal += spot.y;
    }

    return '$_topCategory (${(topCategoryTotal > 0 ? 100 : 0).round()}%)';
  }

  String _getSpendingForecastText() {
    if (_filteredChartData.length < 3) return 'Insufficient data';

    // Calculate average daily spending from last 7 days
    final total =
        _filteredChartData.fold<double>(0.0, (sum, spot) => sum + spot.y);
    final avgDailySpending = total / _filteredChartData.length;

    // Calculate trend (simple linear regression)
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < _filteredChartData.length; i++) {
      final x = i.toDouble();
      final y = _filteredChartData[i].y;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final n = _filteredChartData.length.toDouble();
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Predict next 7 days spending
    double predictedTotal = 0;
    for (int i = 0; i < 7; i++) {
      final futureX = _filteredChartData.length + i;
      final predictedY = slope * futureX + intercept;
      predictedTotal += predictedY > 0 ? predictedY : 0; // Ensure non-negative
    }

    // Calculate trend percentage
    final currentWeekTotal = total;
    final trendPercent = currentWeekTotal > 0
        ? ((predictedTotal - currentWeekTotal) / currentWeekTotal * 100)
        : 0;

    final symbol = CurrencyService.getCurrencySymbol(_currentCurrency);

    if (trendPercent.abs() < 5) {
      return 'Stable $symbol${predictedTotal.round()}';
    } else if (trendPercent > 0) {
      return 'Rising +${trendPercent.round()}%';
    } else {
      return 'Falling ${trendPercent.round()}%';
    }
  }

  String _getWeekdayWeekendText() {
    final total = _weekdayTotal + _weekendTotal;
    if (total == 0) return 'No data';

    final weekdayPercent = (_weekdayTotal / total * 100).round();
    final weekendPercent = (_weekendTotal / total * 100).round();

    final symbol = CurrencyService.getCurrencySymbol(_currentCurrency);

    if (weekdayPercent > weekendPercent) {
      return 'Weekdays $weekdayPercent% ($symbol${_weekdayTotal.toStringAsFixed(0)})';
    } else {
      return 'Weekends $weekendPercent% ($symbol${_weekendTotal.toStringAsFixed(0)})';
    }
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

  double _calculateYAxisInterval() {
    if (_filteredChartData.isEmpty) return 1;
    final maxY = _filteredChartData.fold<double>(
        0, (max, spot) => spot.y > max ? spot.y : max);

    // Dynamic scaling based on actual transaction amounts
    if (maxY == 0) return 1;
    if (maxY <= 10) return 2;
    if (maxY <= 25) return 5;
    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    if (maxY <= 250) return 50;
    if (maxY <= 500) return 100;
    if (maxY <= 1000) return 200;
    if (maxY <= 2500) return 500;
    if (maxY <= 5000) return 1000;
    if (maxY <= 10000) return 2000;
    if (maxY <= 25000) return 5000;
    if (maxY <= 50000) return 10000;

    // For very large values, use 10% of max as interval
    return (maxY * 0.1).ceilToDouble();
  }

  double _calculateBottomLabelInterval() {
    // Always show every day to ensure Today, Yesterday, and recent days are visible
    return 1.0; // Show every single day
  }

  double _calculateMaxY() {
    if (_filteredChartData.isEmpty) return 10;
    final maxY = _filteredChartData.fold<double>(
        0, (max, spot) => spot.y > max ? spot.y : max);

    // Data is already converted to current currency, no need to convert again
    final convertedMaxY = maxY;
    final interval = _calculateYAxisInterval();

    // Calculate proper max Y to include all data points
    final steps = (convertedMaxY / interval).ceil() + 1;
    return steps * interval;
  }

  String _getDayLabel(int index) {
    final dateRange = _getDateRange();
    final currentDate = dateRange.start.add(Duration(days: index));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDay =
        DateTime(currentDate.year, currentDate.month, currentDate.day);
    final daysDiff = today.difference(currentDay).inDays;

    // Perfect 7-day logic with clear relative labels
    if (daysDiff == 0) return 'Today';
    if (daysDiff == 1) return 'Yesterday';
    if (daysDiff == 2)
      return DateFormat('EEEE').format(currentDate); // Full day name
    if (daysDiff == 3)
      return DateFormat('EEEE').format(currentDate); // Full day name
    if (daysDiff == 4)
      return DateFormat('EEEE').format(currentDate); // Full day name
    if (daysDiff == 5)
      return DateFormat('EEEE').format(currentDate); // Full day name
    if (daysDiff == 6)
      return DateFormat('EEEE').format(currentDate); // Full day name
    if (daysDiff == 7)
      return DateFormat('EEEE').format(currentDate); // Full day name

    // Fallback for any edge cases
    return DateFormat('MMM d').format(currentDate);
  }

  Widget _buildDropdown(
    BuildContext context,
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outline.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
