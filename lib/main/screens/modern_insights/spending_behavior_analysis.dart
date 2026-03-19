import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modern_insights_screen.dart' as insights_screen;
import 'package:arthaksh/services/settings_service.dart';
import 'package:arthaksh/services/currency_service.dart';
import 'dart:math' as math;

class SpendingBehaviorAnalysisWidget extends StatefulWidget {
  final List<insights_screen.Transaction> transactions;
  final insights_screen.TransactionType? selectedType;
  final String currentCurrency;

  const SpendingBehaviorAnalysisWidget({
    super.key,
    required this.transactions,
    required this.selectedType,
    required this.currentCurrency,
  });

  @override
  State<SpendingBehaviorAnalysisWidget> createState() =>
      _SpendingBehaviorAnalysisWidgetState();
}

class _SpendingBehaviorAnalysisWidgetState
    extends State<SpendingBehaviorAnalysisWidget>
    with TickerProviderStateMixin {
  String _displayCurrency = 'USD';
  NumberFormat? _currencyFormatter;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
      _animationController.forward();
    }
  }

  double _convertAmount(double amount, String originalCurrency) {
    if (originalCurrency == _displayCurrency) return amount;
    return CurrencyService.convertAmountSync(
        amount, originalCurrency, _displayCurrency);
  }

  Map<String, dynamic> _analyzeBehavior() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Filter transactions by type
    final filteredTransactions = widget.selectedType == null
        ? widget.transactions
        : widget.transactions
            .where((t) => t.type == widget.selectedType)
            .toList();

    // Time-based analysis
    final recentTransactions = filteredTransactions
        .where((t) => t.date.isAfter(sevenDaysAgo))
        .toList();
    final monthlyTransactions = filteredTransactions
        .where((t) => t.date.isAfter(thirtyDaysAgo))
        .toList();

    // Category analysis
    final categoryAnalysis = _analyzeCategories(monthlyTransactions);

    // Frequency analysis
    final frequencyAnalysis = _analyzeFrequency(monthlyTransactions);

    // Amount patterns
    final amountAnalysis = _analyzeAmountPatterns(monthlyTransactions);

    // Time patterns
    final timeAnalysis = _analyzeTimePatterns(monthlyTransactions);

    // Behavior score
    final behaviorScore = _calculateBehaviorScore(
      categoryAnalysis,
      frequencyAnalysis,
      amountAnalysis,
      timeAnalysis,
    );

    // Generate insights
    final insights = _generateBehaviorInsights(
      categoryAnalysis,
      frequencyAnalysis,
      amountAnalysis,
      timeAnalysis,
      behaviorScore,
    );

    return {
      'categoryAnalysis': categoryAnalysis,
      'frequencyAnalysis': frequencyAnalysis,
      'amountAnalysis': amountAnalysis,
      'timeAnalysis': timeAnalysis,
      'behaviorScore': behaviorScore,
      'insights': insights,
      'recentCount': recentTransactions.length,
      'monthlyCount': monthlyTransactions.length,
    };
  }

  Map<String, dynamic> _analyzeCategories(
      List<insights_screen.Transaction> transactions) {
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};

    for (final transaction in transactions) {
      final category = transaction.category.toLowerCase();
      final amount = _convertAmount(transaction.amount, transaction.currency);

      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    final totalAmount =
        categoryTotals.values.fold(0.0, (sum, val) => sum + val);
    final totalTransactions = transactions.length;

    // Find dominant category
    String? dominantCategory;
    double dominancePercentage = 0;
    if (totalAmount > 0) {
      for (final entry in categoryTotals.entries) {
        final percentage = (entry.value / totalAmount) * 100;
        if (percentage > dominancePercentage) {
          dominancePercentage = percentage;
          dominantCategory = entry.key;
        }
      }
    }

    // Calculate diversity
    final diversity = categoryTotals.length.toDouble();

    return {
      'categoryTotals': categoryTotals,
      'categoryCounts': categoryCounts,
      'totalAmount': totalAmount,
      'totalTransactions': totalTransactions,
      'dominantCategory': dominantCategory,
      'dominancePercentage': dominancePercentage,
      'diversity': diversity,
    };
  }

  Map<String, dynamic> _analyzeFrequency(
      List<insights_screen.Transaction> transactions) {
    if (transactions.isEmpty) {
      return {
        'avgTransactionsPerDay': 0.0,
        'avgAmountPerTransaction': 0.0,
        'frequencyPattern': 'none',
        'consistencyScore': 0.0,
      };
    }

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final days = (now.difference(thirtyDaysAgo).inHours / 24).ceil();

    final avgTransactionsPerDay = transactions.length / days;
    final totalAmount = transactions.fold(
        0.0, (sum, t) => sum + _convertAmount(t.amount, t.currency));
    final avgAmountPerTransaction = totalAmount / transactions.length;

    // Analyze frequency pattern
    String frequencyPattern;
    if (avgTransactionsPerDay > 3) {
      frequencyPattern = 'high';
    } else if (avgTransactionsPerDay > 1) {
      frequencyPattern = 'moderate';
    } else if (avgTransactionsPerDay > 0.3) {
      frequencyPattern = 'low';
    } else {
      frequencyPattern = 'minimal';
    }

    // Calculate consistency (based on daily variance)
    final dailyAmounts = <String, double>{};
    for (final transaction in transactions) {
      final dayKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      dailyAmounts[dayKey] = (dailyAmounts[dayKey] ?? 0) +
          _convertAmount(transaction.amount, transaction.currency);
    }

    final amounts = dailyAmounts.values.toList();
    double consistencyScore = 0;
    if (amounts.isNotEmpty) {
      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance =
          amounts.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
              amounts.length;
      final stdDev = variance > 0 ? variance.sqrt() : 0;
      consistencyScore =
          mean > 0 ? (1 - (stdDev / mean)).clamp(0.0, 1.0) * 100 : 0;
    }

    return {
      'avgTransactionsPerDay': avgTransactionsPerDay,
      'avgAmountPerTransaction': avgAmountPerTransaction,
      'frequencyPattern': frequencyPattern,
      'consistencyScore': consistencyScore,
    };
  }

  Map<String, dynamic> _analyzeAmountPatterns(
      List<insights_screen.Transaction> transactions) {
    if (transactions.isEmpty) {
      return {
        'smallTransactions': 0,
        'mediumTransactions': 0,
        'largeTransactions': 0,
        'avgAmount': 0.0,
        'amountPattern': 'none',
      };
    }

    final amounts =
        transactions.map((t) => _convertAmount(t.amount, t.currency)).toList();

    amounts.sort();

    final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
    final medianAmount = amounts.length % 2 == 0
        ? (amounts[amounts.length ~/ 2 - 1] + amounts[amounts.length ~/ 2]) / 2
        : amounts[amounts.length ~/ 2];

    // Categorize transactions by amount (relative to median)
    final smallThreshold = medianAmount * 0.5;
    final largeThreshold = medianAmount * 2.0;

    int smallTransactions = 0;
    int mediumTransactions = 0;
    int largeTransactions = 0;

    for (final amount in amounts) {
      if (amount <= smallThreshold) {
        smallTransactions++;
      } else if (amount <= largeThreshold) {
        mediumTransactions++;
      } else {
        largeTransactions++;
      }
    }

    // Determine pattern
    String amountPattern;
    if (largeTransactions > transactions.length * 0.3) {
      amountPattern = 'large_dominant';
    } else if (smallTransactions > transactions.length * 0.6) {
      amountPattern = 'small_dominant';
    } else if (mediumTransactions > transactions.length * 0.5) {
      amountPattern = 'balanced';
    } else {
      amountPattern = 'mixed';
    }

    return {
      'smallTransactions': smallTransactions,
      'mediumTransactions': mediumTransactions,
      'largeTransactions': largeTransactions,
      'avgAmount': avgAmount,
      'medianAmount': medianAmount,
      'amountPattern': amountPattern,
    };
  }

  Map<String, dynamic> _analyzeTimePatterns(
      List<insights_screen.Transaction> transactions) {
    final hourlyDistribution = <int, int>{};
    final weeklyDistribution = <int, int>{};
    final dailyTotals = <String, double>{};

    for (final transaction in transactions) {
      final hour = transaction.date.hour;
      final weekday = transaction.date.weekday % 7; // 0 = Sunday
      final dayKey = DateFormat('yyyy-MM-dd').format(transaction.date);

      hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
      weeklyDistribution[weekday] = (weeklyDistribution[weekday] ?? 0) + 1;
      dailyTotals[dayKey] = (dailyTotals[dayKey] ?? 0) +
          _convertAmount(transaction.amount, transaction.currency);
    }

    // Find peak hour and day
    int? peakHour;
    int peakHourCount = 0;
    for (final entry in hourlyDistribution.entries) {
      if (entry.value > peakHourCount) {
        peakHourCount = entry.value;
        peakHour = entry.key;
      }
    }

    int? peakDay;
    int peakDayCount = 0;
    for (final entry in weeklyDistribution.entries) {
      if (entry.value > peakDayCount) {
        peakDayCount = entry.value;
        peakDay = entry.key;
      }
    }

    // Analyze weekend vs weekday pattern
    int weekendTransactions = 0;
    int weekdayTransactions = 0;
    for (final transaction in transactions) {
      final weekday = transaction.date.weekday;
      if (weekday == 6 || weekday == 7) {
        // Saturday or Sunday
        weekendTransactions++;
      } else {
        weekdayTransactions++;
      }
    }

    final weekendPreference = weekendTransactions > weekdayTransactions;

    return {
      'hourlyDistribution': hourlyDistribution,
      'weeklyDistribution': weeklyDistribution,
      'peakHour': peakHour,
      'peakDay': peakDay,
      'weekendTransactions': weekendTransactions,
      'weekdayTransactions': weekdayTransactions,
      'weekendPreference': weekendPreference,
    };
  }

  double _calculateBehaviorScore(
    Map<String, dynamic> categoryAnalysis,
    Map<String, dynamic> frequencyAnalysis,
    Map<String, dynamic> amountAnalysis,
    Map<String, dynamic> timeAnalysis,
  ) {
    double score = 0;

    // Category diversity (25 points)
    final diversity = categoryAnalysis['diversity'] as double;
    if (diversity >= 5)
      score += 25;
    else if (diversity >= 3)
      score += 20;
    else if (diversity >= 2)
      score += 15;
    else
      score += 5;

    // Frequency consistency (25 points)
    final consistencyScore = frequencyAnalysis['consistencyScore'] as double;
    score += (consistencyScore / 100) * 25;

    // Amount pattern balance (25 points)
    final amountPattern = amountAnalysis['amountPattern'] as String;
    if (amountPattern == 'balanced')
      score += 25;
    else if (amountPattern == 'mixed')
      score += 20;
    else if (amountPattern == 'small_dominant')
      score += 15;
    else
      score += 10;

    // Time pattern regularity (25 points)
    final weekendPreference = timeAnalysis['weekendPreference'] as bool;
    if (!weekendPreference)
      score += 15; // Weekday preference is generally better
    score += 10; // Base points for having any pattern

    return score.clamp(0, 100);
  }

  List<String> _generateBehaviorInsights(
    Map<String, dynamic> categoryAnalysis,
    Map<String, dynamic> frequencyAnalysis,
    Map<String, dynamic> amountAnalysis,
    Map<String, dynamic> timeAnalysis,
    double behaviorScore,
  ) {
    final insights = <String>[];

    // Transaction type specific insights
    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        insights.addAll(_generateExpenseInsights(categoryAnalysis,
            frequencyAnalysis, amountAnalysis, timeAnalysis, behaviorScore));
        break;
      case insights_screen.TransactionType.income:
        insights.addAll(_generateIncomeInsights(categoryAnalysis,
            frequencyAnalysis, amountAnalysis, timeAnalysis, behaviorScore));
        break;
      case insights_screen.TransactionType.transfer:
        insights.addAll(_generateTransferInsights(categoryAnalysis,
            frequencyAnalysis, amountAnalysis, timeAnalysis, behaviorScore));
        break;
      default:
        insights.addAll(_generateGeneralInsights(categoryAnalysis,
            frequencyAnalysis, amountAnalysis, timeAnalysis, behaviorScore));
    }

    return insights;
  }

  List<String> _generateExpenseInsights(
    Map<String, dynamic> categoryAnalysis,
    Map<String, dynamic> frequencyAnalysis,
    Map<String, dynamic> amountAnalysis,
    Map<String, dynamic> timeAnalysis,
    double behaviorScore,
  ) {
    final insights = <String>[];

    // Dominant category insight
    final dominantCategory = categoryAnalysis['dominantCategory'] as String?;
    final dominancePercentage =
        categoryAnalysis['dominancePercentage'] as double;

    if (dominantCategory != null && dominancePercentage > 40) {
      insights.add(
          'High concentration: ${dominancePercentage.toStringAsFixed(1)}% of spending on ${dominantCategory}');
    } else if (dominantCategory != null) {
      insights.add(
          'Balanced spending across categories, ${dominantCategory} leads at ${dominancePercentage.toStringAsFixed(1)}%');
    }

    // Frequency insight
    final frequencyPattern = frequencyAnalysis['frequencyPattern'] as String;
    final avgTransactionsPerDay =
        frequencyAnalysis['avgTransactionsPerDay'] as double;

    if (frequencyPattern == 'high') {
      insights.add(
          'Frequent spending: ${avgTransactionsPerDay.toStringAsFixed(1)} transactions per day - consider bundling purchases');
    } else if (frequencyPattern == 'minimal') {
      insights.add(
          'Conservative spending pattern: only ${avgTransactionsPerDay.toStringAsFixed(1)} transactions per day');
    }

    // Amount pattern insight
    final amountPattern = amountAnalysis['amountPattern'] as String;
    if (amountPattern == 'large_dominant') {
      insights.add(
          'Large expense pattern: many big transactions - review for necessity');
    } else if (amountPattern == 'small_dominant') {
      insights.add(
          'Micro-spending pattern: many small purchases - consider daily budgeting');
    }

    // Time pattern insight
    final weekendPreference = timeAnalysis['weekendPreference'] as bool;
    if (weekendPreference) {
      insights.add('Weekend spending tendency: higher activity on weekends');
    }

    // Behavior score insight
    if (behaviorScore > 80) {
      insights.add(
          'Excellent spending behavior score: ${behaviorScore.toStringAsFixed(0)}/100');
    } else if (behaviorScore < 50) {
      insights.add(
          'Spending behavior needs attention: ${behaviorScore.toStringAsFixed(0)}/100 - consider optimization');
    }

    return insights;
  }

  List<String> _generateIncomeInsights(
    Map<String, dynamic> categoryAnalysis,
    Map<String, dynamic> frequencyAnalysis,
    Map<String, dynamic> amountAnalysis,
    Map<String, dynamic> timeAnalysis,
    double behaviorScore,
  ) {
    final insights = <String>[];

    // Income diversity
    final diversity = categoryAnalysis['diversity'] as double;
    if (diversity >= 3) {
      insights.add(
          'Diverse income sources: ${diversity.toInt()} different income streams');
    } else if (diversity == 1) {
      insights
          .add('Single income source: consider diversification for stability');
    }

    // Frequency insight
    final frequencyPattern = frequencyAnalysis['frequencyPattern'] as String;
    if (frequencyPattern == 'high') {
      insights.add(
          'Regular income flow: frequent transactions indicate stable income');
    } else if (frequencyPattern == 'minimal') {
      insights
          .add('Irregular income pattern: consider building emergency fund');
    }

    // Amount pattern insight
    final avgAmount = amountAnalysis['avgAmount'] as double;
    if (avgAmount > 0) {
      insights.add(
          'Average income amount: ${_currencyFormatter?.format(avgAmount) ?? '₹0.00'} per transaction');
    }

    // Time pattern insight
    final peakDay = timeAnalysis['peakDay'] as int?;
    final dayNames = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    if (peakDay != null) {
      insights.add('Peak income day: ${dayNames[peakDay]}');
    }

    // Behavior score insight
    if (behaviorScore > 80) {
      insights.add(
          'Strong income behavior: ${behaviorScore.toStringAsFixed(0)}/100');
    }

    return insights;
  }

  List<String> _generateTransferInsights(
    Map<String, dynamic> categoryAnalysis,
    Map<String, dynamic> frequencyAnalysis,
    Map<String, dynamic> amountAnalysis,
    Map<String, dynamic> timeAnalysis,
    double behaviorScore,
  ) {
    final insights = <String>[];

    // Transfer frequency
    final frequencyPattern = frequencyAnalysis['frequencyPattern'] as String;
    if (frequencyPattern == 'high') {
      insights.add(
          'Frequent transfers: ${frequencyAnalysis['avgTransactionsPerDay']} per day - consider consolidation');
    }

    // Amount pattern
    final avgAmount = amountAnalysis['avgAmount'] as double;
    if (avgAmount > 0) {
      insights.add(
          'Average transfer amount: ${_currencyFormatter?.format(avgAmount) ?? '₹0.00'}');
    }

    // Time pattern
    final weekendPreference = timeAnalysis['weekendPreference'] as bool;
    if (weekendPreference) {
      insights.add('Weekend transfer activity detected');
    }

    // Behavior score
    insights.add(
        'Transfer behavior score: ${behaviorScore.toStringAsFixed(0)}/100');

    return insights;
  }

  List<String> _generateGeneralInsights(
    Map<String, dynamic> categoryAnalysis,
    Map<String, dynamic> frequencyAnalysis,
    Map<String, dynamic> amountAnalysis,
    Map<String, dynamic> timeAnalysis,
    double behaviorScore,
  ) {
    final insights = <String>[];

    insights.add(
        'Overall financial behavior score: ${behaviorScore.toStringAsFixed(0)}/100');

    final totalTransactions = categoryAnalysis['totalTransactions'] as int;
    insights.add('Total transactions analyzed: ${totalTransactions}');

    return insights;
  }

  String _getAnalysisTitle() {
    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        return 'Spending Behavior Analysis';
      case insights_screen.TransactionType.income:
        return 'Income Behavior Analysis';
      case insights_screen.TransactionType.transfer:
        return 'Transfer Behavior Analysis';
      default:
        return 'Financial Behavior Analysis';
    }
  }

  Color _getAnalysisColor() {
    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        return Colors.red;
      case insights_screen.TransactionType.income:
        return Colors.green;
      case insights_screen.TransactionType.transfer:
        return Colors.purple;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getAnalysisIcon() {
    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        return Icons.psychology;
      case insights_screen.TransactionType.income:
        return Icons.trending_up;
      case insights_screen.TransactionType.transfer:
        return Icons.swap_horiz;
      default:
        return Icons.analytics;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final analysis = _analyzeBehavior();

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
              _buildBehaviorScore(analysis),
              const SizedBox(height: 24),
              _buildBehaviorMetrics(analysis),
              const SizedBox(height: 24),
              _buildBehaviorInsights(analysis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAnalysisColor().withOpacity(0.2),
            _getAnalysisColor().withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getAnalysisColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAnalysisIcon(),
              color: _getAnalysisColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getAnalysisTitle(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _getAnalysisColor(),
                      ),
                ),
                Text(
                  'Understand your financial patterns and habits',
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
              color: _getAnalysisColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.psychology,
              color: _getAnalysisColor(),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorScore(Map<String, dynamic> analysis) {
    final behaviorScore = analysis['behaviorScore'] as double;
    final recentCount = analysis['recentCount'] as int;
    final monthlyCount = analysis['monthlyCount'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAnalysisColor().withOpacity(0.05),
            _getAnalysisColor().withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAnalysisColor().withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Behavior Score & Activity',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getAnalysisColor(),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child:
                    _buildScoreCard('Behavior Score', behaviorScore, 'Score'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScoreCard(
                    'Recent (7 days)', recentCount.toDouble(), 'Transactions'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScoreCard('Monthly (30 days)',
                    monthlyCount.toDouble(), 'Transactions'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String title, double value, String subtitle) {
    Color scoreColor;
    if (title.contains('Score')) {
      if (value > 80)
        scoreColor = Colors.green;
      else if (value > 60)
        scoreColor = Colors.blue;
      else if (value > 40)
        scoreColor = Colors.orange;
      else
        scoreColor = Colors.red;
    } else {
      scoreColor = _getAnalysisColor();
    }

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
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            title.contains('Score')
                ? '${value.toStringAsFixed(0)}/100'
                : value.toStringAsFixed(0),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scoreColor,
                ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scoreColor.withOpacity(0.8),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorMetrics(Map<String, dynamic> analysis) {
    final categoryAnalysis =
        analysis['categoryAnalysis'] as Map<String, dynamic>;
    final frequencyAnalysis =
        analysis['frequencyAnalysis'] as Map<String, dynamic>;
    final amountAnalysis = analysis['amountAnalysis'] as Map<String, dynamic>;

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getAnalysisColor().withOpacity(0.2),
                      _getAnalysisColor().withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bar_chart,
                  color: _getAnalysisColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Behavior Metrics',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getAnalysisColor(),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Category Diversity',
                  '${categoryAnalysis['diversity']?.toStringAsFixed(0) ?? '0'}',
                  'Categories',
                  Icons.category,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Frequency Pattern',
                  (frequencyAnalysis['frequencyPattern'] as String)
                      .toUpperCase(),
                  'Pattern',
                  Icons.schedule,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Amount Pattern',
                  (amountAnalysis['amountPattern'] as String)
                      .replaceAll('_', ' ')
                      .toUpperCase(),
                  'Pattern',
                  Icons.attach_money,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, String subtitle, IconData icon) {
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
          Icon(
            icon,
            color: _getAnalysisColor(),
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getAnalysisColor(),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getAnalysisColor().withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorInsights(Map<String, dynamic> analysis) {
    final insights = analysis['insights'] as List<String>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getAnalysisColor().withOpacity(0.05),
            _getAnalysisColor().withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAnalysisColor().withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getAnalysisColor().withOpacity(0.2),
                      _getAnalysisColor().withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: _getAnalysisColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Behavior Insights',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getAnalysisColor(),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _getAnalysisColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _getInsightIcon(insight),
                        color: _getAnalysisColor(),
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
              )),
        ],
      ),
    );
  }

  IconData _getInsightIcon(String insight) {
    if (insight.contains('Excellent') ||
        insight.contains('Strong') ||
        insight.contains('Diverse')) {
      return Icons.trending_up;
    } else if (insight.contains('High concentration') ||
        insight.contains('Large') ||
        insight.contains('Frequent')) {
      return Icons.warning_amber;
    } else if (insight.contains('Balanced') ||
        insight.contains('Conservative') ||
        insight.contains('Regular')) {
      return Icons.check_circle;
    } else if (insight.contains('consider') ||
        insight.contains('needs attention') ||
        insight.contains('Irregular')) {
      return Icons.info_outline;
    } else {
      return Icons.analytics_outlined;
    }
  }
}

extension on double {
  double sqrt() => math.sqrt(this);
}
