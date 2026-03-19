import 'package:flutter/material.dart';
import 'package:arthaksh/services/currency_service.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  String? _selectedCurrency; // Will be loaded from service
  late Map<String, Map<String, String>> _currencies;

  @override
  void initState() {
    super.initState();
    _currencies = CurrencyService.getAllSupportedCurrencies();
    _loadSelectedCurrency();
  }

  // Load the selected currency from the service
  Future<void> _loadSelectedCurrency() async {
    final currency = await CurrencyService.getCurrency();
    setState(() {
      _selectedCurrency = currency;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency'),
        elevation: 0,
      ),
      body: _selectedCurrency == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8), // Reduced from default proportionally
              itemCount: _currencies.length,
              itemBuilder: (context, index) {
                final currencyCode = _currencies.keys.elementAt(index);
                final currency = _currencies[currencyCode]!;
                final isSelected = _selectedCurrency == currencyCode;

                return RadioListTile<String>(
                  title: Text(
                    '${currency['name']} (${currencyCode})',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith( // Reduced from default
                      fontSize: 14, // Reduced proportionally
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Symbol: ${currency['symbol']}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith( // Reduced from default
                      fontSize: 11, // Reduced proportionally
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.75),
                    ),
                  ),
                  value: currencyCode,
                  groupValue: _selectedCurrency,
                  onChanged: (String? value) async {
                    if (value != null && value != _selectedCurrency) {
                      // Save the selected currency
                      await CurrencyService.setCurrency(value);

                      setState(() {
                        _selectedCurrency = value;
                      });

                      // Show a confirmation message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Currency set to ${currency['name']}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12), // Reduced proportionally
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  secondary: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 20, // Reduced from default proportionally
                        )
                      : null,
                  activeColor: theme.colorScheme.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced from default proportionally
                  visualDensity: VisualDensity.compact, // More compact layout
                );
              },
            ),
    );
  }
}
