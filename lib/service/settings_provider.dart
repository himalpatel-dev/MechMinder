import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// These are the keys we'll use to save the data
const String _keyUnit = 'app_unit';
const String _keyCurrency = 'app_currency';

class SettingsProvider with ChangeNotifier {
  SharedPreferences? _prefs;

  // --- Internal state ---
  String _unitType = 'km'; // Default value
  String _currencySymbol = '\$'; // Default value

  // --- Getters for the UI ---
  // The app will read from these
  String get unitType => _unitType;
  String get currencySymbol => _currencySymbol;

  SettingsProvider() {
    // Load settings as soon as the app starts
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    // Try to read the saved settings
    _unitType = _prefs?.getString(_keyUnit) ?? 'km';
    _currencySymbol = _prefs?.getString(_keyCurrency) ?? '\$';

    // Tell any part of the app that's listening to update
    notifyListeners();
  }

  // --- Public functions to change settings ---

  Future<void> updateUnit(String newUnit) async {
    if (_prefs == null) await _loadSettings();

    _unitType = newUnit;
    await _prefs!.setString(_keyUnit, newUnit);
    notifyListeners();
  }

  Future<void> updateCurrency(String newCurrency) async {
    if (_prefs == null) await _loadSettings();

    _currencySymbol = newCurrency;
    await _prefs!.setString(_keyCurrency, newCurrency);
    notifyListeners();
  }
}
