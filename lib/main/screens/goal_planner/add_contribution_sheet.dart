import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/settings_service.dart';
import '../../../services/currency_service.dart';

class AddContributionSheet extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> goalRef;
  final VoidCallback? onCompleted;

  const AddContributionSheet({
    super.key,
    required this.goalRef,
    this.onCompleted,
  });

  @override
  State<AddContributionSheet> createState() => _AddContributionSheetState();
}

class _AddContributionSheetState extends State<AddContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String _currencySymbol = '₹';

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x <= 0) return 'Must be > 0';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
  }

  Future<void> _loadCurrencySymbol() async {
    final code = await SettingsService.getSelectedCurrency();
    if (!mounted) return;
    setState(() {
      _currencySymbol = CurrencyService.getCurrencySymbol(code);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 8,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_card_rounded,
                  color: theme.brightness == Brightness.dark
                      ? cs.primary.withValues(alpha: 0.9)
                      : cs.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Contribution',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.brightness == Brightness.dark
                        ? cs.onSurface.withValues(alpha: 0.9)
                        : cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '$_currencySymbol ',
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: _vMoney,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? cs.outline.withValues(alpha: 0.4)
                            : cs.outline,
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(DateTime.now().year + 30),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    icon: Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: theme.brightness == Brightness.dark
                          ? cs.onSurface.withValues(alpha: 0.8)
                          : cs.onSurface,
                    ),
                    label: Text(
                      DateFormat.yMMMd().format(_date),
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? cs.onSurface.withValues(alpha: 0.8)
                            : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(),
                elevation: theme.brightness == Brightness.dark ? 2 : 1,
                shadowColor: theme.brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.3)
                    : cs.shadow.withValues(alpha: 0.2),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
      // Transaction: read goal, add contribution, update totals, detect completion
      final becameComplete =
          await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
        final snap = await tx.get(widget.goalRef);
        final data = snap.data();
        final oldSaved = (data?['currentSavings'] as num?)?.toDouble() ?? 0.0;
        final target = (data?['targetAmount'] as num?)?.toDouble() ?? 0.0;
        final status = (data?['status'] as String?) ?? 'active';
        final newSaved = oldSaved + amount;
        final isCompleting = target > 0 &&
            oldSaved < target &&
            newSaved >= target &&
            status != 'completed';

        final contribRef = widget.goalRef.collection('contributions').doc();
        tx.set(contribRef, {
          'amount': amount,
          'date': Timestamp.fromDate(_date),
          'createdAt': FieldValue.serverTimestamp(),
        });
        final update = <String, Object?>{
          'currentSavings': newSaved,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (isCompleting) update['status'] = 'completed';
        tx.update(widget.goalRef, update);
        return isCompleting;
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Contribution added')));
      if (becameComplete && widget.onCompleted != null) {
        widget.onCompleted!();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
