import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arthaksh/services/currency_service.dart';
import 'package:arthaksh/services/settings_service.dart';

class PieChartAnalysisScreen extends StatefulWidget {
  const PieChartAnalysisScreen({super.key});

  @override
  State<PieChartAnalysisScreen> createState() => _PieChartAnalysisScreenState();
}

class _PieChartAnalysisScreenState extends State<PieChartAnalysisScreen>
    with TickerProviderStateMixin {
  String _selectedRange = 'This Month';
  String _transactionType = 'Expense';
  Map<String, double> categoryTotals = {};
  Map<String, int> categoryCounts = {};
  bool _isLoading = true;
  String _currentCurrency = '₹';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Data tally variables
  double _totalIncome = 0;
  double _balance = 0;
  int _totalTransactions = 0;
  String _topCategory = 'None';
  double _averageTransaction = 0;
  double _filteredTotal = 0;

  // Category trend analysis variables
  Map<String, double> _categoryTrends = {};
  bool _showTrends = false;

  // Real-time listener for expenses
  StreamSubscription<QuerySnapshot>? _expensesSubscription;

  // Teal color palette for charts
  static const _tealShades = [
    Color(0xFF0D9488), // Teal 800
    Color(0xFF14B8A6), // Teal 600
    Color(0xFF2DD4BF), // Teal 500
    Color(0xFF5EEAD4), // Teal 300
    Color(0xFF5FDFDF), // Teal 200
    Color(0xFFCCFBF1), // Teal 100
    Color(0xFF134E4A), // Teal 900
    Color(0xFF115E59), // Teal 700
  ];

  String _formatFullCurrency(double amount) {
    final symbol = CurrencyService.getCurrencySymbol(_currentCurrency);
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    String formattedAmount;
    if (absAmount >= 10000000) {
      formattedAmount = '${(absAmount / 10000000).toStringAsFixed(2)} Cr';
    } else if (absAmount >= 100000) {
      formattedAmount = '${(absAmount / 100000).toStringAsFixed(2)} L';
    } else if (absAmount >= 1000) {
      formattedAmount = '${(absAmount / 1000).toStringAsFixed(1)}K';
    } else {
      formattedAmount = absAmount.toStringAsFixed(0);
    }

    return isNegative ? '-$symbol$formattedAmount' : '$symbol$formattedAmount';
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _setupRealtimeListener();
    _animationController.forward();
  }

  @override
  void dispose() {
    _expensesSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _setupRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to all expenses for immediate updates, then filter in callback
    _expensesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      // Always reload data to ensure consistency and provide real-time updates
      if (mounted) {
        _loadData();
      }
    });

    // Initial data load
    _loadData();
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case 'This Month':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case 'Last 7 days':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now.copyWith(hour: 23, minute: 59, second: 59),
        );
      case 'Last 3 months':
        return DateTimeRange(
          start: DateTime(now.year, now.month - 3, now.day),
          end: now.copyWith(hour: 23, minute: 59, second: 59),
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now.copyWith(hour: 23, minute: 59, second: 59),
        );
    }
  }

  DateTimeRange _getPreviousPeriodRange() {
    final currentRange = _getDateRange();
    final duration = currentRange.duration;

    switch (_selectedRange) {
      case 'This Month':
        final now = DateTime.now();
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0, 23, 59, 59),
        );
      case 'Last 7 days':
        return DateTimeRange(
          start: currentRange.start.subtract(const Duration(days: 7)),
          end: currentRange.end.subtract(const Duration(days: 7)),
        );
      case 'Last 3 months':
        final now = DateTime.now();
        return DateTimeRange(
          start: DateTime(now.year, now.month - 6, now.day),
          end: DateTime(now.year, now.month - 3, now.day, 23, 59, 59),
        );
      default:
        return DateTimeRange(
          start: currentRange.start.subtract(duration),
          end: currentRange.start.subtract(const Duration(days: 1)),
        );
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    try {
      // Show loading state immediately for better UX
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final currency = await SettingsService.getSelectedCurrency();
      if (mounted) {
        setState(() {
          _currentCurrency = currency;
        });
      }

      await CurrencyService.ensureCacheInitialized();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current period data
      final dateRange = _getDateRange();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('date', isLessThan: Timestamp.fromDate(dateRange.end))
          .orderBy('date', descending: true)
          .get();

      // Get previous period data for trend analysis
      final previousRange = _getPreviousPeriodRange();
      final previousSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(previousRange.start))
          .where('date', isLessThan: Timestamp.fromDate(previousRange.end))
          .orderBy('date', descending: true)
          .get();

      final totals = <String, double>{};
      final counts = <String, int>{};
      final previousTotals = <String, double>{};
      final categoryTrends = <String, double>{};
      double totalExpenses = 0;
      double totalIncome = 0;
      int transactionCount = 0;
      double filteredTotal = 0;

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

      // Process current period data
      for (var doc in snap.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount > 0) {
          final category = data['category']?.toString() ?? 'Unknown';
          final type = data['type']?.toString() ?? 'expense';
          final transactionCurrency = (data['currency'] ?? 'INR') as String;

          // Convert amount to current currency
          final convertedAmount = CurrencyService.convertAmountSync(
              amount, transactionCurrency, currency);

          // Only include transactions of the selected type
          if (type.toLowerCase() == selectedTypeKey) {
            totals[category] = (totals[category] ?? 0.0) + convertedAmount;
            counts[category] = (counts[category] ?? 0) + 1;
            transactionCount++;
            filteredTotal += convertedAmount;
          }

          // Separate expenses and income for overall tally
          if (type.toLowerCase() == 'income') {
            totalIncome += convertedAmount;
          } else {
            totalExpenses += convertedAmount;
          }
        }
      }

      // Process previous period data for trend analysis
      for (var doc in previousSnap.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount > 0) {
          final category = data['category']?.toString() ?? 'Unknown';
          final type = data['type']?.toString() ?? 'expense';
          final transactionCurrency = (data['currency'] ?? 'INR') as String;

          // Convert amount to current currency
          final convertedAmount = CurrencyService.convertAmountSync(
              amount, transactionCurrency, currency);

          // Only include transactions of the selected type
          if (type.toLowerCase() == selectedTypeKey) {
            previousTotals[category] =
                (previousTotals[category] ?? 0.0) + convertedAmount;
          }
        }
      }

      // Calculate category trends (percentage change)
      for (var category in totals.keys) {
        final currentAmount = totals[category] ?? 0.0;
        final previousAmount = previousTotals[category] ?? 0.0;

        if (previousAmount > 0) {
          final trend =
              ((currentAmount - previousAmount) / previousAmount) * 100;
          categoryTrends[category] = trend;
        } else if (currentAmount > 0) {
          // New category
          categoryTrends[category] = 100.0;
        } else {
          categoryTrends[category] = 0.0;
        }
      }

      // Calculate additional metrics
      final balance = totalIncome - totalExpenses;
      final averageTransaction = transactionCount > 0
          ? (filteredTotal / transactionCount).toDouble()
          : 0.0;

      // Find top category
      String topCategory = 'None';
      double topAmount = 0;
      for (var entry in totals.entries) {
        if (entry.value > topAmount) {
          topAmount = (entry.value as num).toDouble();
          topCategory = entry.key;
        }
      }

      if (mounted) {
        setState(() {
          categoryTotals = totals;
          categoryCounts = counts;
          _categoryTrends = categoryTrends;
          _totalIncome = totalIncome;
          _balance = balance;
          _totalTransactions = transactionCount;
          _topCategory = topCategory;
          _averageTransaction = averageTransaction;
          _filteredTotal = filteredTotal;
          _showTrends = previousTotals.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Category Analysis'),
          backgroundColor: cs.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
      );
    }

    if (categoryTotals.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Category Analysis'),
          backgroundColor: cs.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
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
                    Icons.pie_chart,
                    size: 64,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expense data available',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'for the selected period',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Category Analysis',
          style: theme.textTheme.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Transaction Type Dropdown
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.tertiary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.tertiary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: DropdownButton<String>(
              value: _transactionType,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(
                fontSize: 12,
                color: cs.tertiary,
                fontWeight: FontWeight.w600,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: cs.tertiary,
              ),
              items: ['Expense', 'Income', 'Transfers']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _transactionType = value;
                    _isLoading = true;
                  });
                  _setupRealtimeListener(); // Re-setup listener with new filter
                }
              },
            ),
          ),
          // Date Range Dropdown
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: DropdownButton<String>(
              value: _selectedRange,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: cs.primary,
              ),
              items: ['This Month', 'Last 7 days', 'Last 3 months']
                  .map((range) => DropdownMenuItem(
                        value: range,
                        child: Text(range),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRange = value;
                    _isLoading = true;
                  });
                  _setupRealtimeListener(); // Re-setup listener with new date range
                }
              },
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Data Tally Cards - Matching Line Chart Analysis Style
                _buildDataTallySection(),
                const SizedBox(height: 16),

                // Category Trend Analysis
                if (_showTrends) _buildTrendAnalysisSection(),
                if (_showTrends) const SizedBox(height: 16),

                // Main Pie Chart
                _buildPieChart(),
                const SizedBox(height: 16),

                // Category Breakdown
                _buildCategoryBreakdown(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendAnalysisSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Calculate overall trend
    double overallTrend = 0;
    int trendingUp = 0;
    int trendingDown = 0;

    for (var trend in _categoryTrends.values) {
      overallTrend += trend;
      if (trend > 0) {
        trendingUp++;
      } else if (trend < 0) {
        trendingDown++;
      }
    }

    final avgTrend =
        _categoryTrends.isNotEmpty ? overallTrend / _categoryTrends.length : 0;

    // Sort categories by biggest absolute change and create local map
    final sortedTrends = _categoryTrends.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    final Map<String, double> previousPeriodMap = {};
    for (var entry in sortedTrends) {
      final currentAmount = categoryTotals[entry.key] ?? 0.0;
      final trend = entry.value;
      if (trend != 100.0) {
        final previousAmount = currentAmount / (1 + trend / 100);
        previousPeriodMap[entry.key] = previousAmount;
      } else {
        previousPeriodMap[entry.key] = 0.0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.05),
            cs.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: cs.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Category Trends vs Previous Period',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: avgTrend >= 0
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      avgTrend >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: avgTrend >= 0 ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${avgTrend.abs().toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: avgTrend >= 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trend summary cards
          Row(
            children: [
              Expanded(
                child: _buildTrendCard(
                  'Trending Up',
                  trendingUp.toString(),
                  Icons.trending_up,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTrendCard(
                  'Trending Down',
                  trendingDown.toString(),
                  Icons.trending_down,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTrendCard(
                  'Total Categories',
                  _categoryTrends.length.toString(),
                  Icons.category,
                  cs.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Top 3 biggest changes
          Text(
            'Biggest Changes',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable biggest changes section with indicator
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: sortedTrends.take(3).map((entry) {
                  final category = entry.key;
                  final trend = entry.value;
                  final previousAmount = previousPeriodMap[category] ?? 0.0;
                  final currentAmount = categoryTotals[category] ?? 0.0;

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          trend > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16,
                          color: trend > 0 ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${trend.abs().toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: trend > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_formatFullCurrency(previousAmount)} → ${_formatFullCurrency(currentAmount)})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(
      String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataTallySection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title with transaction type
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                'Financial Overview',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.tertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _transactionType,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // First row of analytics cards
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                context,
                'Total $_transactionType',
                _formatFullCurrency(_filteredTotal),
                _transactionType == 'Income'
                    ? Icons.trending_up
                    : Icons.trending_down,
                _transactionType == 'Income' ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAnalyticsCard(
                context,
                'Total Income',
                _formatFullCurrency(_totalIncome),
                Icons.trending_up,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Second row
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                context,
                'Balance',
                _formatFullCurrency(_balance),
                Icons.account_balance_wallet,
                _balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAnalyticsCard(
                context,
                'Transactions',
                _totalTransactions.toString(),
                Icons.receipt_long,
                cs.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Third row - full width
        _buildAnalyticsCard(
          context,
          'Average $_transactionType',
          _formatFullCurrency(_averageTransaction),
          Icons.calculate,
          cs.tertiary,
          isFullWidth: true,
        ),
      ],
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Sort categories by amount for better visualization
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tealShades = _tealShades;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category Distribution',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${categoryTotals.length} Categories',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: sortedEntries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final categoryData = entry.value;
                  final value = categoryData.value;
                  final total =
                      categoryTotals.values.fold(0.0, (a, b) => a + b);
                  final percent = (value / total * 100).toStringAsFixed(1);
                  final color = tealShades[index % tealShades.length];

                  return PieChartSectionData(
                    color: color,
                    value: value,
                    title: '$percent%',
                    radius: 50,
                    titleStyle: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    badgeWidget: _Badge(
                      color: color,
                      size: 20,
                      borderColor: cs.surface,
                    ),
                    badgePositionPercentageOffset: .98,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);

    // Sort categories by amount
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tealShades = _tealShades;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Category Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Top: $_topCategory',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedEntries.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: cs.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final category = entry.key;
              final amount = entry.value;
              final count = categoryCounts[category] ?? 0;
              final percent = (amount / total * 100).toStringAsFixed(1);
              final color = tealShades[index % tealShades.length];

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$count transactions',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Trend indicator
                    if (_showTrends && _categoryTrends.containsKey(category))
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (_categoryTrends[category] ?? 0) >= 0
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (_categoryTrends[category] ?? 0) >= 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 12,
                              color: (_categoryTrends[category] ?? 0) >= 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${(_categoryTrends[category] ?? 0).abs().toStringAsFixed(1)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: (_categoryTrends[category] ?? 0) >= 0
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatFullCurrency(amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final double size;
  final Color borderColor;

  const _Badge({
    required this.color,
    required this.size,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
