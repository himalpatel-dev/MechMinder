import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'dart:io';

class OverviewTab extends StatefulWidget {
  final int vehicleId;
  const OverviewTab({super.key, required this.vehicleId});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final dbHelper = DatabaseHelper.instance;
  final TextEditingController _odometerController = TextEditingController();

  Map<String, dynamic>? _vehicle;
  Map<String, dynamic>? _nextDueDateReminder;
  Map<String, dynamic>? _nextOdometerReminder;

  List<Map<String, dynamic>> _vehiclePhotos = [];

  bool _isLoading = true;
  // --- ADD THIS VARIABLE TO STORE ERRORS ---
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // --- ADD try...catch BLOCK ---
    try {
      // 1. Get vehicle details
      final vehicleData = await dbHelper.queryVehicleById(widget.vehicleId);

      // 2. Get reminder summary
      final summary = await dbHelper.queryNextDueSummary(widget.vehicleId);

      // 3. Get vehicle photos
      final photos = await dbHelper.queryPhotosForParent(
        widget.vehicleId,
        'vehicle',
      );

      if (vehicleData == null) {
        // This is a common error we can check for
        throw Exception("Vehicle data not found (ID: ${widget.vehicleId})");
      }

      setState(() {
        _vehicle = vehicleData;

        // This line is a common place for errors if the column is null
        _odometerController.text =
            (vehicleData[DatabaseHelper.columnCurrentOdometer] ?? 0).toString();

        _nextDueDateReminder = summary['nextByDate'];
        _nextOdometerReminder = summary['nextByOdometer'];
        _isLoading = false;
        _vehiclePhotos = photos;
        _errorMessage = null; // Clear any old errors
      });
      print("[DEBUG OverviewTab] Data load and setState complete.");
    } catch (e) {
      // --- CATCH AND DISPLAY THE ERROR ---
      print("[DEBUG OverviewAab] !!!--- ERROR in _loadData ---!!!");
      print(e);
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString(); // Store the error to show it on screen
      });
    }
  }

  void _saveOdometer() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    print("[DEBUG] UPDATE button pressed.");

    int newOdometer = int.tryParse(_odometerController.text) ?? 0;
    print(
      "[DEBUG] Saving new odometer value: $newOdometer for vehicle ID: ${widget.vehicleId}",
    );

    await dbHelper.updateVehicleOdometer(widget.vehicleId, newOdometer);
    print("[DEBUG] Database update called successfully.");

    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Odometer updated!'),
        backgroundColor: Colors.green,
      ),
    );
    print("[DEBUG] Odometer update complete!");
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- ADD THIS ERROR CHECK ---
    // If we have an error, show it instead of the content
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error loading data:\n\n$_errorMessage',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // --- END ERROR CHECK ---

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // --- THE BIG CARD ---
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CURRENT ODOMETER',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _odometerController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(suffixText: 'km'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saveOdometer, // Use our saved function
                        child: const Text('UPDATE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),

                  // --- NEXT DUE SUMMARY ---
                  const Text(
                    'NEXT DUE SUMMARY',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  _buildNextDueRow(
                    icon: Icons.calendar_today,
                    label: 'By Date',
                    value: _nextDueDateReminder != null
                        ? '${_nextDueDateReminder![DatabaseHelper.columnDueDate]}'
                        : 'No upcoming reminders',
                  ),
                  const SizedBox(height: 10),
                  _buildNextDueRow(
                    icon: Icons.speed,
                    label: 'By Odometer',
                    value: _nextOdometerReminder != null
                        ? '${_nextOdometerReminder![DatabaseHelper.columnDueOdometer]} km'
                        : 'No upcoming reminders',
                  ),
                ],
              ),
            ),
          ),
          // --- ADD THIS NEW PHOTO GALLERY CARD ---
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'PHOTO GALLERY',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                SizedBox(
                  height: 120, // Gallery height
                  child: _vehiclePhotos.isEmpty
                      ? const Center(child: Text('No photos added yet.'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _vehiclePhotos.length,
                          itemBuilder: (context, index) {
                            final photo = _vehiclePhotos[index];
                            final photoPath = photo[DatabaseHelper.columnUri];

                            return Container(
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
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16), // Padding at the bottom
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for a formatted row
  Widget _buildNextDueRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 10),
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 5),
        Expanded(child: Text(value)),
      ],
    );
  }
}
