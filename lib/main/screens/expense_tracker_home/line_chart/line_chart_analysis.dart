import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/services/currency_service.dart';

class LineChartAnalysis extends StatelessWidget {
  final List<FlSpot> chartData;
  final String currentCurrency;

  const LineChartAnalysis({
    super.key,
    required this.chartData,
    required this.currentCurrency,
  });

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = chartData.fold<double>(0.0, (sum, spot) => sum + spot.y);
    final avg = total / chartData.length;

    FlSpot? maxSpot;
    for (final spot in chartData) {
      if (maxSpot == null || spot.y > maxSpot.y) {
        maxSpot = spot;
      }
    }

    final symbol = CurrencyService.getCurrencySymbol(currentCurrency);
    final highestLabel =
        maxSpot == null ? '-' : _formatDayLabel(maxSpot.x.toInt());

    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMetric(
            context,
            label: 'Total',
            value: _formatAmount(symbol, total),
          ),
          _buildMetric(
            context,
            label: 'Avg / day',
            value: _formatAmount(symbol, avg),
          ),
          _buildMetric(
            context,
            label: 'Highest',
            value: highestLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context,
      {required String label, required String value}) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _formatAmount(String symbol, double amount) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String _formatDayLabel(int index) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day - (6 - index));

    if (index == 6) {
      return 'Today';
    } else if (index == 5) {
      return 'Yesterday';
    } else {
      return DateFormat('EEE').format(date);
    }
  }
}
