import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../modern_insights_screen.dart' as insights_screen;
import 'package:arthaksh/services/settings_service.dart';
import 'package:arthaksh/services/currency_service.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class SpendingTrendsWidget extends StatefulWidget {
  final List<insights_screen.Transaction> transactions;
  final insights_screen.TransactionType? selectedType;
  final String currentCurrency;
  final DateTimeRange? dateRange;

  const SpendingTrendsWidget({
    super.key,
    required this.transactions,
    required this.selectedType,
    required this.currentCurrency,
    this.dateRange,
  });

  @override
  State<SpendingTrendsWidget> createState() => _SpendingTrendsWidgetState();
}

class _SpendingTrendsWidgetState extends State<SpendingTrendsWidget> {
  String _displayCurrency = 'USD';
  NumberFormat? _currencyFormatter;

  String getTrendsTitle() {
    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        return 'Expense Trends';
      case insights_screen.TransactionType.income:
        return 'Income Trends';
      case insights_screen.TransactionType.transfer:
        return 'Transfer Trends';
      default:
        return 'Spending Trends';
    }
  }

  Color getTrendsColor() {
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

  IconData getTrendsIcon() {
    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        return Icons.trending_down_rounded;
      case insights_screen.TransactionType.income:
        return Icons.trending_up_rounded;
      case insights_screen.TransactionType.transfer:
        return Icons.swap_horiz_rounded;
      default:
        return Icons.trending_up_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencySettings();
  }

  Future<void> _loadCurrencySettings() async {
    final currency = await SettingsService.getSelectedCurrency();

    // Ensure currency cache is initialized for conversions
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
    }
  }

  // Convert amount from original currency to display currency
  double _convertAmount(double amount, String originalCurrency) {
    if (originalCurrency == _displayCurrency) return amount;

    // Use CurrencyService for synchronous conversion
    return CurrencyService.convertAmountSync(
        amount, originalCurrency, _displayCurrency);
  }

  @override
  Widget build(BuildContext context) {
    final monthlyData = _calculateMonthlyTrends();

    if (monthlyData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        getTrendsColor().withOpacity(0.2),
                        getTrendsColor().withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        getTrendsIcon(),
                        color: getTrendsColor(),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${getTrendsTitle()} · ${widget.selectedType?.toString().split('.').last.toUpperCase() ?? 'ALL'}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: getTrendsColor(),
                                ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getTrendsColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: getTrendsColor(),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTrendChart(monthlyData, context),
            const SizedBox(height: 20),
            _buildTrendInsights(monthlyData, context),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(List<MonthlyData> data, BuildContext context) {
    if (data.length < 2) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Need more data for trend analysis',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final maxValue = data.map((d) => d.total).reduce((a, b) => a > b ? a : b);
    final minValue = data.map((d) => d.total).reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    return Container(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: data.asMap().entries.map((entry) {
                final monthData = entry.value;
                final height =
                    range > 0 ? (monthData.total - minValue) / range : 0.5;
                final barHeight = height * 140;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutBack,
                          height: barHeight,
                          width: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                getTrendsColor().withOpacity(0.9),
                                getTrendsColor().withOpacity(0.6),
                                getTrendsColor().withOpacity(0.3),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: getTrendsColor().withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatAmount(monthData.total),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: data.map((monthData) {
                return Expanded(
                  child: Text(
                    DateFormat('MMM').format(monthData.month),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendInsights(List<MonthlyData> data, BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();

    final insights = <String>[];
    final recent = data.length >= 3 ? data.sublist(data.length - 3) : data;
    final earlier = data.length >= 6
        ? data.sublist(data.length - 6, data.length - 3)
        : <MonthlyData>[];

    _generateTypeSpecificTrendInsights(data, recent, earlier, insights);
    _generateVolatilityInsights(data, insights);
    _generatePatternInsights(data, insights);

    if (data.length >= 12) {
      _generateSeasonalInsights(data, insights);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            getTrendsColor().withOpacity(0.05),
            getTrendsColor().withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: getTrendsColor().withOpacity(0.1),
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
                      getTrendsColor().withOpacity(0.2),
                      getTrendsColor().withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  getTrendsIcon(),
                  size: 20,
                  color: getTrendsColor(),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${getTrendsTitle().replaceAll(' Trends', '')} Analysis',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: getTrendsColor(),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            _getInsightColor(insight, context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _getInsightIcon(insight),
                        color: _getInsightColor(insight, context),
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
              ),
            );
          }),
        ],
      ),
    );
  }

  void _generateTypeSpecificTrendInsights(
    List<MonthlyData> data,
    List<MonthlyData> recent,
    List<MonthlyData> earlier,
    List<String> insights,
  ) {
    if (recent.length >= 2 && earlier.length >= 2) {
      final recentAvg =
          recent.map((d) => d.total).reduce((a, b) => a + b) / recent.length;
      final earlierAvg =
          earlier.map((d) => d.total).reduce((a, b) => a + b) / earlier.length;

      final change = ((recentAvg - earlierAvg) / earlierAvg * 100);

      switch (widget.selectedType) {
        case insights_screen.TransactionType.expense:
          if (change > 15) {
            insights.add(
                '⚠️ Spending surged by ${change.toStringAsFixed(1)}% - review budget');
          } else if (change > 5) {
            insights.add(
                '📈 Spending increased by ${change.toStringAsFixed(1)}% - monitor closely');
          } else if (change < -15) {
            insights.add(
                '🎉 Great! Spending reduced by ${change.abs().toStringAsFixed(1)}% - excellent control');
          } else if (change < -5) {
            insights.add(
                '✅ Spending decreased by ${change.abs().toStringAsFixed(1)}% - good progress');
          } else {
            insights.add(
                '📊 Spending stable at ${_formatFullAmount(recentAvg)} per month');
          }
          break;
        case insights_screen.TransactionType.income:
          if (change > 15) {
            insights.add(
                '🚀 Excellent! Income grew by ${change.toStringAsFixed(1)}% - strong performance');
          } else if (change > 5) {
            insights.add(
                '📈 Income increased by ${change.toStringAsFixed(1)}% - positive trend');
          } else if (change < -15) {
            insights.add(
                '⚠️ Income dropped by ${change.abs().toStringAsFixed(1)}% - investigate causes');
          } else if (change < -5) {
            insights.add(
                '📉 Income decreased by ${change.abs().toStringAsFixed(1)}% - monitor closely');
          } else {
            insights.add(
                '💰 Income stable at ${_formatFullAmount(recentAvg)} per month');
          }
          break;
        case insights_screen.TransactionType.transfer:
          if (change > 20) {
            insights.add(
                '🔄 Transfers increased by ${change.toStringAsFixed(1)}% - check necessity');
          } else if (change < -20) {
            insights.add(
                '✅ Transfers reduced by ${change.abs().toStringAsFixed(1)}% - more efficient');
          } else {
            insights.add(
                '💸 Transfer activity stable at ${_formatFullAmount(recentAvg)} per month');
          }
          break;
        default:
          if (change > 10) {
            insights.add(
                '📊 Activity increased by ${change.toStringAsFixed(1)}% recently');
          } else if (change < -10) {
            insights.add(
                '📉 Activity decreased by ${change.abs().toStringAsFixed(1)}% recently');
          } else {
            insights.add('⚖️ Activity has been relatively stable');
          }
      }
    }

    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        final highestMonth = data.reduce((a, b) => a.total > b.total ? a : b);
        final lowestMonth = data.reduce((a, b) => a.total < b.total ? a : b);

        insights.add(
            '🔴 Highest spending: ${DateFormat('MMM yyyy').format(highestMonth.month)} (${_formatFullAmount(highestMonth.total)})');
        insights.add(
            '🟢 Lowest spending: ${DateFormat('MMM yyyy').format(lowestMonth.month)} (${_formatFullAmount(lowestMonth.total)})');
        break;
      case insights_screen.TransactionType.income:
        final highestMonth = data.reduce((a, b) => a.total > b.total ? a : b);
        final lowestMonth = data.reduce((a, b) => a.total < b.total ? a : b);

        insights.add(
            '💰 Peak income: ${DateFormat('MMM yyyy').format(highestMonth.month)} (${_formatFullAmount(highestMonth.total)})');
        insights.add(
            '📉 Low income: ${DateFormat('MMM yyyy').format(lowestMonth.month)} (${_formatFullAmount(lowestMonth.total)})');
        break;
      case insights_screen.TransactionType.transfer:
        final highestMonth = data.reduce((a, b) => a.total > b.total ? a : b);
        final lowestMonth = data.reduce((a, b) => a.total < b.total ? a : b);

        insights.add(
            '🔄 Max transfers: ${DateFormat('MMM yyyy').format(highestMonth.month)} (${_formatFullAmount(highestMonth.total)})');
        insights.add(
            '✅ Min transfers: ${DateFormat('MMM yyyy').format(lowestMonth.month)} (${_formatFullAmount(lowestMonth.total)})');
        break;
      default:
        final highestMonth = data.reduce((a, b) => a.total > b.total ? a : b);
        final lowestMonth = data.reduce((a, b) => a.total < b.total ? a : b);

        insights.add(
            '📊 Peak activity: ${DateFormat('MMM yyyy').format(highestMonth.month)} (${_formatFullAmount(highestMonth.total)})');
        insights.add(
            '📉 Low activity: ${DateFormat('MMM yyyy').format(lowestMonth.month)} (${_formatFullAmount(lowestMonth.total)})');
    }
  }

  void _generateVolatilityInsights(
      List<MonthlyData> data, List<String> insights) {
    if (data.length < 3) return;

    final values = data.map((d) => d.total).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            values.length;
    final stdDev = variance > 0 ? math.sqrt(variance) : 0;
    final volatility = mean > 0 ? (stdDev / mean) * 100 : 0;

    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        if (volatility > 30) {
          insights.add(
              '⚡ High spending volatility (${volatility.toStringAsFixed(1)}%) - budgeting recommended');
        } else if (volatility > 15) {
          insights.add(
              '📊 Moderate spending variation (${volatility.toStringAsFixed(1)}%)');
        } else {
          insights.add(
              '🎯 Consistent spending patterns (${volatility.toStringAsFixed(1)}% volatility)');
        }
        break;
      case insights_screen.TransactionType.income:
        if (volatility > 25) {
          insights.add(
              '⚠️ Income fluctuation high (${volatility.toStringAsFixed(1)}%) - consider stabilization');
        } else if (volatility > 10) {
          insights.add(
              '📈 Moderate income variation (${volatility.toStringAsFixed(1)}%)');
        } else {
          insights.add(
              '💪 Stable income stream (${volatility.toStringAsFixed(1)}% volatility)');
        }
        break;
      case insights_screen.TransactionType.transfer:
        if (volatility > 40) {
          insights.add(
              '🔄 Transfer activity volatile (${volatility.toStringAsFixed(1)}%)');
        } else {
          insights.add(
              '⚖️ Transfer patterns stable (${volatility.toStringAsFixed(1)}% volatility)');
        }
        break;
      default:
        insights
            .add('📊 Activity volatility: ${volatility.toStringAsFixed(1)}%');
    }
  }

  void _generatePatternInsights(List<MonthlyData> data, List<String> insights) {
    if (data.length < 4) return;

    int consecutiveIncreases = 0;
    int consecutiveDecreases = 0;

    for (int i = data.length - 1; i > 0; i--) {
      if (data[i].total > data[i - 1].total) {
        consecutiveIncreases++;
        consecutiveDecreases = 0;
      } else if (data[i].total < data[i - 1].total) {
        consecutiveDecreases++;
        consecutiveIncreases = 0;
      } else {
        break;
      }
    }

    switch (widget.selectedType) {
      case insights_screen.TransactionType.expense:
        if (consecutiveIncreases >= 3) {
          insights.add(
              '📈 Spending rising for ${consecutiveIncreases} months - budget alert!');
        } else if (consecutiveDecreases >= 3) {
          insights.add(
              '📉 Spending falling for ${consecutiveDecreases} months - great discipline!');
        }
        break;
      case insights_screen.TransactionType.income:
        if (consecutiveIncreases >= 3) {
          insights.add(
              '🚀 Income growing for ${consecutiveIncreases} months - excellent trend!');
        } else if (consecutiveDecreases >= 2) {
          insights.add(
              '📉 Income declining for ${consecutiveDecreases} months - review sources');
        }
        break;
      case insights_screen.TransactionType.transfer:
        if (consecutiveIncreases >= 2) {
          insights.add('🔄 Transfers increasing - monitor account management');
        }
        break;
      case null:
        if (consecutiveIncreases >= 3) {
          insights.add(
              '📈 Activity rising for ${consecutiveIncreases} months - overall trend');
        } else if (consecutiveDecreases >= 3) {
          insights.add(
              '📉 Activity falling for ${consecutiveDecreases} months - overall trend');
        }
        break;
    }
  }

  void _generateSeasonalInsights(
      List<MonthlyData> data, List<String> insights) {
    if (data.length < 12) return;

    final currentMonth = DateTime.now();
    final currentMonthData =
        data.where((d) => d.month.month == currentMonth.month).toList();

    if (currentMonthData.isNotEmpty) {
      final sameMonthLastYear = data
          .where((d) =>
              d.month.month == currentMonth.month &&
              d.month.year == currentMonth.year - 1)
          .toList();

      if (sameMonthLastYear.isNotEmpty) {
        final currentAvg =
            currentMonthData.map((d) => d.total).reduce((a, b) => a + b) /
                currentMonthData.length;
        final lastYearAvg =
            sameMonthLastYear.map((d) => d.total).reduce((a, b) => a + b) /
                sameMonthLastYear.length;
        final yearlyChange = ((currentAvg - lastYearAvg) / lastYearAvg * 100);

        switch (widget.selectedType) {
          case insights_screen.TransactionType.expense:
            insights.add(
                '📅 Year-over-year: ${yearlyChange > 0 ? 'up' : 'down'} ${yearlyChange.abs().toStringAsFixed(1)}% vs last ${DateFormat('MMMM').format(currentMonth)}');
            break;
          case insights_screen.TransactionType.income:
            insights.add(
                '📅 Annual comparison: ${yearlyChange > 0 ? 'growth' : 'decline'} of ${yearlyChange.abs().toStringAsFixed(1)}%');
            break;
          default:
            insights.add(
                '📅 Year-over-year change: ${yearlyChange.toStringAsFixed(1)}%');
        }
      }
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else if (amount >= 1) {
      return amount.toStringAsFixed(0);
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  String _formatFullAmount(double amount) {
    if (_currencyFormatter != null) {
      return _currencyFormatter!.format(amount);
    }
    // Fallback to simple formatting if currency formatter is not ready
    return insights_screen.formatNumber(amount,
        currentCurrency: widget.currentCurrency);
  }

  Color _getInsightColor(String insight, BuildContext context) {
    if (insight.contains('decreased') || insight.contains('Great')) {
      return Colors.green;
    } else if (insight.contains('increased')) {
      return Colors.orange;
    } else if (insight.contains('stable')) {
      return Colors.blue;
    } else if (insight.contains('Highest')) {
      return Colors.red;
    } else if (insight.contains('Lowest')) {
      return Colors.teal;
    }
    return Theme.of(context).colorScheme.primary;
  }

  IconData _getInsightIcon(String insight) {
    if (insight.contains('decreased') ||
        insight.contains('Great') ||
        insight.contains('🎉') ||
        insight.contains('✅')) {
      return Icons.trending_down;
    } else if (insight.contains('increased') ||
        insight.contains('📈') ||
        insight.contains('🚀') ||
        insight.contains('⚠️')) {
      return Icons.trending_up;
    } else if (insight.contains('stable') ||
        insight.contains('📊') ||
        insight.contains('🎯') ||
        insight.contains('⚖️')) {
      return Icons.trending_flat;
    } else if (insight.contains('Highest') ||
        insight.contains('🔴') ||
        insight.contains('💰') ||
        insight.contains('🔄')) {
      return Icons.arrow_upward;
    } else if (insight.contains('Lowest') ||
        insight.contains('🟢') ||
        insight.contains('📉') ||
        insight.contains('✅')) {
      return Icons.arrow_downward;
    } else if (insight.contains('volatility') ||
        insight.contains('⚡') ||
        insight.contains('💪')) {
      return Icons.show_chart;
    } else if (insight.contains('rising') ||
        insight.contains('growing') ||
        insight.contains('📈')) {
      return Icons.trending_up;
    } else if (insight.contains('falling') ||
        insight.contains('declining') ||
        insight.contains('📉')) {
      return Icons.trending_down;
    } else if (insight.contains('Year-over-year') || insight.contains('📅')) {
      return Icons.date_range;
    }
    return Icons.info_outline;
  }

  List<MonthlyData> _calculateMonthlyTrends() {
    final filteredTransactions = widget.selectedType == null
        ? widget.transactions
        : widget.transactions
            .where((t) => t.type == widget.selectedType)
            .toList();

    if (filteredTransactions.isEmpty) return [];

    // Group by month
    final monthlyGroups = <DateTime, List<insights_screen.Transaction>>{};

    for (final transaction in filteredTransactions) {
      final month = DateTime(transaction.date.year, transaction.date.month, 1);
      monthlyGroups.putIfAbsent(month, () => []).add(transaction);
    }

    // Sort months and calculate totals
    final sortedMonths = monthlyGroups.keys.toList()..sort();

    final result = sortedMonths.map((month) {
      final monthTransactions = monthlyGroups[month]!;
      final total = monthTransactions.fold<double>(0, (sum, t) {
        // Convert each transaction amount to display currency
        final convertedAmount = _convertAmount(t.amount, t.currency);
        return sum + convertedAmount;
      });

      return MonthlyData(month: month, total: total);
    }).toList();

    return result;
  }
}

class MonthlyData {
  final DateTime month;
  final double total;

  MonthlyData({required this.month, required this.total});
}
