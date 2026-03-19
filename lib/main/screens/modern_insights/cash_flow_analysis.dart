import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modern_insights_screen.dart' as insights_screen;
import 'package:arthaksh/services/settings_service.dart';
import 'package:arthaksh/services/currency_service.dart';
import 'transaction_type_theme.dart';

class CashFlowAnalysisWidget extends StatefulWidget {
  final List<insights_screen.Transaction> transactions;
  final insights_screen.TransactionType? selectedType;
  final String currentCurrency;

  const CashFlowAnalysisWidget({
    super.key,
    required this.transactions,
    required this.selectedType,
    required this.currentCurrency,
  });

  @override
  State<CashFlowAnalysisWidget> createState() => _CashFlowAnalysisWidgetState();
}

class _CashFlowAnalysisWidgetState extends State<CashFlowAnalysisWidget>
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

  Map<String, dynamic> _calculateCashFlowAnalysis() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final twoMonthsAgo = DateTime(now.year, now.month - 2, 1);

    // Use all transactions for cash flow analysis (ignore transaction type filter)
    final allTransactions = widget.transactions;

    // Calculate monthly cash flow
    final thisMonthData = _getMonthlyCashFlow(allTransactions, thisMonth);
    final lastMonthData = _getMonthlyCashFlow(allTransactions, lastMonth);
    final twoMonthsAgoData = _getMonthlyCashFlow(allTransactions, twoMonthsAgo);

    // Calculate trends
    final monthlyTrend =
        (thisMonthData['net'] ?? 0) - (lastMonthData['net'] ?? 0);
    final trendDirection = monthlyTrend > 0
        ? 'improving'
        : monthlyTrend < 0
            ? 'declining'
            : 'stable';

    // Calculate cash flow health
    final cashFlowHealth = _calculateCashFlowHealth(thisMonthData);

    // Generate insights
    final insights =
        _generateCashFlowInsights(thisMonthData, lastMonthData, monthlyTrend);

    return {
      'thisMonth': thisMonthData,
      'lastMonth': lastMonthData,
      'twoMonthsAgo': twoMonthsAgoData,
      'monthlyTrend': monthlyTrend,
      'trendDirection': trendDirection,
      'cashFlowHealth': cashFlowHealth,
      'insights': insights,
    };
  }

  Map<String, double> _getMonthlyCashFlow(
      List<insights_screen.Transaction> transactions, DateTime month) {
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final monthTransactions = transactions
        .where((t) => t.date.isAfter(month) && t.date.isBefore(nextMonth))
        .toList();

    final income = monthTransactions
        .where((t) => t.type == insights_screen.TransactionType.income)
        .fold<double>(
            0, (sum, t) => sum + _convertAmount(t.amount, t.currency));

    final expenses = monthTransactions
        .where((t) => t.type == insights_screen.TransactionType.expense)
        .fold<double>(
            0, (sum, t) => sum + _convertAmount(t.amount, t.currency));

    final transfers = monthTransactions
        .where((t) => t.type == insights_screen.TransactionType.transfer)
        .fold<double>(
            0, (sum, t) => sum + _convertAmount(t.amount, t.currency));

    return {
      'income': income,
      'expenses': expenses,
      'transfers': transfers,
      'net': income - expenses,
    };
  }

  double _calculateCashFlowHealth(Map<String, double> monthlyData) {
    final income = monthlyData['income'] ?? 0;
    final expenses = monthlyData['expenses'] ?? 0;
    final netCashFlow = monthlyData['net'] ?? 0;

    if (income == 0) return 0;

    // Health score based on multiple factors
    double healthScore = 0;

    // Enhanced Positive cash flow calculation (40 points + bonus)
    if (netCashFlow > 0) {
      // Tiered scoring based on cash flow strength
      final cashFlowRatio = netCashFlow / income;

      if (cashFlowRatio >= 0.3) {
        healthScore += 40; // Maximum points for excellent cash flow
        // Additional bonus for exceptional cash flow
        if (cashFlowRatio >= 0.5) {
          healthScore += 10;
        }
      } else if (cashFlowRatio >= 0.2) {
        healthScore += 35; // Strong cash flow
      } else if (cashFlowRatio >= 0.1) {
        healthScore += 30; // Good cash flow
      } else if (cashFlowRatio >= 0.05) {
        healthScore += 25; // Positive but minimal
      } else {
        healthScore += 15; // Slightly positive
      }

      // Consistency bonus - if cash flow has been positive for multiple months
      // This would require historical data - placeholder for future enhancement
      healthScore += 5; // Small consistency bonus
    } else if (netCashFlow == 0) {
      // Neutral cash flow gets some points for breaking even
      healthScore += 10;
    }
    // Negative cash flow gets 0 points for this category

    // Expense ratio (30 points)
    final expenseRatio = expenses / income;
    if (expenseRatio < 0.7)
      healthScore += 30;
    else if (expenseRatio < 0.9)
      healthScore += 20;
    else if (expenseRatio < 1.0) healthScore += 10;

    // Income stability (20 points)
    if (income > 0) healthScore += 20;

    // Transfer activity (10 points)
    final transfers = monthlyData['transfers'] ?? 0;
    if (transfers > 0 && transfers < income * 0.3) healthScore += 10;

    return healthScore.clamp(0, 100);
  }

  List<String> _generateCashFlowInsights(
    Map<String, double> thisMonth,
    Map<String, double> lastMonth,
    double monthlyTrend,
  ) {
    final insights = <String>[];

    // Cash flow direction insight
    if (monthlyTrend > 0) {
      insights.add(
          'Positive trend: Cash flow improved by ${_currencyFormatter?.format(monthlyTrend) ?? '₹0.00'} this month');
    } else if (monthlyTrend < 0) {
      insights.add(
          'Caution: Cash flow decreased by ${_currencyFormatter?.format(monthlyTrend.abs()) ?? '₹0.00'} this month');
    } else {
      insights.add('Cash flow remained stable compared to last month');
    }

    // Income vs expenses insight
    final income = thisMonth['income'] ?? 0;
    final expenses = thisMonth['expenses'] ?? 0;
    final netCashFlow = thisMonth['net'] ?? 0;

    if (netCashFlow > 0) {
      insights.add(
          'Good: You have ${_currencyFormatter?.format(netCashFlow) ?? '₹0.00'} surplus this month');
    } else {
      insights.add(
          'Alert: Spending exceeds income by ${_currencyFormatter?.format(netCashFlow.abs()) ?? '₹0.00'}');
    }

    // Expense ratio insight
    if (income > 0) {
      final expenseRatio = (expenses / income) * 100;
      if (expenseRatio > 90) {
        insights.add(
            'High expense ratio: ${expenseRatio.toStringAsFixed(1)}% of income spent');
      } else if (expenseRatio < 70) {
        insights.add(
            'Healthy expense ratio: Only ${expenseRatio.toStringAsFixed(1)}% of income spent');
      }
    }

    // Transfer insight
    final transfers = thisMonth['transfers'] ?? 0;
    if (transfers > 0) {
      insights.add(
          'Transfer activity: ${_currencyFormatter?.format(transfers) ?? '₹0.00'} moved this month');
    }

    return insights;
  }

  String _getAnalysisTitle() {
    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        return 'Expense Flow Analysis';
      case insights_screen.TransactionType.income:
        return 'Income Flow Analysis';
      case insights_screen.TransactionType.transfer:
        return 'Transfer Flow Analysis';
      default:
        return 'Cash Flow Analysis';
    }
  }

  Color _getAnalysisColor() {
    return TransactionTypeTheme.getColor(widget.selectedType);
  }

  IconData _getAnalysisIcon() {
    return TransactionTypeTheme.getIcon(widget.selectedType);
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

    final analysis = _calculateCashFlowAnalysis();

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
              _buildCashFlowSummary(analysis),
              const SizedBox(height: 24),
              _buildCashFlowTrend(analysis),
              const SizedBox(height: 24),
              _buildCashFlowInsights(analysis),
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
          colors: TransactionTypeTheme.getGradientColors(widget.selectedType),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TransactionTypeTheme.getLightColor(widget.selectedType),
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
                  'Track your money movement patterns',
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.trending_up,
              color: _getAnalysisColor(),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowSummary(Map<String, dynamic> analysis) {
    final thisMonth = analysis['thisMonth'] as Map<String, double>;

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
            'This Month Summary',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getAnalysisColor(),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFlowCard(
                  'Income',
                  thisMonth['income'] ?? 0,
                  Icons.arrow_downward,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFlowCard(
                  'Expenses',
                  thisMonth['expenses'] ?? 0,
                  Icons.arrow_upward,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFlowCard(
                  'Net Cash Flow',
                  thisMonth['net'] ?? 0,
                  thisMonth['net']! >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  thisMonth['net']! >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(
      String title, double amount, IconData icon, Color color) {
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
                color: color,
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
            _currencyFormatter?.format(amount) ?? '₹0.00',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowTrend(Map<String, dynamic> analysis) {
    final thisMonth = analysis['thisMonth'] as Map<String, double>;
    final lastMonth = analysis['lastMonth'] as Map<String, double>;
    final monthlyTrend = analysis['monthlyTrend'] as double;
    final trendDirection = analysis['trendDirection'] as String;

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
                  Icons.trending_up,
                  color: _getAnalysisColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Monthly Trend',
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
                child: _buildTrendItem('Last Month', lastMonth['net'] ?? 0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTrendItem('This Month', thisMonth['net'] ?? 0),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: monthlyTrend >= 0
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  monthlyTrend >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: monthlyTrend >= 0 ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cash flow is ${trendDirection} by ${_currencyFormatter?.format(monthlyTrend.abs()) ?? '₹0.00'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: monthlyTrend >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          _currencyFormatter?.format(amount) ?? '₹0.00',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: amount >= 0 ? Colors.green : Colors.red,
              ),
        ),
      ],
    );
  }

  Widget _buildCashFlowInsights(Map<String, dynamic> analysis) {
    final insights = analysis['insights'] as List<String>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: TransactionTypeTheme.getGradientColors(widget.selectedType),
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
                'Cash Flow Insights',
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
    if (insight.contains('Positive') ||
        insight.contains('Good') ||
        insight.contains('Excellent')) {
      return Icons.trending_up;
    } else if (insight.contains('Caution') ||
        insight.contains('Alert') ||
        insight.contains('Poor')) {
      return Icons.warning_amber;
    } else if (insight.contains('High') || insight.contains('Low')) {
      return Icons.info_outline;
    } else {
      return Icons.analytics_outlined;
    }
  }
}
