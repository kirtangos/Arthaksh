import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/settings_service.dart';
import '../../../services/currency_service.dart';

class NewGoalSheet extends StatefulWidget {
  const NewGoalSheet({super.key});

  @override
  State<NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends State<NewGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _savedCtrl = TextEditingController();
  DateTime? _targetDate;
  bool _saving = false;
  String _currencySymbol = '₹';

  String? _vRequired(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
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

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x < 0) return 'Must be ≥ 0';
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _targetCtrl.dispose();
    _savedCtrl.dispose();
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
                  Icons.add_task_rounded,
                  color: theme.brightness == Brightness.dark
                      ? cs.primary.withValues(alpha: 0.9)
                      : cs.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Create New Goal',
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
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Goal title',
                hintText: 'e.g. Vacation Fund',
                hintStyle: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? cs.onSurface.withValues(alpha: 0.5)
                      : cs.onSurface.withValues(alpha: 0.4),
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
              textInputAction: TextInputAction.next,
              validator: _vRequired,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _categoryCtrl,
              decoration: InputDecoration(
                labelText: 'Category',
                hintText: 'e.g. Travel',
                hintStyle: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? cs.onSurface.withValues(alpha: 0.5)
                      : cs.onSurface.withValues(alpha: 0.4),
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
              textInputAction: TextInputAction.next,
              validator: _vRequired,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _targetCtrl,
              decoration: InputDecoration(
                labelText: 'Target amount',
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
              textInputAction: TextInputAction.next,
              validator: _vMoney,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _savedCtrl,
              decoration: InputDecoration(
                labelText: 'Already saved',
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
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now.add(const Duration(days: 30)),
                        firstDate: now,
                        lastDate: DateTime(now.year + 30),
                      );
                      if (picked != null) {
                        setState(() => _targetDate = picked);
                      }
                    },
                    icon: Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: theme.brightness == Brightness.dark
                          ? cs.onSurface.withValues(alpha: 0.8)
                          : cs.onSurface,
                    ),
                    label: Text(
                      _targetDate == null
                          ? 'Pick target date'
                          : DateFormat.yMMMd().format(_targetDate!),
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
              label: const Text('Save Goal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final target = double.parse(_targetCtrl.text.replaceAll(',', ''));
      final saved = double.parse(_savedCtrl.text.replaceAll(',', ''));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .add({
        'title': _nameCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'status': 'active',
        'targetAmount': target,
        'currentSavings': saved,
        'targetDate':
            _targetDate == null ? null : Timestamp.fromDate(_targetDate!),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
