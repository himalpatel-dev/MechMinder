import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart';
import '../service/settings_provider.dart';
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
    if (!mounted) return;

    try {
      final serviceData = await dbHelper.queryServiceById(widget.serviceId);
      if (serviceData == null) {
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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Delete Service?'),
          content: const Text(
            'Are you sure you want to permanently delete this service record? All its parts and photos will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await dbHelper.deleteService(widget.serviceId);
                await dbHelper.deleteAllServiceItemsForService(
                  widget.serviceId,
                );
                await dbHelper.deletePhotosForParent(
                  widget.serviceId,
                  'service',
                );
                await dbHelper.deleteRemindersByService(widget.serviceId);

                if (mounted) {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Service not found.')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _service![DatabaseHelper.columnServiceName] ?? 'Service Detail',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: primaryColor),
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
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            tooltip: 'Delete Service',
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Summary Card ---
            _buildSummaryCard(settings, isDark, primaryColor),
            const SizedBox(height: 20),

            // --- Parts List ---
            if (_serviceItems.isNotEmpty) ...[
              Text(
                "PARTS & ITEMS",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _buildPartsList(settings, isDark),
              const SizedBox(height: 24),
            ],

            // --- Photos Section ---
            if (_servicePhotos.isNotEmpty) ...[
              Text(
                "PHOTOS",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _buildPhotosList(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    SettingsProvider settings,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn(
                "Date",
                _service![DatabaseHelper.columnServiceDate],
                Icons.calendar_today,
                isDark,
                primaryColor,
              ),
              _buildInfoColumn(
                "Odometer",
                '${_service![DatabaseHelper.columnOdometer]} ${settings.unitType}',
                Icons.speed,
                isDark,
                primaryColor,
                crossAlign: CrossAxisAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: isDark ? Colors.white10 : Colors.grey.shade100),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.store, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Workshop",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      _service!['vendor_name'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_service![DatabaseHelper.columnNotes] != null &&
              _service![DatabaseHelper.columnNotes].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notes,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Notes",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        _service![DatabaseHelper.columnNotes],
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Cost",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                Text(
                  '${settings.currencySymbol}${_service![DatabaseHelper.columnTotalCost] ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    String value,
    IconData icon,
    bool isDark,
    Color primaryColor, {
    CrossAxisAlignment crossAlign = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (crossAlign == CrossAxisAlignment.start) ...[
              Icon(
                icon,
                size: 14,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
            if (crossAlign == CrossAxisAlignment.end) ...[
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 14,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildPartsList(SettingsProvider settings, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _serviceItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == _serviceItems.length - 1;
          final name = item[DatabaseHelper.columnName];
          final qty = (item[DatabaseHelper.columnQty] as num).toDouble();
          final cost = (item[DatabaseHelper.columnUnitCost] as num).toDouble();
          final total = (item[DatabaseHelper.columnTotalCost] as num)
              .toDouble();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$qty x ${settings.currencySymbol}$cost',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${settings.currencySymbol}${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPhotosList(bool isDark) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _servicePhotos.length,
        itemBuilder: (context, index) {
          final photo = _servicePhotos[index];
          final photoPath = photo[DatabaseHelper.columnUri];
          return GestureDetector(
            onTap: () {
              final paths = _servicePhotos
                  .map((photo) => photo[DatabaseHelper.columnUri] as String)
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
              width: 140,
              margin: const EdgeInsets.only(right: 12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black26 : Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                image: DecorationImage(
                  image: FileImage(File(photoPath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
