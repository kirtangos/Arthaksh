import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/ui/app_input.dart';

// Payment frequency constants
const String _frequencyMonthly = 'Monthly';
const String _frequencyQuarterly = 'Quarterly';
const String _frequencyHalfYearly = 'Half Yearly';

/// A standalone bottom sheet widget for adding new loans
class AddLoanSheet extends StatefulWidget {
  final GlobalKey<FormState>? formKey;
  final TextEditingController loanNameCtrl;
  final TextEditingController lenderCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController tenureCtrl;
  final TextEditingController processingCtrl;
  final String currencyCode;
  final String currencySymbol;
  final String frequency;
  final String loanType;
  final DateTime startDate;
  final String? Function(String?) vRequired;
  final String? Function(String?) vMoney;
  final String? Function(String?) vRate;
  final String? Function(String?) vTenure;
  final VoidCallback onReset;
  final VoidCallback onPickStartDate;
  final Future<void> Function() onSaveLoan;
  final Function(String) onFrequencyChanged;

  const AddLoanSheet({
    super.key,
    required this.formKey,
    required this.loanNameCtrl,
    required this.lenderCtrl,
    required this.amountCtrl,
    required this.rateCtrl,
    required this.tenureCtrl,
    required this.processingCtrl,
    required this.currencyCode,
    required this.currencySymbol,
    required this.frequency,
    required this.loanType,
    required this.startDate,
    required this.vRequired,
    required this.vMoney,
    required this.vRate,
    required this.vTenure,
    required this.onReset,
    required this.onPickStartDate,
    required this.onSaveLoan,
    required this.onFrequencyChanged,
  });

  @override
  State<AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<AddLoanSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 14, // Reduced from 16 proportionally
        right: 14, // Reduced from 16 proportionally
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
        top: 4, // Reduced from 7 to make sheet pull up longer
      ),
      child: SingleChildScrollView(
        child: Form(
          key: widget.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  Icons.add_card_rounded,
                  color: theme.brightness == Brightness.dark
                      ? cs.primary.withValues(alpha: 0.9)
                      : cs.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Loan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.brightness == Brightness.dark
                        ? cs.onSurface.withValues(alpha: 0.9)
                        : cs.onSurface,
                  ),
                ),
              ]),
              const SizedBox(height: 10), // Reduced from 12 proportionally
              // Gradient panel like Lumpsum (subtle teal)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  gradient: theme.brightness == Brightness.dark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.surfaceContainerHighest.withValues(alpha: 0.4),
                            cs.surfaceContainer.withValues(alpha: 0.2),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.secondary.withValues(alpha: 0.08),
                            cs.secondaryContainer.withValues(alpha: 0.06),
                          ],
                        ),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? cs.outline.withValues(alpha: 0.3)
                        : cs.outlineVariant,
                    width: 1,
                  ),
                  boxShadow: theme.brightness == Brightness.dark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppInput(
                        controller: widget.loanNameCtrl,
                        label: 'Loan Name',
                        prefixIcon: const Icon(Icons.badge_rounded),
                        validator: widget.vRequired,
                        textInputAction: TextInputAction.next,
                        alwaysShowClear: true,
                      ),
                      const SizedBox(height: 10),
                      AppInput(
                        controller: widget.lenderCtrl,
                        label: 'Lender Name',
                        prefixIcon: const Icon(Icons.account_balance_rounded),
                        validator: widget.vRequired,
                        textInputAction: TextInputAction.next,
                        alwaysShowClear: true,
                      ),
                      const SizedBox(height: 10),
                      AppInput(
                        controller: widget.amountCtrl,
                        label: 'Loan Amount',
                        prefixText: '${widget.currencySymbol} ',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        validator: widget.vMoney,
                        textInputAction: TextInputAction.next,
                        alwaysShowClear: true,
                      ),
                      const SizedBox(height: 10),
                      AppInput(
                        controller: widget.rateCtrl,
                        label: 'Annual Interest Rate',
                        suffixText: '%',
                        prefixIcon: const Icon(Icons.percent_rounded),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        validator: widget.vRate,
                        textInputAction: TextInputAction.next,
                        alwaysShowClear: true,
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: AppInput(
                            controller: widget.tenureCtrl,
                            label: 'Tenure (months)',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(right: 0, left: 6),
                              child: Icon(Icons.schedule_rounded,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 10),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: widget.vTenure,
                            textInputAction: TextInputAction.next,
                            alwaysShowClear: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppInput(
                            controller: widget.processingCtrl,
                            label: 'Processing',
                            prefixText: '${widget.currencySymbol} ',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]')),
                            ],
                            validator: widget.vMoney,
                            textInputAction: TextInputAction.next,
                            alwaysShowClear: true,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        'Payment Frequency',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: theme.brightness == Brightness.dark
                                  ? cs.onSurface.withValues(alpha: 0.8)
                                  : cs.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: widget.frequency,
                        decoration: InputDecoration(
                          labelText: 'Select Frequency',
                          prefixIcon: Icon(
                            Icons.schedule_rounded,
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
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark
                              ? cs.onSurface.withValues(alpha: 0.9)
                              : cs.onSurface.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: _frequencyMonthly,
                              child: Text(' Monthly')),
                          DropdownMenuItem(
                              value: _frequencyQuarterly,
                              child: Text('Quarterly')),
                          DropdownMenuItem(
                              value: _frequencyHalfYearly,
                              child: Text(' Half   - Yearly')),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          widget.onFrequencyChanged(val);
                        },
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        onTap: widget.onPickStartDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            prefixIcon: Icon(
                              Icons.event_rounded,
                              color: theme.brightness == Brightness.dark
                                  ? cs.onSurface.withValues(alpha: 0.6)
                                  : cs.onSurface.withValues(alpha: 0.5),
                            ),
                            hintText: 'Select date',
                            hintStyle: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? cs.onSurface.withValues(alpha: 0.5)
                                  : cs.onSurface.withValues(alpha: 0.4),
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
                            DateFormat('MMM d, yyyy').format(widget.startDate),
                            style: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? cs.onSurface.withValues(alpha: 0.9)
                                  : cs.onSurface.withValues(alpha: 0.85),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onReset,
                    icon: Icon(
                      Icons.restart_alt_rounded,
                      color: theme.brightness == Brightness.dark
                          ? cs.onSurface.withValues(alpha: 0.8)
                          : cs.onSurface,
                    ),
                    label: Text(
                      'Reset',
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? cs.onSurface.withValues(alpha: 0.8)
                            : cs.onSurface,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? cs.outline.withValues(alpha: 0.4)
                            : cs.outline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                      if (widget.formKey?.currentState?.validate() == true) {
                        await widget.onSaveLoan();
                        if (!mounted) return;

                        // Close the bottom sheet immediately after successful save
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Loan'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
