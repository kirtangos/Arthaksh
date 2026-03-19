import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class InsightsCalendar extends StatelessWidget {
  const InsightsCalendar({
    super.key,
    required this.calendarMonthVN,
    required this.hasIncome,
    required this.hasExpense,
    required this.hasTransfer,
    required this.scale,
  });

  final ValueNotifier<DateTime> calendarMonthVN;
  final Map<String, bool> hasIncome;
  final Map<String, bool> hasExpense;
  final Map<String, bool> hasTransfer;
  final double scale;

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
          // Primary shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          // Secondary shadow for ambient lighting
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<DateTime>(
          valueListenable: calendarMonthVN,
          builder: (context, now, _) {
            final first = DateTime(now.year, now.month, 1);
            final last = DateTime(now.year, now.month + 1, 0);
            final daysInMonth = last.day;
            final leadingBlanks = first.weekday % 7; // start from Sunday

            final headerStyle = theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: (theme.textTheme.titleSmall?.fontSize ?? 14) * scale,
            );
            final dayStyle = theme.textTheme.bodySmall?.copyWith(
              fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) * scale,
            );

            Widget weekday(String s) => Expanded(
                  child: Center(
                    child: Text(
                      s,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: (theme.textTheme.labelSmall?.fontSize ?? 11) *
                            scale,
                      ),
                    ),
                  ),
                );

            final List<Widget> cells = [];
            for (int i = 0; i < leadingBlanks; i++) {
              cells.add(const SizedBox());
            }
            for (int d = 1; d <= daysInMonth; d++) {
              final date = DateTime(now.year, now.month, d);
              final key = intl.DateFormat('yyyy-MM-dd').format(date);
              final inc = hasIncome[key] == true;
              final trn = hasTransfer[key] == true;
              final exp = hasExpense[key] == true;
              cells.add(
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$d',
                        style: dayStyle?.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: 1),
                      SizedBox(
                        width: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // INCOME (green) - left
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: inc
                                    ? Colors.green.shade700
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            // TRANSFER (blue) - middle
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: trn
                                    ? Colors.blue.shade600
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            // EXPENSE (red) - right
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: exp
                                    ? Colors.red.shade600
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final monthKey = ValueKey('${now.year}-${now.month}');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: cs.onSurface.withValues(alpha: 0.8),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final cur = calendarMonthVN.value;
                        calendarMonthVN.value =
                            DateTime(cur.year, cur.month - 1, 1);
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          intl.DateFormat.yMMMM().format(now),
                          style: headerStyle?.copyWith(color: cs.onSurface),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: cs.onSurface.withValues(alpha: 0.8),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final cur = calendarMonthVN.value;
                        calendarMonthVN.value =
                            DateTime(cur.year, cur.month + 1, 1);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    weekday('S'),
                    weekday('M'),
                    weekday('T'),
                    weekday('W'),
                    weekday('T'),
                    weekday('F'),
                    weekday('S'),
                  ],
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final double gridHeight =
                        ((240 * scale).clamp(200, 320).toDouble())
                                .floorToDouble() -
                            2.0;
                    return SizedBox(
                      key: monthKey,
                      height: gridHeight,
                      child: GridView.count(
                        crossAxisCount: 7,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        children: cells,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
