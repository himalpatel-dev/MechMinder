import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../service/database_helper.dart';
import 'package:path_provider/path_provider.dart'; // To find the temp folder
import 'package:share_plus/share_plus.dart'; // To open the share dialog
import 'package:file_picker/file_picker.dart';
import 'package:workmanager/workmanager.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  Future<void> _exportDataAsJson(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dbHelper = DatabaseHelper.instance;

    try {
      // No permissions needed for this method!

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Starting export... This may take a moment.'),
        ),
      );

      // --- 1. GATHER ALL DATA ---
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

      // --- 2. CREATE THE BACKUP MAP ---
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

      // --- 3. CONVERT TO JSON ---
      String jsonBackup = jsonEncode(backupData);

      // --- 4. SAVE THE FILE TO A TEMPORARY DIRECTORY ---
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

      // --- 5. OPEN THE NATIVE "SHARE" DIALOG ---
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

  Future<void> _importDataFromJson(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dbHelper = DatabaseHelper.instance;

    try {
      // --- 1. PICK THE .JSON FILE ---
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

      // --- 2. SHOW A DANGEROUS WARNING ---
      if (!context.mounted) return;
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ARE YOU SURE?'),
          content: const Text(
            'Restoring from a backup will DELETE ALL current data in the app. This cannot be undone.\n\nAre you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

      // --- 3. READ AND PARSE THE FILE ---
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Restoring data... Please wait.')),
      );
      File backupFile = File(result.files.single.path!);
      String jsonString = await backupFile.readAsString();
      Map<String, dynamic> backupData = jsonDecode(jsonString);

      // --- 4. WIPE THE DATABASE AND RESTORE ---
      // This is the complex part. We need a new function in DatabaseHelper.
      await dbHelper.restoreBackup(backupData);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Restore complete! Reloading data...'),
          backgroundColor: Colors.green,
        ),
      );

      // --- ADD THIS ---
      // Wait for the SnackBar to show, then pop the screen
      await Future.delayed(const Duration(seconds: 2));
      if (context.mounted) {
        Navigator.of(context).pop(true); // <-- Send "true" back
      }

      // (In a real app, we'd force a restart or reload all state,
      // but for now, we'll just show the message)
    } catch (e) {
      print("Error importing data: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error importing data: $e')),
      );
    }
  }

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

  // --- NEW DIALOG FOR CHANGING CURRENCY ---
  void _showCurrencyDialog(BuildContext context, SettingsProvider settings) {
    // A list of common currency symbols
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
            // Loop through our map to create the radio buttons
            for (var entry in currencies.entries)
              RadioListTile<String>(
                title: Text('${entry.value} (${entry.key})'),
                value: entry.key, // The symbol is the value (e.g., "$")
                groupValue: settings.currencySymbol,
                onChanged: (String? value) {
                  if (value != null) {
                    settings.updateCurrency(value);
                  }
                  Navigator.of(ctx).pop();
                },
              ),

            // An option to add a custom one
            ListTile(
              title: const Text('Other...'),
              onTap: () {
                Navigator.of(ctx).pop();
                // This will open the *old* dialog for custom entry
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
  // A helper function to query all rows from any table
  // Let's add this to DatabaseHelper instead (see Part C)

  @override
  Widget build(BuildContext context) {
    // We wrap the list in a Consumer to get the settings
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
              ListTile(
                leading: const Icon(Icons.straighten),
                title: const Text('Units'),
                // Show the currently selected unit
                subtitle: Text(
                  settings.unitType == 'km' ? 'Kilometers' : 'Miles',
                ),
                onTap: () {
                  // Show the "Change Unit" dialog
                  _showUnitDialog(context, settings);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Currency'),
                // Show the currently selected currency
                subtitle: Text(settings.currencySymbol),
                onTap: () {
                  // Show the "Change Currency" dialog
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
