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
  ThemeMode _themeMode = ThemeMode.light;

  // --- NEW: Add a variable for the color ---
  Color _primaryColor = Colors.blue; // Default color

  // --- Getters for the UI ---
  String get unitType => _unitType;
  String get currencySymbol => _currencySymbol;
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor; // <-- NEW

  /// Text/icon color that stays readable on [primaryColor]: white on dark
  /// colors, near-black on light ones (yellow, white, light green...).
  Color get onPrimaryColor => contrastOn(_primaryColor);

  /// Readable text/icon color for anything drawn on [background].
  static Color contrastOn(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    _unitType = _prefs?.getString(_keyUnit) ?? 'km';
    _currencySymbol = _prefs?.getString(_keyCurrency) ?? '₹';

    // --- FIX: Simplified theme loading ---
    // Default to 'light' if no setting is saved
    final String themeName = _prefs?.getString(_keyTheme) ?? 'light';
    if (themeName == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    // --- END FIX ---

    int? savedColorInt = _prefs?.getInt(_keyColor);
    if (savedColorInt != null) {
      _primaryColor = Color(savedColorInt);
    } else {
      _primaryColor = Colors.blue;
    }

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
    if (_prefs == null) await _loadSettings();

    // We only care about light or dark now
    _themeMode = newThemeMode == ThemeMode.dark
        ? ThemeMode.dark
        : ThemeMode.light;

    String themeName = (newThemeMode == ThemeMode.dark) ? 'dark' : 'light';

    await _prefs!.setString(_keyTheme, themeName);
    notifyListeners();
  }

  // --- NEW: Function to change and save the color ---
  Future<void> updatePrimaryColor(Color newColor) async {
    if (_prefs == null) await _loadSettings();
    _primaryColor = newColor;
    await _prefs!.setInt(_keyColor, newColor.value);
    notifyListeners();
  }

  // --- END NEW ---
}
