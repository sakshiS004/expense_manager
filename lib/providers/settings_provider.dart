import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/formatter.dart';

class SettingsProvider extends ChangeNotifier {
  static const _currencyKey = 'currency_symbol';
  static const _themeKey = 'theme_mode';

  static const Map<String, String> supportedCurrencies = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
  };

  // --- Currency State ---
  String _currencySymbol = '\$';
  String get currencySymbol => _currencySymbol;

  String get currencyCode => supportedCurrencies.entries
      .firstWhere(
        (e) => e.value == _currencySymbol,
    orElse: () => const MapEntry('USD', '\$'),
  )
      .key;

  // --- Theme State ---
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // --- Load Saved Settings ---
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Currency
    _currencySymbol = prefs.getString(_currencyKey) ?? '\$';
    Formatters.currencySymbol = _currencySymbol;

    // Load Theme Mode (0: system, 1: light, 2: dark)
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    notifyListeners();
  }

  // --- Currency Setter ---
  Future<void> setCurrency(String symbol) async {
    if (symbol == _currencySymbol) return;
    _currencySymbol = symbol;
    Formatters.currencySymbol = symbol;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, symbol);
  }

  // --- Theme Mode Setter ---
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }
}