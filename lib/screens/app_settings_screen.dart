import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../service/database_helper.dart';
import 'package:path_provider/path_provider.dart'; // To find the temp folder
import 'package:share_plus/share_plus.dart'; // To open the share dialog
import 'package:file_picker/file_picker.dart';

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

  // A helper function to query all rows from any table
  // Let's add this to DatabaseHelper instead (see Part C)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Settings')),
      body: ListView(
        children: [
          // --- DATA SECTION ---
          const ListTile(
            title: Text(
              'Data Management',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline),
            title: const Text('Export All Data'),
            subtitle: const Text(
              'Save all data to a JSON backup file',
            ), // <-- Updated text
            onTap: () => _exportDataAsJson(context), // <-- Updated function
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import Data'),
            subtitle: const Text(
              'Restore from a JSON backup file',
            ), // <-- Updated text
            onTap: () => _importDataFromJson(context), // <-- Updated function
          ),

          const Divider(),

          // --- PREFERENCES SECTION ---
          const ListTile(
            title: Text(
              'Preferences',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Units'),
            subtitle: const Text('km, miles'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currency'),
            subtitle: const Text('\$ (USD)'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
