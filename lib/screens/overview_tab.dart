import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'dart:io';
import '../widgets/full_screen_photo_viewer.dart';
import '../service/notification_service.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';

class OverviewTab extends StatefulWidget {
  final int vehicleId;
  const OverviewTab({super.key, required this.vehicleId});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final dbHelper = DatabaseHelper.instance;
  final TextEditingController _odometerController = TextEditingController();

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
    // --- 1. Get existing data ---
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    int newOdometer = int.tryParse(_odometerController.text) ?? 0;

    // --- 2. Save the new odometer to the DB ---
    await dbHelper.updateVehicleOdometer(widget.vehicleId, newOdometer);

    // --- 3. Show confirmation SnackBar ---
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Odometer updated!'),
        backgroundColor: Colors.green,
      ),
    );
    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    // --- 4. NEW: CHECK ODOMETER-BASED REMINDERS ---
    print("Checking odometer-based reminders...");

    // Get all reminders for this vehicle
    final allReminders = await dbHelper.queryRemindersForVehicle(
      widget.vehicleId,
    );

    for (var reminder in allReminders) {
      final dueOdometer = reminder[DatabaseHelper.columnDueOdometer];

      // Check if it's an odometer reminder AND if we've passed the value
      if (dueOdometer != null && newOdometer >= dueOdometer) {
        final int reminderId = reminder[DatabaseHelper.columnId];
        final String templateName = reminder['template_name'] ?? 'Service';

        print(
          "  > Odometer due for '$templateName'! Sending notification and deleting reminder.",
        );

        // 5. Send immediate notification
        await NotificationService().showImmediateReminder(
          id: reminderId, // Use the reminder's ID
          title: 'Vehicle Service Due',
          body:
              'Your "$templateName" service is due! (Reached $dueOdometer km).',
        );
      }
    }
    // --- END OF NEW LOGIC ---
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
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
                          decoration: InputDecoration(
                            suffixText: settings.unitType, // <-- THE FIX
                          ),
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
                        ? '${_nextOdometerReminder![DatabaseHelper.columnDueOdometer]} ${settings.unitType}' // <-- THE FIX
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

                            return GestureDetector(
                              // <-- WRAP WITH THIS
                              onTap: () {
                                // --- ADD THIS NAVIGATION ---
                                // Create a simple list of just the paths
                                final paths = _vehiclePhotos
                                    .map(
                                      (photo) =>
                                          photo[DatabaseHelper.columnUri]
                                              as String,
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
                                // --- END OF NAVIGATION ---
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
