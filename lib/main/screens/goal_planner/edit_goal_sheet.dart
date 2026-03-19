import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/settings_service.dart';
import '../../../services/currency_service.dart';

class EditGoalSheet extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> goalRef;
  final Map<String, dynamic> data;

  const EditGoalSheet({
    super.key,
    required this.goalRef,
    required this.data,
  });

  @override
  State<EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<EditGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _savedCtrl;
  DateTime? _targetDate;
  String _status = 'active';
  bool _saving = false;
  String _currencySymbol = '₹';
  Timer? _debounce;
  late final Map<String, Object?> _original;

  Future<void> _loadCurrencySymbol() async {
    final code = await SettingsService.getSelectedCurrency();
    if (!mounted) return;
    setState(() {
      _currencySymbol = CurrencyService.getCurrencySymbol(code);
    });
  }

  String? _vRequired(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _vMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite) return 'Enter a valid number';
    if (x < 0) return 'Must be ≥ 0';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
    final d = widget.data;
    _nameCtrl = TextEditingController(text: (d['title'] ?? '').toString());
    _categoryCtrl =
        TextEditingController(text: (d['category'] ?? 'General').toString());
    final target = (d['targetAmount'] as num?)?.toDouble() ?? 0.0;
    final saved = (d['currentSavings'] as num?)?.toDouble() ?? 0.0;
    _targetCtrl = TextEditingController(text: target.toStringAsFixed(2));
    _savedCtrl = TextEditingController(text: saved.toStringAsFixed(2));
    _status = (d['status'] as String?)?.toLowerCase() ?? 'active';
    final ts = d['targetDate'] as Timestamp?;
    _targetDate = ts?.toDate();

    _original = {
      'title': _nameCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'targetAmount': target,
      'currentSavings': saved,
      'status': _status,
      'targetDate': _targetDate,
    };

    _nameCtrl.addListener(_onFieldChanged);
    _categoryCtrl.addListener(_onFieldChanged);
    _targetCtrl.addListener(_onFieldChanged);
    _savedCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _targetCtrl.dispose();
    _savedCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFieldChanged() {
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _autoSaveIfValid);
  }

  Future<void> _autoSaveIfValid() async {
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;
    final parsedTarget =
        double.tryParse(_targetCtrl.text.replaceAll(',', '')) ??
            (_original['targetAmount'] as double? ?? 0);
    final parsedSaved = double.tryParse(_savedCtrl.text.replaceAll(',', '')) ??
        (_original['currentSavings'] as double? ?? 0);

    bool changed = false;
    Map<String, Object?> updates = {};
    String title = _nameCtrl.text.trim();
    if (title != _original['title']) {
      updates['title'] = title;
      changed = true;
    }
    String category = _categoryCtrl.text.trim();
    if (category != _original['category']) {
      updates['category'] = category;
      changed = true;
    }
    double t = parsedTarget;
    if (((_original['targetAmount'] as double?) ?? 0) != t) {
      updates['targetAmount'] = t;
      changed = true;
    }
    double s = parsedSaved;
    if (((_original['currentSavings'] as double?) ?? 0) != s) {
      updates['currentSavings'] = s;
      changed = true;
    }
    if (_status != (_original['status'] as String? ?? 'active')) {
      updates['status'] = _status;
      changed = true;
    }
    if (!isSameDate(_targetDate, _original['targetDate'] as DateTime?)) {
      updates['targetDate'] =
          _targetDate == null ? null : Timestamp.fromDate(_targetDate!);
      changed = true;
    }
    if (!changed) return;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    try {
      await widget.goalRef.update(updates);
      // Update originals to current values to prevent repeated writes
      _original
        ..['title'] = title
        ..['category'] = category
        ..['targetAmount'] = t
        ..['currentSavings'] = s
        ..['status'] = _status
        ..['targetDate'] = _targetDate;
    } catch (_) {}
  }

  bool isSameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
                  Icons.edit_rounded,
                  color: theme.brightness == Brightness.dark
                      ? cs.primary.withValues(alpha: 0.9)
                      : cs.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edit Goal',
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
                labelText: 'Current savings',
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
            Row(children: [
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
                      initialDate:
                          _targetDate ?? now.add(const Duration(days: 30)),
                      firstDate: now,
                      lastDate: DateTime(now.year + 30),
                    );
                    if (picked != null) {
                      setState(() => _targetDate = picked);
                      _scheduleAutoSave();
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
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: InputDecoration(
                labelText: 'Status',
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
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'paused', child: Text('Paused')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
              ],
              onChanged: (v) {
                setState(() => _status = v ?? 'active');
                _scheduleAutoSave();
              },
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
                  : const Icon(Icons.save_rounded),
              label: const Text('Save changes'),
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
      final target = double.parse(_targetCtrl.text.replaceAll(',', ''));
      final saved = double.parse(_savedCtrl.text.replaceAll(',', ''));
      await widget.goalRef.update({
        'title': _nameCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'status': _status,
        'targetAmount': target,
        'currentSavings': saved,
        'targetDate':
            _targetDate == null ? null : Timestamp.fromDate(_targetDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
