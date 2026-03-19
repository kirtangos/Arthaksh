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

class Transaction {
  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String? description;
  final insights_screen.TransactionType type;

  Transaction({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
    required this.type,
  });
}

class FinancialHealthWidget extends StatelessWidget {
  final double financialHealthScore;
  final List<String> financialInsights;
  final insights_screen.TransactionType? selectedType;

  const FinancialHealthWidget({
    super.key,
    required this.financialHealthScore,
    required this.financialInsights,
    required this.selectedType,
  });

  String getHealthTitle() {
    switch (selectedType) {
      case insights_screen.TransactionType.expense:
        return 'Expense Health';
      case insights_screen.TransactionType.income:
        return 'Income Health';
      case insights_screen.TransactionType.transfer:
        return 'Transfer Health';
      default:
        return 'Financial Health';
    }
  }

  Color getHealthColor(BuildContext context) {
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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${getHealthTitle()} · ${selectedType?.toString().split('.').last.toUpperCase() ?? 'All'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: getHealthColor(context),
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getHealthColor(financialHealthScore)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${financialHealthScore.toStringAsFixed(0)}/100',
                    style: TextStyle(
                      color: _getHealthColor(financialHealthScore),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: financialHealthScore / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getHealthColor(financialHealthScore),
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (financialInsights.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...financialInsights.map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
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
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            insight,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Color _getHealthColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}

class FinancialHealthCalculator {
  static void calculateFinancialHealth(
      List<dynamic> transactions,
      double totalSpent,
      insights_screen.TransactionType? selectedType,
      Function(double, List<String>) onResult) {
    final insights = <String>[];
    double score = 0;

    // Filter transactions based on selected type
    List<dynamic> filteredTransactions;
    if (selectedType == null) {
      filteredTransactions = transactions;
    } else {
      filteredTransactions =
          transactions.where((t) => t.type == selectedType).toList();
    }

    // 1. Spending diversity (up to 25 points) - for expenses only
    int categoryCount = 0;
    double diversityScore = 0;
    if (selectedType == insights_screen.TransactionType.expense) {
      categoryCount = _calculateCategoryCount(filteredTransactions);
      diversityScore = (categoryCount * 2.5).clamp(0, 25);
      if (categoryCount < 3) {
        insights.add('Try diversifying your spending across more categories');
      }
    }

    // 2. Savings rate (up to 30 points) - always use all income and filtered expenses
    final allIncome = transactions
        .where((t) => t.type == insights_screen.TransactionType.income)
        .fold<double>(0, (currentSum, t) => currentSum + (t.amount ?? 0));

    double savingsRate = 0;
    if (allIncome > 0) {
      savingsRate = ((allIncome - totalSpent) / allIncome) * 100;
    }

    final savingsScore = (savingsRate * 0.6).clamp(0, 30);
    if (savingsRate < 10) {
      insights.add('Aim to save at least 10% of your income');
    }

    // 3. Emergency fund (up to 25 points) - for expenses only
    double emergencyFundScore = 0;
    if (selectedType == insights_screen.TransactionType.expense) {
      final monthlyExpenses =
          totalSpent * 12 / 12; // Assuming current period represents a month
      emergencyFundScore = (monthlyExpenses > 0 ? 25 : 0);
      if (monthlyExpenses == 0) {
        insights.add(
            'Consider building an emergency fund (3-6 months of expenses)');
      }
    }

    // 4. Debt-to-income ratio (up to 20 points) - for expenses only
    double debtScore = 20;
    if (selectedType == insights_screen.TransactionType.expense) {
      final debtPayments = filteredTransactions
          .where((t) =>
              (t.category?.toLowerCase().contains('loan') ?? false) ||
              (t.category?.toLowerCase().contains('debt') ?? false))
          .fold<double>(0, (currentSum, t) => currentSum + (t.amount ?? 0));

      double debtToIncome = 0;
      if (allIncome > 0) {
        debtToIncome = (debtPayments / allIncome) * 100;
      }

      debtScore = 20 - (debtToIncome * 0.2).clamp(0, 20);
      if (debtToIncome > 30) {
        insights.add('Your debt payments are high relative to your income');
      }
    }

    // Calculate total score
    score = (diversityScore + savingsScore + emergencyFundScore + debtScore)
        .toDouble();

    // Add positive reinforcement
    if (savingsRate > 20) {
      insights.add('Great job saving more than 20% of your income!');
    }
    if (categoryCount >= 5 &&
        selectedType == insights_screen.TransactionType.expense) {
      insights.add('Good spending diversity across $categoryCount categories');
    }

    onResult(score.clamp(0, 100), insights.take(3).toList());
  }

  static int _calculateCategoryCount(List<dynamic> transactions) {
    final categories =
        transactions.map((t) => t.category).whereType<String>().toSet();
    return categories.length;
  }
}
