import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/services/settings_service.dart';
import 'package:arthaksh/services/currency_service.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  // null = no filter, 'income' | 'expense' | 'net'
  final ValueNotifier<String?> _filterVN = ValueNotifier<String?>(null);
  // Time filter: 'month' | '7days' | 'lastmonth' | 'custom'
  String _timeFilter = 'month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final initialRange = _customStartDate != null && _customEndDate != null
        ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
        : DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now.add(const Duration(days: 30)),
      initialDateRange: initialRange,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).scaffoldBackgroundColor,
              onSurface:
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _timeFilter = 'custom';
      });
    }
  }

  // Currency state for conversion
  String _currentCurrency = 'USD'; // Will be updated from settings

  @override
  void initState() {
    super.initState();
    _loadCurrencyAndRates();
  }

  Future<void> _loadCurrencyAndRates() async {
    final currency = await SettingsService.getSelectedCurrency();
    setState(() {
      _currentCurrency = currency;
    });

    // Ensure currency cache is initialized for conversions
    await CurrencyService.ensureCacheInitialized();

    // No need to manually fetch rates - CurrencyService handles this
  }

  // Convert amount from original currency to current currency
  double _convertAmount(double amount, String originalCurrency) {
    if (originalCurrency == _currentCurrency) return amount;

    // Use CurrencyService for synchronous conversion
    return CurrencyService.convertAmountSync(
        amount, originalCurrency, _currentCurrency);
  }

  @override
  void dispose() {
    _filterVN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Balance Sheet')),
        body: const Center(child: Text('Please log in to view summary.')),
      );
    }

    // Compute start and end dates based on dropdown selection
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;
    switch (_timeFilter) {
      case '7days':
        startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 7));
        endDate =
            DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        break;
      case 'lastmonth':
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        startDate = DateTime(prevYear, prevMonth, 1);
        endDate = DateTime(now.year, now.month, 1);
        break;
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          startDate = _customStartDate!;
          endDate = _customEndDate!;
        } else {
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1);
        }
        break;
      case 'month':
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
    }

    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            isLessThan: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );

    final dateFmt = DateFormat.yMMMd();

    Widget metricCard({
      required String label,
      required String value,
      required Color color,
      required VoidCallback onTap,
      bool selected = false,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(10), // Reduced from 12 proportionally
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12), // Reduced from 16,14 proportionally
          decoration: BoxDecoration(
            color: selected
                ? color.withAlpha((0.1 * 255).round())
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(10), // Reduced from 12 proportionally
            border: Border.all(
              color: selected
                  ? color.withAlpha((0.4 * 255).round())
                  : theme.colorScheme.outlineVariant,
              width: 1.0, // Reduced from 1.2 proportionally
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 4, // Reduced from 6 proportionally
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant
                      .withAlpha((0.8 * 255).round()),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                  fontSize: 9, // Reduced from 10 proportionally
                ),
              ),
              const SizedBox(height: 3), // Reduced from 4 proportionally
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        // Reduced from titleMedium
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 13, // Reduced from 15 proportionally
                        letterSpacing: -0.2,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10, // Reduced from 12 proportionally
                    color: theme.colorScheme.onSurfaceVariant
                        .withAlpha((0.5 * 255).round()),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Balance Sheet')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Failed to load summary.'));
          }

          final docs = snap.data?.docs ?? const [];

          // Aggregate totals by currency
          final Map<String, double> incomeByCurrency = {};
          final Map<String, double> expenseByCurrency = {};

          for (final d in docs) {
            final data = d.data();
            final amount = (data['amount'] is num)
                ? (data['amount'] as num).toDouble()
                : 0.0;
            final type = (data['type'] ?? '') as String;
            final currency = (data['currency'] ?? 'INR') as String;

            if (type.toLowerCase() == 'income') {
              incomeByCurrency[currency] =
                  (incomeByCurrency[currency] ?? 0) + amount;
            } else {
              expenseByCurrency[currency] =
                  (expenseByCurrency[currency] ?? 0) + amount;
            }
          }

          // For display purposes, we'll show totals in user's preferred currency
          // For now, let's just work with the first currency found or user's preferred currency
          if (incomeByCurrency.isNotEmpty) {
            // primaryCurrency = incomeByCurrency.keys.first;
          } else if (expenseByCurrency.isNotEmpty) {
            // primaryCurrency = expenseByCurrency.keys.first;
          }

          // Get user's preferred currency for display
          final userCurrency = _currentCurrency;
          final userCurrencySymbol =
              CurrencyService.getCurrencySymbol(userCurrency);
          final userCurrencyLocale =
              CurrencyService.getCurrencyLocale(userCurrency);

          final displayCurrency = NumberFormat.currency(
              symbol: userCurrencySymbol,
              locale: userCurrencyLocale,
              decimalDigits: 2);

          // Calculate totals in user's preferred currency
          double totalIncome = 0;
          double totalExpense = 0;

          for (final currency in incomeByCurrency.keys) {
            totalIncome +=
                _convertAmount(incomeByCurrency[currency] ?? 0, currency);
          }

          for (final currency in expenseByCurrency.keys) {
            totalExpense +=
                _convertAmount(expenseByCurrency[currency] ?? 0, currency);
          }

          final netWorth = totalIncome - totalExpense;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12), // Reduced from 16 proportionally
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period filter
                Row(
                  children: [
                    Text(
                      'Period',
                      style: theme.textTheme.labelSmall?.copyWith(
                        // Reduced from labelMedium
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12, // Reduced proportionally
                      ),
                    ),
                    const SizedBox(width: 10), // Reduced from 12 proportionally
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _timeFilter,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Select period',
                          prefixIcon: Icon(Icons.calendar_month_rounded),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8), // Reduced proportionally
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '7days',
                            child: Text('Last 7 days'),
                          ),
                          const DropdownMenuItem(
                            value: 'month',
                            child: Text('This month'),
                          ),
                          const DropdownMenuItem(
                            value: 'lastmonth',
                            child: Text('Last month'),
                          ),
                          const DropdownMenuItem(
                            value: 'custom',
                            child: Text('Custom range'),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == null) return;
                          if (val == 'custom') {
                            await _selectCustomDateRange();
                          } else {
                            setState(() => _timeFilter = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // Reduced from 12 proportionally

                // Date range display
                ValueListenableBuilder(
                  valueListenable: ValueNotifier(_timeFilter),
                  builder: (context, timeFilter, _) {
                    final dateFmt = DateFormat.MMMd();
                    String dateRangeText;

                    switch (_timeFilter) {
                      case '7days':
                        final now = DateTime.now();
                        final weekAgo = now.subtract(const Duration(days: 7));
                        dateRangeText =
                            '${dateFmt.format(weekAgo)} - ${dateFmt.format(now)}';
                        break;
                      case 'month':
                        final now = DateTime.now();
                        final monthStart = DateTime(now.year, now.month, 1);
                        final monthEnd = DateTime(now.year, now.month + 1, 1)
                            .subtract(const Duration(days: 1));
                        dateRangeText =
                            '${dateFmt.format(monthStart)} - ${dateFmt.format(monthEnd)}';
                        break;
                      case 'lastmonth':
                        final now = DateTime.now();
                        final lastMonthStart =
                            DateTime(now.year, now.month - 1, 1);
                        final lastMonthEnd = DateTime(now.year, now.month, 1)
                            .subtract(const Duration(days: 1));
                        dateRangeText =
                            '${dateFmt.format(lastMonthStart)} - ${dateFmt.format(lastMonthEnd)}';
                        break;
                      case 'custom':
                        if (_customStartDate != null &&
                            _customEndDate != null) {
                          dateRangeText =
                              '${dateFmt.format(_customStartDate!)} - ${dateFmt.format(_customEndDate!)}';
                        } else {
                          dateRangeText = 'Select custom range';
                        }
                        break;
                      default:
                        dateRangeText = '';
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: theme.brightness == Brightness.dark
                            ? cs.surfaceContainer.withValues(alpha: 0.8)
                            : cs.primaryContainer.withValues(alpha: 0.1),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? cs.outline.withValues(alpha: 0.3)
                              : cs.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        dateRangeText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? cs.onSurface.withValues(alpha: 0.9)
                              : cs.onSurface.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8), // Reduced from 12 proportionally

                // Top metrics
                ValueListenableBuilder<String?>(
                  valueListenable: _filterVN,
                  builder: (context, filter, _) {
                    return Row(
                      children: [
                        Expanded(
                          child: metricCard(
                            label: 'Assets',
                            value: displayCurrency.format(totalIncome),
                            color: Colors.green,
                            selected: filter == 'income',
                            onTap: () => _filterVN.value =
                                filter == 'income' ? null : 'income',
                          ),
                        ),
                        const SizedBox(
                            width: 10), // Reduced from 12 proportionally
                        Expanded(
                          child: metricCard(
                            label: 'Liabilities',
                            value: displayCurrency.format(totalExpense),
                            color: cs.error,
                            selected: filter == 'expense',
                            onTap: () => _filterVN.value =
                                filter == 'expense' ? null : 'expense',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10), // Reduced from 12 proportionally
                ValueListenableBuilder<String?>(
                  valueListenable: _filterVN,
                  builder: (context, filter, _) {
                    final color = netWorth >= 0 ? cs.primary : cs.error;
                    return metricCard(
                      label: 'Net Worth',
                      value: displayCurrency.format(netWorth),
                      color: color,
                      selected: filter == 'net',
                      onTap: () =>
                          _filterVN.value = filter == 'net' ? null : 'net',
                    );
                  },
                ),
                const SizedBox(height: 12), // Reduced from 16 proportionally

                // Legend
                Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.green,
                      size: 16, // Reduced from 18 proportionally
                    ),
                    const SizedBox(width: 4), // Reduced from 6 proportionally
                    Text('Income',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 11)), // Reduced proportionally
                    const SizedBox(width: 12), // Reduced from 14 proportionally
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: cs.error,
                      size: 16, // Reduced from 18 proportionally
                    ),
                    const SizedBox(width: 4), // Reduced from 6 proportionally
                    Text('Expense',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 11)), // Reduced proportionally
                  ],
                ),
                const SizedBox(height: 6), // Reduced from 8 proportionally

                // Transactions list (filtered by KPI selection)
                ValueListenableBuilder<String?>(
                  valueListenable: _filterVN,
                  builder: (context, filter, _) {
                    final filtered = docs.where((doc) {
                      final data = doc.data();
                      final type = (data['type'] ?? '') as String;
                      if (filter == 'income') {
                        return type.toLowerCase() == 'income';
                      }
                      if (filter == 'expense') {
                        return type.toLowerCase() != 'income';
                      }
                      // For 'net' and null, show all
                      return true;
                    }).toList();

                    return Container(
                      decoration: BoxDecoration(
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                            10), // Reduced from 14 proportionally
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(
                            10), // Reduced from 12 proportionally
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(
                            height: 6), // Reduced from 8 proportionally
                        itemBuilder: (context, i) {
                          final data = filtered[i].data();
                          final amount = (data['amount'] is num)
                              ? (data['amount'] as num).toDouble()
                              : 0.0;
                          final payee = ((data['payeeItem'] ??
                                  data['payee'] ??
                                  '') as String)
                              .trim();
                          final category = (data['category'] ?? '') as String;
                          final type = (data['type'] ?? '') as String;
                          final transactionCurrency =
                              (data['currency'] ?? 'INR') as String;
                          final ts = data['date'];
                          DateTime? date;
                          if (ts is Timestamp) date = ts.toDate();

                          final convertedAmount =
                              _convertAmount(amount, transactionCurrency);

                          final transactionCurrencySymbol =
                              CurrencyService.getCurrencySymbol(
                                  _currentCurrency);
                          final transactionCurrencyLocale =
                              CurrencyService.getCurrencyLocale(
                                  _currentCurrency);
                          final transactionFormatter = NumberFormat.currency(
                              symbol: transactionCurrencySymbol,
                              locale: transactionCurrencyLocale,
                              decimalDigits: 2);

                          final isIncome = type.toLowerCase() == 'income';
                          final isTransfer = type.toLowerCase() == 'transfer';
                          final color = isTransfer
                              ? Colors.blue.shade700
                              : isIncome
                                  ? Colors.green
                                  : cs.error;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical:
                                    8), // Reduced from 12,10 proportionally
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(
                                  10), // Reduced from 12 proportionally
                              border: Border.all(
                                  color: cs.outlineVariant
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16, // Reduced proportionally
                                  backgroundColor:
                                      color.withValues(alpha: 0.15),
                                  child: Icon(
                                    isIncome
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    color: color,
                                    size: 14, // Reduced proportionally
                                  ),
                                ),
                                const SizedBox(
                                    width:
                                        10), // Reduced from 12 proportionally
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          payee.isNotEmpty
                                              ? payee
                                              : '(No payee)',
                                          style: theme.textTheme
                                              .bodySmall // Reduced from bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize:
                                                12, // Reduced proportionally
                                          )),
                                      const SizedBox(height: 2),
                                      Text(
                                          [
                                            if (category.isNotEmpty) category,
                                            if (date != null)
                                              dateFmt.format(date),
                                          ].join(' · '),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: cs.onSurface
                                                .withValues(alpha: 0.75),
                                            fontSize:
                                                10, // Reduced proportionally
                                          )),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                    width: 8), // Reduced from 10 proportionally
                                Text(
                                  transactionFormatter.format(convertedAmount),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    // Reduced from bodyMedium
                                    fontWeight: FontWeight.w900,
                                    color: color,
                                    fontSize: 12, // Reduced proportionally
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
