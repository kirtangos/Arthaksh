import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AppThemeController {
  // Private constructor to prevent external instantiation
  AppThemeController._internal() {
    _loadThemePreference();
  }

  static final AppThemeController instance = AppThemeController._internal();

  // Default accent (teal)
  final ValueNotifier<Color> seedColor =
      ValueNotifier<Color>(const Color(0xFF0D9488));

  // Allow theme switching based on user preference
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  // Load saved theme preference
  Future<void> _loadThemePreference() async {
    final isDarkTheme = await SettingsService.getDarkTheme();
    themeMode.value = isDarkTheme ? ThemeMode.dark : ThemeMode.light;
  }

  // Update theme mode and save preference
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await SettingsService.setDarkTheme(mode == ThemeMode.dark);
  }

  // Get current theme mode
  ThemeMode get currentTheme => themeMode.value;
}
