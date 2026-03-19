import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/settings_service.dart';
import '../../services/currency_service.dart';
import '../../ui/noise_decoration.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  String _fromCurrency = 'USD';
  String _toCurrency = 'INR';
  double _amount = 1.0;
  double _convertedAmount = 0.0;
  bool _isLoading = false;
  String _lastUpdateTime = '';
  String _rateDate = '';

  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDefaultCurrencies();
    _amountController.text = _amount.toString();
  }

  Future<void> _loadDefaultCurrencies() async {
    final selectedCurrency = await SettingsService.getSelectedCurrency();
    if (mounted) {
      setState(() {
        _fromCurrency = selectedCurrency;
        _toCurrency = selectedCurrency == 'INR' ? 'USD' : 'INR';
      });
    }
  }

  Future<void> _convertCurrency() async {
    if (_amount <= 0) return;

    setState(() {
      _isLoading = true;
    });

    // Use enhanced currency service for better precision
    final rateInfo = await CurrencyService.getExchangeRateWithInfo(
        _fromCurrency, _toCurrency);
    final converted = await CurrencyService.convertAmount(
        _amount, _fromCurrency, _toCurrency);

    if (mounted) {
      setState(() {
        _convertedAmount = converted;
        _isLoading = false;
        _lastUpdateTime = rateInfo['timestamp'] ?? '';
        _rateDate = rateInfo['date'] ?? '';
      });
    }
  }

  // Auto-refresh rates
  Future<void> _refreshRates() async {
    await CurrencyService.refreshRates();
    if (_amount > 0) {
      await _convertCurrency();
    }
  }

  // Get currency symbol
  String _getCurrencySymbol(String currencyCode) {
    return CurrencyService.getCurrencySymbol(currencyCode);
  }

  // Format date time for display
  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter'),
        elevation: 0,
        centerTitle: false,
      ),
      body: Container(
        decoration: isDark
            ? const NoiseDecoration(
                color: Color(0xFF00897b),
                opacity: 0.02,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount Input - Enhanced with refined layered depth
              Container(
                margin: const EdgeInsets.symmetric(
                    vertical: 4), // Increased separation
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHigh // Layer 3 depth
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(
                          color: theme.colorScheme.outline.withValues(
                              alpha: 0.2), // Consistent with settings
                          width: 0.5,
                        )
                      : null,
                  boxShadow: isDark
                      ? [
                          // Enhanced layered shadows matching settings
                          BoxShadow(
                            color:
                                const Color(0xFF0A1416).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color:
                                const Color(0xFF1A1A1A).withValues(alpha: 0.6),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : [
                          // Light theme enhanced shadow
                          BoxShadow(
                            color: theme.colorScheme.shadow
                                .withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: isDark ? theme.colorScheme.onSurface : null,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          labelStyle: TextStyle(
                            color: isDark
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? theme.colorScheme.outline
                                      .withValues(alpha: 0.3)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? theme.colorScheme.outline
                                      .withValues(alpha: 0.2)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF00897b)
                                  : const Color(0xFF00897b),
                              width: 1.4,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? theme.colorScheme.surfaceContainerLow
                              : const Color(0xFFF3F4F6),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _amount = double.tryParse(value) ?? 0.0;
                          });
                          // Auto-convert on input change
                          if (_amount > 0) {
                            _convertCurrency();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _fromCurrency,
                              style: TextStyle(
                                color:
                                    isDark ? theme.colorScheme.onSurface : null,
                              ),
                              dropdownColor: isDark
                                  ? theme.colorScheme.surfaceContainerHigh
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'From',
                                labelStyle: TextStyle(
                                  color: isDark
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? theme.colorScheme.outline
                                            .withValues(alpha: 0.3)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? theme.colorScheme.outline
                                            .withValues(alpha: 0.2)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF00897b)
                                        : const Color(0xFF00897b),
                                    width: 1.4,
                                  ),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? theme.colorScheme.surfaceContainerLow
                                    : const Color(0xFFF3F4F6),
                              ),
                              items: SettingsService.majorCurrencies
                                  .map((currency) {
                                return DropdownMenuItem<String>(
                                  value: currency['code'],
                                  child: Text(
                                    '${currency['code']} - ${currency['name']}',
                                    style: TextStyle(
                                      color: isDark
                                          ? theme.colorScheme.onSurface
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _fromCurrency = value!;
                                });
                                // Auto-convert when currency changes
                                if (_amount > 0) {
                                  _convertCurrency();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.arrow_forward,
                            color: isDark
                                ? const Color(0xFF00897b)
                                : colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _toCurrency,
                              style: TextStyle(
                                color:
                                    isDark ? theme.colorScheme.onSurface : null,
                              ),
                              dropdownColor: isDark
                                  ? theme.colorScheme.surfaceContainerHigh
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'To',
                                labelStyle: TextStyle(
                                  color: isDark
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? theme.colorScheme.outline
                                            .withValues(alpha: 0.3)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? theme.colorScheme.outline
                                            .withValues(alpha: 0.2)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF00897b)
                                        : const Color(0xFF00897b),
                                    width: 1.4,
                                  ),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? theme.colorScheme.surfaceContainerLow
                                    : const Color(0xFFF3F4F6),
                              ),
                              items: SettingsService.majorCurrencies
                                  .map((currency) {
                                return DropdownMenuItem<String>(
                                  value: currency['code'],
                                  child: Text(
                                    '${currency['code']} - ${currency['name']}',
                                    style: TextStyle(
                                      color: isDark
                                          ? theme.colorScheme.onSurface
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _toCurrency = value!;
                                });
                                // Auto-convert when currency changes
                                if (_amount > 0) {
                                  _convertCurrency();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Refresh Button - Enhanced with dark theme
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _convertCurrency,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF00897b).withValues(alpha: 0.8)
                            : null,
                        foregroundColor: Colors.white,
                        elevation: isDark ? 2 : 1,
                        shadowColor: isDark
                            ? const Color(0xFF0A1416).withValues(alpha: 0.4)
                            : null,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : const Text(
                              'Convert',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHigh
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: isDark
                          ? Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.15),
                              width: 0.5,
                            )
                          : null,
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0A1416)
                                    .withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: IconButton(
                      onPressed: _refreshRates,
                      icon: Icon(
                        Icons.refresh,
                        color: isDark
                            ? const Color(0xFF00897b)
                            : colorScheme.primary,
                      ),
                      tooltip: 'Refresh Exchange Rates',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Result - Enhanced with layered depth
              if (_convertedAmount > 0)
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3)
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: isDark
                        ? Border.all(
                            color:
                                const Color(0xFF00897b).withValues(alpha: 0.2),
                            width: 0.5,
                          )
                        : null,
                    boxShadow: isDark
                        ? [
                            // Refined layered shadows for result card
                            BoxShadow(
                              color: const Color(0xFF00897b)
                                  .withValues(alpha: 0.12), // Reduced opacity
                              blurRadius: 8, // Reduced blur for classier look
                              offset: const Offset(0, 0),
                              spreadRadius: 0.5, // Subtle spread
                            ),
                            BoxShadow(
                              color: const Color(0xFF0A1416)
                                  .withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: const Color(0xFF1A1A1A)
                                  .withValues(alpha: 0.6),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: theme.colorScheme.shadow
                                  .withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '${NumberFormat.currency(symbol: _getCurrencySymbol(_fromCurrency)).format(_amount)} =',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isDark ? theme.colorScheme.onSurface : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(
                            symbol: _getCurrencySymbol(_toCurrency),
                            decimalDigits: 6, // Show more precision
                          ).format(_convertedAmount),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: isDark
                                ? const Color(
                                    0xFFA5D6D1) // Soft cyan for result
                                : colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_rateDate.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Rate date: $_rateDate',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? theme.colorScheme.onSurfaceVariant
                                  : colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Info Text - Enhanced with muted typography
              Column(
                children: [
                  Text(
                    'Exchange rates are fetched from Frankfurter API (European Central Bank rates).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : colorScheme.onSurfaceVariant,
                      fontSize: isDark ? 11 : 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  if (_lastUpdateTime.isNotEmpty)
                    Text(
                      'Last updated: ${_formatDateTime(_lastUpdateTime)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8)
                            : colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                        fontSize: isDark ? 10 : 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  Text(
                    'Rates are cached for 1 hour for performance.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6)
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: isDark ? 10 : 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
