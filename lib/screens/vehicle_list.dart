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
import '../widgets/mini_spending_chart.dart'; // Make sure this path is correct

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshVehicleList();
  }

  Future<void> _refreshVehicleList() async {
    // (This function is unchanged)
    setState(() {
      _isLoading = true;
    });
    final allVehicles = await dbHelper.queryAllVehiclesWithNextReminder();
    List<Map<String, dynamic>> vehiclesWithSpending = [];
    for (var vehicle in allVehicles) {
      final serviceTotal = await dbHelper.queryTotalSpendingForType(
        vehicle[DatabaseHelper.columnId],
        'services',
      );
      final expenseTotal = await dbHelper.queryTotalSpendingForType(
        vehicle[DatabaseHelper.columnId],
        'expenses',
      );
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
    // (This function is unchanged)
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
    ).then((_) {
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
          // (Your App Bar buttons are unchanged)
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

      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Loading dashboard..."),
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
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
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

                // (Get spending data - same as before)
                final double serviceTotal = vehicle['service_total'] ?? 0.0;
                final double expenseTotal = vehicle['expense_total'] ?? 0.0;
                final double totalSpending = serviceTotal + expenseTotal;

                // --- THIS IS THE REDESIGNED CARD UI ---
                return Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 1. THE IMAGE & TITLE STACK (UPDATED) ---
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _buildVehicleImage(vehicle['photo_uri']),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),
                            // --- FIX 1: Removed Year/RegNo from here ---
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Text(
                                '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                            // --- END OF FIX 1 ---
                          ],
                        ),

                        // --- 2. THE DETAILS ROW (UPDATED) ---
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              // Left Side: Text Details
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // --- FIX 1: Added Year/RegNo here ---
                                    Text(
                                      '${vehicle[DatabaseHelper.columnYear] ?? 'N/A'} | ${vehicle[DatabaseHelper.columnRegNo] ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    // --- END OF FIX 1 ---
                                    Text(
                                      'NEXT REMINDER',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      nextReminderText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Right Side: Chart & Total
                              Expanded(
                                flex: 2,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // --- FIX 2: Check if spending is zero ---
                                    if (totalSpending == 0)
                                      Column(
                                        children: [
                                          Icon(
                                            Icons.pie_chart_outline,
                                            size: 40,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${settings.currencySymbol}0 total',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Column(
                                        children: [
                                          SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: MiniSpendingChart(
                                              serviceSpending: serviceTotal,
                                              expenseSpending: expenseTotal,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${settings.currencySymbol}${totalSpending.toStringAsFixed(0)} total',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    // --- END OF FIX 2 ---
                                  ],
                                ),
                              ),
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

  // (This helper function is unchanged)
  Widget _buildVehicleImage(String? photoPath) {
    if (photoPath != null && photoPath.isNotEmpty) {
      return Image.file(
        File(photoPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.directions_car, color: Colors.grey[400], size: 60),
      );
    }
  }
}
