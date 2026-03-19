import 'dart:convert';
import 'package:flutter/foundation.dart' as foundation;
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class CurrencyService {
  static const String _defaultCurrency = 'INR';
  static const String _baseUrl = 'https://api.frankfurter.app';

  // Cache for exchange rates with timestamp
  static Map<String, dynamic>? _cachedRates;
  static DateTime? _lastFetchTime;
  static const Duration _cacheTimeout = Duration(hours: 1); // Cache for 1 hour

  // Get the current currency (delegated to SettingsService)
  static Future<String> getCurrency() async {
    return await SettingsService.getSelectedCurrency();
  }

  // Set the current currency (delegated to SettingsService)
  static Future<bool> setCurrency(String currencyCode) async {
    await SettingsService.setSelectedCurrency(currencyCode);
    return true; // SettingsService doesn't return bool, but API expects it
  }

  // Get currency symbol for a currency code
  static String getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CHF':
        return 'CHF'; // Using 'CHF' instead of '₣' for better compatibility
      case 'CAD':
        return r'C$';
      case 'AUD':
        return r'A$';
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'KRW':
        return '₩';
      case 'BRL':
        return r'R$';
      case 'MXN':
        return r'Mex$';
      case 'RUB':
        return '₽';
      case 'ZAR':
        return 'R';
      case 'SGD':
        return r'S$';
      default:
        return currencyCode;
    }
  }

  // Get currency locale for number formatting
  static String getCurrencyLocale(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return 'en_US';
      case 'EUR':
        return 'de_DE';
      case 'GBP':
        return 'en_GB';
      case 'JPY':
        return 'ja_JP';
      case 'INR':
        return 'en_IN';
      case 'AUD':
        return 'en_AU';
      case 'CAD':
        return 'en_CA';
      case 'CNY':
        return 'zh_CN';
      case 'CHF':
        return 'de_CH';
      case 'KRW':
        return 'ko_KR';
      case 'BRL':
        return 'pt_BR';
      case 'MXN':
        return 'es_MX';
      case 'RUB':
        return 'ru_RU';
      case 'ZAR':
        return 'en_ZA';
      case 'SGD':
        return 'en_SG';
      default:
        return 'en_IN'; // Default to Indian locale
    }
  }

  // Get currency name for a currency code
  static String getCurrencyName(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return 'US Dollar';
      case 'EUR':
        return 'Euro';
      case 'GBP':
        return 'British Pound';
      case 'JPY':
        return 'Japanese Yen';
      case 'CHF':
        return 'Swiss Franc';
      case 'CAD':
        return 'Canadian Dollar';
      case 'AUD':
        return 'Australian Dollar';
      case 'CNY':
        return 'Chinese Yuan';
      case 'INR':
        return 'Indian Rupee';
      case 'KRW':
        return 'South Korean Won';
      case 'BRL':
        return 'Brazilian Real';
      case 'MXN':
        return 'Mexican Peso';
      case 'RUB':
        return 'Russian Ruble';
      case 'ZAR':
        return 'South African Rand';
      case 'SGD':
        return 'Singapore Dollar';
      default:
        return currencyCode;
    }
  }

  // Get currency symbol for the currently selected currency
  static Future<String> getCurrentCurrencySymbol() async {
    final currency = await getCurrency();
    return getCurrencySymbol(currency);
  }

  // Get currency locale for the currently selected currency
  static Future<String> getCurrentCurrencyLocale() async {
    final currency = await getCurrency();
    return getCurrencyLocale(currency);
  }

  // Get currency name for the currently selected currency
  static Future<String> getCurrentCurrencyName() async {
    final currency = await getCurrency();
    return getCurrencyName(currency);
  }

  // Get all supported currencies as a list (now using SettingsService list)
  static Map<String, Map<String, String>> getAllSupportedCurrencies() {
    final Map<String, Map<String, String>> currencies = {};
    for (final currency in SettingsService.majorCurrencies) {
      final code = currency['code']!;
      currencies[code] = {
        'name': currency['name']!,
        'symbol': getCurrencySymbol(code),
        'locale': getCurrencyLocale(code),
        'position': getCurrencyPosition(code),
      };
    }
    return currencies;
  }

  // Get currency position (before or after number)
  static String getCurrencyPosition(String currencyCode) {
    switch (currencyCode) {
      case 'EUR':
        return 'after'; // Euro symbol after number
      case 'USD':
      case 'GBP':
      case 'JPY':
      case 'INR':
      case 'AUD':
      case 'CAD':
      case 'CNY':
      case 'CHF':
      case 'KRW':
      case 'BRL':
      case 'MXN':
      case 'RUB':
      case 'ZAR':
      case 'SGD':
      default:
        return 'before'; // Most currencies have symbol before number
    }
  }

  // Get exchange rate using Frankfurter API with caching and precision
  static Future<double> getExchangeRate(String from, String to) async {
    if (from == to) return 1.0;

    try {
      // Check if we need to refresh cache
      if (_cachedRates == null ||
          _lastFetchTime == null ||
          DateTime.now().difference(_lastFetchTime!) > _cacheTimeout) {
        await _refreshCache();
      }

      // Try to get rate from cache
      if (_cachedRates != null && _cachedRates!['rates'] is Map) {
        final rates = (_cachedRates!['rates'] as Map).cast<String, dynamic>();

        // Direct rate
        if (rates.containsKey(to)) {
          final rate = rates[to];
          if (rate is num) return rate.toDouble();
          if (rate is String) {
            final parsed = double.tryParse(rate);
            if (parsed != null) return parsed;
          }
        }

        // If no direct rate, try to get it via EUR (Frankfurter's base)
        if (from != 'EUR' && to != 'EUR') {
          final fromToEur = await _getRateViaEur(from, to);
          if (fromToEur != null) return fromToEur;
        }
      }

      // Fallback: direct API call
      final response = await http
          .get(
            Uri.parse('$_baseUrl/latest?from=$from&to=$to'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rate = data['rates'][to];
        if (rate is num) return rate.toDouble();
        if (rate is String) {
          final parsed = double.tryParse(rate);
          if (parsed != null) return parsed;
        }
      }

      print('Failed to fetch exchange rate: ${response.statusCode}');
      return 1.0; // Fallback to no conversion
    } catch (e) {
      print('Error fetching exchange rate: $e');
      return 1.0; // Fallback to no conversion
    }
  }

  // Helper method to get rate via EUR (Frankfurter's base currency)
  static Future<double?> _getRateViaEur(String from, String to) async {
    try {
      // Get from -> EUR rate
      final fromResponse = await http
          .get(
            Uri.parse('$_baseUrl/latest?from=$from&to=EUR'),
          )
          .timeout(const Duration(seconds: 5));

      if (fromResponse.statusCode == 200) {
        final fromData = json.decode(fromResponse.body);
        final fromToEur = fromData['rates']['EUR'];

        // Get EUR -> to rate
        final toResponse = await http
            .get(
              Uri.parse('$_baseUrl/latest?from=EUR&to=$to'),
            )
            .timeout(const Duration(seconds: 5));

        if (toResponse.statusCode == 200) {
          final toData = json.decode(toResponse.body);
          final eurToTo = toData['rates'][to];

          if (fromToEur is num && eurToTo is num) {
            return fromToEur.toDouble() * eurToTo.toDouble();
          }
        }
      }
    } catch (e) {
      print('Error getting rate via EUR: $e');
    }
    return null;
  }

  // Refresh the cache with latest rates
  static Future<void> _refreshCache() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/latest?from=$_defaultCurrency'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _cachedRates = json.decode(response.body);
        _lastFetchTime = DateTime.now();
      }
    } catch (e) {
      print('Error refreshing cache: $e');
    }
  }

  // Get exchange rate with timestamp information
  static Future<Map<String, dynamic>> getExchangeRateWithInfo(
      String from, String to) async {
    final rate = await getExchangeRate(from, to);
    return {
      'rate': rate,
      'from': from,
      'to': to,
      'timestamp': _lastFetchTime?.toIso8601String(),
      'date': _cachedRates?['date'],
    };
  }

  // Convert amount with high precision
  static Future<double> convertAmount(
      double amount, String from, String to) async {
    final rate = await getExchangeRate(from, to);
    // Return accurate conversion without rounding
    return amount * rate;
  }

  // Synchronous conversion using cached rates (for use in map operations)
  static double convertAmountSync(double amount, String from, String to) {
    if (from == to) return amount;

    foundation
        .debugPrint('CurrencyService: Converting $amount from $from to $to');
    foundation.debugPrint(
        'CurrencyService: Available rates: ${_cachedRates?['rates']?.keys}');

    // Try to get rate from cache (cache is based on INR as base)
    if (_cachedRates != null && _cachedRates!['rates'] is Map) {
      final rates = (_cachedRates!['rates'] as Map).cast<String, dynamic>();

      // If converting from INR to target currency
      if (from == 'INR' && rates.containsKey(to)) {
        final rate = rates[to];
        foundation.debugPrint('CurrencyService: INR->$to rate: $rate');
        if (rate is num) {
          final result = amount * rate.toDouble();
          foundation.debugPrint('CurrencyService: Result: $result');
          return result;
        }
        if (rate is String) {
          final parsed = double.tryParse(rate);
          if (parsed != null) {
            final result = amount * parsed;
            foundation.debugPrint('CurrencyService: Result: $result');
            return result;
          }
        }
      }

      // If converting to INR from target currency
      if (to == 'INR' && rates.containsKey(from)) {
        final rate = rates[from];
        foundation.debugPrint('CurrencyService: $from->INR rate: $rate');
        if (rate is num && rate != 0) {
          final result = amount / rate.toDouble();
          foundation.debugPrint('CurrencyService: Result: $result');
          return result;
        }
        if (rate is String) {
          final parsed = double.tryParse(rate);
          if (parsed != null && parsed != 0) {
            final result = amount / parsed;
            foundation.debugPrint('CurrencyService: Result: $result');
            return result;
          }
        }
      }

      // For other currency pairs, convert via INR as intermediary
      if (rates.containsKey(from) && rates.containsKey(to)) {
        final fromRate = rates[from];
        final toRate = rates[to];
        foundation.debugPrint(
            'CurrencyService: Converting via INR - $from rate: $fromRate, $to rate: $toRate');
        if (fromRate is num && toRate is num && fromRate != 0) {
          // Convert: from -> INR -> to
          final inrAmount = amount / fromRate.toDouble();
          final result = inrAmount * toRate.toDouble();
          foundation.debugPrint(
              'CurrencyService: INR amount: $inrAmount, Final result: $result');
          return result;
        }
        if (fromRate is String && toRate is String) {
          final fromParsed = double.tryParse(fromRate);
          final toParsed = double.tryParse(toRate);
          if (fromParsed != null && toParsed != null && fromParsed != 0) {
            final inrAmount = amount / fromParsed;
            final result = inrAmount * toParsed;
            foundation.debugPrint(
                'CurrencyService: INR amount: $inrAmount, Final result: $result');
            return result;
          }
        }
      }
    }

    // Fallback: return original amount
    foundation.debugPrint(
        'CurrencyService: Could not convert $amount from $from to $to - using fallback');
    return amount;
  }

  // Get last update timestamp
  static DateTime? getLastUpdateTime() => _lastFetchTime;

  // Force refresh cache
  static Future<void> refreshRates() async {
    _cachedRates = null;
    _lastFetchTime = null;
    await _refreshCache();
  }

  // Ensure cache is initialized (call this from insights screens)
  static Future<void> ensureCacheInitialized() async {
    if (_cachedRates == null ||
        _lastFetchTime == null ||
        DateTime.now().difference(_lastFetchTime!) > _cacheTimeout) {
      await _refreshCache();
    }
  }

  // Get current exchange rate for selected currency (assuming base is INR)
  static Future<double> getCurrentExchangeRate() async {
    final currentCurrency = await getCurrency();
    return await getExchangeRate(_defaultCurrency, currentCurrency);
  }

  // Reset to default currency
  static Future<void> resetToDefault() async {
    await setCurrency(_defaultCurrency);
  }
}
