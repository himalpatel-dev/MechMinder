import 'dart:io';
import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'add_service_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final int serviceId;
  final int vehicleId;
  final int currentOdometer;

  const ServiceDetailScreen({
    super.key,
    required this.serviceId,
    required this.vehicleId,
    required this.currentOdometer,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final dbHelper = DatabaseHelper.instance;

  Map<String, dynamic>? _service;
  List<Map<String, dynamic>> _serviceItems = [];
  List<Map<String, dynamic>> _servicePhotos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServiceDetails();
  }

  Future<void> _loadServiceDetails() async {
    // We need a new function to get a single service, but for now,
    // we'll just re-query all of them and find the one we need.
    // In a future step, we can optimize this.
    // Let's create a temporary (less efficient) way to get the data.

    // We'll re-use the queryServicesForVehicle (which gets all) and find ours.
    // This is inefficient, but requires no DB changes right now.
    // A better way is to add a `queryServiceById` function.

    // Let's add that new DB function first... (see Part B)
    // For now, let's assume we have the functions from Part B

    try {
      final serviceData = await dbHelper.queryServiceById(widget.serviceId);
      final itemsData = await dbHelper.queryServiceItems(widget.serviceId);
      final photosData = await dbHelper.queryPhotosForParent(
        widget.serviceId,
        'service',
      );

      setState(() {
        _service = serviceData;
        _serviceItems = itemsData;
        _servicePhotos = photosData;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading service details: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Service not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Service on ${_service![DatabaseHelper.columnServiceDate]}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Service',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddServiceScreen(
                    vehicleId: widget.vehicleId,
                    currentOdometer: widget.currentOdometer,
                    serviceId:
                        widget.serviceId, // <-- This puts it in "Edit Mode"
                  ),
                ),
              ).then((_) {
                // This refreshes the details when we come back
                _loadServiceDetails();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Overview Card ---
            _buildDetailCard(
              title: 'Details',
              children: [
                _buildDetailRow(
                  'Date:',
                  _service![DatabaseHelper.columnServiceDate],
                ),
                _buildDetailRow(
                  'Odometer:',
                  '${_service![DatabaseHelper.columnOdometer]} km',
                ),
                _buildDetailRow('Vendor:', _service!['vendor_name'] ?? 'N/A'),
                _buildDetailRow(
                  'Total Cost:',
                  '\$${_service![DatabaseHelper.columnTotalCost] ?? '0.00'}',
                ),
                _buildDetailRow(
                  'Notes:',
                  _service![DatabaseHelper.columnNotes] ?? 'N/A',
                ),
              ],
            ),

            // --- Parts Card ---
            const SizedBox(height: 20),
            _buildDetailCard(
              title: 'Parts / Items (${_serviceItems.length})',
              children: [
                if (_serviceItems.isEmpty) const Text('No parts were added.'),
                for (var item in _serviceItems) _buildPartRow(item),
              ],
            ),

            // --- Photos Card ---
            const SizedBox(height: 20),
            _buildDetailCard(
              title: 'Photos (${_servicePhotos.length})',
              children: [
                if (_servicePhotos.isEmpty) const Text('No photos were added.'),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _servicePhotos.length,
                    itemBuilder: (context, index) {
                      final photo = _servicePhotos[index];
                      return Container(
                        width: 120,
                        height: 120,
                        margin: const EdgeInsets.only(right: 8.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(
                              File(photo[DatabaseHelper.columnUri]),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build a styled card
  Widget _buildDetailCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  // Helper widget for a single detail row
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Helper widget for a single part row
  Widget _buildPartRow(Map<String, dynamic> item) {
    String name = item[DatabaseHelper.columnName];
    double qty = (item[DatabaseHelper.columnQty] as num).toDouble();
    double cost = (item[DatabaseHelper.columnUnitCost] as num).toDouble();
    double total = (item[DatabaseHelper.columnTotalCost] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name)),
          Text('$qty x \$${cost.toStringAsFixed(2)}'),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
