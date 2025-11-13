import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- NEW: Add a key for the color ---
const String _keyTheme = 'app_theme';
const String _keyUnit = 'app_unit';
const String _keyCurrency = 'app_currency';
const String _keyColor = 'app_color'; // <-- NEW

class SettingsProvider with ChangeNotifier {
  SharedPreferences? _prefs;

  // --- Internal state ---
  String _unitType = 'km';
  String _currencySymbol = '₹';
  ThemeMode _themeMode = ThemeMode.system;

  // --- NEW: Add a variable for the color ---
  Color _primaryColor = Colors.blue; // Default color

  // --- Getters for the UI ---
  String get unitType => _unitType;
  String get currencySymbol => _currencySymbol;
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor; // <-- NEW

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    _unitType = _prefs?.getString(_keyUnit) ?? 'km';
    _currencySymbol = _prefs?.getString(_keyCurrency) ?? '₹';

    // (Load Theme)
    final String themeName = _prefs?.getString(_keyTheme) ?? 'system';
    if (themeName == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeName == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    // --- NEW: Load the saved color ---
    // We save the color as an integer (e.g., 0xFF4CAF50)
    int? savedColorInt = _prefs?.getInt(_keyColor);
    if (savedColorInt != null) {
      _primaryColor = Color(savedColorInt);
    } else {
      _primaryColor = Colors.blue; // Default
    }
    // --- END NEW ---

    notifyListeners();
  }

  // --- Public functions to change settings ---
  Future<void> updateUnit(String newUnit) async {
    // (This function is unchanged)
    if (_prefs == null) await _loadSettings();
    _unitType = newUnit;
    await _prefs!.setString(_keyUnit, newUnit);
    notifyListeners();
  }

  Future<void> updateCurrency(String newCurrency) async {
    // (This function is unchanged)
    if (_prefs == null) await _loadSettings();
    _currencySymbol = newCurrency;
    await _prefs!.setString(_keyCurrency, newCurrency);
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode newThemeMode) async {
    // (This function is unchanged)
    if (_prefs == null) await _loadSettings();
    _themeMode = newThemeMode;
    String themeName;
    if (newThemeMode == ThemeMode.light) {
      themeName = 'light';
    } else if (newThemeMode == ThemeMode.dark) {
      themeName = 'dark';
    } else {
      themeName = 'system';
    }
    await _prefs!.setString(_keyTheme, themeName);
    notifyListeners();
  }

  // --- NEW: Function to change and save the color ---
  Future<void> updatePrimaryColor(Color newColor) async {
    if (_prefs == null) await _loadSettings();

    _primaryColor = newColor;
    // Save the color as its integer value
    await _prefs!.setInt(_keyColor, newColor.value);
    notifyListeners();
  }

  // --- END NEW ---
}
