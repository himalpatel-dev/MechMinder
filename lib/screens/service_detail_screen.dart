import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
import 'add_service_screen.dart';
import '../widgets/full_screen_photo_viewer.dart';

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
    // Get settings for currency and units
    final settings = Provider.of<SettingsProvider>(context);

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
          _service![DatabaseHelper.columnServiceName] ?? 'Service Detail',
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
                    serviceId: widget.serviceId,
                  ),
                ),
              ).then((_) {
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
            // --- THIS IS THE NEW DETAILS CARD ---
            Card(
              elevation: 4,
              child: Column(
                children: [
                  _buildDetailTile(
                    icon: Icons.calendar_today,
                    title: 'Date',
                    subtitle: _service![DatabaseHelper.columnServiceDate],
                  ),
                  _buildDetailTile(
                    icon: Icons.speed,
                    title: 'Odometer',
                    subtitle:
                        '${_service![DatabaseHelper.columnOdometer]} ${settings.unitType}',
                  ),
                  _buildDetailTile(
                    icon: Icons.store,
                    title: 'Vendor',
                    subtitle: _service!['vendor_name'] ?? 'N/A',
                  ),
                  _buildDetailTile(
                    icon: Icons.attach_money,
                    title: 'Total Cost',
                    subtitle:
                        '${settings.currencySymbol}${_service![DatabaseHelper.columnTotalCost] ?? '0.00'}',
                    isGreen: true,
                  ),
                  _buildDetailTile(
                    icon: Icons.notes,
                    title: 'Notes',
                    subtitle: _service![DatabaseHelper.columnNotes] ?? 'N/A',
                    isThreeLine: true,
                  ),
                ],
              ),
            ),
            // --- END OF NEW CARD ---

            // --- Parts Card ---
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARTS / ITEMS (${_serviceItems.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Divider(height: 20),
                    if (_serviceItems.isEmpty)
                      const Text('No parts were added.')
                    else
                      // Use a DataTable for a clean, aligned table
                      DataTable(
                        columnSpacing: 20, // Space between columns
                        horizontalMargin: 0, // No extra margin
                        headingRowHeight: 30,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Part',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Qty',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Cost',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                        ],
                        rows: _serviceItems.map((item) {
                          // Get the data from the item
                          final name = item[DatabaseHelper.columnName];
                          final qty = (item[DatabaseHelper.columnQty] as num)
                              .toDouble();
                          final cost =
                              (item[DatabaseHelper.columnUnitCost] as num)
                                  .toDouble();
                          final total =
                              (item[DatabaseHelper.columnTotalCost] as num)
                                  .toDouble();

                          return DataRow(
                            cells: [
                              DataCell(Text(name)),
                              DataCell(Text(qty.toString())),
                              DataCell(
                                Text(
                                  '${settings.currencySymbol}${cost.toStringAsFixed(2)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${settings.currencySymbol}${total.toStringAsFixed(2)}',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // --- Photos Card ---
            const SizedBox(height: 20),
            _buildDetailCard(
              title: 'Photos (${_servicePhotos.length})',
              children: [
                if (_servicePhotos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No photos were added.'),
                  ),
                if (_servicePhotos.isNotEmpty)
                  SizedBox(
                    // Use SizedBox to give the gallery a fixed height
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _servicePhotos.length,
                      itemBuilder: (context, index) {
                        final photo = _servicePhotos[index];
                        final photoPath = photo[DatabaseHelper.columnUri];
                        return GestureDetector(
                          onTap: () {
                            final paths = _servicePhotos
                                .map(
                                  (photo) =>
                                      photo[DatabaseHelper.columnUri] as String,
                                )
                                .toList();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenPhotoViewer(
                                  photoPaths: paths,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            margin: const EdgeInsets.only(right: 8.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(File(photoPath)),
                                fit: BoxFit.cover,
                              ),
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

  // --- NEW: Helper widget for a styled ListTile ---
  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isGreen = false,
    bool isThreeLine = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 16,
          color: isGreen ? Colors.green[700] : null,
          fontWeight: isGreen ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      isThreeLine: isThreeLine,
    );
  }
  // --- END OF NEW HELPER ---

  // Helper widget to build a styled card (for Parts and Photos)
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
}
