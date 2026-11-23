import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../screens/vehicle_list.dart';
import '../screens/todo_list_screen.dart';

import 'package:path/path.dart' as p;
import '../service/backup_archive.dart';
import '../utils/formatters.dart';
import '../service/subscription_provider.dart';
import '../screens/paywall_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  final GlobalKey<VehicleListScreenState> vehicleListKey;
  final GlobalKey<TodoListScreenState> allRemindersKey;
  final VoidCallback onShowTour; // NEW: Callback for tutorial

  const AppSettingsScreen({
    super.key,
    required this.vehicleListKey,
    required this.allRemindersKey,
    required this.onShowTour, // NEW: Required
  });

  // --- (Your _exportDataAsJson and _importDataFromJson functions are unchanged) ---
  Future<void> _exportData(BuildContext context) async {
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
      final allPapers = await dbHelper.queryAllRows(
        DatabaseHelper.tableVehiclePapers,
      );
      final allDocuments = await dbHelper.queryAllRows(
        DatabaseHelper.tableDocuments,
      );
      final allTodos = await dbHelper.queryAllRows(
        DatabaseHelper.tableTodoList,
      );

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
        'vehicle_papers': allPapers,
        'documents': allDocuments,
        'todolist': allTodos,
      };

      // Files to put in the zip: zip entry name -> file on disk. Entry names
      // are what restoreBackup() looks for.
      final Map<String, String> files = {};
      void addFiles(
        List<Map<String, dynamic>> rows,
        String pathColumn,
        String prefix,
      ) {
        for (final row in rows) {
          final String? path = row[pathColumn];
          if (path == null || path.isEmpty) continue;
          files['$prefix${row[DatabaseHelper.columnId]}${p.extension(path)}'] =
              path;
        }
      }

      addFiles(allPhotos, DatabaseHelper.columnUri, 'photos/photo_');
      addFiles(allPapers, DatabaseHelper.columnFilePath, 'papers/paper_');
      addFiles(allDocuments, DatabaseHelper.columnFilePath, 'documents/doc_');

      final directory = await getTemporaryDirectory();
      String timestamp = DateTime.now()
          .toString()
          .replaceAll(':', '-')
          .replaceAll(' ', '_');
      String fileName = 'mechminder_backup_$timestamp.zip';
      final filePath = '${directory.path}/$fileName';

      // Zipping runs on a background isolate and streams each file, so big
      // backups no longer freeze the screen or run out of memory.
      await BackupArchive.writeZip(filePath, jsonEncode(backupData), files);
      print("Backup file created at: $filePath");

      if (!context.mounted) return;

      // Ask user what to do
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Backup Created'),
          content: const Text('How would you like to export the backup file?'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final xfile = XFile(filePath);
                await SharePlus.instance.share(
                  ShareParams(
                    files: [xfile],
                    subject: 'MechMinder Data Backup (With Files)',
                    text: 'Here is the MechMinder backup file.',
                  ),
                );
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text('Save to Device'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final params = SaveFileDialogParams(sourceFilePath: filePath);
                  final finalPath = await FlutterFileDialog.saveFile(
                    params: params,
                  );
                  if (finalPath != null) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Saved to: $finalPath'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error saving file: $e')),
                  );
                }
              },
            ),
          ],
        ),
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

  Future<void> _importData(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dbHelper = DatabaseHelper.instance;
    Directory? extractDir;
    try {
      final PlatformFile? picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
      );
      final String? pickedPath = picked?.path;
      if (pickedPath == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No file selected.')),
        );
        return;
      }

      // Read and check the backup BEFORE anything is wiped, so a broken or
      // wrong file can't leave the app empty.
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Reading backup...')),
      );
      final bool isZip = p.extension(pickedPath).toLowerCase() == '.zip';
      String jsonString;
      if (isZip) {
        final tempDir = await getTemporaryDirectory();
        extractDir = Directory(p.join(tempDir.path, 'restore_temp'));
        if (await extractDir.exists()) {
          await extractDir.delete(recursive: true);
        }
        await extractDir.create(recursive: true);
        // Background isolate; unsafe paths in the zip are skipped.
        jsonString = await BackupArchive.extractZip(
          pickedPath,
          extractDir.path,
        );
      } else {
        jsonString = await File(pickedPath).readAsString();
      }
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic> || decoded['vehicles'] is! List) {
        throw const FormatException('This file is not a MechMinder backup.');
      }
      final Map<String, dynamic> backupData = decoded;
      final int vehicleCount = (backupData['vehicles'] as List).length;
      final int serviceCount = (backupData['services'] as List?)?.length ?? 0;
      final String exportDate = Fmt.date(backupData['export_date'] as String?);

      if (!context.mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ARE YOU SURE?'),
          content: Text(
            'This backup${exportDate.isEmpty ? '' : ' from $exportDate'} has '
            '$vehicleCount vehicle${vehicleCount == 1 ? '' : 's'} and '
            '$serviceCount service record${serviceCount == 1 ? '' : 's'}.\n\n'
            'Restoring it will DELETE ALL current data in the app. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
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

      await dbHelper.restoreBackup(
        backupData,
        fileSourcePath: extractDir?.path,
      );

      // --- REFRESH LOGIC ---
      // 1. Refresh the lists using the keys
      vehicleListKey.currentState?.refreshVehicleList();
      allRemindersKey.currentState?.refreshTodoList();

      // 2. Show success and switch to the first tab
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Restore complete! Switching to Vehicles tab...'),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (context.mounted) {
        // Find the TabController and switch to the first tab (index 0)
        DefaultTabController.of(context).animateTo(0);
      }
      // --- END REFRESH LOGIC ---
    } catch (e) {
      print("Error importing data: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error importing data: $e')),
      );
    } finally {
      // The extracted copy is no longer needed (files were copied in).
      if (extractDir != null) {
        try {
          if (await extractDir.exists()) {
            await extractDir.delete(recursive: true);
          }
        } catch (_) {}
      }
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

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        scrollable:
            true, // IMPORTANT: Allows the whole dialog content to scroll
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              '1. Introduction\n'
              'Welcome to MechMinder, a vehicle maintenance and management application developed by Krimal Techworks. We are committed to protecting your privacy. This Privacy Policy explains how MechMinder handles information.\n\n'
              'Crucially, MechMinder is an offline-first application. We do not collect, store, or process your personal data on our servers.\n\n'
              '2. Information We Collect (Stored Locally Only)\n'
              'All information you enter into MechMinder is stored locally on your device in a secure database. We do not have access to this data. The types of information you may store in the app include:\n\n'
              'Vehicle Information: Make, model, registration number, fuel type, and owner name.\n'
              'Maintenance Records: Service history, odometer readings, service costs, and notes.\n'
              'Financial Data: Fuel expenses and other vehicle-related costs.\n'
              'Reminders: Maintenance schedules and due dates.\n'
              'Documents & Photos: Images of your vehicle, service receipts, and vehicle papers (such as Insurance or PUC documents).\n'
              'Vendor Information: Names and contact details of your mechanics or service centers.\n\n'
              '3. How We Use Your Information\n'
              'Since all data is stored locally, it is used solely to provide the app\'s features to you, such as:\n\n'
              'Tracking your vehicle\'s service history and expenses.\n'
              'Calculating total spending on your vehicle.\n'
              'Sending you local notifications for upcoming service reminders.\n'
              'Allowing you to export your data to Excel files.\n\n'
              '4. Permissions We Request\n'
              'To provide its full functionality, MechMinder may request the following permissions:\n\n'
              'Camera: To allow you to take photos of your vehicle, receipts, or documents.\n'
              'Storage/Media: To allow you to pick existing photos/documents from your gallery and to save exported Excel reports to your device.\n'
              'Notifications: To send you alerts for maintenance tasks and document expiry dates.\n'
              'Internet: Used only for basic technical requirements (like checking for app updates) or if you choose to manually share a report via third-party apps.\n\n'
              '5. Data Security and Storage\n'
              'Your data is stored in an SQLite database on your device. We do not use cloud storage or sync services.\n\n'
              'Data Retention: Data remains on your device until you delete the app or clear the app\'s data.\n'
              'User Control: You have full control over your data. You can add, edit, or delete any record at any time.\n\n'
              '6. Third-Party Services\n'
              'MechMinder does not share your data with any third parties. If you use the "Share" feature within the app, you are manually choosing to send specific data to another application (like WhatsApp or Email) of your choice.\n\n'
              '7. Children’s Privacy\n'
              'MechMinder does not collect any personal information from anyone, including children under the age of 13.\n\n'
              '8. Changes to This Policy\n'
              'We may update our Privacy Policy from time to time. Any changes will be posted on this page with an updated "Last Updated" date.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- UPDATED BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, SubscriptionProvider>(
      builder: (context, settings, subProvider, child) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            // --- DATA MANAGEMENT (unchanged) ---
            const ListTile(
              title: Text(
                'Data Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            ListTile(
              leading: Icon(
                Icons.download_for_offline,
                color: subProvider.isPremium
                    ? settings.primaryColor
                    : Colors.grey,
              ),
              title: const Text('Export Backup (Zip)'),
              subtitle: Text(
                subProvider.isPremium
                    ? 'Save all data and files together'
                    : 'Premium Feature',
              ),
              trailing: subProvider.isPremium
                  ? null
                  : const Icon(Icons.lock, size: 20, color: Colors.grey),
              onTap: () {
                if (subProvider.isPremium) {
                  _exportData(context);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.upload_file,
                color: subProvider.isPremium
                    ? settings.primaryColor
                    : Colors.grey,
              ),
              title: const Text('Restore Backup'),
              subtitle: Text(
                subProvider.isPremium
                    ? 'Restore from a Zip or Json file'
                    : 'Premium Feature',
              ),
              trailing: subProvider.isPremium
                  ? null
                  : const Icon(Icons.lock, size: 20, color: Colors.grey),
              onTap: () {
                if (subProvider.isPremium) {
                  _importData(context);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                }
              },
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

            // --- END NEW ---
            ListTile(
              leading: Icon(Icons.straighten, color: settings.primaryColor),
              title: const Text('Units'),
              subtitle: Text(
                settings.unitType == 'km' ? 'Kilometers' : 'Miles',
              ),
              onTap: () {
                _showUnitDialog(context, settings);
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_money, color: settings.primaryColor),
              title: const Text('Currency'),
              subtitle: Text(settings.currencySymbol),
              onTap: () {
                _showCurrencyDialog(context, settings);
              },
            ),

            const Divider(),

            // --- HELP SECTION ---
            const ListTile(
              title: Text(
                'Help & Info',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(Icons.help_outline, color: settings.primaryColor),
              title: const Text('App Tour'),
              subtitle: const Text('See what MechMinder can do'),
              onTap: () {
                // Trigger the home screen tutorial
                onShowTour();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.privacy_tip_outlined,
                color: settings.primaryColor,
              ),
              title: const Text('Privacy Policy'),
              subtitle: const Text('Data usage and protection'),
              onTap: () {
                _showPrivacyPolicyDialog(context);
              },
            ),
          ],
        );
      },
    );
  }
}
