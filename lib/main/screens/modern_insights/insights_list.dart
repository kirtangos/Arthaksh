import 'package:flutter/material.dart';
import '../../../services/currency_service.dart';
import '../modern_insights_screen.dart' as insights_screen;

// Global formatNumber function (moved from modern_insights_screen.dart)
String formatNumber(double number,
    {bool includeSymbol = true,
    String? currencySymbol,
    String? currentCurrency}) {
  // Show full precise amount without K/M/B abbreviations for 100% accuracy
  if (includeSymbol) {
    final symbol = currencySymbol ??
        CurrencyService.getCurrencySymbol(currentCurrency ?? 'INR');
    return '$symbol${number.toStringAsFixed(2)}';
  }
  return number.toStringAsFixed(2);
}

class InsightsListWidget extends StatelessWidget {
  final List<String> insights;
  final insights_screen.TransactionType? selectedType;

  const InsightsListWidget({
    super.key,
    required this.insights,
    this.selectedType,
  });

  String getInsightsTitle() {
    switch (selectedType) {
      case insights_screen.TransactionType.expense:
        return 'Expense Insights';
      case insights_screen.TransactionType.income:
        return 'Income Insights';
      case insights_screen.TransactionType.transfer:
        return 'Transfer Insights';
      default:
        return 'Key Insights';
    }
  }

  Color getInsightsColor(BuildContext context) {
    switch (selectedType) {
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

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${getInsightsTitle()} · ${selectedType?.toString().split('.').last.toUpperCase() ?? 'All'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: getInsightsColor(context),
                      ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getInsightsColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: getInsightsColor(context),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        insight.startsWith('Great') ||
                                insight.startsWith('Good')
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        color: insight.startsWith('Great') ||
                                insight.startsWith('Good')
                            ? Colors.green
                            : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class InsightsCalculator {
  static List<String> calculateInsights(
      List<dynamic> transactions, double totalSpent) {
    final insights = <String>[];

    // 1. Spending diversity
    final categoryCount = _calculateCategoryCount(transactions);
    if (categoryCount < 3) {
      insights.add('Try diversifying your spending across more categories');
    }

    // 2. Savings rate
    final income = transactions.where((t) {
      final typeStr = t.type?.toString().toLowerCase() ?? '';
      return typeStr.contains('income');
    }).fold<double>(0, (currentSum, t) => currentSum + (t.amount ?? 0));

    double savingsRate = 0;
    if (income > 0) {
      savingsRate = ((income - totalSpent) / income) * 100;
    }

    if (savingsRate < 10) {
      insights.add('Aim to save at least 10% of your income');
    }

    // 3. Emergency fund
    if (totalSpent == 0) {
      insights
          .add('Consider building an emergency fund (3-6 months of expenses)');
    }

    // 4. Debt-to-income ratio
    final debtPayments = transactions
        .where((t) =>
            (t.category?.toLowerCase().contains('loan') ?? false) ||
            (t.category?.toLowerCase().contains('debt') ?? false))
        .fold<double>(0, (currentSum, t) => currentSum + (t.amount ?? 0));

    double debtToIncome = 0;
    if (income > 0) {
      debtToIncome = (debtPayments / income) * 100;
    }

    if (debtToIncome > 30) {
      insights.add('Your debt payments are high relative to your income');
    }

    // Positive reinforcement
    if (savingsRate > 20) {
      insights.add('Great job saving more than 20% of your income!');
    }
    if (categoryCount >= 5) {
      insights.add('Good spending diversity across $categoryCount categories');
    }

    return insights.take(3).toList();
  }

  static int _calculateCategoryCount(List<dynamic> transactions) {
    final categories =
        transactions.map((t) => t.category).whereType<String>().toSet();
    return categories.length;
  }
}
