import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:arthaksh/services/currency_service.dart';
import 'package:arthaksh/services/settings_service.dart';
import 'pie_chart_analysis_screen.dart';

class PieChartWidget extends StatefulWidget {
  const PieChartWidget({super.key});

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  Map<String, double> categoryTotals = {};
  bool _isLoading = true;
  String _selectedRange = 'This Month';
  String _currentCurrency = 'USD';
  Key _chartKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadCurrencyAndData();
  }

  DateTime? _getStartDate(String range) {
    final now = DateTime.now();
    switch (range) {
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 days':
        return now.subtract(const Duration(days: 30));
      case 'Last 3 months':
        return DateTime(now.year, now.month - 3, now.day);
      case 'Last year':
        return DateTime(now.year - 1, now.month, now.day);
      default:
        return null; // All Time
    }
  }

  double _convertAmount(double amount, String originalCurrency) {
    if (originalCurrency == _currentCurrency) return amount;

    // Use CurrencyService for synchronous conversion
    return CurrencyService.convertAmountSync(
        amount, originalCurrency, _currentCurrency);
  }

  Future<void> _loadCurrencyAndData() async {
    try {
      final currency = await SettingsService.getSelectedCurrency();
      if (mounted) {
        setState(() {
          _currentCurrency = currency;
        });
      }

      // Ensure currency cache is initialized for conversions
      await CurrencyService.ensureCacheInitialized();

      // No need to manually fetch rates - CurrencyService handles this
      // The _convertAmount method now uses CurrencyService.convertAmountSync

      await _loadData();
    } catch (e, stackTrace) {
      debugPrint('Error in _loadCurrencyAndData: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final startDate = _getStartDate(_selectedRange);
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses');

    if (startDate != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    query = query.orderBy('date', descending: true);

    final snap = await query.get();

    final Map<String, double> totals = {};

    for (final doc in snap.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final category = data['category'] as String? ?? 'Uncategorized';
      final type = (data['type'] as String?)?.toLowerCase() ?? 'expense';
      final currency = (data['currency'] as String?) ?? 'INR';

      if (type == 'expense') {
        final convertedAmount = _convertAmount(amount, currency);
        totals[category] = (totals[category] ?? 0) + convertedAmount;
      }
    }

    if (mounted) {
      setState(() {
        categoryTotals = totals;
        _isLoading = false;
        _chartKey = UniqueKey();
      });
    }
  }

  void dispose() {
    // Cancel any ongoing operations if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: cs.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: cs.outline.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optimized header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.pie_chart,
                        size: 16,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Category Distribution',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedRange,
                    underline: const SizedBox(),
                    isDense: true,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: cs.primary,
                    ),
                    items: ['This Month', 'Last 7 days', 'Last 3 months']
                        .map((range) => DropdownMenuItem(
                              value: range,
                              child: Text(range),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedRange = value;
                          _chartKey = UniqueKey();
                        });
                        _loadData();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              SizedBox(
                height: 200, // Match line chart height
                child: Center(
                  child: CircularProgressIndicator(
                    color: cs.primary,
                  ),
                ),
              )
            else if (categoryTotals.isEmpty)
              Container(
                height: 200, // Match line chart height
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.pie_chart,
                        size: 48,
                        color: cs.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No expense data available',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'for the selected period',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 200, // Match line chart height
                  maxHeight: 200, // Fixed height to match line chart
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.maxWidth > constraints.maxHeight
                        ? constraints.maxHeight
                        : constraints.maxWidth;
                    final chartSize = size * 0.8;

                    return GestureDetector(
                      onTap: () {
                        // Navigate to pie chart analysis screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const PieChartAnalysisScreen(),
                          ),
                        );
                      },
                      child: SfCircularChart(
                        key: _chartKey,
                        margin: const EdgeInsets.all(8),
                        backgroundColor: cs.surface,
                        series: <CircularSeries>[
                          DoughnutSeries<_PieData, String>(
                            dataSource: categoryTotals.entries
                                .map((e) => _PieData(e.key, e.value))
                                .toList(),
                            xValueMapper: (_PieData data, _) => data.category,
                            yValueMapper: (_PieData data, _) => data.amount,
                            innerRadius: '35%',
                            radius: '75%',
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              labelPosition: ChartDataLabelPosition.outside,
                              useSeriesColor: true,
                              textStyle: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurface,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              labelIntersectAction: LabelIntersectAction.shift,
                              connectorLineSettings:
                                  const ConnectorLineSettings(
                                width: 2,
                                type: ConnectorType.line,
                                length: '15%',
                              ),
                            ),
                            dataLabelMapper: (_PieData data, index) {
                              // Skip labels for "General" and "college" categories
                              if (data.category
                                      .toLowerCase()
                                      .contains('general') ||
                                  data.category
                                      .toLowerCase()
                                      .contains('college')) {
                                return ''; // Empty string to hide label
                              }

                              final total = categoryTotals.values
                                  .fold(0.0, (a, b) => a + b);
                              final percent = total > 0
                                  ? (data.amount / total * 100)
                                      .toStringAsFixed(1)
                                  : '0.0';
                              return '${data.category} ($percent%)';
                            },
                            pointColorMapper: (_PieData data, index) {
                              // Different shades of teal for different categories
                              final tealShades = [
                                const Color(0xFF0D9488), // Teal 800 - Darkest
                                const Color(0xFF14B8A6), // Teal 600
                                const Color(0xFF2DD4BF), // Teal 500
                                const Color(0xFF5EEAD4), // Teal 300
                                const Color(0xFF5FDFDF), // Teal 200
                                const Color(0xFFCCFBF1), // Teal 100 - Lightest
                                const Color(0xFF134E4A), // Teal 900 - Very Dark
                                const Color(0xFF115E59), // Teal 700
                              ];
                              return tealShades[index % tealShades.length];
                            },
                            // Enhanced visual effects
                            explode:
                                false, // Disable explode to prevent shifting
                            animationDuration: 1200,
                            strokeColor: cs.surface,
                            strokeWidth: 2,
                            opacity: 0.95,
                            // Add professional tap behavior
                            onPointTap: (ChartPointDetails details) {
                              // Handle tap consistently with line chart
                              // Could navigate to detailed category view or show modal
                            },
                          ),
                        ],
                        legend: Legend(
                          isVisible: true,
                          position: LegendPosition.bottom,
                          overflowMode: LegendItemOverflowMode.wrap,
                          textStyle: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          itemPadding: 6,
                          iconHeight: 12,
                          iconWidth: 12,
                          legendItemBuilder:
                              (legendName, series, point, pointIndex) {
                            // Use same teal shades as pie chart
                            final tealShades = [
                              const Color(0xFF0D9488), // Teal 800
                              const Color(0xFF14B8A6), // Teal 600
                              const Color(0xFF2DD4BF), // Teal 500
                              const Color(0xFF5EEAD4), // Teal 300
                              const Color(0xFF5FDFDF), // Teal 200
                              const Color(0xFFCCFBF1), // Teal 100
                              const Color(0xFF134E4A), // Teal 900
                              const Color(0xFF115E59), // Teal 700
                            ];
                            final color =
                                tealShades[pointIndex % tealShades.length];

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  legendName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        // Enhanced tooltip with hover behavior
                        tooltipBehavior: TooltipBehavior(
                          enable: true, // Enable tooltips on hover
                          builder: (dynamic data, dynamic point, dynamic series,
                              int pointIndex, int seriesIndex) {
                            // Calculate proportion ratio
                            final total = categoryTotals.values
                                .fold(0.0, (a, b) => a + b);
                            final amount = categoryTotals.entries
                                .elementAt(pointIndex)
                                .value;
                            final percent = total > 0
                                ? (amount / total * 100).toStringAsFixed(1)
                                : '0.0';
                            final category = categoryTotals.entries
                                .elementAt(pointIndex)
                                .key;

                            // Get the teal shade for this category
                            final tealShades = [
                              const Color(0xFF0D9488), // Teal 800
                              const Color(0xFF14B8A6), // Teal 600
                              const Color(0xFF2DD4BF), // Teal 500
                              const Color(0xFF5EEAD4), // Teal 300
                              const Color(0xFF5FDFDF), // Teal 200
                              const Color(0xFFCCFBF1), // Teal 100
                              const Color(0xFF134E4A), // Teal 900
                              const Color(0xFF115E59), // Teal 700
                            ];
                            final categoryColor =
                                tealShades[pointIndex % tealShades.length];

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: categoryColor.withOpacity(0.4),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                  BoxShadow(
                                    color: categoryColor.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Color indicator
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: categoryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Category and percentage
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: cs.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '$percent%',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: categoryColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                          shouldAlwaysShow: false, // Only on hover
                          opacity: 0.95,
                          duration: 1200, // Show for 1.2 seconds
                          animationDuration: 200, // Smooth fade in
                          elevation: 0, // Use custom shadows instead
                        ),
                      ),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _PieData {
  final String category;
  final double amount;

  _PieData(this.category, this.amount);
}
