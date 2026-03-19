import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../services/currency_service.dart';
import '../../auth_choice_sheet.dart';
import 'package:logging/logging.dart';

class ExcelExportService {
  static final Logger _logger = Logger('ExcelExport');

  // Constants for Excel styling
  static const String _baseCurrency = 'INR';
  static const String _headerBackgroundColor = '#F3F4F6';
  static const String _titleBackgroundColor = '#1E40AF';
  static const String _titleTextColor = '#FFFFFF';
  static const String _metaTextColor = '#555555';
  static const String _greenTextColor = '#059669';
  static const String _redTextColor = '#DC2626';
  static const String _blueTextColor = '#4F46E5';
  static const String _indigoTextColor = '#2563EB';

  // Date range selection for export
  String _selectedDateRange = 'All Time';
  DateTimeRange? _customDateRange;

  // Getters for state
  String get selectedDateRange => _selectedDateRange;
  DateTimeRange? get customDateRange => _customDateRange;

  // Setters for state
  void setSelectedDateRange(String value) {
    _selectedDateRange = value;
  }

  void setCustomDateRange(DateTimeRange? value) {
    _customDateRange = value;
  }

  // Method to fetch exchange rates from API using base currency
  Future<Map<String, double>> _fetchExchangeRates(String baseCurrency) async {
    try {
      final url = 'https://api.exchangerate-api.com/v4/latest/$baseCurrency';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, double>.from(data['rates']);
      } else {
        throw Exception('Failed to fetch exchange rates');
      }
    } catch (e) {
      _logger.severe('Error fetching exchange rates: $e');
      return {}; // Return empty map on failure
    }
  }

  // Excel styling - clean without borders
  xls.CellStyle get headerStyle => xls.CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex:
            xls.ExcelColor.fromHexString(_headerBackgroundColor),
        horizontalAlign: xls.HorizontalAlign.Center,
      );

  // Calculate Financial Health Score (0-100)
  double _calculateHealthScore(
      double income, double expenses, double savingsRate) {
    if (income <= 0) return 0;

    double score = 0;

    // Savings Rate Component (40% weight)
    if (savingsRate >= 20)
      score += 40;
    else if (savingsRate >= 10)
      score += 30;
    else if (savingsRate >= 5)
      score += 20;
    else if (savingsRate >= 0)
      score += 10;
    else
      score += 0;

    // Income vs Expenses Component (40% weight)
    final netSavings = income - expenses;
    final netSavingsRate = netSavings / income;
    if (netSavingsRate >= 0.2)
      score += 40;
    else if (netSavingsRate >= 0.1)
      score += 30;
    else if (netSavingsRate >= 0)
      score += 20;
    else if (netSavingsRate >= -0.1)
      score += 10;
    else
      score += 0;

    // Income Stability Component (20% weight) - simplified
    score += 20; // Assuming stable income for now

    return score.clamp(0, 100);
  }

  // Get Health Score Description
  String _getHealthScoreDescription(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Poor';
    return 'Critical';
  }

  // Calculate Month-over-Month Change
  Map<String, dynamic> _calculateMonthlyChange(
      Map<int, double> monthlyExpenses) {
    if (monthlyExpenses.length < 2)
      return {
        'change': 0.0,
        'changePercent': 0.0,
        'trend': 'Insufficient Data'
      };

    final sortedMonths = monthlyExpenses.keys.toList()..sort();
    final currentMonth = sortedMonths.last;
    final previousMonth =
        sortedMonths[sortedMonths.length - 2]; // Safe: length >= 2 here

    final currentExpense = monthlyExpenses[currentMonth] ?? 0;
    final previousExpense = monthlyExpenses[previousMonth] ?? 0;

    final change = currentExpense - previousExpense;
    final changePercent =
        previousExpense != 0 ? (change / previousExpense) * 100 : 0;

    return {
      'change': change,
      'changePercent': changePercent,
      'trend': changePercent > 5
          ? 'Increasing'
          : changePercent < -5
              ? 'Decreasing'
              : 'Stable'
    };
  }

  DateTimeRange? _getDateRangeForExport() {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (_selectedDateRange) {
      case 'All Time':
        return null;
      case 'Last 7 days':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6, 0, 0, 0,
              0), // 6 days ago at start of day
          end: todayEnd,
        );
      case 'Last 30 days':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 29, 0, 0, 0,
              0), // 29 days ago at start of day
          end: todayEnd,
        );
      case 'Last 3 months':
        return DateTimeRange(
          start: DateTime(now.year, now.month - 3, now.day, 0, 0, 0, 0)
              .add(const Duration(days: 1)), // 3 months ago at start of day
          end: todayEnd,
        );
      case 'Last year':
        return DateTimeRange(
          start: DateTime(now.year - 1, now.month, now.day, 0, 0, 0, 0)
              .add(const Duration(days: 1)), // 1 year ago at start of day
          end: todayEnd,
        );
      case 'Custom Range':
        return _customDateRange;
      default:
        return null;
    }
  }

  // Helper function to format numbers with K, M, B suffixes and proper formatting
  String formatNumber(double num,
      {bool forExcel = false,
      String? userCurrencySymbol,
      String? userCurrencyLocale}) {
    final isNegative = num < 0;
    final absNum = num.abs();
    final formatter = intl.NumberFormat.decimalPattern('en_IN');

    if (forExcel) {
      // For Excel, we want to maintain the full number but format it nicely
      return formatter.format(num);
    } else if (absNum >= 1000000000) {
      final value = absNum / 1000000000;
      return '${isNegative ? '-' : ''}${value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}B';
    } else if (absNum >= 1000000) {
      final value = absNum / 1000000;
      return '${isNegative ? '-' : ''}${value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}M';
    } else if (absNum >= 1000) {
      final value = absNum / 1000;
      return '${isNegative ? '-' : ''}${value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}K';
    } else {
      // For numbers less than 1000, show 2 decimal places if not whole number
      return num % 1 == 0 ? num.toInt().toString() : num.toStringAsFixed(2);
    }
  }

  Future<void> exportExcel(BuildContext context) async {
    // Show loading indicator immediately
    bool isExporting = true;
    NavigatorState? navigator = Navigator.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Exporting Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                StreamBuilder<bool>(
                  stream: Stream.fromFuture(Future.delayed(
                    const Duration(seconds: 1),
                    () => true,
                  )),
                  builder: (context, snapshot) {
                    if (snapshot.data == true && isExporting) {
                      return const Text('Preparing your export...');
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      _logger.info('Starting Excel export process');

      // Ensure auth
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logger.warning('No user found, showing auth choice');
        await showAuthChoiceSheet(context);
        user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _logger.severe('User still not authenticated after auth prompt');
          if (navigator.mounted) navigator.pop();
          return;
        }
      }

      _logger.info('User authenticated: ${user.uid}');

      // Check premium status
      _logger.fine('Checking premium status...');
      final isPremium = await _isUserPremium(user.uid);
      if (!isPremium) {
        _logger.warning('User does not have premium access');
        if (navigator.mounted) navigator.pop();
        _showUpgradePrompt(context);
        return;
      }

      _logger.info('User has premium access, proceeding with export');

      // Fetch expenses
      _logger.fine('Fetching expenses from Firestore...');

      // Get the selected date range
      final dateRange = _getDateRangeForExport();
      final q = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .orderBy('date', descending: true);

      // Apply date filter if not 'All Time'
      Query<Map<String, dynamic>> query = q;
      if (dateRange != null) {
        query = q.where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start),
            isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
      }

      final snap = await query.get();
      final docs = snap.docs;
      _logger.info('Found ${docs.length} expenses to export');

      if (docs.isEmpty) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true)
              .pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No expenses found to export')),
          );
        }
        return;
      }

      // Fetch exchange rates for currency conversion using base currency
      _logger.fine('Fetching exchange rates...');
      final baseCurrency = _baseCurrency; // Use INR as base currency
      final userCurrency = await CurrencyService.getCurrency();
      final rates = await _fetchExchangeRates(baseCurrency);
      final userRate =
          rates[userCurrency] ?? 1.0; // Rate from base to user currency

      // Generate Excel file with conversion
      await _generateExcelFile(context, docs, dateRange, rates, userRate,
          baseCurrency, userCurrency);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _generateExcelFile(
      BuildContext context,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      DateTimeRange? dateRange,
      Map<String, double> rates,
      double userRate,
      String baseCurrency,
      String userCurrency) async {
    // Define styles
    final titleStyle = xls.CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: xls.ExcelColor.fromHexString(_titleTextColor),
      backgroundColorHex: xls.ExcelColor.fromHexString(_titleBackgroundColor),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    final metaStyle = xls.CellStyle(
      fontSize: 12,
      fontColorHex: xls.ExcelColor.fromHexString(_metaTextColor),
      fontFamily: 'Arial',
      verticalAlign: xls.VerticalAlign.Center,
    );

    // Initialize Excel
    _logger.fine('Creating Excel workbook...');
    final excel = xls.Excel.createExcel();

    // Initialize sheets
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Summary');
    final summarySheet = excel['Summary'];

    // Create transactions sheet
    excel.copy('Summary', 'Transactions');
    final transactionsSheet = excel['Transactions'];

    // Set column widths for summary sheet - cleaner layout
    summarySheet.setColumnWidth(0, 25); // A - Labels
    summarySheet.setColumnWidth(1, 20); // B - Values
    summarySheet.setColumnWidth(2, 20); // C - Values
    summarySheet.setColumnWidth(3, 20); // D - Values
    summarySheet.setColumnWidth(4, 20); // E - Values

    // Set column widths for transactions sheet
    transactionsSheet.setColumnWidth(0, 20); // Date
    transactionsSheet.setColumnWidth(1, 15); // Type
    transactionsSheet.setColumnWidth(2, 20); // Category
    transactionsSheet.setColumnWidth(3, 15); // Amount
    transactionsSheet.setColumnWidth(4, 30); // Note
    transactionsSheet.setColumnWidth(5, 20); // Payee
    transactionsSheet.setColumnWidth(6, 15); // Transaction ID

    // Get date range display string
    String dateRangeDisplay = _selectedDateRange;
    if (dateRange != null && _selectedDateRange != 'Custom Range') {
      final dateFormat = intl.DateFormat('MMM d, yyyy');
      dateRangeDisplay =
          '${dateFormat.format(dateRange.start)} to ${dateFormat.format(dateRange.end)}';
    } else if (_selectedDateRange == 'Custom Range' &&
        _customDateRange != null) {
      final dateFormat = intl.DateFormat('MMM d, yyyy');
      dateRangeDisplay =
          '${dateFormat.format(_customDateRange!.start)} to ${dateFormat.format(_customDateRange!.end)}';
    }

    // Get current timestamp for export
    final exportTime =
        intl.DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Add elegant header with better spacing
    summarySheet.appendRow([xls.TextCellValue('')]); // Breathing room
    summarySheet.appendRow([xls.TextCellValue('Financial Summary')]);
    summarySheet.merge(
        xls.CellIndex.indexByString('A2'), xls.CellIndex.indexByString('E2'));
    summarySheet.cell(xls.CellIndex.indexByString('A2')).cellStyle = titleStyle;

    // Add Executive Summary Section
    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing
    summarySheet.appendRow([xls.TextCellValue('Executive Summary')]);
    summarySheet.merge(
        xls.CellIndex.indexByString('A${summarySheet.rows.length}'),
        xls.CellIndex.indexByString('E${summarySheet.rows.length}'));
    summarySheet
        .cell(xls.CellIndex.indexByString('A${summarySheet.rows.length}'))
        .cellStyle = xls.CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: xls.ExcelColor.fromHexString(_titleTextColor),
      backgroundColorHex: xls.ExcelColor.fromHexString(_titleBackgroundColor),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing
    summarySheet.appendRow([xls.TextCellValue('Period: $dateRangeDisplay')]);
    summarySheet.appendRow([
      xls.TextCellValue(
          'Generated: ${intl.DateFormat('dd MMM yyyy').format(DateTime.now())}')
    ]);
    summarySheet.appendRow([xls.TextCellValue('Currency: $userCurrency')]);
    summarySheet.appendRow([xls.TextCellValue('')]); // Empty row for spacing

    // Apply elegant styling to metadata
    summarySheet.cell(xls.CellIndex.indexByString('A4')).cellStyle = metaStyle;
    summarySheet.cell(xls.CellIndex.indexByString('A5')).cellStyle = metaStyle;
    summarySheet.cell(xls.CellIndex.indexByString('A6')).cellStyle = metaStyle;

    // Add KPI Dashboard Section

    // Add KPI Dashboard Section
    final kpiHeaders = ['Income', 'Expenses', 'Savings', 'Rate', 'Top Expense'];
    summarySheet
        .appendRow(kpiHeaders.map((e) => xls.TextCellValue(e)).toList());
    final kpiHeaderRow = summarySheet.rows.length;

    // Style KPI headers
    for (var i = 0; i < kpiHeaders.length; i++) {
      summarySheet
          .cell(xls.CellIndex.indexByString(
              '${String.fromCharCode(65 + i)}$kpiHeaderRow'))
          .cellStyle = xls.CellStyle(
        bold: true,
        fontSize: 12,
        horizontalAlign: xls.HorizontalAlign.Center,
        backgroundColorHex: xls.ExcelColor.fromHexString('#F8FAFC'),
      );
    }

    // Style KPI values row
    for (var i = 0; i < kpiHeaders.length; i++) {
      summarySheet
          .cell(xls.CellIndex.indexByString(
              '${String.fromCharCode(65 + i)}${kpiHeaderRow + 1}'))
          .cellStyle = xls.CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: xls.ExcelColor.fromHexString('#F3F4F6'),
        horizontalAlign: xls.HorizontalAlign.Center,
      );
    }

    // Add title to Transactions sheet
    transactionsSheet.appendRow([xls.TextCellValue('Transaction Details')]);
    transactionsSheet.merge(
        xls.CellIndex.indexByString('A1'), xls.CellIndex.indexByString('E1'));
    transactionsSheet.cell(xls.CellIndex.indexByString('A1')).cellStyle =
        titleStyle;

    // Add date range to Transactions sheet
    transactionsSheet.appendRow([
      xls.TextCellValue('REPORT PERIOD: $dateRangeDisplay'),
    ]);
    transactionsSheet.merge(
        xls.CellIndex.indexByString('A2'), xls.CellIndex.indexByString('E2'));
    transactionsSheet.cell(xls.CellIndex.indexByString('A2')).cellStyle =
        metaStyle;

    // Add export time to Transactions sheet
    transactionsSheet.appendRow([
      xls.TextCellValue('Exported:'),
      xls.TextCellValue(exportTime),
    ]);
    transactionsSheet.merge(
        xls.CellIndex.indexByString('A3'), xls.CellIndex.indexByString('B3'));
    transactionsSheet.cell(xls.CellIndex.indexByString('A3')).cellStyle =
        metaStyle;
    transactionsSheet.appendRow([xls.TextCellValue('')]); // Empty row

    // Add headers with proper CellValue types to transactions sheet
    final headers = [
      xls.TextCellValue('Date'),
      xls.TextCellValue('Type'),
      xls.TextCellValue('Category'),
      xls.TextCellValue('Amount'),
      xls.TextCellValue('Note'),
      xls.TextCellValue('Payee'),
      xls.TextCellValue('Transaction ID'),
    ];
    transactionsSheet.appendRow(headers);
    for (var i = 0; i < headers.length; i++) {
      transactionsSheet
          .cell(xls.CellIndex.indexByString('${String.fromCharCode(65 + i)}3'))
          .cellStyle = headerStyle;
    }

    // Process data and create sheets with currency conversion
    await _processDataAndCreateSheets(context, docs, summarySheet,
        transactionsSheet, kpiHeaderRow, excel, rates, userRate);
  }

  Future<void> _processDataAndCreateSheets(
      BuildContext context,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      xls.Sheet summarySheet,
      xls.Sheet transactionsSheet,
      int kpiHeaderRow,
      xls.Excel excel,
      Map<String, double> rates,
      double userRate) async {
    double totalExpense = 0, totalIncome = 0;

    // Fastest possible export - minimal processing
    final dateFormat = intl.DateFormat('dd-MMM-yyyy HH:mm');

    // Define color styles
    final redText = xls.ExcelColor.fromHexString(_redTextColor); // Red-600
    final greenText =
        xls.ExcelColor.fromHexString(_greenTextColor); // Green-600
    final indigoText =
        xls.ExcelColor.fromHexString(_blueTextColor); // Indigo-600

    // Define row styles
    final expenseStyle = xls.CellStyle(
      fontColorHex: redText,
    );
    final incomeStyle = xls.CellStyle(
      fontColorHex: greenText,
    );
    final transferStyle = xls.CellStyle(
      fontColorHex: indigoText,
    );

    // Initialize monthly tracking maps
    final Map<int, double> monthlyTotals =
        {}; // key: year*100 + month (net values)
    final Map<int, double> monthlyIncome =
        {}; // key: year*100 + month (income only)
    final Map<int, double> monthlyExpenses =
        {}; // key: year*100 + month (expenses only)
    final Map<int, int> monthlyTransactionCounts = {};
    final Map<int, int> dayOfWeekCounts = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0
    };
    final Map<int, double> dayOfWeekTotals = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0
    };

    // Track largest expense
    double largestExpense = 0;
    String largestExpenseCategory = '';

    // Track notes and payees for summary
    final Map<String, int> noteFrequency = {};
    final Map<String, double> noteAmounts = {};
    final Map<String, int> payeeFrequency = {};
    final Map<String, double> payeeAmounts = {};

    // Get user's selected currency information
    final userCurrency = await CurrencyService.getCurrency();
    final userCurrencySymbol = CurrencyService.getCurrencySymbol(userCurrency);
    final userCurrencyLocale = CurrencyService.getCurrencyLocale(userCurrency);

    // Helper function for consistent 2-decimal formatting with user's currency and conversion
    String formatToTwoDecimals(double num) {
      final convertedAmount = num * userRate; // Apply conversion
      final formatter = intl.NumberFormat('#,##0.00', userCurrencyLocale);
      return '$userCurrencySymbol${formatter.format(convertedAmount)}';
    }

    // Process data in one pass
    for (final d in docs) {
      final data = d.data();
      final ts = data['date'];
      final dt = ts is Timestamp ? ts.toDate() : null;
      final type = (data['type'] ?? '').toString().toLowerCase();
      final isIncome = type == 'income';
      final isTransfer = type == 'transfer';
      final amount =
          (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
      final category = (data['category'] ?? 'Uncategorized').toString();
      final note = (data['note'] ?? data['description'] ?? '').toString();
      final payee = (data['payee'] ?? 'Unknown').toString();

      // Track notes and payees
      if (note.isNotEmpty) {
        noteFrequency[note] = (noteFrequency[note] ?? 0) + 1;
        noteAmounts[note] = (noteAmounts[note] ?? 0) + amount * userRate;
      }
      if (payee.isNotEmpty && payee != 'Unknown') {
        payeeFrequency[payee] = (payeeFrequency[payee] ?? 0) + 1;
        payeeAmounts[payee] = (payeeAmounts[payee] ?? 0) + amount * userRate;
      }

      // Update totals with conversion
      if (isIncome) {
        totalIncome += amount * userRate;
      } else {
        totalExpense += amount * userRate;
      }
      if (dt != null) {
        final dtLocal = dt.toLocal();
        final monthKey = dtLocal.year * 100 + dtLocal.month;

        // Track monthly totals and counts with conversion
        monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0) +
            (isIncome ? amount * userRate : -amount * userRate);

        // Track income and expenses separately
        if (isIncome) {
          monthlyIncome[monthKey] =
              (monthlyIncome[monthKey] ?? 0) + amount * userRate;
        } else if (!isTransfer) {
          monthlyExpenses[monthKey] =
              (monthlyExpenses[monthKey] ?? 0) + amount * userRate;
        }

        monthlyTransactionCounts[monthKey] =
            (monthlyTransactionCounts[monthKey] ?? 0) + 1;

        // Track day of week data (1=Monday, 7=Sunday) with conversion
        final dayOfWeek = dt.weekday;
        dayOfWeekCounts[dayOfWeek] = (dayOfWeekCounts[dayOfWeek] ?? 0) + 1;
        dayOfWeekTotals[dayOfWeek] = (dayOfWeekTotals[dayOfWeek] ?? 0) +
            (isIncome ? amount * userRate : -amount * userRate);

        // Track largest expense with conversion
        if (type == 'expense' && amount * userRate > largestExpense) {
          largestExpense = amount * userRate;
          largestExpenseCategory = category;
        }
      }

      // Add row with color coding based on type to Transactions sheet
      final rowIndex = transactionsSheet.rows.length;
      transactionsSheet.appendRow([
        xls.TextCellValue(dt != null ? dateFormat.format(dt.toLocal()) : ''),
        xls.TextCellValue(type),
        xls.TextCellValue(category),
        xls.TextCellValue(formatToTwoDecimals(amount)),
        xls.TextCellValue(note),
        xls.TextCellValue(payee),
        xls.TextCellValue((data['transactionId'] ?? '').toString()),
      ]);

      // Apply row styling based on transaction type
      final style = isIncome
          ? incomeStyle
          : isTransfer
              ? transferStyle
              : expenseStyle;

      // Apply style to each cell in the row
      final rowNum = rowIndex + 1; // Convert to 1-based index for Excel

      // Apply base style to all cells in Transactions sheet
      transactionsSheet
          .cell(xls.CellIndex.indexByString('A$rowNum'))
          .cellStyle = style;
      transactionsSheet
          .cell(xls.CellIndex.indexByString('B$rowNum'))
          .cellStyle = style;
      transactionsSheet
          .cell(xls.CellIndex.indexByString('C$rowNum'))
          .cellStyle = style;

      // Special styling for amount (column D) based on transaction type
      if (isIncome) {
        transactionsSheet
            .cell(xls.CellIndex.indexByString('D$rowNum'))
            .cellStyle = xls.CellStyle(
          fontColorHex:
              xls.ExcelColor.fromHexString(_greenTextColor), // Green-600
          bold: true,
          numberFormat: xls.NumFormat.standard_2, // 2 decimal places in Excel
        );
      } else if (isTransfer) {
        transactionsSheet
            .cell(xls.CellIndex.indexByString('D$rowNum'))
            .cellStyle = xls.CellStyle(
          fontColorHex:
              xls.ExcelColor.fromHexString(_indigoTextColor), // Blue-600
          bold: true,
          numberFormat: xls.NumFormat.standard_2, // 2 decimal places in Excel
        );
      } else {
        transactionsSheet
            .cell(xls.CellIndex.indexByString('D$rowNum'))
            .cellStyle = xls.CellStyle(
          fontColorHex: xls.ExcelColor.fromHexString(_redTextColor), // Red-600
          bold: true,
          numberFormat: xls.NumFormat.standard_2, // 2 decimal places in Excel
        );
      }

      transactionsSheet
          .cell(xls.CellIndex.indexByString('E$rowNum'))
          .cellStyle = style;
      transactionsSheet
          .cell(xls.CellIndex.indexByString('F$rowNum'))
          .cellStyle = style;
      transactionsSheet
          .cell(xls.CellIndex.indexByString('G$rowNum'))
          .cellStyle = style;
    }

    // Simplified approach - skip detailed category breakdown for cleaner look

    // Add Clean Monthly Overview
    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing
    summarySheet.appendRow([xls.TextCellValue('Monthly Overview')]);
    summarySheet.merge(
        xls.CellIndex.indexByString('A${summarySheet.rows.length}'),
        xls.CellIndex.indexByString('D${summarySheet.rows.length}'));
    summarySheet
        .cell(xls.CellIndex.indexByString('A${summarySheet.rows.length}'))
        .cellStyle = xls.CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: xls.ExcelColor.fromHexString(_titleTextColor),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing

    // Simplified monthly headers
    final monthlyHeaders = [
      xls.TextCellValue('Month'),
      xls.TextCellValue('Income'),
      xls.TextCellValue('Expenses'),
      xls.TextCellValue('Balance')
    ];
    summarySheet.appendRow(monthlyHeaders);
    final monthlyHeaderRow = summarySheet.rows.length;
    for (var i = 0; i < monthlyHeaders.length; i++) {
      summarySheet
          .cell(xls.CellIndex.indexByString(
              '${String.fromCharCode(65 + i)}$monthlyHeaderRow'))
          .cellStyle = headerStyle;
    }

    // Add clean monthly data (show only last 6 months for elegance)
    final sortedMonths = monthlyIncome.keys.toList()
      ..addAll(monthlyExpenses.keys)
      ..sort();
    final uniqueMonths = sortedMonths.toSet().toList()..sort();

    // Take only last 6 months for cleaner view
    final recentMonths = uniqueMonths.length > 6
        ? uniqueMonths.sublist(uniqueMonths.length - 6)
        : uniqueMonths;

    for (final monthKey in recentMonths) {
      final year = monthKey ~/ 100;
      final month = monthKey % 100;
      final monthName =
          intl.DateFormat('MMM yyyy').format(DateTime(year, month));

      final income = monthlyIncome[monthKey] ?? 0;
      final expenses = monthlyExpenses[monthKey] ?? 0;
      final balance = income - expenses;

      summarySheet.appendRow([
        xls.TextCellValue(monthName),
        xls.TextCellValue(formatToTwoDecimals(income)),
        xls.TextCellValue(formatToTwoDecimals(expenses)),
        xls.TextCellValue(formatToTwoDecimals(balance)),
      ]);
    }

    // Apply clean alignment to monthly data
    final monthlyDataRows = recentMonths.length;
    final monthlyDataStartRow = summarySheet.rows.length - monthlyDataRows;
    for (var row = monthlyDataStartRow; row < summarySheet.rows.length; row++) {
      // Income (column B)
      summarySheet.cell(xls.CellIndex.indexByString('B${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
      // Expenses (column C)
      summarySheet.cell(xls.CellIndex.indexByString('C${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
      // Balance (column D)
      summarySheet.cell(xls.CellIndex.indexByString('D${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
    }

    // Calculate net savings and savings rate early
    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100) : 0;

    // Skip cash flow section for cleaner, more elegant design

    // Add Simple Financial Insights
    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing
    summarySheet.appendRow([xls.TextCellValue('Financial Insights')]);
    summarySheet.merge(
        xls.CellIndex.indexByString('A${summarySheet.rows.length}'),
        xls.CellIndex.indexByString('C${summarySheet.rows.length}'));
    summarySheet
        .cell(xls.CellIndex.indexByString('A${summarySheet.rows.length}'))
        .cellStyle = xls.CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: xls.ExcelColor.fromHexString(_titleTextColor),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing

    // Simple insights headers
    final insightsHeaders = [
      xls.TextCellValue('Metric'),
      xls.TextCellValue('Current'),
      xls.TextCellValue('Monthly Average')
    ];
    summarySheet.appendRow(insightsHeaders);
    final insightsHeaderRow = summarySheet.rows.length;
    for (var i = 0; i < insightsHeaders.length; i++) {
      summarySheet
          .cell(xls.CellIndex.indexByString(
              '${String.fromCharCode(65 + i)}$insightsHeaderRow'))
          .cellStyle = headerStyle;
    }

    // Calculate forecasting data
    final monthCount = uniqueMonths.isNotEmpty ? uniqueMonths.length : 1;
    final avgMonthlyIncome = totalIncome / monthCount;
    final avgMonthlyExpense = totalExpense / monthCount;
    final avgMonthlySavings = avgMonthlyIncome - avgMonthlyExpense;

    // Add simple insights data
    summarySheet.appendRow([
      xls.TextCellValue('Total Income'),
      xls.TextCellValue(formatToTwoDecimals(totalIncome)),
      xls.TextCellValue(formatToTwoDecimals(avgMonthlyIncome)),
    ]);
    summarySheet.appendRow([
      xls.TextCellValue('Total Expenses'),
      xls.TextCellValue(formatToTwoDecimals(totalExpense)),
      xls.TextCellValue(formatToTwoDecimals(avgMonthlyExpense)),
    ]);
    summarySheet.appendRow([
      xls.TextCellValue('Net Savings'),
      xls.TextCellValue(formatToTwoDecimals(netSavings)),
      xls.TextCellValue(formatToTwoDecimals(avgMonthlySavings)),
    ]);
    summarySheet.appendRow([
      xls.TextCellValue('Savings Rate'),
      xls.TextCellValue('${savingsRate.toStringAsFixed(1)}%'),
      xls.TextCellValue('${savingsRate.toStringAsFixed(1)}%'),
    ]);

    // Apply clean alignment to insights data
    final insightsDataStartRow = summarySheet.rows.length - 4;
    for (var row = insightsDataStartRow;
        row < summarySheet.rows.length;
        row++) {
      summarySheet.cell(xls.CellIndex.indexByString('B${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
      summarySheet.cell(xls.CellIndex.indexByString('C${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
    }

    // Add Executive Summary Section
    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing
    summarySheet.appendRow([xls.TextCellValue('Executive Summary')]);
    summarySheet.merge(
        xls.CellIndex.indexByString('A${summarySheet.rows.length}'),
        xls.CellIndex.indexByString('E${summarySheet.rows.length}'));
    summarySheet
        .cell(xls.CellIndex.indexByString('A${summarySheet.rows.length}'))
        .cellStyle = xls.CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: xls.ExcelColor.fromHexString(_titleTextColor),
      backgroundColorHex: xls.ExcelColor.fromHexString(_titleBackgroundColor),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing

    // Calculate financial health score
    final healthScore = _calculateHealthScore(
        totalIncome, totalExpense, savingsRate.toDouble());
    final healthDescription = _getHealthScoreDescription(healthScore);

    // Calculate monthly change
    final monthlyChange = _calculateMonthlyChange(monthlyExpenses);
    final changePercent = monthlyChange['changePercent'] ?? 0;
    final trend = monthlyChange['trend'] ?? 'Stable';
    final changeEmoji = changePercent > 5
        ? '📈'
        : changePercent < -5
            ? '📉'
            : '➡️';

    // Add simple executive insights
    summarySheet.appendRow([
      xls.TextCellValue('• Financial Health Score'),
      xls.TextCellValue('${healthScore.toStringAsFixed(0)}/100'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(healthDescription)
    ]);

    summarySheet.appendRow([
      xls.TextCellValue('• Monthly Change'),
      xls.TextCellValue('${changePercent.toStringAsFixed(1)}%'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue('$trend $changeEmoji')
    ]);

    summarySheet.appendRow([
      xls.TextCellValue('• Total Transactions'),
      xls.TextCellValue('${docs.length}'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(
          (totalIncome - totalExpense) >= 0 ? '✓ Healthy' : '⚠ Review Needed')
    ]);

    summarySheet.appendRow([
      xls.TextCellValue('• Key Insight'),
      xls.TextCellValue((totalIncome - totalExpense) >= 0
          ? 'Positive cash flow maintained'
          : 'Expenses exceed income'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue((totalIncome - totalExpense) >= 0 ? '👍' : '📊')
    ]);

    summarySheet.appendRow([xls.TextCellValue('')]); // Spacing

    // Format KPI values with consistent currency formatting and growth indicators
    final kpiValues = [
      '${formatNumber(totalIncome)} ${totalIncome >= 0 ? '↑' : '↓'}',
      '${formatNumber(totalExpense)} ${totalExpense >= 0 ? '↑' : '↓'}',
      '${formatNumber(netSavings)} ${netSavings >= 0 ? '↑' : '↓'}',
      '${savingsRate.toStringAsFixed(1)}%',
      largestExpense > 0
          ? '${formatNumber(largestExpense)} ($largestExpenseCategory)'
          : 'N/A'
    ];

    // Update KPI values in the sheet
    for (var i = 0; i < kpiValues.length; i++) {
      final cell = summarySheet.cell(xls.CellIndex.indexByString(
          '${String.fromCharCode(65 + i)}${kpiHeaderRow + 1}'));
      cell.value = xls.TextCellValue(kpiValues[i]);

      // Apply conditional formatting for Total Income (green if positive, red if negative)
      if (i == 0) {
        // Total Income column
        cell.cellStyle = xls.CellStyle(
          bold: true,
          fontSize: 18, // Larger font for main KPIs
          horizontalAlign: xls.HorizontalAlign.Right,
          numberFormat: xls.NumFormat.standard_2,
          fontColorHex: xls.ExcelColor.fromHexString(
              totalIncome >= 0 ? _greenTextColor : _redTextColor),
        );
      }
      // Apply conditional formatting for Total Expenses (red if positive, green if negative)
      else if (i == 1) {
        // Total Expenses column
        cell.cellStyle = xls.CellStyle(
          bold: true,
          fontSize: 18, // Larger font for main KPIs
          horizontalAlign: xls.HorizontalAlign.Right,
          numberFormat: xls.NumFormat.standard_2,
          fontColorHex: xls.ExcelColor.fromHexString(
              totalExpense >= 0 ? _redTextColor : _greenTextColor),
        );
      }
      // Apply conditional formatting for Net Savings (red if negative, green if positive)
      else if (i == 2) {
        // Net Savings column
        cell.cellStyle = xls.CellStyle(
          bold: true,
          fontSize: 18, // Larger font for main KPIs
          horizontalAlign: xls.HorizontalAlign.Right,
          numberFormat: xls.NumFormat.standard_2,
          fontColorHex: xls.ExcelColor.fromHexString(
              netSavings >= 0 ? _greenTextColor : _redTextColor),
        );
      } else if (i == 3) {
        // Savings Rate column
        cell.cellStyle = xls.CellStyle(
          bold: true,
          fontSize: 16, // Larger font for better visibility
          horizontalAlign: xls.HorizontalAlign.Right,
          fontColorHex: xls.ExcelColor.fromHexString(
              _greenTextColor), // Emerald-500 for positive metrics
        );
      } else {
        cell.cellStyle = xls.CellStyle(
          bold: true,
          fontSize: i <= 2 ? 20 : 16, // Even larger font for main KPIs
          horizontalAlign: xls.HorizontalAlign.Right,
          numberFormat: xls.NumFormat.standard_2,
        );
      }
    }

    // Add Notes Summary Section
    summarySheet.appendRow([xls.TextCellValue('')]); // Empty row for spacing
    summarySheet.appendRow([xls.TextCellValue('TOP NOTES SUMMARY')]);
    summarySheet.merge(
        xls.CellIndex.indexByString('A${summarySheet.rows.length}'),
        xls.CellIndex.indexByString('E${summarySheet.rows.length}'));
    summarySheet
        .cell(xls.CellIndex.indexByString('A${summarySheet.rows.length}'))
        .cellStyle = xls.CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: xls.ExcelColor.fromHexString(_titleTextColor),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    // Add notes headers
    final notesHeaders = [
      xls.TextCellValue('Note'),
      xls.TextCellValue('Frequency'),
      xls.TextCellValue('Total Amount'),
      xls.TextCellValue('Average Amount'),
    ];
    summarySheet.appendRow(notesHeaders);
    final notesHeaderRow = summarySheet.rows.length;
    for (var i = 0; i < notesHeaders.length; i++) {
      summarySheet
          .cell(xls.CellIndex.indexByString(
              '${String.fromCharCode(65 + i)}$notesHeaderRow'))
          .cellStyle = headerStyle;
    }

    // Add notes data (sorted by amount descending)
    final sortedNotes = noteAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i < sortedNotes.length && i < 5; i++) {
      final entry = sortedNotes[i];
      final frequency = noteFrequency[entry.key] ?? 0;
      final average = entry.value / frequency;

      summarySheet.appendRow([
        xls.TextCellValue(entry.key.length > 50
            ? '${entry.key.substring(0, 47)}...'
            : entry.key),
        xls.TextCellValue(frequency.toString()),
        xls.TextCellValue(formatToTwoDecimals(entry.value)),
        xls.TextCellValue(formatToTwoDecimals(average)),
      ]);
    }

    // Apply right alignment to numeric columns in notes data
    final notesDataRows = sortedNotes.length > 5 ? 5 : sortedNotes.length;
    final notesDataStartRow = summarySheet.rows.length - notesDataRows;
    for (var row = notesDataStartRow; row < summarySheet.rows.length; row++) {
      // Apply right alignment to all numeric columns
      summarySheet.cell(xls.CellIndex.indexByString('B${row + 1}')).cellStyle =
          xls.CellStyle(horizontalAlign: xls.HorizontalAlign.Right);
      summarySheet.cell(xls.CellIndex.indexByString('C${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
      summarySheet.cell(xls.CellIndex.indexByString('D${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
    }

    // Add Payees Summary Section
    summarySheet.appendRow([xls.TextCellValue('')]); // Empty row for spacing
    summarySheet.appendRow([xls.TextCellValue('TOP PAYEES SUMMARY')]);
    summarySheet.merge(
        xls.CellIndex.indexByString('A${summarySheet.rows.length}'),
        xls.CellIndex.indexByString('E${summarySheet.rows.length}'));
    summarySheet
        .cell(xls.CellIndex.indexByString('A${summarySheet.rows.length}'))
        .cellStyle = xls.CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: xls.ExcelColor.fromHexString(_titleTextColor),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    // Add payees headers
    final payeesHeaders = [
      xls.TextCellValue('Payee'),
      xls.TextCellValue('Transaction Count'),
      xls.TextCellValue('Total Amount'),
      xls.TextCellValue('Average Amount'),
    ];
    summarySheet.appendRow(payeesHeaders);
    final payeesHeaderRow = summarySheet.rows.length;
    for (var i = 0; i < payeesHeaders.length; i++) {
      summarySheet
          .cell(xls.CellIndex.indexByString(
              '${String.fromCharCode(65 + i)}$payeesHeaderRow'))
          .cellStyle = headerStyle;
    }

    // Add payees data (sorted by amount descending)
    final sortedPayees = payeeAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i < sortedPayees.length && i < 5; i++) {
      final entry = sortedPayees[i];
      final frequency = payeeFrequency[entry.key] ?? 0;
      final average = entry.value / frequency;

      summarySheet.appendRow([
        xls.TextCellValue(entry.key),
        xls.TextCellValue(frequency.toString()),
        xls.TextCellValue(formatToTwoDecimals(entry.value)),
        xls.TextCellValue(formatToTwoDecimals(average)),
      ]);
    }

    // Apply right alignment to numeric columns in payees data
    final payeesDataRows = sortedPayees.length > 5 ? 5 : sortedPayees.length;
    final payeesDataStartRow = summarySheet.rows.length - payeesDataRows;
    for (var row = payeesDataStartRow; row < summarySheet.rows.length; row++) {
      // Apply right alignment to all numeric columns
      summarySheet.cell(xls.CellIndex.indexByString('B${row + 1}')).cellStyle =
          xls.CellStyle(horizontalAlign: xls.HorizontalAlign.Right);
      summarySheet.cell(xls.CellIndex.indexByString('C${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
      summarySheet.cell(xls.CellIndex.indexByString('D${row + 1}')).cellStyle =
          xls.CellStyle(
              horizontalAlign: xls.HorizontalAlign.Right,
              numberFormat: xls.NumFormat.standard_2);
    }

    // Encode Excel data
    _logger.fine('Encoding Excel data...');
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel data');
    }

    // Remove the Summary sheet if it exists (cleanup)
    if (excel.tables.keys.contains('Summary')) {
      excel.delete('Summary');
    }

    // Handle web vs mobile export
    await _handleFileExport(context, bytes, excel);
  }

  Future<void> _handleFileExport(
      BuildContext context, List<int> bytes, xls.Excel excel) async {
    if (kIsWeb) {
      try {
        // For web, create a download link
        final blob = html.Blob([
          bytes
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final timestamp =
            intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'expense_export_$timestamp.xlsx';

        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true)
              .pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Export started, check your downloads')),
          );
        }
      } catch (e, st) {
        _logger.severe('Web export error', e, st);
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true)
              .pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('❌ Failed to start download. Please try again.')),
          );
        }
      }
    } else {
      // For mobile/desktop, use file system
      try {
        _logger.fine('Getting temporary directory...');
        final tempDir = await getTemporaryDirectory();
        final timestamp =
            intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'expense_export_$timestamp.xlsx';
        final filePath = '${tempDir.path}/$fileName';

        _logger.info('Saving file to: $filePath');
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        _logger.fine('Opening file...');
        final result = await OpenFilex.open(filePath);
        _logger.info('File open result: ${result.message}');

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true)
              .pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Exported $fileName')),
          );
        }
      } catch (e, stackTrace) {
        _logger.severe('Error during export', e, stackTrace);
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true)
              .pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Export failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> showCustomDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
    );
    if (picked != null) {
      _customDateRange = picked;
    }
  }

  // Check premium status from Firestore with detailed logging
  Future<bool> _isUserPremium(String uid) async {
    try {
      _logger.fine('Checking premium status for user: $uid');

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(GetOptions(source: Source.server)); // Force server fetch

      if (!snap.exists) {
        _logger.warning('User document does not exist');
        return false;
      }

      final data = snap.data()!;
      _logger.finer('User data: ${data.toString()}');

      // Check premium status
      final isPremium = data['isPremium'] == true;
      final premiumFeatures = data['premiumFeatures'] is Map
          ? Map<String, dynamic>.from(data['premiumFeatures'] as Map)
          : null;
      final hasExportAccess =
          premiumFeatures != null && premiumFeatures['exportToExcel'] == true;

      _logger.fine(
          'Premium status: isPremium=$isPremium, exportToExcel=$hasExportAccess');

      // Check subscription expiry if it exists
      final sub = data['subscription'] is Map
          ? Map<String, dynamic>.from(data['subscription'] as Map)
          : null;
      if (sub != null) {
        _logger.finer(
            'Subscription: provider=${sub['provider']}, original=${sub['originalPurchaseDate']}, expires=${sub['expiresDate']}');

        if (sub['expiresDate'] is Timestamp) {
          final expiresAt = (sub['expiresDate'] as Timestamp).toDate();
          final isExpired = expiresAt.isBefore(DateTime.now());
          _logger.fine('Subscription expired: $isExpired');
          if (isExpired) return false;
        }
      }

      final hasAccess = isPremium || hasExportAccess;
      _logger.info('Final premium access: $hasAccess');
      return hasAccess;
    } catch (e, stackTrace) {
      _logger.severe('Premium check failed', e, stackTrace);
      return false;
    }
  }

  void _showUpgradePrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Premium Feature',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Export to Excel is available for premium users. Upgrade to unlock professional exports and more.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Maybe Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Navigate to upgrade screen when implemented
                    },
                    icon: const Icon(Icons.star_rate_rounded),
                    label: const Text('Upgrade'),
                  ),
                ),
              ])
            ],
          ),
        );
      },
    );
  }
}
