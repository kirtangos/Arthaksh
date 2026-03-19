import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/settings_service.dart';
import '../../../services/currency_service.dart';

class ContributionsSheet extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> goalRef;
  final String goalName;
  final double target;

  const ContributionsSheet({
    super.key,
    required this.goalRef,
    required this.goalName,
    required this.target,
  });

  @override
  State<ContributionsSheet> createState() => _ContributionsSheetState();
}

class _ContributionsSheetState extends State<ContributionsSheet> {
  String _currentCurrency = 'INR';
  late NumberFormat _displayFormatter;

  @override
  void initState() {
    super.initState();
    _loadCurrencyAndRates();
  }

  Future<void> _loadCurrencyAndRates() async {
    final currencyCode = await SettingsService.getSelectedCurrency();
    if (!mounted) return;
    setState(() {
      _currentCurrency = currencyCode;
      final symbol = CurrencyService.getCurrencySymbol(currencyCode);
      final locale = CurrencyService.getCurrencyLocale(currencyCode);
      _displayFormatter = NumberFormat.currency(
        symbol: symbol,
        locale: locale,
        decimalDigits: 2,
      );
    });
  }

  double _convertAmount(double amountInINR) {
    return CurrencyService.convertAmountSync(
      amountInINR,
      'INR',
      _currentCurrency,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.history_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Contributions — ${widget.goalName}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.goalRef
                  .collection('contributions')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator()));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('No contributions yet.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  );
                }
                double total = 0;
                for (final d in docs) {
                  total += (d['amount'] as num?)?.toDouble() ?? 0.0;
                }
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.25),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total contributed',
                              style: Theme.of(context).textTheme.bodyMedium),
                          Text(_displayFormatter.format(_convertAmount(total)),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final d = docs[i].data();
                          final amount =
                              (d['amount'] as num?)?.toDouble() ?? 0.0;
                          final ts = d['date'] as Timestamp?;
                          final date = ts?.toDate();
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: cs.outlineVariant),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(10)),
                            ),
                            title: Text(
                                _displayFormatter
                                    .format(_convertAmount(amount)),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            subtitle: Text(date == null
                                ? '-'
                                : DateFormat.yMMMd().format(date)),
                            leading: CircleAvatar(
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.16),
                                child: Icon(Icons.call_made_rounded,
                                    color: cs.primary)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
