import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _showFactsKey = 'show_facts';
  static const String _selectedCurrencyKey = 'selected_currency';
  static const String _darkThemeKey = 'dark_theme';

  // List of major international currencies supported by Frankfurter API
  static const List<Map<String, String>> majorCurrencies = [
    {'code': 'USD', 'name': 'US Dollar'},
    {'code': 'EUR', 'name': 'Euro'},
    {'code': 'GBP', 'name': 'British Pound'},
    {'code': 'JPY', 'name': 'Japanese Yen'},
    {'code': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'CAD', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'name': 'Australian Dollar'},
    {'code': 'CNY', 'name': 'Chinese Yuan'},
    {'code': 'INR', 'name': 'Indian Rupee'},
    {'code': 'BRL', 'name': 'Brazilian Real'},
    {'code': 'MXN', 'name': 'Mexican Peso'},
    {'code': 'ZAR', 'name': 'South African Rand'},
    {'code': 'SGD', 'name': 'Singapore Dollar'},
    {'code': 'HKD', 'name': 'Hong Kong Dollar'},
    {'code': 'IDR', 'name': 'Indonesian Rupiah'},
    {'code': 'CZK', 'name': 'Czech Koruna'},
    {'code': 'DKK', 'name': 'Danish Krone'},
    {'code': 'HUF', 'name': 'Hungarian Forint'},
    {'code': 'ISK', 'name': 'Icelandic Krona'},
    {'code': 'ILS', 'name': 'Israeli New Shekel'},
    {'code': 'NOK', 'name': 'Norwegian Krone'},
    {'code': 'NZD', 'name': 'New Zealand Dollar'},
    {'code': 'PHP', 'name': 'Philippine Peso'},
    {'code': 'PLN', 'name': 'Polish Zloty'},
    {'code': 'RON', 'name': 'Romanian Leu'},
    {'code': 'SEK', 'name': 'Swedish Krona'},
    {'code': 'THB', 'name': 'Thai Baht'},
    {'code': 'TRY', 'name': 'Turkish Lira'},
    // Removed: RUB (Russian Ruble) - not supported by Frankfurter API
    // Removed: KRW (South Korean Won) - not supported by Frankfurter API
  ];

  // Get the current setting for showing facts
  static Future<bool> getShowFacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showFactsKey) ?? true; // Default to true (show facts)
  }

  // Save the setting for showing facts
  static Future<void> setShowFacts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFactsKey, value);
  }

  // Get the current selected currency
  static Future<String> getSelectedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedCurrencyKey) ?? 'INR'; // Default to INR
  }

  // Save the selected currency
  static Future<void> setSelectedCurrency(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCurrencyKey, currencyCode);
  }

  // Get the current dark theme setting
  static Future<bool> getDarkTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkThemeKey) ??
        false; // Default to false (light theme)
  }

  // Save the dark theme setting
  static Future<void> setDarkTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkThemeKey, value);
  }
}
