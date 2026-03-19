import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/ui/app_input.dart';
import '../../../services/settings_service.dart';
import '../../../services/currency_service.dart';
import 'dart:async';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Filters
  // Removed: type/date/amount/category filters and cached categories

  // Currency state for conversion
  String _currentCurrency = 'USD'; // Will be updated from settings

  @override
  void initState() {
    super.initState();
    _loadCurrencyAndRates();
    // Ensure UI updates when AppInput's internal clear button is used
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
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
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {});
    });
  }

  IconData _categoryIcon(String category, bool isIncome) {
    if (isIncome) return Icons.trending_up_rounded;
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return Icons.restaurant_menu_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'transport':
      case 'travel':
        return Icons.directions_bus_filled_rounded;
      case 'fuel':
        return Icons.local_gas_station_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_creation_rounded;
      case 'health':
      case 'medical':
        return Icons.health_and_safety_rounded;
      case 'bills':
      case 'utilities':
        return Icons.receipt_long_rounded;
      case 'rent':
        return Icons.home_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'investment':
        return Icons.savings_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // Removed filter bottom sheet

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view expenses.')),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .orderBy('date', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );

    final dateFmt = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: AppInput(
          controller: _searchCtrl,
          label: 'Search',
          hint: 'Search payee, notes, category... ',
          prefixIcon: const Icon(Icons.search_rounded),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
        ),
        actions: const [SizedBox(width: 6)], // Reduced from 8 proportionally
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(12), // Reduced from 16 proportionally
                child: Text(
                  'Failed to load expenses. Please try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No expenses yet.'));
          }

          // Apply client-side search only (filters removed)

          final searchQ = _searchCtrl.text.trim().toLowerCase();
          bool matchesSearch(Map<String, dynamic> d) {
            if (searchQ.isEmpty) return true;
            final payeeRaw = (d['payeeItem'] ?? d['payee'] ?? '').toString();
            final payee = payeeRaw.toLowerCase();
            final notes = (d['notes'] ?? '').toString().toLowerCase();
            final category = (d['category'] ?? '').toString().toLowerCase();
            final label = (d['label'] ?? '').toString().toLowerCase();
            return payee.contains(searchQ) ||
                notes.contains(searchQ) ||
                category.contains(searchQ) ||
                label.contains(searchQ);
          }

          final filteredDocs = docs.where((doc) {
            final d = doc.data();
            return matchesSearch(d);
          }).toList();

          // Build a flat list with date headers inserted when the date changes
          final items = <Widget>[];
          String? lastKey;
          for (final doc in filteredDocs) {
            final d = doc.data();
            final ts = d['date'];
            DateTime? date;
            if (ts is Timestamp) date = ts.toDate();
            final key = date != null
                ? DateFormat('yyyy-MM-dd').format(date)
                : 'unknown';
            if (lastKey != key) {
              lastKey = key;
              final headerText = date != null
                  ? DateFormat.yMMMMd().format(date)
                  : 'Unknown date';
              items.add(Padding(
                padding: const EdgeInsets.fromLTRB(
                    10, 10, 10, 4), // Reduced from 12,12,12,6 proportionally
                child: Text(
                  headerText,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        // Reduced from titleMedium
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        fontSize: 14, // Reduced proportionally
                      ),
                ),
              ));
            }

            final amount =
                (d['amount'] is num) ? (d['amount'] as num).toDouble() : 0.0;
            final category = (d['category'] ?? '') as String;
            final payee =
                ((d['payeeItem'] ?? d['payee'] ?? '') as String).trim();
            final method = (d['paymentMethod'] ?? '') as String;
            final type = (d['type'] ?? '') as String;
            final label = (d['label'] ?? '') as String;
            final transactionCurrency = (d['currency'] ?? 'INR') as String;

            // Convert amount to current currency
            final convertedAmount = _convertAmount(amount, transactionCurrency);

            // Use current currency for display
            final displayCurrencySymbol =
                CurrencyService.getCurrencySymbol(_currentCurrency);
            final displayCurrencyLocale =
                CurrencyService.getCurrencyLocale(_currentCurrency);
            final displayFormatter = NumberFormat.currency(
                symbol: displayCurrencySymbol,
                locale: displayCurrencyLocale,
                decimalDigits: 2);

            items.add(Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3), // Reduced from 12,4 proportionally
              child: Card(
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 18, // Reduced from default proportionally
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.5),
                    child: Icon(
                        _categoryIcon(category, type.toLowerCase() == 'income'),
                        color: type.toLowerCase() == 'income'
                            ? Colors.green
                            : Theme.of(context).colorScheme.secondary,
                        size: 16), // Reduced icon size proportionally
                  ),
                  title: Text(
                    payee.isNotEmpty ? payee : '(No payee)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          // Reduced from bodyLarge
                          fontWeight: FontWeight.w700,
                          fontSize: 14, // Reduced proportionally
                        ),
                  ),
                  subtitle: Text(
                    [
                      category,
                      method,
                      if (label.isNotEmpty) '#$label',
                      if (date != null) dateFmt.format(date),
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          // Reduced from bodySmall
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.75),
                          fontSize: 11, // Reduced proportionally
                        ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayFormatter.format(convertedAmount),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              // Reduced from bodyLarge
                              fontWeight: FontWeight.w800,
                              color: type.toLowerCase() == 'transfer'
                                  ? Colors.blue.shade700
                                  : type.toLowerCase() == 'income'
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.error,
                              fontSize: 14, // Reduced proportionally
                            ),
                      ),
                      const SizedBox(width: 6), // Reduced from 8 proportionally
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18), // Reduced from default proportionally
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) {
                              final cs = Theme.of(ctx).colorScheme;
                              return AlertDialog(
                                title: const Text('Delete transaction?'),
                                content: Text(
                                  'This will permanently delete this transaction from Arthaksh and Firestore.\n\nPayee: '
                                  '${payee.isNotEmpty ? payee : '(No payee)'}\n'
                                  'Amount: ${displayFormatter.format(convertedAmount)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          fontSize:
                                              12), // Reduced proportionally
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: cs.error),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text('Delete',
                                        style: TextStyle(color: cs.onError)),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmed == true) {
                            try {
                              await doc.reference.delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Transaction deleted'),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .error
                                        .withValues(alpha: 0.9),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete: $e'),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ));
          }

          return ListView(
            padding: const EdgeInsets.only(
                bottom: 4), // Reduced from 12 proportionally
            children: items,
          );
        },
      ),
    );
  }
}
