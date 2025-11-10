import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
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
    final data = await Future.wait([
      dbHelper.queryServicesForVehicle(widget.vehicleId),
      dbHelper.queryVehicleById(widget.vehicleId),
    ]);

    final services = data[0] as List<Map<String, dynamic>>;
    final vehicle = data[1] as Map<String, dynamic>?;

    setState(() {
      _serviceRecords = services;
      _currentOdometer = vehicle?[DatabaseHelper.columnCurrentOdometer] ?? 0;
      _isLoading = false;
    });
  }

  void _navigateToAddService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddServiceScreen(
          vehicleId: widget.vehicleId,
          currentOdometer: _currentOdometer,
        ),
      ),
    ).then((_) {
      _refreshServiceList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
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
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _serviceRecords.length,
              itemBuilder: (context, index) {
                final record = _serviceRecords[index];

                // --- THIS IS THE NEW, REDESIGNED CARD ---
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  elevation: 3,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceDetailScreen(
                            serviceId: record[DatabaseHelper.columnId],
                            vehicleId: widget.vehicleId,
                            currentOdometer: _currentOdometer,
                          ),
                        ),
                      ).then((_) {
                        _refreshServiceList();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
                          // 1. Leading Icon (wrench)
                          const Icon(Icons.build, color: Colors.blue, size: 30),
                          const SizedBox(width: 16),

                          // 2. Main Details (fills the space)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record[DatabaseHelper.columnServiceName] ??
                                      'Service',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Icon Row for Date
                                _buildIconRow(
                                  Icons.calendar_today,
                                  record[DatabaseHelper.columnServiceDate],
                                ),
                                const SizedBox(height: 4),
                                // Icon Row for Odometer
                                _buildIconRow(
                                  Icons.speed,
                                  '${record[DatabaseHelper.columnOdometer] ?? 'N/A'} ${settings.unitType}',
                                ),
                                const SizedBox(height: 4),
                                // Icon Row for Vendor
                                _buildIconRow(
                                  Icons.store,
                                  record['vendor_name'] ?? 'N/A',
                                ),
                              ],
                            ),
                          ),

                          // 3. Trailing Cost and Chevron
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${settings.currencySymbol}${record[DatabaseHelper.columnTotalCost] ?? '0.00'}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${record['item_count']} items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                // --- END OF NEW CARD ---
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddService,
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- NEW HELPER WIDGET FOR ICON ROWS ---
  Widget _buildIconRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
      ],
    );
  }
}
