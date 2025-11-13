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
    // We check if the widget is still "mounted" (on the screen)
    // before updating the state.
    if (!mounted) return;

    try {
      final serviceData = await dbHelper.queryServiceById(widget.serviceId);
      if (serviceData == null) {
        // If service was deleted, pop back
        if (mounted) Navigator.of(context).pop();
        return;
      }

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- NEW: FUNCTION TO SHOW DELETE CONFIRMATION ---
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Delete Service?'),
          content: const Text(
            'Are you sure you want to permanently delete this service record? All its parts and photos will be lost.',
            // style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.black, // Black text
              ),
              onPressed: () async {
                // Delete all related data in a transaction
                print("Deleting service, items, and photos...");
                await dbHelper.deleteService(widget.serviceId);
                await dbHelper.deleteAllServiceItemsForService(
                  widget.serviceId,
                );
                await dbHelper.deletePhotosForParent(
                  widget.serviceId,
                  'service',
                );

                // --- 2. THIS IS THE FIX ---
                // Delete all reminders linked to this service
                print("Deleting associated reminders...");
                await dbHelper.deleteRemindersByService(widget.serviceId);
                // --- END OF FIX ---

                if (mounted) {
                  Navigator.of(ctx).pop(); // Close the dialog
                  Navigator.of(context).pop(); // Pop back
                }
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final Color myAppColor = settings.primaryColor;
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
                _loadServiceDetails(); // Refresh after editing
              });
            },
          ),
          // --- NEW: DELETE BUTTON ---
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete Service',
            onPressed: _showDeleteConfirmation,
          ),
          // --- END OF NEW BUTTON ---
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Details Card (Unchanged) ---
            Card(
              elevation: 4,
              child: Column(
                children: [
                  _buildDetailTile(
                    icon: Icons.calendar_today,
                    title: 'Date',
                    subtitle: _service![DatabaseHelper.columnServiceDate],
                    primaryColor: myAppColor,
                  ),
                  _buildDetailTile(
                    icon: Icons.speed,
                    title: 'Odometer',
                    subtitle:
                        '${_service![DatabaseHelper.columnOdometer]} ${settings.unitType}',
                    primaryColor: myAppColor,
                  ),
                  _buildDetailTile(
                    icon: Icons.store,
                    title: 'Workshop',
                    subtitle: _service!['vendor_name'] ?? 'N/A',
                    primaryColor: myAppColor,
                  ),
                  _buildDetailTile(
                    icon: Icons.attach_money,
                    title: 'Total Cost',
                    subtitle:
                        '${settings.currencySymbol}${_service![DatabaseHelper.columnTotalCost] ?? '0.00'}',
                    isGreen: true,
                    primaryColor: myAppColor,
                  ),
                  _buildDetailTile(
                    icon: Icons.notes,
                    title: 'Notes',
                    subtitle: _service![DatabaseHelper.columnNotes] ?? 'N/A',
                    isThreeLine: true,
                    primaryColor: myAppColor,
                  ),
                ],
              ),
            ),

            // --- Parts Card (Unchanged) ---
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
                        // color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Divider(height: 20),
                    if (_serviceItems.isEmpty)
                      const Text('No parts were added.')
                    else
                      DataTable(
                        columnSpacing: 20,
                        horizontalMargin: 0,
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

            // --- Photos Card (Unchanged) ---
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

  // (Helper widget is unchanged)
  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color primaryColor,
    bool isGreen = false,
    bool isThreeLine = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryColor),
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

  // (Helper widget is unchanged)
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
                // color: Theme.of(context).primaryColor,
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
