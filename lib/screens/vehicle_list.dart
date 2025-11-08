import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'add_vehicle.dart';
import 'vehicle_detail.dart';
import 'vendor_list_screen.dart';
import 'service_templates_screen.dart';
import 'app_settings_screen.dart';

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

  Future<void> _refreshVehicleList() async {
    try {
      // This is the part that was failing before
      print("[DEBUG] Trying to query all vehicles..."); // Check DEBUG CONSOLE
      final allVehicles = await dbHelper.queryAllVehicles();

      setState(() {
        _vehicles = allVehicles;
        _isLoading = false;
        if (_vehicles.isEmpty) {
          _statusMessage =
              "No vehicles found. \nTap the '+' button to add one!";
        }
      });
      print("[DEBUG] Query successful. Found ${_vehicles.length} vehicles.");
    } catch (e) {
      // If there's an error, we will see it
      setState(() {
        _isLoading = false;
        _statusMessage = "Error loading vehicles: \n${e.toString()}";
      });
      print("[DEBUG] !!!--- ERROR in _refreshVehicleList ---!!!");
      print(e);
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),

        // --- THIS IS THE CORRECT LOCATION ---
        actions: [
          IconButton(
            icon: const Icon(Icons.store), // "Store" icon for vendors
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
            icon: const Icon(Icons.list_alt), // "List" icon for templates
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
            icon: const Icon(Icons.settings), // "Settings" gear icon
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
        // --- END OF 'actions' ---
      ), // <-- AppBar() ends here

      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(_statusMessage),
                ],
              ),
            )
          : _vehicles.isEmpty
          ? Center(
              child: Text(
                _statusMessage, // This will show "No vehicles found..."
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(
                      '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Year: ${vehicle[DatabaseHelper.columnYear] ?? 'N/A'} | Reg: ${vehicle[DatabaseHelper.columnRegNo] ?? 'N/A'}',
                    ),
                    onTap: () {
                      final int vehicleId = vehicle[DatabaseHelper.columnId];

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VehicleDetailScreen(vehicleId: vehicleId),
                        ),
                      ).then((_) {
                        // --- THIS IS THE FIX ---
                        // This code runs when you "pop" back to this screen
                        print(
                          "Popped back to VehicleListScreen, refreshing list...",
                        );
                        _refreshVehicleList();
                        // --- END OF FIX ---
                      });
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddVehicle,
        child: const Icon(Icons.add),
      ),
    );
  }
}
