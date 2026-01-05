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
import '../screens/all_reminders_screen.dart';
import '../screens/onboarding_screen.dart'; // Add this import
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class AppSettingsScreen extends StatelessWidget {
  final GlobalKey<VehicleListScreenState> vehicleListKey;
  final GlobalKey<AllRemindersScreenState> allRemindersKey;
  const AppSettingsScreen({
    super.key,
    required this.vehicleListKey,
    required this.allRemindersKey,
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
      };

      // Create Archive
      final archive = Archive();

      // Add JSON
      String jsonBackup = jsonEncode(backupData);
      final jsonBytes = utf8.encode(jsonBackup);
      archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

      // Add Photos
      for (var photo in allPhotos) {
        String? path = photo[DatabaseHelper.columnUri];
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final ext = p.extension(path);
            final id = photo[DatabaseHelper.columnId];
            archive.addFile(
              ArchiveFile('photos/photo_$id$ext', bytes.length, bytes),
            );
          }
        }
      }

      // Add Papers
      for (var paper in allPapers) {
        String? path = paper[DatabaseHelper.columnFilePath];
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final ext = p.extension(path);
            final id = paper[DatabaseHelper.columnId];
            archive.addFile(
              ArchiveFile('papers/paper_$id$ext', bytes.length, bytes),
            );
          }
        }
      }

      // Add Documents
      for (var doc in allDocuments) {
        String? path = doc[DatabaseHelper.columnFilePath];
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final ext = p.extension(path);
            final id = doc[DatabaseHelper.columnId];
            archive.addFile(
              ArchiveFile('documents/doc_$id$ext', bytes.length, bytes),
            );
          }
        }
      }

      // Save Zip
      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);
      if (zipBytes == null) throw Exception('Failed to create zip');

      final directory = await getTemporaryDirectory();
      String timestamp = DateTime.now()
          .toString()
          .replaceAll(':', '-')
          .replaceAll(' ', '_');
      String fileName = 'mechminder_backup_$timestamp.zip';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(zipBytes);
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
                await Share.shareXFiles(
                  [xfile],
                  subject: 'MechMinder Data Backup (With Files)',
                  text: 'Here is the MechMinder backup file.',
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
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
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
            'Restoring from a backup will DELETE ALL current data in the app. This cannot be undone.',
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

      File backupFile = File(result.files.single.path!);
      String extension = p.extension(backupFile.path).toLowerCase();

      if (extension == '.zip') {
        // Handle ZIP
        final bytes = await backupFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Find JSON
        final jsonFile = archive.findFile('backup.json');
        if (jsonFile == null) {
          throw Exception('Invalid Backup: backup.json not found in zip');
        }

        String jsonString = utf8.decode(jsonFile.content);
        Map<String, dynamic> backupData = jsonDecode(jsonString);

        // Extract all files to a temp dir for dbHelper to access
        final tempDir = await getTemporaryDirectory();
        final extractDir = Directory('${tempDir.path}/restore_temp');
        if (await extractDir.exists()) {
          await extractDir.delete(recursive: true);
        }
        await extractDir.create();

        for (final file in archive) {
          if (file.isFile) {
            final data = file.content as List<int>;
            final filename = file.name;
            final filepath = '${extractDir.path}/$filename';
            // Create subdirectories if needed
            final File f = File(filepath);
            await f.create(recursive: true);
            await f.writeAsBytes(data);
          }
        }

        await dbHelper.restoreBackup(
          backupData,
          fileSourcePath: extractDir.path,
        );
      } else {
        // Handle JSON
        String jsonString = await backupFile.readAsString();
        Map<String, dynamic> backupData = jsonDecode(jsonString);
        await dbHelper.restoreBackup(backupData);
      }

      // --- REFRESH LOGIC ---
      // 1. Refresh the lists using the keys
      vehicleListKey.currentState?.refreshVehicleList();
      allRemindersKey.currentState?.refreshReminderList();

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

  // --- UPDATED BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 60),
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
                color: settings.primaryColor,
              ),
              title: const Text('Export Backup (Zip)'),
              subtitle: const Text('Save all data and files together'),
              onTap: () => _exportData(context),
            ),
            ListTile(
              leading: Icon(Icons.upload_file, color: settings.primaryColor),
              title: const Text('Restore Backup'),
              subtitle: const Text('Restore from a Zip or Json file'),
              onTap: () => _importData(context),
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
                // Navigate to Onboarding with flag isFromSettings = true
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const OnboardingScreen(isFromSettings: true),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
