import 'package:flutter/material.dart';
import '../modern_insights_screen.dart' as insights_screen;

class TransactionTypeTheme {
  // Unified color scheme for transaction types
  static const Color expenseColor = Color(0xFFE53E3E); // Modern red
  static const Color incomeColor = Color(0xFF38A169); // Modern green
  static const Color transferColor = Color(0xFF805AD5); // Modern purple
  static const Color defaultColor = Color(0xFF3182CE); // Modern blue

  // Light opacity variants
  static Color expenseLight = expenseColor.withOpacity(0.2);
  static Color incomeLight = incomeColor.withOpacity(0.2);
  static Color transferLight = transferColor.withOpacity(0.2);
  static Color defaultLight = defaultColor.withOpacity(0.2);

  // Extra light opacity variants
  static Color expenseExtraLight = expenseColor.withOpacity(0.1);
  static Color incomeExtraLight = incomeColor.withOpacity(0.1);
  static Color transferExtraLight = transferColor.withOpacity(0.1);
  static Color defaultExtraLight = defaultColor.withOpacity(0.1);

  // Background variants
  static Color expenseBg = expenseColor.withOpacity(0.05);
  static Color incomeBg = incomeColor.withOpacity(0.05);
  static Color transferBg = transferColor.withOpacity(0.05);
  static Color defaultBg = defaultColor.withOpacity(0.05);

  // Background extra light variants
  static Color expenseBgExtraLight = expenseColor.withOpacity(0.02);
  static Color incomeBgExtraLight = incomeColor.withOpacity(0.02);
  static Color transferBgExtraLight = transferColor.withOpacity(0.02);
  static Color defaultBgExtraLight = defaultColor.withOpacity(0.02);

  // Get color based on transaction type
  static Color getColor(insights_screen.TransactionType? type) {
    switch (type) {
      case insights_screen.TransactionType.expense:
        return expenseColor;
      case insights_screen.TransactionType.income:
        return incomeColor;
      case insights_screen.TransactionType.transfer:
        return transferColor;
      default:
        return defaultColor;
    }
  }

  // Get light color variant
  static Color getLightColor(insights_screen.TransactionType? type) {
    switch (type) {
      case insights_screen.TransactionType.expense:
        return expenseLight;
      case insights_screen.TransactionType.income:
        return incomeLight;
      case insights_screen.TransactionType.transfer:
        return transferLight;
      default:
        return defaultLight;
    }
  }

  // Get extra light color variant
  static Color getExtraLightColor(insights_screen.TransactionType? type) {
    switch (type) {
      case insights_screen.TransactionType.expense:
        return expenseExtraLight;
      case insights_screen.TransactionType.income:
        return incomeExtraLight;
      case insights_screen.TransactionType.transfer:
        return transferExtraLight;
      default:
        return defaultExtraLight;
    }
  }

  // Get background color variant
  static Color getBgColor(insights_screen.TransactionType? type) {
    switch (type) {
      case insights_screen.TransactionType.expense:
        return expenseBg;
      case insights_screen.TransactionType.income:
        return incomeBg;
      case insights_screen.TransactionType.transfer:
        return transferBg;
      default:
        return defaultBg;
    }
  }

  // Get background extra light color variant
  static Color getBgExtraLightColor(insights_screen.TransactionType? type) {
    switch (type) {
      case insights_screen.TransactionType.expense:
        return expenseBgExtraLight;
      case insights_screen.TransactionType.income:
        return incomeBgExtraLight;
      case insights_screen.TransactionType.transfer:
        return transferBgExtraLight;
      default:
        return defaultBgExtraLight;
    }
  }

  // Unified icons for transaction types
  static IconData getIcon(insights_screen.TransactionType? type) {
    switch (type) {
      case insights_screen.TransactionType.expense:
        return Icons.money_off;
      case insights_screen.TransactionType.income:
        return Icons.account_balance;
      case insights_screen.TransactionType.transfer:
        return Icons.swap_horiz;
      default:
        return Icons.account_balance_wallet;
    }
  }

  // Get gradient colors for backgrounds
  static List<Color> getGradientColors(insights_screen.TransactionType? type) {
    switch (type) {
      case insights_screen.TransactionType.expense:
        return [expenseLight, expenseExtraLight];
      case insights_screen.TransactionType.income:
        return [incomeLight, incomeExtraLight];
      case insights_screen.TransactionType.transfer:
        return [transferLight, transferExtraLight];
      default:
        return [defaultLight, defaultExtraLight];
    }
  }

  // Get background gradient colors
  static List<Color> getBgGradientColors(
      insights_screen.TransactionType? type) {
    switch (type) {
      case insights_screen.TransactionType.expense:
        return [expenseBg, expenseBgExtraLight];
      case insights_screen.TransactionType.income:
        return [incomeBg, incomeBgExtraLight];
      case insights_screen.TransactionType.transfer:
        return [transferBg, transferBgExtraLight];
      default:
        return [defaultBg, defaultBgExtraLight];
    }
  }
}
