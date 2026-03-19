import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modern_insights_screen.dart' as insights_screen;
import 'package:arthaksh/services/settings_service.dart';
import 'package:arthaksh/services/currency_service.dart';

class SpendingAnalyticsWidget extends StatefulWidget {
  final List<insights_screen.Transaction> transactions;
  final insights_screen.TransactionType? selectedType;
  final String currentCurrency;

  const SpendingAnalyticsWidget({
    super.key,
    required this.transactions,
    required this.selectedType,
    required this.currentCurrency,
  });

  @override
  State<SpendingAnalyticsWidget> createState() =>
      _SpendingAnalyticsWidgetState();
}

class _SpendingAnalyticsWidgetState extends State<SpendingAnalyticsWidget>
    with TickerProviderStateMixin {
  String _displayCurrency = 'USD';
  NumberFormat? _currencyFormatter;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressController;
  Map<String, double> _categoryPercentages = {};
  Map<String, List<insights_screen.Transaction>> _categoryTransactions = {};

  @override
  void initState() {
    super.initState();
    _loadCurrencySettings();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  Future<void> _loadCurrencySettings() async {
    final currency = await SettingsService.getSelectedCurrency();

    await CurrencyService.ensureCacheInitialized();

    if (mounted) {
      setState(() {
        _displayCurrency = currency;
        final currencySymbol = CurrencyService.getCurrencySymbol(currency);
        final currencyLocale = CurrencyService.getCurrencyLocale(currency);
        _currencyFormatter = NumberFormat.currency(
          symbol: currencySymbol,
          locale: currencyLocale,
          decimalDigits: 2,
        );
      });
      _calculateAnalytics();
      _animationController.forward();
      _progressController.forward();
    }
  }

  double _convertAmount(double amount, String originalCurrency) {
    if (originalCurrency == _displayCurrency) return amount;
    return CurrencyService.convertAmountSync(
        amount, originalCurrency, _displayCurrency);
  }

  void _calculateAnalytics() {
    final filteredTransactions = widget.selectedType == null
        ? widget.transactions
        : widget.transactions
            .where((t) => t.type == widget.selectedType)
            .toList();

    if (filteredTransactions.isEmpty) {
      setState(() {
        _categoryPercentages = {};
      });
      return;
    }

    // Calculate category totals with currency conversion
    final categoryTotals = <String, double>{};
    double grandTotal = 0;
    final categoryTransactions = <String, List<insights_screen.Transaction>>{};

    for (final transaction in filteredTransactions) {
      final convertedAmount =
          _convertAmount(transaction.amount, transaction.currency);
      final category = transaction.category.toLowerCase();
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) + convertedAmount;
      grandTotal += convertedAmount;
      categoryTransactions.putIfAbsent(category, () => []).add(transaction);
    }

    // Calculate percentages
    final percentages = <String, double>{};
    for (final entry in categoryTotals.entries) {
      percentages[entry.key] =
          grandTotal > 0 ? (entry.value / grandTotal) * 100 : 0;
    }

    setState(() {
      _categoryPercentages = percentages;
      _categoryTransactions = categoryTransactions;
    });
  }

  // Advanced analytics calculations
  double _calculateSpendingVelocity() {
    if (widget.transactions.isEmpty) return 0;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentTransactions = widget.transactions
        .where((t) => t.date.isAfter(thirtyDaysAgo))
        .toList();

    if (recentTransactions.isEmpty) return 0;

    final totalSpent = recentTransactions.fold<double>(
        0, (sum, t) => sum + _convertAmount(t.amount, t.currency));

    return totalSpent / 30; // Daily average
  }

  Map<String, dynamic> _calculatePredictiveInsights() {
    if (widget.transactions.length < 10) {
      return {
        'prediction': 'Insufficient data for prediction',
        'confidence': 0
      };
    }

    // Calculate spending trends over time
    final sortedTransactions = widget.transactions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final weeklySpending = <DateTime, double>{};
    for (final transaction in sortedTransactions) {
      final weekStart = DateTime(
          transaction.date.year, transaction.date.month, transaction.date.day);
      final convertedAmount =
          _convertAmount(transaction.amount, transaction.currency);
      weeklySpending[weekStart] =
          (weeklySpending[weekStart] ?? 0) + convertedAmount;
    }

    if (weeklySpending.length < 4) {
      return {'prediction': 'Need more weeks of data', 'confidence': 0};
    }

    // Simple linear regression for prediction
    final weeks = weeklySpending.keys.toList()..sort();
    final values = weeks.map((week) => weeklySpending[week] ?? 0).toList();

    if (values.length < 4) {
      return {'prediction': 'Insufficient weekly data', 'confidence': 0};
    }

    // Calculate trend
    final recentWeeks =
        values.length >= 4 ? values.sublist(values.length - 4) : values;
    final earlierWeeks = values.length >= 8
        ? values.sublist(values.length - 8, values.length - 4)
        : <double>[];

    if (earlierWeeks.isEmpty) {
      return {'prediction': 'Calculating trend...', 'confidence': 0.5};
    }

    final recentAvg = recentWeeks.reduce((a, b) => a + b) / recentWeeks.length;
    final earlierAvg =
        earlierWeeks.reduce((a, b) => a + b) / earlierWeeks.length;

    final trend = recentAvg - earlierAvg;
    final trendPercentage = earlierAvg > 0 ? (trend / earlierAvg) * 100 : 0;

    String prediction;
    double confidence;

    if (trendPercentage > 15) {
      prediction =
          'Spending likely to increase by ${trendPercentage.toStringAsFixed(1)}% next month';
      confidence = 0.8;
    } else if (trendPercentage < -15) {
      prediction =
          'Spending likely to decrease by ${trendPercentage.abs().toStringAsFixed(1)}% next month';
      confidence = 0.8;
    } else {
      prediction = 'Spending expected to remain stable';
      confidence = 0.7;
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'trend': trendPercentage,
      'weekly_avg': recentAvg,
    };
  }

  List<String> _generateAdvancedInsights() {
    final insights = <String>[];

    if (_categoryPercentages.isEmpty) return insights;

    // Category concentration analysis
    final sortedCategories = _categoryPercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategory = sortedCategories.first;
    final topTwoCategories = sortedCategories
        .take(2)
        .fold<double>(0, (sum, entry) => sum + entry.value);

    // Dynamic insights based on transaction type
    if (widget.selectedType == insights_screen.TransactionType.expense) {
      // Expense-specific insights
      if (topCategory.value > 50) {
        insights.add(
            'Highly concentrated expenses in ${topCategory.key.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')} (${topCategory.value.toStringAsFixed(1)}%)');
      }

      if (topTwoCategories > 70) {
        insights.add(
            'Top 2 expense categories dominate ${topTwoCategories.toStringAsFixed(1)}% of spending');
      }

      // Spending velocity insights
      final velocity = _calculateSpendingVelocity();
      if (velocity > 1000) {
        insights.add(
            'High expense velocity: ${_currencyFormatter?.format(velocity) ?? '₹0.00'}/day');
      } else if (velocity < 100) {
        insights.add(
            'Low expense velocity: ${_currencyFormatter?.format(velocity) ?? '₹0.00'}/day');
      }

      // Expense frequency analysis
      if (_categoryTransactions.isNotEmpty) {
        final avgTransactionsPerCategory =
            widget.transactions.length / _categoryTransactions.length;
        if (avgTransactionsPerCategory > 10) {
          insights.add(
              'High expense frequency: ${avgTransactionsPerCategory.toStringAsFixed(1)} transactions per category');
        }
      }
    } else if (widget.selectedType == insights_screen.TransactionType.income) {
      // Income-specific insights
      if (topCategory.value > 60) {
        insights.add(
            'Primary income source: ${topCategory.key.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')} (${topCategory.value.toStringAsFixed(1)}%)');
      }

      if (_categoryPercentages.length >= 3) {
        insights.add(
            'Well-diversified income across ${_categoryPercentages.length} sources');
      } else if (_categoryPercentages.length == 1) {
        insights.add('Single income source - consider diversification');
      }

      // Income stability insights
      final velocity = _calculateSpendingVelocity();
      if (velocity > 2000) {
        insights.add(
            'Strong income flow: ${_currencyFormatter?.format(velocity) ?? '₹0.00'}/day');
      } else if (velocity < 500) {
        insights.add(
            'Limited income flow: ${_currencyFormatter?.format(velocity) ?? '₹0.00'}/day');
      }
    } else if (widget.selectedType ==
        insights_screen.TransactionType.transfer) {
      // Transfer-specific insights
      if (topCategory.value > 40) {
        insights.add(
            'Primary transfer destination: ${topCategory.key.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')} (${topCategory.value.toStringAsFixed(1)}%)');
      }

      if (_categoryPercentages.length >= 3) {
        insights.add(
            'Multiple transfer destinations: ${_categoryPercentages.length} different accounts');
      } else if (_categoryPercentages.length == 1) {
        insights.add('Single transfer destination - concentrated transfers');
      }

      // Transfer volume insights
      final velocity = _calculateSpendingVelocity();
      if (velocity > 3000) {
        insights.add(
            'High transfer volume: ${_currencyFormatter?.format(velocity) ?? '₹0.00'}/day');
      } else if (velocity < 300) {
        insights.add(
            'Low transfer volume: ${_currencyFormatter?.format(velocity) ?? '₹0.00'}/day');
      }
    } else {
      // Mixed/All transactions insights
      if (topCategory.value > 50) {
        insights.add(
            'Highly concentrated in ${topCategory.key.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')} (${topCategory.value.toStringAsFixed(1)}%)');
      }

      if (topTwoCategories > 70) {
        insights.add(
            'Top 2 categories dominate ${topTwoCategories.toStringAsFixed(1)}% of transactions');
      }

      // Overall velocity insights
      final velocity = _calculateSpendingVelocity();
      if (velocity > 1500) {
        insights.add(
            'High transaction volume: ${_currencyFormatter?.format(velocity) ?? '₹0.00'}/day');
      } else if (velocity < 200) {
        insights.add(
            'Low transaction volume: ${_currencyFormatter?.format(velocity) ?? '₹0.00'}/day');
      }

      // Transaction frequency analysis
      if (_categoryTransactions.isNotEmpty) {
        final avgTransactionsPerCategory =
            widget.transactions.length / _categoryTransactions.length;
        if (avgTransactionsPerCategory > 8) {
          insights.add(
              'High activity: ${avgTransactionsPerCategory.toStringAsFixed(1)} transactions per category');
        }
      }
    }

    // Predictive insights (common to all types but with different wording)
    final predictive = _calculatePredictiveInsights();
    if (predictive['confidence'] != null && predictive['confidence'] > 0.5) {
      String prediction = predictive['prediction'] as String;

      // Customize prediction wording based on transaction type
      if (widget.selectedType == insights_screen.TransactionType.expense) {
        prediction = prediction.replaceAll('Spending', 'Expenses');
      } else if (widget.selectedType ==
          insights_screen.TransactionType.income) {
        prediction = prediction.replaceAll('Spending', 'Income');
      }

      insights.add(prediction);
    }

    return insights;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_categoryPercentages.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildCategoryBreakdown(),
              const SizedBox(height: 24),
              _buildSpendingPatterns(),
              const SizedBox(height: 24),
              _buildKeyMetrics(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String analyticsTitle = 'Spending Analytics';
    String analyticsSubtitle = 'Deep insights into your spending patterns';

    // Dynamic title based on transaction type
    if (widget.selectedType != null) {
      switch (widget.selectedType!) {
        case insights_screen.TransactionType.expense:
          analyticsTitle = 'Expense Analytics';
          analyticsSubtitle = 'Detailed breakdown of your expenses';
          break;
        case insights_screen.TransactionType.income:
          analyticsTitle = 'Income Analytics';
          analyticsSubtitle = 'Analysis of your income sources';
          break;
        case insights_screen.TransactionType.transfer:
          analyticsTitle = 'Transfer Analytics';
          analyticsSubtitle = 'Analysis of money transfers';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.selectedType == insights_screen.TransactionType.expense
                ? Colors.red.withOpacity(0.2)
                : widget.selectedType == insights_screen.TransactionType.income
                    ? Colors.green.withOpacity(0.2)
                    : widget.selectedType ==
                            insights_screen.TransactionType.transfer
                        ? Colors.purple.withOpacity(0.2)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
            widget.selectedType == insights_screen.TransactionType.expense
                ? Colors.red.withOpacity(0.1)
                : widget.selectedType == insights_screen.TransactionType.income
                    ? Colors.green.withOpacity(0.1)
                    : widget.selectedType ==
                            insights_screen.TransactionType.transfer
                        ? Colors.purple.withOpacity(0.1)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.selectedType ==
                      insights_screen.TransactionType.expense
                  ? Colors.red.withOpacity(0.2)
                  : widget.selectedType ==
                          insights_screen.TransactionType.income
                      ? Colors.green.withOpacity(0.2)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.selectedType == insights_screen.TransactionType.expense
                  ? Icons.money_off
                  : widget.selectedType ==
                          insights_screen.TransactionType.income
                      ? Icons.account_balance
                      : Icons.analytics_outlined,
              color:
                  widget.selectedType == insights_screen.TransactionType.expense
                      ? Colors.red
                      : widget.selectedType ==
                              insights_screen.TransactionType.income
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analyticsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: widget.selectedType ==
                                insights_screen.TransactionType.expense
                            ? Colors.red
                            : widget.selectedType ==
                                    insights_screen.TransactionType.income
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                      ),
                ),
                Text(
                  analyticsSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.selectedType ==
                      insights_screen.TransactionType.expense
                  ? Colors.red.withOpacity(0.1)
                  : widget.selectedType ==
                          insights_screen.TransactionType.income
                      ? Colors.green.withOpacity(0.1)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.selectedType == insights_screen.TransactionType.expense
                  ? Icons.trending_down
                  : widget.selectedType ==
                          insights_screen.TransactionType.income
                      ? Icons.trending_up
                      : Icons.insights,
              color:
                  widget.selectedType == insights_screen.TransactionType.expense
                      ? Colors.red
                      : widget.selectedType ==
                              insights_screen.TransactionType.income
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final sortedCategories = _categoryPercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Breakdown',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 16),
        ...sortedCategories.take(5).map((entry) {
          return _buildCategoryItem(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildCategoryItem(String category, double percentage) {
    final categoryName = category
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                categoryName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage / 100 * _progressController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingPatterns() {
    final insights = _generateAdvancedInsights();
    final predictive = _calculatePredictiveInsights();

    String analyticsTitle = 'Advanced Analytics';
    String analyzingText = 'Analyzing spending patterns...';

    // Dynamic title based on transaction type
    if (widget.selectedType == insights_screen.TransactionType.expense) {
      analyticsTitle = 'Expense Insights';
      analyzingText = 'Analyzing expense patterns...';
    } else if (widget.selectedType == insights_screen.TransactionType.income) {
      analyticsTitle = 'Income Insights';
      analyzingText = 'Analyzing income patterns...';
    } else if (widget.selectedType ==
        insights_screen.TransactionType.transfer) {
      analyticsTitle = 'Transfer Insights';
      analyzingText = 'Analyzing transfer patterns...';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_graph,
                color: widget.selectedType ==
                        insights_screen.TransactionType.expense
                    ? Colors.red
                    : widget.selectedType ==
                            insights_screen.TransactionType.income
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                analyticsTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (predictive['confidence'] != null &&
                  predictive['confidence'] > 0.5) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.selectedType ==
                            insights_screen.TransactionType.expense
                        ? Colors.red.withOpacity(0.1)
                        : widget.selectedType ==
                                insights_screen.TransactionType.income
                            ? Colors.green.withOpacity(0.1)
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(predictive['confidence']! * 100).toStringAsFixed(0)}% confidence',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.selectedType ==
                                  insights_screen.TransactionType.expense
                              ? Colors.red
                              : widget.selectedType ==
                                      insights_screen.TransactionType.income
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => _buildPatternItem(insight)),
          if (insights.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  analyzingText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatternItem(String insight) {
    IconData icon = Icons.info_outline;
    Color color = Theme.of(context).colorScheme.primary;

    if (insight.contains('highest')) {
      icon = Icons.trending_up;
      color = Colors.red;
    } else if (insight.contains('lowest')) {
      icon = Icons.trending_down;
      color = Colors.green;
    } else if (insight.contains('diversified')) {
      icon = Icons.diversity_3;
      color = Colors.blue;
    } else if (insight.contains('concentrated')) {
      icon = Icons.center_focus_strong;
      color = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    final metrics = _calculateKeyMetrics();

    String metricsTitle = 'Key Metrics';
    String totalLabel = 'Total Spent';
    String avgLabel = 'Avg Transaction';
    String frequencyLabel = 'Frequency';

    // Dynamic labels based on transaction type
    if (widget.selectedType == insights_screen.TransactionType.expense) {
      metricsTitle = 'Expense Metrics';
      totalLabel = 'Total Expenses';
      avgLabel = 'Avg Expense';
      frequencyLabel = 'Expense Rate';
    } else if (widget.selectedType == insights_screen.TransactionType.income) {
      metricsTitle = 'Income Metrics';
      totalLabel = 'Total Income';
      avgLabel = 'Avg Income';
      frequencyLabel = 'Income Flow';
    } else if (widget.selectedType ==
        insights_screen.TransactionType.transfer) {
      metricsTitle = 'Transfer Metrics';
      totalLabel = 'Total Transfers';
      avgLabel = 'Avg Transfer';
      frequencyLabel = 'Transfer Rate';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.selectedType == insights_screen.TransactionType.expense
                ? Colors.red.withOpacity(0.05)
                : widget.selectedType == insights_screen.TransactionType.income
                    ? Colors.green.withOpacity(0.05)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.05),
            widget.selectedType == insights_screen.TransactionType.expense
                ? Colors.red.withOpacity(0.02)
                : widget.selectedType == insights_screen.TransactionType.income
                    ? Colors.green.withOpacity(0.02)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.selectedType == insights_screen.TransactionType.expense
              ? Colors.red.withOpacity(0.1)
              : widget.selectedType == insights_screen.TransactionType.income
                  ? Colors.green.withOpacity(0.1)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metricsTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.selectedType ==
                          insights_screen.TransactionType.expense
                      ? Colors.red
                      : widget.selectedType ==
                              insights_screen.TransactionType.income
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildMetricCard('Categories',
                      metrics['categories'] ?? '0', Icons.category)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildMetricCard(
                      avgLabel,
                      metrics['avgTransaction'] ?? '₹0.00',
                      Icons.receipt_long)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildMetricCard(
                      totalLabel,
                      metrics['totalSpent'] ?? '₹0.00',
                      Icons.account_balance_wallet)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildMetricCard(frequencyLabel,
                      metrics['frequency'] ?? '0/day', Icons.calendar_today)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _calculateKeyMetrics() {
    final filteredTransactions = widget.selectedType == null
        ? widget.transactions
        : widget.transactions
            .where((t) => t.type == widget.selectedType)
            .toList();

    if (filteredTransactions.isEmpty) {
      return {
        'categories': '0',
        'avgTransaction': _currencyFormatter?.format(0) ?? '₹0.00',
        'totalSpent': _currencyFormatter?.format(0) ?? '₹0.00',
        'frequency': '0/day',
      };
    }

    final categories =
        filteredTransactions.map((t) => t.category).toSet().length;
    final totalSpent = filteredTransactions.fold<double>(
        0, (sum, t) => sum + _convertAmount(t.amount, t.currency));
    final avgTransaction = totalSpent / filteredTransactions.length;

    // Calculate frequency (transactions per day)
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentTransactions =
        filteredTransactions.where((t) => t.date.isAfter(thirtyDaysAgo)).length;
    final frequency = (recentTransactions / 30).toStringAsFixed(1);

    return {
      'categories': categories.toString(),
      'avgTransaction': _currencyFormatter?.format(avgTransaction) ?? '₹0.00',
      'totalSpent': _currencyFormatter?.format(totalSpent) ?? '₹0.00',
      'frequency': '$frequency/day',
    };
  }
}
