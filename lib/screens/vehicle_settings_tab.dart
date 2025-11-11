import 'package:flutter/material.dart';
import '../service/database_helper.dart';
// We'll import the AddVehicleScreen but re-use it for "editing"
import 'add_vehicle.dart';
import 'vehicle_list.dart'; // To navigate home after delete
import 'package:provider/provider.dart';
import '../service/excel_service.dart';
import '../service/settings_provider.dart';

class VehicleSettingsTab extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback onVehicleUpdated; // A function to refresh the parent

  const VehicleSettingsTab({
    super.key,
    required this.vehicle,
    required this.onVehicleUpdated,
  });

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Delete Vehicle?'),
          content: Text(
            'Are you sure you want to delete "${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}"?\n\nThis action is permanent and will delete all associated services, expenses, and reminders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final dbHelper = DatabaseHelper.instance;
                await dbHelper.deleteVehicle(vehicle[DatabaseHelper.columnId]);

                // Pop the dialog
                Navigator.of(ctx).pop();

                // Go all the way back to the home screen
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const VehicleListScreen(),
                    ),
                    (Route<dynamic> route) => false, // Remove all other routes
                  );
                }
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToEditVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(
          // --- PASS THE VEHICLE ID ---
          vehicleId: vehicle[DatabaseHelper.columnId],
        ),
      ),
    ).then((_) {
      // --- REFRESH THE DATA WHEN WE COME BACK ---
      onVehicleUpdated();
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. Get the settings provider ---
    final settings = Provider.of<SettingsProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_note, color: Colors.blue),
                  title: const Text('Edit Vehicle Details'),
                  subtitle: const Text('Update make, model, year, etc.'),
                  onTap: () {
                    _navigateToEditVehicle(context);
                  },
                ),

                // --- 2. ADD THE NEW EXPORT BUTTON ---
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.download, color: Colors.green[700]),
                  title: const Text('Export Vehicle Report'),
                  subtitle: const Text('Save services and expenses to Excel'),
                  onTap: () async {
                    // Show a "loading" snackbar
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Creating report...')),
                    );

                    // Create the service and run the report
                    final excelService = ExcelService(
                      dbHelper: DatabaseHelper.instance,
                      settings: settings,
                    );

                    final result = await excelService.createExcelReport(
                      vehicle[DatabaseHelper.columnId],
                      '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                    );

                    // Show the result
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(result ?? 'An unknown error occurred.'),
                        backgroundColor:
                            result != null && result.startsWith('Report saved')
                            ? Colors.green
                            : Colors.red,
                      ),
                    );
                  },
                ),

                // --- END OF NEW BUTTON ---
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Vehicle'),
                  subtitle: const Text('Permanently remove this vehicle'),
                  onTap: () => _showDeleteConfirmation(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
