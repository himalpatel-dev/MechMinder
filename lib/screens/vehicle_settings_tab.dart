import 'package:flutter/material.dart';
import '../service/database_helper.dart';
// We'll import the AddVehicleScreen but re-use it for "editing"
import 'add_vehicle.dart';
import 'vehicle_list.dart'; // To navigate home after delete

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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                    // We'll implement this "Edit" feature in a future step
                    // as it requires modifying the AddVehicleScreen to accept data.
                    _navigateToEditVehicle(context);
                  },
                ),
                const Divider(height: 1),
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
