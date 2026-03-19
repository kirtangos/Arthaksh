import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;
import 'expense_tracker_home/expenses_list.dart';
import 'expense_tracker_home/balance_sheet.dart';
import 'expense_tracker_home/excel_export_service.dart';
import 'expense_tracker_home/line_chart/line_chart_widget.dart';
import 'expense_tracker_home/pie_chart/pie_chart_widget.dart';
import 'expense_tracker_home/insights_calendar.dart';
import 'modern_insights_screen.dart';
import 'add_expense.dart';
import '../../widgets/premium_upsell_dialog.dart';
import '../auth_choice_sheet.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  // Excel export service instance
  final ExcelExportService _excelExportService = ExcelExportService();

  // Calendar state management
  final ValueNotifier<DateTime> _calendarMonthVN =
      ValueNotifier(DateTime.now());
  final Map<String, bool> _hasIncome = {};
  final Map<String, bool> _hasExpense = {};
  final Map<String, bool> _hasTransfer = {};
  StreamSubscription<QuerySnapshot>? _calendarSubscription;

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  @override
  void dispose() {
    _calendarSubscription?.cancel();
    _calendarMonthVN.dispose();
    super.dispose();
  }

  void _loadCalendarData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get first and last day of current month
    final now = _calendarMonthVN.value;
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    _calendarSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .snapshots()
        .listen((snapshot) {
      // Clear previous data
      _hasIncome.clear();
      _hasExpense.clear();
      _hasTransfer.clear();

      // Process transactions
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final type = data['type']?.toString().toLowerCase() ?? 'expense';
        final dateKey = intl.DateFormat('yyyy-MM-dd').format(date);

        switch (type) {
          case 'income':
            _hasIncome[dateKey] = true;
            break;
          case 'expense':
            _hasExpense[dateKey] = true;
            break;
          case 'transfer':
            _hasTransfer[dateKey] = true;
            break;
        }
      }

      setState(() {});
    });

    // Listen for month changes
    _calendarMonthVN.addListener(() {
      _loadCalendarData();
    });
  }

  // Build mobile-optimized quick action button
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.08),
        highlightColor: isDark
            ? color.withValues(alpha: 0.06)
            : color.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isDark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.08),
                      color.withValues(alpha: 0.03),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.06),
                      color.withValues(alpha: 0.02),
                    ],
                  ),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.25)
                  : color.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? color.withValues(alpha: 0.16)
                          : color.withValues(alpha: 0.12),
                      isDark
                          ? color.withValues(alpha: 0.08)
                          : color.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: isDark ? color.withValues(alpha: 0.9) : color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? color.withValues(alpha: 0.9) : color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (!isFullWidth) ...[
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark
                      ? color.withValues(alpha: 0.7)
                      : color.withValues(alpha: 0.5),
                  size: 12,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Method to ensure authentication before proceeding with a callback
  Future<void> _ensureAuthOrPrompt(
      BuildContext context, VoidCallback onAuthenticated) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await showAuthChoiceSheet(context);
      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser != null) {
        onAuthenticated();
      }
    } else {
      onAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Track Expense'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Financial Insights',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get();
                      final isPremium = userDoc.data()?['isPremium'] == true;
                      final premiumFeatures =
                          userDoc.data()?['premiumFeatures'] is Map
                              ? Map<String, dynamic>.from(
                                  userDoc.data()?['premiumFeatures'] as Map)
                              : null;
                      final hasInsightsAccess =
                          isPremium || (premiumFeatures?['insights'] == true);

                      if (!hasInsightsAccess) {
                        await PremiumUpsellDialog.show(
                          context,
                          featureName: 'Insights',
                          description:
                              'Insights is available for premium users. Upgrade to unlock advanced analytics, trends, personalized tips, and more.',
                          onUpgrade: () {
                            // Removed context usage to avoid async gap
                            // The upgrade flow will be handled by the dialog itself
                          },
                          onLater: () {
                            // Optionally handle later
                          },
                        );
                        // Don't navigate if user doesn't have access
                        return;
                      }

                      // Only navigate if user has access and we're still mounted
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ModernInsightsScreen()),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.insights_outlined, size: 20),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Export to Excel',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _excelExportService.exportExcel(context),
                  icon: const Icon(Icons.download_rounded, size: 20),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(width: 1.5, color: cs.primary)),
                  ),
                  child: DropdownButton<String>(
                    value: _excelExportService.selectedDateRange,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _excelExportService.setSelectedDateRange(newValue);
                        });
                        if (newValue == 'Custom Range') {
                          _excelExportService
                              .showCustomDateRangePicker(context);
                        }
                      }
                    },
                    items: <String>[
                      'All Time',
                      'Last 7 days',
                      'Last 30 days',
                      'Last 3 months',
                      'Last year',
                      'Custom Range'
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    icon: const Icon(Icons.filter_list, size: 20),
                    underline: const SizedBox(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _ensureAuthOrPrompt(context, () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
            );
          });
        },
        icon: const Icon(Icons.add_card_rounded, size: 26),
        label: const Text('Add Expense'),
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surfaceContainerHighest.withValues(alpha: 0.35),
              cs.surface.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, 8), // Reduced from 18,20,18,120 proportionally
            children: [
              Text('Expense Tracker',
                  style: theme.textTheme.titleLarge?.copyWith(
                    // Reduced from headlineSmall
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    fontSize: 20, // Reduced proportionally
                  )),
              const SizedBox(height: 4), // Reduced from 6 proportionally
              Text('Log your expenses, categorize them, and view summaries.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    // Reduced from bodyMedium
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontSize: 12, // Reduced proportionally
                  )),
              const SizedBox(height: 16),

              // Quick Actions Section - Mobile Optimized
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: theme.brightness == Brightness.dark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.surfaceContainerHighest.withValues(alpha: 0.3),
                            cs.surfaceContainer.withValues(alpha: 0.1),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary.withValues(alpha: 0.05),
                            cs.secondary.withValues(alpha: 0.02),
                          ],
                        ),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? cs.outline.withValues(alpha: 0.3)
                        : cs.outline.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.secondary],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.flash_on_rounded,
                            color: cs.onPrimary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Actions',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // First Row: History & Balance Sheet
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.history_rounded,
                            label: 'History',
                            color: cs.primary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ExpensesListScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.table_chart_rounded,
                            label: 'Balance Sheet',
                            color: cs.tertiary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const BalanceSheetScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Second Row: Export
                    _buildQuickActionButton(
                      icon: Icons.download_rounded,
                      label: 'Export Data',
                      color: cs.secondary,
                      isFullWidth: true,
                      onTap: () => _excelExportService.exportExcel(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Last 7 Days Line Chart
              const LineChartWidget(),
              const SizedBox(height: 16),

              // Category Distribution Pie Chart
              const PieChartWidget(),
              const SizedBox(height: 16),

              // Monthly Calendar View
              InsightsCalendar(
                calendarMonthVN: _calendarMonthVN,
                hasIncome: _hasIncome,
                hasExpense: _hasExpense,
                hasTransfer: _hasTransfer,
                scale: 0.9,
              ),
              const SizedBox(height: 16),
            ], // ✅ Added missing closing bracket for ListView children
          ),
        ),
      ),
    );
  }
}
