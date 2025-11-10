import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'add_vehicle.dart';
import 'vehicle_detail.dart';
import 'vendor_list_screen.dart';
import 'service_templates_screen.dart';
import 'app_settings_screen.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';
import 'dart:io';
import '../widgets/mini_spending_chart.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final dbHelper = DatabaseHelper.instance;

  // This list will hold our vehicles
  List<Map<String, dynamic>> _vehicles = [];

  // A variable to track loading or errors
  String _statusMessage = "Loading vehicles...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshVehicleList();
  }

  void _refreshVehicleList() async {
    setState(() {
      _isLoading = true;
    }); // Show loading spinner

    // 1. Get all vehicles (with their reminders and photos)
    final allVehicles = await dbHelper.queryAllVehiclesWithNextReminder();

    // 2. Loop through each vehicle and get its spending data
    List<Map<String, dynamic>> vehiclesWithSpending = [];
    for (var vehicle in allVehicles) {
      // We have to run these queries for each vehicle
      final serviceTotal = await dbHelper.queryTotalSpendingForType(
        vehicle[DatabaseHelper.columnId],
        'services',
      );
      final expenseTotal = await dbHelper.queryTotalSpendingForType(
        vehicle[DatabaseHelper.columnId],
        'expenses',
      );

      // Add the new data to the vehicle's map
      Map<String, dynamic> vehicleData = Map.from(vehicle);
      vehicleData['service_total'] = serviceTotal;
      vehicleData['expense_total'] = expenseTotal;
      vehiclesWithSpending.add(vehicleData);
    }

    setState(() {
      _vehicles = vehiclesWithSpending;
      _isLoading = false;
    });
  }

  void _navigateToAddVehicle() {
    print("[DEBUG] Plus button tapped. Navigating to AddVehicleScreen...");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
    ).then((_) {
      // This runs when we come back
      _refreshVehicleList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        actions: [
          // Your existing buttons (Vendors, Templates, Settings)
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Manage Vendors',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VendorListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Manage Templates',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ServiceTemplatesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'App Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppSettingsScreen(),
                ),
              ).then((result) {
                if (result == true) {
                  _refreshVehicleList();
                }
              });
            },
          ),
        ],
      ),

      // --- BODY IS NOW UPDATED ---
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Loading vehicles..."),
                ],
              ),
            )
          : _vehicles.isEmpty
          ? const Center(
              child: Text(
                'No vehicles found. \nTap the "+" button to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          // --- USE GridView.builder INSTEAD OF ListView ---
          : GridView.builder(
              padding: const EdgeInsets.all(8.0),
              // This creates a 2-column grid
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 vehicles per row
                childAspectRatio: 0.8, // Adjust this ratio (width / height)
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
              ),
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];

                // (Get reminder text - same as before)
                String nextReminderText = "No upcoming reminders";
                final String? nextTemplate = vehicle['template_name'];
                final String? nextDate = vehicle[DatabaseHelper.columnDueDate];
                final int? nextOdo = vehicle[DatabaseHelper.columnDueOdometer];
                if (nextTemplate != null) {
                  if (nextDate != null) {
                    nextReminderText = 'Next: $nextTemplate (by $nextDate)';
                  } else if (nextOdo != null) {
                    nextReminderText =
                        'Next: $nextTemplate (by $nextOdo ${settings.unitType})';
                  }
                }

                // --- THIS IS THE NEW LOGIC ---
                // Get spending data for the text
                final double serviceTotal = vehicle['service_total'] ?? 0.0;
                final double expenseTotal = vehicle['expense_total'] ?? 0.0;
                final double totalSpending = serviceTotal + expenseTotal;
                // --- END OF NEW LOGIC ---

                return Card(
                  clipBehavior: Clip
                      .antiAlias, // Clips the image to the card's rounded border
                  elevation: 4,
                  child: InkWell(
                    // Makes the whole card tappable
                    onTap: () {
                      final int vehicleId = vehicle[DatabaseHelper.columnId];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VehicleDetailScreen(vehicleId: vehicleId),
                        ),
                      ).then((_) {
                        _refreshVehicleList();
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- 1. THE IMAGE (Unchanged) ---
                        AspectRatio(
                          aspectRatio: 1.5, // Adjust this (width / height)
                          child: _buildVehicleImage(vehicle['photo_uri']),
                        ),

                        // --- 2. THE DETAILS (Updated) ---
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${vehicle[DatabaseHelper.columnYear] ?? 'N/A'} | ${vehicle[DatabaseHelper.columnRegNo] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nextReminderText,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // --- THIS IS THE FIX ---
                              // We've replaced the chart with this Text
                              const SizedBox(height: 8),
                              Text(
                                'Total Spent: ${settings.currencySymbol}${totalSpending.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // --- END OF FIX ---
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _navigateToAddVehicle,
      ),
    );
  }

  // --- ADD THIS NEW HELPER WIDGET ---
  // This widget builds the image, or a placeholder if there is no image
  Widget _buildVehicleImage(String? photoPath) {
    if (photoPath != null && photoPath.isNotEmpty) {
      // We have a photo
      return Image.file(
        File(photoPath),
        fit: BoxFit.cover,

        // --- THIS IS THE FIX ---
        // 'loadingBuilder' is not a valid parameter for Image.file,
        // so we remove it. File loading is usually instant.
        // --- END OF FIX ---

        // Show an error icon if the file is missing/corrupt
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
          );
        },
      );
    } else {
      // No photo, show a placeholder
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.directions_car, color: Colors.grey[400], size: 60),
      );
    }
  }
}
