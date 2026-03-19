import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'installment_service.dart';
import 'loan_service.dart';
import 'add_loan_sheet.dart';
import 'validators.dart';
import 'constants.dart';
import 'package:arthaksh/services/settings_service.dart';
import 'package:arthaksh/services/currency_service.dart';

class LoanPlannerScreen extends StatefulWidget {
  const LoanPlannerScreen({super.key});

  @override
  State<LoanPlannerScreen> createState() => _LoanPlannerScreenState();
}

// Payment frequency constants
const String _frequencyMonthly = frequencyMonthly;

class _LoanPlannerScreenState extends State<LoanPlannerScreen> {
  GlobalKey<FormState>? _formKey;
  // Loan inputs
  final _loanNameCtrl = TextEditingController();
  final _lenderCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _processingCtrl = TextEditingController();
  final _nf = NumberFormat.decimalPattern();

  // Initialize with date only to avoid timezone issues
  late DateTime _startDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  // Frequency selection (Monthly | Quarterly | Half Yearly)
  String _frequency = _frequencyMonthly;
  String _loanType = homeLoan; // Dropdown

  // Installment inputs (used in bottom sheet)
  final _instLoanNameCtrl = TextEditingController();
  final _instAmountCtrl = TextEditingController();
  // Initialize as null to show empty field by default
  DateTime? _instDate = DateTime.now();
  String _paymentType = regularEMI; // Regular EMI | Extra/Prepayment
  // The Firestore loan document id for which we're currently adding/editing installments
  String? _instLoanId;

  double? _emi;
  double? _totalPayment;
  double? _totalInterest;

  // Filters & search for loan list
  String _loanFilter = statusAll; // All | Active | Closed
  String _loanSearch = '';

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
  }

  // Convert amount from original currency to current currency
  double _convertAmount(double amount, String originalCurrency) {
    if (originalCurrency == _currentCurrency) return amount;

    // Use CurrencyService for synchronous conversion
    return CurrencyService.convertAmountSync(
        amount, originalCurrency, _currentCurrency);
  }

  // Get currency formatter for display
  NumberFormat _getCurrencyFormatter() {
    final userCurrencySymbol =
        CurrencyService.getCurrencySymbol(_currentCurrency);
    final userCurrencyLocale =
        CurrencyService.getCurrencyLocale(_currentCurrency);
    return NumberFormat.currency(
        symbol: userCurrencySymbol,
        locale: userCurrencyLocale,
        decimalDigits: 2);
  }

  @override
  void dispose() {
    _loanNameCtrl.dispose();
    _lenderCtrl.dispose();
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    _processingCtrl.dispose();
    _instLoanNameCtrl.dispose();
    _instAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEditInstallmentDialog(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> data) async {
    final cs = Theme.of(context).colorScheme;
    final nf = NumberFormat.decimalPattern();
    final amount =
        (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
    DateTime date = DateTime.now();
    final ts = data['date'];
    if (ts is Timestamp) date = ts.toDate();
    String type = (data['paymentType'] ?? 'Regular EMI').toString();
    final ctrl = TextEditingController(
        text: amount > 0 ? nf.format(amount.round()) : '');
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cs.surface,
          title: const Text('Edit Installment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: date,
                  );
                  if (d != null) {
                    date = d;
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat.yMMMd().format(date)),
                      const Icon(Icons.event_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(
                      value: 'Regular EMI', child: Text('Regular EMI')),
                  DropdownMenuItem(
                      value: 'Extra/Prepayment',
                      child: Text('Extra/Prepayment')),
                ],
                onChanged: (v) => type = v ?? 'Regular EMI',
                decoration: const InputDecoration(labelText: 'Payment Type'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                double x = 0;
                try {
                  x = NumberFormat.decimalPattern().parse(ctrl.text).toDouble();
                } catch (_) {}
                await ref.update({
                  'amount': x,
                  'date': Timestamp.fromDate(date),
                  'paymentType': type,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                // After async gap, guard both contexts appropriately
                if (!mounted || !ctx.mounted) {
                  return;
                }
                Navigator.of(ctx).pop();
                final messenger = ScaffoldMessenger.maybeOf(context);
                messenger?.showSnackBar(
                  const SnackBar(content: Text('Installment updated')),
                );
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }

  void _deleteInstallmentWithUndo(DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete installment?'),
        content: const Text('This action can be undone from the snackbar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    await ref.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Installment deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref.set(data);
          },
        ),
      ),
    );
  }

  void _prefillAndOpenInstallmentSheet(
    Map<String, dynamic> t, {
    DateTime? dateOverride,
    double? amountOverride,
  }) {
    // Prefill loan name
    _instLoanNameCtrl.text = (t['name'] ?? '').toString();
    // Remember the exact loan document id so installments are stored under the correct loan
    _instLoanId = (t['id'] ?? '').toString();

    // Determine frequency params
    final freq = (t['frequency'] ?? 'Monthly') as String;
    int periodMonths;
    double annualRate =
        ((t['annualRate'] is num) ? (t['annualRate'] as num).toDouble() : 0.0) /
            100.0;
    double tenureMonths = (t['tenureMonths'] is num)
        ? (t['tenureMonths'] as num).toDouble()
        : 0.0;
    int totalPeriods;
    double rPerPeriod;
    switch (freq) {
      case 'Quarterly':
        periodMonths = 3;
        totalPeriods = (tenureMonths / 3.0).round();
        rPerPeriod = annualRate / 4.0;
        break;
      case 'Half Yearly':
        periodMonths = 6;
        totalPeriods = (tenureMonths / 6.0).round();
        rPerPeriod = annualRate / 2.0;
        break;
      default:
        periodMonths = 1;
        totalPeriods = tenureMonths.round();
        rPerPeriod = annualRate / 12.0;
    }

    // EMI amount (use stored if available)
    final principal =
        (t['principal'] is num) ? (t['principal'] as num).toDouble() : 0.0;
    double emi =
        (t['computedEmi'] is num) ? (t['computedEmi'] as num).toDouble() : 0.0;
    if (emi <= 0 && totalPeriods > 0) {
      if (rPerPeriod == 0) {
        emi = principal / totalPeriods;
      } else {
        double factor = 1.0;
        for (int i = 0; i < totalPeriods; i++) {
          factor *= (1 + rPerPeriod);
        }
        emi = principal * rPerPeriod * factor / (factor - 1);
      }
    }
    final amt = amountOverride ?? emi;
    final loanCurrency = (t['currency'] ?? 'INR') as String;
    _instAmountCtrl.text = amt > 0
        ? _getCurrencyFormatter().format(_convertAmount(amt, loanCurrency))
        : '';

    // Choose start date: prefer startDate, else createdAt, else today
    DateTime start = DateTime.now();
    final startTs = t['startDate'];
    if (startTs is Timestamp) {
      start = startTs.toDate();
    } else {
      final createdAt = t['createdAt'];
      if (createdAt is Timestamp) start = createdAt.toDate();
    }

    // Compute next scheduled date >= today, used as a smart default
    DateTime today = DateTime.now();
    DateTime next = start;
    int k = 1;
    while (next.isBefore(today) && k <= totalPeriods + 1) {
      next = _addMonths(start, periodMonths * k);
      k++;
    }

    // Respect an explicit override (e.g. when tapped from a schedule row).
    // Otherwise, only set the default if the user hasn't already picked a date
    // in this session, so the picker selection remains stable.
    if (dateOverride != null) {
      _instDate =
          DateTime(dateOverride.year, dateOverride.month, dateOverride.day);
    } else if (_instDate == null) {
      _instDate = DateTime(next.year, next.month, next.day);
    }
    _paymentType = regularEMI;

    // Open the sheet
    _openAddInstallmentSheet();
  }

  DateTime _addMonths(DateTime from, int months) {
    final int y = from.year;
    final int m = from.month + months;
    final int year = y + ((m - 1) ~/ 12);
    final int month = ((m - 1) % 12) + 1;
    final int day = from.day;
    // Clamp to last valid day of target month
    final int lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
    final int safeDay =
        day <= lastDayOfTargetMonth ? day : lastDayOfTargetMonth;
    return DateTime(year, month, safeDay);
  }

  // --- UI Sections ---
  Widget _yourLoansSection() {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: const Text('Log in to view your saved loans'),
      );
    }
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('loans')
        .orderBy('createdAt', descending: true)
        .snapshots();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Loans',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                ),
                hintText: 'Search loan or lender',
                hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context)
                        .colorScheme
                        .surfaceContainer
                        .withValues(alpha: 0.8)
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainer
                        .withValues(alpha: 0.3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
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
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
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
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.9)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.85),
                fontSize: 14,
              ),
              onChanged: (v) => setState(() => _loanSearch = v.trim()),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _loanFilter,
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Closed', child: Text('Closed')),
            ],
            onChanged: (v) => setState(() => _loanFilter = v ?? 'All'),
          )
        ]),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(),
              ));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('No loans found',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75))),
              );
            }
            var docs = snapshot.data!.docs;
            // Apply filter
            if (_loanFilter != 'All') {
              final closed = _loanFilter == 'Closed';
              docs = docs
                  .where((d) =>
                      (d.data()['status']?.toString().toLowerCase() ==
                          'closed') ==
                      closed)
                  .toList();
            }
            // Apply search
            if (_loanSearch.isNotEmpty) {
              final q = _loanSearch.toLowerCase();
              docs = docs.where((d) {
                final m = d.data();
                final name = (m['name'] ?? '').toString().toLowerCase();
                final lender = (m['lender'] ?? '').toString().toLowerCase();
                return name.contains(q) || lender.contains(q);
              }).toList();
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _loanCard({
                ...docs[i].data(),
                'id': docs[i].id,
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _loanCard(Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nf = NumberFormat.decimalPattern();
    final name = (t['name'] ?? 'Untitled') as String;
    final lender = (t['lender'] ?? '') as String;
    final emi =
        (t['computedEmi'] is num) ? (t['computedEmi'] as num).toDouble() : null;
    final rate = (t['annualRate'] is num)
        ? (t['annualRate'] as num).toDouble()
        : null; // stored in %
    final principal =
        (t['principal'] is num) ? (t['principal'] as num).toDouble() : null;
    final months = (t['tenureMonths'] is num)
        ? (t['tenureMonths'] as num).toDouble()
        : null;
    final freq = (t['frequency'] ?? 'Monthly') as String;
    DateTime? due;
    final ts = t['emiDueDate'];
    if (ts is Timestamp) due = ts.toDate();
    final isClosed = (t['status']?.toString().toLowerCase() == 'closed');

    // Compute number of EMIs based on frequency and tenure months
    int? numEmi;
    if (months != null) {
      double periods;
      switch (freq) {
        case 'Weekly':
          periods = months / 12.0 * 52.0;
          break;
        case 'Biweekly':
          periods = months / 12.0 * 26.0;
          break;
        default:
          periods = months; // Monthly
      }
      numEmi = periods.round();
      if (numEmi < 1) numEmi = 1;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
            Radius.circular(14)), // Reduced from 16 proportionally
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0), // Reduced from 16.0 proportionally
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                ),
                if (rate != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text('${rate.toStringAsFixed(2)}%',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: cs.primary, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
            if (lender.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(lender,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
            ],
            const SizedBox(height: 10), // Reduced from 12 proportionally
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpiChip(
                  context,
                  'Monthly EMI',
                  (emi == null || !emi.isFinite)
                      ? '-'
                      : _getCurrencyFormatter()
                          .format(_convertAmount(emi, 'INR')),
                ),
                _kpiChip(
                    context,
                    'Principal',
                    principal == null
                        ? '-'
                        : _getCurrencyFormatter()
                            .format(_convertAmount(principal, 'INR'))),
                _kpiChip(context, 'Tenure',
                    months == null ? '-' : '${months.round()} m'),
                _kpiChip(
                  context,
                  'No. of EMI',
                  (numEmi == null || !numEmi.isFinite)
                      ? '-'
                      : nf.format(numEmi),
                ),
                _kpiChip(context, 'Due Date',
                    due == null ? '-' : DateFormat('d MMM yyyy').format(due)),
                if (isClosed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text('Closed',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
            const SizedBox(height: 10), // Reduced from 12 proportionally
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openLoanDetails(t),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLoanDetails(Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nf = NumberFormat.decimalPattern();
    final name = (t['name'] ?? 'Untitled').toString();
    final lender = (t['lender'] ?? '').toString();
    final principal =
        (t['principal'] is num) ? (t['principal'] as num).toDouble() : null;
    final rate =
        (t['annualRate'] is num) ? (t['annualRate'] as num).toDouble() : null;
    final months = (t['tenureMonths'] is num)
        ? (t['tenureMonths'] as num).toDouble()
        : null;
    DateTime? due;
    final ts = t['emiDueDate'];
    if (ts is Timestamp) due = ts.toDate();
    final isClosed = (t['status']?.toString().toLowerCase() == 'closed');
    DateTime? closedAt;
    final closedTs = t['closedAt'];
    if (closedTs is Timestamp) closedAt = closedTs.toDate();

    // Prefill loan name and id for installment form, and reset date so each
    // loan starts with its own smart default instead of reusing a previous one.
    _instLoanNameCtrl.text = name;
    _instLoanId = (t['id'] ?? '').toString();
    _instDate = null;

    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          title: Text(name),
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                18, 10, 18, 22), // Reduced from 20,12,20,24 proportionally
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isClosed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                        10), // Reduced from 12 proportionally
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.all(Radius.circular(
                          10)), // Reduced from 12 proportionally
                    ),
                    child: Row(children: [
                      Icon(Icons.verified_rounded, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Loan Closed ${closedAt != null ? 'on ${DateFormat('d MMM yyyy').format(closedAt)}' : ''}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10), // Reduced from 12 proportionally
                ],
                Row(children: [
                  Icon(Icons.visibility_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  if (rate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Text('${rate.toStringAsFixed(2)}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.primary, fontWeight: FontWeight.w800)),
                    ),
                ]),
                if (lender.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(lender,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.75))),
                ],
                const SizedBox(height: 10), // Reduced from 12 proportionally
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiChip(
                        context,
                        'Principal',
                        principal == null
                            ? '-'
                            : '₹ ${nf.format((principal).round())}'),
                    _kpiChip(context, 'Tenure',
                        months == null ? '-' : '${months.round()} m'),
                    _kpiChip(
                        context,
                        'Due Date',
                        due == null
                            ? '-'
                            : DateFormat('d MMM yyyy').format(due)),
                  ],
                ),
                const SizedBox(height: 14), // Reduced from 16 proportionally
                // Progress header (paid vs total) with red/green status
                Builder(builder: (_) {
                  final freq = (t['frequency'] ?? 'Monthly') as String;
                  final months = (t['tenureMonths'] is num)
                      ? (t['tenureMonths'] as num).toDouble()
                      : 0.0;
                  int totalPeriods;
                  int periodMonths;
                  switch (freq) {
                    case 'Quarterly':
                      totalPeriods = (months / 3.0).round();
                      periodMonths = 3;
                      break;
                    case 'Half Yearly':
                      totalPeriods = (months / 6.0).round();
                      periodMonths = 6;
                      break;
                    default:
                      totalPeriods = months.round();
                      periodMonths = 1;
                  }
                  return Builder(builder: (context) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('loans')
                          .doc((t['id'] ?? '').toString())
                          .collection('installments')
                          .where('paymentType', isEqualTo: 'Regular EMI')
                          .snapshots(),
                      builder: (context, s) {
                        final paidCount = s.hasData ? s.data!.docs.length : 0;
                        final pct = (totalPeriods > 0)
                            ? (paidCount / totalPeriods).clamp(0.0, 1.0)
                            : 0.0;

                        // Determine expected paid by now using startDate/createdAt and frequency
                        DateTime start = DateTime.now();
                        final startTs = t['startDate'];
                        if (startTs is Timestamp) {
                          start = startTs.toDate();
                        } else {
                          final createdAt = t['createdAt'];
                          if (createdAt is Timestamp) {
                            start = createdAt.toDate();
                          }
                        }
                        final now = DateTime.now();
                        int monthsDiff = (now.year - start.year) * 12 +
                            (now.month - start.month);
                        if (DateTime(now.year, now.month, start.day)
                            .isBefore(now)) {
                          // already inclusive for day-of-month alignment
                        }
                        if (monthsDiff < 0) monthsDiff = 0;
                        int expected = 0;
                        if (periodMonths > 0) {
                          expected = (monthsDiff / periodMonths).floor();
                        }
                        if (expected > totalPeriods) expected = totalPeriods;
                        final behind = paidCount < expected;
                        final statusColor = behind
                            ? cs.error
                            : Colors.green.shade700.withValues(alpha: 0.7);
                        return Container(
                          padding: const EdgeInsets.all(
                              14), // Reduced from 16 proportionally
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.18),
                            borderRadius: const BorderRadius.all(
                                Radius.circular(
                                    10)), // Reduced from 12 proportionally
                            border: Border.all(
                                color:
                                    cs.outlineVariant.withValues(alpha: 0.6)),
                          ),
                          child: Row(children: [
                            Stack(alignment: Alignment.center, children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(
                                  value: pct,
                                  strokeWidth: 8,
                                  backgroundColor:
                                      cs.outlineVariant.withValues(alpha: 0.25),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      statusColor),
                                ),
                              ),
                              Text(
                                '${(pct * 100).round()}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: statusColor),
                              ),
                            ]),
                            const SizedBox(
                                width: 14), // Reduced from 16 proportionally
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Payoff Progress',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800)),
                                    const SizedBox(
                                        height:
                                            3), // Reduced from 4 proportionally
                                    Text(
                                        'Paid $paidCount of $totalPeriods EMIs',
                                        style: theme.textTheme.bodySmall),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                              alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          behind
                                              ? 'Behind Schedule'
                                              : 'On Track',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (behind)
                                        Text('Expected $expected by now',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                    color: cs.onSurface
                                                        .withValues(
                                                            alpha: 0.7))),
                                    ]),
                                  ]),
                            )
                          ]),
                        );
                      },
                    );
                  });
                }),
                const SizedBox(height: 10), // Reduced from 12 proportionally
                const SizedBox(height: 14), // Reduced from 16 proportionally
                Text('Amortization Schedule',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 7), // Reduced from 8 proportionally
                Builder(builder: (_) {
                  final loanId = (t['id'] ?? '').toString();
                  debugPrint('Loan data: $t');
                  debugPrint('Extracted loan ID: "$loanId"');
                  if (loanId.isEmpty) {
                    debugPrint(
                        'Loan ID is empty, returning empty amortization table');
                    return _amortizationTable(t);
                  }
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return _amortizationTable(t);
                  final coll = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('loans')
                      .doc(loanId)
                      .collection('installments')
                      .orderBy('date');
                  debugPrint('Querying installments for loan ID: $loanId');
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: coll.snapshots(),
                    builder: (context, snap) {
                      debugPrint(
                          'Installment query snapshot hasData: ${snap.hasData}, docs count: ${snap.data?.docs.length ?? 0}');
                      if (snap.hasData && snap.data!.docs.isNotEmpty) {
                        for (final doc in snap.data!.docs) {
                          debugPrint(
                              'Found installment: ${doc.id}, data: ${doc.data()}');
                        }
                      }
                      final set = <String>{};
                      final map = <String,
                          QueryDocumentSnapshot<Map<String, dynamic>>>{};
                      // Derive period bucketing from loan data
                      final freq = (t['frequency'] ?? 'Monthly') as String;
                      int periodMonths;
                      switch (freq) {
                        case 'Quarterly':
                          periodMonths = 3;
                          break;
                        case 'Half Yearly':
                          periodMonths = 6;
                          break;
                        default:
                          periodMonths = 1;
                      }
                      DateTime start = DateTime.now();
                      final sd = t['startDate'];
                      if (sd is Timestamp) {
                        start = sd.toDate();
                      } else {
                        final createdAt = t['createdAt'];
                        if (createdAt is Timestamp) start = createdAt.toDate();
                      }

                      if (snap.hasData) {
                        debugPrint(
                            'Processing ${snap.data!.docs.length} installments for loan matching');
                        for (final d in snap.data!.docs) {
                          final ts = d.data()['date'];
                          if (ts is Timestamp) {
                            final dt = ts.toDate();
                            debugPrint(
                                'Installment date: $dt, Loan start: $start');
                            // Compute period index bucket relative to start
                            int monthsDiff = (dt.year - start.year) * 12 +
                                (dt.month - start.month);
                            if (monthsDiff < 0) monthsDiff = 0;
                            final idx = (monthsDiff / periodMonths).floor();
                            final key = idx.toString();
                            debugPrint(
                                'Months diff: $monthsDiff, Period index: $idx, Key: $key');
                            set.add(key);
                            // Keep the earliest doc for that bucket as representative
                            map.putIfAbsent(key, () => d);
                          }
                        }
                        debugPrint('Final paid keys: $set');

                        // Check if loan is fully paid based on amortization table state
                        final tenureMonths = (t['tenureMonths'] is num)
                            ? (t['tenureMonths'] as num).toDouble()
                            : 0.0;
                        int totalPeriods;
                        switch (freq) {
                          case 'Quarterly':
                            totalPeriods = (tenureMonths / 3.0).round();
                            break;
                          case 'Half Yearly':
                            totalPeriods = (tenureMonths / 6.0).round();
                            break;
                          default:
                            totalPeriods = tenureMonths.round();
                        }

                        final alreadyClosed =
                            (t['status']?.toString().toLowerCase() == 'closed');
                        final paidCount = set.length;
                        debugPrint(
                            'Amortization completion check: totalPeriods=$totalPeriods, paidCount=$paidCount, alreadyClosed=$alreadyClosed');

                        if (!alreadyClosed &&
                            paidCount >= totalPeriods &&
                            totalPeriods > 0) {
                          debugPrint(
                              'All periods marked paid in amortization table! Will mark loan as closed.');
                          // Update loan status to closed
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            // Perform async update
                            _markLoanClosed(
                                loanId, (t['name'] ?? 'Loan').toString());
                          }
                        }
                      }
                      return _amortizationTable(t,
                          paidKeys: set, paidDocByKey: map);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      );
    }));
  }

  Widget _amortizationTable(Map<String, dynamic> t,
      {Set<String>? paidKeys,
      Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>? paidDocByKey}) {
    final cs = Theme.of(context).colorScheme;
    final paidBg =
        Color.alphaBlend(Colors.green.withValues(alpha: 0.18), cs.surface);

    double principal =
        (t['principal'] is num) ? (t['principal'] as num).toDouble() : 0.0;
    double annualRatePct = (t['annualRate'] is num)
        ? (t['annualRate'] as num).toDouble()
        : 0.0; // %
    double annualRate = annualRatePct / 100.0;
    double months = (t['tenureMonths'] is num)
        ? (t['tenureMonths'] as num).toDouble()
        : 0.0;
    final freq = (t['frequency'] ?? 'Monthly') as String;

    // Determine periods and rate per period by frequency
    int periodMonths;
    int totalPeriods;
    double rPerPeriod;
    switch (freq) {
      case 'Quarterly':
        periodMonths = 3;
        totalPeriods = (months / 3.0).round();
        rPerPeriod = annualRate / 4.0;
        break;
      case 'Half Yearly':
        periodMonths = 6;
        totalPeriods = (months / 6.0).round();
        rPerPeriod = annualRate / 2.0;
        break;
      default:
        periodMonths = 1;
        totalPeriods = months.round();
        rPerPeriod = annualRate / 12.0;
    }

    // EMI per period (use stored if present)
    double emi =
        (t['computedEmi'] is num) ? (t['computedEmi'] as num).toDouble() : 0.0;
    if (emi <= 0) {
      if (rPerPeriod == 0) {
        emi = principal / totalPeriods;
      } else {
        double factor = 1.0;
        for (int i = 0; i < totalPeriods; i++) {
          factor *= (1 + rPerPeriod);
        }
        emi = principal * rPerPeriod * factor / (factor - 1);
      }
    }

    // Start date: prefer startDate, else createdAt, else now
    DateTime start = DateTime.now();
    final sd = t['startDate'];
    if (sd is Timestamp) {
      start = sd.toDate();
    } else {
      final createdAt = t['createdAt'];
      if (createdAt is Timestamp) start = createdAt.toDate();
    }

    // Currency context for this loan (default to INR)
    final loanCurrency = (t['currency'] ?? 'INR') as String;
    final currencyFormatter = _getCurrencyFormatter();

    // Build rows
    double balance = principal;
    final rows = <DataRow>[];
    DateTime periodDate = start;
    for (int i = 1; i <= totalPeriods; i++) {
      final opening = balance;
      final interest = opening * rPerPeriod;
      double principalPart = emi - interest;
      if (principalPart > balance) {
        principalPart = balance;
      }
      final closing = opening - principalPart;
      // Use start date for first row, then add period months
      periodDate = _addMonths(start, periodMonths * (i - 1));
      // Capture a stable copy for this row so callbacks don't see the
      // mutated loop variable value later.
      final rowDate = periodDate;
      // Use period index key for matching instead of exact date to allow flexible paid dates within the period
      final indexKey = (i - 1).toString();
      final isPaid = paidKeys?.contains(indexKey) ?? false;
      rows.add(DataRow(
        color: isPaid ? WidgetStatePropertyAll(paidBg) : null,
        cells: [
          DataCell(Text(i.toString())),
          DataCell(Text(DateFormat('d MMM yyyy').format(rowDate))),
          DataCell(Text(
              currencyFormatter.format(_convertAmount(opening, loanCurrency)))),
          DataCell(Text(currencyFormatter
              .format(_convertAmount(interest, loanCurrency)))),
          DataCell(Text(currencyFormatter
              .format(_convertAmount(principalPart, loanCurrency)))),
          DataCell(Text(
              currencyFormatter.format(_convertAmount(emi, loanCurrency)))),
          DataCell(Text(
              currencyFormatter.format(_convertAmount(closing, loanCurrency)))),
          DataCell(
            isPaid
                ? Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (val) async {
                          final doc = paidDocByKey?[indexKey];
                          if (doc == null) return;
                          if (val == 'delete') {
                            _deleteInstallmentWithUndo(
                                doc.reference, doc.data());
                          } else if (val == 'edit') {
                            _openEditInstallmentDialog(
                                doc.reference, doc.data());
                          }
                        },
                      )
                    ],
                  )
                : PopupMenuButton<String>(
                    tooltip: 'Actions',
                    icon: const Icon(Icons.more_horiz_rounded),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                          value: 'add', child: Text('Add Installment')),
                    ],
                    onSelected: (val) {
                      if (val == 'add') {
                        _prefillAndOpenInstallmentSheet(
                          t,
                          dateOverride: rowDate,
                          amountOverride: emi,
                        );
                      }
                    },
                  ),
          ),
        ],
      ));
      balance = closing;
      if (balance <= 0.0001) break;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
            Radius.circular(10)), // Reduced from 12 proportionally
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 680),
          child: SingleChildScrollView(
            child: DataTable(
              headingTextStyle:
                  TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Opening')),
                DataColumn(label: Text('Interest')),
                DataColumn(label: Text('Principal')),
                DataColumn(label: Text('EMI')),
                DataColumn(label: Text('Closing')),
                DataColumn(label: Text('')),
              ],
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      // Clear all text fields aggressively
      _loanNameCtrl.clear();
      _lenderCtrl.clear();
      _amountCtrl.clear();
      _rateCtrl.clear();
      _tenureCtrl.clear();
      _processingCtrl.clear();

      // Reset dropdowns and selections
      _frequency = _frequencyMonthly;
      _loanType = homeLoan;
      _startDate = DateTime.now();
      _paymentType = regularEMI;

      // Clear computed results
      _emi = null;
      _totalPayment = null;
      _totalInterest = null;

      // Reset form state and clear validation errors
      _formKey?.currentState?.reset();
      _formKey?.currentState?.validate(); // Re-validate to clear error states
    });

    // Force a second update to ensure UI reflects the changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _openAddLoanSheet() {
    // Create a fresh form key first
    _formKey = GlobalKey<FormState>();

    // Reset form to ensure blank fields
    _reset();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return AddLoanSheet(
          formKey: _formKey,
          loanNameCtrl: _loanNameCtrl,
          lenderCtrl: _lenderCtrl,
          amountCtrl: _amountCtrl,
          rateCtrl: _rateCtrl,
          tenureCtrl: _tenureCtrl,
          processingCtrl: _processingCtrl,
          currencyCode: _currentCurrency,
          currencySymbol: CurrencyService.getCurrencySymbol(_currentCurrency),
          frequency: _frequency,
          loanType: _loanType,
          startDate: _startDate,
          vRequired: vRequired,
          vMoney: vMoney,
          vRate: vRate,
          vTenure: vTenure,
          onReset: _reset,
          onPickStartDate: _pickStartDate,
          onSaveLoan: _saveLoan,
          onFrequencyChanged: (val) {
            setState(() => _frequency = val);
          },
        );
      },
    );
  }

  void _openAddInstallmentSheet() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 14, // Reduced from 16 proportionally
            right: 14, // Reduced from 16 proportionally
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                14, // Reduced from 16 proportionally
            top: 7, // Reduced from 8 proportionally
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  Icons.add_task_rounded,
                  color: theme.brightness == Brightness.dark
                      ? cs.primary.withValues(alpha: 0.9)
                      : cs.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Installment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.brightness == Brightness.dark
                        ? cs.onSurface.withValues(alpha: 0.9)
                        : cs.onSurface,
                  ),
                ),
              ]),
              const SizedBox(height: 10), // Reduced from 12 proportionally
              TextField(
                controller: _instLoanNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Loan Name',
                  prefixIcon: Icon(
                    Icons.badge_rounded,
                    color: theme.brightness == Brightness.dark
                        ? cs.onSurface.withValues(alpha: 0.6)
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? cs.surfaceContainer.withValues(alpha: 0.6)
                      : cs.surfaceContainer.withValues(alpha: 0.2),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? cs.outline.withValues(alpha: 0.3)
                          : cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? cs.outline.withValues(alpha: 0.3)
                          : cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? cs.onSurface.withValues(alpha: 0.9)
                      : cs.onSurface.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10), // Reduced from 12 proportionally
              TextFormField(
                controller: _instAmountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Installment Amount',
                  prefixText:
                      '${CurrencyService.getCurrencySymbol(_currentCurrency)} ',
                  prefixStyle: TextStyle(
                    color: theme.brightness == Brightness.dark
                        ? cs.onSurface.withValues(alpha: 0.9)
                        : cs.onSurface.withValues(alpha: 0.85),
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? cs.surfaceContainer.withValues(alpha: 0.6)
                      : cs.surfaceContainer.withValues(alpha: 0.2),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? cs.outline.withValues(alpha: 0.3)
                          : cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? cs.outline.withValues(alpha: 0.3)
                          : cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? cs.onSurface.withValues(alpha: 0.9)
                      : cs.onSurface.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10), // Reduced from 12 proportionally
              // Date Picker Field
              InkWell(
                onTap: _pickInstDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Installment Date',
                    prefixIcon: Icon(
                      Icons.calendar_today_rounded,
                      color: theme.brightness == Brightness.dark
                          ? cs.onSurface.withValues(alpha: 0.6)
                          : cs.onSurface.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark
                        ? cs.surfaceContainer.withValues(alpha: 0.6)
                        : cs.surfaceContainer.withValues(alpha: 0.2),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? cs.outline.withValues(alpha: 0.3)
                            : cs.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? cs.outline.withValues(alpha: 0.3)
                            : cs.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: cs.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _instDate == null
                        ? 'Select a date'
                        : DateFormat('MMMM d, y').format(_instDate!),
                    style: TextStyle(
                      color: _instDate == null
                          ? (theme.brightness == Brightness.dark
                              ? cs.onSurface.withValues(alpha: 0.5)
                              : cs.onSurface.withValues(alpha: 0.4))
                          : (theme.brightness == Brightness.dark
                              ? cs.onSurface.withValues(alpha: 0.9)
                              : cs.onSurface.withValues(alpha: 0.85)),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10), // Reduced from 12 proportionally
              DropdownButtonFormField<String>(
                value: _paymentType,
                items: const [
                  DropdownMenuItem(
                      value: 'Regular EMI', child: Text('Regular EMI')),
                  DropdownMenuItem(
                      value: 'Extra/Prepayment',
                      child: Text('Extra/Prepayment')),
                ],
                onChanged: (v) =>
                    setState(() => _paymentType = v ?? 'Regular EMI'),
                decoration: InputDecoration(
                  labelText: 'Payment Type',
                  prefixIcon: Icon(
                    Icons.tune_rounded,
                    color: theme.brightness == Brightness.dark
                        ? cs.onSurface.withValues(alpha: 0.6)
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? cs.surfaceContainer.withValues(alpha: 0.6)
                      : cs.surfaceContainer.withValues(alpha: 0.2),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? cs.outline.withValues(alpha: 0.3)
                          : cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? cs.outline.withValues(alpha: 0.3)
                          : cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? cs.onSurface.withValues(alpha: 0.9)
                      : cs.onSurface.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14), // Reduced from 16 proportionally
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const StadiumBorder(),
                      elevation: theme.brightness == Brightness.dark ? 2 : 1,
                      shadowColor: theme.brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.3)
                          : cs.shadow.withValues(alpha: 0.2),
                    ),
                    onPressed: () async {
                      try {
                        await _saveInstallment();
                      } finally {
                        if (mounted) Navigator.of(ctx).pop();
                      }
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Installment'),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  void _pickStartDate() async {
    final now = DateTime.now();
    // Normalize current _startDate to local timezone
    final localStartDate =
        DateTime(_startDate.year, _startDate.month, _startDate.day);

    final d = await showDatePicker(
      context: context,
      firstDate:
          DateTime(now.year - 50, 1, 1), // Start from Jan 1st, 50 years ago
      lastDate: DateTime(
          now.year + 50, 12, 31), // End on Dec 31st, 50 years in future
      initialDate: localStartDate,
      initialDatePickerMode:
          DatePickerMode.day, // Ensure day picker is shown by default
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            textTheme: Theme.of(context).textTheme,
          ),
          child: child!,
        );
      },
    );
    if (d != null) {
      // Store only the date part to avoid timezone issues
      setState(() => _startDate = DateTime(d.year, d.month, d.day));
    }
  }

  // Add Installment helpers
  void _pickInstDate() async {
    final now = DateTime.now();
    // Use current date as initial if _instDate is null, otherwise normalize to local timezone
    final initialDate = _instDate ?? now;
    final localInstDate =
        DateTime(initialDate.year, initialDate.month, initialDate.day);

    final d = await showDatePicker(
      context: context,
      firstDate:
          DateTime(now.year - 50, 1, 1), // Start from Jan 1st, 50 years ago
      lastDate: DateTime(
          now.year + 50, 12, 31), // End on Dec 31st, 50 years in future
      initialDate: localInstDate,
      initialDatePickerMode:
          DatePickerMode.day, // Ensure day picker is shown by default
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            // Ensure proper text style for the date picker
            textTheme: Theme.of(context).textTheme,
          ),
          child: child!,
        );
      },
    );
    if (d != null) {
      // Store only the date part to avoid timezone issues
      setState(() => _instDate = DateTime(d.year, d.month, d.day));
    }
  }

  Future<void> _saveInstallment() async {
    final loanName = _instLoanNameCtrl.text.trim();
    final rawAmount = _instAmountCtrl.text.trim();
    if (loanName.isEmpty || rawAmount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final amount = double.tryParse(rawAmount.replaceAll(
        RegExp(r'[^\d.]'), '')); // Remove all non-numeric chars except dots
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_instDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    await InstallmentService.saveInstallment(
      context: context,
      loanName: loanName,
      amount: amount,
      instDate: _instDate!,
      paymentType: _paymentType,
      instLoanId: _instLoanId,
    );

    if (!mounted) return;
    setState(() {
      // Keep current values; the bottom sheet caller is responsible for closing
      debugPrint(
          'Installment saved via service; leaving form values as-is before sheet is closed.');
    });
  }

  Future<void> _markLoanClosed(String loanId, String loanName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final loanRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('loans')
          .doc(loanId);
      await loanRef.update({
        'status': 'Closed',
        'closedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      debugPrint('Loan "$loanName" marked as closed');
    } catch (e) {
      debugPrint('Error marking loan closed: $e');
    }
  }

  Future<void> _saveLoan() async {
    if (_formKey?.currentState?.validate() != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save loans')),
      );
      return;
    }

    try {
      final name = _loanNameCtrl.text.trim();
      final lender = _lenderCtrl.text.trim();
      final principal =
          double.parse(_amountCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''));
      final annualRate =
          double.parse(_rateCtrl.text.replaceAll(RegExp(r'[^\d.]'), '')) /
              100.0;
      final tenureMonths =
          double.parse(_tenureCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''));
      final processingFee =
          double.parse(_processingCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''));

      await LoanService.saveLoan(
        context: context,
        name: name,
        lender: lender,
        principal: principal,
        annualRate: annualRate,
        tenureMonths: tenureMonths,
        processingFee: processingFee,
        frequency: _frequency,
        loanType: _loanType,
        startDate: _startDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loan "$name" saved')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save loan: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save loan: $e')),
      );
    }
  }

  // ignore: unused_element
  void _calculate() {
    if (_formKey?.currentState?.validate() != true) return;

    final P = double.parse(_amountCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''));
    final annualRate =
        double.parse(_rateCtrl.text.replaceAll(RegExp(r'[^\d.]'), '')) / 100.0;

    int totalPeriods;
    double ratePerPeriod;

    // Tenure is provided in months
    final months =
        double.parse(_tenureCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''));
    switch (_frequency) {
      case 'Quarterly':
        totalPeriods = (months / 3.0).round();
        ratePerPeriod = annualRate / 4.0;
        break;
      case 'Half Yearly':
        totalPeriods = (months / 6.0).round();
        ratePerPeriod = annualRate / 2.0;
        break;
      default: // Monthly
        totalPeriods = months.round();
        ratePerPeriod = annualRate / 12.0;
    }

    double emi;
    if (ratePerPeriod == 0) {
      emi = P / totalPeriods;
    } else {
      // Prefer function declaration over assigning a closure to a variable
      double pow(double a, int b) {
        double res = 1.0;
        for (int i = 0; i < b; i++) {
          res *= a;
        }
        return res;
      }

      final factor = pow(1 + ratePerPeriod, totalPeriods);
      emi = P * ratePerPeriod * factor / (factor - 1);
    }
    final totalPayment = emi * totalPeriods;
    final totalInterest = totalPayment - P;

    setState(() {
      _emi = emi;
      _totalPayment = totalPayment;
      _totalInterest = totalInterest;
    });
  }

  void _showInfo() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
            18, 7, 18, 18), // Reduced from 20,8,20,20 proportionally
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text('Loan Planner',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  )),
            ]),
            const SizedBox(height: 8), // Reduced from 10 proportionally
            Text(
              'Plan and understand your loan repayments. Enter the principal, interest rate, tenure, and payment frequency to compute the installment, total payment, and interest.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Planner'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'What is this?',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfo,
          ),
        ],
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(
                  14.0), // Reduced from 16.0 proportionally
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14,
                      16), // Reduced from 16,16,16,32 proportionally
                  children: [
                    Text('Plan your loan',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        )),
                    const SizedBox(
                        height: 10), // Reduced from 12 proportionally
                    // Top action buttons (compact pill buttons)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _openAddLoanSheet,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical:
                                    7), // Reduced from 16,8 proportionally
                            minimumSize: const Size(
                                110, 36), // Reduced from 120,40 proportionally
                            visualDensity: VisualDensity.compact,
                            shape: const StadiumBorder(),
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            elevation: 0,
                            textStyle: theme.textTheme.labelLarge,
                          ),
                          icon: const Icon(Icons.add_card_rounded, size: 18),
                          label: const Text('Add Loan',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(
                        height: 14), // Reduced from 16 proportionally
                    // Your Loans list
                    _yourLoansSection(),
                    const SizedBox(
                        height: 14), // Reduced from 16 proportionally
                    if (_emi != null) ...[
                      Container(
                        padding: const EdgeInsets.all(
                            14), // Reduced from 16 proportionally
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(
                              14)), // Reduced from 16 proportionally
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.25),
                          border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Results',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(
                                height: 7), // Reduced from 8 proportionally
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _kpiChip(context, 'Installment',
                                    '₹ ${_nf.format(_emi!.round())}'),
                                _kpiChip(context, 'Total Payment',
                                    '₹ ${_nf.format(_totalPayment!.round())}'),
                                _kpiChip(context, 'Total Interest',
                                    '₹ ${_nf.format(_totalInterest!.round())}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                          height: 14), // Reduced from 16 proportionally
                      Container(
                        padding: const EdgeInsets.all(
                            14), // Reduced from 16 proportionally
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(
                              14)), // Reduced from 16 proportionally
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.25),
                          border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Schedule (summary)',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(
                                height: 7), // Reduced from 8 proportionally
                            Text(
                              'An amortization schedule view will appear here with breakdowns by period. Coming soon.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.75)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiChip(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 7), // Reduced from 12,8 proportionally
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: const BorderRadius.all(
            Radius.circular(8)), // Reduced from 10 proportionally
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
        ],
      ),
    );
  }
}
