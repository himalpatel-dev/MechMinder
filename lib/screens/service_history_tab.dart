import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'add_service_screen.dart';
import 'service_detail_screen.dart';

class ServiceHistoryTab extends StatefulWidget {
  final int vehicleId;
  const ServiceHistoryTab({super.key, required this.vehicleId});

  @override
  State<ServiceHistoryTab> createState() => _ServiceHistoryTabState();
}

class _ServiceHistoryTabState extends State<ServiceHistoryTab> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _serviceRecords = [];
  bool _isLoading = true;
  int _currentOdometer = 0;

  @override
  void initState() {
    super.initState();
    _refreshServiceList();
  }

  Future<void> _refreshServiceList() async {
    final vehicle = await dbHelper.queryVehicleById(widget.vehicleId);
    _currentOdometer = vehicle?[DatabaseHelper.columnCurrentOdometer] ?? 0;

    final services = await dbHelper.queryServicesForVehicle(widget.vehicleId);
    setState(() {
      _serviceRecords = services;
      _isLoading = false;
    });
  }

  void _navigateToAddService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddServiceScreen(
          vehicleId: widget.vehicleId,
          currentOdometer: _currentOdometer, // We pass the odometer here
        ),
      ),
    ).then((_) {
      // This will run when we come back from the form
      _refreshServiceList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We add a Scaffold here to get the FloatingActionButton
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _serviceRecords.isEmpty
          ? const Center(
              child: Text(
                'No service records found. \nTap the "+" button to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: _serviceRecords.length,
              itemBuilder: (context, index) {
                final record = _serviceRecords[index];
                // We'll show a simple card for now
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(
                      record[DatabaseHelper.columnNotes] ?? 'Service',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Date: ${record[DatabaseHelper.columnServiceDate]}\n'
                      'Vendor: ${record['vendor_name'] ?? 'N/A'}',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceDetailScreen(
                            serviceId: record[DatabaseHelper.columnId],
                            // --- ADD THESE TWO LINES ---
                            vehicleId: widget.vehicleId,
                            currentOdometer: _currentOdometer,
                          ),
                        ),
                      ).then((_) {
                        // --- ADD THIS .then() BLOCK ---
                        // This will refresh the service list if you
                        // delete the service from the detail screen (in a future step)
                        _refreshServiceList();
                      });
                    },
                    isThreeLine:
                        false, // We're moving data to the trailing widget
                    // --- NEW TRAILING WIDGET ---
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${record[DatabaseHelper.columnTotalCost] ?? '0.00'}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${record['item_count']} items', // <-- SHOWS ITEM COUNT
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddService,
        child: const Icon(Icons.add),
      ),
    );
  }
}
