import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  // --- (Your _exportDataAsJson and _importDataFromJson functions are unchanged) ---
  Future<void> _exportDataAsJson(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dbHelper = DatabaseHelper.instance;
    try {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Starting export... This may take a moment.'),
        ),
      );
      final allVehicles = await dbHelper.queryAllRows(
        DatabaseHelper.tableVehicles,
      );
      final allServices = await dbHelper.queryAllRows(
        DatabaseHelper.tableServices,
      );
      final allServiceItems = await dbHelper.queryAllRows(
        DatabaseHelper.tableServiceItems,
      );
      final allExpenses = await dbHelper.queryAllRows(
        DatabaseHelper.tableExpenses,
      );
      final allVendors = await dbHelper.queryAllRows(
        DatabaseHelper.tableVendors,
      );
      final allTemplates = await dbHelper.queryAllRows(
        DatabaseHelper.tableServiceTemplates,
      );
      final allReminders = await dbHelper.queryAllRows(
        DatabaseHelper.tableReminders,
      );
      final allPhotos = await dbHelper.queryAllRows(DatabaseHelper.tablePhotos);

      Map<String, dynamic> backupData = {
        'export_date': DateTime.now().toIso8601String(),
        'vehicles': allVehicles,
        'services': allServices,
        'service_items': allServiceItems,
        'expenses': allExpenses,
        'vendors': allVendors,
        'service_templates': allTemplates,
        'reminders': allReminders,
        'photos': allPhotos,
      };

      String jsonBackup = jsonEncode(backupData);

      final directory = await getTemporaryDirectory();
      String timestamp = DateTime.now()
          .toString()
          .replaceAll(':', '-')
          .replaceAll(' ', '_');
      String fileName = 'mechminder_backup_$timestamp.json';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      await file.writeAsString(jsonBackup);
      print("Backup file created at: $filePath");

      final xfile = XFile(filePath);
      await Share.shareXFiles(
        [xfile],
        subject: 'MechMinder Data Backup',
        text: 'Here is the MechMinder backup file.',
      );
    } catch (e) {
      print("Error exporting data: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error exporting data: $e')),
      );
    }
  }

  // --- NEW: FUNCTION TO SHOW COLOR PICKER ---
  void _showColorPickerDialog(BuildContext context, SettingsProvider settings) {
    Color pickerColor = settings.primaryColor;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color; // Update the color in the dialog
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                settings.updatePrimaryColor(pickerColor); // Save to provider
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _importDataFromJson(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dbHelper = DatabaseHelper.instance;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No file selected.')),
        );
        return;
      }
      if (!context.mounted) return;
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ARE YOU SURE?'),
          content: const Text(
            'Restoring from a backup will DELETE ALL current data in the app. This cannot be undone.\n\nAre you sure you want to proceed?',
            //style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Wipe and Restore'),
            ),
          ],
        ),
      );
      if (confirmed == null || confirmed == false) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Restore cancelled.')),
        );
        return;
      }
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Restoring data... Please wait.')),
      );
      File backupFile = File(result.files.single.path!);
      String jsonString = await backupFile.readAsString();
      Map<String, dynamic> backupData = jsonDecode(jsonString);
      await dbHelper.restoreBackup(backupData);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Restore complete! Reloading data...'),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (context.mounted) {
        Navigator.of(context).pop(true); // Send back "true" to refresh
      }
    } catch (e) {
      print("Error importing data: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error importing data: $e')),
      );
    }
  }

  // --- (Your Currency dialogs are unchanged) ---
  void _showUnitDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: const Text('Select Unit'),
          children: [
            RadioListTile<String>(
              title: const Text('Kilometers (km)'),
              value: 'km',
              groupValue: settings.unitType,
              onChanged: (String? value) {
                if (value != null) {
                  settings.updateUnit(value);
                }
                Navigator.of(ctx).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('Miles (mi)'),
              value: 'mi',
              groupValue: settings.unitType,
              onChanged: (String? value) {
                if (value != null) {
                  settings.updateUnit(value);
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCurrencyDialog(BuildContext context, SettingsProvider settings) {
    final Map<String, String> currencies = {
      '\$': 'Dollar (USD)',
      '₹': 'Rupee (INR)',
      '€': 'Euro (EUR)',
      '£': 'Pound (GBP)',
    };
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: const Text('Select Currency Symbol'),
          children: [
            for (var entry in currencies.entries)
              RadioListTile<String>(
                title: Text('${entry.value} (${entry.key})'),
                value: entry.key,
                groupValue: settings.currencySymbol,
                onChanged: (String? value) {
                  if (value != null) {
                    settings.updateCurrency(value);
                  }
                  Navigator.of(ctx).pop();
                },
              ),
            ListTile(
              title: const Text('Other...'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showCustomCurrencyDialog(context, settings);
              },
            ),
          ],
        );
      },
    );
  }

  void _showCustomCurrencyDialog(
    BuildContext context,
    SettingsProvider settings,
  ) {
    final currencyController = TextEditingController(
      text: settings.currencySymbol,
    );
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Set Custom Symbol'),
          content: TextField(
            controller: currencyController,
            decoration: const InputDecoration(labelText: 'Symbol (e.g., ¥)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (currencyController.text.isNotEmpty) {
                  settings.updateCurrency(currencyController.text);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // --- NEW: FUNCTION TO SHOW THEME DIALOG ---
  void _showThemeDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: const Text('Select Theme'),
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: settings.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  settings.updateThemeMode(value);
                }
                Navigator.of(ctx).pop();
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light Mode'),
              value: ThemeMode.light,
              groupValue: settings.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  settings.updateThemeMode(value);
                }
                Navigator.of(ctx).pop();
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark Mode'),
              value: ThemeMode.dark,
              groupValue: settings.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  settings.updateThemeMode(value);
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- NEW: Helper to get the current theme name as text ---
  String _getThemeName(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  // --- UPDATED BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('App Settings')),
          body: ListView(
            children: [
              // --- DATA MANAGEMENT (unchanged) ---
              const ListTile(
                title: Text(
                  'Data Management',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline),
                title: const Text('Export All Data'),
                subtitle: const Text('Save all data to a JSON backup file'),
                onTap: () => _exportDataAsJson(context),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Import Data'),
                subtitle: const Text('Restore from a JSON backup file'),
                onTap: () => _importDataFromJson(context),
              ),

              const Divider(),

              // --- PREFERENCES (UPDATED) ---
              const ListTile(
                title: Text(
                  'Preferences',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              //Color Picker Tile
              ListTile(
                leading: Icon(Icons.color_lens, color: settings.primaryColor),
                title: const Text('App Color'),
                subtitle: const Text('Change the primary app color'),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: settings.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                onTap: () {
                  _showColorPickerDialog(context, settings);
                },
              ),

              // --- NEW: THEME BUTTON ---
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                subtitle: Text(_getThemeName(settings.themeMode)),
                onTap: () {
                  _showThemeDialog(context, settings);
                },
              ),

              // --- END NEW ---
              ListTile(
                leading: const Icon(Icons.straighten),
                title: const Text('Units'),
                subtitle: Text(
                  settings.unitType == 'km' ? 'Kilometers' : 'Miles',
                ),
                onTap: () {
                  _showUnitDialog(context, settings);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Currency'),
                subtitle: Text(settings.currencySymbol),
                onTap: () {
                  _showCurrencyDialog(context, settings);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
