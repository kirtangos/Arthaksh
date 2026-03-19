import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/services/currency_service.dart';
import 'package:arthaksh/widgets/premium_upsell_dialog.dart';
import 'modern_insights/spending_trends.dart';
import 'modern_insights/spending_analytics.dart';
import 'modern_insights/cash_flow_analysis.dart';

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

class ModernInsightsScreen extends StatefulWidget {
  const ModernInsightsScreen({super.key});

  @override
  State<ModernInsightsScreen> createState() => _ModernInsightsScreenState();
}

class _ModernInsightsScreenState extends State<ModernInsightsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Premium access state
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;

  // Data states
  List<Transaction> _transactions = [];
  List<Transaction> _allTransactions =
      []; // All transactions for cash flow analysis

  // UI states
  bool _isLoading = true;
  String _error = '';
  String _currentCurrency = 'INR';
  TransactionType? _selectedType =
      TransactionType.expense; // Default to expense

  // Date range for filtering
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  String _selectedDateRange = 'Last 7 Days';
  final Map<String, Duration> _dateRangeOptions = {
    'Last 7 Days': const Duration(days: 7),
    'Last 30 Days': const Duration(days: 30),
    'Last 3 Months': const Duration(days: 90),
    'Last 6 Months': const Duration(days: 180),
    'This Year': Duration(
        days: DateTime.now()
            .difference(DateTime(DateTime.now().year, 1, 1))
            .inDays),
  };

  @override
  void initState() {
    super.initState();
    _initializeCurrency().then((_) {
      _checkPremiumAccess().then((_) {
        if (_hasPremiumAccess) {
          _loadData();
        }
      });
    });

    // Listen for currency preference changes
    // Note: If you implement a currency preference stream in CurrencyService,
    // you can uncomment and use this code
    /*
    CurrencyService.currencyStream?.listen((newCurrency) {
      if (newCurrency != _currentCurrency) {
        _initializeCurrency();
      }
    });
    */
  }

  Future<void> _initializeCurrency() async {
    try {
      // Ensure currency cache is initialized for insights
      await CurrencyService.ensureCacheInitialized();

      // Default values
      String currency = 'INR'; // Default currency

      // Get user's preferred currency
      try {
        currency = await CurrencyService.getCurrency();
        // Note: If you need exchange rates, you'll need to implement that in CurrencyService
      } catch (e) {
        debugPrint('Error getting currency settings: $e');
      }

      if (mounted) {
        setState(() {
          _currentCurrency = currency;
        });
      }
    } catch (e) {
      debugPrint('Error initializing currency: $e');
    }
  }

  // Convert amount from original currency to current currency using CurrencyService
  double _convertAmount(double amount, String originalCurrency) {
    try {
      // Ensure amount is a valid number
      if (amount.isNaN || amount.isInfinite) {
        debugPrint('Invalid amount: $amount');
        return 0.0;
      }

      debugPrint(
          'CurrencyService.convertAmountSync: $amount $originalCurrency -> $_currentCurrency');
      // Delegate to CurrencyService which uses Frankfurter API + cache
      final converted = CurrencyService.convertAmountSync(
        amount,
        originalCurrency,
        _currentCurrency,
      );
      debugPrint('CurrencyService result: $converted');
      return converted;
    } catch (e) {
      debugPrint('Error in _convertAmount with CurrencyService: $e');
      // Fallback to original amount on error
      return amount;
    }
  }

  Future<void> _showInsightsPremiumPullup() async {
    await PremiumUpsellDialog.show(
      context,
      featureName: 'Insights',
      description:
          'Insights is available for premium users. Upgrade to unlock advanced analytics, trends, personalized tips, and more.',
      onUpgrade: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening Premium...')),
        );
      },
      onLater: () {
        // Optionally handle later
      },
    );
  }

  Future<void> _checkPremiumAccess() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _hasPremiumAccess = false);
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        setState(() => _hasPremiumAccess = false);
        return;
      }

      final data = doc.data() ?? {};
      final isPremium = data['isPremium'] == true;
      final premiumFeatures = data['premiumFeatures'] is Map
          ? Map<String, dynamic>.from(data['premiumFeatures'] as Map)
          : null;

      setState(() {
        _hasPremiumAccess = isPremium || (premiumFeatures?['insights'] == true);
      });
    } catch (e) {
      debugPrint('Error checking premium access: $e');
      setState(() => _hasPremiumAccess = false);
    } finally {
      setState(() => _isCheckingPremium = false);
    }
  }

  Future<void> _loadAllTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Fetch all transactions without date filtering
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .get();

      if (snapshot.docs.isNotEmpty) {
        _allTransactions = snapshot.docs
            .map((doc) =>
                Transaction.fromMap(doc.data()..['id'] = doc.id, doc.id))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading all transactions: $e');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _error = 'User not authenticated');
        return;
      }

      // Clear existing data
      _transactions = [];
      _allTransactions = [];

      // Fetch expenses from Firestore
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange.start))
          .where('date',
              isLessThanOrEqualTo: Timestamp.fromDate(_dateRange.end))
          .get();

      if (snapshot.docs.isNotEmpty) {
        _transactions = snapshot.docs
            .map((doc) =>
                Transaction.fromMap(doc.data()..['id'] = doc.id, doc.id))
            .toList();

        // Make sure currency is initialized before processing data
        await _initializeCurrency();

        // Load all transactions for cash flow analysis
        await _loadAllTransactions();

        _processData();
      } else {
        // No data found for the selected range
        setState(() {
          _transactions = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading insights data: $e');
      setState(() => _error = 'Failed to load data. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processData() {
    if (_transactions.isEmpty) {
      return;
    }

    try {
      // Convert all amounts to the selected currency
      _transactions = _transactions.map((t) {
        try {
          debugPrint(
              'Converting transaction: ${t.id}, amount: ${t.amount}, from: ${t.currency} to: $_currentCurrency');
          final convertedAmount = _convertAmount(t.amount, t.currency);
          debugPrint('Converted to: $convertedAmount');
          return t.copyWith(
            amount: convertedAmount,
            currency: _currentCurrency,
          );
        } catch (e) {
          debugPrint('Error converting amount for transaction ${t.id}: $e');
          return t; // Return original transaction if conversion fails
        }
      }).toList();

      // Get filtered transactions - transactions are already filtered by type in the widgets

      // Calculate financial health score

      if (mounted) {
        setState(() {
          // State will be updated by the setState calls in the methods above
        });
      }
    } catch (e) {
      debugPrint('Error in _processData: $e');
      if (mounted) {
        setState(() {
          _error = 'Error processing data. Please try again.';
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    // Show a bottom sheet with quick select options
    final quickSelect = await showModalBottomSheet<DateTimeRange?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(12), // Reduced from 16 proportionally
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Date Range',
              style: TextStyle(
                fontSize: 16, // Reduced from 18 proportionally
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12), // Reduced from 16 proportionally
            // Quick select options
            Wrap(
              spacing: 6, // Reduced from 8 proportionally
              runSpacing: 6, // Reduced from 8 proportionally
              alignment: WrapAlignment.center,
              children: [
                _buildQuickSelectChipWithDuration(
                    'Last 7 Days', const Duration(days: 7)),
                _buildQuickSelectChipWithDuration(
                    'Last 30 Days', const Duration(days: 30)),
                _buildQuickSelectChipWithDuration(
                    'Last 3 Months', const Duration(days: 90)),
                _buildQuickSelectChip(
                  'This Year',
                  DateTime(DateTime.now().year, 1, 1),
                ),
              ],
            ),
            const SizedBox(height: 12), // Reduced from 16 proportionally
            // Custom date range button
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(
                  context, null), // Return null to indicate custom range
              icon: const Icon(Icons.calendar_today,
                  size: 18), // Reduced from 20 proportionally
              label: const Text('Select Custom Range',
                  style: TextStyle(fontSize: 13)), // Reduced proportionally
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    vertical: 10), // Reduced from 12 proportionally
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(6), // Reduced from 8 proportionally
                ),
              ),
            ),
            const SizedBox(height: 4), // Reduced from 6 proportionally
          ],
        ),
      ),
    );

    // If user selected a quick option, update the range
    if (quickSelect != null) {
      await _updateDateRange(quickSelect.start, quickSelect.end);
      return;
    }

    // Show the date range picker for custom range
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (context, child) {
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
      await _updateDateRange(picked.start, picked.end);
    }
  }

  Widget _buildQuickSelectChip(String label, DateTime startDate) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        Navigator.pop(
            context,
            DateTimeRange(
              start: startDate,
              end: DateTime.now(),
            ));
      },
      backgroundColor: Theme.of(context)
          .primaryColor
          .withValues(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.1),
      labelStyle: TextStyle(
        color: Theme.of(context).primaryColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildQuickSelectChipWithDuration(String label, Duration duration) {
    return _buildQuickSelectChip(
      label,
      DateTime.now().subtract(duration),
    );
  }

  Future<void> _updateDateRange(DateTime start, DateTime end) async {
    // Normalize dates to start and end of day for accurate comparison
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if this matches any of our predefined ranges
    String? matchedRange;

    for (var entry in _dateRangeOptions.entries) {
      final rangeStart = now.subtract(entry.value);
      final normalizedRangeStart =
          DateTime(rangeStart.year, rangeStart.month, rangeStart.day);

      if (normalizedStart.isAtSameMomentAs(normalizedRangeStart) &&
          normalizedEnd.isAtSameMomentAs(
              DateTime(today.year, today.month, today.day, 23, 59, 59))) {
        matchedRange = entry.key;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _dateRange = DateTimeRange(
          start: normalizedStart,
          end: normalizedEnd,
        );
        _selectedDateRange = matchedRange ??
            '${_formatDate(normalizedStart)} - ${_formatDate(normalizedEnd)}';
      });

      // Show loading indicator
      setState(() => _isLoading = true);

      try {
        await _loadData();
      } catch (e) {
        debugPrint('Error updating date range: $e');
        if (mounted) {
          setState(() {
            _error =
                'Failed to load data for selected range. Please try again.';
          });
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildPremiumUpsell() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInsightsPremiumPullup();
    });

    return Container(); // Return an empty container as we're showing a dialog
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPremium) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPremiumAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Insights & Analytics'),
          elevation: 0,
          centerTitle: true,
        ),
        body: _buildPremiumUpsell(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TransactionType?>(
                value: _selectedType,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                dropdownColor: Theme.of(context).cardColor,
                focusColor: Colors.transparent,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13, // Reduced from 14 proportionally
                    ),
                hint: Text(
                    _selectedType?.toString().split('.').last.toUpperCase() ??
                        'EXPENSE',
                    style: const TextStyle(
                        fontSize: 13)), // Reduced from 14 proportionally
                onChanged: (TransactionType? newValue) {
                  setState(() {
                    _selectedType = newValue;
                    _processData();
                  });
                },
                items: [
                  // Add all transaction types
                  ...TransactionType.values
                      .map<DropdownMenuItem<TransactionType?>>(
                          (TransactionType type) {
                    return DropdownMenuItem<TransactionType?>(
                      value: type,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6.0), // Reduced from 8 proportionally
                        child: Text(
                          type.toString().split('.').last.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 13), // Reduced from 14 proportionally
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Picker Card with Dropdown
          Container(
            margin: const EdgeInsets.all(12), // Reduced from 16 proportionally
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context)
                      .colorScheme
                      .surfaceContainer
                      .withValues(alpha: 0.8)
                  : Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(10), // Reduced from 12 proportionally
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3)
                    : Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: Theme.of(context).brightness == Brightness.dark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10), // Reduced proportionally
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date Range',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.8)
                              : Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedDateRange,
                            icon: Icon(Icons.arrow_drop_down,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.8)
                                    : Theme.of(context).colorScheme.primary),
                            elevation: 16,
                            style: TextStyle(
                              fontSize: 13, // Reduced from 14 proportionally
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.9)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                            onChanged: (String? newValue) async {
                              if (newValue == 'Custom Range') {
                                await _selectDateRange();
                              } else if (newValue != null &&
                                  _dateRangeOptions.containsKey(newValue)) {
                                setState(() {
                                  _selectedDateRange = newValue;
                                  _updateDateRange(
                                    DateTime.now()
                                        .subtract(_dateRangeOptions[newValue]!),
                                    DateTime.now(),
                                  );
                                });
                              }
                            },
                            items: <String>[
                              ..._dateRangeOptions.keys,
                              'Custom Range',
                            ].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    style: TextStyle(
                                        fontSize:
                                            13)), // Reduced from 14 proportionally
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(_dateRange.start)} - ${DateFormat('MMM d, yyyy').format(_dateRange.end)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.8)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(
                              20.0), // Reduced from 24 proportionally
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 40,
                                  color: Colors
                                      .red), // Reduced from 48 proportionally
                              const SizedBox(
                                  height: 12), // Reduced from 16 proportionally
                              Text(
                                _error,
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontSize:
                                        14), // Reduced from 15 proportionally
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(
                                  height: 12), // Reduced from 16 proportionally
                              TextButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh,
                                    size: 16), // Reduced from 18 proportionally
                                label: const Text('Try Again',
                                    style: TextStyle(
                                        fontSize:
                                            13)), // Reduced proportionally
                              ),
                            ],
                          ),
                        ),
                      )
                    : _transactions.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(
                                  12.0), // Reduced from 16 proportionally
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CashFlowAnalysisWidget(
                                      transactions: _allTransactions,
                                      selectedType: _selectedType,
                                      currentCurrency: _currentCurrency),
                                  const SizedBox(
                                      height:
                                          20), // Reduced from 24 proportionally
                                  SpendingAnalyticsWidget(
                                      transactions: _transactions,
                                      selectedType: _selectedType,
                                      currentCurrency: _currentCurrency),
                                  const SizedBox(
                                      height:
                                          20), // Reduced from 24 proportionally
                                  SpendingTrendsWidget(
                                      transactions: _transactions,
                                      selectedType: _selectedType,
                                      currentCurrency: _currentCurrency),
                                  const SizedBox(
                                      height:
                                          20), // Reduced from 24 proportionally
                                  _buildSpendingForecast(),
                                  const SizedBox(
                                      height:
                                          20), // Reduced from 24 proportionally
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Reduced from 24 proportionally
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined,
                size: 48,
                color: Colors.grey[400]), // Reduced from 56 proportionally
            const SizedBox(height: 12), // Reduced from 16 proportionally
            Text(
              'No transaction data available',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8),
                fontSize: 14, // Reduced from 15 proportionally
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4), // Reduced from 6 proportionally
            Text(
              'Add some expenses to see detailed insights',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontSize: 12, // Reduced from 13 proportionally
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20), // Reduced from 24 proportionally
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.add,
                  size: 16), // Reduced from 18 proportionally
              label: const Text('Add Expense',
                  style: TextStyle(fontSize: 13)), // Reduced proportionally
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10), // Reduced proportionally
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(6), // Reduced from 8 proportionally
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingForecast() {
    return const SizedBox.shrink();
  }
}

enum TransactionType { expense, income, transfer }

class Transaction {
  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String? description;
  final String? paymentMethod;
  final TransactionType type;
  final String currency; // Added currency field

  Transaction({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
    this.paymentMethod,
    required this.type,
    this.currency = 'INR', // Default to INR
  });

  factory Transaction.fromMap(Map<String, dynamic> map, String id) {
    // Safely parse amount to double
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Safely parse date
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      return DateTime.now();
    }

    return Transaction(
      id: id,
      category: (map['category'] as String?) ?? 'Uncategorized',
      amount: parseAmount(map['amount']),
      date: parseDate(map['date']),
      description: map['description'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      type: _parseTransactionType((map['type'] as String?) ?? 'expense'),
      currency: (map['currency'] as String?) ?? 'INR',
    );
  }

  // Create a copy of this transaction with updated fields
  Transaction copyWith({
    String? id,
    String? category,
    double? amount,
    DateTime? date,
    String? description,
    String? paymentMethod,
    TransactionType? type,
    String? currency,
  }) {
    return Transaction(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      type: type ?? this.type,
      currency: currency ?? this.currency,
    );
  }

  static TransactionType _parseTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'income':
        return TransactionType.income;
      case 'transfer':
        return TransactionType.transfer;
      case 'expense':
      default:
        return TransactionType.expense;
    }
  }
}
